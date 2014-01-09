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
# Build A FOTA update zip that flashes the system partition

import argparse
import os
import sys
import tempfile
import update_tools

def build_flash_fota(args):
    security_dir = os.path.join(update_tools.b2g_dir, "build", "target",
        "product", "security")
    public_key = args.public_key or os.path.join(security_dir,
        args.dev_key + ".x509.pem")
    private_key = args.private_key or os.path.join(security_dir,
        args.dev_key + ".pk8")
    output_zip = args.output or "flash.zip"

    system = update_tools.Partition.create_system(args.system_fs_type,
                                                  args.system_location)
    data = update_tools.Partition.create_data(args.data_fs_type,
                                              args.data_location)
    builder = update_tools.FlashFotaBuilder(system, data)

    builder.fota_type = args.fota_type
    builder.fota_dirs = []
    builder.fota_files = []
    if args.fota_type == 'partial':
	builder.fota_dirs = args.fota_dirs.split(' ')
        builder.fota_files = [line.rstrip() for line in open(args.fota_files, 'r')]

    builder.build_flash_fota(args.system_dir, public_key, private_key,
                             output_zip)
    print "FOTA Flash ZIP generated: %s" % output_zip

def main():
    parser = argparse.ArgumentParser(usage="%(prog)s [options]",
        epilog="Note: java is required to be on your PATH to sign the update.zip")

    system_group = parser.add_argument_group("system options")
    system_group.add_argument("--system-dir", dest="system_dir",
        required=True, help="path to system directory. required")
    system_group.add_argument("--system-fs-type", dest="system_fs_type",
        default=None, required=True, help="filesystem type for /system. required")
    system_group.add_argument("--system-location", dest="system_location",
        default=None, required=True, help="device location for /system. required")

    data_group = parser.add_argument_group("data options")
    data_group.add_argument("--data-fs-type", dest="data_fs_type",
        default=None, required=True, help="filesystem type for /data. required")
    data_group.add_argument("--data-location", dest="data_location",
        default=None, required=True, help="device location for /data. required")

    fota_group = parser.add_argument_group("fota options")
    fota_group.add_argument("--fota-type", dest="fota_type",
        required=False, default="full",
        help="'partial' or 'full' fota. 'partial' requires a file list")
    fota_group.add_argument("--fota-dirs", dest="fota_dirs",
        required=False, default="",
        help="space-separated string containing list of dirs to include, to delete files")
    fota_group.add_argument("--fota-files", dest="fota_files",
        required=False, default="",
        help="file containing list of files in /system to include")

    signing_group = parser.add_argument_group("signing options")
    signing_group.add_argument("-d", "--dev-key", dest="dev_key",
        metavar="KEYNAME", default="testkey",
        help="Use the named dev key pair in build/target/product/security. " +
             "Possible keys: media, platform, shared, testkey. Default: testkey")

    signing_group.add_argument("-k", "--private-key", dest="private_key",
        metavar="PRIVATE_KEY", default=None,
        help="Private key used for signing the update.zip. Overrides --dev-key.")

    signing_group.add_argument("-K", "--public-key", dest="public_key",
        metavar="PUBLIC_KEY", default=None,
        help="Public key used for signing the update.zip. Overrides --dev-key.")

    parser.add_argument("-o", "--output", dest="output", metavar="ZIP",
        help="Output to ZIP. Default: flash.zip", default=None)

    update_tools.validate_env(parser)
    try:
        build_flash_fota(parser.parse_args())
    except update_tools.UpdateException, e:
        print >>sys.stderr, "Error: %s" % e
        sys.exit(1)

if __name__ == "__main__":
    main()
