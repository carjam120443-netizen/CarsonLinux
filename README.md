<div align="center">

<img src="assets/carsonlinux.svg" alt="CarsonLinux logo" width="180">

# CarsonLinux

**A personal Linux-based operating system built from the ground up.**

</div>

CarsonLinux is an experimental x86_64 Linux distribution focused on learning how an operating system fits together while still becoming a usable, bootable system.

> 🚧 **Status:** Early development — the base project is being assembled now.

## Goals

- 🐧 Linux kernel based
- 🧱 Custom root filesystem and system layout
- ⚙️ Custom init/userspace components
- 📦 A CarsonLinux package manager
- 🌐 Networking support
- 💾 VirtualBox-first testing
- 🖥️ Desktop environment support later
- 💿 Reproducible ISO builds through GitHub Actions

## Project layout

```text
CarsonLinux/
├── assets/
│   └── carsonlinux.svg
├── build/
│   └── config.sh
├── kernel/
│   └── config
├── rootfs/
│   ├── etc/
│   │   ├── hostname
│   │   └── os-release
│   └── init
├── packages/
│   └── README.md
├── installer/
│   └── README.md
├── scripts/
│   └── build-rootfs.sh
└── .github/
    └── workflows/
        └── build.yml
```

## Build direction

The first CarsonLinux milestone is a small bootable Linux system that can be tested in **VirtualBox**. The project will start with a minimal userspace and grow toward a complete desktop distribution.

Planned layers:

1. Linux kernel
2. Root filesystem
3. Init system
4. Core utilities
5. Networking
6. Package management
7. User management
8. Installer
9. Desktop environment
10. ISO/release automation

## Development

CarsonLinux is developed and tested primarily in virtual machines so experimentation does not affect the host operating system.

The first target is **x86_64**.

## License

CarsonLinux is currently released under the MIT License. See [LICENSE](LICENSE).
