#!/bin/bash
#
# Script to build U-Boot and TF-A and generate FIP files for RZ/G3S (SMARC).
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
make smarc-rzg3s_defconfig
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
make PLAT=g3s realclean BOARD=smarc
make PLAT=g3s BOARD=smarc PLAT_SYSTEM_SUSPEND=vbat  bl2 bl31 bptool fiptool
cd -

#=======BUILD==========
BUILD_TYPE="release"
TFA_OUTPUT=${TFA_DIR}/build/g3s/${BUILD_TYPE}
BPTOOL=${TFA_DIR}/tools/renesas/bptool
FIPTOOL=${TFA_DIR}/tools/fiptool/fiptool

${BPTOOL} ${TFA_OUTPUT}/bl2.bin ${TFA_OUTPUT}/bp_mmc.bin 0xA3000 mmc
cat ${TFA_OUTPUT}/bp_mmc.bin ${TFA_OUTPUT}/bl2.bin > ${TFA_OUTPUT}/bl2_bp_mmc.bin
objcopy -I binary -O srec --adjust-vma=0xA1E00 --srec-forceS3 ${TFA_OUTPUT}/bl2_bp_mmc.bin  ${TFA_OUTPUT}/bl2_bp_mmc.srec
${FIPTOOL} create --align 16 --soc-fw ${TFA_OUTPUT}/bl31.bin --nt-fw ${UBOOT_DIR}/u-boot.bin ${TFA_OUTPUT}/fip.bin
objcopy -I binary -O srec --adjust-vma=0x0000 --srec-forceS3 ${TFA_OUTPUT}/fip.bin ${TFA_OUTPUT}/fip.srec

if [ -f "${TFA_OUTPUT}/bl2_bp_mmc.srec" ] && [ -f "${TFA_OUTPUT}/fip.srec" ]; then
	echo "### Generated FIP files successfully!! ###"
	ls -alh ${TFA_OUTPUT}/*.srec
else
	echo "### Generated FIP files failed!! ###"
	exit 0
fi

cp ${TFA_OUTPUT}/bl2_bp_mmc.srec ${OUTPUT_DIR}bl2_bp_mmc-smarc-rzg3s.srec
cp ${TFA_OUTPUT}/fip.srec ${OUTPUT_DIR}fip-smarc-rzg3s.srec
cp ${TFA_OUTPUT}/bl2_bp_mmc.bin ${OUTPUT_DIR}bl2_bp_mmc-smarc-rzg3s.bin
cp ${TFA_OUTPUT}/fip.bin ${OUTPUT_DIR}fip-smarc-rzg3s.bin

if [ -f "${OUTPUT_DIR}bl2_bp_mmc-smarc-rzg3s.srec" ] && [ -f "${OUTPUT_DIR}fip-smarc-rzg3s.srec" ]; then
	echo "### Copied FIP files successfully!! ###"
	ls -alh ${OUTPUT_DIR}*.srec
else
	echo "### Copied FIP files failed!! ###"
	exit 0
fi

date
