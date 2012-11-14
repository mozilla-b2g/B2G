#!/usr/bin/env python
#
# Copyright (C) 2012 Mozilla Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Build a gecko (OTA) full or incremental MAR

import argparse
import os
import shutil
import tempfile
import update_tools

def unwrap_mar(mar, verbose):
    print "Extracting MAR for incremental update: %s" % mar
    tmpdir = tempfile.mkdtemp()
    bz2_mar = update_tools.BZip2Mar(mar, verbose=verbose)
    bz2_mar.extract(tmpdir)
    return tmpdir

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mar", metavar="MAR", help="Destination MAR file")
    parser.add_argument("--dir", metavar="DIR", default=None,
        help="Source directory. When building an \"incremental\" MAR, this can " +
             "also be a MAR for convenience. Default: $PWD")

    parser.add_argument("--to", metavar="TO", default=None,
        help="This is a synonym for --dir")
    parser.add_argument("--from", metavar="FROM", dest="from_dir", default=None,
        help="The base directory or MAR to build an incremental MAR from. This " +
             "will build an incremental update MAR between FROM and TO")
    parser.add_argument("-v", "--verbose", dest="verbose", action="store_true",
        default=False, help="Enable verbose logging")

    args = parser.parse_args()

    if os.path.isdir(args.mar):
        parser.error("MAR destination is a directory: %s" % args.mar)

    if not args.dir:
        args.dir = args.to if args.to else os.getcwd()

    if not args.from_dir and not os.path.isdir(args.dir):
        parser.error("Path is not a directory: %s" % args.dir)

    to_tmpdir = from_tmpdir = None
    if args.from_dir and os.path.isfile(args.dir):
        to_tmpdir = unwrap_mar(args.dir, args.verbose)
        args.dir = to_tmpdir

    if args.from_dir and os.path.isfile(args.from_dir):
        from_tmpdir = unwrap_mar(args.from_dir, args.verbose)
        args.from_dir = from_tmpdir

    try:
        builder = update_tools.GeckoMarBuilder()
        builder.build_gecko_mar(args.dir, args.mar, from_dir=args.from_dir)
        update_type = "incremental" if args.from_dir else "full"

        print "Built %s update MAR: %s" % (update_type, args.mar)
    except Exception, e:
        parser.error(e)
    finally:
        if to_tmpdir:
            shutil.rmtree(to_tmpdir)
        if from_tmpdir:
            shutil.rmtree(from_tmpdir)

if __name__ == "__main__":
    main()
