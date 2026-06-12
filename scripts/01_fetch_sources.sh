#!/usr/bin/env bash
set -euo pipefail

echo "==> Fetch kernel source"

ROOT_DIR="$(pwd)"
SOURCE_REPO="${SOURCE_REPO:-https://github.com/onclite/android_kernel_xiaomi_onc.git}"
SOURCE_BRANCH="${SOURCE_BRANCH:-}"

echo "Root dir      : ${ROOT_DIR}"
echo "Source repo   : ${SOURCE_REPO}"
echo "Source branch : ${SOURCE_BRANCH:-default}"

rm -rf kernel kernel_source source android_kernel_xiaomi_onc android_kernel_xiaomi_onclite

if [ -n "${SOURCE_BRANCH}" ]; then
  echo "==> Clone with branch: ${SOURCE_BRANCH}"
  git clone --depth=1 --single-branch -b "${SOURCE_BRANCH}" "${SOURCE_REPO}" kernel
else
  echo "==> Clone default branch"
  git clone --depth=1 "${SOURCE_REPO}" kernel
fi

if [ ! -d "kernel" ]; then
  echo "ERROR: Folder kernel tidak terbentuk."
  exit 1
fi

if [ ! -d "kernel/arch/arm64/configs" ]; then
  echo "ERROR: Source kernel tidak valid, folder arch/arm64/configs tidak ada."
  echo "Isi folder kernel:"
  ls -la kernel
  exit 1
fi

echo "==> Kernel source berhasil diambil"
echo "==> Info git:"
cd kernel
git log --oneline -5 || true

echo "==> Daftar defconfig kandidat:"
find arch/arm64/configs -maxdepth 1 -type f \( \
  -iname "*onclite*defconfig" -o \
  -iname "*onc*defconfig" -o \
  -iname "*msm8953*defconfig" -o \
  -iname "*sdm632*defconfig" \
\) | sort || true

echo "==> Semua defconfig awal:"
ls arch/arm64/configs | grep -i "defconfig" | head -n 80 || true

cd "${ROOT_DIR}"

echo "==> Selesai fetch kernel source"
