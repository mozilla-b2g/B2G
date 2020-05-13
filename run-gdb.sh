#!/bin/bash
#set -x

get_pid_by_name() {
    pid=$($ADB shell "ps | grep '$1' | cut -b 14-19 | tr -d ' '")
    if [ -n "$pid" ]; then
        pid=$($ADB shell "ps -A | grep '$1' | cut -b 14-19 | tr -d ' '")
    fi
    echo $pid
}

SCRIPT_NAME=$(basename $0)
. load-config.sh

ADB=${ADB:-adb}
if [ ! -f "`which \"$ADB\" 2>/dev/null`" ]; then
	ADB=out/host/`uname -s | tr "[[:upper:]]" "[[:lower:]]"`-x86/bin/adb
fi
echo "ADB Location: " $ADB

# Make sure that the adb server is running and that it's compatible with the
# version of adb that we're using. Anytime you run adb it will kill the
# running server if there is a mismatch, and it will automatically start
# the server if it isn't running. Unfortunately, both of these activities
# cause information to be printed, which can screw up any further command
# which is trying to query information from the phone. So by starting
# the server explicitly here, then we'll cause that output to go to this
# command (which we ignore), and not wind up prepending output.
#
# For a clear example of this, try the following:
#
#   adb start-server
#   x1=$(adb shell echo test)
#   adb kill-server
#   x2=$(adb shell echo test)
#
# and then compare x1 and x2 by using:
#
#   echo "$x1"
#   echo "$x2"
$ADB start-server

case $DEVICE in
    aosp_x86_64)
        BINSUFFIX=64
        ;;
    *)
        BINSUFFIX=
        ;;
esac

HOST_OS=$(uname -s | tr "[[:upper:]]" "[[:lower:]]")
HOST_ARCH=$(uname -m | tr "[[:upper:]]" "[[:lower:]]")

if [ -z "${GDB}" ]; then
   if [ "${HOME}/.mozbuild/android-ndk-r20b-canary" ]; then
      GDB="${HOME}/.mozbuild/android-ndk-r20b-canary/prebuilt/${HOST_OS}-${HOST_ARCH}/bin/gdb"
   else
      echo "Not sure where gdb is located. Override using GDB= or fix the script."
      exit 1
   fi
fi

B2G_BIN=/system/b2g/b2g
GDBINIT=/tmp/b2g.gdbinit.$(whoami).$$

GONK_OBJDIR="out/target/product/$TARGET_NAME"
SYMDIR="$GONK_OBJDIR/symbols"

if [ "$1" != "core" ] ; then
   GDBSERVER_PID=$(get_pid_by_name gdbserver$BINSUFFIX)

   if [ "$1" = "vgdb"  -a  -n "$2" ] ; then
      GDB_PORT="$2"
   elif [ "$1" = "attach"  -a  -n "$2" ] ; then
      B2G_PID=$2
      if [ -z "$($ADB ls /proc/$B2G_PID)" ] ; then
         ATTACH_TARGET=$B2G_PID
         B2G_PID=$(get_pid_by_name "$B2G_PID")
         if [ -z "$B2G_PID" ] ; then
           echo Error: PID $ATTACH_TARGET is invalid
           exit 1;
         fi
         echo "Found $ATTACH_TARGET PID: $B2G_PID"
      fi
      PROCESS_PORT=$((10000 + ($B2G_PID + $(id -u)) % 50000))
      GDB_PORT=${GDB_PORT:-$PROCESS_PORT}
      # cmdline is null separated
      B2G_BIN=$($ADB shell "cat /proc/$B2G_PID/cmdline" | tr '\0' '\n' | head -1)
   else
      GDB_PORT=$((10000 + $(id -u) % 50000))
      B2G_PID=$(get_pid_by_name b2g)
   fi

   for p in $GDBSERVER_PID ; do
      $ADB shell "cat /proc/$p/cmdline" | grep -q :$GDB_PORT && ( \
         echo ..killing gdbserver pid $p
         $ADB shell "kill $p"
      ) || echo ..ignoring gdbserver pid $p

   done

   $ADB forward tcp:$GDB_PORT tcp:$GDB_PORT
fi

if [ "$1" = "attach" ]; then
   if [ -z "$B2G_PID" ]; then
      echo Error: No PID to attach to. B2G not running?
      exit 1
   fi

   $ADB shell "gdbserver$BINSUFFIX :$GDB_PORT --attach $B2G_PID" &
