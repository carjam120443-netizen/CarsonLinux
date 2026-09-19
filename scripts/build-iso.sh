#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/out"
WORK="$ROOT/.build"
ROOTFS="$WORK/rootfs"

rm -rf "$OUT" "$WORK"
mkdir -p "$OUT" "$WORK"

debootstrap --variant=minbase --include=systemd-sysv,dbus bookworm "$ROOTFS" http://deb.debian.org/debian

rm -f "$ROOTFS/etc/resolv.conf"
cat > "$ROOTFS/etc/resolv.conf" <<'EOF'
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

cp -a "$ROOT/rootfs/." "$ROOTFS/"
chmod +x "$ROOTFS/init" "$ROOTFS/usr/bin/cpkg" "$ROOTFS/usr/bin/carsonfetch"

chroot "$ROOTFS" /usr/bin/env DEBIAN_FRONTEND=noninteractive PATH=/usr/sbin:/usr/bin:/sbin:/bin   apt-get update

chroot "$ROOTFS" /usr/bin/env DEBIAN_FRONTEND=noninteractive PATH=/usr/sbin:/usr/bin:/sbin:/bin   apt-get install -y --no-install-recommends     xfce4 xfce4-goodies xfce4-terminal xorg lightdm dbus-x11     network-manager network-manager-gnome xserver-xorg-input-all     xserver-xorg-video-fbdev

chroot "$ROOTFS" apt-get clean
rm -rf "$ROOTFS/var/lib/apt/lists/"*

if ! chroot "$ROOTFS" id live >/dev/null 2>&1; then
  chroot "$ROOTFS" useradd -m -s /bin/bash live
fi
printf 'live:root\n' | chroot "$ROOTFS" chpasswd

for group in audio video input netdev; do
  if chroot "$ROOTFS" getent group "$group" >/dev/null 2>&1; then
    chroot "$ROOTFS" usermod -aG "$group" live
  fi
done

mkdir -p "$ROOTFS/etc/lightdm/lightdm.conf.d"
cat > "$ROOTFS/etc/lightdm/lightdm.conf.d/50-carsonlinux-live.conf" <<'EOF'
[Seat:*]
autologin-user=live
autologin-user-timeout=0
user-session=xfce
greeter-session=lightdm-gtk-greeter
EOF

mkdir -p "$ROOTFS/etc/NetworkManager/conf.d"
cat > "$ROOTFS/etc/NetworkManager/conf.d/10-carsonlinux.conf" <<'EOF'
[main]
plugins=keyfile

[device]
wifi.scan-rand-mac-address=no
EOF

chroot "$ROOTFS" systemctl enable NetworkManager.service
chroot "$ROOTFS" systemctl enable lightdm.service
ln -sf /lib/systemd/system/graphical.target "$ROOTFS/etc/systemd/system/default.target"

install -Dm755 /bin/busybox "$ROOTFS/bin/busybox"
/bin/busybox --install -s "$ROOTFS/bin"
mkdir -p "$ROOTFS"/{dev,proc,sys,tmp,run,home,var}

(
  cd "$ROOTFS"
  find . -print0 | cpio --null -ov --format=newc > "$WORK/initramfs.cpio"
)
gzip -9 -f "$WORK/initramfs.cpio"

KVER="6.12.47"
curl -L --fail --retry 3 -o "$WORK/linux.tar.xz"   "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$KVER.tar.xz"
tar -xf "$WORK/linux.tar.xz" -C "$WORK"

cd "$WORK/linux-$KVER"
cp "$ROOT/kernel/config" .config
make olddefconfig
make -j"$(nproc)" bzImage

mkdir -p "$WORK/iso/boot/grub"
cp arch/x86/boot/bzImage "$WORK/iso/boot/carsonlinux-kernel"
cp "$WORK/initramfs.cpio.gz" "$WORK/iso/boot/carsonlinux-initramfs"

cat > "$WORK/iso/boot/grub/grub.cfg" <<'EOF'
set timeout=3
set default=0
set menu_color_normal=light-gray/black
set menu_color_highlight=white/blue

insmod all_video
insmod gfxterm
insmod font

if loadfont unicode; then
    terminal_output gfxterm
fi

