#!/bin/bash

echo "* Automated testing with orangutan *"
echo "You might want to disable phone calls and sending sms:"
echo "Look at https://github.com/gregorwagner/gaia/tree/monkey"

SCRIPT_NAME=orangutan-script
ORNG_PATH=/data
SCRIPT_PATH=/mnt/sdcard
ADB=${ADB:-adb}
orangutan="$ORNG_PATH/orng"
ifstmt="test -x $orangutan && echo '1'"
status="$(${ADB} shell $ifstmt)"
if [ -z "$status" ]; then
  echo "$orangutan does not exist! Install from https://github.com/wlach/orangutan and push orng to /data"
  exit
fi

if [ $# -eq 1 ]; then
  steps=$1
else
  steps=100000
fi

PYTHON=${PYTHON:-`which python`}
$PYTHON generate-orangutan-script.py --steps $steps >$SCRIPT_NAME
$ADB push $SCRIPT_NAME $SCRIPT_PATH
echo "Running the script..."
$ADB shell $orangutan /dev/input/event0 $SCRIPT_PATH/$SCRIPT_NAME
$ADB shell rm $SCRIPT_PATH/$SCRIPT_NAME
echo "Done"
