# IRIS Experiment

### [Before Starting]
Before starting experiments, configuration needs to be modified first.

#### Download the Chaos Jungle experiment scripts
```
$ git clone --branch storage https://github.com/RENCI-NRIG/chaos-jungle.git
$ cd chaos-jungle/experiment/v1 
```

#### Modify following configurations in `test_env.sh`
```
# modify according to your experiment
export ANY_NODE=OriginSDSC
export ANY_NODE_IP="198.129.50.24"
export USER="root"
export SSH_OPTION="-i ~/.ssh/id_geni_ssh_rsa -o UserKnownHostsFile=~/.ssh/known_hosts2 -o StrictHostKeyChecking=no"
export OUTPUT_DIR=../results
```

### [Start Experiment]

#### 1. Now setup the nodes by `init_experiment.sh` which will install CJ and apache2, as well as getting the nodes information (IP addresses, Links...) to control machine
```
$ ./init_experiment.sh
```
 
#### a) If needed, modify `CORRUPT_NODES` and `CORRUPT_EDGES` files to indicate which nodes and edges to corrupt. 
&nbsp;&nbsp;&nbsp;&nbsp;Default all end nodes and all edges will be included. 

&nbsp;&nbsp;&nbsp;&nbsp;in `CORRUPT_NODES` file:

```
    141.217.114.192 Node5
    141.217.114.138 Node3
    141.217.114.173 Node4
```

&nbsp;&nbsp;&nbsp;&nbsp;in `CORRUPT_EDGES` file:

```
    export ESNET_Link1=10.100.1.2
    export ESNET_Link4=172.16.4.2
    export CENIC_Link5=172.16.5.2
```

#### b) If needed, modify `NODES_SRC` and `NODES_DEST` files 
&nbsp;&nbsp;&nbsp;&nbsp;Modify the files in case you want to set the src and dest for data transfers. <br />
&nbsp;&nbsp;&nbsp;&nbsp;Otherwise by default, data will be transferred between all end nodes.
<br />
<br />

#### 2. Then you can start the experiment by `start_experiement.sh`, a result folder will be created under `OUTPUT_DIR`. The log files and result `matrix.csv` will be inside the folder.
```
$ ./run_experiement.sh
```



