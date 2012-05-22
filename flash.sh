#!/bin/bash

. load-config.sh

ADB=${ADB:-adb}
FASTBOOT=${FASTBOOT:-fastboot}
HEIMDALL=${HEIMDALL:-heimdall}

if [ ! -f "`which \"$ADB\"`" ]; then
	ADB=out/host/`uname -s | tr "[[:upper:]]" "[[:lower:]]"`-x86/bin/adb
fi
if [ ! -f "`which \"$FASTBOOT\"`" ]; then
	FASTBOOT=out/host/`uname -s | tr "[[:upper:]]" "[[:lower:]]"`-x86/bin/fastboot
fi

update_time()
{
	if [ `uname` = Darwin ]; then
		echo On OSX - Assuming PDT
		TIMEZONE="PDT+07"
	else
		TIMEZONE=`date +%Z%:::z|tr +- -+`
	fi
	echo Attempting to set the time on the device
	$ADB wait-for-device &&
	$ADB shell toolbox date `date +%s` &&
	$ADB shell setprop persist.sys.timezone $TIMEZONE
}

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
		$FASTBOOT reboot &&
		update_time
		;;
	esac
	echo -ne \\a
}

flash_heimdall()
{
	if [ ! -f "`which \"$HEIMDALL\"`" ]; then
		echo Couldn\'t find heimdall.
		echo Install Heimdall v1.3.1 from http://www.glassechidna.com.au/products/heimdall/
		exit -1
	fi

	$ADB reboot download && sleep 8
	if [ $? -ne 0 ]; then
		echo Couldn\'t reboot into download mode. Hope you\'re already in download mode
	fi

	case $1 in
	"system")
		$HEIMDALL flash --factoryfs out/target/product/$DEVICE/$1.img
		;;

	"kernel")
		$HEIMDALL flash --kernel device/samsung/$DEVICE/kernel
		;;

	*)
		$HEIMDALL flash --factoryfs out/target/product/$DEVICE/system.img --kernel device/samsung/$DEVICE/kernel &&
		update_time
		;;
	esac

	ret=$?
	echo -ne \\a
	if [ $ret -ne 0 ]; then
		echo Heimdall flashing failed.
		case "`uname`" in
		"Darwin")
			if kextstat | grep com.devguru.driver.Samsung > /dev/null ; then
				echo Kies drivers found.
				echo Uninstall kies completely and restart your system.
			else
				echo Restart your system if you\'ve just installed heimdall.
			fi
			;;
		"Linux")
			echo Make sure you have a line like
			echo SUBSYSTEM==\"usb\", ATTRS{idVendor}==\"04e8\", MODE=\"0666\"
			echo in /etc/udev/rules.d/android.rules
			;;
		esac
		exit -1
	fi

	echo Run \|./flash.sh gaia\| if you wish to install or update gaia.
}

case "$1" in
"gecko")
	$ADB remount &&
	$ADB push $GECKO_OBJDIR/dist/b2g /system/b2g &&
	echo Restarting B2G &&
	$ADB shell stop b2g &&
	$ADB shell start b2g &&
	exit $?
	;;

"gaia")
	make -C gaia install-gaia ADB="$ADB"
	exit $?
	;;

"time")
	update_time
	exit $?
	;;
esac

case "$DEVICE" in
"maguro")
	flash_fastboot $1
	;;

"crespo")
	flash_fastboot $1
	;;

"galaxys2")
	flash_heimdall $1
	;;

*)
	if [[ $(type -t flash_${DEVICE}) = function ]]; then
		flash_${DEVICE} $1
	else
		echo Unsupported device \"$DEVICE\", can\'t flash
		exit -1
	fi
	;;
esac
