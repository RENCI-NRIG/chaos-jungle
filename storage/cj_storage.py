#! /usr/bin/env python3
"""

The script provides corruption service by running cj_corrupt.py

"""
import argparse
import os
import sys
from crontab import CronTab
from cj_corrupt import run_corrupt


var_run_file = '/var/run/chaosjungle'


def is_cj_running():
    return os.path.isfile(var_run_file)

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
        sys.exit('exit(): Chaos jungle service is already running. use --stop first')

    if not args.target_directory or not args.target_files or not args.frequency:
        sys.exit('exit(): please provide -d, -f and -F <frequency> when using --start')

    if not args.recursive:
        print('RECURSIVE is OFF')
    else:
        print('RECURSIVE is ON')

    filepath = os.path.realpath(__file__)

    for i in range(0, len(sys.argv)-1):
        if sys.argv[i] == '-f' or sys.argv[i] == '-d':
            sys.argv[i+1] = '\'' + sys.argv[i+1] + '\''
            i += 1

    sys.argv.remove('--start')
    cmdlist = (['python3'] + [filepath] + ['--onetime'] + sys.argv[1:] + ['>/dev/null'] + ['2>&1'])
    cmdstr = ' '.join(cmdlist)
    job = mycron.new(command=cmdstr, comment='cj_corrupt')

    if args.frequency.find('h') >= 0:
        hour = int(args.frequency[:args.frequency.find('h')])
        if hour < 24:
            mark_cj_running(args)
            job.every(hour).hours()
            mycron.write()
            print('start chaos jungle service every {} hour'.format(hour))
            return
    elif args.frequency.find('m') >= 0:
        mins = int(args.frequency[:args.frequency.find('m')])
        if mins < 60:
            mark_cj_running(args)
            job.minute.every(mins)
            mycron.write()
            print('start chaos jungle service every {} min'.format(mins))
            return
    sys.exit('exit(): invalid -F frequency')


def stop(mycron):
    print('stop chaos jungle service')
    unmark_cj_running()
    mycron.remove_all(comment='cj_corrupt')
    mycron.write()


def run(args):
    mycron = CronTab(user=True)

    if args.onetime or args.wait or args.revert or args.inputfile:
        run_corrupt(args)
    elif args.stop:
        stop(mycron)
    elif args.start:
        start(mycron, args)
    else:
        sys.exit('exit(): please specify your action ( --onetime / --start / --stop / --filelist / --wait/ --revert)')


def main():

    parser = argparse.ArgumentParser(description='[WARNING!] The program corrupts file(s), please use it with CAUTION!')
    parser.add_argument('--onetime', action='store_true', help='just to corrupt once')
    parser.add_argument('--filelist', dest="inputfile", help='a file of file lists to corrupt')
    parser.add_argument('--revert', action='store_true', help='revert the specified corrupted file [-f <file>] or all files if -f is omitted')
    parser.add_argument('--start', action='store_true', help='start the chaos jungle')
    parser.add_argument('--stop', action='store_true', help='stop the chaos jungle')
    parser.add_argument('--wait', action='store_true', help='wait and corrupt a single file [-f "pattern"] under folder [-d <directory>]')

    parser.add_argument('-f', dest="target_files", nargs='*',
                        help='the path of target file or the pattern of filename (pattern should be wrapped by "") to corrupt. e.g.: -f /tmp/abc.txt, -f "*.txt", -f "*"')
    parser.add_argument('-d', dest="target_directory",
                        help='the directory, under which the files will randomly selected to be corrupted ')
    parser.add_argument('-r', '--recursive', action='store_true', default=False, help='match the files within the directory and its entire subtree (default: False)')
    parser.add_argument('-p', dest='probability', type=float, help='the probability of corruption (default: 1.0)')
    parser.add_argument('-F', dest="frequency", help='-F 2h means every 2 hrs, -F 10m means every 10 mins')
    parser.add_argument('-i', dest="index", help='the index of byte number to corrupt')
    parser.add_argument('-q', '--quiet', action='store_true', help='Be quiet')

    parser.set_defaults(func=run)
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
