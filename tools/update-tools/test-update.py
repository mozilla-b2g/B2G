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
# Given an a complete and/or partial update mar, this script will:
# - Generate an update.xml
# - Push the busybox HTTP server to device
# - Push the update site to device, and start the HTTP server
# - Tweak the profile prefs to override the update URL
# - Restart B2G

import sys
from update_tools import UpdateXmlOptions, TestUpdate

def main():
    options = UpdateXmlOptions(output_arg=False)
    options.add_argument("--update-dir", dest="update_dir", metavar="DIR",
        default=None, help="Use a local http directory instead of pushing " +
                            " Busybox to the device. Also requires --url-template")
    options.parse_args()

    try:
        test_update = TestUpdate(options.build_xml(),
                                 complete_mar=options.get_complete_mar(),
                                 partial_mar=options.get_partial_mar(),
                                 url_template=options.get_url_template(),
                                 update_dir=options.options.update_dir)

        test_update.test_update()
    except Exception, e:
        print >>sys.stderr, "Error: %s" % e
        sys.exit(1)

if __name__ == "__main__":
    main()
