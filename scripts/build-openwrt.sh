#!/bin/bash
set -e

# Clear Windows PATH interference if running inside WSL
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${1:-$HOME/openwrt}"

echo "=== OpenWrt Source Build for TP-Link Archer AX55 v1 ==="
echo "Build directory: $BUILD_DIR"

if [ ! -d "$BUILD_DIR/.git" ]; then
  echo "Cloning official OpenWrt source repository..."
  git clone --depth 1 https://github.com/openwrt/openwrt.git "$BUILD_DIR"
fi

cd "$BUILD_DIR"

echo "Updating and installing feeds (packages, LuCI)..."
./scripts/feeds update -a
./scripts/feeds install -a

echo "Applying SerDes cold-boot timing patch (PR #25153)..."
PATCH_FILE="$REPO_DIR/patches/740-net-dsa-realtek-rtl8365mb-delay-serdes-up-until-cond.patch"
if git apply --check "$PATCH_FILE" 2>/dev/null; then
  git apply "$PATCH_FILE"
  echo "Patch applied successfully."
else
  echo "Patch check skipped or already applied."
fi

echo "Configuring target: qualcommax / ipq50xx / tplink_archer-ax55-v1..."
cat << 'EOF' > .config
CONFIG_TARGET_qualcommax=y
CONFIG_TARGET_qualcommax_ipq50xx=y
CONFIG_TARGET_qualcommax_ipq50xx_DEVICE_tplink_archer-ax55-v1=y
CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_luci-ssl=y
CONFIG_PACKAGE_kmod-dsa-rtl8365mb=y
CONFIG_PACKAGE_ath11k-firmware-ipq5018-qcn6122=y
CONFIG_PACKAGE_ipq-wifi-tplink_archer-ax55-v1=y
EOF

make defconfig

echo "Pre-fetching source packages..."
make -j"$(nproc)" download

echo "Compiling firmware with $(nproc) parallel threads..."
make -j"$(nproc)"

echo "=== Build Complete! Images located at: ==="
ls -lh bin/targets/qualcommax/ipq50xx/*archer-ax55*
