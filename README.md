# x86-shadowcore

Personal CachyOS-based kernel tuned for one specific machine: Intel i5-1135G7
(Tiger Lake, 4c/8t, AVX-512), 16GB RAM, DevSecOps/bug-bounty/CTF workloads plus
CPU-bound ML training (no discrete GPU).

Not a fork of the kernel source itself - this is the patch/config/build recipe
on top of CachyOS's published source releases and patch set, in the same spirit
as [CachyOS/linux-cachyos](https://github.com/CachyOS/linux-cachyos) (which
also doesn't vendor full kernel source). Kernel source is fetched at build
time, not committed here.

## What's in this build

- Base: CachyOS kernel source release (via `CachyOS/linux` GitHub releases)
- Scheduler: BORE + the `0001-bore-cachy.patch` ("Cachy Sauce")
- CPU target: **native** (`CONFIG_X86_NATIVE_CPU`), not the generic
  `x86-64-vN` baseline CachyOS ships by default
- LTO: **full** (`CONFIG_LTO_CLANG_FULL`), not thin
- 1000Hz tick, tickless=idle, preempt=full, `-O3`
- Transparent Hugepages: always
- `TCP_CONG_BBR3` built as a module
- Mitigations left compiled in (not stripped) - only disabled at boot via
  `mitigations=off` on this machine, reversible without a rebuild

## Currently tracked version

`7.1.3-1` (kernel-patches dir `7.1`)

## Build

```
./build.sh 7.1.3-1 7.1
```

Fetches source + patches (skips if already present in `~/kernel-build/shadowcore/`),
applies patches, seeds `.config` from `config/shadowcore.config`, runs
`configure.sh` to (re)apply the native-CPU/full-LTO/localversion fixes, then
builds with `ccache` wired in (`CC="ccache clang"`).

## Install

```
! sudo bash install.sh
```

Run from the built source tree. Installs modules, copies the kernel image to
`/boot/vmlinuz-ShadowCore`, writes an mkinitcpio preset, regenerates initramfs
and GRUB config. If a pacman-tracked `ShadowCore` package already exists (e.g.
from an earlier cachyos-kernel-manager build), it's removed first so pacman's
file database doesn't go stale underneath this build. Other installed kernels
(`linux-cachyos-bore-lto`, `linux-lts`, `linux`) are untouched either way.

## Why `configure.sh` exists as a separate script

The kernel's x86 CPU-targeting Kconfig has two overlapping mechanisms: the
older per-vendor choice (`X86_NATIVE_CPU`, `MZEN4`, ...) and a newer generic
psABI-level one (`GENERIC_CPU` + `X86_64_VERSION` 1-4). Seeding a `.config`
from an existing kernel (e.g. via a GUI kernel-manager's "use current config"
option) can silently keep the old kernel's `GENERIC_CPU`/`X86_64_VERSION=4`
choice active even after explicitly asking for "native," because
`olddefconfig` only prompts for genuinely new symbols - it doesn't revisit an
already-answered Kconfig choice group. `configure.sh` explicitly disables
`GENERIC_CPU` and enables `X86_NATIVE_CPU` (and the equivalent for LTO) so this
doesn't happen silently again.

## Upreving to a new kernel version

CachyOS publishes a new source release + patch set per version bump:
- Source tarball: `https://github.com/CachyOS/linux/releases/download/cachyos-<KVER>/cachyos-<KVER>.tar.gz`
- Patches: `https://raw.githubusercontent.com/cachyos/kernel-patches/master/<KVER_SHORT>/...`

Run `./build.sh <new-kver> <new-kver-short>`. If a patch fails to apply due to
upstream code drift, fix the hunk by hand before continuing - don't assume a
patch written for one version applies cleanly several versions later.
