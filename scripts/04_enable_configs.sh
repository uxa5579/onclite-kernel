#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00_env.sh"
if [ -f .buildkit_defconfig.env ]; then source .buildkit_defconfig.env; fi

CONFIG_PATH="$KERNEL_DIR/arch/arm64/configs/$DEFCONFIG"
if [ ! -f "$CONFIG_PATH" ] && [ -f "$KERNEL_DIR/arch/arm64/configs/vendor/$DEFCONFIG" ]; then
  CONFIG_PATH="$KERNEL_DIR/arch/arm64/configs/vendor/$DEFCONFIG"
fi
if [ ! -f "$CONFIG_PATH" ]; then
  echo "[x] Defconfig not found: $DEFCONFIG"
  exit 1
fi

set_config() {
  local key="$1" val="$2"
  if grep -qE "^# ${key} is not set$" "$CONFIG_PATH"; then
    sed -i "s/^# ${key} is not set$/${key}=${val}/" "$CONFIG_PATH"
  elif grep -qE "^${key}=" "$CONFIG_PATH"; then
    sed -i "s/^${key}=.*/${key}=${val}/" "$CONFIG_PATH"
  else
    printf '%s=%s\n' "$key" "$val" >> "$CONFIG_PATH"
  fi
}

# ReSukiSU / non-GKI flags
set_config CONFIG_KSU y
set_config CONFIG_KSU_MANUAL_HOOK y
set_config CONFIG_KALLSYMS y
set_config CONFIG_KALLSYMS_ALL y

# Helpful auto hooks when available in ReSukiSU source. If unsupported, olddefconfig may drop them.
set_config CONFIG_KSU_MANUAL_HOOK_AUTO_INPUT_HOOK y
set_config CONFIG_KSU_MANUAL_HOOK_AUTO_SETUID_HOOK y
set_config CONFIG_KSU_MANUAL_HOOK_AUTO_INITRC_HOOK y

if [ "$USE_SUSFS" = "1" ]; then
  set_config CONFIG_KSU_SUSFS y
fi

# Keep the same local version as uploaded kernel unless source overrides it.
set_config CONFIG_LOCALVERSION '"-Chidori-Kernel"'

printf '[i] Updated config flags in %s\n' "$CONFIG_PATH"
grep -E 'CONFIG_KSU|CONFIG_KALLSYMS|CONFIG_LOCALVERSION|CONFIG_KPROBES' "$CONFIG_PATH" || true
