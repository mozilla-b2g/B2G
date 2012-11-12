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
# AUS MARs will also have each entry bz2 compressed. This tool can extract or
# rebuild these "wrapped" MARs.
#
# Warning: If you unwrap, edit a file, then re-wrap a MAR you will lose any
# metadata that existed in the original MAR, such as signatures.

import argparse
import os
import update_tools

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mar", metavar="MAR", help="MAR archive to (un)wrap")
    parser.add_argument("dir", metavar="DIR", help="Source or destination " +
        "directory for (un)wrapping MAR.")
    parser.add_argument("-u", "--unwrap", dest="unwrap", action="store_true",
        default=False, help="Unwrap MAR to DIR")
    parser.add_argument("-v", "--verbose", dest="verbose", action="store_true",
        default=False, help="Verbose (un)wrapping")

    args = parser.parse_args()
    if os.path.isfile(args.dir):
        parser.error("Path is not a directory: %s" % args.dir)

    try:
        mar = update_tools.BZip2Mar(args.mar, verbose=args.verbose)
        action = mar.extract if args.unwrap else mar.create
        action(args.dir)

        if args.unwrap:
            print "Unwrapped MAR to %s" % args.dir
        else:
            print "Wrapped MAR to %s" % args.mar

    except Exception, e:
        parser.error(e)

if __name__ == "__main__":
    main()
