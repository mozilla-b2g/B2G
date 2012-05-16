#!/bin/bash

. setup.sh

# Determine the absolute path of our location.
B2G_HOME=$(cd `dirname $0`; pwd)

# Use default Gecko location if it's not provided in .config.
if [ -z $GECKO_PATH ]; then
  GECKO_PATH=$B2G_HOME/gecko
fi

# Run standard set of tests by default. Command line arguments can be
# specified to run specific tests (an individual test file, a directory,
# or an .ini file).
TEST_PATH=$GECKO_PATH/testing/marionette/client/marionette/tests/unit-tests.ini
if [ "$#" -gt 0 ]; then
  TEST_PATH=$@
fi
echo "Running tests from $TEST_PATH"

if [ "$DEVICE" = "generic_x86" ]; then
  ARCH=x86
else
  ARCH=arm
fi

SCRIPT=$GECKO_PATH/testing/marionette/client/marionette/venv_test.sh
bash $SCRIPT `which python` --emulator=$ARCH --homedir=$B2G_HOME --type=b2g $MARIONETTE_FLAGS $TEST_PATH
