#!/usr/bin/env bash
set -euo pipefail

echo "==> Prepare defconfig"

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
  echo "Isi root repo:"
  ls -la
  exit 1
fi

echo "Kernel dir: ${KERNEL_DIR}"

CONFIG_DIR="${KERNEL_DIR}/arch/arm64/configs"
DEFCONFIG_PATH="${CONFIG_DIR}/${DEFCONFIG}"

mkdir -p "${CONFIG_DIR}"

if [ -f "${DEFCONFIG_PATH}" ]; then
  echo "Defconfig ditemukan: ${DEFCONFIG_PATH}"
else
  echo "WARNING: ${DEFCONFIG_PATH} tidak ditemukan."
  echo "Mencari defconfig alternatif..."

  ALT_DEFCONFIG="$(find "${CONFIG_DIR}" -maxdepth 1 -type f \( \
    -iname "*onclite*defconfig" -o \
    -iname "*onc*defconfig" -o \
    -iname "*msm8953*defconfig" -o \
    -iname "*sdm632*defconfig" \
  \) | head -n 1 || true)"

  if [ -n "${ALT_DEFCONFIG}" ]; then
    echo "Pakai defconfig alternatif sebagai base:"
    echo "${ALT_DEFCONFIG}"
    cp "${ALT_DEFCONFIG}" "${DEFCONFIG_PATH}"
  else
    echo "Tidak menemukan defconfig alternatif."
    echo "Mencoba pakai config hasil ekstrak dari boot.img..."

    BOOT_CONFIG=""

    for f in \
      "${ROOT_DIR}/boot_info/boot4_kernel_config.txt" \
      "${ROOT_DIR}/boot_info/kernel_config.txt" \
      "${ROOT_DIR}/boot4_kernel_config.txt" \
      "${ROOT_DIR}/kernel_config.txt" \
      "${ROOT_DIR}/.config"; do
      if [ -f "${f}" ]; then
        BOOT_CONFIG="${f}"
        break
      fi
    done

    if [ -z "${BOOT_CONFIG}" ]; then
      echo "ERROR: Tidak ada defconfig dan tidak ada config hasil ekstrak."
      echo "Daftar isi ${CONFIG_DIR}:"
      ls -la "${CONFIG_DIR}" | head -n 100
      exit 1
    fi

    echo "Pakai boot config: ${BOOT_CONFIG}"
    cp "${BOOT_CONFIG}" "${DEFCONFIG_PATH}"
  fi
fi

# Fix CRLF Windows
sed -i 's/\r$//' "${DEFCONFIG_PATH}"

echo "==> Defconfig siap:"
ls -lh "${DEFCONFIG_PATH}"

echo "==> Preview config:"
grep -E "CONFIG_LOCALVERSION|CONFIG_IKCONFIG|CONFIG_MODULES|CONFIG_OVERLAY_FS|CONFIG_KALLSYMS|CONFIG_KSU" "${DEFCONFIG_PATH}" || true

echo "==> Selesai prepare defconfig"
