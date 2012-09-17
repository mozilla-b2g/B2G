#!/bin/bash

. load-config.sh

ADB=${ADB:-adb}
FASTBOOT=${FASTBOOT:-fastboot}
HEIMDALL=${HEIMDALL:-heimdall}
VARIANT=${VARIANT:-eng}

if [ ! -f "`which \"$ADB\"`" ]; then
	ADB=out/host/`uname -s | tr "[[:upper:]]" "[[:lower:]]"`-x86/bin/adb
fi
if [ ! -f "`which \"$FASTBOOT\"`" ]; then
	FASTBOOT=out/host/`uname -s | tr "[[:upper:]]" "[[:lower:]]"`-x86/bin/fastboot
fi

run_adb()
{
	$ADB $ADB_FLAGS $@
}

run_fastboot()
{
	if [ "$1" = "devices" ]; then
		$FASTBOOT $@
	else
		$FASTBOOT $FASTBOOT_FLAGS $@
	fi
	return $?
}

update_time()
{
	if [ `uname` = Darwin ]; then
		OFFSET=`date +%z`
		OFFSET=${OFFSET:0:3}
		TIMEZONE=`date +%Z$OFFSET|tr +- -+`
	else
		TIMEZONE=`date +%Z%:::z|tr +- -+`
	fi
	echo Attempting to set the time on the device
	run_adb wait-for-device &&
	run_adb shell toolbox date `date +%s` &&
	run_adb shell setprop persist.sys.timezone $TIMEZONE
}

fastboot_flash_image()
{
	# $1 = {userdata,boot,system}
	imgpath="out/target/product/$DEVICE/$1.img"
	out="$(run_fastboot flash "$1" "$imgpath" 2>&1)"
	rv="$?"
	echo "$out"

	if [[ "$rv" != "0" ]]; then
		# Print a nice error message if we understand what went wrong.
		if grep -q "too large" <(echo "$out"); then
			echo ""
			echo "Flashing $imgpath failed because the image was too large."
			echo "Try re-flashing after running"
			echo "  \$ rm -rf $(dirname "$imgpath")/data && ./build.sh"
		fi
		return $rv
	fi
}

flash_fastboot()
{
	run_adb reboot bootloader ;
	run_fastboot devices &&
	( [ "$1" = "nounlock" ] || run_fastboot oem unlock || true )

	if [ $? -ne 0 ]; then
		echo Couldn\'t setup fastboot
		return -1
	fi
	case $2 in
	"system" | "boot" | "userdata")
		fastboot_flash_image $2 &&
		run_fastboot reboot
		;;

	*)
		run_fastboot erase cache &&
		run_fastboot erase userdata &&
		fastboot_flash_image userdata &&
		([ ! -e out/target/product/$DEVICE/boot.img ] ||
		fastboot_flash_image boot) &&
		fastboot_flash_image system &&
		run_fastboot reboot &&
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

	run_adb reboot download && sleep 8
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

while [ $# -gt 0 ]; do
	case "$1" in
	"-s")
		ADB_FLAGS+="-s $2"
		FASTBOOT_FLAGS+="-s $2"
		shift
		;;
	*)
		PROJECT=$1
		;;
	esac
	shift
done

case "$PROJECT" in
"gecko")
	run_adb remount &&
	run_adb push $GECKO_OBJDIR/dist/b2g /system/b2g &&
	echo Restarting B2G &&
	run_adb shell stop b2g &&
	run_adb shell start b2g
	exit $?
	;;

"gaia")
	GAIA_MAKE_FLAGS="ADB=\"$ADB\""
	USER_VARIANTS="user(debug)?"
	if [[ "$VARIANT" =~ $USER_VARIANTS ]]; then
		# Gaia's build takes care of remounting /system for production builds
		GAIA_MAKE_FLAGS+=" PRODUCTION=1"
	fi

	make -C gaia install-gaia $GAIA_MAKE_FLAGS
	make -C gaia install-media-samples $GAIA_MAKE_FLAGS
	exit $?
	;;

"time")
	update_time
	exit $?
	;;
esac

case "$DEVICE" in
"otoro"|"unagi")
	flash_fastboot nounlock $PROJECT
	;;

"panda")
	flash_fastboot unlock $PROJECT
	;;

"maguro")
	flash_fastboot unlock $PROJECT
	;;

"m4")
	flash_fastboot unlock $PROJECT
	;;

"crespo"|"crespo4g")
	flash_fastboot unlock $PROJECT
	;;

"galaxys2")
	flash_heimdall $PROJECT
	;;

*)
	if [[ $(type -t flash_${DEVICE}) = function ]]; then
		flash_${DEVICE} $PROJECT
	else
		echo Unsupported device \"$DEVICE\", can\'t flash
		exit -1
	fi
	;;
esac
