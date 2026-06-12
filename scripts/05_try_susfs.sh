#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00_env.sh"

if [ "$USE_SUSFS" != "1" ]; then
  echo "[i] USE_SUSFS=0, skipping SUSFS."
  exit 0
fi

echo "[i] Cloning SUSFS branch $SUSFS_BRANCH..."
rm -rf susfs4ksu
if ! git clone --depth=1 -b "$SUSFS_BRANCH" "$SUSFS_REPO" susfs4ksu; then
  echo "[!] Failed to clone $SUSFS_REPO branch $SUSFS_BRANCH. Try simonpunk/susfs4ksu or another branch."
  exit 1
fi

cd "$KERNEL_DIR"
PATCHES=$(find ../susfs4ksu -type f \( -name '*.patch' -o -name '*.diff' \) | sort)
if [ -z "$PATCHES" ]; then
  echo "[!] No patch files found in SUSFS tree. Manual backport is required."
  exit 1
fi

echo "$PATCHES" | while read -r p; do
  echo "[i] Applying $p"
  if ! patch -p1 --forward < "$p"; then
    echo "[x] Patch failed: $p"
    echo "    This is common on non-GKI 4.9. Fix rejects manually or build ReSukiSU without SUSFS first."
    exit 1
  fi
done
