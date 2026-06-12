#!/usr/bin/env bash
set -euo pipefail

echo "==> Apply ReSukiSU faccessat manual hook"

ROOT_DIR="$(pwd)"

KERNEL_DIR=""

for dir in kernel kernel_source source android_kernel_xiaomi_onc android_kernel_xiaomi_onclite; do
  if [ -d "${dir}/fs" ] && [ -f "${dir}/fs/open.c" ]; then
    KERNEL_DIR="${dir}"
    break
  fi
done

if [ -z "${KERNEL_DIR}" ]; then
  KERNEL_DIR="$(find . -maxdepth 3 -type f -path "*/fs/open.c" | head -n 1 | sed 's#/fs/open.c##' | sed 's#^\./##')"
fi

if [ -z "${KERNEL_DIR}" ] || [ ! -d "${KERNEL_DIR}" ]; then
  echo "ERROR: Kernel source folder tidak ditemukan."
  ls -la
  exit 1
fi

OPEN_FILE="${KERNEL_DIR}/fs/open.c"

if [ ! -f "${OPEN_FILE}" ]; then
  echo "ERROR: ${OPEN_FILE} tidak ditemukan."
  exit 1
fi

echo "Kernel dir: ${KERNEL_DIR}"
echo "Open file : ${OPEN_FILE}"

python3 - <<'PY'
from pathlib import Path
import re
import sys

candidates = [
    Path("kernel/fs/open.c"),
    Path("kernel_source/fs/open.c"),
    Path("source/fs/open.c"),
    Path("android_kernel_xiaomi_onc/fs/open.c"),
    Path("android_kernel_xiaomi_onclite/fs/open.c"),
]

open_file = None

for p in candidates:
    if p.exists():
        open_file = p
        break

if open_file is None:
    found = list(Path(".").glob("*/fs/open.c"))
    if found:
        open_file = found[0]

if open_file is None:
    print("ERROR: fs/open.c tidak ditemukan")
    sys.exit(1)

text = open_file.read_text(errors="ignore")

if "ksu_handle_faccessat(&dfd, &filename, &mode" in text:
    print("Hook ksu_handle_faccessat sudah ada. Skip.")
    sys.exit(0)

extern_block = """
#ifdef CONFIG_KSU_MANUAL_HOOK
__attribute__((hot))
extern int ksu_handle_faccessat(int *dfd, const char __user **filename_user,
				int *mode, int *flags);
#endif

"""

# Taruh extern sebelum syscall faccessat
if "extern int ksu_handle_faccessat" not in text:
    marker = re.search(r"\nSYSCALL_DEFINE[34]\s*\(\s*faccessat\s*,", text)
    if not marker:
        print("ERROR: Tidak menemukan SYSCALL_DEFINE3/4(faccessat) untuk tempat extern.")
        sys.exit(1)

    text = text[:marker.start()+1] + extern_block + text[marker.start()+1:]

hook_block = """
#ifdef CONFIG_KSU_MANUAL_HOOK
	ksu_handle_faccessat(&dfd, &filename, &mode, NULL);
#endif

"""

# Cari fungsi SYSCALL_DEFINE3(faccessat...) atau SYSCALL_DEFINE4(faccessat...)
m = re.search(r"SYSCALL_DEFINE[34]\s*\(\s*faccessat\s*,", text)
if not m:
    print("ERROR: Fungsi faccessat tidak ditemukan.")
    sys.exit(1)

# Cari pembuka body fungsi
brace = text.find("{", m.end())
if brace == -1:
    print("ERROR: Tidak menemukan body { untuk faccessat.")
    sys.exit(1)

# Ambil window isi fungsi
window_start = brace + 1
window = text[window_start:window_start + 5000]

# Lokasi ideal untuk kernel 4.9: sebelum validasi mode
target = re.search(r"\n\s*if\s*\(\s*mode\s*&", window)

if not target:
    # fallback: setelah lookup_flags declaration
    target = re.search(r"lookup_flags\s*=\s*LOOKUP_FOLLOW\s*;\s*", window)
    if target:
        insert_at = window_start + target.end()
    else:
        print("ERROR: Tidak menemukan lokasi aman untuk inject faccessat hook.")
        print("Kirim bagian fs/open.c sekitar SYSCALL_DEFINE3(faccessat).")
        sys.exit(1)
else:
    insert_at = window_start + target.start()

text = text[:insert_at] + hook_block + text[insert_at:]

open_file.write_text(text)

print(f"Patched file: {open_file}")
PY

echo "==> Verify faccessat hook"
grep -n "ksu_handle_faccessat" "${OPEN_FILE}" || {
  echo "ERROR: hook tetap tidak ditemukan setelah patch."
  exit 1
}

echo "==> Context:"
grep -n -A8 -B8 "ksu_handle_faccessat" "${OPEN_FILE}" || true

echo "==> faccessat hook patch selesai"
