#! /usr/bin/env python3
"""

The script provides corruption service by running cj_corrupt.py

"""
import argparse
import os
import sys
from cj_corrupt import run_corrupt
from crontab import CronTab

var_run_file = '/var/run/chaosjungle'

def is_cj_running():
    if os.path.isfile(var_run_file):
        return True
    else:
        return False

def mark_cj_running(args):
    with open(var_run_file, 'w') as f:
        f.write('uid {} -d {} -f {}'.format(os.getuid(), args.target_directory, args.target_files))

def unmark_cj_running():
    if os.path.isfile(var_run_file):
        try:
            os.remove(var_run_file)
        except:
            return

def start(mycron, args):
    if is_cj_running():
        print ('Chaos jungle service is already running. use --stop first')
        return

    if not args.target_directory:
        print ('please provide -d <target_directory> when using --start')
        return

    if not args.frequency:
        print ('please provide -F <frequency> when using --start')
        return

    filepath = os.path.realpath('./cj_corrupt.py')

    for i in range (0, len(sys.argv)-1):
        if sys.argv[i] == '-f' or sys.argv[i] == '-d':
            sys.argv[i+1] = '\'' + sys.argv[i+1] + '\''
            i += 1

    print (sys.argv)
    cmdlist = (['python3'] + [filepath] + sys.argv[1:] +['>/dev/null'] +['2>&1'])
    cmdstr = ' '.join(cmdlist)
    print (cmdstr)
    job = mycron.new(command=cmdstr, comment='cj_corrupt')

    if args.frequency.find('h') >= 0:
        hour = int(args.frequency[:args.frequency.find('h')])
        if hour < 24:
            mark_cj_running(args)
            job.every(hour).hours()
            mycron.write()
            print ('start chaos jungle service every {} hour'.format(hour))
            return
    elif args.frequency.find('m') >= 0:
        min = int(args.frequency[:args.frequency.find('m')])
        if min < 60:
            mark_cj_running(args)
            job.minute.every(min)
            mycron.write()
            print ('start chaos jungle service every {} min'.format(min))
            return
    print ('invalid -F frequency')


def stop(mycron):
    print ('stop chaos jungle service')
    unmark_cj_running()
    mycron.remove_all(comment='cj_corrupt')
    mycron.write()


def run(args):
    if args.onetime or args.wait or args.revert or args.filelist:
        run_corrupt(args)
        return

    mycron = CronTab(user=True)
    if args.stop:
        stop(mycron)
        return

    if not args.start:
        sys.exit('exit(): please specify your option ( --onetime / --start / --stop / --filelist / --wait)')

    if args.target_directory:
        if not args.target_files:
            sys.exit('exit(): must provide file pattern by -f')
    elif not args.target_files:
        sys.exit('exit(): no file or directory given')
    start(mycron, args)


def main():

    parser = argparse.ArgumentParser(description='[WARNING!] The program corrupts file(s), please use it with CAUTION!')
    parser.add_argument('-f', dest="target_files", nargs='*',
                        help='the path of target file or the pattern of filename (pattern should be wrapped by "") to corrupt. e.g.: -f /tmp/abc.txt, -f "*.txt", -f "*"')
    parser.add_argument('-d', dest="target_directory",
                        help='the directory, under which the files will randomly selected to be corrupted ')
    parser.add_argument('-r', '--recursive', action='store_true', default=False, help='match the files within the directory and its entire subtree (default: False)')
    parser.add_argument('-p', dest='probability', type=float, help='the probability of corruption (default: 1.0)')
    parser.add_argument('-F', dest="frequency", help='-F 2h means every 2 hrs, -F 10m means every 10 mins')
    parser.add_argument('-i', dest="index", help='the index of byte number to corrupt')
    parser.add_argument('-db', dest="db_file", help=argparse.SUPPRESS)
    parser.add_argument('--onetime', action='store_true', help='just to corrupt once')
    parser.add_argument('--filelist', dest="filelist", help='a file of file lists to corrupt')
    parser.add_argument('--start', action='store_true', help='start the chaos jungle')
    parser.add_argument('--stop', action='store_true', help='stop the chaos jungle')
    parser.add_argument('--wait', action='store_true', help='wait and corrupt a single file [-f "pattern"] under folder [-d <directory>]')
    parser.add_argument('--revert', action='store_true', help='revert the specified corrupted file [-f <file>] or all files if -f is omitted')
    parser.add_argument('-q', '--quiet', action='store_true', help='Be quiet')

    parser.set_defaults(func=run)
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
