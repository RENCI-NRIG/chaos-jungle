#!/bin/bash


echo maxtransfer=$maxtransfer

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
    end_nodes_count=0
    while IFS= read line || [ -n "$line" ]
    do
        nodeip=$(echo $line | awk '{print $1;}'); #echo $nodeip
        node=$(echo $line | awk '{print $2;}')
        echo $node > $OUTPUT_DIR/${nodeip}_hostname
        END_NODES=${END_NODES}' '${nodeip}
        END_NODES_ARRAY[${end_nodes_count}]=${nodeip}
        end_nodes_count=$((end_nodes_count+1))
    done < ${END_NODES_FILE}
}

_get_src_nodes () {
    SRC_NODES=""
    while IFS= read line || [ -n "$line" ]
    do
        if [[ $line = \#* ]] ; then
          continue;
        fi
        nodeip=$(echo $line | awk '{print $1;}'); #echo $nodeip
        SRC_NODES=${SRC_NODES}' '${nodeip}
    done < ${SRC_NODES_FILE}
}

_get_dest_nodes () {
    DEST_NODES=""
    while IFS= read line || [ -n "$line" ]
    do
        if [[ $line = \#* ]] ; then
          continue;
        fi
        nodeip=$(echo $line | awk '{print $1;}'); #echo $nodeip
        DEST_NODES=${DEST_NODES}' '${nodeip}
    done < ${DEST_NODES_FILE}
}

_get_corrupt_nodes () {
    CORRUPT_NODES=""
    while IFS= read line || [ -n "$line" ]
    do
        if [[ $line = \#* ]] ; then
          continue;
        fi
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
        if [[ $line = \#* ]] ; then
          continue;
        fi
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
            break
        fi
    done < ${ALL_NODES_FILE}
}

_get_hostname () {
  x_ip=$1
  RETURN_HOSTNAME=$(head -n 1 $OUTPUT_DIR/${x_ip}_hostname)
  #echo "RETURN_HOSTNAME = $RETURN_HOSTNAME"
}

_get_virtualIP () {
    while IFS= read line || [ -n "$line" ]
    do
        edge=$(cut -d' ' -f2 <<< $line | cut -d= -f1)
        x_node=$(cut -d_ -f1 <<< $edge)
        if [ $x_node == $1 ]; then
            RETURN_IP=$(cut -d= -f2 <<< $line)
            break
        fi
    done < ${ALL_EDGES_FILE}
}

_get_hostname_by_virtualIP () {
    while IFS= read line || [ -n "$line" ]
    do
        x_ip=$(cut -d= -f2 <<< $line)
        if [ $x_ip == $1 ]; then
            RETURN_HOSTNAME=$(cut -d' ' -f2 <<< $line | cut -d_ -f1)
            break
        fi
    done < ${ALL_EDGES_FILE}
}

_get_storage_probablity () {
    STORAGE_PROB=1
    while IFS= read line || [ -n "$line" ]
    do
      x_ip=$(cut -d' ' -f1 <<< $line)
        if [ $x_ip == $1 ]; then
          P=$(cut -d' ' -f3 <<< $line)
          echo "P=$P"
          if [ ! -z $P ]; then
            STORAGE_PROB=$P
            echo "STORAGE_PROB=$STORAGE_PROB"
          fi
        break
      fi
    done < ${CORRUPT_NODES_FILE}
}

_get_network_probablity () {
    NETWORK_PROB=0.002
    while IFS= read line || [ -n "$line" ]
    do
      x_link=$(cut -d' ' -f2 <<< $line | cut -d= -f1)
        if [ $x_link == $1 ]; then
          P=$(cut -d' ' -f3 <<< $line)
          echo "P=$P"
          if [ ! -z $P ]; then
            NETWORK_PROB=$P
          fi
        break
      fi
    done < ${CORRUPT_EDGES_FILE}
    echo $NETWORK_PROB
    if [ $NETWORK_PROB != "0" ]; then
      NETWORK_PROB=$(echo "1 / $NETWORK_PROB" | bc)
    fi
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
  for d_nodeip in $DEST_NODES; do
      echo clean up dest node data in ${d_nodeip}
      ssh -n $SSH_OPTION ${USER}@${d_nodeip} sudo rm -rf ${IRIS_DIR}/*.*.*/* > /dev/null 2>&1 &
  done

  for s_node in $SRC_NODES; do
      echo create new $RUN_DIR in ${s_node}
      ssh -n $SSH_OPTION ${USER}@${s_node} "/root/src_create_data.sh ${RUN_DIR} > /dev/null 2>&1 &" &
  done
  isFirstTime=1
}

# transfer files from S->D by wget
_transfer_files () {
  #./transfer.py ${run}
  for x in $(seq 1 $((end_nodes_count-1))); do
      echo get from to ${x}_th neighbor
      for i in $(seq 0 $((end_nodes_count-1))); do
            j=$(expr $i + $x)
            j=$(expr $j % ${end_nodes_count})
            
            #if end_nodes[i] in src_nodes and end_nodes[j] in dest_nodes:
            d_nodeip=${END_NODES_ARRAY[$i]}
            s_nodeip=${END_NODES_ARRAY[$j]}

            _get_hostname $d_nodeip
            D_HOSTNAME=$RETURN_HOSTNAME
            _get_hostname $s_nodeip
            S_HOSTNAME=$RETURN_HOSTNAME
            _get_virtualIP $S_HOSTNAME
            S_IP=$RETURN_IP
            
            if [[ $DEST_NODES != *${d_nodeip}* ]]; then
              #echo "skip ${S_HOSTNAME}->${D_HOSTNAME}"
              continue
            fi

            if [[ $SRC_NODES != *${s_nodeip}* ]]; then
              #echo "skip ${S_HOSTNAME}->${D_HOSTNAME}"
              ssh -n $SSH_OPTION ${USER}@${d_nodeip} "touch /root/${run}_${x}_transfer_diff_done" # create dummy file on dest_node
              continue
            fi

            if [ $isFirstTime -eq "1" ]; then
              while true
              do 
                _OUTPUT=$(ssh -n $SSH_OPTION ${USER}@${s_nodeip} sudo ls /root/ | grep -i src_create_data_done)
                if [ ! -z "$_OUTPUT" ]; then
                  echo -e "\t\t${_OUTPUT}(${S_HOSTNAME})"  
                  break
                fi
                echo -n "."; sleep 0.5
              done
            else
              if [ $((($x - 1) % $maxtransfer)) -eq 0 ]; then
                prev_x=$((x - maxtransfer))
                while [ $prev_x -lt $x ]
                do 
                  _OUTPUT=$(ssh -n $SSH_OPTION ${USER}@${d_nodeip} sudo ls /root/ | grep -i ${run}_${prev_x}_transfer_diff_done)
                  if [ ! -z "$_OUTPUT" ]; then
                    echo -e "\t\t${_OUTPUT}(${D_HOSTNAME})"
                    prev_x=$(expr $prev_x + 1 )
                  else
                    echo -n "*"; sleep 0.5
                  fi
                done
              fi
            fi
            echo "run${run}: ${S_HOSTNAME}(${j}) -> ${D_HOSTNAME}(${i})"
            logfile=${D_HOSTNAME}_run${run}_wget_${S_HOSTNAME}.log
            DIFF_OUTPUT=${D_HOSTNAME}_run${run}_diff_${S_HOSTNAME}.log
            
            ssh -n $SSH_OPTION ${USER}@${d_nodeip} "/root/dest_transfer_diff.sh ${S_IP} ${run} ${logfile} ${DIFF_OUTPUT} ${x} > /dev/null 2>&1 &" &
      done
      isFirstTime=0
    done

  # last check
  for i in $(seq 0 $((end_nodes_count-1))); do
          d_nodeip=${END_NODES_ARRAY[$i]}
            _get_hostname $d_nodeip
            D_HOSTNAME=$RETURN_HOSTNAME

            if [[ $DEST_NODES != *${d_nodeip}* ]]; then
              echo "skip ${D_HOSTNAME}"
              continue
            fi
                prev_x=$((end_nodes_count-maxtransfer))
                if [ $prev_x -lt 1 ]; then 
                  prev_x=1
                fi
                while [ $prev_x -lt $end_nodes_count ]
                do 
                  _OUTPUT=$(ssh -n $SSH_OPTION ${USER}@${d_nodeip} sudo ls /root/ | grep -i ${run}_${prev_x}_transfer_diff_done)
                  if [ ! -z "$_OUTPUT" ]; then
                    echo -e "\t\t${_OUTPUT}(${D_HOSTNAME})"
                    prev_x=$(expr $prev_x + 1 )
                  else
                    echo -n "."; sleep 0.5
                  fi
                done
  done
  echo "run${run} done"
}

_get_log_files () {
  for d_nodeip in $DEST_NODES; do
      ssh -n $SSH_OPTION root@${d_nodeip} "rm ~/*diff_done"
      scp $SSH_OPTION root@${d_nodeip}:\*_wget_\*.log ${RESULT_DIR}
      scp $SSH_OPTION root@${d_nodeip}:\*_diff_\*.log ${RESULT_DIR}
      ssh -n $SSH_OPTION root@${d_nodeip} "rm ~/*_diff_*.log"
      ssh -n $SSH_OPTION root@${d_nodeip} "rm ~/*_wget_*.log"
  done
}

_delete_log_files () {
  for d_nodeip in $DEST_NODES; do
      ssh -n $SSH_OPTION root@${d_nodeip} "rm ~/*_transfer_diff_done"
      ssh -n $SSH_OPTION root@${d_nodeip} "rm ~/*_diff_*.log"
      ssh -n $SSH_OPTION root@${d_nodeip} "rm ~/*_wget_*.log"
  done
}

_get_end_nodes
_get_all_nodes
_get_all_edges
echo END_NODES = $END_NODES
echo ALL_NODES = $ALL_NODES
echo ALL_EDGES = $ALL_EDGES

