#!/usr/bin/env bash
set -euo pipefail

echo "==> Build ReSukiSU-only kernel"

ROOT_DIR="$(pwd)"
DEFCONFIG="${DEFCONFIG:-onclite_defconfig}"

echo "Root dir  : ${ROOT_DIR}"
echo "Defconfig : ${DEFCONFIG}"

KERNEL_DIR=""

for dir in kernel kernel_source source android_kernel_xiaomi_onc android_kernel_xiaomi_onclite; do
  if [ -d "${dir}/arch/arm64/configs" ]; then
    KERNEL_DIR="${dir}"
    break
  fi
done

if [ -z "${KERNEL_DIR}" ]; then
  KERNEL_DIR="$(find . -maxdepth 3 -type d -path "*/arch/arm64/configs" | head -n 1 | sed 's#/arch/arm64/configs##' | sed 's#^\./##')"
fi

if [ -z "${KERNEL_DIR}" ] || [ ! -d "${KERNEL_DIR}" ]; then
  echo "ERROR: Kernel source folder tidak ditemukan."
  ls -la
  exit 1
fi

echo "Kernel dir: ${KERNEL_DIR}"

cd "${KERNEL_DIR}"

export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_USER=resukisu
export KBUILD_BUILD_HOST=github-actions

OUT_DIR="${ROOT_DIR}/out"
DIST_DIR="${ROOT_DIR}/dist"

mkdir -p "${OUT_DIR}"
mkdir -p "${DIST_DIR}"

echo "==> Check defconfig"

if [ ! -f "arch/arm64/configs/${DEFCONFIG}" ]; then
  echo "WARNING: ${DEFCONFIG} tidak ditemukan."
  echo "Mencari defconfig alternatif..."

  ALT_DEFCONFIG="$(find arch/arm64/configs -maxdepth 1 -type f \( -iname "*onclite*defconfig" -o -iname "*onc*defconfig" -o -iname "*msm8953*defconfig" \) | head -n 1 || true)"

  if [ -n "${ALT_DEFCONFIG}" ]; then
    DEFCONFIG="$(basename "${ALT_DEFCONFIG}")"
    echo "Pakai defconfig alternatif: ${DEFCONFIG}"
  else
    echo "ERROR: Tidak menemukan defconfig cocok."
    ls -la arch/arm64/configs | head -n 100
    exit 1
  fi
fi

echo "==> Make defconfig"
make O="${OUT_DIR}" "${DEFCONFIG}"

echo "==> Final config check"
grep -E "CONFIG_KSU|CONFIG_KALLSYMS|CONFIG_KPROBES|CONFIG_OVERLAY_FS" "${OUT_DIR}/.config" || true

echo "==> Start kernel build"

make -j"$(nproc)" O="${OUT_DIR}" \
  CC=clang \
  CLANG_TRIPLE=aarch64-linux-gnu- \
  CROSS_COMPILE=aarch64-linux-gnu- \
  CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
  Image.gz-dtb

echo "==> Search build output"

IMAGE_PATH=""

for f in \
  "${OUT_DIR}/arch/arm64/boot/Image.gz-dtb" \
  "${OUT_DIR}/arch/arm64/boot/Image.gz" \
  "${OUT_DIR}/arch/arm64/boot/Image"; do
  if [ -f "${f}" ]; then
    IMAGE_PATH="${f}"
    break
  fi
done

if [ -z "${IMAGE_PATH}" ]; then
  echo "ERROR: Kernel image tidak ditemukan."
  find "${OUT_DIR}/arch/arm64/boot" -maxdepth 3 -type f | sort || true
  exit 1
fi

echo "Kernel image: ${IMAGE_PATH}"

cp "${IMAGE_PATH}" "${DIST_DIR}/Image.gz-dtb"
cp "${OUT_DIR}/.config" "${DIST_DIR}/kernel_config_built.txt"

echo "==> Build selesai"
ls -lh "${DIST_DIR}"
