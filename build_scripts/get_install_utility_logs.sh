#!/bin/bash

# ./get_install_utility_logs.sh <FASTBOOT> <PROTOCOL> <MODE> <FILE1> <FILE2_OPTIONAL>

set -eu

FASTBOOT=$1
PROTOCOL=$2
MODE=$3

LOG_FILE="flash_log.txt"
TEMP_LOG=".fastboot_temp.log"
STATUS="SUCCESS"
BOARD_NAME=""

FASTBOOT_BUF_ADDR=0x4D000000

if [ ! -f "$FASTBOOT" ]; then
	echo "Error: Fastboot executable not found at $FASTBOOT"
	exit 1
fi

if [ -f "$LOG_FILE" ]; then
	rm "$LOG_FILE"
fi

exec > >(tee -a "$LOG_FILE")
exec 2>&1

###############################################################################
# Helper Functions
###############################################################################

print_section()
{
	printf '%s\n' "--------------------------------------------------------------------------------"
	echo "$1"
	printf '%s\n' "--------------------------------------------------------------------------------"
	echo
}

print_field() {
	printf '\t%-16s: %s\n' "$1" "$2"
}

print_crc_verification()
{
	local section="$1"
	local board_crc="$2"
	local expected_crc="$3"

	echo "[$section]"

	print_field "Board CRC32" "$board_crc"
	print_field "Expected CRC32" "$expected_crc"

	if [ "$board_crc" = "$expected_crc" ]; then
		print_field "Result" "MATCH"
		return 0
	else
		print_field "Result" "MISMATCH"
		return 1
	fi
}

cleanup_wic_mount()
{
	if mountpoint -q "$MOUNT_DIR" 2>/dev/null; then
		sudo umount "$MOUNT_DIR"
	fi

	if [ -n "${TEMP_LOOP:-}" ]; then
		sudo losetup -d "$TEMP_LOOP" 2>/dev/null || true
	fi

	sudo rmdir "$MOUNT_DIR" 2>/dev/null || true

	if [ -f "$WIC_FILE" ]; then
		rm -f "$WIC_FILE"
	fi
}

###############################################################################
# Header
###############################################################################

PLATFORM=$(sudo "$FASTBOOT" -s "$PROTOCOL" getvar platform 2>&1 | sed -n 's/.*platform:[[:space:]]*//p')
{
	case "$PLATFORM" in
		r9a07g044l)
			BOARD_NAME="RZ/G2L"
			;;
		r9a08g045s)
			BOARD_NAME="RZ/G3S"
			;;
		r9a09g047)
			BOARD_NAME="RZ/G3E"
			;;
		r9a08g046)
			BOARD_NAME="RZ/G3L"
			;;
		*)
			echo "Error: Board not support"
			exit 1
			;;
	esac
}

{
	echo "================================================================================"
	echo "                         INSTALL UTILITY FLASH REPORT"
	echo "================================================================================"
	echo

	echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"

	echo
	echo "[HOST]"
	print_field "Hostname" "$(hostname)"
	print_field "OS" "$(grep PRETTY_NAME /etc/os-release | cut -d '"' -f2)"
	print_field "User" "$(whoami)"

	echo
	echo "[FASTBOOT]"
	print_field "Binary" "$FASTBOOT"
	print_field "Version" "$("$FASTBOOT" --version | head -1)"
	print_field "Protocol" "$PROTOCOL"

	echo
	echo "[TARGET]"
	print_field "Platform" "$PLATFORM"
	print_field "Board name" "$BOARD_NAME"
	print_field "U-Boot" "$( sudo "$FASTBOOT" -s "$PROTOCOL" getvar version-bootloader 2>&1 | sed -n 's/.*version-bootloader:[[:space:]]*//p' )"

	echo
}

