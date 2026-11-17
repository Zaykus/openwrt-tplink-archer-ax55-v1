#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run as root to preserve device nodes (like /dev/console)."
  exit 1
fi

if [ $# -ne 1 ]; then
  echo "Usage: $0 <firmware.bin>"
  exit 1
fi

if [ ! -f "$1" ]; then
  echo "Error: File not found: $1"
  exit 1
fi

firmware="$1"
pos=$(grep -a -b -m 1 "UBI#" "$firmware" | cut -d ":" -f 1)
if [ -z "$pos" ]; then
  echo "Error: Could not locate UBI# signature in $firmware"
  exit 1
fi

mkdir -p tmp
echo "Splitting firmware at offset $pos..."
dd if="$firmware" of=tmp/header.bin bs="$pos" count=1 status=none
dd if="$firmware" of=tmp/ubi.img bs="$pos" skip=1 status=none

cd tmp
echo "Extracting UBI volumes with ubireader..."
ubireader_extract_images ubi.img

cd ..
rootfs_ubifs=$(find tmp/ -name "*rootfs.ubifs" | head -n 1)
if [ -z "$rootfs_ubifs" ]; then
  echo "Error: rootfs.ubifs not found"
  exit 1
fi

echo "Unsquashing root filesystem..."
unsquashfs -d squashfs-root "$rootfs_ubifs"

# Verify /dev/console
if [ ! -e squashfs-root/dev/console ]; then
  echo "Warning: /dev/console missing, creating character device node..."
  mkdir -p squashfs-root/dev
  mknod -m 600 squashfs-root/dev/console c 5 1
fi

echo "Successfully unpacked rootfs to squashfs-root."
echo "Modify files under squashfs-root (e.g. enable telnetd in etc/rc.local), then run 02-repack.sh."
