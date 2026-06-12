#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00_env.sh"
if [ -f .buildkit_defconfig.env ]; then source .buildkit_defconfig.env; fi

mkdir -p "$OUT_DIR" "$DIST_DIR"
cd "$KERNEL_DIR"

export ARCH SUBARCH CROSS_COMPILE CROSS_COMPILE_ARM32

if [ -f "arch/arm64/configs/vendor/$DEFCONFIG" ]; then
  DEFCONFIG="vendor/$DEFCONFIG"
fi

echo "[i] make O=../$OUT_DIR ARCH=arm64 $DEFCONFIG"
make O="../$OUT_DIR" ARCH=arm64 "$DEFCONFIG"

# Let olddefconfig normalize any new ReSuki options.
make O="../$OUT_DIR" ARCH=arm64 olddefconfig

# Prefer clang, fallback to gcc if clang build fails.
echo "[i] Building kernel with clang..."
if make -j"$JOBS" O="../$OUT_DIR" ARCH=arm64 CC=clang LLVM=1 LLVM_IAS=1 CROSS_COMPILE="$CROSS_COMPILE" CROSS_COMPILE_ARM32="$CROSS_COMPILE_ARM32" Image.gz-dtb dtbs; then
  echo "[i] clang build OK"
else
  echo "[!] clang build failed, trying GCC fallback..."
  make -j"$JOBS" O="../$OUT_DIR" ARCH=arm64 CROSS_COMPILE="$CROSS_COMPILE" CROSS_COMPILE_ARM32="$CROSS_COMPILE_ARM32" Image.gz-dtb dtbs
fi

cd ..
for f in "$OUT_DIR/arch/arm64/boot/Image.gz-dtb" "$OUT_DIR/arch/arm64/boot/Image.gz" "$OUT_DIR/arch/arm64/boot/Image"; do
  if [ -f "$f" ]; then
    cp "$f" "$DIST_DIR/$(basename "$f")"
  fi
done

find "$OUT_DIR/arch/arm64/boot/dts" -name '*.dtb' -print0 2>/dev/null | xargs -0 -r cp -t "$DIST_DIR" || true

echo "[i] Dist files:"
ls -lah "$DIST_DIR"
