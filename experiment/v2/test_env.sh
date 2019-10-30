#!/bin/bash

# modify according to your experiment

export ANY_NODE="Node5"
export ANY_NODE_IP="147.72.248.40"
#export ANY_NODE=OriginSDSC
#export ANY_NODE_IP="198.129.50.24"
export USER="root"
export SSH_OPTION="-i ~/.ssh/id_geni_ssh_rsa -o UserKnownHostsFile=~/.ssh/known_hosts2 -o StrictHostKeyChecking=no"
export OUTPUT_DIR=~/Documents/TmpData/test/test2
#export SSH_OPTION="-i ~/.ssh/id_geni_ssh_rsa_new -o UserKnownHostsFile=~/.ssh/known_hosts2 -o StrictHostKeyChecking=no"
#export OUTPUT_DIR=/root/results/v2big

# unlikely you will need to change follwing items
export IRIS_DIR=/root/iris
export TEMPLATE_DIR=${IRIS_DIR}/testdata/20190425T121649-0700
export START_RUN=1
export CORRUPT_NODES_FILE=${OUTPUT_DIR}/CORRUPT_NODES
export CORRUPT_EDGES_FILE=${OUTPUT_DIR}/CORRUPT_EDGES
export ALL_EDGES_FILE=${OUTPUT_DIR}/edges_all.sh
export ALL_NODES_FILE=${OUTPUT_DIR}/nodes_all
export END_NODES_FILE=${OUTPUT_DIR}/nodes_end
export SRC_NODES_FILE=${OUTPUT_DIR}/NODES_SRC
export DEST_NODES_FILE=${OUTPUT_DIR}/NODES_DEST
export PROB_FILE=${OUTPUT_DIR}/PROB_config

export NODE_ROUTER_FILE="node_router"
export RUN_LINKLABEL_FILE=run_label_autogen
export RETURN_HOSTNAME=""
export RETURN_IP=""
export SITE_DIR=/var/www/iris      #if you modify this 000-default.conf will need to be modified as well
export CJ_DIR=/root/chaos-jungle
export maxtransfer=6 # max transfers that can be triggered at the same time



