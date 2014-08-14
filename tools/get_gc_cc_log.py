#!/usr/bin/env python

'''This script pulls GC and CC logs from all B2G processes on a device.  These
logs are primarily used by leak-checking tools.

This script also saves the output of b2g-procrank and a few other diagnostic
programs.

'''

from __future__ import print_function

import sys
if sys.version_info < (2,7):
    # We need Python 2.7 because we import argparse.
    print('This script requires Python 2.7.', file=sys.stderr)
    sys.exit(1)

import os
import sys
import re
import argparse
import textwrap
import gzip
from multiprocessing import Pool

import include.device_utils as utils


def gzip_compress(to_compress):
    with open(to_compress, mode='rb') as f_in:
        with gzip.open(to_compress + '.gz', mode='wb') as f_out:
            f_out.writelines(f_in)

    os.remove(to_compress)


def compress_logs(log_filenames, out_dir):
    print('Compressing logs...')

    # Compress in parallel.  While we're at it, we also strip off the
    # long identifier from the filenames, if we can.  (The filename is
    # something like gc-log.PID.IDENTIFIER.log, where the identifier is
    # something like the number of seconds since the epoch when the log was
    # triggered.)
    to_compress = []
    for f in log_filenames:
        # Rename the log file if we can.
        match = re.match(r'^([a-zA-Z-]+\.[0-9]+)\.[0-9]+.log$', f)
        if match:
            if not os.path.exists(os.path.join(out_dir, match.group(1))):
                new_name = match.group(1) + '.log'
                os.rename(os.path.join(out_dir, f),
                          os.path.join(out_dir, new_name))
                f = new_name

        to_compress.append(os.path.join(out_dir, f))

    # Start compressing.
    pool = Pool()
    pool.map(gzip_compress, to_compress)


def get_logs(args, out_dir=None, get_procrank_etc=True):
    if not out_dir:
        if args.output_directory:
            out_dir = utils.create_specific_output_dir(args.output_directory)
        else:
            out_dir = utils.create_new_output_dir('gc-cc-logs-')

    if args.abbreviated_gc_cc_log:
        fifo_msg='abbreviated gc log'
    else:
        fifo_msg='gc log'

    def do_work():
        log_filenames = utils.notify_and_pull_files(
            fifo_msg=fifo_msg,
            outfiles_prefixes=['cc-edges.', 'gc-edges.'],
            remove_outfiles_from_device=not args.leave_on_device,
            out_dir=out_dir)

        if get_procrank_etc:
            utils.pull_procrank_etc(out_dir)

        if args.compress_gc_cc_logs:
            compress_logs(log_filenames, out_dir)

    utils.run_and_delete_dir_on_exception(do_work, out_dir)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)

    parser.add_argument('--directory', '-d', dest='output_directory',
        action='store', metavar='DIR',
        help=textwrap.dedent('''\
            The directory to store the logs in.  By default, we'll store the
            reports in the directory gc-cc-logs-N, for some N.'''))

    parser.add_argument('--leave-on-device', '-l', dest='leave_on_device',
        action='store_true', default=False,
        help=textwrap.dedent('''\
            Leave the logs on the device after pulling them.  (Note: These logs
            can take up tens of megabytes and are stored uncompressed on the
            device!)'''))

    parser.add_argument('--abbreviated', dest='abbreviated_gc_cc_log',
        action='store_true', default=False,
        help=textwrap.dedent('''\
            Get an abbreviated CC log instead of a full (i.e., all-traces) log.
            An abbreviated log doesn't trace through objects that the cycle
            collector knows must be reachable (e.g. DOM nodes whose window is
            alive).'''))

    parser.add_argument('--uncompressed', dest='compress_gc_cc_logs',
        action='store_false', default=True,
        help='Do not compress the individual logs.')

    args = parser.parse_args()
    get_logs(args)
