#!/bin/sh
#
# Script to set up the AArch64 cross-compilation environment.
#

TOOLCHAIN_DIR=`pwd`/../../gcc-arm-10.3-2021.07-x86_64-aarch64-none-elf
export PATH=$PATH:$TOOLCHAIN_DIR/bin
unset LDFLAGS
export CROSS_COMPILE="aarch64-none-elf-"
export TARGET_PREFIX="aarch64-none-elf-"
export SDKTARGETSYSROOT="$TOOLCHAIN_DIR"
export PKG_CONFIG_SYSROOT_DIR="$TOOLCHAIN_DIR"
export LD="aarch64-none-elf-ld --sysroot=$SDKTARGETSYSROOT"
export CC="aarch64-none-elf-gcc -march=armv8-a -mtune=cortex-a55 --sysroot=$SDKTARGETSYSROOT"
export CPP="aarch64-none-elf-gcc -E -march=armv8-a -mtune=cortex-a55 --sysroot=$SDKTARGETSYSROOT"
export CXX="aarch64-none-elf-g++  -march=armv8-a -mtune=cortex-a55 --sysroot=$SDKTARGETSYSROOT"
