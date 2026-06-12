#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00_env.sh"
cd "$KERNEL_DIR"

if [ -d KernelSU ] || [ -d drivers/kernelsu ] || grep -Rqs "config KSU" KernelSU drivers kernel 2>/dev/null; then
  echo "[i] Kernel source already seems to contain KernelSU/ReSuki/Suki integration. Skipping setup script."
  exit 0
fi

echo "[i] Running ReSukiSU setup script..."
curl -LSs "https://raw.githubusercontent.com/ReSukiSU/ReSukiSU/main/kernel/setup.sh" | bash
