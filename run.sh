#!/bin/bash

# Checks all neccesary tools are available on the user's machine #
tools=("nasm" "make" "qemu-system-x86_64")

for tool in "${tools[@]}"; do
	if ! which "$tool" > /dev/null; then
		echo Install "$tool" as it is required for the OS to build or run
		exit 1
	fi
done

# Builds the Virtual machine #
make

# Runs the Virtual machine #
qemu-system-x86_64 -fda Build/main_floppy.img -boot a -nographic

