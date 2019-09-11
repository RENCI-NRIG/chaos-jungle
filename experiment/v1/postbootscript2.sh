#!/bin/bash

echo "Installing CJ and apache2" >> /root/tmp

cd /root
git clone --branch storage https://github.com/RENCI-NRIG/chaos-jungle.git

date >> /root/tmp
until apt-get -y install apache2
do
        echo "installing apache2" >> /root/tmp
        sleep 2
done
date >> /root/tmp

mkdir -p /root/iris
cp -r /root/chaos-jungle/experiment/testdata /root/iris
cp chaos-jungle/experiment/v1/000-default.conf /etc/apache2/sites-available
mkdir -p /var/www/iris
service apache2 reload

apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 4052245BD4284CDD
echo "deb https://repo.iovisor.org/apt/$(lsb_release -cs) $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/iovisor.list
apt-get -y update
apt-get -y install bcc-tools libbcc-examples linux-headers-$(uname -r)
apt-get -y install python3-bcc
apt-get -y install python3-pyroute2 python-pyroute2 iperf3

apt install -y python3-pip python3-setuptools
pip3 install python-crontab  

date >> /root/tmp
python3 /root/chaos-jungle/storage/cj_storage.py --revert >> /root/tmp

echo "done" >> /root/tmp


        
        
        
        
