#!/bin/bash
# Build script for Orange Pi Zero 3 Ultra Minimal
# Usage: ./build-orangepizero3-minimal.sh [RELEASE]

set -euo pipefail

RELEASE="${1:-trixie}"
BOARD="orangepizero3-minimal"
BRANCH="current"
BUILD_DESKTOP="no"
BUILD_MINIMAL="yes"
KERNEL_CONFIGURE="no"
COMPRESS_OUTPUTIMAGE="sha,gz,img.xz"
SHARE_LOGS="no"

echo "============================================"
echo "Building Orange Pi Zero 3 H618 Ultra Minimal (Generic H618 Base)"
echo "Board: $BOARD"
echo "Release: $RELEASE"
echo "Branch: $BRANCH"
echo "Desktop: $BUILD_DESKTOP"
echo "Packages: dropbear, iwd, vim-tiny, htop, curl, wget, git, python3, nftables"
echo "DTB: sun50i-h616-orangepi-zero3.dtb (change BOOT_FDT_FILE in board config for other H618 boards)"
echo "============================================"

./compile.sh \
    BOARD="$BOARD" \
    BRANCH="$BRANCH" \
    RELEASE="$RELEASE" \
    BUILD_DESKTOP="$BUILD_DESKTOP" \
    BUILD_MINIMAL="$BUILD_MINIMAL" \
    KERNEL_CONFIGURE="$KERNEL_CONFIGURE" \
    COMPRESS_OUTPUTIMAGE="$COMPRESS_OUTPUTIMAGE" \
    SHARE_LOGS="$SHARE_LOGS" \
    "$@"

echo "============================================"
echo "Build complete!"
echo "Images in: output/images/"
ls -la output/images/ 2>/dev/null || true
