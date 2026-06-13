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
  echo "Isi root repo:"
  ls -la
  exit 1
fi

echo "Kernel dir: ${KERNEL_DIR}"

OUT_DIR="${ROOT_DIR}/out"
DIST_DIR="${ROOT_DIR}/dist"

mkdir -p "${OUT_DIR}"
mkdir -p "${DIST_DIR}"

echo "==> Force disable broken DTBs before build"

cd "${ROOT_DIR}"

if [ -f "scripts/03_disable_broken_dtbs.sh" ]; then
  sed -i 's/\r$//' scripts/03_disable_broken_dtbs.sh
  chmod +x scripts/03_disable_broken_dtbs.sh
  bash scripts/03_disable_broken_dtbs.sh
else
  echo "WARNING: scripts/03_disable_broken_dtbs.sh tidak ada, skip disable broken DTBs."
fi

cd "${ROOT_DIR}/${KERNEL_DIR}"

export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_USER=resukisu
export KBUILD_BUILD_HOST=github-actions

echo "==> Check defconfig"

if [ ! -f "arch/arm64/configs/${DEFCONFIG}" ]; then
  echo "WARNING: ${DEFCONFIG} tidak ditemukan."
  echo "Mencari defconfig alternatif..."

  ALT_DEFCONFIG="$(find arch/arm64/configs -maxdepth 1 -type f \( \
    -iname "*onclite*defconfig" -o \
    -iname "*onc*defconfig" -o \
    -iname "*msm8953*defconfig" -o \
    -iname "*sdm632*defconfig" \
  \) | head -n 1 || true)"

  if [ -n "${ALT_DEFCONFIG}" ]; then
    DEFCONFIG="$(basename "${ALT_DEFCONFIG}")"
    echo "Pakai defconfig alternatif: ${DEFCONFIG}"
  else
    echo "ERROR: Tidak menemukan defconfig cocok."
    echo "Daftar defconfig:"
    ls -la arch/arm64/configs | head -n 100
    exit 1
  fi
fi

echo "==> Make defconfig"

make O="${OUT_DIR}" "${DEFCONFIG}"

echo "==> Final config check"

if [ -f "${OUT_DIR}/.config" ]; then
  grep -E "CONFIG_KSU|CONFIG_KALLSYMS|CONFIG_KPROBES|CONFIG_OVERLAY_FS|CONFIG_MODULES|CONFIG_SECURITY_SELINUX" "${OUT_DIR}/.config" || true
else
  echo "ERROR: ${OUT_DIR}/.config tidak ditemukan setelah make defconfig."
  exit 1
fi

echo "==> Setup compiler"

if [ "${USE_CCACHE:-0}" = "1" ] && command -v ccache >/dev/null 2>&1; then
  CC_CMD="ccache clang"
  echo "Using ccache."
else
  CC_CMD="clang"
  echo "Using clang without ccache."
fi

JOBS="$(nproc)"

echo "Compiler: ${CC_CMD}"
echo "Jobs    : ${JOBS}"

if command -v clang >/dev/null 2>&1; then
  echo "Clang version:"
  clang --version | head -n 3 || true
fi

if command -v ccache >/dev/null 2>&1; then
  echo "Ccache status before build:"
  ccache -s || true
fi

echo "==> Start kernel build"

make -j"${JOBS}" O="${OUT_DIR}" \
  CC="${CC_CMD}" \
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
  echo "Isi folder boot:"
  find "${OUT_DIR}/arch/arm64/boot" -maxdepth 3 -type f | sort || true
  exit 1
fi

echo "Kernel image: ${IMAGE_PATH}"

cp "${IMAGE_PATH}" "${DIST_DIR}/Image.gz-dtb"
cp "${OUT_DIR}/.config" "${DIST_DIR}/kernel_config_built.txt"

if command -v ccache >/dev/null 2>&1; then
  echo "Ccache status after build:"
  ccache -s || true
fi

echo "==> Build selesai"
ls -lh "${DIST_DIR}"
