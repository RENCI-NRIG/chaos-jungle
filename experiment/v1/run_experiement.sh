#!/bin/bash
set -ux

source ./test_env.sh
source $ALL_EDGES_FILE
source ./include.sh
_get_src_nodes
_get_dest_nodes
_get_corrupt_nodes
_get_corrupt_edges

#rm -rf $RESULT_DIR; mkdir $RESULT_DIR
currenttime=$(date +"%Y%m%d_%H%M%p")
RESULT_DIR=${OUTPUT_DIR}output_${currenttime}
mkdir $RESULT_DIR
cp ${OUTPUT_DIR}${NODE_ROUTER_FILE} ${RESULT_DIR}/${NODE_ROUTER_FILE}


run=$((START_RUN-1))
if [ $run == 0 ]
then
  if [ -f ${RESULT_DIR}/${RUN_LINKLABEL_FILE} ]; then 
    rm ${RESULT_DIR}/${RUN_LINKLABEL_FILE}
  fi
  touch ${RESULT_DIR}/${RUN_LINKLABEL_FILE}
fi

##### experiment starts ######
# corrupt storage in CORRUPT_NODES
echo $CORRUPT_NODES
for v_nodeip in $CORRUPT_NODES
do
  run=$((run+1))
  RUN_DIR=${SITE_DIR}/run${run}

  _get_hostname $v_nodeip
  v_node=$RETURN_HOSTNAME

  _create_new_run_data
  # corrupt data in node ; get the corruption log
  ssh -n $SSH_OPTION ${USER}@${v_nodeip} sudo python3 $CJ_DIR/storage/cj_storage.py -d $RUN_DIR -f \"*\" -r --onetime
  scp $SSH_OPTION ${USER}@${v_nodeip}:/var/log/cj.log ${RESULT_DIR}/${v_node}_run${run}_cj.log

  _transfer_files
  ssh -n $SSH_OPTION ${USER}@${v_nodeip} sudo python3 $CJ_DIR/storage/cj_storage.py --revert
  ssh -n $SSH_OPTION ${USER}@${v_nodeip} sudo rm /var/log/cj.log
done

# corrupt network in CORRUPT_EDGES
echo $CORRUPT_EDGES
for link in $CORRUPT_EDGES
do
    run=$((run+1))
    RUN_DIR=${SITE_DIR}/run${run}
    echo "run$run $link" >> ${RESULT_DIR}/${RUN_LINKLABEL_FILE}

    _create_new_run_data

    node="$(cut -d'_' -f 1 <<< $link)"
    linkip=${!link}
    _get_ip ${node}
    nodeip=$RETURN_IP

    ssh -n $SSH_OPTION ${USER}@${nodeip} 'ifconfig | grep $linkip'
    LINE=$(ssh -n $SSH_OPTION ${USER}@${nodeip} ifconfig | grep ${linkip} -n | awk -F ':' '{print $1}')
    LINE=$((LINE-1))
    interface=$(ssh -n $SSH_OPTION ${USER}@${nodeip} ifconfig | awk NR==${LINE} | awk -F ':' '{print $1}')

    # corrupt the LINK(E_EDGE) by sudo ./xdp_flow_modify.py eno1 -f src=129.114.109.33
    ssh -n $SSH_OPTION ${USER}@${nodeip} sudo $CJ_DIR/bpf/bcc/xdp_flow_modify.py -i 500 -t ${interface} > /dev/null 2>&1 &
    ssh -n $SSH_OPTION ${USER}@${nodeip} 'sudo ps ax | grep xdp_flow | grep -v sudo | grep -v grep'

    _transfer_files

    # kill the cj network corrupter process
    ssh -n $SSH_OPTION ${USER}@${nodeip} sudo pkill -u root -f xdp_flow_modify
    ssh -n $SSH_OPTION ${USER}@${nodeip} 'sudo ps ax | grep xdp_flow | grep -v sudo | grep -v grep'
    ssh -n $SSH_OPTION ${USER}@${nodeip} sudo $CJ_DIR/bpf/bcc/xdp_flow_modify.py --stoptc ${interface}
done


./parse_logs.py $RESULT_DIR
