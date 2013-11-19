#!/bin/bash

set -e

# Support running with PWD=script or b2g root
[ -e load-config.sh ] || cd ..

B2G_DIR=$PWD
. ./load-config.sh

SCRIPT_NAME=$(basename $0)

make -C "${GECKO_OBJDIR}" $MAKE_FLAGS binaries
make -C "${GECKO_OBJDIR}" $MAKE_FLAGS package

echo "Compressing xul"
gzip --best -c "${GECKO_OBJDIR}/dist/b2g/libxul.so" > /tmp/b2g_libxul.so.gz
adb remount
echo adb push /tmp/b2g_libxul.so.gz /system/b2g/libxul.so.gz
adb push /tmp/b2g_libxul.so.gz /system/b2g/libxul.so.gz

adb shell stop b2g
echo adb shell "gzip -d /system/b2g/libxul.so"
adb shell "gzip -d /system/b2g/libxul.so"
echo Restarting B2G
adb shell start b2g

echo "Reminder: ${SCRIPT_NAME} is a helper script to quickly update XUL when making"
echo "c++ only changes that *only* affect libxul.so."
