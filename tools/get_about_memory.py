#!/usr/bin/env python

'''Get a dump of about:memory from all the processes running on your device.

You can then view these dumps using a recent Firefox nightly on your desktop by
opening about:memory and using the button at the bottom of the page to load the
memory-reports file that this script creates.

By default this script also gets gc/cc logs from all B2G processes.  This takes
a while, and these logs are large, so you can turn it off if you like.

This script also saves the output of b2g-procrank and a few other diagnostic
programs.  If you compiled with DMD and have it enabled, we'll also pull the
DMD reports.

'''

from __future__ import print_function

import sys
if sys.version_info < (2,7):
    # We need Python 2.7 because we import argparse.
    print('This script requires Python 2.7.')
    sys.exit(1)

import os
import re
import textwrap
import argparse
import json
import urllib
import subprocess
import traceback
from datetime import datetime
from gzip import GzipFile

import include.device_utils as utils
import fix_b2g_stack

def process_dmd_files(dmd_files, args):
    '''Run fix_b2g_stack.py on each of these files.'''
    if not dmd_files or args.no_dmd:
        return

    print()
    print('Processing DMD files.  This may take a minute or two.')
    try:
        process_dmd_files_impl(dmd_files, args)
        print('Done processing DMD files.  Have a look in %s.' %
              os.path.dirname(dmd_files[0]))
    except Exception as e:
        print('')
        print(textwrap.dedent('''\
            An error occurred while processing the DMD dumps.  Not to worry!
            The raw dumps are still there; just run fix_b2g_stack.py on
            them.
            '''))
        traceback.print_exc(e)

def process_dmd_files_impl(dmd_files, args):
    out_dir = os.path.dirname(dmd_files[0])

    procrank = open(os.path.join(out_dir, 'b2g-procrank'), 'r').read().split('\n')
    proc_names = {}
    for line in procrank:
        # App names may contain spaces and special characters (e.g.
        # '(Preallocated app)').  But for our purposes here, it's easier to
        # look at only the first word, and to strip off any special characters.
        #
        # We also assume that if an app name contains numbers, it contains them
        # only in the first word.
        match = re.match(r'^(\S+)\s+\D*(\d+)', line)
        if not match:
            continue
        proc_names[int(match.group(2))] = re.sub('\W', '', match.group(1)).lower()

    for f in dmd_files:
        # Extract the PID (e.g. 111) and UNIX time (e.g. 9999999) from the name
        # of the dmd file (e.g. dmd-9999999-111.txt.gz).
        basename = os.path.basename(f)
        dmd_filename_match = re.match(r'^dmd-(\d+)-(\d+).', basename)
        if dmd_filename_match:
            creation_time = datetime.fromtimestamp(int(dmd_filename_match.group(1)))
            pid = int(dmd_filename_match.group(2))
            if pid in proc_names:
                proc_name = proc_names[pid]
                outfile_name = 'dmd-%s-%d.txt.gz' % (proc_name, pid)
            else:
                proc_name = None
                outfile_name = 'dmd-%d.txt.gz' % pid
        else:
            pid = None
            creation_time = None
            outfile_name = 'processed-' + basename

        outfile = GzipFile(os.path.join(out_dir, outfile_name), 'w')
        def write(str):
            print(str, file=outfile)

        write('# Processed DMD output')
        if creation_time:
            write('# Created on %s, device time (may be unreliable).' %
                  creation_time.strftime('%c'))
        write('# Processed on %s, host machine time.' %
              datetime.now().strftime('%c'))
        if proc_name:
            write('# Corresponds to "%s" app, pid %d' % (proc_name, pid))
        elif pid:
            write('# Corresponds to unknown app, pid %d' % pid)
        else:
            write('# Corresponds to unknown app, unknown pid.')

        write('#\n# Contents of b2g-procrank:\n#')
        for line in procrank:
            write('#    ' + line.strip())
        write('\n')

        fix_b2g_stack.fix_b2g_stacks_in_file(GzipFile(f, 'r'), outfile, args)
        if not args.keep_individual_reports:
            os.remove(f)

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
    args.output_directory = out_dir

    # Do this function inside a try/catch which will delete out_dir if the
    # function throws and out_dir is empty.
    def do_work():
        fifo_msg = 'memory report' if not args.minimize_memory_usage else \
                   'minimize memory report'
        new_files = utils.notify_and_pull_files(
            fifo_msg=fifo_msg,
            outfiles_prefixes=['memory-report-'],
            remove_outfiles_from_device=not args.leave_on_device,
            out_dir=out_dir,
            optional_outfiles_prefixes=['dmd-'])

        memory_report_files = [f for f in new_files if f.startswith('memory-report-')]
        dmd_files = [f for f in new_files if f.startswith('dmd-')]
        merged_reports_path = merge_files(out_dir, memory_report_files)
        utils.pull_procrank_etc(out_dir)

        if not args.keep_individual_reports:
            for f in memory_report_files:
                os.remove(os.path.join(out_dir, f))

        return (out_dir,
                os.path.abspath(merged_reports_path),
                [os.path.join(out_dir, f) for f in dmd_files])

    return utils.run_and_delete_dir_on_exception(do_work, out_dir)

def get_and_show_info(args):
    (out_dir, merged_reports_path, dmd_files) = get_dumps(args)

    if dmd_files and not args.no_dmd:
        print('Got %d DMD dump(s).' % len(dmd_files))

    # Try to open the dump in Firefox.
    about_memory_url = "about:memory?file=%s" % urllib.quote(merged_reports_path)

    opened_in_firefox = False
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
            opened_in_firefox = True

            print()
            print(textwrap.fill(textwrap.dedent('''\
                I just tried to open the memory report in Firefox.  If that
                didn't work for some reason, or if you want to open this report
                at a later time, open the following URL in a Firefox nightly build:
                ''')) + '\n\n  ' + about_memory_url)
        except (subprocess.CalledProcessError, OSError):
            pass

    # If we didn't open in Firefox, output the message below.
    if not opened_in_firefox:
        print()
        print(textwrap.fill(textwrap.dedent('''\
            To view this report, open Firefox on this machine and load the
            following URL:
            ''')) + '\n\n  ' + about_memory_url)

    # Get GC/CC logs if necessary.
    if args.get_gc_cc_logs:
        import get_gc_cc_log
        print('')
        print('Pulling GC/CC logs...')
        get_gc_cc_log.get_logs(args, out_dir=out_dir, get_procrank_etc=False)

    process_dmd_files(dmd_files, args)

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

    gc_log_group = parser.add_mutually_exclusive_group()

    gc_log_group.add_argument('--no-gc-cc-log',
        dest='get_gc_cc_logs',
        action='store_false',
        default=True,
        help="Don't get a gc/cc log.")

    gc_log_group.add_argument('--abbreviated-gc-cc-log',
        dest='abbreviated_gc_cc_log',
        action='store_true',
        default=False,
        help='Get an abbreviated GC/CC log, instead of a full one.')

    parser.add_argument('--no-dmd', action='store_true', default=False,
        help='''Don't process DMD logs, even if they're available.''')

    dmd_group = parser.add_argument_group('optional DMD args (passed to fix_b2g_stack)',
        textwrap.dedent('''\
            You only need to worry about these options if you're running DMD on
            your device.  These options get passed to fix_b2g_stack.'''))
    fix_b2g_stack.add_argparse_arguments(dmd_group)

    args = parser.parse_args()
    get_and_show_info(args)
