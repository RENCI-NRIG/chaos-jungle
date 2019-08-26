#!/bin/bash

# edit the squid.conf before running this script:
# - modify cache_peer to the IP address of real web server:
#    cache_peer 127.0.0.1 parent 8080 0 no-query originserver name=myAccel
# - modify local network setting:
#    acl our_networks src 192.168.50.0/24
# - enlarge cache maximum size if neede
#    cache_dir ufs /var/spool/squid3 1024 16 256 


# this script should run as root
if [[ "$USER" != "root" ]]; then
  echo "script must run as root"
  exit 1
fi

set -eux

apt-get -y install squid
cp ./squid.conf /etc/squid/squid.conf
/etc/init.d/squid3 start
