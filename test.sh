#!/bin/bash

. setup.sh

# Determine the absolute path of our location.
B2G_HOME=`dirname $0`
pushd $B2G_HOME && B2G_HOME=$PWD && popd

# Run standard set of tests by default. Command line arguments can be
# specified to run specific tests (an individual test file, a directory,
# or an .ini file).
TEST_PATH=$GECKO_PATH/testing/marionette/client/marionette/tests/unit-tests.ini
if [ "$#" -gt 0 ]; then
  TEST_PATH=$@
fi
echo "Running tests from $TEST_PATH"

cd $GECKO_PATH/testing/marionette/client/marionette &&
sh venv_test.sh `which python` --emulator --homedir=$B2G_HOME --type=b2g $TEST_PATH
