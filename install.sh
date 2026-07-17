#!/bin/bash
# Installs a built ShadowCoreX kernel: modules, vmlinuz, initramfs preset, GRUB.
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

make modules_install
cp -v arch/x86/boot/bzImage "/boot/vmlinuz-ShadowCoreX"

cat > /etc/mkinitcpio.d/ShadowCoreX.preset <<EOF
# mkinitcpio preset file for the manually-built 'ShadowCoreX' kernel

ALL_kver="/boot/vmlinuz-ShadowCoreX"

PRESETS=('default')

default_image="/boot/initramfs-ShadowCoreX.img"
EOF

mkinitcpio -p ShadowCoreX
grub-mkconfig -o /boot/grub/grub.cfg

echo
echo "Done. ShadowCoreX should now be a GRUB boot entry."
echo "Existing kernels (ShadowCore, linux-cachyos-bore-lto, linux-lts, linux) are untouched."
