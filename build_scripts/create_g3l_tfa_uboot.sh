#!/bin/bash
#
# Script to build U-Boot and TF-A and generate FIP files for RZ/G3L (SMARC).
#

set -e

WORKDIR=${1-`pwd`/../..}

#======DEVICE======
PLATFORM=g3l
BOARD=smarc
PMIC=
if [[ "${PLATFORM}" = "g2l" && -n "${PMIC}" ]]; then
	TFA_BOARD=smarc_pmic_2
	TFA_PLAT=${PLATFORM}_pmic
else
	TFA_BOARD=${BOARD}
	TFA_PLAT=${PLATFORM}
fi

#======INPUT=======
UBOOT_DIR=$WORKDIR/rz_tool_u-boot
TFA_DIR=$WORKDIR/rzg_trusted-firmware-a

#======OUTPUT=======
OUTPUT_DIR=$WORKDIR/output/
rm -rvf $OUTPUT_DIR
mkdir $OUTPUT_DIR

#======SETUP=======
export ARCH=arm64
source gcc_10.3.sh

#======UBOOT=======
cd ${UBOOT_DIR}
make clean
make ${BOARD}-rz${PLATFORM}_defconfig
make -j$(nproc)

#======TFA========
cd ${TFA_DIR}
make PLAT=${PLATFORM} BOARD=${TFA_BOARD} realclean
make PLAT=${PLATFORM} BOARD=${TFA_BOARD} BL33=${UBOOT_DIR}/u-boot.bin bl2 fip bptool pkg

# #=======TFA_OUTPUT==========
BUILD_TYPE="release"
TFA_OUTPUT=${TFA_DIR}/build/${PLATFORM}/${BUILD_TYPE}

cp ${TFA_OUTPUT}/bl2_bp_mmc.srec ${OUTPUT_DIR}/bl2_bp_mmc-${BOARD}-rz${TFA_PLAT}.srec
cp ${TFA_OUTPUT}/fip.srec ${OUTPUT_DIR}/fip-${BOARD}-rz${TFA_PLAT}.srec
cp ${TFA_OUTPUT}/bl2_bp_mmc.bin ${OUTPUT_DIR}/bl2_bp_mmc-${BOARD}-rz${TFA_PLAT}.bin
cp ${TFA_OUTPUT}/fip.bin ${OUTPUT_DIR}/fip-${BOARD}-rz${TFA_PLAT}.bin
ls -alh ${OUTPUT_DIR}*

date
