#!/bin/bash
# Fetches CachyOS kernel source + patches for a given version, applies them,
# seeds config, runs configure.sh, and builds.
#
# Usage: ./build.sh <kver> <kver_short>
#   e.g. ./build.sh 7.1.3-1 7.1
#
# kver        - the CachyOS release tag suffix, e.g. 7.1.3-1
# kver_short  - the kernel-patches repo directory, e.g. 7.1
set -euo pipefail

KVER="${1:?usage: build.sh <kver e.g. 7.1.3-1> <kver_short e.g. 7.1>}"
KVER_SHORT="${2:?usage: build.sh <kver e.g. 7.1.3-1> <kver_short e.g. 7.1>}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${WORK_DIR:-$HOME/kernel-build/shadowcore}"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

TARBALL="cachyos-${KVER}.tar.gz"
if [[ ! -f "$TARBALL" ]]; then
  echo "Fetching $TARBALL..."
  curl -LO "https://github.com/CachyOS/linux/releases/download/cachyos-${KVER}/${TARBALL}"
fi

BORE_PATCH="0001-bore-cachy.patch"
DKMS_PATCH="dkms-clang.patch"
[[ -f "$BORE_PATCH" ]] || curl -Lo "$BORE_PATCH" \
  "https://raw.githubusercontent.com/cachyos/kernel-patches/master/${KVER_SHORT}/sched/0001-bore-cachy.patch"
[[ -f "$DKMS_PATCH" ]] || curl -Lo "$DKMS_PATCH" \
  "https://raw.githubusercontent.com/cachyos/kernel-patches/master/${KVER_SHORT}/misc/dkms-clang.patch"

SRC_DIR="cachyos-${KVER}"
if [[ ! -d "$SRC_DIR" ]]; then
  echo "Extracting..."
  tar -xzf "$TARBALL"
fi

cd "$SRC_DIR"
echo "Applying patches..."
patch -p1 -N < "../$BORE_PATCH" || echo "(bore-cachy patch already applied or failed - check manually)"
patch -p1 -N < "../$DKMS_PATCH" || echo "(dkms-clang patch already applied or failed - check manually)"

echo "Seeding config..."
if [[ -f "$SCRIPT_DIR/config/shadowcore.config" ]]; then
  cp "$SCRIPT_DIR/config/shadowcore.config" .config
else
  echo "no stored config found at $SCRIPT_DIR/config/shadowcore.config - seed .config yourself before continuing" >&2
  exit 1
fi

"$SCRIPT_DIR/configure.sh"

echo "Building with $(nproc) jobs, ccache wired in..."
make LLVM=1 LLVM_IAS=1 CC="ccache clang" -j"$(nproc)"

echo
echo "Build finished. bzImage at: $WORK_DIR/$SRC_DIR/arch/x86/boot/bzImage"
echo "Run install.sh next (as root) to install modules/kernel/initramfs/grub."
