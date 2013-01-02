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
TEST_PATH=$GECKO_PATH/testing/marionette/client/marionette/tests/update-tests.ini
MARIONETTE_FLAGS+=" --homedir=$B2G_DIR --type=b2g-smoketest"

while [ $# -gt 0 ]; do
  case "$1" in
    --*)
      MARIONETTE_FLAGS+=" $1" ;;
    *)
      MARIONETTE_TESTS+=" $1" ;;
  esac
  shift
done

MARIONETTE_TESTS=${MARIONETTE_TESTS:-$TEST_PATH}
echo "Running tests: $MARIONETTE_TESTS"

SCRIPT=$GECKO_PATH/testing/marionette/client/marionette/venv_b2g_update_test.sh
PYTHON=${PYTHON:-`which python`}

echo bash $SCRIPT "$PYTHON" $MARIONETTE_FLAGS $MARIONETTE_TESTS
bash $SCRIPT "$PYTHON" $MARIONETTE_FLAGS $MARIONETTE_TESTS
