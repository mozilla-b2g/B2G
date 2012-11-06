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
# Build FOTA update zips for testing. Production zips should be built w/ AOSP tools.

import argparse
import os
import sys
import tempfile
import update_tools

def build_fota_zip(update_dir, public_key, private_key, output_zip):
    try:
        builder = update_tools.FotaZipBuilder()

        stage_dir = tempfile.mkdtemp()
        unsigned_zip = os.path.join(stage_dir, "update-unsigned.zip")

        builder.build_unsigned_zip(update_dir, unsigned_zip)
        print "Public key: %s" % public_key
        print "Private key: %s" % private_key

        builder.sign_zip(unsigned_zip, public_key, private_key, output_zip)
        print "FOTA Update ZIP generated: %s" % output_zip
    except Exception, e:
        print >>sys.stderr, "Error: %s" % e
        sys.exit(1)

def main():
    parser = argparse.ArgumentParser(usage="%(prog)s [options] update-dir",
        epilog="Note: java is required to be on your PATH to sign the update.zip")

    parser.add_argument("-d", "--dev-key", dest="dev_key", metavar="KEYNAME",
        default="testkey",
        help="Use the named dev key pair in build/target/product/security. " +
             "Possible keys: media, platform, shared, testkey. Default: testkey")

    parser.add_argument("-k", "--private-key", dest="private_key",
        metavar="PRIVATE_KEY", default=None,
        help="Private key used for signing the update.zip. Overrides --dev-key.")

    parser.add_argument("-K", "--public-key", dest="public_key",
        metavar="PUBLIC_KEY", default=None,
        help="Public key used for signing the update.zip. Overrides --dev-key.")

    parser.add_argument("-o", "--output", dest="output", metavar="ZIP",
        help="Output to ZIP. Default: update-dir.zip", default=None)

    update_tools.validate_env(parser)
    options, args = parser.parse_known_args()
    if len(args) == 0:
        parser.print_help()
        print >>sys.stderr, "Error: update-dir not specified"
        sys.exit(1)

    update_dir = args[0]
    if not os.path.isdir(update_dir):
        print >>sys.stderr, \
            "Error: update-dir is not a directory: %s" % update_dir
        sys.exit(1)

    security_dir = os.path.join(update_tools.b2g_dir, "build", "target",
        "product", "security")
    public_key = options.public_key or os.path.join(security_dir,
        options.dev_key + ".x509.pem")
    private_key = options.private_key or os.path.join(security_dir,
        options.dev_key + ".pk8")

    output_zip = options.output or update_dir + ".zip"
    build_fota_zip(update_dir, public_key, private_key, output_zip)

if __name__ == "__main__":
    main()
