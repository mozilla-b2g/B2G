#!/bin/bash
#set -x

ADB=${ADB:-adb}
if [ ! -f "`which \"$ADB\"`" ]; then
	ADB=out/host/`uname -s | tr "[[:upper:]]" "[[:lower:]]"`-x86/bin/adb
fi

if [ "$1" = "" ] || [ "$1" = "connect" ]; then
	TARGET_IP=$($ADB shell netcfg | grep wlan0 | tr -s ' ' | cut -d' ' -f3 | cut -d'/' -f1)
	ADB_PORT=$((20000 + $(id -u) % 10000))
	TARGET_DEV=$TARGET_IP:$ADB_PORT
	echo "Target IP: $TARGET_IP"
	echo "ADB port:  $ADB_PORT"

	$ADB tcpip $ADB_PORT > /dev/null
	if [ "$?" != "0" ] || [ -n "$($ADB connect $TARGET_DEV | grep 'unable')" ]; then
		echo "Fail to establish the connection with TCP/IP!"
		exit 1
	else
		echo "Connected to the device at ${TARGET_DEV}."
	fi
elif [ "$1" = "disconnect" ]; then
	TARGET_DEV=$($ADB devices | grep -oE "([[:digit:]]+\.){3}[[:digit:]]+:[[:digit:]]+")
	if [ "$TARGET_DEV" != "" ]; then
		$ADB disconnect $TARGET_DEV > /dev/null
		echo "Already disconnected at ${TARGET_DEV}."
	else
		echo "No device connected with TCP/IP!"
	fi
fi

