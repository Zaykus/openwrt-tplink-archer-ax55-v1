# OpenWrt Installation Guide & Build Tools for TP-Link Archer AX55 v1

This repository provides comprehensive instructions, scripts, and kernel patches to build and install OpenWrt on the **TP-Link Archer AX55 v1** wireless router without requiring a hardware serial (UART) connection.

![OpenWrt LuCI Web Interface on TP-Link Archer AX55 v1](docs/images/luci-status.png)

---

## 📥 Pre-Compiled Firmware Downloads

Pre-built, patched OpenWrt binaries (including the **SerDes timing fix** and the **LuCI Web GUI**) are available on the [**GitHub Releases Page**](https://github.com/Zaykus/openwrt-tplink-archer-ax55-v1/releases):

| File | Size | Description |
| :--- | :--- | :--- |
| `openwrt-qualcommax-ipq50xx-tplink_archer-ax55-v1-initramfs-factory.ubi` | ~13.8 MB | Intermediate RAM boot image (used in Step 3) |
| `openwrt-qualcommax-ipq50xx-tplink_archer-ax55-v1-squashfs-sysupgrade.bin` | ~13.4 MB | Permanent flash image with LuCI Web GUI (used in Step 4) |

### Checksums (SHA-256)
```text
b5b812b1a38489b411c5c8304c339bd81b1b21fc911742eb05bd26d0e0987fa5  openwrt-qualcommax-ipq50xx-tplink_archer-ax55-v1-initramfs-factory.ubi
e64716535c4fea0c3577d9a124b3a480941845c32f7365570da4717f89ca20b3  openwrt-qualcommax-ipq50xx-tplink_archer-ax55-v1-squashfs-sysupgrade.bin
```

---

## Hardware Specifications

| Component | Specification |
| :--- | :--- |
| **Model** | TP-Link Archer AX55 (Hardware Version: v1) |
| **SoC** | Qualcomm IPQ5018 (Dual-Core ARM Cortex-A53 @ 1.0 GHz) |
| **RAM** | 512 MB DDR3L |
| **Flash Storage** | 128 MB SPI NAND Flash |
| **Ethernet Switch** | Realtek RTL8367S (DSA switch) |
| **Wi-Fi 2.4 GHz** | Qualcomm IPQ5018 (802.11b/g/n/ax, 2x2 MIMO) |
| **Wi-Fi 5 GHz** | Qualcomm QCN6102 / QCN6122 (802.11a/n/ac/ax, 2x2 MIMO, 160 MHz) |
| **USB** | 1x USB 3.0 Type-A |

---

## Key Features & Fixes in this Release

1. **Kernel SerDes Timing Fix (PR #25153)**:
   * Resolves the known race condition where the link between the Qualcomm IPQ5018 CPU and the Realtek RTL8367S switch initializes in the reverse order on cold boots, leaving Ethernet ports dead.
   * Holds back SerDes bring-up until the network conduit reports operational, ensuring all wired ports come up reliably on every reboot.
2. **LuCI Web GUI Pre-installed**:
   * Upstream snapshot images lack a web interface by default. This build bakes `luci` and `luci-ssl` directly into the firmware image so `http://192.168.1.1` opens immediately upon boot.
3. **No-Serial Installation Method**:
   * Utilizes an unencrypted stock firmware base image to inject Telnet access, enabling a completely software-based flashing procedure without opening the router casing.

---

## Repository Structure

```
├── configs/
│   └── ubinize-ipq50xx.cfg      # UBI volume layout configuration
├── docs/
│   └── images/
│       └── luci-status.png      # LuCI dashboard status screenshot
├── patches/
│   └── 740-net-dsa-realtek-rtl8365mb-delay-serdes-up-until-cond.patch  # SerDes cold-boot fix
├── scripts/
│   ├── 01-unpack.sh             # Unpack stock firmware UBI/squashfs
│   ├── 02-repack.sh             # Repack modified rootfs with MD5 fix
│   ├── Makefile                 # Builds the local MD5 checksum tool
│   ├── md5-fix.c                # C utility to compute header checksums
│   └── build-openwrt.sh         # Automates source compilation in Linux/WSL
├── .gitignore                   # Excludes binaries, images, and archives
└── README.md
```

---

## Step-by-Step Installation Guide (No Serial Required)

### Step 1: Create and Flash Telnet-Enabled Stock Firmware

1. Sourcing a stock unencrypted firmware image (version 1.3.3 or earlier).
2. Install prerequisites on your Linux / WSL environment:
   ```bash
   sudo apt update
   sudo apt install -y build-essential gcc make libssl-dev mtd-utils squashfs-tools python3 python3-pip
   pip install ubi_reader
   ```
3. Unpack the stock image as root:
   ```bash
   sudo ./scripts/01-unpack.sh stock_firmware.bin
   ```
4. Add `telnetd -l /bin/sh &` into `squashfs-root/etc/rc.local` immediately before `exit 0`.
5. Repack the firmware:
   ```bash
   sudo ./scripts/02-repack.sh ax55-repacked-telnet.bin
   ```
6. Navigate to the stock router web interface (`http://192.168.0.1`), open **Advanced** -> **System Tools** -> **Firmware Upgrade**, and flash `ax55-repacked-telnet.bin`.

---

### Step 2: Switch Hardware Verification

Once the router reboots, connect via Telnet:

```bash
telnet 192.168.0.1
```

Run the switch verification check:

```bash
dmesg | grep -o 'find rtk switch [0-9]*'
```

* **`find rtk switch 0`**: Supported RTL8367S switch. Proceed to Step 3.
* **Other or empty**: Stop installation (indicates the alternative `-VB` switch variant which lacks driver support in current OpenWrt).

---

### Step 3: Flash OpenWrt via RAM Boot

1. Start an HTTP server on your PC in the directory containing the downloaded release images:
   ```bash
   python3 -m http.server 8000
   ```
2. In the router Telnet session, download the RAM boot image:
   ```bash
   cd /tmp
   wget http://<PC_IP>:8000/openwrt-qualcommax-ipq50xx-tplink_archer-ax55-v1-initramfs-factory.ubi -O factory.ubi
   ```
3. Identify the inactive partition slot:
   ```bash
   fw_printenv tp_boot_idx
   cat /proc/mtd | grep -E '"rootfs"|"rootfs_1"'
   ```
4. Flash the inactive partition. For example, if active is `tp_boot_idx=1` (`rootfs_1`), write to `mtd11` (`rootfs`):
   ```bash
   mtd erase /dev/mtd11
   mtd write /tmp/factory.ubi /dev/mtd11
   fw_setenv tp_boot_idx 0
   fw_setenv config_name config@mp03.3
   reboot
   ```

---

### Step 4: Final Permanent OpenWrt Installation

1. After rebooting, the router starts OpenWrt in RAM at `192.168.1.1`.
2. Connect via SSH:
   ```bash
   ssh root@192.168.1.1
   ```
3. Download and flash the permanent sysupgrade image:
   ```bash
   cd /tmp
   wget http://<PC_IP>:8000/openwrt-qualcommax-ipq50xx-tplink_archer-ax55-v1-squashfs-sysupgrade.bin -O sysupgrade.bin
   sysupgrade -n /tmp/sysupgrade.bin
   ```
4. The router flashes NAND memory and reboots permanently into OpenWrt with LuCI enabled.

---

### Step 5: Web Control Panel & Wi-Fi Configuration

1. Connect your PC to any yellow LAN port and open `http://192.168.1.1` in your browser.
2. Log in (default password is empty) and set an administrative password under **System** -> **Administration**.
3. Under **Network** -> **Wireless**, configure both radios:
   * **`radio0`**: 2.4 GHz (802.11ax)
   * **`radio1`**: 5 GHz (802.11ax)
4. Set your SSID and security mode (`WPA2-PSK/WPA3-SAE mixed`), then click **Enable** and **Save & Apply**.

---

### Step 6: Setting up Wi-Fi Repeater / Range Extender Mode (Optional)

To connect the router to an existing Wi-Fi network and re-broadcast it:
1. Go to **Network** -> **Wireless**.
2. Click **Scan** on the radio corresponding to the source network (e.g. `radio1` for 5 GHz).
3. Find your network, click **Join Network**, enter the password, and ensure the firewall zone is set to **`wan`**.
4. Keep the **Master (Access Point)** interface active to broadcast your private Wi-Fi network.
5. Click **Save & Apply**.

---

## Recovery Procedure (Return to OEM)

The Archer AX55 features an indestructible U-Boot hardware web recovery:

1. Configure your PC with static IP `192.168.0.10` / subnet `255.255.255.0` and connect via Ethernet to LAN 1.
2. Turn off the router.
3. Hold the **Reset button** with a pin while powering on, keep holding for 10 seconds, then release.
4. Navigate to `http://192.168.0.1` in your web browser.
5. Upload an official signed TP-Link firmware image to restore factory software.

---

## License

All original scripts and documentation in this repository are released under the MIT License.
OpenWrt kernel patches adhere to the GNU General Public License v2 (GPL-2.0).
