#!/bin/bash

. .config
if [ $? -ne 0 ]; then
	echo Could not load .config. Did you run config.sh?
	exit -1
fi

ADB=${ADB:-adb}
FASTBOOT=${FASTBOOT:-fastboot}
HEIMDALL=${HEIMDALL:-heimdall}

if [ ! -f "`which \"$ADB\"`" ]; then
	ADB=out/host/`uname -s | tr "[[:upper:]]" "[[:lower:]]"`-x86/bin/adb
fi
if [ ! -f "`which \"$FASTBOOT\"`" ]; then
	FASTBOOT=out/host/`uname -s | tr "[[:upper:]]" "[[:lower:]]"`-x86/bin/fastboot
fi

flash_fastboot()
{
	$ADB reboot bootloader ;
	$FASTBOOT devices &&
	( $FASTBOOT oem unlock || true )

	if [ $? -ne 0 ]; then
		echo Couldn\'t setup fastboot
		return -1
	fi
	case $1 in
	"system" | "boot" | "userdata")
		$FASTBOOT flash $1 out/target/product/$DEVICE/$1.img &&
		$FASTBOOT reboot
		;;

	*)
		$FASTBOOT erase cache &&
		$FASTBOOT erase userdata &&
		$FASTBOOT flash userdata out/target/product/$DEVICE/userdata.img &&
		$FASTBOOT flash boot out/target/product/$DEVICE/boot.img &&
		$FASTBOOT flash system out/target/product/$DEVICE/system.img &&
		$FASTBOOT reboot
		;;
	esac
}

flash_heimdall()
{
	if [ ! -f "`which \"$HEIMDALL\"`" ]; then
		echo Couldn\'t find heimdall.
		exit -1
	fi

	$ADB reboot download || echo Couldn\'t reboot into download mode. Hope you\'re already in download mode
	sleep 8

	case $1 in
	"system")
		$HEIMDALL flash --factoryfs out/target/product/$DEVICE/$1.img
		;;

	"kernel")
		$HEIMDALL flash --kernel device/samsung/$DEVICE/kernel
		;;

	*)
		$HEIMDALL flash --factoryfs out/target/product/$DEVICE/system.img --kernel device/samsung/$DEVICE/kernel
		;;
	esac
}

update_time()
{
	echo Attempting to set the time on the device
	$ADB wait-for-device &&
	$ADB shell toolbox date `date +%s` &&
	$ADB shell setprop persist.sys.timezone `date +%Z%:::z|tr +- -+`
}

case "$1" in
"gecko")
	$ADB remount &&
	$ADB push $GECKO_OBJDIR/dist/b2g /system/b2g
	$ADB shell stop b2g
	$ADB shell start b2g
	exit $?
	;;

"gaia")
	make -C gaia install-gaia
	exit $?
	;;
esac

case "$DEVICE" in
"maguro")
	flash_fastboot $1 &&
	update_time
	;;

"crespo")
	flash_fastboot $1 &&
	update_time
	;;

"galaxys2")
	flash_heimdall $1
	;;

*)
	echo Unsupported device \"$DEVICE\", can\'t flash
	exit -1
	;;
esac
