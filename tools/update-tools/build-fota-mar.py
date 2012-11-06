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
# Build FxOS FOTA update MARs that contain an AOSP update.zip

import argparse
import os
import sys
import update_tools

def build_fota_mar(update_zip, output_mar):
    try:
        builder = update_tools.FotaMarBuilder()
        builder.build_mar(update_zip, output_mar)
        print "FOTA Update MAR generated: %s" % output_mar
    except Exception, e:
        print >>sys.stderr, "Error: %s" % e
        sys.exit(1)

def main():
    parser = argparse.ArgumentParser(usage="%(prog)s [options] update.zip",
        epilog="Note: update.zip must be a signed FOTA update.zip")

    parser.add_argument("-o", "--output", dest="output", metavar="MAR",
        default=None,
        help="Output to update MAR. Default: replace '.zip' with '.mar'")

    update_tools.validate_env(parser)
    options, args = parser.parse_known_args()
    if len(args) == 0:
        parser.print_help()
        print >>sys.stderr, "Error: update.zip not specified"
        sys.exit(1)

    update_zip = args[0]
    if not os.path.exists(update_zip):
        print >>sys.stderr, \
            "Error: update.zip does not exist: %s" % update_zip
        sys.exit(1)

    output_mar = options.output
    if not output_mar:
        if ".zip" in update_zip:
            output_mar = update_zip.replace(".zip", ".mar")
        else:
            output_mar = "update.mar"

    build_fota_mar(update_zip, output_mar)

if __name__ == "__main__":
    main()
