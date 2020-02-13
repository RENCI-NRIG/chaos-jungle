#!/bin/bash
set -u

source ./revert_corruption.sh

source ./test_env.sh
source $ALL_EDGES_FILE
source ./include.sh
_get_src_nodes
_get_dest_nodes
_get_corrupt_nodes
_get_corrupt_edges
_get_end_nodes
export DEST_NODES=${DEST_NODES}
export SRC_NODES=${SRC_NODES}
export END_NODES=${END_NODES}
echo ${END_NODES_ARRAY[*]}
echo $end_nodes_count

ssh $SSH_OPTION root@$ANY_NODE_IP "cd ${TEMPLATE_DIR}/.. && find $(basename ${TEMPLATE_DIR}) -type f" > ${OUTPUT_DIR}/allfiles

currenttime=$(date +"%Y%m%d_%H%M%p")
RESULT_DIR=${OUTPUT_DIR}/output_${currenttime}
mkdir $RESULT_DIR
cp ${OUTPUT_DIR}/${NODE_ROUTER_FILE} ${RESULT_DIR}/${NODE_ROUTER_FILE}
cp ${OUTPUT_DIR}/allfiles ${RESULT_DIR}/allfiles

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
  echo DEST_NODES: $DEST_NODES
  echo SRC_NODES: $SRC_NODES

_delete_log_files

echo $CORRUPT_NODES
for v_nodeip in $CORRUPT_NODES
do
  run=$((run+1))
  RUN_DIR=${SITE_DIR}/run${run}
  echo "### New Run" run${run}

  _get_hostname $v_nodeip
  v_node=$RETURN_HOSTNAME

  _create_new_run_data
  # corrupt data in node ; get the corruption log
  echo check whether src data is ready 
  while true
  do 
    _OUTPUT=$(ssh -n $SSH_OPTION ${USER}@${v_nodeip} sudo ls /root/ | grep -i src_create_data_done)
    if [ ! -z $_OUTPUT ]; then
      break
    fi
    echo -n "."
    sleep 1
  done

  echo "Corrupting" $v_node $v_nodeip; echo $v_nodeip > ${OUTPUT_DIR}/CORRUPTING_NODE

  _get_storage_probablity $v_nodeip
  ssh -n $SSH_OPTION ${USER}@${v_nodeip} sudo python3 $CJ_DIR/storage/cj_storage.py -d ${RUN_DIR} -f \"*\" -p $STORAGE_PROB -r --onetime
  scp $SSH_OPTION ${USER}@${v_nodeip}:/var/log/cj.log ${RESULT_DIR}/${v_node}_run${run}_cj.log

  _transfer_files

  ssh -n $SSH_OPTION ${USER}@${v_nodeip} sudo python3 $CJ_DIR/storage/cj_storage.py --revert
  ssh -n $SSH_OPTION ${USER}@${v_nodeip} sudo rm /var/log/cj.log

  rm ${OUTPUT_DIR}/CORRUPTING_NODE
  #_get_log_files
done

# corrupt network in CORRUPT_EDGES
echo $CORRUPT_EDGES
for link in $CORRUPT_EDGES
do
    run=$((run+1))
    RUN_DIR=${SITE_DIR}/run${run}
    
    _create_new_run_data

    node="$(cut -d'_' -f 1 <<< $link)"
    linkip=${!link}
    _get_ip ${node}
    nodeip=$RETURN_IP

    ssh -n $SSH_OPTION ${USER}@${nodeip} ifconfig | grep $linkip
    LINE=$(ssh -n $SSH_OPTION ${USER}@${nodeip} ifconfig | grep $linkip -n | awk -F ':' '{print $1}')
    LINE=$((LINE-1))
    interface=$(ssh -n $SSH_OPTION ${USER}@${nodeip} ifconfig | awk NR==${LINE} | awk -F ':' '{print $1}')

    # corrupt the LINK(E_EDGE) by sudo ./xdp_flow_modify.py eno1 -f src=129.114.109.33
    _get_network_probablity $link
    echo "NETWORK_PROB=$NETWORK_PROB"
    if [ $NETWORK_PROB != "0" ]; then
      echo "run$run $link" >> ${RESULT_DIR}/${RUN_LINKLABEL_FILE}
      ssh -n $SSH_OPTION ${USER}@${nodeip} sudo $CJ_DIR/bpf/bcc/xdp_flow_modify.py -i $NETWORK_PROB -t ${interface} > /dev/null 2>&1 &
      sleep 2
      echo "corrupting" $link $interface ${linkip}; echo $link > ${OUTPUT_DIR}/CORRUPTING_EDGE
      echo "cj network corruption starting"
      ssh -n $SSH_OPTION ${USER}@${nodeip} ps ax | grep xdp_flow | grep -v sudo | grep -v grep
    fi

    _transfer_files

    # kill the cj network corrupter process
    if [ $NETWORK_PROB != "0" ]; then
      echo stopping corruption on $interface ${linkip}
      ssh -n $SSH_OPTION ${USER}@${nodeip} sudo $CJ_DIR/bpf/bcc/xdp_flow_modify.py --stoptc ${interface}
      sleep 2
      ssh -n $SSH_OPTION ${USER}@${nodeip} sudo pkill -u root -f xdp_flow_modify
      echo "cj network corruption stopped"
      rm ${OUTPUT_DIR}/CORRUPTING_EDGE
    fi
    #_get_log_files
done

_get_log_files
./parse_logs.py $RESULT_DIR

cat ${CORRUPT_NODES_FILE} ${CORRUPT_EDGES_FILE} > ${RESULT_DIR}/$(basename ${RESULT_DIR}).txt
