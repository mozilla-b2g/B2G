# Boot to Gecko (B2G)

Boot to Gecko aims to create a complete, standalone operating system for the open web.

You can read more about B2G here:

  http://wiki.mozilla.org/B2G
  
  https://developer.mozilla.org/en-US/docs/Mozilla/B2G_OS

Follow us on twitter: @Boot2Gecko

  http://twitter.com/Boot2Gecko

Join the Mozilla Platform mailing list:

  http://groups.google.com/group/mozilla.dev.platform

and talk to us on Matrix:

  https://chat.mozilla.org/#/room/#b2g:mozilla.org

Discuss with Developers:

  Discourse: https://discourse.mozilla-community.org/c/b2g-os-participation

# Building and running the android-10 emulator

1. Fetch the code: `REPO_INIT_FLAGS="--depth=1" ./config.sh emulator-10`
2. Setup your environment to fetch the custom NDK: `export LOCAL_NDK_BASE_URL='ftp://ftp.kaiostech.com/ndk/android-ndk'`
3. Install Gecko dependencies: `cd gecko && ./mach bootstrap`, choose option 4 (Android Geckoview).
4. Build: `./build.sh`
5. Run the emulator: `source build/envsetup.sh && lunch aosp_arm-userdebug && emulator -writable-system -selinux permissive`

# Re-building your own NDK

Because it's using a different c++ namespace than the AOSP base, we can't use the prebuilt NDK from Google. If you can't use the one built by KaiOS, here are the steps to build your own:
1. Download the ndk source:
`repo init -u https://android.googlesource.com/platform/manifest -b ndk-release-r20`
2. change `__ndk` to `__` in `external/libcxx/include/__config`:
```diff
-#define _LIBCPP_NAMESPACE _LIBCPP_CONCAT(__ndk,_LIBCPP_ABI_VERSION)
+#define _LIBCPP_NAMESPACE _LIBCPP_CONCAT(__,_LIBCPP_ABI_VERSION)
```
3. Build the ndk:
`python ndk/checkbuild.py --no-build-tests`
