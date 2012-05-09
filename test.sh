#!/bin/bash

. setup.sh

# Determine the absolute path of our location.
B2G_HOME=`dirname $0`
pushd $B2G_HOME && B2G_HOME=$PWD && popd

# Use default Gecko location if it's not provided in .config.
if [ -z $GECKO_PATH ]; then
  GECKO_PATH=gecko
fi

# Run standard set of tests by default. Command line arguments can be
# specified to run specific tests (an individual test file, a directory,
# or an .ini file).
TEST_PATH=$GECKO_PATH/testing/marionette/client/marionette/tests/unit-tests.ini
if [ "$#" -gt 0 ]; then
  TEST_PATH=$@
fi
echo "Running tests from $TEST_PATH"

SCRIPT=$GECKO_PATH/testing/marionette/client/marionette/venv_test.sh
bash $SCRIPT `which python` --emulator --homedir=$B2G_HOME --type=b2g $TEST_PATH