elif [ "$1" == "core" ]; then
   if [ -z "$3" ]; then
     CORE_FILE=$2
   else
     B2G_BIN=$2
     CORE_FILE=$3
   fi

   if [ "$B2G_BIN" == "" -o "$CORE_FILE" == "" ]; then
     echo "Usage: $SCRIPT_NAME core [bin] <core>"
     exit 1
   fi

   if [ ! -f $CORE_FILE ]; then
     echo "Error: $CORE_FILE not found."
     exit 1
   fi
elif [ "$1" != "vgdb" ]; then
   if [ -n "$1" ]; then
      B2G_BIN=$1
      shift
   fi
   [ -n "$MOZ_PROFILER_STARTUP" ] && GDBSERVER_ENV="$GDBSERVER_ENV MOZ_PROFILER_STARTUP=$MOZ_PROFILER_STARTUP "
   [ -n "$MOZ_DEBUG_CHILD_PROCESS" ] && GDBSERVER_ENV="$GDBSERVER_ENV MOZ_DEBUG_CHILD_PROCESS=$MOZ_DEBUG_CHILD_PROCESS "
   [ -n "$MOZ_DEBUG_APP_PROCESS" ] && GDBSERVER_ENV="$GDBSERVER_ENV MOZ_DEBUG_APP_PROCESS='$MOZ_DEBUG_APP_PROCESS' "
   [ -n "$MOZ_IPC_MESSAGE_LOG" ]     && GDBSERVER_ENV="$GDBSERVER_ENV MOZ_IPC_MESSAGE_LOG=$MOZ_IPC_MESSAGE_LOG "

   [ -n "$B2G_PID" ] && $ADB shell "kill $B2G_PID"
   [ "$B2G_BIN" = "/system/b2g/b2g" ] && $ADB shell "stop b2g"

   if [ "$($ADB shell 'if [ -f /system/b2g/libdmd.so ]; then echo 1; fi')" != "" ]; then
     echo ""
     echo "Using DMD."
     echo ""
     dmd="1"
     ld_preload_extra="/system/b2g/libdmd.so"
  fi

   $ADB shell "DMD=$dmd LD_LIBRARY_PATH=\"/system/b2g:/apex/com.android.runtime/lib$BINSUFFIX:/system/apex/com.android.runtime.debug/lib$BINSUFFIX\" LD_PRELOAD=\"$ld_preload_extra /system/b2g/libmozglue.so /system/b2g/libmozsandbox.so\" TMPDIR=/data/local/tmp $GDBSERVER_ENV gdbserver$BINSUFFIX --multi :$GDB_PORT $B2G_BIN $@" &
fi

sleep 1
echo "handle SIGPIPE nostop" >> $GDBINIT
echo "set solib-absolute-prefix $SYMDIR" > $GDBINIT
echo "set solib-search-path $GECKO_OBJDIR/dist/bin:$SYMDIR:$SYMDIR/apex/com.android.runtime.debug/bin:$SYMDIR/apex/com.android.runtime.debug/lib:$SYMDIR/apex/com.android.runtime.debug/lib$BINSUFFIX:$SYMDIR/apex/com.android.runtime.debug/lib$BINSUFFIX/bionic" >> $GDBINIT
if [ "$1" == "vgdb" ] ; then
  echo "target remote :$GDB_PORT" >> $GDBINIT
elif [ "$1" != "core" ]; then
  echo "target extended-remote :$GDB_PORT" >> $GDBINIT
fi

PROG=$GECKO_OBJDIR/dist/bin/$(basename $B2G_BIN)
[ -f $PROG ] || PROG=${SYMDIR}/${B2G_BIN}
[ -f $PROG ] || PROG=${B2G_BIN}
if [ ! -f $PROG ]; then
  echo "Error: program to debug not found:"
  echo "  $GECKO_OBJDIR/dist/bin/$(basename $B2G_BIN)"
  echo "  $SYMDIR/$B2G_BIN"
  echo "  $B2G_BIN"
  exit 1
fi

if [[ "$-" == *x* ]]; then
    # Since we got here, set -x was enabled near the top of the file. print
    # out the contents of of the gdbinit file.
    echo "----- Start of $GDBINIT -----"
    cat $GDBINIT
    echo "----- End of $GDBINIT -----"
fi

if [ "$SCRIPT_NAME" == "run-ddd.sh" ]; then
    echo "ddd --debugger \"$GDB -x $GDBINIT\" $PROG $CORE_FILE"
    ddd --debugger "$GDB -x $GDBINIT" $PROG $CORE_FILE
else
    echo $GDB -x $GDBINIT $PROG $CORE_FILE
    $GDB -x $GDBINIT $PROG $CORE_FILE
fi

