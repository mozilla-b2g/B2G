#!/bin/bash

B2G_DIR=$(cd `dirname $0`; pwd)

. "$B2G_DIR/.config"
if [ $? -ne 0 ]; then
	echo Could not load .config. Did you run config.sh?
	exit -1
fi

if [ -f "$B2G_DIR/.userconfig" ]; then
    . "$B2G_DIR/.userconfig"
fi
