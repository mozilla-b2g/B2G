#!/bin/bash

B2G_DIR=$(cd `dirname $0`/..; pwd)
. $B2G_DIR/load-config.sh

# Use default Gecko location if it's not provided in .config.
if [ -z $GECKO_PATH ]; then
  GECKO_PATH=$B2G_DIR/gecko
fi

VIRTUAL_ENV_VERSION="49f40128a9ca3824ebf253eca408596e135cf893"
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
MARIONETTE_HOME=$GECKO_PATH/testing/marionette/client/
PYTHON=`which python`

VENV_DIR="marionette_venv"
if [ -z $GECKO_OBJDIR ]
then
  VENV_DIR="$MARIONETTE_DIR/$VENV_DIR"
else
  VENV_DIR="$GECKO_OBJDIR/$VENV_DIR"
fi

if [ -d $VENV_DIR ]
then
  echo "Using virtual environment in $VENV_DIR"
else
  echo "Creating a virtual environment in $VENV_DIR"
  curl https://raw.github.com/pypa/virtualenv/${VIRTUAL_ENV_VERSION}/virtualenv.py | ${PYTHON} - $VENV_DIR
fi
. $VENV_DIR/bin/activate

cd $MARIONETTE_HOME
python setup.py develop

set -e
if [ ! -d "$TEST_PACKAGE_STAGE_DIR" ]; then
  cd $GECKO_OBJDIR
  make package-tests
fi

set -x
cd $TEST_PACKAGE_STAGE_DIR/xpcshell
$VENV_DIR/bin/python runtestsb2g.py $XPCSHELL_FLAGS $@
