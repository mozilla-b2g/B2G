#!/bin/bash

. .config
if [ $? -ne 0 ]; then
	echo Could not load .config. Did you run config.sh?
	exit -1
fi

ADB=adb
GDB_PORT=22576
GDB=prebuilt/`uname -s | tr "[[:upper:]]" "[[:lower:]]"`-x86/toolchain/arm-linux-androideabi-4.4.x/bin/arm-linux-androideabi-gdb
B2G_BIN=/system/b2g/b2g
GDBINIT=/tmp/b2g.gdbinit.`whoami`

GONK_OBJDIR=out/target/product/$DEVICE
SYMDIR=$GONK_OBJDIR/symbols

echo "set solib-absolute-prefix $SYMDIR" > $GDBINIT
echo "set solib-search-path $GECKO_OBJDIR/dist/bin:$SYMDIR/system/lib:$SYMDIR/system/lib/hw:$SYMDIR/system/lib/egl:$GONK_OBJDIR/system/lib:$GONK_OBJDIR/system/lib/egl:$GONK_OBJDIR/system/lib/hw:$GONK_OBJDIR/system/vendor/lib:$GONK_OBJDIR/system/vendor/lib/hw:$GONK_OBJDIR/system/vendor/lib/egl" >> $GDBINIT
echo "target extended-remote :$GDB_PORT" >> $GDBINIT

GDBSERVER_PID=`$ADB shell toolbox ps |
               grep "gdbserver" | awk '{ print \$2; }'`
B2G_PID=`$ADB shell toolbox ps |
         grep "b2g" | awk '{ print \$2; }'`

$ADB forward tcp:$GDB_PORT tcp:$GDB_PORT
[ -n "$GDBSERVER_PID" ] && $ADB shell kill $GDBSERVER_PID

if [ "$1" = "attach" ]; then
	$ADB shell gdbserver :$GDB_PORT --attach $B2G_PID &
else
	$ADB shell kill $B2G_PID
	$ADB shell stop b2g
	$ADB shell LD_LIBRARY_PATH=/system/b2g gdbserver --multi :$GDB_PORT $B2G_BIN &
fi

sleep 1
$GDB -x $GDBINIT $GECKO_OBJDIR/dist/bin/b2g
