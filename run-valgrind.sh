#!/bin/bash
#set -xv

SCRIPT_NAME=$(basename $0)

. load-config.sh

ADB=${ADB:-adb}
if [ ! -f "`which \"$ADB\"`" ]; then
	ADB=out/host/`uname -s | tr "[[:upper:]]" "[[:lower:]]"`-x86/bin/adb
fi

B2G_DIR="/data/valgrind-b2g"

HAS_VALGRIND=$($ADB shell 'test -e /system/bin/valgrind ; echo -n $?')

# Make sure valgrind is actually on system
if [ "$HAS_VALGRIND" -ne 0 ]; then
    echo "Platform does not have valgrind executable, did you build with B2G_VALGRIND=1 in your .userconfig?"
    exit 1
fi

# Load libxul
if [ "$1" = "debuginfo" ]; then
  echo "Recompiling libxul.so with debug info (this can take a few minutes)"
  $ADB remount
  $ADB shell "rm -rf $B2G_DIR && cp -r /system/b2g $B2G_DIR"
  cp $GECKO_OBJDIR/toolkit/library/libxul.so $GECKO_OBJDIR/toolkit/library/libxul.debuginfo.so
  ./prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.7/bin/arm-linux-androideabi-strip -R .debug_info $GECKO_OBJDIR/toolkit/library/libxul.debuginfo.so
  echo "Pushing debug libxul to phone (this takes about a minute)"
  time adb push $GECKO_OBJDIR/toolkit/library/libxul.debuginfo.so $B2G_DIR/libxul.so
elif [ "$1" = "nocopy" ]; then
  echo "Skipping libxul.so copy step and just running valgrind..."
else
  echo "Pushing debug libxul to phone (this can take upwards of 5 minutes)"
  $ADB remount
  $ADB shell "rm -rf $B2G_DIR && cp -r /system/b2g $B2G_DIR"
  time adb push $GECKO_OBJDIR/toolkit/library/libxul.so $B2G_DIR/libxul.so
fi

$ADB reboot
$ADB wait-for-device
$ADB shell stop b2g

# Due to the fact that we follow forks, we can't log to a logfile. Expect the
# user to redirect stdout.
$ADB shell 'B2G_DIR="/data/valgrind-b2g" COMMAND_PREFIX="/system/bin/valgrind -v --fair-sched=try --trace-children=yes --error-limit=no --smc-check=all-non-file" exec /system/bin/b2g.sh'

