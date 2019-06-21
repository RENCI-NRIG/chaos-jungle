# Chaos-Jungle storage

## Overview

This section of Chaos Jungle will introduce impairments to data in the disk.


## Prerequisites

Install pip

```
$ sudo yum install epel-release
$ sudo yum install python-pip
$ pip install python-crontab

```

## Examples of operation

### One-time corruption
one-time corruption: corrupt the file "~/20190425T121649-0700/00/00/a12as_0008.pdb", with probability 80%:

```
$ sudo ./cj_storage.py -f ~/20190425T121649-0700/00/00/a12as_0008.pdb -p 0.8 --onetime

```

one-time corruption to multiple files: "-f file1 file2 file3 ..."

```
$ sudo ./cj_storage.py -f ~/20190425T121649-0700/00/00/a12as_0008.pdb ~/20190425T121649-0700/00/00/a12as_0017.pdb  --onetime

```

one-time corruption: pick an file which matches "\*.pdb" under "~/20190425T121649-0700" directory:

```
$ sudo ./cj_storage.py -f "*.pdb" -d ~/20190425T121649-0700 --onetime

```

one-time corruption: pick an file which matches "\*.pdb" under "~/20190425T121649-0700" directory and its subtree(option -r):

```
$ sudo ./cj_storage.py -f "*.pdb" -d ~/20190425T121649-0700 -r --onetime

```

### One-time corruption using '--wait'
wait and corrupt ONE matched file 

```
$ sudo ./cj_storage.py -d ~/20190425T121649-0700 -f "*.pdb" --wait

```

### Start/Stop crontab service for periodic corruption
start corruption service: corrupt every 1 hr, pick file which matches "\*.pdb" under "~/20190425T121649-0700" directory. 

```
$ sudo ./cj_storage.py -f "*.pdb" -d ~/20190425T121649-0700 --start -F 1h

```

stop corruption service:

```
$ sudo ./cj_storage.py --stop

```

Note: The minimum interval for crontab is 1 min(1m).

### Revert corruption file(s)
revert all corruption files record in database

```
$ sudo ./cj_storage.py --revert

```

revert specific file(s): you need to give specific files (regex not supported) for "--revert" 

```
$ sudo ./cj_storage.py -f ~/20190425T121649-0700/00/00/a12as_0008.pdb --revert

```


## Log files
```cj.log``` is user log file which contains corruption/reversion history

```
$ cat /var/log/cj.log
2019-06-01 15:29:29,071 CORRUPT_BIT START filename = /tmp/hello_world.txt, target_block = 1144748
2019-06-01 15:29:29,075 CORRUPT_BIT END success
2019-06-01 15:29:29,079 CORRUPT record: ('/tmp/hello_world.txt', 1559414486.0916538, '/dev/mapper/centos-root', 1144748, 0, 72, 200)
2019-06-01 15:29:32,804 CORRUPT_BIT START filename = /tmp/hello_world2.txt, target_block = 1144750
2019-06-01 15:29:32,807 CORRUPT_BIT END success
2019-06-01 15:29:32,811 CORRUPT record: ('/tmp/hello_world2.txt', 1559405777.6346905, '/dev/mapper/centos-root', 1144750, 0, 84, 212)
2019-06-01 15:30:11,599 REVERT START filename = /tmp/hello_world.txt, target_block = 1144748
2019-06-01 15:30:11,601 REVERT END success
2019-06-01 15:30:11,617 REVERT START filename = /tmp/hello_world2.txt, target_block = 1144750
2019-06-01 15:30:11,631 REVERT END success

```

```cj_debug.log``` contains debug information

The log folder path can be configured in .cfg file.  

```
[Paths]
log_dir = /var/log

```


## Using SQLite Database
Chaos Jungle uses the database in order not to corrupt the same file twice.
Chaos Jungle also provide feature to revert the corrupt data into original values based on the database records. see ```--revert``` usage

The database file path can be configured in .cfg file.  

```
[Paths]
database_file = /var/log/cj.db

```

## Full usage details
```
$ ./cj_storage.py -h
usage: cj_storage.py [-h] [-f [TARGET_FILE [TARGET_FILE ...]]]
                     [-d TARGET_DIRECTORY] [-r] [-p PROBABILITY]
                     [-F FREQUENCY] [--onetime] [--start] [--stop] [--wait]
                     [--revert] [-q]

[WARNING!] The program corrupts file(s), please use it with CAUTION!

optional arguments:
  -h, --help            show this help message and exit
  -f [TARGET_FILE [TARGET_FILE ...]]
                        the path of target file (when -d option is not
                        provided) or the pattern of filename to corrupt. e.g.:
                        /tmp/abc.txt, '*.txt', '*'
  -d TARGET_DIRECTORY   the directory, under which the files will randomly
                        selected to be corrupted
  -r, --recursive       match the files within the directory and its entire
                        subtree (default: False)
  -p PROBABILITY        the probability of corruption (default: 1.0)
  -F FREQUENCY          -F 2h means every 2 hrs, -F 10m means every 10 mins
  --onetime             just to corrupt once
  --start               start the chaos jungle
  --stop                stop the chaos jungle
  --wait                wait and corrupt a single file [-f <file>]
  --revert              revert the specified corrupted file [-f <file>] or all
                        files if -f is omitted
  -q, --quiet           Be quiet


```
