#!/bin/bash

# Determine the absolute path of our location.
B2G_DIR=$(cd `dirname $0`/..; pwd)
. $B2G_DIR/setup.sh

# Use default Gecko location if it's not provided in .config.
if [ -z $GECKO_PATH ]; then
  GECKO_PATH=$B2G_DIR/gecko
fi

# Run standard set of tests by default. Command line arguments can be
# specified to run specific tests (an individual test file, a directory,
# or an .ini file).
TEST_PATH=$GECKO_PATH/testing/marionette/client/marionette/tests/unit-tests.ini
MARIONETTE_FLAGS+=" --homedir=$B2G_DIR --type=b2g"
USE_EMULATOR=yes

# Allow other marionette arguments to override the default --emulator argument
while [ $# -gt 0 ]; do
  case "$1" in
    --address=*|--emulator=*)
      MARIONETTE_FLAGS+=" $1"
      USE_EMULATOR=no ;;
    --*)
      MARIONETTE_FLAGS+=" $1" ;;
    *)
      MARIONETTE_TESTS+=" $1" ;;
  esac
  shift
done

if [ "$USE_EMULATOR" = "yes" ]; then
  if [ "$DEVICE" = "generic_x86" ]; then
    ARCH=x86
  else
    ARCH=arm
  fi
  MARIONETTE_FLAGS+=" --emulator=$ARCH"
fi

MARIONETTE_TESTS=${MARIONETTE_TESTS:-$TEST_PATH}

echo "Running tests: $MARIONETTE_TESTS"

SCRIPT=$GECKO_PATH/testing/marionette/client/marionette/venv_test.sh
PYTHON=`which python`

echo bash $SCRIPT "$PYTHON" $MARIONETTE_FLAGS $MARIONETTE_TESTS
bash $SCRIPT "$PYTHON" $MARIONETTE_FLAGS $MARIONETTE_TESTS
