#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run as root."
  exit 1
fi

if [ $# -ne 1 ]; then
  echo "Usage: $0 <output-repacked-firmware.bin>"
  exit 1
fi

if [ -f "$1" ]; then
  echo "Error: Output file already exists: $1"
  exit 1
fi

output_fw="$1"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
CFG="$REPO_DIR/configs/ubinize-ipq50xx.cfg"

if [ ! -f "$CFG" ]; then
  echo "Error: Config file not found: $CFG"
  exit 1
fi

# Ensure md5-fix is compiled
if [ ! -f "$SCRIPT_DIR/md5-fix" ]; then
  echo "Compiling md5-fix tool..."
  make -C "$SCRIPT_DIR"
fi

mkdir -p tmp
echo "Compressing squashfs filesystem (xz 256K block)..."
mksquashfs squashfs-root/ tmp/rootfs.bin -comp xz -b 256K -noappend

kernel=$(find tmp/ -name "*kernel.ubifs" | head -n 1)
if [ -z "$kernel" ]; then
  echo "Error: kernel.ubifs not found in tmp/"
  exit 1
fi

cp -f "$kernel" tmp/kernel.itb

echo "Building UBI image with ubinize..."
ubinize -m 2048 -p 128KiB -o tmp/ubi-new.img "$CFG"

echo "Combining header and new UBI image..."
cat tmp/header.bin tmp/ubi-new.img > "$output_fw"

echo "Applying TP-Link header flag patch..."
printf '\x50\x72' | dd of="$output_fw" bs=1 seek=28 count=2 conv=notrunc status=none

echo "Calculating and fixing MD5 checksum in header..."
"$SCRIPT_DIR/md5-fix" "$output_fw"

rm -rf tmp
echo "Successfully generated repacked firmware: $output_fw"
