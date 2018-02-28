# Linux Traffic Control (TC) with Netem

## Overview

The Linux netem tool provides Network Emulation functionality for injecting synthetic false traffic in wide area networks. The current version can emulate variable delay, loss, duplication and re-ordering, and more. 

Netem is controlled by the command line tool 'tc' (traffic control) which is part of the iproute2 package of tools. The tc command uses shared libraries and data files in the /usr/lib/tc directory. 

## Examples
The following command Adds synthetic delay of 100ms to eth0:

	tc qdisc add dev eth0 root netem delay 100ms
	
When the Netem module is enabled, it can be "changed" instead of "add".

For example, the following command adds synthetic packet loss to eth0:

	tc qdisc change dev eth0 root netem loss 0.1%
	
The following command adds 1% packet duplication:
	
	tc qdisc change dev eth0 root netem duplicate 1%
	
The following command adds 0.1 packet corruption:
	
	tc qdisc change dev eth0 root netem corrupt 0.1%
	
Newer versions of netem will also re-order packets if the random delay values are out of order. The following will cause some reordering: 

	tc qdisc change dev eth0 root netem delay 100ms 75ms
	
If the first packet gets a random delay of 100ms (100ms base - 0ms jitter) and the second packet is sent 1ms later and gets a delay of 50ms (100ms base - 50ms jitter); the second packet will be sent first. This is because the queue discipline tfifo inside netem, keeps packets in order by time to send. 	

## References

For more information, consult this document: https://wiki.linuxfoundation.org/networking/netem
