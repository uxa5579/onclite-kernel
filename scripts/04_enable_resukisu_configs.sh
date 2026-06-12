#!/usr/bin/env bash
set -euo pipefail

echo "==> Enable ReSukiSU-only kernel config"

ROOT_DIR="$(pwd)"
DEFCONFIG="${DEFCONFIG:-onclite_defconfig}"

echo "Root dir  : ${ROOT_DIR}"
echo "Defconfig : ${DEFCONFIG}"

# Cari folder kernel source
KERNEL_DIR=""

for dir in kernel kernel_source source android_kernel_xiaomi_onc android_kernel_xiaomi_onclite; do
  if [ -d "${dir}/arch/arm64/configs" ]; then
    KERNEL_DIR="${dir}"
    break
  fi
done

# Fallback: cari folder yang punya arch/arm64/configs
if [ -z "${KERNEL_DIR}" ]; then
  KERNEL_DIR="$(find . -maxdepth 3 -type d -path "*/arch/arm64/configs" | head -n 1 | sed 's#/arch/arm64/configs##' | sed 's#^\./##')"
fi

if [ -z "${KERNEL_DIR}" ] || [ ! -d "${KERNEL_DIR}" ]; then
  echo "ERROR: Kernel source folder tidak ditemukan."
  echo "Isi repo:"
  ls -la
  exit 1
fi

echo "Kernel dir: ${KERNEL_DIR}"

CONFIG_DIR="${KERNEL_DIR}/arch/arm64/configs"
DEFCONFIG_PATH="${CONFIG_DIR}/${DEFCONFIG}"

# Kalau defconfig input tidak ada, coba cari defconfig yang mirip onclite/onc
if [ ! -f "${DEFCONFIG_PATH}" ]; then
  echo "WARNING: ${DEFCONFIG_PATH} tidak ditemukan."
  echo "Mencari defconfig alternatif..."

  ALT_DEFCONFIG="$(find "${CONFIG_DIR}" -maxdepth 1 -type f \( -iname "*onclite*defconfig" -o -iname "*onc*defconfig" -o -iname "*msm8953*defconfig" \) | head -n 1 || true)"

  if [ -n "${ALT_DEFCONFIG}" ]; then
    DEFCONFIG_PATH="${ALT_DEFCONFIG}"
    DEFCONFIG="$(basename "${ALT_DEFCONFIG}")"
    echo "Pakai defconfig alternatif: ${DEFCONFIG}"
  else
    echo "ERROR: Tidak menemukan defconfig yang cocok."
    echo "Daftar defconfig:"
    ls -la "${CONFIG_DIR}" | head -n 80
    exit 1
  fi
fi

echo "Defconfig path: ${DEFCONFIG_PATH}"

# Fungsi set config
set_config() {
  local key="$1"
  local val="$2"

  sed -i "/^${key}=/d" "${DEFCONFIG_PATH}"
  sed -i "/^# ${key} is not set/d" "${DEFCONFIG_PATH}"

  if [ "${val}" = "n" ]; then
    echo "# ${key} is not set" >> "${DEFCONFIG_PATH}"
  else
    echo "${key}=${val}" >> "${DEFCONFIG_PATH}"
  fi
}

echo "==> Menambahkan config ReSukiSU-only"

set_config CONFIG_KSU y
set_config CONFIG_KSU_MANUAL_HOOK y
set_config CONFIG_KALLSYMS y
set_config CONFIG_KALLSYMS_ALL y

# Untuk kernel 4.9 non-GKI manual hook, jangan pakai kprobes dulu
set_config CONFIG_KPROBES n

# Tambahan yang biasanya dibutuhkan root/kernel manager
set_config CONFIG_OVERLAY_FS y
set_config CONFIG_MODULES y
set_config CONFIG_MODULE_UNLOAD y
set_config CONFIG_SECURITY_SELINUX y

echo "==> Hasil config yang ditambahkan:"
grep -E "CONFIG_KSU|CONFIG_KALLSYMS|CONFIG_KPROBES|CONFIG_OVERLAY_FS|CONFIG_MODULES|CONFIG_SECURITY_SELINUX" "${DEFCONFIG_PATH}" || true

echo "==> Selesai enable ReSukiSU config"
