#!/usr/bin/env python3

# count TCP packets from a particular source
# using either XDP or TC BPF hooks

from bcc import BPF
import pyroute2
import time
import sys
import argparse

flags = 0
parser = argparse.ArgumentParser()

parser.add_argument("interface", help="interface to bind program to")
parser.add_argument("-s", "--source", help="TCP flow source IP address")
parser.add_argument("-p", "--port", help="TCP flow source port")
parser.add_argument("-t", "--tc", action="store_true", help="Use TC ingress hook instead of XDP")

args = parser.parse_args()

device = args.interface

if args.tc:
    flags |= 2 << 0
    mode = BPF.SCHED_CLS
    ret = "TC_ACT_OK"
    ctxtype = "__sk_buff"
else:
    mode = BPF.XDP
    ret = "XDP_PASS"
    ctxtype = "xdp_md"

print("Binding to {} using method {}".format(device, mode))
    
# load from file

b = BPF(src_file = "tcp_count.c", cflags=["-w", "-DCTXTYPE=%s" % ctxtype], debug = 0)

fn = b.load_func("xdp_tcp_count_prog", mode)

if mode == BPF.XDP:
    b.attach_xdp(device, fn, flags)
else:
    ip = pyroute2.IPRoute()
    ipdb = pyroute2.IPDB(nl=ip)
    idx = ipdb.interfaces[device].index
    ip.tc("add", "clsact", idx)
    ip.tc("add-filter", "bpf", idx, ":1", fd=fn.fd, name=fn.name,
          parent="ffff:fff2", classid=1, direct_action=True)

flowcnt = b["flowcnt"]
#prev = [0] * 256
print("Printing SYN packets for ports 22, 80 and other, hit CTRL+C to stop")
while 1:
    try:
        #b.trace_print()
        #print dir(flowcnt)
        for k in flowcnt.keys():
            val = flowcnt.get(k).value
            i = k.value
            print("{}: {} syns".format(i, val))
#            if val:
#                delta = val - prev[i]
#                prev[i] = val
 #               print("{}: {} pkt/s".format(i, delta))
        time.sleep(1)
    except KeyboardInterrupt:
        print("Removing filter from device")
        break;

if mode == BPF.XDP:
    b.remove_xdp(device)
else:
    ip.tc("del", "clsact", idx)
    ipdb.release()
