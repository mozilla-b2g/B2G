#!/bin/bash

# We want to figure out if we need to re-run the firmware
# extraction routine.  The first time we run build.sh, we
# store the hash of important files.  On subsequent runs,
# we check if the hash is the same as the previous run.
# If the hashes differ, we use a per-device script to redo
# the firmware extraction
function configure_device() {
    hash_file="$OUT/firmware.hash"

    # Figure out which pieces of information are important
    case $DEVICE in
        galaxys2)
            script="cd device/samsung/$DEVICE && ./extract-files.sh"
            important_files="device/samsung/$DEVICE/extract-files.sh"
            ;;
        crespo|crespo4g|maguro)
            script="cd device/samsung/$DEVICE && ./download-blobs.sh"
            important_files="device/samsung/$DEVICE/download-blobs.sh"
            ;;
        otoro|unagi)
            script="cd device/qcom/$DEVICE && ./extract-files.sh"
            important_files="device/qcom/$DEVICE/extract-files.sh"
            ;;
        m4)
            script="cd device/lge/$DEVICE && ./extract-files.sh"
            important_files="device/lge/$DEVICE/extract-files.sh"
            ;;
        panda)
            script="cd device/ti/$DEVICE && ./download-blobs.sh"
            important_files="device/ti/$DEVICE/download-blobs.sh"
            ;;
        generic)
            script=
            important_files=
            ;;
        *)
            echo "Cannot configure blobs for unknown device $DEVICE_NAME \($DEVICE\)"
            return 1
            ;;
    esac

    # If we have files that are important to look at, we need
    # to check if they've changed
    if [ -n "$important_files" ] ; then
        new_hash=$(cat "$important_files" | openssl sha1)
        if [ -f "$hash_file" ] ; then
            old_hash=$(cat "$hash_file")
        fi
        if [ "$old_hash" != "$new_hash" ] ; then
            echo Blob setup script has chagned, re-running &&
            sh -c "$script" &&
            mkdir -p "$(dirname "$hash_file")" &&
            echo "$new_hash" > "$hash_file"
        fi
    else
        rm -f $hash_file
    fi

    return $?
}

. setup.sh &&
configure_device &&
time nice -n19 make $MAKE_FLAGS $@

ret=$?
echo -ne \\a
if [ $ret -ne 0 ]; then
	echo
	echo \> Build failed\! \<
	echo
	echo Build with \|./build.sh -j1\| for better messages
	echo If all else fails, use \|rm -rf objdir-gecko\| to clobber gecko and \|rm -rf out\| to clobber everything else.
else
	if echo $DEVICE | grep generic > /dev/null ; then
		echo Run \|./run-emulator.sh\| to start the emulator
		exit 0
	fi
	case "$1" in
	"gecko")
		echo Run \|./flash.sh gecko\| to update gecko
		;;
	*)
		echo Run \|./flash.sh\| to flash all partitions of your device
		;;
	esac
	exit 0
fi

exit $ret
