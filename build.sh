#!/bin/bash

. setup.sh &&
time nice -n19 make $MAKE_FLAGS $@
