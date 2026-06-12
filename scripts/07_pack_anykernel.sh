#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00_env.sh"
mkdir -p "$DIST_DIR" anykernel_work
rm -rf anykernel_work

git clone --depth=1 https://github.com/osm0sis/AnyKernel3.git anykernel_work
rm -rf anykernel_work/.git anykernel_work/.github anykernel_work/README.md
cp anykernel_template/anykernel.sh anykernel_work/anykernel.sh

if [ -f "$DIST_DIR/Image.gz-dtb" ]; then
  cp "$DIST_DIR/Image.gz-dtb" anykernel_work/Image.gz-dtb
elif [ -f "$DIST_DIR/Image.gz" ]; then
  cp "$DIST_DIR/Image.gz" anykernel_work/Image.gz
else
  echo "[x] No Image.gz-dtb/Image.gz found in $DIST_DIR"
  exit 1
fi

( cd anykernel_work && zip -r9 ../"$DIST_DIR/ReSukiSU-onclite-4.9-AnyKernel3.zip" . )
echo "[i] Created $DIST_DIR/ReSukiSU-onclite-4.9-AnyKernel3.zip"
