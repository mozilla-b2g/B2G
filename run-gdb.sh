#!/bin/bash
#set -x

get_pid_by_name() {
    echo $($ADB shell "toolbox ps '$1' | (read header; read user pid rest; echo -n \$pid)")
}

SCRIPT_NAME=$(basename $0)
. load-config.sh

ADB=adb
if [ -z "${GDB}" ]; then
   if [ -d prebuilt ]; then
      GDB=prebuilt/$(uname -s | tr "[[:upper:]]" "[[:lower:]]")-x86/toolchain/arm-linux-androideabi-4.4.x/bin/arm-linux-androideabi-gdb
   elif [ -d prebuilts ]; then
      GDB=prebuilts/gcc/$(uname -s | tr "[[:upper:]]" "[[:lower:]]")-x86/arm/arm-linux-androideabi-4.7/bin/arm-linux-androideabi-gdb
   else
      echo "Not sure where gdb is located. Override using GDB= or fix the script."
      exit 1
   fi
fi

B2G_BIN=/system/b2g/b2g
GDBINIT=/tmp/b2g.gdbinit.$(whoami).$$

GONK_OBJDIR=out/target/product/$DEVICE
SYMDIR=$GONK_OBJDIR/symbols

GDBSERVER_PID=$(get_pid_by_name gdbserver)

GDB_PORT=$((10000 + $(id -u) % 50000))
if [ "$1" = "attach"  -a  -n "$2" ] ; then
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
   GDB_PORT=$((10000 + ($B2G_PID + $(id -u)) % 50000))
   # cmdline is null separated
   B2G_BIN=$($ADB shell cat /proc/$B2G_PID/cmdline | tr '\0' '\n' | head -1)
else
   B2G_PID=$(get_pid_by_name b2g)
fi

for p in $GDBSERVER_PID ; do
   $ADB shell cat /proc/$p/cmdline | grep -q :$GDB_PORT && ( \
      echo ..killing gdbserver pid $p
      $ADB shell kill $p
   ) || echo ..ignoring gdbserver pid $p

done

$ADB forward tcp:$GDB_PORT tcp:$GDB_PORT

if [ "$1" = "attach" ]; then
   if [ -z "$B2G_PID" ]; then
      echo Error: No PID to attach to. B2G not running?
      exit 1
   fi

   $ADB shell gdbserver :$GDB_PORT --attach $B2G_PID &
else
   if [ -n "$1" ]; then
      B2G_BIN=$1
      shift
   fi
   [ -n "$MOZ_PROFILER_STARTUP" ] && GDBSERVER_ENV="$GDBSERVER_ENV MOZ_PROFILER_STARTUP=$MOZ_PROFILER_STARTUP "
   [ -n "$MOZ_DEBUG_CHILD_PROCESS" ] && GDBSERVER_ENV="$GDBSERVER_ENV MOZ_DEBUG_CHILD_PROCESS=$MOZ_DEBUG_CHILD_PROCESS "
   [ -n "$MOZ_DEBUG_APP_PROCESS" ] && GDBSERVER_ENV="$GDBSERVER_ENV MOZ_DEBUG_APP_PROCESS='$MOZ_DEBUG_APP_PROCESS' "
   [ -n "$MOZ_IPC_MESSAGE_LOG" ]     && GDBSERVER_ENV="$GDBSERVER_ENV MOZ_IPC_MESSAGE_LOG=$MOZ_IPC_MESSAGE_LOG "

   [ -n "$B2G_PID" ] && $ADB shell kill $B2G_PID
   [ "$B2G_BIN" = "/system/b2g/b2g" ] && $ADB shell stop b2g

   if [ "$($ADB shell "if [ -f /system/b2g/libdmd.so ]; then echo 1; fi")" != "" ]; then
     echo ""
     echo "Using DMD."
     echo ""
     dmd="1"
     ld_preload_extra="/system/b2g/libdmd.so"
  fi

   $ADB shell DMD=$dmd LD_LIBRARY_PATH=/system/b2g LD_PRELOAD=\"$ld_preload_extra /system/b2g/libmozglue.so\" TMPDIR=/data/local/tmp $GDBSERVER_ENV gdbserver --multi :$GDB_PORT $B2G_BIN $@ &
fi

sleep 1
echo "set solib-absolute-prefix $SYMDIR" > $GDBINIT
echo "handle SIGPIPE nostop" >> $GDBINIT
echo "set solib-search-path $GECKO_OBJDIR/dist/bin:$SYMDIR/system/lib:$SYMDIR/system/lib/hw:$SYMDIR/system/lib/egl:$SYMDIR/system/bin:$GONK_OBJDIR/system/lib:$GONK_OBJDIR/system/lib/egl:$GONK_OBJDIR/system/lib/hw:$GONK_OBJDIR/system/vendor/lib:$GONK_OBJDIR/system/vendor/lib/hw:$GONK_OBJDIR/system/vendor/lib/egl" >> $GDBINIT
echo "target extended-remote :$GDB_PORT" >> $GDBINIT

PROG=$GECKO_OBJDIR/dist/bin/$(basename $B2G_BIN)
[ -f $PROG ] || PROG=${SYMDIR}${B2G_BIN}

if [[ "$-" == *x* ]]; then
    # Since we got here, set -x was enabled near the top of the file. print
    # out the contents of of the gdbinit file.
    echo "----- Start of $GDBINIT -----"
    cat $GDBINIT
    echo "----- End of $GDBINIT -----"
fi

if [ "$SCRIPT_NAME" == "run-ddd.sh" ]; then
    echo "ddd --debugger \"$GDB -x $GDBINIT\" $PROG"
    ddd --debugger "$GDB -x $GDBINIT" $PROG
else
    echo $GDB -x $GDBINIT $PROG
    $GDB -x $GDBINIT $PROG
fi
