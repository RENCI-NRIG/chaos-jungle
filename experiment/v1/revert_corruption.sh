set -u

source ./test_env.sh
source $ALL_EDGES_FILE
source ./include.sh

if [ -f ${OUTPUT_DIR}/CORRUPTING_NODE ]; then
  v_nodeip=$(cat ${OUTPUT_DIR}/CORRUPTING_NODE)
  echo reverting $v_nodeip
  _get_hostname $v_nodeip
  v_node=$RETURN_HOSTNAME
  ssh -n $SSH_OPTION ${USER}@${v_nodeip} sudo python3 $CJ_DIR/storage/cj_storage.py --revert
  ssh -n $SSH_OPTION ${USER}@${v_nodeip} sudo rm /var/log/cj.log
  rm ${OUTPUT_DIR}/CORRUPTING_NODE
fi

if [ -f ${OUTPUT_DIR}/CORRUPTING_EDGE ]; then
    link=$(cat ${OUTPUT_DIR}/CORRUPTING_EDGE)
    echo reverting $link
    node="$(cut -d'_' -f 1 <<< $link)"
    linkip=${!link}
    _get_ip ${node}
    nodeip=$RETURN_IP

    ssh -n $SSH_OPTION ${USER}@${nodeip} ifconfig | grep $linkip
    LINE=$(ssh -n $SSH_OPTION ${USER}@${nodeip} ifconfig | grep $linkip -n | awk -F ':' '{print $1}')
    LINE=$((LINE-1))
    interface=$(ssh -n $SSH_OPTION ${USER}@${nodeip} ifconfig | awk NR==${LINE} | awk -F ':' '{print $1}')
    
    # kill the cj network corrupter process
    echo stopping corruption on $interface ${linkip}
    ssh -n $SSH_OPTION ${USER}@${nodeip} sudo $CJ_DIR/bpf/bcc/xdp_flow_modify.py --stoptc ${interface}
    sleep 2
    ssh -n $SSH_OPTION ${USER}@${nodeip} sudo pkill -u root -f xdp_flow_modify
    echo "cj network corruption stopped"
    rm ${OUTPUT_DIR}/CORRUPTING_EDGE
fi

