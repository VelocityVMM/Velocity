#!/bin/bash
echo "[!] Checking if building in an SSH shell.."
if [ x"${SSH_CONNECTION}" == "x" ]; then
	echo "[!] Keychain is already unlocked."
else
	echo "[!] SSH shell detected. You will need to unlock your keychain. Enter your password if requested."
	security -v unlock-keychain -p
fi

echo "[!] Building Velocity."
xcodebuild -scheme velocity -derivedDataPath build build

echo "[!] Copying Binary."
cp -v build/Build/Products/Debug/velocity ./vlcty
