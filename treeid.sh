#!/bin/bash
#
# Attempt to identify the Android tree in use.  On success one or more
# tree identifiers are output to stdout.
#
# Copyright (c) 2012, The Linux Foundation. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above
#       copyright notice, this list of conditions and the following
#       disclaimer in the documentation and/or other materials provided
#       with the distribution.
#     * Neither the name of Code Aurora Forum, Inc. nor the names of its
#       contributors may be used to endorse or promote products derived
#       from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED "AS IS" AND ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT
# ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS
# BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
# BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
# IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# NOTE: This file is from changeset 3adb883a67f76736fae667ea48fb9159f616efd6
# retrieved from git://codeaurora.org/quic/b2g/build.git 
# There is a small patch applied that changes how we determine whether we
# apply the 'gb' or 'ics' patch series
if [[ ! ( -f build/envsetup.sh ) ]]; then
   echo $0: Error: CWD does not look like the root of an Android tree. > /dev/stderr
   exit 1
fi

if [[ -f .repo/manifest.xml ]] ; then
   MANIFEST_ID=$(sed -e \ '/<default.*/!d ; s/^.*revision="// ; s/".*$// ; s/refs\/tags\///' .repo/manifest.xml)
fi

# Parse the default value of PLATFORM_VERSION.  Assumption is that there is
# only going to be one uncommented definition of PLATFORM_VERSION.  This is
# true for Android 2.3 and 4.0
case $(sed -e '/^.*[^#]PLATFORM_VERSION .*=/!d  ; s/.*PLATFORM_VERSION.*=[^0-9]*\([0-9]\.[0-9]\).*/\1/' build/core/version_defaults.mk) in
    # The first asterisk is probably bad
    4.1|4.2)
        echo ${MANIFEST_ID} jb all
        ;;
    4.0)
        echo ${MANIFEST_ID} ics all
        ;;
    2.3)
        echo ${MANIFEST_ID} gb all
        ;;
    *)
        echo ${MANIFEST_ID} all
esac
