#!/usr/bin/env python

'''Get a dump of about:memory from all the processes running on your device.

You can then view these dumps using Firefox on your desktop.

We also include the output of b2g-procrank and b2g-ps.

'''

from __future__ import print_function
from __future__ import division

import sys
if sys.version_info < (2,7):
    print('This script requires Python 2.7.')
    sys.exit(1)

import re
import os
import subprocess
import textwrap
import argparse
from time import sleep

def shell(cmd, cwd=None):
    proc = subprocess.Popen(cmd, shell=True, cwd=cwd,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    (out, err) = proc.communicate()
    if proc.returncode:
        print("Command %s failed with error code %d" % (cmd, proc.returncode), file=sys.stderr)
        if err:
            print(err, file=sys.stderr)
        raise subprocess.CalledProcessError(proc.returncode, cmd, err)
    return out

def get_pids():
    """Get the pids of all gecko processes running on the device.
    
    Returns a tuple (master_pid, child_pids), where child_pids is a list.
    
    """
    procs = shell("adb shell ps").split('\n')
    master_pid = None
    child_pids = []
    for line in procs:
        if re.search(r'/b2g\s*$', line):
            if master_pid:
                raise Exception("Two copies of b2g process found?")
            master_pid = int(line.split()[1])
        if re.search(r'/plugin-container\s*$', line):
            child_pids.append(int(line.split()[1]))

    if not master_pid:
        raise Exception("b2g does not appear to be running on the device.")

    return (master_pid, child_pids)

def list_files():
    return set(['/data/local/tmp/' + f.strip() for f in
                shell("adb shell ls '/data/local/tmp'").split('\n')
                if f.strip().startswith('memory-report-')])

def send_signal(args, pid):
    # killer is a program we put on the device which is like kill(1), except it
    # accepts signals above 31.  It also understands "SIGRTn" to mean 
    # SIGRTMIN + n.
    #
    # SIGRT0 dumps memory reports, and SIGRT1 first minimizes memory usage and
    # then dumps the reports.
    signal = 'SIGRT0' if not args.minimize_memory_usage else 'SIGRT1'
    shell("adb shell killer %s %d" % (signal, pid))

def choose_output_dir(args):
    if args.output_directory:
        return args.output_directory

    for i in range(0, 1024):
        try:
            dir = 'about-memory-%d' % i
            os.mkdir(dir)
            return dir
        except:
            pass
    raise Exception("Couldn't create about-memory output directory.")

def wait_for_all_files(num_expected_files, old_files):
    wait_interval = .25
    max_wait = 30

    warn_time = 5
    warned = False

    for i in range(0, int(max_wait / wait_interval)):
        new_files = list_files() - old_files

        # For some reason, print() doesn't work with the \r hack.
        sys.stdout.write('\rGot %d/%d files.' % (len(new_files), num_expected_files))
        sys.stdout.flush()

        if not warned and len(new_files) == 0 and i * wait_interval >= warn_time:
            warned = True
            sys.stdout.write('\r')
            print(textwrap.fill(textwrap.dedent("""\
                  The device may be asleep and not responding to our signal.
                  Try pressing a button on the device to wake it up.\n\n""")))

        if len(new_files) == num_expected_files:
            print('')
            return

        sleep(wait_interval)

    print("We've waited %ds but the only about:memory dumps we see are" % max_wait)
    print('\n'.join(['  ' + f for f in new_files]))
    print('We expected %d but see only %d files.  Giving up...' %
          (num_expected_files, len(new_files)))
    raise Exception("Missing some about:memory dumps.")

def get_files(args, master_pid, child_pids, old_files):
    """Get the memory reporter dumps from the device and return the directory
    we saved them to.

    """
    num_expected_files = 1 + len(child_pids)

    wait_for_all_files(num_expected_files, old_files)
    new_files = list_files() - old_files
    dir = choose_output_dir(args)
    for f in new_files:
        shell('adb pull %s' % f, cwd=dir)
        pass
    print("Pulled files into %s." % dir)
    return dir

def remove_new_files(old_files):
    # Hopefully this command line won't get too long for ADB.
    shell('adb shell rm %s' % ' '.join(["'%s'" % f for f in list_files() - old_files]))

def get_procrank_etc(dir):
    shell('adb shell procrank > procrank', cwd=dir)
    shell('adb shell b2g-ps > b2g-ps', cwd=dir)
    shell('adb shell b2g-procrank > b2g-procrank', cwd=dir)

def get_dumps(args):
    (master_pid, child_pids) = get_pids()
    old_files = list_files()
    send_signal(args, master_pid)
    dir = get_files(args, master_pid, child_pids, old_files)
    if args.remove_from_device:
        remove_new_files(old_files)
    get_procrank_etc(dir)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=textwrap.dedent('''\
        This script pulls about:memory reports from a device.  You can then
        open these reports in desktop Firefox by visiting about:memory.'''))

    parser.add_argument('--minimize', '-m', dest='minimize_memory_usage',
        action='store_true', default=False,
        help='Minimize memory usage before collecting the memory reports.')

    parser.add_argument('--directory', '-d', dest='output_directory',
        action='store', metavar='DIR',
        help=textwrap.dedent('''\
            The directory to store the reports in.  By default, we'll store the
            reports in the directory about-memory-N, for some N.'''))

    parser.add_argument('--remove', '-r', dest='remove_from_device',
        action='store_true', default=False,
        help='Delete the reports from the device after pulling them.')

    args = parser.parse_args()
    get_dumps(args)
