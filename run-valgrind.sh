#!/bin/bash
#set -xv

SCRIPT_NAME=$(basename $0)

. load-config.sh

ADB=${ADB:-adb}
if [ ! -f "`which \"$ADB\"`" ]; then
	ADB=out/host/`uname -s | tr "[[:upper:]]" "[[:lower:]]"`-x86/bin/adb
fi
echo "ADB Location: " $ADB
B2G_DIR="/data/valgrind-b2g"

HAS_VALGRIND=$($ADB shell 'test -e /system/bin/valgrind ; echo -n $?')

# Make sure valgrind is actually on system
if [ "$HAS_VALGRIND" -ne 0 ]; then
    echo "Platform does not have valgrind executable, did you build with B2G_VALGRIND=1 in your .userconfig?"
    exit 1
fi

LIBMOZGLUE="$GECKO_OBJDIR/mozglue/build/libmozglue.so"
LIBXUL="$GECKO_OBJDIR/toolkit/library/build/libxul.so"
if [ ! -e "$LIBXUL" ]; then
  # try the old location
  LIBXUL="$GECKO_OBJDIR/toolkit/library/libxul.so"
fi

# Load libxul
if [ "$1" = "debuginfo" ]; then
  echo "Recompiling libxul.so with debug info (this can take a few minutes)"
  $ADB remount
  $ADB shell "rm -rf $B2G_DIR && cp -r /system/b2g $B2G_DIR"
  cp "$LIBXUL" "$GECKO_OBJDIR/toolkit/library/libxul.debuginfo.so"

  STRIP=prebuilts/gcc/`uname -s | tr "[[:upper:]]" "[[:lower:]]"`-x86/arm/arm-linux-androideabi-4.7/bin/arm-linux-androideabi-strip
  $STRIP -R .debug_info "$GECKO_OBJDIR/toolkit/library/libxul.debuginfo.so"
  echo "Pushing debug libxul to phone (this takes about a minute)"
  time $ADB push $GECKO_OBJDIR/toolkit/library/libxul.debuginfo.so $B2G_DIR/libxul.so
  shift
elif [ "$1" = "nocopy" ]; then
  echo "Skipping libxul.so copy step and just running valgrind..."
  shift
else
  $ADB remount
  $ADB shell "rm -rf $B2G_DIR && cp -r /system/b2g $B2G_DIR"

  # compress first, to limit amount of data pushed over the slow pipe
  # Compressing at level 3 or greater increases compression time a lot
  # without having much effect on resulting file size, and so is a net loss.
  echo "Compressing libxul.so..."
  time gzip -2 < "$LIBXUL" > $GECKO_OBJDIR/toolkit/library/libxul.so.gz

  echo "Pushing compressed debug libxul to device (this can take upwards of 5 minutes)"
  time $ADB push $GECKO_OBJDIR/toolkit/library/libxul.so.gz $B2G_DIR/libxul.so.gz
  time $ADB push "$LIBMOZGLUE" $B2G_DIR/libmozglue.so

  echo "Decompressing on phone..."
  time $ADB shell "gzip -d $B2G_DIR/libxul.so.gz"
  $ADB shell "chmod 0755 $B2G_DIR/libxul.so"
  $ADB shell "chmod 0755 $B2G_DIR/libmozglue.so"
fi

#$ADB reboot
$ADB wait-for-device
$ADB shell stop b2g

CORE_ARGS=""
if [ "$1" = "vgdb" ]; then
  # delete stale vgdb pipes
  $ADB shell rm /data/local/tmp/vgdb*
  CORE_ARGS="--trace-children=no --vgdb-error=0 --vgdb=yes"
else
  CORE_ARGS="--trace-children=yes"
fi

# Flags for the Valgrind core -- applicable to all tools.
#
# The --px- flags control precise exceptions.  They are mandatory for Gecko.
CORE_ARGS="$CORE_ARGS --px-default=allregs-at-mem-access"
CORE_ARGS="$CORE_ARGS --px-file-backed=unwindregs-at-mem-access"
# Show source paths relative to the source tree root
CORE_ARGS="$CORE_ARGS --fullpath-after=`pwd`/"
# Read full debuginfo for libraries, if available
CORE_ARGS="$CORE_ARGS --extra-debuginfo-path=/sdcard/symbols-for-valgrind"
# Specify what GPU the device has.
CORE_ARGS="$CORE_ARGS --kernel-variant=android-gpu-adreno3xx"
# Other flags
CORE_ARGS="$CORE_ARGS --error-limit=no --fair-sched=yes"

# Flags for Memcheck.
#
MC_ARGS=""
# Not necessary for a --disable-jemalloc build, but ..
MC_ARGS="$MC_ARGS --soname-synonyms=somalloc=libmozglueZdso"
# Avoid a lot of pointless noise.
MC_ARGS="$MC_ARGS --show-mismatched-frees=no --partial-loads-ok=yes"
# Avoid segfaulting Gecko until such time as bug 1166724 is fixed
MC_ARGS="$MC_ARGS --malloc-fill=0x00"
# Say what we expect the average translation size to be.  Getting this
# right can save tens of megabytes of RAM on the phone.
MC_ARGS="$MC_ARGS --avg-transtab-entry-size=400"
# Request 11 sectors for translation storage.  More sectors improves
# performance but costs a lot of memory.
MC_ARGS="$MC_ARGS --num-transtab-sectors=11"

# Gather them all together.  EXTRA_ARGS allows users to pass in extra
# arguments on the command line.
VALGRIND_ARGS="$CORE_ARGS $MC_ARGS $EXTRA_ARGS"

# Due to the fact that we follow forks, we can't log to a logfile. Expect the
# user to redirect stdout.
$ADB shell "B2G_DIR='/data/valgrind-b2g' HOSTNAME='b2g' LOGNAME='b2g' COMMAND_PREFIX='/system/bin/valgrind $VALGRIND_ARGS' exec /system/bin/b2g.sh"

