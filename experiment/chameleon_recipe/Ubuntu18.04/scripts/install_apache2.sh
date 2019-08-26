#!/bin/bash

# this script should run as root

if [[ "$USER" != "root" ]]; then
  echo "script must run as root"
  exit 1
fi

apt-get -y install apache2
cp -f ./apache2_ports.conf /etc/apache2/ports.conf # set port to 8080
service apache2 reload

ufw allow ssh
ufw allow from 192.168.100.0/24
ufw allow from 152.54.9.101
ufw enable