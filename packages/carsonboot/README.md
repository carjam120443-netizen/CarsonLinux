# CarsonBoot

CarsonBoot is the CarsonLinux UEFI boot stage.

## Role

CarsonBoot is installed as the default removable-media UEFI entry:

`EFI/BOOT/BOOTX64.EFI`

It provides the CarsonLinux-themed startup screen and then launches the
bundled GRUB stage at:

`EFI/BOOT/GRUBX64.EFI`

This keeps the first boot stage CarsonLinux-owned while retaining GRUB for
the Linux kernel boot protocol during the early CarsonBoot 0.1 development
stage.

## Build

The ISO build compiles `bootloader/carsonboot.c` with GNU-EFI and places the
result into the ISO's EFI system partition.

## Future

CarsonBoot can eventually replace the GRUB handoff with a native Linux
kernel loader, configuration parser, and interactive boot menu.