#!/bin/bash

B2G_DIR=$(cd `dirname $0`/..; pwd)
. $B2G_DIR/load-config.sh

# Use default Gecko location if it's not provided in .config.
if [ -z $GECKO_PATH ]; then
  GECKO_PATH=$B2G_DIR/gecko
fi

BUSYBOX=$B2G_DIR/gaia/build/busybox-armv6l
TEST_PACKAGE_STAGE_DIR=$GECKO_OBJDIR/dist/test-package-stage
TESTING_MODULES_DIR=$TEST_PACKAGE_STAGE_DIR/modules

XPCSHELL_FLAGS+=" --b2gpath $B2G_DIR \
                  --use-device-libs \
                  --busybox $BUSYBOX \
                  --testing-modules-dir $TESTING_MODULES_DIR"

OUT_HOST=$B2G_DIR/out/host/`uname -s | tr "[[:upper:]]" "[[:lower:]]"`-x86
ADB=${ADB:-$OUT_HOST/bin/adb}
XPCSHELL_FLAGS+=" --adbpath $ADB"

if [ "$DEVICE" = "generic" ]; then
  XPCSHELL_FLAGS+=" --emulator arm"
elif [ "$DEVICE" = "generic_x86" ]; then
  XPCSHELL_FLAGS+=" --emulator x86"
fi

XPCSHELL_MANIFEST=tests/xpcshell_b2g.ini
while [ $# -gt 0 ]; do
  case "$1" in
    --manifest)
      shift; XPCSHELL_MANIFEST=$1 ;;
    --manifest=*)
      XPCSHELL_MANIFEST=${1:11} ;;
    *)
      XPCSHELL_FLAGS+=" $1" ;;
  esac
  shift
done

XPCSHELL_FLAGS+=" --manifest $XPCSHELL_MANIFEST"
SCRIPT=$GECKO_PATH/testing/marionette/client/marionette/venv_mochitest.sh
PYTHON=`which python`

set -e
if [ ! -d "$TEST_PACKAGE_STAGE_DIR" ]; then
  cd $GECKO_OBJDIR
  make package-tests
fi

set -x
GECKO_OBJDIR=$GECKO_OBJDIR \
TEST_PWD=$TEST_PACKAGE_STAGE_DIR/xpcshell \
  bash $SCRIPT "$PYTHON" $XPCSHELL_FLAGS $@
