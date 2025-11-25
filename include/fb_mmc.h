/* SPDX-License-Identifier: GPL-2.0+ */
/*
 * Copyright 2014 Broadcom Corporation.
 */

#ifndef _FB_MMC_H_
#define _FB_MMC_H_

extern uint8_t f_completed_flash_wic;

#define EMMC_BLOCK_SIZE 512

/* Maximum number of SDHI (SD Host Interface) controllers supported by the SoC. */
#define MAX_SDHI_CONTROLLER 3

#define BL2_ADD_SAVE_TO_EMMC 0x00000001
#define FIP_ADD_300_SAVE_TO_EMMC 0x00000300
#define FIP_ADD_320_SAVE_TO_EMMC 0x00000320
#define BL2_BP_EMMC "bl2_bp_emmc-smarc-rzg3s.bin"
#define BL2_BP_MMC "bl2_bp_mmc-smarc-rzg3s.bin"
#define CMD_UPDATE_BOOTLOADER_BL2_EMMC \
	"fatload mmc 0:1 0x4D000000 " BL2_BP_EMMC
#define CMD_UPDATE_BOOTLOADER_BL2_MMC \
	"fatload mmc 0:1 0x4D000000 " BL2_BP_MMC
#define CMD_UPDATE_BOOTLOADER_FIP \
	"fatload mmc 0:1 0x4D000000 fip-smarc-rzg3s.bin"

struct blk_desc;
struct disk_partition;

/**
 * fastboot_mmc_get_part_info() - Lookup eMMC partion by name
 *
 * @part_name: Named partition to lookup
 * @dev_desc: Pointer to returned blk_desc pointer
 * @part_info: Pointer to returned struct disk_partition
 * @response: Pointer to fastboot response buffer
 */
int fastboot_mmc_get_part_info(const char *part_name,
			       struct blk_desc **dev_desc,
			       struct disk_partition *part_info,
			       char *response);

/**
 * fastboot_mmc_flash_write() - Write image to eMMC for fastboot
 *
 * @cmd: Named partition to write image to
 * @download_buffer: Pointer to image data
 * @download_bytes: Size of image data
 * @response: Pointer to fastboot response buffer
 */
void fastboot_mmc_flash_write(const char *cmd, void *download_buffer,
			      u32 download_bytes, char *response);
/**
 * fastboot_mmc_flash_erase() - Erase eMMC for fastboot
 *
 * @cmd: Named partition to erase
 * @response: Pointer to fastboot response buffer
 */
void fastboot_mmc_erase(const char *cmd, char *response);
#endif

/**
 * write_to_eMMC_bootpart() - Write data to eMMC Boot Partition
 *
 * @blk_start: Start block
 */
int write_to_eMMC_bootpart(size_t blk_start);

/**
 * update_bootloader_to_eMMC(void) - Update bootloader for eMMC from the WIC image
 */
void update_bootloader_to_eMMC(void);
