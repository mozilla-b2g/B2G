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
# Given a MAR, Build a FxOS update.xml for testing.

import sys
import update_tools

def main():
    options = update_tools.UpdateXmlOptions()
    options.parse_args()
    output_xml = options.get_output_xml()

    try:
        xml = options.build_xml()
        if output_xml:
            with open(output_xml, "w") as out_file:
                out_file.write(xml)
        else:
            print xml

    except Exception, e:
        print >>sys.stderr, "Error: %s" % e
        sys.exit(1)

if __name__ == "__main__":
    main()
