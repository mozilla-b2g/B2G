#!/bin/bash
source build/envsetup.sh
HOST_ARCH=$(get_build_var HOST_ARCH)
lunch "aosp_${HOST_ARCH}-userdebug"
PRODUCT_OUT=$(get_build_var PRODUCT_OUT)
OUT_DIR=$(get_abs_build_var OUT_DIR)
OUT_TEMP_DIR=$(get_build_var OUT_DIR)/avd_package
# Default name compatible with mach's emulator extractor.
AVD_NAME="test-1"
AVD_DIR_NAME="${AVD_NAME}.avd"

mkdir -p $OUT_TEMP_DIR/$AVD_DIR_NAME

echo "avd.ini.encoding=UTF-8
path=/home/cltbld/.android/avd/${AVD_DIR_NAME}
path.rel=avd/${AVD_DIR_NAME}
target=android-29" > $OUT_TEMP_DIR/$AVD_NAME.ini

CONFIG_FILE=$OUT_TEMP_DIR/$AVD_DIR_NAME/config.ini
cp $PRODUCT_OUT/config.ini $CONFIG_FILE
sed -i 's/image\.sysdir\.1=x86\//image\.sysdir\.1=/g' $CONFIG_FILE
echo -e "abi.type=$HOST_ARCH\nhw.cpu.arch=$HOST_ARCH" >> $CONFIG_FILE

EMULATOR_FILES=(\
       ${PRODUCT_OUT}/cache.img \
       ${OUT_TEMP_DIR}/${AVD_NAME}.ini \
       ${OUT_TEMP_DIR}/${AVD_DIR_NAME}/config.ini \
       ${PRODUCT_OUT}/encryptionkey.img \
       ${PRODUCT_OUT}/kernel-ranchu \
       ${PRODUCT_OUT}/ramdisk.img \
       ${PRODUCT_OUT}/VerifiedBootParams.textproto \
       ${PRODUCT_OUT}/system/build.prop \
       ${PRODUCT_OUT}/system-qemu.img \
       ${PRODUCT_OUT}/userdata.img)

EMULATOR_ARCHIVE="${OUT_DIR}/emulator.tar.gz"

echo "Creating emulator archive at ${EMULATOR_ARCHIVE}"

# Create a file structure needed by mach.
rm -f $EMULATOR_ARCHIVE
tar -cvzf $EMULATOR_ARCHIVE --transform "\
s,^${PRODUCT_OUT}/system/,avd/${AVD_DIR_NAME}/,S;\
s,^${PRODUCT_OUT}/,avd/${AVD_DIR_NAME}/,S;\
s,^${OUT_TEMP_DIR}/,avd/,S" --show-transformed-names ${EMULATOR_FILES[@]}
