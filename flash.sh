#!/bin/bash

. load-config.sh

ADB=${ADB:-adb}
FASTBOOT=${FASTBOOT:-fastboot}
HEIMDALL=${HEIMDALL:-heimdall}
VARIANT=${VARIANT:-eng}
FULLFLASH=false

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
	local lockedness=$1 project=$2
	case $lockedness in
	"unlock"|"nounlock")
		;;
	*)
		echo "$0: $FUNCNAME: Invalid argument: $lockedness"
		return 1
		;;
	esac
	case $project in
	"system"|"boot"|"userdata"|"")
		;;
	*)
		echo "$0: Unrecognized project: $project"
		return 1
		;;
	esac

	case $DEVICE in
	"helix")
		run_adb reboot oem-1
		;;
	*)
		run_adb reboot bootloader
		;;
	esac

	if ! run_fastboot devices; then
		echo Couldn\'t setup fastboot
		return 1
	fi

	case $lockedness in
	"unlock")
		run_fastboot oem unlock || true
		;;
	esac

	case $project in
	"system" | "boot" | "userdata")
		fastboot_flash_image $project &&
		run_fastboot reboot
		;;

	"")
		# helix doesn't support erase command in fastboot mode.
		VERB="erase"
		if [ "$DEVICE" == "hammerhead" ] || [ "$DEVICE" == "mako" ] ||
		[ "$DEVICE" == "flo" ]; then
			VERB="format"
		fi
		if [ "$DEVICE" != "helix" ]; then
			run_fastboot $VERB cache &&
			run_fastboot $VERB userdata
			if [ $? -ne 0 ]; then
				return $?
			fi
		fi
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
	local project=$1
	case $project in
	"system"|"kernel"|"")
		;;
	*)
		echo "$0: Unrecognized project: $project"
		return 1
		;;
	esac

	if [ ! -f "`which \"$HEIMDALL\"`" ]; then
		echo Couldn\'t find heimdall.
		echo Install Heimdall v1.3.1 from http://www.glassechidna.com.au/products/heimdall/
		exit -1
	fi

	run_adb reboot download && sleep 8
	if [ $? -ne 0 ]; then
		echo Couldn\'t reboot into download mode. Hope you\'re already in download mode
	fi

	case $project in
	"system")
		$HEIMDALL flash --factoryfs out/target/product/$DEVICE/$project.img
		;;

	"kernel")
		$HEIMDALL flash --kernel device/samsung/$DEVICE/kernel
		;;

	"")
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

# Delete files in the device's /system/b2g that aren't in
# $GECKO_OBJDIR/dist/b2g.
#
# We do this for general cleanliness, but also because b2g.sh determines
# whether to use DMD by looking for the presence of libdmd.so in /system/b2g.
# If we switch from a DMD to a non-DMD build and then |flash.sh gecko|, we want
# to disable DMD, so we have to delete libdmd.so.
#
# Note that we do not delete *folders* in /system/b2g.  This is intentional,
# because some user data is stored under /system/b2g (e.g. prefs), but it seems
# to be stored only inside directories.
delete_extra_gecko_files_on_device()
{
	files_to_remove="$(cat <(ls "$GECKO_OBJDIR/dist/b2g") <(run_adb shell "ls /system/b2g" | tr -d '\r') | sort | uniq -u)"
	if [[ "$files_to_remove" != "" ]]; then
		# We expect errors from the call to rm below under two circumstances:
		#
		#  - We ask rm to remove a directory (per above, we don't
		#    actually want to remove directories, so rm is doing the
		#    right thing by not removing dirs)
		#
		#  - We ask rm to remove a file which isn't on the device (if
		#    you squint at files_to_remove, you'll see that it will
		#    contain files which are on the host but not on the device;
		#    obviously we can't remove those files from the device).

		run_adb shell "cd /system/b2g && rm $files_to_remove" > /dev/null
	fi
	return 0
}

flash_gecko()
{
	delete_extra_gecko_files_on_device &&
	run_adb push $GECKO_OBJDIR/dist/b2g /system/b2g &&
	return 0
}

flash_gaia()
{
	GAIA_MAKE_FLAGS="ADB=\"$ADB\""
	USER_VARIANTS="user(debug)?"
	if [[ "$VARIANT" =~ $USER_VARIANTS ]]; then
		# Gaia's build takes care of remounting /system for production builds
		GAIA_MAKE_FLAGS+=" PRODUCTION=1"
	fi
	adb wait-for-device
	if adb shell cat /data/local/webapps/webapps.json | grep -qs '"basePath": "/system' ; then
		echo -n "In ${bold}production${offbold} mode"
		export B2G_SYSTEM_APPS=1
		adb remount
	else
		echo -n "In ${bold}dev${offbold} mode"
	fi 
	make -C gaia install-gaia $GAIA_MAKE_FLAGS
	return 0
}

while [ $# -gt 0 ]; do
	case "$1" in
	"-s")
		ADB_FLAGS+="-s $2"
		FASTBOOT_FLAGS+="-s $2"
		shift
		;;
	"-f")
		FULLFLASH=true
		;;
	"-h"|"--help")
		echo "Usage: $0 [-s device] [-f] [project]"
		exit 0
		;;
	"-"*)
		echo "$0: Unrecognized option: $1"
		exit 1
		;;
	*)
		FULLFLASH=true
		PROJECT=$1
		;;
	esac
	shift
done

case "$PROJECT" in
"gecko")
	run_adb shell stop b2g &&
	run_adb remount &&
	flash_gecko &&
	echo Restarting B2G &&
	run_adb shell start b2g
	exit $?
	;;

"gaia")
	flash_gaia
	exit $?
	;;

"time")
	update_time
	exit $?
	;;
esac

case "$DEVICE" in
"leo"|"hamachi"|"helix"|"fugu")
	if $FULLFLASH; then
		flash_fastboot nounlock $PROJECT
		exit $?
	else
		run_adb root &&
		run_adb shell stop b2g &&
		run_adb remount &&
		flash_gecko &&
		flash_gaia &&
		update_time &&
		echo Restarting B2G &&
		run_adb shell start b2g
	fi
	exit $?
	;;

"otoro"|"unagi"|"keon"|"peak"|"inari"|"sp8810ea"|"wasabi")
	flash_fastboot nounlock $PROJECT
	;;

"panda"|"maguro"|"m4"|"crespo"|"crespo4g"|"mako"|"hammerhead"|"flo")
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
