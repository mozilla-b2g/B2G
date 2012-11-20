#!/bin/bash
set -e

# This script will probably live in /scripts/ but life's easier
# when work is done in the actual B2G root
cd ..

OUT_DIR=out

. load-config.sh

if [ -z $1 ] ; then
    echo "Usage: $0 <version> [<toolchain_target>]" 1>&2
    exit -1
fi

output=gonk-toolchain-$1
manifest_file=sources.xml
toolchain_target=linux-x86
if [ $2 ] ; then
    toolchain_target=$2
fi

rm -rf $output ; mkdir -p $output
./gonk-misc/add-revision.py .repo/manifest.xml \
        --output $manifest_file --force --b2g-path $B2G_DIR --tags

if [ ! -d $OUT_DIR/target/product/$DEVICE ] ; then
    echo "ERROR: you must build B2G before building a toolchain" 1>&2
    exit -1
fi

# Important Directories
for i in \
    bionic \
    dalvik/libnativehelper/include/nativehelper \
    external/stlport/stlport \
    external/bluetooth/bluez \
    external/dbus \
    external/libpng \
    frameworks/base/include \
    frameworks/base/media/libstagefright \
    frameworks/base/native/include \
    frameworks/base/opengl/include \
    frameworks/base/services/sensorservice \
    frameworks/base/services/camera/libcameraservice \
    hardware/libhardware/include \
    hardware/libhardware_legacy/include \
    ndk/sources/android/cpufeatures \
    ndk/sources/cxx-stl/system/include \
    ndk/sources/cxx-stl/stlport/stlport \
    ndk/sources/cxx-stl/gabi++/include \
    out/target/product/$DEVICE/obj/lib \
    prebuilt/$toolchain_target/toolchain/arm-linux-androideabi-4.4.x \
    system/core/include \
    system/media/wilhelm/include
do 
    mkdir -p $output/$i
    cp -r $i/* $output/$i
done

# Important Files
for i in \
    gonk-misc/Unicode.h \
    system/vold/ResponseCode.h
do
    directory=$(dirname $i)
    mkdir -p $output/$directory
    cp $i $output/$directory/
done

tar cjf $output.tar.bz2 $output $manifest_file
rm -rf $output

echo "{ \"toolchain_tarball\": \"$(dirname `pwd`)/$output.tar.bz2\" }" 

