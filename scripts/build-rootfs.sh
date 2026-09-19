#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOTFS="${ROOT}/rootfs"

mkdir -p "${ROOTFS}"/{bin,sbin,usr/bin,usr/sbin,etc,dev,proc,sys,tmp,var,home}

chmod +x "${ROOTFS}/init"

echo "CarsonLinux rootfs prepared at: ${ROOTFS}"
