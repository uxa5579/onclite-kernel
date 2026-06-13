#!/usr/bin/env bash
set -euo pipefail

echo "==> Build ReSukiSU-only kernel with original DTB tail"

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

ORIGINAL_BOOT=""

for f in \
  "${ROOT_DIR}/original_boot.img" \
  "${ROOT_DIR}/boot.img" \
  "${ROOT_DIR}/boot_info/original_boot.img" \
  "${ROOT_DIR}/boot_info/boot.img"; do
  if [ -f "${f}" ]; then
    ORIGINAL_BOOT="${f}"
    break
  fi
done

if [ -z "${ORIGINAL_BOOT}" ]; then
  echo "ERROR: original boot.img tidak ditemukan."
  echo "Upload boot CrDroid kamu ke root repo dengan nama: original_boot.img"
  exit 1
fi

echo "Original boot: ${ORIGINAL_BOOT}"

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

clang --version | head -n 3 || true

if command -v ccache >/dev/null 2>&1; then
  echo "Ccache status before build:"
  ccache -s || true
fi

echo "==> Start kernel build"
echo "Important: building Image.gz only, original DTB will be reused."

make -j"${JOBS}" O="${OUT_DIR}" \
  CC="${CC_CMD}" \
  CLANG_TRIPLE=aarch64-linux-gnu- \
  CROSS_COMPILE=aarch64-linux-gnu- \
  CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
  Image.gz

echo "==> Search Image.gz output"

IMAGE_GZ=""

for f in \
  "${OUT_DIR}/arch/arm64/boot/Image.gz" \
  "${OUT_DIR}/arch/arm64/boot/Image"; do
  if [ -f "${f}" ]; then
    IMAGE_GZ="${f}"
    break
  fi
done

if [ -z "${IMAGE_GZ}" ]; then
  echo "ERROR: Image.gz tidak ditemukan."
  find "${OUT_DIR}/arch/arm64/boot" -maxdepth 3 -type f | sort || true
  exit 1
fi

echo "Built kernel image: ${IMAGE_GZ}"

echo "==> Extract original DTB tail and append to built Image.gz"

export ORIGINAL_BOOT
export IMAGE_GZ
export DIST_DIR

python3 - <<'PY'
import os
import struct
import sys
import zlib
from pathlib import Path

original_boot = Path(os.environ["ORIGINAL_BOOT"])
image_gz = Path(os.environ["IMAGE_GZ"])
dist_dir = Path(os.environ["DIST_DIR"])

dist_dir.mkdir(parents=True, exist_ok=True)

boot = original_boot.read_bytes()
new_kernel = image_gz.read_bytes()

if boot[:8] != b"ANDROID!":
    print("ERROR: original_boot.img bukan Android boot image.")
    sys.exit(1)

def u32(buf, off):
    return struct.unpack_from("<I", buf, off)[0]

def align(x, page):
    return ((x + page - 1) // page) * page

kernel_size = u32(boot, 8)
ramdisk_size = u32(boot, 16)
page_size = u32(boot, 36)
header_version = u32(boot, 40)

header_size = page_size

if header_version >= 1 and len(boot) >= 1648:
    header_size_v1 = u32(boot, 1644)
    if 0 < header_size_v1 < 65536:
        header_size = align(header_size_v1, page_size)

kernel_off = align(header_size, page_size)
kernel_blob = boot[kernel_off:kernel_off + kernel_size]

if not kernel_blob.startswith(b"\x1f\x8b\x08"):
    print("ERROR: kernel original tidak diawali gzip magic.")
    print("Kemungkinan format boot tidak sesuai script ini.")
    sys.exit(1)

d = zlib.decompressobj(16 + zlib.MAX_WBITS)

try:
    _ = d.decompress(kernel_blob)
except Exception as e:
    print("ERROR: gagal decompress gzip kernel original:", e)
    sys.exit(1)

if not d.eof:
    print("ERROR: gzip kernel original tidak selesai/eof.")
    sys.exit(1)

dtb_tail = d.unused_data

if len(dtb_tail) < 1024:
    print("ERROR: DTB tail dari boot original terlalu kecil/kosong.")
    print("DTB tail size:", len(dtb_tail))
    sys.exit(1)

if not dtb_tail.startswith(b"\xd0\x0d\xfe\xed"):
    print("WARNING: DTB tail tidak diawali FDT magic, tapi tetap lanjut.")
    print("First bytes:", dtb_tail[:16].hex())

out_image = dist_dir / "Image.gz-dtb"
dtb_out = dist_dir / "original_dtb_tail.bin"

out_image.write_bytes(new_kernel + dtb_tail)
dtb_out.write_bytes(dtb_tail)

print("Original boot       :", original_boot)
print("Original kernel size:", kernel_size)
print("Original ramdisk    :", ramdisk_size)
print("Page size           :", page_size)
print("Header version      :", header_version)
print("New Image.gz size   :", len(new_kernel))
print("Original DTB tail   :", len(dtb_tail))
print("Output Image.gz-dtb :", out_image)
print("Saved DTB tail      :", dtb_out)
PY

cp "${OUT_DIR}/.config" "${DIST_DIR}/kernel_config_built.txt"

if command -v ccache >/dev/null 2>&1; then
  echo "Ccache status after build:"
  ccache -s || true
fi

echo "==> Build selesai"
ls -lh "${DIST_DIR}"
