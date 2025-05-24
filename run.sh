#!/bin/bash

# Checks all neccesary tools are available on the user's machine #
tools=("nasm" "make" "qemu-system-x86_64" "mkfs.fat" "mtools")

for tool in "${tools[@]}"; do
	if ! which "$tool" > /dev/null; then
		echo Install "$tool" as it is required for the OS to build or run
		exit 1
	fi
done

# Tells the shell script to exit if any commands fail 				#
# Lets the developer see make errors instead of booting up an old OS in the VM 	#
set -e

# Builds the Operating system #
make

# Runs the Virtual machine with the OS #
qemu-system-x86_64 -fda Build/main_floppy.img -boot a -nographic

