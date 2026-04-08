#!/bin/sh
# Build opkg .ipk package for kmod-rtl8852bu
# Run from the rtl8852bu repo root after compiling 8852bu.ko

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
IPK_DIR="$SCRIPT_DIR/ipk"
BUILD_DIR="$SCRIPT_DIR/build-ipk"
PKG_NAME="kmod-rtl8852bu_1.0.0-1_aarch64_cortex-a53_neon-vfpv4.ipk"

if [ ! -f "$REPO_DIR/8852bu.ko" ]; then
    echo "Error: 8852bu.ko not found. Build the driver first."
    exit 1
fi

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Copy package structure
cp -a "$IPK_DIR/CONTROL" "$BUILD_DIR/"
chmod 755 "$BUILD_DIR/CONTROL/postinst" "$BUILD_DIR/CONTROL/prerm"

# Copy files
mkdir -p "$BUILD_DIR/lib/modules/5.4.213"
cp "$REPO_DIR/8852bu.ko" "$BUILD_DIR/lib/modules/5.4.213/"

mkdir -p "$BUILD_DIR/etc/init.d"
cp "$SCRIPT_DIR/rtl8852bu.init" "$BUILD_DIR/etc/init.d/rtl8852bu"
chmod 755 "$BUILD_DIR/etc/init.d/rtl8852bu"

mkdir -p "$BUILD_DIR/root"
cp "$IPK_DIR/root/wpa.conf" "$BUILD_DIR/root/wpa.conf"

# Build ipk (tar.gz archives in ar container)
cd "$BUILD_DIR"

# Create data.tar.gz
tar czf "$SCRIPT_DIR/data.tar.gz" --owner=root --group=root \
    lib/ etc/ root/

# Create control.tar.gz
cd CONTROL
tar czf "$SCRIPT_DIR/control.tar.gz" --owner=root --group=root \
    control postinst prerm conffiles
cd ..

# Create debian-binary
echo "2.0" > "$SCRIPT_DIR/debian-binary"

# Assemble ipk
cd "$SCRIPT_DIR"
ar r "$REPO_DIR/$PKG_NAME" debian-binary control.tar.gz data.tar.gz

# Cleanup
rm -rf "$BUILD_DIR" debian-binary control.tar.gz data.tar.gz

echo "Package built: $REPO_DIR/$PKG_NAME"
echo "Install on router with: opkg install $PKG_NAME"
