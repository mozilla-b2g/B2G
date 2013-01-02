#!/bin/bash

B2G_HOME=$(dirname $BASH_SOURCE)

usage() {
    echo "Usage: $0 [marionette|mochitest|updates] (frontend-args)"
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
    SCRIPT=$B2G_HOME/scripts/mochitest.sh ;;
  marionette)
    SCRIPT=$B2G_HOME/scripts/marionette.sh ;;
  updates)
    SCRIPT=$B2G_HOME/scripts/updates.sh ;;
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
