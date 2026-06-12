#!/usr/bin/env bash
set -euo pipefail

# Override these from environment when needed.
export SOURCE_REPO="${SOURCE_REPO:-https://github.com/onclite/android_kernel_xiaomi_onc.git}"
export SOURCE_BRANCH="${SOURCE_BRANCH:-}"
export DEFCONFIG="${DEFCONFIG:-onclite_defconfig}"
export JOBS="${JOBS:-$(nproc)}"
export KERNEL_DIR="${KERNEL_DIR:-kernel}"
export OUT_DIR="${OUT_DIR:-out}"
export DIST_DIR="${DIST_DIR:-dist}"
export ARCH="${ARCH:-arm64}"
export SUBARCH="${SUBARCH:-arm64}"
export CROSS_COMPILE="${CROSS_COMPILE:-aarch64-linux-gnu-}"
export CROSS_COMPILE_ARM32="${CROSS_COMPILE_ARM32:-arm-linux-gnueabi-}"
export USE_SUSFS="${USE_SUSFS:-0}"
export SUSFS_REPO="${SUSFS_REPO:-https://gitlab.com/1392726643/susfs4ksu.git}"
export SUSFS_BRANCH="${SUSFS_BRANCH:-1.4.2-kernel-4.9}"
