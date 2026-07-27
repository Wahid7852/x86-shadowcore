#!/bin/bash
# Builds the kernel. Source is this repo itself now (no fetch step) - just
# make sure .config is what you want (run configure.sh first if you changed
# anything) and build.
set -euo pipefail

if [[ ! -x scripts/config ]]; then
  echo "run this from the repo root (kernel source tree)" >&2
  exit 1
fi

make LLVM=1 LLVM_IAS=1 CC="ccache clang" -j"$(nproc)"

echo
echo "Build finished. bzImage at: $(pwd)/arch/x86/boot/bzImage"
echo "Run install.sh next (as root) to install modules/kernel/initramfs/grub."
