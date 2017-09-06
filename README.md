# chaos-jungle

## Overview

Chaos Jungle is a set of mechanisms for introducing disruptions into the work of distributed computational workflows. Those include deliberately degrading the performance of various components of the workflow infrastructure and introducing errors into data transfers during workflow execution.

## Directory structure

- vagrant/ contains various Vagrant configurations for working with XDP
- vagrant/xdp-fedora25 - based on Fedora 25 and kernel 4.13
- bpf/bcc contains the BCC flow modification code code

## Flow Modification

Flow modification is performed by inserting BPF programs into kernel at either XDP or TC classifier hooks to manipulate TCP and UDP payloads without affecting respective checksums. The manipulation is achieved by swapping 16-bit aligned values within the segment/payload.

The program can be instructed to keep track of up to 5 different flowspecs (limited to src/dst addresses and port numbers and a protocol discriminator - TCP/UDP). Within each flow matching a given flowspec it will attempt to modify I-th packet in the flow. A modification may fail if one or both swap indices fall outside the payload boundary. 

By default the program attempts to use the XDP hook, however this has limited compatibility, requiring an XDP-compatible driver, like e1000. This option provides the highest performance. For wider compatibility use the TC classifier hook. BPF with TC and XDP kernel support is required. This code was tested on Fedora 25 with kernel 4.13.0-0.rc5.git0.2.fc27.x86_64. The vagrant directory contains the appropriate configuration. 

## Examples of operation

$ sudo ./xdp_flow_modify.py -f src=hostname.uni.edu,sport=80 --s1 10 --s2 20 -i 10 enp0s3

Modify each 10th packet in a flow from hostname.uni.edu:80 by swapping 10th and 20th u16s (aligned). The program attaches to interface enp0s3 and uses XDP. Use -t to use TC classifier BPF hook rather than XDP. 

By default the program prints out counts of modified packets for each flowspec. Flowspecs can be added to invocation by adding -f or --flow options followed by flowspec. 

## Full usage details
```
usage: xdp_flow_modify.py [-h] [-f FLOW] [-t] [-e] [-i INDEX] [--s1 S1]
                          [--s2 S2] [-q]
                          interface

positional arguments:
  interface             interface to bind program to

optional arguments:
  -h, --help            show this help message and exit
  -f FLOW, --flow FLOW  flow specifier
  -t, --tc              Use TC ingress hook instead of XDP (wider
                        compatibility, but lower performance)
  -e, --emulate         Count packet modify events without doing anything to
                        them
  -i INDEX, --index INDEX
                        Modify every i-th packet in each flow
  --s1 S1               u16 index to swap in payload
  --s2 S2               u16 index to swap in payload
  -q, --quiet           Be quiet

Each FLOW can be specified as src=a.b.c.d,dst=m.n.o.p,sport=X,dport=Y Any of
the flow parameters can be omitted and specified in any order. No spaces are
allowed. Up to 5 flowspecs are allowed. The program does NOT do most-specific
flow matching. Instead the first match always wins, others are not examined.
Packet modification may fail if modify indices fall outside the segment
length, in which case the program will attempt to modify the current + INDEX
packet. The count of packets actually modified is displayed for every flow
spec.
```

## References

For kernel compatibility, consult this document: https://github.com/iovisor/bcc/blob/master/docs/kernel-versions.md
