#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00_env.sh"

if [ -d "$KERNEL_DIR/.git" ]; then
  echo "[i] Kernel source already exists: $KERNEL_DIR"
  exit 0
fi

if [ -n "$SOURCE_BRANCH" ]; then
  git clone --depth=1 -b "$SOURCE_BRANCH" "$SOURCE_REPO" "$KERNEL_DIR"
else
  git clone --depth=1 "$SOURCE_REPO" "$KERNEL_DIR"
fi
