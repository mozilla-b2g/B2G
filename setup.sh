#!/bin/bash

. .config
if [ $? -ne 0 ]; then
	echo Could not load .config. Did you run config.sh?
	exit -1
fi

if [ $DEVICE = "generic" ]; then
	LUNCH=generic-eng
else
	LUNCH=full_${DEVICE}-eng
fi

export USE_CCACHE=yes &&
export GECKO_OBJDIR &&
. build/envsetup.sh &&
lunch $LUNCH
