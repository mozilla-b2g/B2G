#!/bin/bash

. load-config.sh

LUNCH=${LUNCH:-full_${DEVICE}-eng}

export USE_CCACHE=yes &&
export GECKO_PATH &&
export GAIA_PATH &&
export GAIA_DOMAIN &&
export GAIA_PORT &&
export GAIA_DEBUG &&
export GECKO_OBJDIR &&
. build/envsetup.sh &&
lunch $LUNCH
