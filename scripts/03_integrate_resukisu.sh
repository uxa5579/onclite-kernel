#!/usr/bin/env bash
set -euo pipefail

echo "==> Integrate ReSukiSU"

ROOT_DIR="$(pwd)"
RESUKISU_REPO="${RESUKISU_REPO:-https://github.com/ReSukiSU/ReSukiSU.git}"
RESUKISU_BRANCH="${RESUKISU_BRANCH:-main}"

echo "Root dir       : ${ROOT_DIR}"
echo "ReSukiSU repo  : ${RESUKISU_REPO}"
echo "ReSukiSU branch: ${RESUKISU_BRANCH}"

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

if [ -f "drivers/kernelsu/Kconfig" ]; then
  echo "drivers/kernelsu sudah ada. Skip integrate."
  exit 0
fi

echo "==> Coba integrasi via setup.sh resmi ReSukiSU"

SETUP_OK=0

if curl -LSsf "https://raw.githubusercontent.com/ReSukiSU/ReSukiSU/main/kernel/setup.sh" -o /tmp/resukisu_setup.sh; then
  chmod +x /tmp/resukisu_setup.sh

  if bash /tmp/resukisu_setup.sh; then
    SETUP_OK=1
  else
    echo "setup.sh tanpa argumen gagal, coba dengan branch ${RESUKISU_BRANCH}"
    if bash /tmp/resukisu_setup.sh "${RESUKISU_BRANCH}"; then
      SETUP_OK=1
    fi
  fi
else
  echo "Gagal download setup.sh resmi, lanjut manual fallback."
fi

if [ "${SETUP_OK}" = "1" ] && [ -f "drivers/kernelsu/Kconfig" ]; then
  echo "ReSukiSU berhasil diintegrasikan via setup.sh."
else
  echo "==> Manual fallback integrate ReSukiSU"

  cd "${ROOT_DIR}"
  rm -rf resukisu_source

  if git clone --depth=1 --single-branch -b "${RESUKISU_BRANCH}" "${RESUKISU_REPO}" resukisu_source; then
    echo "Clone ReSukiSU branch ${RESUKISU_BRANCH} sukses."
  else
    echo "Clone branch ${RESUKISU_BRANCH} gagal, coba default branch."
    git clone --depth=1 "${RESUKISU_REPO}" resukisu_source
  fi

  KSU_KERNEL_DIR=""

  for d in \
    "resukisu_source/kernel" \
    "resukisu_source/KernelSU/kernel" \
    "resukisu_source/drivers/kernelsu"; do
    if [ -f "${d}/Kconfig" ]; then
      KSU_KERNEL_DIR="${d}"
      break
    fi
  done

  if [ -z "${KSU_KERNEL_DIR}" ]; then
    echo "ERROR: Tidak menemukan folder kernel ReSukiSU yang berisi Kconfig."
    echo "Isi repo ReSukiSU:"
    find resukisu_source -maxdepth 3 -type f | head -n 100
    exit 1
  fi

  echo "KSU kernel dir: ${KSU_KERNEL_DIR}"

  cd "${ROOT_DIR}/${KERNEL_DIR}"

  mkdir -p drivers
  rm -rf drivers/kernelsu
  cp -a "${ROOT_DIR}/${KSU_KERNEL_DIR}" drivers/kernelsu

  if [ ! -f "drivers/kernelsu/Kconfig" ]; then
    echo "ERROR: drivers/kernelsu/Kconfig tetap tidak ada setelah copy."
    ls -la drivers/kernelsu || true
    exit 1
  fi

  echo "==> Patch drivers/Makefile"

  if ! grep -q "kernelsu" drivers/Makefile; then
    echo 'obj-$(CONFIG_KSU) += kernelsu/' >> drivers/Makefile
  else
    echo "drivers/Makefile sudah punya entry kernelsu."
  fi

  echo "==> Patch drivers/Kconfig"

  if ! grep -q 'drivers/kernelsu/Kconfig' drivers/Kconfig; then
    cat >> drivers/Kconfig <<'EOF'

source "drivers/kernelsu/Kconfig"
EOF
  else
    echo "drivers/Kconfig sudah punya source kernelsu."
  fi
fi

echo "==> Validasi ReSukiSU"

if [ ! -f "drivers/kernelsu/Kconfig" ]; then
  echo "ERROR: ReSukiSU gagal terpasang, drivers/kernelsu/Kconfig tidak ada."
  exit 1
fi

echo "==> ReSukiSU files:"
find drivers/kernelsu -maxdepth 2 -type f | head -n 40

echo "==> Integrate ReSukiSU selesai"
