#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${ROOT}/out"
WORK="${ROOT}/.build"

rm -rf "${OUT}" "${WORK}"
mkdir -p "${OUT}" "${WORK}/rootfs"

# Start from the tracked CarsonLinux rootfs.
cp -a "${ROOT}/rootfs/." "${WORK}/rootfs/"

# BusyBox supplies the first usable userspace. The static binary is provided
# by the CI package on Ubuntu runners.
install -Dm755 /bin/busybox "${WORK}/rootfs/bin/busybox"

# Populate the standard BusyBox command names.
chroot "${WORK}/rootfs" /bin/busybox --install -s /bin

# The init script is the PID 1 entry point.
chmod +x "${WORK}/rootfs/init"

# Required virtual filesystems/devices.
mkdir -p "${WORK}/rootfs"/{dev,proc,sys,tmp,run,etc,home,var}

# Build an initramfs.
(
  cd "${WORK}/rootfs"
  find . -print0 | cpio --null -ov --format=newc > "${WORK}/initramfs.cpio"
)
gzip -9 -f "${WORK}/initramfs.cpio"

# Build a Linux kernel on the GitHub runner.
KVER="6.12.47"
curl -L --fail --retry 3 -o "${WORK}/linux.tar.xz"   "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KVER}.tar.xz"
tar -xf "${WORK}/linux.tar.xz" -C "${WORK}"

cd "${WORK}/linux-${KVER}"
cp "${ROOT}/kernel/config" .config
make olddefconfig
make -j"$(nproc)" bzImage

# GRUB boot tree for BIOS + UEFI.
mkdir -p "${WORK}/iso/boot/grub"
cp arch/x86/boot/bzImage "${WORK}/iso/boot/carsonlinux-kernel"
cp "${WORK}/initramfs.cpio.gz" "${WORK}/iso/boot/carsonlinux-initramfs"

cat > "${WORK}/iso/boot/grub/grub.cfg" <<'EOF'
set timeout=3
set default=0

menuentry "CarsonLinux" {
    linux /boot/carsonlinux-kernel console=tty0
    initrd /boot/carsonlinux-initramfs
}
EOF

grub-mkrescue -o "${OUT}/CarsonLinux-${CARSONLINUX_VERSION:-0.1.0-dev}-x86_64.iso" "${WORK}/iso"

echo "ISO created:"
ls -lh "${OUT}/"*.iso
