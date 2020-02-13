#!/bin/bash
set -u

source ./test_env.sh
source $ALL_EDGES_FILE
source ./include.sh

echo reset folders in END_NODES
for nodeip in $END_NODES; do
    SSH_DEST=${USER}@${nodeip}
    echo $SSH_DEST
    ssh $SSH_OPTION $SSH_DEST sudo rm -rf $IRIS_DIR
    ssh $SSH_OPTION $SSH_DEST sudo mkdir -p $IRIS_DIR
    ssh $SSH_OPTION $SSH_DEST sudo cp -r /root/chaos-jungle/experiment/testdata $IRIS_DIR
    ssh $SSH_OPTION $SSH_DEST sudo rm -rf $SITE_DIR
    ssh $SSH_OPTION $SSH_DEST sudo mkdir -p $SITE_DIR
    #ssh $SSH_OPTION $SSH_DEST sudo rm -rf ${IRIS_DIR}/*.*.*.*
done
