#!/bin/bash

# this script should run as root

if [[ "$USER" != "root" ]]; then
  echo "script must run as root"
  exit 1
fi

set -eux

sudo apt-get -y update
sudo apt-get install -y gcc g++ make libarchive-dev

if [ -d ./chaos-jungle ]; then
  rm -rf ./chaos-jungle
fi

git clone --branch storage https://github.com/RENCI-NRIG/chaos-jungle.git

############################################
### INSTALL BCC for CJ Network XDP usage ###
############################################
#version=$(hostnamectl | grep Ubuntu | awk '{print $NF}')
#if [[ "$version" == "19.04" ]]; then
#sudo apt-get install bpfcc-tools linux-headers-$(uname -r)
#fi
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 4052245BD4284CDD
echo "deb https://repo.iovisor.org/apt/$(lsb_release -cs) $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/iovisor.list
sudo apt-get -y update
sudo apt-get -y install bcc-tools libbcc-examples linux-headers-$(uname -r)
sudo apt-get -y install python3-bcc

#sudo apt-get install bpfcc-tools linux-headers-$(uname -r)
sudo apt-get -y install python3-pyroute2 python-pyroute2 iperf3

###########################
### INSTALL python-crontab for CJ Storage, the parse_logs.py require Python 3.6 ###
###########################
pythonversion=$(python3 --version | awk '{print $NF}')
if [[ $pythonversion =~ "3.5" ]]
then
  sudo add-apt-repository -y ppa:deadsnakes/ppa
  sudo apt-get -y update
  sudo apt-get -y install python3.7
  sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.7 0
  sudo update-alternatives --config python3
  sudo apt install -y libpython3-dev libpython3.7-dev python3-dev python3-wheel python3.7-dev python3-gdbm 
fi
sudo apt install -y python3-pip python3-setuptools
sudo pip3 install python-crontab  
 

