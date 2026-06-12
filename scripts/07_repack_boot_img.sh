#!/usr/bin/env bash
set -euo pipefail

echo "==> Repack raw boot.img"

ROOT_DIR="$(pwd)"
DIST_DIR="${ROOT_DIR}/dist"
KERNEL_IMAGE="${DIST_DIR}/Image.gz-dtb"

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
  echo "WARNING: original boot.img tidak ditemukan."
  echo "Lewati raw boot.img repack. Pakai AnyKernel3 zip saja."
  exit 0
fi

if [ ! -f "${KERNEL_IMAGE}" ]; then
  echo "WARNING: ${KERNEL_IMAGE} tidak ditemukan."
  echo "Lewati raw boot.img repack."
  exit 0
fi

python3 - <<'PY'
import os
import struct
import hashlib
import math
import sys

root = os.getcwd()
dist = os.path.join(root, "dist")
kernel_path = os.path.join(dist, "Image.gz-dtb")

candidates = [
    os.path.join(root, "original_boot.img"),
    os.path.join(root, "boot.img"),
    os.path.join(root, "boot_info", "original_boot.img"),
    os.path.join(root, "boot_info", "boot.img"),
]

boot_path = next((p for p in candidates if os.path.exists(p)), None)

if not boot_path:
    print("original boot.img tidak ditemukan, skip")
    sys.exit(0)

if not os.path.exists(kernel_path):
    print("Image.gz-dtb tidak ditemukan, skip")
    sys.exit(0)

with open(boot_path, "rb") as f:
    orig = bytearray(f.read())

with open(kernel_path, "rb") as f:
    new_kernel = f.read()

if orig[:8] != b"ANDROID!":
    print("Bukan Android boot image, skip")
    sys.exit(0)

def u32(off):
    return struct.unpack_from("<I", orig, off)[0]

def u64(off):
    return struct.unpack_from("<Q", orig, off)[0]

def put_u32(buf, off, val):
    struct.pack_into("<I", buf, off, val)

def put_u64(buf, off, val):
    struct.pack_into("<Q", buf, off, val)

def align(x, page):
    return ((x + page - 1) // page) * page

old_kernel_size = u32(8)
ramdisk_size = u32(16)
second_size = u32(24)
page_size = u32(36)
header_version = u32(40)

if page_size <= 0 or page_size > 65536:
    print("Page size tidak valid, skip")
    sys.exit(0)

header_size = page_size
recovery_dtbo_size = 0

if header_version >= 1 and len(orig) >= 1648:
    recovery_dtbo_size = u32(1632)
    try:
        header_size_v1 = u32(1644)
        if header_size_v1 > 0:
            header_size = align(header_size_v1, page_size)
    except Exception:
        header_size = page_size

kernel_off = align(header_size, page_size)
ramdisk_off = kernel_off + align(old_kernel_size, page_size)
second_off = ramdisk_off + align(ramdisk_size, page_size)
recovery_dtbo_off = second_off + align(second_size, page_size)

ramdisk = orig[ramdisk_off:ramdisk_off + ramdisk_size] if ramdisk_size else b""
second = orig[second_off:second_off + second_size] if second_size else b""
recovery_dtbo = orig[recovery_dtbo_off:recovery_dtbo_off + recovery_dtbo_size] if recovery_dtbo_size else b""

new = bytearray(orig[:header_size])
put_u32(new, 8, len(new_kernel))

new_recovery_dtbo_offset = align(header_size, page_size)
new_recovery_dtbo_offset += align(len(new_kernel), page_size)
new_recovery_dtbo_offset += align(len(ramdisk), page_size)
new_recovery_dtbo_offset += align(len(second), page_size)

if header_version >= 1 and len(new) >= 1648:
    put_u64(new, 1636, new_recovery_dtbo_offset)

# update id hash sederhana
sha = hashlib.sha1()
sha.update(new_kernel)
sha.update(struct.pack("<I", len(new_kernel)))
sha.update(ramdisk)
sha.update(struct.pack("<I", len(ramdisk)))
sha.update(second)
sha.update(struct.pack("<I", len(second)))
digest = sha.digest()
id_off = 576
new[id_off:id_off+20] = digest

out = bytearray()
out += new
out += b"\x00" * (align(len(out), page_size) - len(out))

out += new_kernel
out += b"\x00" * (align(len(out), page_size) - len(out))

if ramdisk:
    out += ramdisk
    out += b"\x00" * (align(len(out), page_size) - len(out))

if second:
    out += second
    out += b"\x00" * (align(len(out), page_size) - len(out))

if recovery_dtbo:
    out += recovery_dtbo
    out += b"\x00" * (align(len(out), page_size) - len(out))

out_path = os.path.join(dist, "ReSukiSU-onclite-4.9-boot.img")
with open(out_path, "wb") as f:
    f.write(out)

print("Original boot :", boot_path)
print("Old kernel    :", old_kernel_size)
print("New kernel    :", len(new_kernel))
print("Page size     :", page_size)
print("Header version:", header_version)
print("Output        :", out_path)
PY

ls -lh "${DIST_DIR}" || true
