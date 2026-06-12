#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00_env.sh"

mkdir -p "$KERNEL_DIR/arch/arm64/configs"
cp boot_info/boot4_kernel_config.txt "$KERNEL_DIR/arch/arm64/configs/chatgpt_boot4_defconfig"

if [ -n "$DEFCONFIG" ] && [ -f "$KERNEL_DIR/arch/arm64/configs/$DEFCONFIG" ]; then
  echo "[i] Using source defconfig: $DEFCONFIG"
elif [ -n "$DEFCONFIG" ] && [ -f "$KERNEL_DIR/arch/arm64/configs/vendor/$DEFCONFIG" ]; then
  echo "[i] Using vendor defconfig: vendor/$DEFCONFIG"
else
  echo "[!] Requested defconfig '$DEFCONFIG' not found. Falling back to chatgpt_boot4_defconfig extracted from boot.img"
  export DEFCONFIG="chatgpt_boot4_defconfig"
  echo "DEFCONFIG=chatgpt_boot4_defconfig" > .buildkit_defconfig.env
fi
