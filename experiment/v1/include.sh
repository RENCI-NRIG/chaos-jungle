#!/bin/bash

_get_all_nodes () {
    ALL_NODES=""
    while IFS= read line || [ -n "$line" ]
    do
        nodeip=$(echo $line | awk '{print $1;}'); #echo $nodeip
        ALL_NODES=${ALL_NODES}' '${nodeip}
    done < ${ALL_NODES_FILE}
}

_get_end_nodes () {
    END_NODES=""
    while IFS= read line || [ -n "$line" ]
    do
        nodeip=$(echo $line | awk '{print $1;}'); #echo $nodeip
        END_NODES=${END_NODES}' '${nodeip}
    done < ${END_NODES_FILE}
}

_get_src_nodes () {
    SRC_NODES=""
    while IFS= read line || [ -n "$line" ]
    do
        nodeip=$(echo $line | awk '{print $1;}'); #echo $nodeip
        SRC_NODES=${SRC_NODES}' '${nodeip}
    done < ${SRC_NODES_FILE}
}

_get_dest_nodes () {
    DEST_NODES=""
    while IFS= read line || [ -n "$line" ]
    do
        nodeip=$(echo $line | awk '{print $1;}'); #echo $nodeip
        DEST_NODES=${DEST_NODES}' '${nodeip}
    done < ${DEST_NODES_FILE}
}

_get_corrupt_nodes () {
    CORRUPT_NODES=""
    while IFS= read line || [ -n "$line" ]
    do
        nodeip=$(echo $line | awk '{print $1;}'); #echo $nodeip
        CORRUPT_NODES=${CORRUPT_NODES}' '${nodeip}
    done < ${CORRUPT_NODES_FILE}
}

_get_all_edges () {
    ALL_EDGES=""
    while IFS= read line || [ -n "$line" ]
    do
        edge=$(cut -d' ' -f2 <<< $line | cut -d= -f1)
        ALL_EDGES=${ALL_EDGES}' '${edge}
    done < ${ALL_EDGES_FILE}
}

_get_corrupt_edges () {
    CORRUPT_EDGES=""
    while IFS= read line || [ -n "$line" ]
    do
        edge=$(cut -d' ' -f2 <<< $line | cut -d= -f1)
        CORRUPT_EDGES=${CORRUPT_EDGES}' '${edge}
        #echo CORRUPT_EDGES ${CORRUPT_EDGES}
    done < ${CORRUPT_EDGES_FILE}
}

_get_ip () {
    while IFS= read line || [ -n "$line" ]
    do
        x_node=$(cut -d' ' -f2 <<< $line)
        if [ $x_node == $1 ]; then
            RETURN_IP=$(cut -d' ' -f1 <<< $line)
        fi
    done < ${ALL_NODES_FILE}
}

_get_hostname () {
    while IFS= read line || [ -n "$line" ]
    do
        x_ip=$(cut -d' ' -f1 <<< $line)
        if [ $x_ip == $1 ]; then
            RETURN_HOSTNAME=$(cut -d' ' -f2 <<< $line)
        fi
    done < ${ALL_NODES_FILE}    
}

_get_virtualIP () {
    while IFS= read line || [ -n "$line" ]
    do
        edge=$(cut -d' ' -f2 <<< $line | cut -d= -f1)
        x_node=$(cut -d_ -f1 <<< $edge)
        if [ $x_node == $1 ]; then
            RETURN_IP=$(cut -d= -f2 <<< $line)
        fi
    done < ${ALL_EDGES_FILE}
}

_get_hostname_by_virtualIP () {
    while IFS= read line || [ -n "$line" ]
    do
        x_ip=$(cut -d= -f2 <<< $line)
        if [ $x_ip == $1 ]; then
            RETURN_HOSTNAME=$(cut -d' ' -f2 <<< $line | cut -d_ -f1)
        fi
    done < ${ALL_EDGES_FILE}
}

_generate_node_router_file () {
  for file in $(ls $OUTPUT_DIR); do
    if [ -z "${file##*'_gw'*}" ]; then
      while IFS= read line || [ -n "$line" ]
      do
          node=$(cut -d: -f1 <<< $line)
          routerip=$(cut -d: -f2 <<< $line)
          if [ ! -z $routerip ]; then
            _get_hostname_by_virtualIP $routerip
            echo $node $RETURN_HOSTNAME >> ${OUTPUT_DIR}/${NODE_ROUTER_FILE}
          fi
      done < ${OUTPUT_DIR}/${file}
    fi
  done
  cat ${OUTPUT_DIR}/${NODE_ROUTER_FILE}
}

# create new run folder and data for S_NODES
_create_new_run_data () {
  echo create new $RUN_DIR in source nodes ...
  for s_node in $SRC_NODES; do
      ssh -n $SSH_OPTION ${USER}@${s_node} sudo rm -rf ${SITE_DIR}
      ssh -n $SSH_OPTION ${USER}@${s_node} sudo mkdir -p ${RUN_DIR}
      ssh -n $SSH_OPTION ${USER}@${s_node} sudo cp -r ${TEMPLATE_DIR} ${RUN_DIR}/
  done
}

# transfer files from S->D by wget
_transfer_files () {
  for d_nodeip in $DEST_NODES; do
      _get_hostname $d_nodeip
      D_HOSTNAME=$RETURN_HOSTNAME
      for s_nodeip in $SRC_NODES; do
          _get_hostname $s_nodeip
          S_HOSTNAME=$RETURN_HOSTNAME
          if [ $d_nodeip == $s_nodeip ]
          then
            continue
          fi
          echo transferring from $S_HOSTNAME to $D_HOSTNAME
          _get_virtualIP $S_HOSTNAME
          S_IP=$RETURN_IP

          ssh -n $SSH_OPTION ${USER}@${d_nodeip} sudo rm -rf ${IRIS_DIR}/${S_IP}/run${run}

          logfile=${RESULT_DIR}/${D_HOSTNAME}_run${run}_wget_${S_HOSTNAME}.log
          echo $logfile
          ssh -n $SSH_OPTION ${USER}@${d_nodeip} sudo wget -P ${IRIS_DIR} -r -m --no-parent -R "index.html*" http://${S_IP}/run${run}/ > $logfile 2>&1
          
          sleep 1
          DIFF_OUTPUT=${RESULT_DIR}/${D_HOSTNAME}_run${run}_diff_${S_HOSTNAME}.log
          if ssh -n $SSH_OPTION ${USER}@${d_nodeip} sudo diff -qr ${TEMPLATE_DIR} ${IRIS_DIR}/${S_IP}/run${run}/$(basename ${TEMPLATE_DIR}) > ${DIFF_OUTPUT} 2>&1
          then
            echo "no corruption"; #rm -v ${DIFF_OUTPUT}
          else 
            echo "there is corruption!"
          fi

          ssh -n $SSH_OPTION ${USER}@${d_nodeip} sudo rm -rf ${IRIS_DIR}/${S_IP}
      done
  done
}

_get_end_nodes
_get_all_nodes
_get_all_edges
echo END_NODES = $END_NODES
echo ALL_NODES = $ALL_NODES
echo ALL_EDGES = $ALL_EDGES

