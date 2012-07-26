#!/bin/bash

. load-config.sh

ADB=adb
GDB=${GDB:-prebuilt/`uname -s | tr "[[:upper:]]" "[[:lower:]]"`-x86/toolchain/arm-linux-androideabi-4.4.x/bin/arm-linux-androideabi-gdb}
B2G_BIN=/system/b2g/b2g
GDBINIT=/tmp/b2g.gdbinit.`whoami`

GONK_OBJDIR=out/target/product/$DEVICE
SYMDIR=$GONK_OBJDIR/symbols

GDBSERVER_PID=`$ADB shell toolbox ps |
               grep "gdbserver" | awk '{ print \$2; }'`

GDB_PORT=$((10000 + $(id -u) % 50000))
if [ "$1" = "attach"  -a  -n "$2" ] ; then
   B2G_PID=$2
   if [ -z "$($ADB ls /proc/$B2G_PID)" ] ; then
      echo Error: PID $B2G_PID is invalid
      exit 1;
   fi
   GDB_PORT=$((10000 + ($B2G_PID + $(id -u)) % 50000))
   # cmdline is null separated
   B2G_BIN=`$ADB shell cat /proc/$B2G_PID/cmdline | awk 'BEGIN{FS="\0"}{ print \$1; }'`
else
   B2G_PID=`$ADB shell toolbox ps | grep "b2g" | awk '{ print \$2; }'`
fi

for p in $GDBSERVER_PID ; do
   $ADB shell cat /proc/$p/cmdline | grep -q :$GDB_PORT && ( \
      echo ..killing gdbserver pid $p
      $ADB shell kill $p
   ) || echo ..ignoring gdbserver pid $p

done

$ADB forward tcp:$GDB_PORT tcp:$GDB_PORT

if [ "$1" = "attach" ]; then
   if [ -z $B2G_PID ]; then
      echo Error: No PID to attach to. B2G not running?
      exit 1
   fi

   $ADB shell gdbserver :$GDB_PORT --attach $B2G_PID &
else
   if [ -n "$1" ]; then
      B2G_BIN=$1
      shift
   fi
   [ -n "$MOZ_DEBUG_CHILD_PROCESS" ] && GDBSERVER_ENV="$GDBSERVER_ENV MOZ_DEBUG_CHILD_PROCESS=$MOZ_DEBUG_CHILD_PROCESS "
   [ -n "$MOZ_IPC_MESSAGE_LOG" ]     && GDBSERVER_ENV="$GDBSERVER_ENV MOZ_IPC_MESSAGE_LOG=$MOZ_IPC_MESSAGE_LOG "
   $ADB shell kill $B2G_PID
   [ "$B2G_BIN" = "/system/b2g/b2g" ] && $ADB shell stop b2g
   $ADB shell LD_LIBRARY_PATH=/system/b2g $GDBSERVER_ENV gdbserver --multi :$GDB_PORT $B2G_BIN $@ &
fi

sleep 1
echo "set solib-absolute-prefix $SYMDIR" > $GDBINIT
echo "set solib-search-path $GECKO_OBJDIR/dist/bin:$SYMDIR/system/lib:$SYMDIR/system/lib/hw:$SYMDIR/system/lib/egl:$SYMDIR/system/bin:$GONK_OBJDIR/system/lib:$GONK_OBJDIR/system/lib/egl:$GONK_OBJDIR/system/lib/hw:$GONK_OBJDIR/system/vendor/lib:$GONK_OBJDIR/system/vendor/lib/hw:$GONK_OBJDIR/system/vendor/lib/egl" >> $GDBINIT
echo "target extended-remote :$GDB_PORT" >> $GDBINIT

PROG=$GECKO_OBJDIR/dist/bin/$(basename $B2G_BIN)
[ -f $PROG ] || PROG=${SYMDIR}${B2G_BIN}

echo $GDB -x $GDBINIT $PROG
$GDB -x $GDBINIT $PROG
