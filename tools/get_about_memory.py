#!/usr/bin/env python

'''Get a dump of about:memory from all the processes running on your device.

You can then view these dumps using a recent Firefox nightly on your desktop by
opening about:memory and using the button at the bottom of the page to load the
memory-reports file that this script creates.

This script also saves the output of b2g-procrank and a few other diagnostic
programs.

'''

from __future__ import print_function

import sys
if sys.version_info < (2,7):
    # We need Python 2.7 because we import argparse.
    print('This script requires Python 2.7.')
    sys.exit(1)

import os
import textwrap
import argparse
import json
import urllib
import subprocess
from gzip import GzipFile

import include.device_utils as utils

def merge_files(dir, files):
    '''Merge the given memory reporter dump files into one giant file.'''
    dumps = [json.load(GzipFile(os.path.join(dir, f))) for f in files]

    merged_dump = dumps[0]
    for dump in dumps[1:]:
        # All of the properties other than 'reports' must be identical in all
        # dumps, otherwise we can't merge them.
        if set(dump.keys()) != set(merged_dump.keys()):
            print("Can't merge dumps because they don't have the "
                  "same set of properties.")
            return
        for prop in merged_dump:
            if prop != 'reports' and dump[prop] != merged_dump[prop]:
                print("Can't merge dumps because they don't have the "
                      "same value for property '%s'" % prop)

        merged_dump['reports'] += dump['reports']

    merged_reports_path = os.path.join (dir, 'memory-reports')
    json.dump(merged_dump,
              open(merged_reports_path, 'w'),
              indent=2)
    return merged_reports_path

def get_dumps(args):
    if args.output_directory:
        out_dir = utils.create_specific_output_dir(args.output_directory)
    else:
        out_dir = utils.create_new_output_dir('about-memory-')

    # Do this function inside a try/catch which will delete out_dir if the
    # function throws and out_dir is empty.
    def do_work():
        signal = 'SIGRT0' if not args.minimize_memory_usage else 'SIGRT1'
        new_files = utils.send_signal_and_pull_files(
            signal=signal,
            outfiles_prefixes=['memory-report-'],
            remove_outfiles_from_device=not args.leave_on_device,
            out_dir=out_dir)

        merged_reports_path = merge_files(out_dir, new_files)
        utils.pull_procrank_etc(out_dir)

        if not args.keep_individual_reports:
            for f in new_files:
                os.remove(os.path.join(out_dir, f))

        return os.path.abspath(merged_reports_path)

    return utils.run_and_delete_dir_on_exception(do_work, out_dir)

def get_and_show_dump(args):
    merged_reports_path = get_dumps(args)

    # Try to open the dump in Firefox.
    about_memory_url = "about:memory?file=%s" % urllib.quote(merged_reports_path)
    if args.open_in_firefox:
        try:
            # Open about_memory_url in Firefox, but don't display stdout or stderr.
            # This isn't necessary if Firefox is already running (which it
            # probably is), because in that case our |firefox| invocation will
            # open a new tab in the existing process and then immediately exit.
            # But if Firefox isn't already running, we don't want to pollute
            # our terminal with its output.

            # If we wanted to be platform-independent, we might be able to use
            # "NUL" on Windows.  But the rest of this script already isn't
            # platform-independent, so whatever.
            fnull = open('/dev/null', 'w')
            subprocess.Popen(['firefox', about_memory_url], stdout=fnull, stderr=fnull)
            print()
            print(textwrap.fill(textwrap.dedent('''\
                I just tried to open the memory report in Firefox.  If that
                didn't work for some reason, or if you want to open this report
                at a later time, open the following URL in a Firefox nightly build:
                ''')) + '\n\n  ' + about_memory_url)
            return
        except (subprocess.CalledProcessError, OSError):
            pass

    # If not args.open_in_firefox or if we weren't able to open in Firefox,
    # output the message below.
    print()
    print(textwrap.fill(textwrap.dedent('''\
        To view this report, open Firefox on this machine and load the
        following URL:
        ''')) + '\n\n  ' + about_memory_url)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)

    parser.add_argument('--minimize', '-m', dest='minimize_memory_usage',
        action='store_true', default=False,
        help='Minimize memory usage before collecting the memory reports.')

    parser.add_argument('--directory', '-d', dest='output_directory',
        action='store', metavar='DIR',
        help=textwrap.dedent('''\
            The directory to store the reports in.  By default, we'll store the
            reports in the directory about-memory-N, for some N.'''))

    parser.add_argument('--leave-on-device', '-l', dest='leave_on_device',
        action='store_true', default=False,
        help='Leave the reports on the device after pulling them.')

    parser.add_argument('--no-auto-open', '-o', dest='open_in_firefox',
        action='store_false', default=True,
        help=textwrap.dedent("""\
            By default, we try to open the memory report we fetch in Firefox.
            Specify this option prevent this."""))

    parser.add_argument('--keep-individual-reports',
        dest='keep_individual_reports',
        action='store_true', default=False,
        help=textwrap.dedent('''\
            Don't delete the individual memory reports which we merge to create
            the memory-reports file.  You shouldn't need to pass this parameter
            except for debugging.'''))

    args = parser.parse_args()
    get_and_show_dump(args)