clear
echo ""
echo "  +----------------------------------------------+"
echo "  |              C A R S O N L I N U X           |"
echo "  |                                              |"
echo "  |                 CarsonBoot / GRUB            |"
echo "  +----------------------------------------------+"
echo ""

menuentry "CarsonLinux XFCE Live" {
    linux /boot/carsonlinux-kernel console=tty0
    initrd /boot/carsonlinux-initramfs
}

menuentry "CarsonLinux Recovery" {
    linux /boot/carsonlinux-kernel console=tty0 single
    initrd /boot/carsonlinux-initramfs
}
EOF

EFI_INC="$(dpkg -L gnu-efi | awk '/\/include\/efi$/{print; exit}')"
EFI_CRT="$(dpkg -L gnu-efi | awk '/crt0-efi-x86_64\.o$/{print; exit}')"
EFI_LDS="$(dpkg -L gnu-efi | awk '/elf_x86_64_efi\.lds$/{print; exit}')"
EFI_LIB="$(dpkg -L gnu-efi | awk '/\/libgnuefi\.a$/{print; exit}')"

test -n "$EFI_INC" -a -n "$EFI_CRT" -a -n "$EFI_LDS" -a -n "$EFI_LIB"

mkdir -p "$WORK/carsonboot"
gcc -I"$EFI_INC" -I"$EFI_INC/x86_64"   -fpic -ffreestanding -fno-stack-protector -fno-stack-check   -fshort-wchar -mno-red-zone -DEFI_FUNCTION_WRAPPER   -c "$ROOT/bootloader/carsonboot.c" -o "$WORK/carsonboot/carsonboot.o"

ld -nostdlib -znocombreloc -T "$EFI_LDS" -shared -Bsymbolic   -L"$(dirname "$EFI_LIB")" "$EFI_CRT" "$WORK/carsonboot/carsonboot.o"   -o "$WORK/carsonboot/carsonboot.so" -lefi -lgnuefi

objcopy -j .text -j .sdata -j .data -j .dynamic -j .dynsym   -j .rel -j .rela -j .reloc --target=efi-app-x86_64   "$WORK/carsonboot/carsonboot.so" "$WORK/carsonboot/CarsonBoot.efi"

mkdir -p "$WORK/efi/EFI/BOOT"
grub-mkstandalone --format=x86_64-efi   --output="$WORK/efi/EFI/BOOT/GRUBX64.EFI"   --install-modules="all_video gfxterm font normal linux search search_fs_file configfile echo"   --modules="all_video gfxterm font normal linux search search_fs_file configfile echo"   --locales="" --fonts=""   "boot/grub/grub.cfg=$WORK/iso/boot/grub/grub.cfg"

cp "$WORK/carsonboot/CarsonBoot.efi" "$WORK/efi/EFI/BOOT/BOOTX64.EFI"

dd if=/dev/zero of="$WORK/efiboot.img" bs=1M count=16 status=none
mkfs.vfat -n CARSONEFI "$WORK/efiboot.img" >/dev/null
mcopy -s -i "$WORK/efiboot.img" "$WORK/efi/EFI" ::/

grub-mkstandalone --format=i386-pc   --output="$WORK/core.img"   --install-modules="linux normal iso9660 biosdisk search search_fs_file configfile echo"   --modules="linux normal iso9660 biosdisk search search_fs_file configfile echo"   --locales="" --fonts=""   "boot/grub/grub.cfg=$WORK/iso/boot/grub/grub.cfg"

cat /usr/lib/grub/i386-pc/cdboot.img "$WORK/core.img" > "$WORK/bios.img"

xorriso -as mkisofs   -iso-level 3 -r -J -joliet-long -V "CARSONLINUX"   -o "$OUT/CarsonLinux-$CARSONLINUX_VERSION-x86_64.iso"   -b boot/grub/bios.img -no-emul-boot -boot-load-size 4 -boot-info-table   --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img   -eltorito-alt-boot -e --interval:appended_partition_2:all:: -no-emul-boot   -append_partition 2 0xef "$WORK/efiboot.img"   -isohybrid-gpt-basdat "$WORK/iso"

echo "ISO created:"
ls -lh "$OUT/"*.iso
