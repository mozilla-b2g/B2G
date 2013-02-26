#!/bin/bash

# We want to figure out if we need to re-run the firmware
# extraction routine.  The first time we run build.sh, we
# store the hash of important files.  On subsequent runs,
# we check if the hash is the same as the previous run.
# If the hashes differ, we use a per-device script to redo
# the firmware extraction
function configure_device() {
    hash_file="$OUT/firmware.hash"

    # Make sure that our assumption that device codenames are unique
    # across vendors is true
    if [ $(ls -d device/*/$DEVICE 2> /dev/null | wc -l) -gt 1 ] ; then
        echo $DEVICE is ambiguous \"$(ls -d device/*/$DEVICE 2> /dev/null)\"
        return 1
    fi

    # Select which blob setup script to use, if any.  We currently
    # assume that $DEVICE maps to the filesystem location, which is true
    # for the devices we support now (oct 2012) that do not require blobs.
    # The emulator uses a $DEVICE of 'emulator' but its device/ directory
    # uses the 'goldfish' name.
    if [ -f device/*/$DEVICE/download-blobs.sh ] ; then
        important_files="device/*/$DEVICE/download-blobs.sh"
        script="cd device/*/$DEVICE && ./download-blobs.sh"
    elif [ -f device/*/$DEVICE/extract-files.sh ] ; then
        important_files="device/*/$DEVICE/extract-files.sh"
        script="cd device/*/$DEVICE && ./extract-files.sh"
    else
        important_files=
        script=
    fi

    # If we have files that are important to look at, we need
    # to check if they've changed
    if [ -n "$important_files" ] ; then
        new_hash=$(cat $important_files | openssl sha1)
        if [ -f "$hash_file" ] ; then
            old_hash=$(cat "$hash_file")
        fi
        if [ "$old_hash" != "$new_hash" ] ; then
            echo Blob setup script has changed, re-running &&
            sh -c "$script" &&
            mkdir -p "$(dirname "$hash_file")" &&
            echo "$new_hash" > "$hash_file"
        fi
    else
        rm -f $hash_file
    fi

    return $?
}

unset CDPATH
. setup.sh &&
if [ -f patches/patch.sh ] ; then
    . patches/patch.sh
fi &&
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
