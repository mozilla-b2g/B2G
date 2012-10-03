#!/bin/bash

B2G_HOME=$(cd `dirname $0`; pwd)

usage() {
    echo "Usage: $0 [marionette|mochitest]"
    echo ""
    echo "'marionette' is the default frontend"
}

if [[ "$1" = "--help" ]]; then
  usage
  exit 0
fi

FRONTEND=${1:-marionette}
shift

case "$FRONTEND" in
  mochitest)
    SCRIPT=$B2G_HOME/scripts/mochitest.sh ;;
  marionette)
    SCRIPT=$B2G_HOME/scripts/marionette.sh ;;
  *)
    usage
    echo "Error: Unknown test frontend: $FRONTEND" 1>&2
    exit 1
esac

echo $SCRIPT $@
$SCRIPT $@
