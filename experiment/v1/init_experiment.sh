#!/bin/bash

set -u

source ./test_env.sh

## copy /etc/hosts to local and get the all nodes to .tmp/allnodes
rm -rf $OUTPUT_DIR; mkdir $OUTPUT_DIR
scp $SSH_OPTION root@$ANY_NODE_IP:/etc/hosts $OUTPUT_DIR
sed -i "" "/$ANY_NODE/ s/.*/$ANY_NODE_IP    $ANY_NODE/g" "${OUTPUT_DIR}hosts"
NeucaItems='n'
while IFS= read -r line
do
    begin=$(cut -d' ' -f 1 <<< $line)
    #begin=$(echo $line | awk '{print $1;}')
    if [ "$NeucaItems" == "n" ] && [ "$begin" == "###" ]; then
      NeucaItems='y'
    fi
    if [ "$NeucaItems" == "y" ] && [ "$begin" != "###" ] && [ "$line" != "" ] && [ -z "${line##*'.'*}" ]; then
        echo $line >> $ALL_NODES_FILE
    fi
done < "${OUTPUT_DIR}hosts"

## get the interfaces and gw information from all nodes
while IFS= read -r line; do
    nodeip=$(echo $line | awk '{print $1;}'); #echo $nodeip
    node=$(echo $line | awk '{print $2;}'); #echo $node
    scp $SSH_OPTION root@${nodeip}:/root/tmp_links.sh ${OUTPUT_DIR}${node}_links.sh
    scp $SSH_OPTION root@${nodeip}:/root/tmp_gw ${OUTPUT_DIR}${node}_gw
    if [ -f "${OUTPUT_DIR}${node}_gw" ]; then 
        echo $node is end node
        echo $line >> $END_NODES_FILE
    fi
    cat ${OUTPUT_DIR}${node}_links.sh >> $ALL_EDGES_FILE
done < $ALL_NODES_FILE

cp $END_NODES_FILE $SRC_NODES_FILE
cp $END_NODES_FILE $DEST_NODES_FILE
cp $END_NODES_FILE $CORRUPT_NODES_FILE
cp $ALL_EDGES_FILE $CORRUPT_EDGES_FILE

source ./include.sh
_generate_node_router_file # generate node_router.txt

set -ue
# Setup for All nodes
for nodeip in $ALL_NODES; do
    # Install cj on all nodes
    SSH_DEST=${USER}@${nodeip}
    echo $SSH_DEST
    scp $SSH_OPTION ./install_cj.sh $SSH_DEST:/home/$USER
    ssh $SSH_OPTION $SSH_DEST sudo /home/$USER/install_cj.sh
    # Copy original data to nodes
    ssh $SSH_OPTION $SSH_DEST mkdir -p $TEMPLATE_DIR
    scp $SSH_OPTION -r $LOCAL_INPUT_DIR $SSH_DEST:$TEMPLATE_DIR
done

# Install apache2 web server on END_NODES
for nodeip in $END_NODES; do
    SSH_DEST=${USER}@${nodeip}
    echo $SSH_DEST
    ssh $SSH_OPTION $SSH_DEST sudo apt-get -y install apache2
    scp $SSH_OPTION ./000-default.conf $SSH_DEST:/home/$USER
    ssh $SSH_OPTION $SSH_DEST << EOF
        sudo cp /home/$USER/000-default.conf /etc/apache2/sites-available
        sudo rm -f /home/$USER/000-default.conf
        sudo mkdir -p /var/www/iris
        sudo service apache2 reload
        sudo ufw allow from $SUBNET
        sudo ufw allow from $CONTROL_NODE
EOF
done


