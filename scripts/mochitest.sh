#!/bin/bash

B2G_DIR=$(cd `dirname $0`/..; pwd)
. $B2G_DIR/load-config.sh

# Use default Gecko location if it's not provided in .config.
if [ -z $GECKO_PATH ]; then
  GECKO_PATH=$B2G_DIR/gecko
fi

XRE_PATH=$B2G_DIR/gaia/xulrunner-sdk/bin
MOCHITEST_FLAGS+="--b2gpath $B2G_DIR --xre-path $XRE_PATH"
SCRIPT=$GECKO_PATH/testing/marionette/client/marionette/venv_mochitest.sh

PYTHON=`which python`

echo bash $SCRIPT "$PYTHON" $MOCHITEST_FLAGS $@
GECKO_OBJDIR=$GECKO_OBJDIR \
  bash $SCRIPT "$PYTHON" $MOCHITEST_FLAGS $@
