#!/bin/bash
#
# Boot2Gecko Mac OS X bootstrap script
# See --help

this_dir=$(cd `dirname $0`; pwd)

print_usage() {
    cat << EOF
Boot2Gecko Mac OS X Bootstrap

This script attempts to bootstrap a "minimal" OS X installation
with the tools necessary to build Boot2Gecko.

The only requirement for running this script should be XCode 4.x / 3.x,
and either OS X 10.6 (Snow Leopard) or 10.7 (Lion)

Usage: $0 [options]
Options:
    --help              print this message
    --dry-run           only prints commands instead of executing them
                        (default: run commands)
    --auto-install      automatically installs all necessary packages,
                        and doesn't prompt (default: prompt)
    --clone             clone the Boot2Gecko git repository after the
                        environment has been bootstrapped into:
                        $PWD/B2G
EOF
    exit 1
}

parse_options() {
    option_dry_run=no
    option_auto_install=no
    option_help=no
    option_clone=no

    while [ $# -gt 0 ]; do
        case "$1" in
            --help|-h) option_help=yes;;
            --dry-run) option_dry_run=yes;;
            --auto-install) option_auto_install=yes;;
            --clone) option_clone=yes;;
            *) break;;
        esac
        shift
    done

    if [ "$option_help" = "yes" ]; then
        print_usage
    fi
}

prompt_question() {
    question="$1"
    default_answer="$2"

    echo -n "$question"

    # using /dev/tty avoids slurping up STDIN when this script is piped to bash
    read full_answer < /dev/tty

    if [ "$full_answer" = "" ]; then
        answer=$default_answer
    else
        answer=${full_answer:0:1}
    fi
    answer=`echo $answer | tr '[[:lower:]]' '[[:upper:]]'`

    if [[ $answer != Y && $answer != N ]]; then
        echo "Error: invalid response $full_answer."
        echo "Expected \"y\", \"yes\", \"n\", or \"no\" (case insensitive)"
        echo ""
        prompt_question "$question" "$default_answer"
    fi
}

run_command() {
    if [ "$option_dry_run" = "yes" ]; then
        command_prefix="(dry-run) "
    fi

    echo "$command_prefix=> $@"

    if [ "$option_dry_run" = "no" ]; then
        $@
    fi
}

