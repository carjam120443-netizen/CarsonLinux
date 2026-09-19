#!/usr/bin/env bash
set -euo pipefail

export CARSONLINUX_ARCH="${CARSONLINUX_ARCH:-x86_64}"
export CARSONLINUX_NAME="CarsonLinux"
export CARSONLINUX_VERSION="${CARSONLINUX_VERSION:-0.1.0-dev}"
export CARSONLINUX_ROOTFS="${CARSONLINUX_ROOTFS:-rootfs}"
