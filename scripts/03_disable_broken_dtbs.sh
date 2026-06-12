#!/usr/bin/env bash
set -euo pipefail

echo "==> Disable broken/non-onclite DTBs"

ROOT_DIR="$(pwd)"

KERNEL_DIR=""

for dir in kernel kernel_source source android_kernel_xiaomi_onc android_kernel_xiaomi_onclite; do
  if [ -d "${dir}/arch/arm64/boot/dts/qcom" ]; then
    KERNEL_DIR="${dir}"
    break
  fi
done

if [ -z "${KERNEL_DIR}" ]; then
  KERNEL_DIR="$(find . -maxdepth 5 -type d -path "*/arch/arm64/boot/dts/qcom" | head -n 1 | sed 's#/arch/arm64/boot/dts/qcom##' | sed 's#^\./##')"
fi

if [ -z "${KERNEL_DIR}" ] || [ ! -d "${KERNEL_DIR}" ]; then
  echo "ERROR: Kernel source folder tidak ditemukan."
  ls -la
  exit 1
fi

QCOM_DTS_DIR="${KERNEL_DIR}/arch/arm64/boot/dts/qcom"
QCOM_MAKEFILE="${QCOM_DTS_DIR}/Makefile"

echo "Kernel dir    : ${KERNEL_DIR}"
echo "QCOM DTS dir  : ${QCOM_DTS_DIR}"
echo "QCOM Makefile : ${QCOM_MAKEFILE}"

if [ ! -f "${QCOM_MAKEFILE}" ]; then
  echo "WARNING: ${QCOM_MAKEFILE} tidak ada, skip."
  exit 0
fi

echo "==> Backup Makefile"
cp "${QCOM_MAKEFILE}" "${QCOM_MAKEFILE}.bak"

echo "==> Disable broken dragon DTBs"
sed -i '/apq8053-lite-dragon/d' "${QCOM_MAKEFILE}"
sed -i '/typec_ssmux_config/d' "${QCOM_MAKEFILE}" || true

echo "==> Result check"
if grep -n "apq8053-lite-dragon" "${QCOM_MAKEFILE}"; then
  echo "WARNING: masih ada apq8053-lite-dragon di Makefile"
else
  echo "OK: apq8053-lite-dragon sudah dihapus dari build list"
fi

echo "==> Cari target onclite/onc/msm8953"
find "${QCOM_DTS_DIR}" -maxdepth 1 -type f \( \
  -iname "*onclite*.dts" -o \
  -iname "*onclite*.dtsi" -o \
  -iname "*onc*.dts" -o \
  -iname "*onc*.dtsi" -o \
  -iname "*msm8953*.dts" -o \
  -iname "*sdm632*.dts" \
\) | sort || true

echo "==> Broken DTB disable selesai"
