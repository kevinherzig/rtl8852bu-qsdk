#!/bin/sh
# One-line installer for RTL8852BU driver on GL-BE3600 (QSDK 12.5)
# Usage: wget -O- https://raw.githubusercontent.com/kevinherzig/rtl8852bu-qsdk/main/install.sh | sh

set -e

PKG_URL="https://github.com/kevinherzig/rtl8852bu-qsdk/releases/download/v1.0.0-qsdk12.5/kmod-rtl8852bu_1.1.0-1_aarch64_cortex-a53_neon-vfpv4.ipk"
PKG_FILE="/tmp/kmod-rtl8852bu.ipk"

echo "=== RTL8852BU Driver Installer ==="

# Check architecture
ARCH=$(uname -m)
if [ "$ARCH" != "aarch64" ]; then
    echo "Error: This package is for aarch64. Your architecture: $ARCH"
    exit 1
fi

# Check kernel version
KVER=$(uname -r)
if [ "$KVER" != "5.4.213" ]; then
    echo "Warning: This package was built for kernel 5.4.213. Your kernel: $KVER"
    echo "The module may fail to load if vermagic doesn't match."
    echo "Press Ctrl+C to cancel, or wait 5 seconds to continue..."
    sleep 5
fi

echo "Downloading package..."
wget --no-check-certificate -O "$PKG_FILE" "$PKG_URL" 2>&1

echo "Installing..."
opkg install --force-reinstall "$PKG_FILE"
rm -f "$PKG_FILE"

echo "Loading module..."
insmod 8852bu rtw_power_mgnt=0 rtw_ips_mode=0 2>/dev/null || true
sleep 2

echo "Restarting network..."
/etc/init.d/network restart 2>/dev/null

echo ""
echo "=== Installation complete ==="
echo "Configure in LuCI: Network -> Wireless -> radio_rtk"
echo "Or manually:"
echo "  uci set wireless.sta_rtk.ssid='YourSSID'"
echo "  uci set wireless.sta_rtk.key='YourPassword'"
echo "  uci set wireless.sta_rtk.disabled='0'"
echo "  uci commit wireless"
echo "  wifi up radio_rtk"
