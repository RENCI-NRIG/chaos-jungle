#!/bin/bash

# modify according to your experiment

#export ANY_NODE="Node5"
#export ANY_NODE_IP="141.217.114.192"
#export SUBNET="141.217.0.0/24" 
export ANY_NODE="OriginUNL"
export ANY_NODE_IP="147.72.248.42"
export SUBNET="147.72.0.0/24" 

export USER="ericafu"
export SSH_OPTION="-i ~/.ssh/id_geni_ssh_rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
export CONTROL_NODE="152.54.9.101" # to allow in firewall and test apache from control machine
export OUTPUT_DIR=~/Downloads/big/
export LOCAL_INPUT_DIR=/Users/ericafu/Documents/TmpData/20190425T121649-0700

# modify the corruption parts, each run will corrupt 1 item based on following 2 files
export CORRUPT_NODES_FILE="${OUTPUT_DIR}CORRUPT_NODES"
export CORRUPT_EDGES_FILE="${OUTPUT_DIR}CORRUPT_EDGES"

# unlikely you will need to change follwing items
export ALL_EDGES_FILE="${OUTPUT_DIR}edges_all.sh"
export ALL_NODES_FILE="${OUTPUT_DIR}nodes_all"
export END_NODES_FILE="${OUTPUT_DIR}nodes_end"
export SRC_NODES_FILE="${OUTPUT_DIR}NODES_SRC"
export DEST_NODES_FILE="${OUTPUT_DIR}NODES_DEST"
export NODE_ROUTER_FILE="node_router.txt"
export RUN_LINKLABEL_FILE=run_label_autogen.txt
export RETURN_HOSTNAME=""
export RETURN_IP=""

export START_RUN=1
export SITE_DIR=/var/www/iris      #if you modify this 000-default.conf will need to be modified as well
export CJ_DIR=/home/${USER}/chaos-jungle
export IRIS_DIR=/home/${USER}/iris    
export TEMPLATE_DIR=${IRIS_DIR}/template




