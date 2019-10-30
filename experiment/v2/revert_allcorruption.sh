#!/bin/bash
set -u

source ./test_env.sh
source $ALL_EDGES_FILE
source ./include.sh

# clear/reset all corruption in case previous script didn't finish completely 
for nodeip in $ALL_NODES; do
    ssh -n $SSH_OPTION ${USER}@${nodeip} sudo python3 $CJ_DIR/storage/cj_storage.py --revert
    ssh -n $SSH_OPTION ${USER}@${nodeip} sudo rm /var/log/cj.log
done

for link in $ALL_EDGES
do
    node="$(cut -d'_' -f 1 <<< $link)"
    linkip=${!link}
    _get_ip ${node}
    nodeip=$RETURN_IP # _get_ip() will set RETURN_IP
    LINE=$(ssh -n $SSH_OPTION ${USER}@${nodeip} ifconfig | grep ${linkip} -n | awk -F ':' '{print $1}')
    LINE=$((LINE-1))
    interface=$(ssh -n $SSH_OPTION ${USER}@${nodeip} ifconfig | awk NR==${LINE} | awk -F ':' '{print $1}')
    ssh -n $SSH_OPTION ${USER}@${nodeip} sudo pkill -u root -f xdp_flow_modify
    ssh -n $SSH_OPTION ${USER}@${nodeip} sudo $CJ_DIR/bpf/bcc/xdp_flow_modify.py --stoptc ${interface} > /dev/null 2>&1 &
done