###############################################################################
# Main Flow
###############################################################################
case $MODE in
	###############################################################################
	# WIC FLASH
	###############################################################################
	1)
		if [ $# -lt 4 ]; then
			echo "Error: Missing WIC file path"
			exit 1
		fi

		INPUT_WIC=$4
		if [ ! -f "$INPUT_WIC" ]; then
			echo "Error: File not found: $INPUT_WIC"
			exit 1
		else
			case "$INPUT_WIC" in
				*.wic.gz)
					WIC_FILE="${INPUT_WIC%.gz}"
					gzip -dk "$INPUT_WIC"
					;;
				*)
					echo "Error: Input file must be .wic.gz"
					exit 1
					;;
			esac
		fi

		truncate -s %4096 $WIC_FILE

		# [WIC FLASH] SOURCE IMAGE CHECKSUMS
		print_section "SOURCE IMAGE CHECKSUMS"

		WIC_NAME=$(basename "$WIC_FILE")
		WIC_CRC=$(crc32 "$WIC_FILE")

		MOUNT_DIR="/mnt/wic_boot"
		sudo mkdir -p "$MOUNT_DIR"

		TEMP_LOOP=$(sudo losetup --show -Pf "$WIC_FILE")
		trap cleanup_wic_mount EXIT

		BOOT_PART="${TEMP_LOOP}p1"
		if [ ! -e "$BOOT_PART" ]; then
			echo "[ERROR] Boot partition not found: $BOOT_PART"
			sudo losetup -d "$TEMP_LOOP"
			exit 1
		fi

		sudo mount -o ro "$BOOT_PART" "$MOUNT_DIR"

		if [[ "$BOARD_NAME" == "RZ/G2L" ]]; then
			BL2_FILE=$(find "$MOUNT_DIR" -maxdepth 1 -type f -name "bl2_bp_mmc*_pmic.bin" | head -n1)
			FIP_FILE=$(find "$MOUNT_DIR" -maxdepth 1 -type f -name "fip*_pmic.bin" | head -n1)
		else
			BL2_FILE=$(find "$MOUNT_DIR" -maxdepth 1 -type f -name "bl2_bp_mmc*.bin" | head -n1)
			FIP_FILE=$(find "$MOUNT_DIR" -maxdepth 1 -type f -name "fip*.bin" | head -n1)
		fi

		if [ -z "$BL2_FILE" ]; then
			echo "[ERROR] BL2 image not found in WIC"
			exit 1
		fi

		if [ -z "$FIP_FILE" ]; then
			echo "[ERROR] FIP image not found in WIC"
			exit 1
		fi

		BL2_NAME=$(basename "$BL2_FILE")
		BL2_CRC=$(crc32 "$BL2_FILE")

		FIP_NAME=$(basename "$FIP_FILE")
		FIP_CRC=$(crc32 "$FIP_FILE")

		echo "[WIC IMAGE]"
		print_field "File name" "$WIC_NAME"
		print_field "CRC32" "$WIC_CRC"
		echo

		echo "[BL2 IMAGE]"
		print_field "File name" "$BL2_NAME"
		print_field "CRC32" "$BL2_CRC"
		echo

		echo "[FIP IMAGE]"
		print_field "File name" "$FIP_NAME"
		print_field "CRC32" "$FIP_CRC"
		echo

		# [WIC FLASH] FASTBOOT EXECUTION
		print_section "FASTBOOT EXECUTION"

		echo "Command:"
		printf '\t%s\n' "sudo ./fastboot -s $PROTOCOL flash mmc0 $WIC_FILE"
		echo

		echo "Output:"
		sudo "$FASTBOOT" -s "$PROTOCOL" flash mmc0 $WIC_FILE 2>&1 | sed 's/^/\t/'  | tee "$TEMP_LOG"
		echo

		# [WIC FLASH] TARGET VERIFICATION
		print_section "TARGET VERIFICATION"

		ERR=$(grep -Ei "FAILED|error:" "$TEMP_LOG" || true)
		TOTAL_TIME=$(grep "Finished. Total time:" "$TEMP_LOG" | awk '{print $4}' | sed 's/s//')

		if [ -z "$ERR" ] && [ -n "$TOTAL_TIME" ]; then
			RAW_SIZE=$(stat -c%s "$WIC_FILE")
			RAW_SIZE_HEX=$(printf "0x%x" "$RAW_SIZE")
			VERIFY_BLK_NUMS=$(( (RAW_SIZE + 511) / 512 ))
			VERIFY_BLK_NUMS_HEX=$(printf "0x%x" "$VERIFY_BLK_NUMS")

			{
				sudo "$FASTBOOT" -s "$PROTOCOL" oem run:"mmc dev 0"
				sudo "$FASTBOOT" -s "$PROTOCOL" oem run:"mmc read $FASTBOOT_BUF_ADDR 0 $VERIFY_BLK_NUMS_HEX"
				sudo "$FASTBOOT" -s "$PROTOCOL" oem run:"crc32 $FASTBOOT_BUF_ADDR $RAW_SIZE_HEX $FASTBOOT_BUF_ADDR"

				sudo "$FASTBOOT" -s "$PROTOCOL" getvar crc32:wic
				sudo "$FASTBOOT" -s "$PROTOCOL" getvar crc32:bl2
				sudo "$FASTBOOT" -s "$PROTOCOL" getvar crc32:fip
			} >> "$TEMP_LOG" 2>&1

			WIC_CRC_BOARD=$(sed -n 's/.*crc32:wic:[[:space:]]*//p' "$TEMP_LOG" | tail -1)
			BL2_CRC_BOARD=$(sed -n 's/.*crc32:bl2:[[:space:]]*//p' "$TEMP_LOG" | tail -1)
			FIP_CRC_BOARD=$(sed -n 's/.*crc32:fip:[[:space:]]*//p' "$TEMP_LOG" | tail -1)

			print_crc_verification "ROOTFS" "$WIC_CRC_BOARD" "$WIC_CRC" || STATUS="FAIL"
			echo
			print_crc_verification "BL2" "$BL2_CRC_BOARD" "$BL2_CRC" || STATUS="FAIL"
			echo
			print_crc_verification "FIP" "$FIP_CRC_BOARD" "$FIP_CRC" || STATUS="FAIL"
			echo
		else
			echo "Skip TARGET VERIFICATION"
			echo
			STATUS="FAIL"
		fi

		# [WIC FLASH] SUMMARY
		print_section "SUMMARY"

		if [ "$STATUS" = "SUCCESS" ]; then
			SIZE_MB=$(echo "scale=2; $RAW_SIZE / 1048576" | bc)
			AVG_SPEED=$(echo "scale=2; $SIZE_MB / $TOTAL_TIME" | bc)

			print_field "Total written size" "$RAW_SIZE bytes (${SIZE_MB} MB)"
			print_field "Total elapsed time" "${TOTAL_TIME} s"
			print_field "Average Speed" "${AVG_SPEED} MB/s"
		fi

		print_field "Status" "$STATUS"
		echo "================================================================================"
		;;

	###############################################################################
	# UPDATE BOOTLOADER
	###############################################################################
	2)
		if [ $# -lt 5 ]; then
			echo "Error: Missing Bootloader files!"
			exit 1
		fi

		BL2_FILE=$4
		if [ -z "$BL2_FILE" ]; then
			echo "[ERROR] BL2 image not found in WIC"
			exit 1
		fi

		FIP_FILE=$5
		if [ -z "$FIP_FILE" ]; then
			echo "[ERROR] FIP image not found in WIC"
			exit 1
		fi

		# [UPDATE BL] SOURCE IMAGE CHECKSUMS
		print_section "SOURCE IMAGE CHECKSUMS"

		BL2_NAME=$(basename "$BL2_FILE")
		BL2_CRC=$(crc32 "$BL2_FILE")

		FIP_NAME=$(basename "$FIP_FILE")
		FIP_CRC=$(crc32 "$FIP_FILE")

		echo "[BL2 IMAGE]"
		print_field "File name" "$BL2_NAME"
		print_field "CRC32" "$BL2_CRC"
		echo

		echo "[FIP IMAGE]"
		print_field "File name" "$FIP_NAME"
		print_field "CRC32" "$FIP_CRC"
		echo

		# [UPDATE BL] FASTBOOT EXECUTION
		print_section "FASTBOOT EXECUTION"

		echo "[Staging BL2]: sudo "$FASTBOOT" -s "$PROTOCOL" stage "$BL2_FILE" "
		sudo "$FASTBOOT" -s "$PROTOCOL" stage "$BL2_FILE" 2>&1 | sed 's/^/\t/' | tee -a "$TEMP_LOG"

		echo "[Writing BL2]: sudo "$FASTBOOT" -s "$PROTOCOL" oem emmcupdate:writebl2"
		sudo "$FASTBOOT" -s "$PROTOCOL" oem emmcupdate:writebl2 2>&1 | sed 's/^/\t/' | tee -a "$TEMP_LOG"

		echo "[Staging FIP]: sudo "$FASTBOOT" -s "$PROTOCOL" stage "$FIP_FILE""
		sudo "$FASTBOOT" -s "$PROTOCOL" stage "$FIP_FILE" 2>&1 | sed 's/^/\t/' | tee -a "$TEMP_LOG"

		echo "[Writing FIP]: sudo "$FASTBOOT" -s "$PROTOCOL" oem emmcupdate:writefip"
		sudo "$FASTBOOT" -s "$PROTOCOL" oem emmcupdate:writefip 2>&1 | sed 's/^/\t/' | tee -a "$TEMP_LOG"

		echo

		# [UPDATE BL] TARGET VERIFICATION
		print_section "TARGET VERIFICATION"

		ERR=$(grep -Ei "FAILED|error:" "$TEMP_LOG" || true)

		if [ -z "$ERR" ]; then
			sudo "$FASTBOOT" -s "$PROTOCOL" getvar crc32:bl2 >> "$TEMP_LOG" 2>&1
			sudo "$FASTBOOT" -s "$PROTOCOL" getvar crc32:fip >> "$TEMP_LOG" 2>&1

			BL2_CRC_BOARD=$(sed -n 's/.*crc32:bl2:[[:space:]]*//p' "$TEMP_LOG" | tail -1)
			FIP_CRC_BOARD=$(sed -n 's/.*crc32:fip:[[:space:]]*//p' "$TEMP_LOG" | tail -1)

			print_crc_verification "BL2" "$BL2_CRC_BOARD" "$BL2_CRC" || STATUS="FAIL"
			echo
			print_crc_verification "FIP" "$FIP_CRC_BOARD" "$FIP_CRC" || STATUS="FAIL"
			echo
		else
			echo "Skip TARGET VERIFICATION"
			echo
			STATUS="FAIL"
		fi

		# [UPDATE BL] SUMMARY
		print_section "SUMMARY"
		print_field "Status" "$STATUS"
		echo "================================================================================"
		;;

	*)
		echo "Invalid mode: $MODE. Use 1 (WIC) or 2 (BL)."
		exit 1
		;;

esac

rm -f "$TEMP_LOG"

echo "Done! Log saved to $LOG_FILE"
