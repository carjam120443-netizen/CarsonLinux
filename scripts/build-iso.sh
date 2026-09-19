#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "build-iso.sh must run as root (the workflow invokes it with sudo)." >&2
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${ROOT}/out"
WORK="${ROOT}/.build"
ROOTFS="${WORK}/rootfs"

rm -rf "${OUT}" "${WORK}"
mkdir -p "${OUT}" "${WORK}"

# Build a real Debian userspace first, then overlay CarsonLinux's tracked files.
# This gives the live ISO a normal libc/userspace, apt metadata, systemd, Xorg,
# XFCE, LightDM, and NetworkManager while CarsonLinux keeps its own init/cpkg layer.
debootstrap --variant=minbase --include=systemd-sysv,dbus bookworm "${ROOTFS}" http://deb.debian.org/debian

# Replace debootstrap's resolver with a simple live-build resolver.
rm -f "${ROOTFS}/etc/resolv.conf"
cat > "${ROOTFS}/etc/resolv.conf" <<'EOF'
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

# Overlay the tracked CarsonLinux rootfs.
cp -a "${ROOT}/rootfs/." "${ROOTFS}/"

# Give the package manager and init scripts executable permissions.
chmod +x "${ROOTFS}/init" "${ROOTFS}/usr/bin/cpkg"

# Install the desktop, display manager, and networking stack.
chroot "${ROOTFS}" /usr/bin/env DEBIAN_FRONTEND=noninteractive PATH=/usr/sbin:/usr/bin:/sbin:/bin \
  apt-get update

chroot "${ROOTFS}" /usr/bin/env DEBIAN_FRONTEND=noninteractive PATH=/usr/sbin:/usr/bin:/sbin:/bin \
  apt-get install -y --no-install-recommends \
    xfce4 \
    xfce4-goodies \
    xfce4-terminal \
    xorg \
    lightdm \
    dbus-x11 \
    network-manager \
    network-manager-gnome \
    xserver-xorg-input-all \
    xserver-xorg-video-fbdev

# Keep the live image small after package installation.
chroot "${ROOTFS}" apt-get clean
rm -rf "${ROOTFS}/var/lib/apt/lists/"*

# Create the default live account. Password is intentionally "root" for the
# disposable live environment requested for CarsonLinux testing.
if ! chroot "${ROOTFS}" id live >/dev/null 2>&1; then
  chroot "${ROOTFS}" useradd -m -s /bin/bash live
fi
printf 'live:root\n' | chroot "${ROOTFS}" chpasswd

for group in audio video input netdev; do
  if chroot "${ROOTFS}" getent group "${group}" >/dev/null 2>&1; then
    chroot "${ROOTFS}" usermod -aG "${group}" live
  fi
done

# LightDM automatically logs the live user into XFCE on the desktop ISO.
mkdir -p "${ROOTFS}/etc/lightdm/lightdm.conf.d"
cat > "${ROOTFS}/etc/lightdm/lightdm.conf.d/50-carsonlinux-live.conf" <<'EOF'
[Seat:*]
autologin-user=live
autologin-user-timeout=0
user-session=xfce
greeter-session=lightdm-gtk-greeter
EOF

# NetworkManager owns Ethernet/Wi-Fi interfaces and requests DHCP by default.
mkdir -p "${ROOTFS}/etc/NetworkManager/conf.d"
cat > "${ROOTFS}/etc/NetworkManager/conf.d/10-carsonlinux.conf" <<'EOF'
[main]
plugins=keyfile

[device]
wifi.scan-rand-mac-address=no
EOF

mkdir -p "${ROOTFS}/etc/NetworkManager/system-connections"
cat > "${ROOTFS}/etc/NetworkManager/system-connections/CarsonLinux Wired.nmconnection" <<'EOF'
[connection]
id=CarsonLinux Wired
type=ethernet
autoconnect=true

[ipv4]
method=auto

[ipv6]
method=auto
EOF
chmod 600 "${ROOTFS}/etc/NetworkManager/system-connections/CarsonLinux Wired.nmconnection"

# Make the graphical desktop the default systemd target and enable networking.
chroot "${ROOTFS}" systemctl enable NetworkManager.service
chroot "${ROOTFS}" systemctl enable lightdm.service
ln -sf /lib/systemd/system/graphical.target "${ROOTFS}/etc/systemd/system/default.target"

# BusyBox remains available as a small rescue/toolbox layer.
install -Dm755 /bin/busybox "${ROOTFS}/bin/busybox"
/bin/busybox --install -s "${ROOTFS}/bin"

# Required virtual filesystem directories.
mkdir -p "${ROOTFS}"/{dev,proc,sys,tmp,run,home,var}

# Build an initramfs containing the complete live userspace.
(
  cd "${ROOTFS}"
  find . -print0 | cpio --null -ov --format=newc > "${WORK}/initramfs.cpio"
)
gzip -9 -f "${WORK}/initramfs.cpio"

# Build a Linux kernel on the GitHub runner.
KVER="6.12.47"
curl -L --fail --retry 3 -o "${WORK}/linux.tar.xz" \
  "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KVER}.tar.xz"
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

menuentry "CarsonLinux XFCE Live" {
    linux /boot/carsonlinux-kernel console=tty0
    initrd /boot/carsonlinux-initramfs
}
EOF

grub-mkrescue -o "${OUT}/CarsonLinux-${CARSONLINUX_VERSION:-0.1.0-dev}-x86_64.iso" "${WORK}/iso"

echo "ISO created:"
ls -lh "${OUT}/"*.iso
