#!/bin/bash
set -
cd ..
. setup.sh
PRODUCT_OUT=$(get_build_var PRODUCT_OUT)
HOST_OUT=$(get_build_var HOST_OUT)
OUT_DIR=$(get_abs_build_var OUT_DIR)

EMULATOR_FILES=(\
	.config \
	load-config.sh \
	run-emulator.sh \
	${HOST_OUT}/bin/adb \
	${HOST_OUT}/bin/emulator \
	${HOST_OUT}/bin/emulator-arm \
	${HOST_OUT}/bin/mksdcard \
	${HOST_OUT}/bin/qemu-android-x86 \
	${HOST_OUT}/lib \
	${HOST_OUT}/usr \
	development/tools/emulator/skins \
	prebuilts/qemu-kernel/arm/kernel-qemu-armv7 \
	${PRODUCT_OUT}/system/build.prop \
	${PRODUCT_OUT}/system.img \
	${PRODUCT_OUT}/userdata.img \
	${PRODUCT_OUT}/ramdisk.img)

EMULATOR_ARCHIVE="${OUT_DIR}/emulator.tar.gz"

echo "Creating emulator archive at $EMULATOR_ARCHIVE"

rm -rf $EMULATOR_ARCHIVE
tar -cvzf $EMULATOR_ARCHIVE --transform 's,^,b2g-distro/,S' --show-transformed-names ${EMULATOR_FILES[@]}

