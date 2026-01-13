#!/bin/bash
#
# Script to build U-Boot and TF-A and generate FIP files for RZ/G2L (SMARC).
#

WORKDIR=${1-`pwd`/../..}

#======INPUT=======
UBOOT_DIR=$WORKDIR/rz_tool_u-boot
TFA_DIR=$WORKDIR/rzg_trusted-firmware-a

#======OUTPUT=======
OUTPUT_DIR=$WORKDIR/output/
rm -rf $OUTPUT_DIR
mkdir $OUTPUT_DIR

#======GCC_10.3=======
./gcc_10.3.sh

#======SETUP=======

export ARCH=arm64
source gcc_10.3.sh

#======UBOOT=======
cd ${UBOOT_DIR}
make clean
make smarc-rzg2l_defconfig
make -j$(nproc)
cd -

if [ -f "${UBOOT_DIR}/u-boot.bin" ]; then
	echo "### Build u-boot successfully!! ###"
else
	echo "### Build u-boot failed!! ###"
	exit 0
fi

#======TFA========
cd ${TFA_DIR}
make PLAT=g2l BOARD=smarc_pmic_2 realclean
make PLAT=g2l BOARD=smarc_pmic_2 BL33=${UBOOT_DIR}/u-boot.bin bl2 fip bptool pkg
cd -

#=======TFA_OUTPUT==========
BUILD_TYPE="release"
TFA_OUTPUT=${TFA_DIR}/build/g2l/${BUILD_TYPE}

if [ -f "${TFA_OUTPUT}/bl2_bp_mmc.srec" ] && [ -f "${TFA_OUTPUT}/fip.srec" ]; then
	echo "### Generated FIP files successfully!! ###"
	ls -alh ${TFA_OUTPUT}/*.srec
else
	echo "### Generated FIP files failed!! ###"
	exit 0
fi

cp ${TFA_OUTPUT}/bl2_bp_mmc.srec ${OUTPUT_DIR}bl2_bp_mmc-smarc-rzg2l_pmic.srec
cp ${TFA_OUTPUT}/fip.srec ${OUTPUT_DIR}fip-smarc-rzg2l_pmic.srec
cp ${TFA_OUTPUT}/bl2_bp_mmc.bin ${OUTPUT_DIR}bl2_bp_mmc-smarc-rzg2l_pmic.bin
cp ${TFA_OUTPUT}/fip.bin ${OUTPUT_DIR}fip-smarc-rzg2l_pmic.bin

if [ -f "${OUTPUT_DIR}bl2_bp_mmc-smarc-rzg2l_pmic.srec" ] && [ -f "${OUTPUT_DIR}fip-smarc-rzg2l_pmic.srec" ]; then
	echo "### Copied FIP files successfully!! ###"
	ls -alh ${OUTPUT_DIR}*.srec
else
	echo "### Copied FIP files failed!! ###"
	exit 0
fi

date
