Tools for packaging and testing FxOS system updates

Acknowledgements
================
For convenience, these scripts depend on a number of prebuilt binaries to
minimize local build dependencies:

* bin/$HOST/adb is from AOSP, and is licensed under the Apache Public License v2.
  Source code can be found [here](https://github.com/android/platform_system_core/tree/master/adb)

* bin/$HOST/mar is from Mozilla, and is licensed under the Mozilla Public License 2.0.
  Source code can be found [here](http://hg.mozilla.org/mozilla-central/file/tip/modules/libmar)

* bin/gonk/busybox-armv6l is from Busybox, and is licensed under the GNU GPL v2.
  Source code can be found [here](http://www.busybox.net/downloads/)

* bin/gonk/update-binary is from AOSP and is licensed under the Apache Public License v2.
  Source code can be found [here](https://android.googlesource.com/platform/bootable/recovery.git)

* bin/signapk.jar is from AOSP, and is licensed under the Apache Public License v2.
  Source code can be found [here](https://github.com/android/platform_build/tree/master/tools/signapk)
