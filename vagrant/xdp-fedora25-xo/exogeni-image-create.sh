#/bin/bash -x

dnf -y update

#dnf -y install yum-utils epel-release
#package-cleanup --oldkernels --count=1

dnf install -y python python-devel python-boto python-daemon python-ipaddr python-netaddr
dnf install -y wget vim git
dnf install -y dracut-config-generic net-tools cloud-init cloud-utils-growpart acpid
dnf install -y iscsi-initiator-utils iscsi-initiator-utils-iscsiuio

sed -i s/"disable_root: 1"/"disable_root: 0"/g /etc/cloud/cloud.cfg
sed -i s/SELINUX=enforcing/SELINUX=disabled/g /etc/selinux/config
sed -r -i 's/^#*(PermitRootLogin).*/\1 without-password/g' /etc/ssh/sshd_config
cat << EOF >> /etc/hosts.deny
rpcbind: ALL EXCEPT 172.16.0.0/255.240.0.0 10.0.0.0/255.0.0.0 192.168.0.0/255.255.0.0
EOF

FEDORA=`cat /etc/fedora-release | grep -oE '[0-9]+'`
cat << EOF > /etc/motd
########################################################
#         ExoGENI VM Instance - Fedora ${FEDORA}             #
#                                                      #
# /etc/hosts.deny file is customized for rpcbind.      #
# If you are using rpcbind daemon, please              #
# check /etc/hosts.deny for connectivity on dataplane. #
#                                                      #
# More information about security:                     #
# www.exogeni.net/2016/10/securing-your-slice-part-1/  #
########################################################
EOF

cat << EOF > /etc/resolv.conf
nameserver 8.8.8.8
EOF

cat << EOF > /etc/sysconfig/network
NETWORKING=yes
NOZEROCONF=yes
EOF


cat << EOF > /etc/default/grub
GRUB_TIMEOUT=1
GRUB_DISTRIBUTOR="$(sed 's, release .*$,,g' /etc/system-release)"
GRUB_DEFAULT=saved
GRUB_DISABLE_SUBMENU=true
GRUB_TERMINAL="serial console"
GRUB_SERIAL_COMMAND="serial --speed=115200"
GRUB_CMDLINE_LINUX=" vconsole.keymap=us console=tty0 vconsole.font=latarcyrheb-sun16 console=ttyS0,115200"
GRUB_DISABLE_RECOVERY="true"
EOF


###cat << EOF > /usr/lib/dracut/dracut.conf.d/02-generic-image.conf
###hostonly="no"
###EOF


git clone https://github.com/RENCI-NRIG/neuca-guest-tools.git
cd ./neuca-guest-tools/neuca-py
python setup.py install
cp neucad.service /usr/lib/systemd/system/neucad.service
ln -s /usr/lib/systemd/system/neucad.service /etc/systemd/system/multi-user.target.wants/neucad.service
systemctl enable neucad

systemctl enable iscsid

#systemctl stop firewalld
#systemctl disable firewalld


IMG_NAME="fedora25-v1.0.3"
IMG_URL="http://geni-images.renci.org/images/standard/fedora/${IMG_NAME}"
DEST="/mnt/target"
SIZE="8G"

if [ ! -d ${DEST} ]; then
   mkdir -p ${DEST}
fi

cd /tmp
wget  http://geni-images.renci.org/images/tools/imgcapture.sh
chmod +x imgcapture.sh
./imgcapture.sh -o -n ${IMG_NAME} -s ${SIZE} -u ${IMG_URL} -d ${DEST}

cd ${DEST}

# Re-create initramfs with hostonly=no option in /usr/lib/dracut/dracut.conf.d/02-generic-image.conf
rm -f initramfs*.img
dracut -f ${DEST}/initramfs-$(uname -r).img $(uname -r)

chmod 644 *.tgz *.xml *.img

echo Please recompute initramfs checksum as it has been rebuilt...
