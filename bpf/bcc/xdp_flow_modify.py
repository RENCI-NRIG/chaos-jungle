#!/usr/bin/env python

# modify TCP payloads to keep checksum
# probability distribution ? 
# using either XDP or TC BPF hooks

from bcc import BPF
import pyroute2
import time
import sys
import argparse
import collections
import socket
import struct
import warnings
import atexit

def hostnameToLong(ip):
    """Return 32-bit representation of IP address or hostname in network byte order"""
    if ip is None:
        return 0
    packetIP = socket.inet_pton(socket.AF_INET, socket.gethostbyname(ip))
    # always produces a tuple, so take 0th index
    return socket.htonl(struct.unpack("!L", packetIP)[0])

def portToShort(port):
    """Return 16-bit representation of port in network byte order"""
    if port is None:
        return 0
    return socket.htons(port)

def protoUdp(proto):
    """Return 1 if protocol string us UDP, 0 otherwise"""
    if proto is None:
        return 0
    if proto == 'udp':
        return 1
    return 0

def unloadBPF(mode, idx):
    print "Unloading BPF"
    if mode == BPF.XDP:
        b.remove_xdp(device)
    else:
        ip.tc("del", "clsact", idx)
        ipdb.release()

flags = 0
parser = argparse.ArgumentParser(epilog="""
Each flow can be specified as src=a.b.c.d,dst=m.n.o.p,sport=X,dport=Y\n
Any of the flow parameters can be omitted and specified in any order.
No spaces are allowed. Up to 5 flowspecs are allowed.
""")

parser.add_argument("interface", help="interface to bind program to")
parser.add_argument("--flow", action="append", help="flow specifier")
parser.add_argument("-t", "--tc", action="store_true", help="Use TC ingress hook instead of XDP")

args = parser.parse_args()

flowparser = argparse.ArgumentParser()
flowparser.add_argument("--src", help="TCP flow source IP address")
flowparser.add_argument("--dst", help="TCP flow destination IP address")
flowparser.add_argument("--sport", help="TCP flow source port", type=int)
flowparser.add_argument("--dport", help="TCP flow destination port", type=int)
flowparser.add_argument("--proto", help="Protocol TCP or UDP, defaults to TCP", choices=['tcp', 'udp'], default='tcp')

device = args.interface

if args.tc:
    flags |= 2 << 0
    mode = BPF.SCHED_CLS
    retcode = "TC_ACT_OK"
    ctxtype = "__sk_buff"
else:
    mode = BPF.XDP
    retcode = "XDP_PASS"
    ctxtype = "xdp_md"

# list of flowspecs
flowlist = []

flownum = 0

if args.flow:
    flownum = len(args.flow)
    if flownum > 5:
        print("Too manu flowspecs ({}), exiting. Only 5 allowed".format(flownum))
        sys.exit(1)
else:
    warnings.warn("WARNING: All TCP flows entering interface {} will be modified".format(device))

print ("There are {} flowspecs\n".format(flownum))
print("Binding to {} using method {}".format(device, mode))
    
# load from file
b = BPF(src_file = "flow_modify.c", cflags=["-w",
                                            "-DCTXTYPE=%s" % ctxtype,
                                            "-DRETCODE=%s" % retcode,
                                            "-DFLOWNUM=%d" % flownum], debug = 0)

fn = b.load_func("xdp_flow_mod_prog", mode)

# attach via TC or XDP
idx = 0
if mode == BPF.XDP:
    b.attach_xdp(device, fn, flags)
else:
    ip = pyroute2.IPRoute()
    ipdb = pyroute2.IPDB(nl=ip)
    idx = ipdb.interfaces[device].index
    ip.tc("add", "clsact", idx)
    ip.tc("add-filter", "bpf", idx, ":1", fd=fn.fd, name=fn.name,
          parent="ffff:fff2", classid=1, direct_action=True)

# be sure to cleanup on exit
atexit.register(unloadBPF, mode, idx)

# fill out flowspecs
flowspecs = b["flowspecs"]

# fill in the flow table
flowIdx = 0
if args.flow:
    for flow in args.flow:
        flowarg = "--" + flow.replace(",", " --").replace("=", " ")
        # parse flow specifier
        flowargs = flowparser.parse_args(flowarg.split())
        flowspecs[flowspecs.Key(flowIdx)] = flowspecs.Leaf(saddr = hostnameToLong(flowargs.src),
                                                           daddr = hostnameToLong(flowargs.dst),
                                                           sport = portToShort(flowargs.sport),
                                                           dport = portToShort(flowargs.dport),
                                                           udp = protoUdp(flowargs.proto),
                                                           active = 1)
        flowIdx += 1

while 1:
    try:
        (saddr, daddr) = b.trace_print()
        print("Entry has {} {}\n".format(saddr, daddr))
        time.sleep(1)
    except KeyboardInterrupt:
        print("Removing filter from device")
        break;


