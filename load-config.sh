#!/bin/bash

. .config
if [ $? -ne 0 ]; then
	echo Could not load .config. Did you run config.sh?
	exit -1
fi

if [ -f "$HOME/.b2g_config" ]; then
    . "$HOME/.b2g_config"
fi
