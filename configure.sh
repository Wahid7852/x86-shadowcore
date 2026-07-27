#!/bin/bash
# Applies the ShadowCore config fixups to whatever .config is currently in the
# kernel source tree this script is run from. Fixes the bug where seeding from
# an existing kernel's config silently keeps GENERIC_CPU/thin-LTO instead of
# switching to the choices we actually want.
#
# Usage: run from the root of an extracted+patched kernel source tree that
# already has a seed .config in place, with LLVM toolchain available:
#   cp /path/to/seed.config .config
#   /path/to/configure.sh
set -euo pipefail

if [[ ! -f .config ]]; then
  echo "no .config in cwd - seed one first (e.g. from config/shadowcore.config or an existing kernel's config)" >&2
  exit 1
fi
if [[ ! -x scripts/config ]]; then
  echo "scripts/config not found - run this from a kernel source tree root" >&2
  exit 1
fi

# Native CPU target instead of generic x86-64-vN (this is the whole point -
# tune for this exact machine's silicon, not a portable baseline).
./scripts/config -d GENERIC_CPU -e X86_NATIVE_CPU

# Full LTO instead of thin - accept the longer build for better codegen.
./scripts/config -d LTO_CLANG_THIN -e LTO_CLANG_FULL

# -O3 instead of the default -O2.
./scripts/config -d CC_OPTIMIZE_FOR_PERFORMANCE -e CC_OPTIMIZE_FOR_PERFORMANCE_O3

# Idle-only tickless, not full tickless - NO_HZ_FULL only pays off with
# isolated/pinned CPUs (nohz_full= boot param), which we don't do on this
# 8-thread box running desktop + compute simultaneously. Arch's default
# config ships NO_HZ_FULL; that's the wrong default for this machine.
./scripts/config -d NO_HZ_FULL -e NO_HZ_IDLE

# Performance governor as the compiled-in default (Arch/CachyOS baseline
# both default to schedutil).
./scripts/config -d CPU_FREQ_DEFAULT_GOV_SCHEDUTIL -e CPU_FREQ_DEFAULT_GOV_PERFORMANCE

# BBR3 as a loadable module (source exists from the CachyOS baseline sync,
# just wasn't enabled in Arch's config).
./scripts/config -m TCP_CONG_BBR3

./scripts/config --set-str LOCALVERSION "-ShadowCore" -d LOCALVERSION_AUTO

echo "Resolving dependent options via olddefconfig..."
make LLVM=1 LLVM_IAS=1 CC="ccache clang" olddefconfig

echo
echo "--- verifying ---"
grep -E "^CONFIG_(X86_NATIVE_CPU|GENERIC_CPU\b|LTO_CLANG_FULL|LTO_CLANG_THIN|LOCALVERSION|SCHED_BORE|HZ=|TRANSPARENT_HUGEPAGE_ALWAYS|TCP_CONG_BBR3|KVM_INTEL=|CC_OPTIMIZE_FOR_PERFORMANCE_O3|NO_HZ_IDLE|NO_HZ_FULL|CPU_FREQ_DEFAULT_GOV_PERFORMANCE)" .config || true
