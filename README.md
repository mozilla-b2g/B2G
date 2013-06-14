# Boot to Gecko (B2G)

Boot to Gecko aims to create a complete, standalone operating system for the open web.

You can read more about B2G here:

  http://wiki.mozilla.org/B2G

follow us on twitter: @Boot2Gecko

  http://twitter.com/Boot2Gecko

join the Mozilla Platform mailing list:

  http://groups.google.com/group/mozilla.dev.platform

and talk to us on IRC:

  #B2G on irc.mozilla.org

## Prerequisites

### Linux

* A 64 bit linux distro
  * See http://source.android.com/source/initializing.html on configuring USB access.
* 20GB of free disk space
* autoconf-2.13
* git
* ccache
* gcc/g++ __4.6.3 or older__
* bison
* flex
* 32bit ncurses
* zlib
  * You need both zlib1g and zlib1g-dev for both i386 and amd64. That is, for
    Ubuntu 12.04 Precise or older, they are zlib1g, zlib1g-dev, zlib1g:i386, and
    zlib1g-dev:i386; for Ubuntu 12.10 Quantal or newer, they are zlib1g:amd64,
    zlib1g-dev:amd64, zlib1g:i386, and zlib1g-dev:i386.
* make

Additionally, if you're building the emulator, you probably need the the Mesa
implementation of OpenGL.  On Ubuntu, this is the __libgl1-mesa-dev__ package.

Ubuntu 12.10 ships with gcc 4.7 by default, which causes build errors pretty
early in the process.  To use gcc 4.6, edit .userconfig and add

    export CC=gcc-4.6
    export CXX=g++-4.6

Of course, you'll need the g++-4.6 package installed.

On Ubuntu 13.04, for example, you might find `apt-get install zlib1g{,-dev}:i386`
is going to do something seriously wrong like removing all your toolchain
packages. You may execute either `apt-get install --no-install-recommends <packages>`
to explicitly disallow installing recommended packages, or `aptitude` to
interactively select the very necessary packages you need.

For full lists of minimum required packages that build B2G emulator on all
recent Ubuntu releases, see https://bugzilla.mozilla.org/show_bug.cgi?id=866489 .

### OSX

* XCode
* 20GB of free space
* homebrew
  * git (if not using XCode 4)
  * gpg
  * ccache
  * autoconf-2.13 - brew install https://raw.github.com/Homebrew/homebrew-versions/master/autoconf213.rb

#### Note: Builds for some devices require case-sensitive file systems

Some B2G subrepositories contain files whose names differ only in case.
This causes build failures when building for some target phones (such as the
Hamachi) if you're on a case-insensitive FS (the default on Mac).  You'll see
an error like the following during the ./build.sh step:

> [entering kernel]
> ERROR: You have uncommited changes in kernel
> You may force overwriting these changes
> with |source build/envsetup.sh force|
> 
> ERROR: Patching of kernel/ failed.

If you hit this error, the easiest way around it is to build on a
case-sensitive file-system.  Doing so doesn't require any re-partitioning; you
can simply create a disk image and build within it using the following
commands.

    hdiutil create -volname 'firefoxos' -type SPARSE -fs 'Case-sensitive Journaled HFS+' -size 40g ~/firefoxos.sparseimage
    open ~/firefoxos.sparseimage
    cd /Volumes/firefoxos/

See https://bugzilla.mozilla.org/show_bug.cgi?id=867259 for details.

#### Note: Linker OOM with noopt builds

If you build with B2G_NOOPT=1 on MacOS, your linker may run out of memory and
crash.

The solution, if you really want a noopt build, is to use a 64-bit linker.
Follow these steps:

1. Clone this repository somewhere

    $ git://github.com/jld/b2g-toolchain-prebuilt.git

2. In .userconfig, add the following line.

        export TARGET_TOOLS_PREFIX=/path/to/b2g-toolchain-prebuilt/toolchain-4.4.3/x86_64-apple-darwin/bin/arm-linux-androideabi-

  (Of course, replace /path/to/b2g-toolchain-prebuilt/ with the actual path.)

3. Rebuild.

See https://bugzilla.mozilla.org/show_bug.cgi?id=854535 for details.

## Configure

Run config.sh to get a list of supported devices:

    ./config.sh

And then run config.sh for the device you want to build for:

    ./config.sh [device name]

### Udev Permissions
If you get "error: insufficient permissions for device"...

Obtain ID of device manufacturer (first 4 hexidecimal digits before colon):

    $ lsusb

Add a line to /etc/udev/rules.d/android.rules (replacing XXXX with 4 digit ID):

    SUBSYSTEM=="usb", ATTRS{idVendor}=="XXXX", MODE="0666"

Restart udev before re-plugging your device for it to be detected:

    $ sudo service udev restart

Re-run configure:

    ./config.sh [device name]

### Building against a custom Gecko

It can sometimes be useful to build against a different Gecko than the one specified in the manifest, e.g. a mozilla-central checkout that has some patches applied. To do so, edit .userconfig:

    GECKO_PATH=/path/to/mozilla-central
    GECKO_OBJDIR=/path/to/mozilla-central/objdir-gonk

Note that if you switch your userconfig's gecko path, you need to rm -rf the objdir and rebuild.

## Build

Run build.sh or bld.sh to build B2G.

    ./build.sh

If you want to just build gecko or some other project, just specify it:

    ./build.sh gecko

## Flash/Install

Make sure your phone is plugged in with usb debugging enabled.

To flash everything on your phone:

    ./flash.sh

To flash system/userdata/boot partitions on fastboot phones:

    ./flash.sh system
    ./flash.sh boot
    ./flash.sh user

To update gecko:

    ./flash.sh gecko

To update gaia:

    ./flash.sh gaia

## Update Repos

To update all repos:

    git pull
    ./repo sync

To update a specific repo (eg, gaia):

    ./repo sync gaia

## Debug

To restart B2G and run B2G under gdb:

    ./run-gdb.sh

To attach gdb to a running B2G process:

    ./run-gdb.sh attach

## Test

To run the Marionette test suite on the emulator:

    ./test.sh

To run specific tests (individual files, directories, or ini files):

    ./test.sh gecko/dom/sms gecko/dom/battery/test/marionette/test_battery.py

Specify the full path if you're using a different Gecko repo:

    ./test.sh /path/to/mozilla-central/dom/battery/test/marionette/test_battery.py

