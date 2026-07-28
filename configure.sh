#!/bin/bash
# ShadowCore config fixups. Run from a kernel source tree root with a seed
# .config already in place.
set -euo pipefail

if [[ ! -f .config ]]; then
  echo "no .config in cwd - seed one first" >&2
  exit 1
fi
if [[ ! -x scripts/config ]]; then
  echo "scripts/config not found - run from a kernel source tree root" >&2
  exit 1
fi

# native cpu, not generic x86-64-vN
./scripts/config -d GENERIC_CPU -e X86_NATIVE_CPU

# thin lto - full lto's link OOMs on 16GB RAM
./scripts/config -d LTO_CLANG_FULL -e LTO_CLANG_THIN

# -O3 instead of -O2
./scripts/config -d CC_OPTIMIZE_FOR_PERFORMANCE -e CC_OPTIMIZE_FOR_PERFORMANCE_O3

# tickless=idle, not full - no cpu isolation on this box
./scripts/config -d NO_HZ_FULL -e NO_HZ_IDLE

# performance governor as compiled-in default
./scripts/config -d CPU_FREQ_DEFAULT_GOV_SCHEDUTIL -e CPU_FREQ_DEFAULT_GOV_PERFORMANCE

# BBR3 module
./scripts/config -m TCP_CONG_BBR3

./scripts/config --set-str LOCALVERSION "-ShadowCore" -d LOCALVERSION_AUTO

# localmodconfig safety list - stuff that may not be loaded at trim time but
# is still needed (docker, USB storage/serial, VM networking, mkinitcpio)
./scripts/config -m OVERLAY_FS -m EXFAT_FS -m NTFS3_FS -m USB_STORAGE \
  -m USB_SERIAL_CH341 -m USB_SERIAL_CP210X -m USB_SERIAL_FTDI_SIO \
  -m VIRTIO_NET -m VHOST_NET -m BRIDGE -m VETH -m BT_HIDP -m CRYPTO_LZ4

echo "Resolving dependent options via olddefconfig..."
make LLVM=1 LLVM_IAS=1 CC="ccache clang" olddefconfig

echo
echo "--- verifying ---"
grep -E "^CONFIG_(X86_NATIVE_CPU|GENERIC_CPU\b|LTO_CLANG_FULL|LTO_CLANG_THIN|LOCALVERSION|SCHED_BORE|HZ=|TRANSPARENT_HUGEPAGE_ALWAYS|TCP_CONG_BBR3|KVM_INTEL=|CC_OPTIMIZE_FOR_PERFORMANCE_O3|NO_HZ_IDLE|NO_HZ_FULL|CPU_FREQ_DEFAULT_GOV_PERFORMANCE|OVERLAY_FS)" .config || true
