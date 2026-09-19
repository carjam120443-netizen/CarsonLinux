# CarsonLinux Packages

CarsonLinux uses **cpkg** as its native package manager.

## Commands

```text
cpkg install <package.cpkg>
cpkg remove <package>
cpkg list
cpkg info <package>
cpkg help
```

## Package format

A `.cpkg` file is a gzip-compressed tar archive containing:

```text
manifest
payload/
```

The manifest contains package metadata such as:

```text
NAME=example
VERSION=1.0
ARCH=x86_64
DESCRIPTION=Example CarsonLinux package
```

Files under `payload/` are installed relative to the CarsonLinux filesystem root.

The current implementation is intentionally small and local-file based. Repository
support, dependency resolution, upgrades, signatures, and package building will
be added as the package system grows.