bootstrap_mac() {
    check_xcode

    homebrew_formulas=""
    git=`which git`
    if [ $? -ne 0 ]; then
        homebrew_formulas+="git:git"
    else
        echo "Found git: $git"
    fi

    gpg=`which gpg`
    if [ $? -ne 0 ]; then
        homebrew_formulas+=" gpg:gpg"
    else
        echo "Found gpg: $gpg"
    fi

    ccache=`which ccache`
    if [ $? -ne 0 ]; then
        homebrew_formulas+=" ccache:ccache"
    else
        echo "Found ccache: $ccache"
    fi

    yasm=`which yasm`
    if [ $? -ne 0 ]; then
        homebrew_formulas+=" yasm:yasm"
    else
        echo "Found yasm: $yasm"
    fi

    found_autoconf213=1
    autoconf213=`which autoconf213`
    if [ $? -ne 0 ]; then
        found_autoconf213=0

        # Try just "autoconf" and check the version
        autoconf=`which autoconf`
        if [ $? -eq 0 ]; then
            autoconf_version=`$autoconf --version | grep "2.13"`
            if [ $? -eq 0 ]; then
                autoconf213=$autoconf
                found_autoconf213=1
            fi
        fi
    fi

    if [ $found_autoconf213 -eq 0 ]; then
        autoconf213_formula="https://raw.github.com/Homebrew/homebrew-versions/master/autoconf213.rb"
        homebrew_formulas+=" autoconf-2.13:$autoconf213_formula"
    else
        echo "Found autoconf-2.13: $autoconf213"
    fi

    found_apple_gcc=0
    check_apple_gcc

    if [ $found_apple_gcc -eq 0 ]; then
        # No Apple gcc, probably because newer Xcode 4.3 only installed LLVM-backed gcc
        # Fall back to checking for / installing gcc-4.6 

        found_gcc46=1
        gcc46=`which gcc-4.6`
        if [ $? -ne 0 ]; then
            found_gcc46=0
            gcc46_formula="https://raw.github.com/mozilla-b2g/B2G/master/scripts/homebrew/gcc-4.6.rb"
            homebrew_formulas+=" gcc-4.6:$gcc46_formula"
        else
            echo "Found gcc-4.6: $gcc46"
        fi
    fi

    if [ ! -z "$homebrew_formulas" ]; then
        homebrew=`which brew`
        if [ $? -ne 0 ]; then
            homebrew="/usr/local/bin/brew"
        fi

        if [ ! -f $homebrew ]; then
            prompt_install_homebrew
            homebrew=`which brew`
            if [ $? -ne 0 ]; then
                homebrew="/usr/local/bin/brew"
            fi
        fi

        if [ ! -f $homebrew ]; then
            echo "Error: Homebrew was not found, and some dependencies couldn't"
            echo "       be found. Without homebrew, You'll need to 'brew install' these"
            echo "       dependencies manually:"
            echo ""
            for entry in $homebrew_formulas; do
                name=${entry%%:*}
                formula=${entry:${#name}+1}
                echo "  * $formula"
            done
            echo ""
            exit 1
        fi

        echo "Found homebrew: $homebrew"
        for entry in $homebrew_formulas; do
            name=${entry%%:*}
            formula=${entry:${#name}+1}
            prompt_install_homebrew_formula $name $formula
        done
    else
        if [ "$option_clone" = "yes" ]; then
            clone_b2g
        fi

        echo "Congratulations, you are now ready to start building Boot2Gecko!"
        echo "For more details, see our documentation:"
        echo ""
        echo "    https://developer.mozilla.org/en/Mozilla/Boot_to_Gecko/Preparing_for_your_first_B2G_build"
        echo ""
    fi
}

check_xcode() {
    xcode43_path=/Applications/Xcode.app
    pre_xcode43_path=/Developer

    if [ -d "$xcode43_path" ]; then
        xcode_path=$xcode43_path
        osx_106_sdk=$xcode_path/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.6.sdk
    fi

    if [ -d "$pre_xcode43_path" ]; then
        xcode_path=$pre_xcode43_path
        osx_106_sdk=$xcode_path/SDKs/MacOSX10.6.sdk
    fi

    if [ ! -d "$xcode_path" ]; then
        echo "Could not find an Xcode installation in either of these locations:"
        echo "    $xcode43_path"
        echo "    $pre_xcode43_path"
        echo ""
    else
        echo "Found Xcode: $xcode_path"
        if [ ! -d "$osx_106_sdk" ]; then
            echo "Error: Could not find MacOSX10.6.sdk in this location:"
            echo "    $osx_106_sdk"
            echo ""
            exit 1
        else
            echo "Found OSX 10.6 SDK: $osx_106_sdk"
            return 0
        fi
    fi

    osx_version=`sw_vers -productVersion`

    if [[ ${osx_version:0:4} == "10.7" ]]; then
        # In Lion, we open the Mac App Store for Xcode 4.3.
        # Opening the App Store is annoying, so ignore option_auto_install here
        prompt_question "Do you want to open Xcode 4.3 in the Mac App Store? [Y/n] " Y
        if [[ $answer = Y ]]; then
            # Xcode 4.3 iTunes http URL: http://itunes.apple.com/us/app/xcode/id497799835?mt=12
            # Mac App Store URL: macappstore://itunes.apple.com/app/id497799835?mt=12
            run_command open macappstore://itunes.apple.com/app/id497799835\?mt\=12
        fi
    else
        echo "You will need to install \"Xcode 3.2.6 for Snow Leopard\" to build Boot2Gecko."
        echo "Note: This is a 4.1GB download, and requires a free Apple account."
        echo ""
        prompt_question "Do you want to download XCode 3.2.6 for Snow Leopard in your browser? [Y/n] " Y
        if [[ $answer = Y ]]; then
            run_command open https://developer.apple.com/downloads/download.action\?path=Developer_Tools/xcode_3.2.6_and_ios_sdk_4.3__final/xcode_3.2.6_and_ios_sdk_4.3.dmg
        fi
    fi

    exit 1
}

check_apple_gcc() {
    # Check for non-LLVM apple gcc
    gcc_path=`which gcc`
    gcc_regex="i686-apple-darwin1[01]-gcc-"

    if [ ! -f "$gcc_path" ]; then
        return 1
    fi

    version=`"$gcc_path" --version | sed '2,/end-/d' | sed 's/ .*//' `
    echo $version | grep -q -E $gcc_regex
    if [ $? -eq 0 ]; then
        found_apple_gcc=1
        apple_gcc=$gcc_path
        echo "Found Apple gcc ($version): $gcc_path"
        return 0
    else
        echo "Warning: gcc reports version $version, will look for gcc-4.6" 1>&2
        return 1
    fi
}

prompt_install_homebrew() {
    if [ "$option_auto_install" = "no" ]; then
        echo "You don't seem to have the 'brew' command installed"
        echo "in your system. Homebrew is a free package manager for"
        echo "OS X that will greatly ease environment setup."
        echo ""

        prompt_question "Do you want to install Homebrew? (may require sudo) [Y/n] " Y
    else
        echo "Could not find 'brew', starting Homebrew installer..."
        answer=Y
    fi

    if [[ $answer = Y ]]; then
        install_homebrew
    else
        echo "Please manually install Homebrew, and put it in your PATH. For more, see:"
        echo "https://github.com/mxcl/homebrew/wiki/installation"
        echo ""
    fi
}

install_homebrew() {
    # This was taken and modified from the official Homebrew wiki:
    # https://github.com/mxcl/homebrew/wiki/installation
    # Update this in the future if Homebrew installation changes

    if [ "$option_dry_run" = "yes" ]; then
        # fake the tempfile creation for dry-runs
        echo "(dry-run)=> mktemp /tmp/b2g-boostrap.XXXXX"
        tmp_installer="/tmp/b2g-bootstrap.XXXXX"
    else
        tmp_installer=`mktemp /tmp/b2g-bootstrap.XXXXXX` || (
            echo "Error: Could not make temporary file for Homebrew installer" &&
            exit 1
        )
    fi

    installer_url="https://raw.github.com/mxcl/homebrew/master/Library/Contributions/install_homebrew.rb"

    run_command curl -fsSL $installer_url -o $tmp_installer
    run_command ruby $tmp_installer
}

prompt_install_homebrew_formula() {
    name=$1
    formula=$2

    if [ "$option_auto_install" = "no" ]; then
        echo "$name wasn't found, but it looks like you have Homebrew"
        echo "installed at $homebrew."
        echo ""
        echo "Do you want to install $name by running Homebrew?"
        prompt_question "[$homebrew install $formula] [Y/n] " Y
    else
        echo "Automatically installing $name"
        answer=Y
    fi

    if [[ $answer = Y ]]; then
        run_command $homebrew install $formula
    fi
}

clone_b2g() {
    if [ -d "$PWD/B2G" ]; then
        echo "Found existing B2G: $PWD/B2G"
        return 0
    fi

    run_command git clone git://github.com/mozilla-b2g/B2G.git
}

parse_options $@
bootstrap_mac
