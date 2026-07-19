#!/bin/bash
# Installs a built ShadowCore kernel: modules, vmlinuz, initramfs preset, GRUB.
# This kernel is NOT pacman-tracked - this script does what the package hooks
# would normally do. Run as root from within the built kernel source tree
# (the directory build.sh built in), e.g.:
#   ! sudo bash ~/kernel-build/x86-shadowcore/install.sh
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "run with sudo" >&2
  exit 1
fi

if [[ ! -f arch/x86/boot/bzImage ]]; then
  echo "no bzImage in cwd - run this from the built kernel source tree" >&2
  exit 1
fi

KVER="$(make -s kernelrelease)"
echo "Installing kernel release: $KVER"

# This build reuses the 'ShadowCore' name, which may already be a
# pacman-tracked package from an earlier cachyos-kernel-manager build. Remove
# it first so pacman's file database doesn't go stale (it would otherwise
# still think it owns /boot/vmlinuz-ShadowCore etc. while we silently
# overwrite them, risking a future pacman -Syu clobbering this build).
if pacman -Qi ShadowCore &>/dev/null; then
  echo "Removing pacman-tracked ShadowCore package (being replaced by this manual build)..."
  pacman -R --noconfirm ShadowCore ShadowCore-headers 2>&1 || pacman -R --noconfirm ShadowCore
fi

make modules_install
cp -v arch/x86/boot/bzImage "/boot/vmlinuz-ShadowCore"

cat > /etc/mkinitcpio.d/ShadowCore.preset <<EOF
# mkinitcpio preset file for the manually-built 'ShadowCore' kernel

ALL_kver="/boot/vmlinuz-ShadowCore"

PRESETS=('default')

default_image="/boot/initramfs-ShadowCore.img"
EOF

mkinitcpio -p ShadowCore

# Make ShadowCore the actual GRUB default, not just a reachable menu entry.
# GRUB_TOP_LEVEL is CachyOS's grub-mkconfig hook for which kernel lands at
# menu position 0 (GRUB_DEFAULT=0). Without this, ShadowCore only boots when
# manually selected - a plain reboot silently falls back to whatever kernel
# was previously default.
sed -i "s|^GRUB_TOP_LEVEL=.*|GRUB_TOP_LEVEL='/boot/vmlinuz-ShadowCore'|" /etc/default/grub

grub-mkconfig -o /boot/grub/grub.cfg

echo
echo "Done. ShadowCore should now be a GRUB boot entry (rebuilt, no longer pacman-tracked)."
echo "Existing kernels (linux-cachyos-bore-lto, linux-lts, linux) are untouched, still there as fallback."
