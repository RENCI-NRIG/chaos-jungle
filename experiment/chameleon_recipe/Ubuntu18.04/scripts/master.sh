#!/bin/bash

# this script should run as root

if [[ "$USER" != "root" ]]; then
  echo "script must run as root"
  exit 1
fi

set -eux

sudo apt-get -y update
sudo apt-get install -y gcc g++ make libarchive-dev

if [ ! -d ./chaos-jungle ]; then
  git clone --branch storage https://github.com/RENCI-NRIG/chaos-jungle.git
fi

############################################
### INSTALL BCC for CJ Network XDP usage ###
############################################
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 4052245BD4284CDD
echo "deb https://repo.iovisor.org/apt/$(lsb_release -cs) $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/iovisor.list
sudo apt-get -y update
sudo apt-get -y install bcc-tools libbcc-examples linux-headers-$(uname -r)
sudo apt-get -y install python3-bcc python3-pyroute2 python-pyroute2 iperf3

###########################
### INSTALL python-crontab for CJ Storage ###
###########################
sudo apt install -y python3-pip python3-setuptools
pip3 install python-crontab



######################
### EDIT /etc/hosts ##
######################

cat << EOF >> /etc/hosts
127.0.0.1 master
EOF

######################
### INSTALL CONDOR ###
######################
wget -qO - https://research.cs.wisc.edu/htcondor/ubuntu/HTCondor-Release.gpg.key | sudo apt-key add -
echo "deb http://research.cs.wisc.edu/htcondor/ubuntu/8.8/bionic bionic contrib" >> /etc/apt/sources.list
echo "deb-src http://research.cs.wisc.edu/htcondor/ubuntu/8.8/bionic bionic contrib" >> /etc/apt/sources.list
sudo apt-get -y update
sudo apt-get install -y condor

cat << EOF > /etc/condor/config.d/50-main.config
DAEMON_LIST = MASTER, COLLECTOR, NEGOTIATOR, SCHEDD

CONDOR_HOST = master

USE_SHARED_PORT = TRUE

NETWORK_INTERFACE = 192.168.100.*

# the nodes have shared filesystem
UID_DOMAIN = \$(CONDOR_HOST)
TRUST_UID_DOMAIN = TRUE
FILESYSTEM_DOMAIN = \$(FULL_HOSTNAME)

# Schedd and Negotiator run more often
NEGOTIATOR_INTERVAL=45
NEGOTIATOR_UPDATE_AFTER_CYCLE= TRUE

#--     Authentication settings
SEC_PASSWORD_FILE = /etc/condor/pool_password
SEC_DEFAULT_AUTHENTICATION = REQUIRED
SEC_DEFAULT_AUTHENTICATION_METHODS = FS,PASSWORD
SEC_READ_AUTHENTICATION = OPTIONAL
SEC_CLIENT_AUTHENTICATION = OPTIONAL
SEC_ENABLE_MATCH_PASSWORD_AUTHENTICATION = TRUE
DENY_WRITE = anonymous@*
DENY_ADMINISTRATOR = anonymous@*
DENY_DAEMON = anonymous@*
DENY_NEGOTIATOR = anonymous@*
DENY_CLIENT = anonymous@*

#--     Privacy settings
SEC_DEFAULT_ENCRYPTION = OPTIONAL
SEC_DEFAULT_INTEGRITY = REQUIRED
SEC_READ_INTEGRITY = OPTIONAL
SEC_CLIENT_INTEGRITY = OPTIONAL
SEC_READ_ENCRYPTION = OPTIONAL
SEC_CLIENT_ENCRYPTION = OPTIONAL

#-- With strong security, do not use IP based controls
HOSTALLOW_WRITE = *
ALLOW_NEGOTIATOR = *

EOF

condor_store_cred -f /etc/condor/pool_password -p c454_c0nd0r_p00l

systemctl enable condor
systemctl restart condor

#######################
### INSTALL PEGASUS ###
#######################

wget -O - https://download.pegasus.isi.edu/pegasus/gpg.txt | apt-key add -
echo 'deb https://download.pegasus.isi.edu/pegasus/ubuntu zesty main' >/etc/apt/sources.list.d/pegasus.list
apt-get -y update
apt-get -y install pegasus

##########################
### INSTALL SINGULARITY ##
##########################

SINGULARITY_VERSION=2.6.0
parent_dir=`pwd`
wget https://github.com/sylabs/singularity/releases/download/${SINGULARITY_VERSION}/singularity-${SINGULARITY_VERSION}.tar.gz
tar xvf singularity-${SINGULARITY_VERSION}.tar.gz
cd singularity-${SINGULARITY_VERSION}
./configure --prefix=/usr/local
make && make install
cd $parent_dir
rm -r singularity-${SINGULARITY_VERSION}
rm singularity-${SINGULARITY_VERSION}.tar.gz

##########################
### INSTALL DOCKER      ##
##########################
sudo apt-get -y install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo apt-key fingerprint 0EBFCD88
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
sudo apt-get -y install docker-ce docker-ce-cli containerd.io

if [ $(getent group docker) ]; then
  echo "group docker exists."
else
  groupadd docker
fi
usermod -aG docker condor

systemctl enable docker
systemctl restart docker

##############################################
### SETUP NFS ACCESS AND INSTALL CONTAINERS ##
##############################################
#yum install -y nfs-utils
#mkdir -p /nfs/shared
#echo "storage:/nfs/shared  /nfs/shared   nfs      rw,sync,hard,intr  0     0" >> /etc/fstab
#mount -a

#docker pull papajim/casa-app
#docker save -o /nfs/shared/casacontainer.tar papajim/casa-app
#chmod 644 /nfs/shared/casacontainer.tar
#docker rmi papajim/casa-app

#docker pull casaelyons/nowcastcontainer
#docker save -o /nfs/shared/nowcastcontainer.tar casaelyons/nowcastcontainer
#chmod 644 /nfs/shared/nowcastcontainer.tar
#docker rmi casaelyons/nowcastcontainer

#######################
### SETUP LDM USER ####
#######################

groupadd casa
useradd -c "" -d /home/ldm -G casa,docker -m -s /bin/bash ldm


