#!/bin/bash

#set -x

SCRIPT_NAME=$(basename $0)

ADB=adb

set_recording() {
  PREFS_JS=$(adb shell echo -n "/data/b2g/mozilla/*.default")/prefs.js
  $ADB pull $PREFS_JS
  echo "user_pref(\"gfx.2d.recording\", $1);" >> prefs.js
  $ADB push prefs.js $PREFS_JS
}

HELP_start="Restart b2g with moz2d draw call recording."
cmd_start() {
  echo "Stopping b2g"
  $ADB shell stop b2g
  $ADB shell rm "/data/local/tmp/moz2drec_*.aer"
  set_recording "true"
  echo "Restarting"
  $ADB shell start b2g
  echo "TIP: Close the application before invoking moz2d-record.sh stop"
}

HELP_stop="Restart b2g without recording and pull the files."
cmd_stop() {
  echo "Stopping b2g"
  $ADB shell stop b2g
  echo "Pulling recording(s)"
  $ADB shell ls "/data/local/tmp/moz2drec_*.aer" | tr -d '\r' | xargs -n1 $ADB pull
  $ADB shell rm "/data/local/tmp/moz2drec_*.aer"
  set_recording "false"
  echo "Restarting"
  $ADB shell start b2g
}

HELP_clean="Clean the moz2drec files."
cmd_clean() {
  rm moz2drec_*.aer
}
###########################################################################
#
# Display a brief help message for each supported command
#
HELP_help="Shows these help messages"
cmd_help() {
  if [ "$1" == "" ]; then
    echo "Usage: ${SCRIPT_NAME} command [args]"
    echo "where command is one of:"
    for command in ${allowed_commands}; do
      desc=HELP_${command}
      printf "  %-11s %s\n" ${command} "${!desc}"
    done
  else
    command=$1
    if [ "${allowed_commands/*${command}*/${command}}" == "${command}" ]; then
      desc=HELP_${command}
      printf "%-11s %s\n" ${command} "${!desc}"
    else
      echo "Unrecognized command: '${command}'"
    fi
  fi
}

#
# Determine if the first argument is a valid command and execute the
# corresponding function if it is.
#
allowed_commands=$(declare -F | sed -ne 's/declare -f cmd_\(.*\)/\1/p' | tr "\n" " ")
command=$1
if [ "${command}" == "" ]; then
  cmd_help
  exit 0
fi
if [ "${allowed_commands/*${command}*/${command}}" == "${command}" ]; then
  shift
  cmd_${command} "$@"
else
  echo "Unrecognized command: '${command}'"
fi

