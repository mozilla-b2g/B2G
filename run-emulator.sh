#!/bin/sh
B2G_HOME=$PWD

DBG_CMD=""
if [ x"$DBG" != x"" ]; then
   DBG_CMD="gdb -args"
fi
TAIL_ARGS=""
if [ x"$GDBSERVER" != x"" ]; then
   TAIL_ARGS="$TAIL_ARGS -s -S"
fi

TOOLS_PATH=$B2G_HOME/out/host/`uname -s | tr "[[:upper:]]" "[[:lower:]]"`-x86/bin

export PATH=$PATH:$TOOLS_PATH
${DBG_CMD} $TOOLS_PATH/emulator \
   -kernel $B2G_HOME/prebuilts/qemu-kernel/arm/kernel-qemu-armv7 \
   -sysdir $B2G_HOME/out/target/product/generic/ \
   -data $B2G_HOME/out/target/product/generic/userdata.img \
   -memory 512 \
   -partition-size 512 \
   -skindir $B2G_HOME/development/tools/emulator/skins \
   -skin WVGA854 \
   -verbose \
   -qemu -cpu 'cortex-a8' $TAIL_ARGS
