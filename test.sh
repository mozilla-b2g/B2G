#!/bin/bash

B2G_HOME=$(dirname $BASH_SOURCE)

usage() {
    echo "Usage: $0 [marionette|mochitest|updates|xpcshell] (frontend-args)"
    echo ""
    echo "'marionette' is the default frontend"
}

FRONTEND=$1
if [ -z "$FRONTEND" ]; then
  FRONTEND=marionette
else
  shift
fi

case "$FRONTEND" in
  mochitest)
    echo "Use ./mach mochitest-remote to run tests;"
    echo "use ./mach help mochitest-remote for options." ;;
  marionette)
    echo "Use ./mach marionette-webapi to run tests;"
    echo "use ./mach help mochitest-webapi for options." ;;
  updates)
    SCRIPT=$B2G_HOME/scripts/updates.sh ;;
  xpcshell)
    SCRIPT=$B2G_HOME/scripts/xpcshell.sh ;;
  --help|-h|help)
    usage
    exit 0;;
  *)
    usage
    echo "Error: Unknown test frontend: $FRONTEND" 1>&2
    exit 1
esac

echo $SCRIPT $@
$SCRIPT $@
