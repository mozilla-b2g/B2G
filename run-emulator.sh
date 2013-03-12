#!/bin/bash

# Get full path from where the script was executed, full path is needed to run emulator succesfully
B2G_HOME=$(cd $(dirname $BASH_SOURCE); pwd)

. $B2G_HOME/load-config.sh

DEVICE=${DEVICE:-generic}

TOOLS_PATH=$B2G_HOME/out/host/`uname -s | tr "[[:upper:]]" "[[:lower:]]"`-x86/bin

DBG_CMD=""
if [ x"$DBG" != x"" ]; then
    DBG_CMD="gdb -args"
fi
TAIL_ARGS=""
if [ x"$GDBSERVER" != x"" ]; then
    TAIL_ARGS="$TAIL_ARGS -s -S"
fi

if [ "$DEVICE" = "generic_x86" ]; then
    EMULATOR=$TOOLS_PATH/emulator-x86
    KERNEL=$B2G_HOME/prebuilts/qemu-kernel/x86/kernel-qemu
else
    EMULATOR=$TOOLS_PATH/emulator
    KERNEL=$B2G_HOME/prebuilts/qemu-kernel/arm/kernel-qemu-armv7
    TAIL_ARGS="$TAIL_ARGS -cpu cortex-a8"
fi

SDCARD_SIZE=${SDCARD_SIZE:-512M}
SDCARD_IMG=${SDCARD_IMG:-${B2G_HOME}/out/target/product/${DEVICE}/sdcard.img}

if [ ! -f "${SDCARD_IMG}" ]; then
  echo "Creating sdcard image file with size: ${SDCARD_SIZE} ..."
  ${TOOLS_PATH}/mksdcard -l sdcard ${SDCARD_SIZE} ${SDCARD_IMG}
fi

export DYLD_LIBRARY_PATH="$B2G_HOME/out/host/darwin-x86/lib"
export PATH=$PATH:$TOOLS_PATH
${DBG_CMD} $EMULATOR \
   -kernel $KERNEL \
   -sysdir $B2G_HOME/out/target/product/$DEVICE/ \
   -data $B2G_HOME/out/target/product/$DEVICE/userdata.img \
   -sdcard ${SDCARD_IMG} \
   -memory 512 \
   -partition-size 512 \
   -skindir $B2G_HOME/development/tools/emulator/skins \
   -skin HVGA \
   -verbose \
   -gpu on \
   -camera-back webcam0 \
   -qemu $TAIL_ARGS
