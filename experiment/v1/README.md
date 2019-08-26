# IRIS Experiment

### [Before Starting]
Before starting experiments, configuration needs to be modified first.

#### 0. Download the Chaos Jungle experiment scripts
```
$ git clone --branch storage https://github.com/RENCI-NRIG/chaos-jungle.git
$ cd chaos-jungle/experiment/v1 
```

#### 1. Modify following configurations in `test_env.sh`
```
# modify according to your experiment
export ANY_NODE="Node5"
export ANY_NODE_IP="141.217.114.192"
export SUBNET="141.217.0.0/24" 
export USER="ericafu"
export SSH_OPTION="-i ~/.ssh/id_geni_ssh_rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
export CONTROL_NODE="152.54.9.101" # to allow in firewall and test apache from control machine
export OUTPUT_DIR="tmp/"
```

#### 2. If needed, modify `CORRUPT_NODES` and `CORRUPT_EDGES` files to indicate which nodes and edges to corrupt. Default all end nodes and all edges will be included. 

in `CORRUPT_NODES` file:

```
141.217.114.192 Node5
141.217.114.138 Node3
141.217.114.173 Node4
```

in `CORRUPT_EDGES` file:

```
export ESNET_Link1=10.100.1.2
export ESNET_Link4=172.16.4.2
export CENIC_Link5=172.16.5.2
```

#### 3. If needed, modify `nodes_src` and `nodes_dest` files 
Modify the files in case you want to set the src and dest for data transfers. 
Otherwise by default, data will be transferred between all end nodes.
&nbsp;
&nbsp;

### [Start Experiment]

#### 1. Now setup the nodes by `init_experiment.sh` which will install CJ and apache2, as well as getting the nodes information (IP addresses, Links...) to control machine
```
$ ./init_experiment.sh
```
 
#### 2. Then you can start the experiment by `start_experiement.sh`, a result folder will be created under `OUTPUT_DIR`. The log files and result matrix.csv will be inside the folder.
```
$ ./run_experiement.sh
```

#### 3. if step 2 wasn't completed successfully, run `reset_experiment.sh` to invert all corruptions before restarting again. 
```
$ ./reset_experiement.sh
```

