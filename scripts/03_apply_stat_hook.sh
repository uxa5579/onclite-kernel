#!/usr/bin/env bash
set -euo pipefail

echo "==> Apply ReSukiSU stat manual hook"

ROOT_DIR="$(pwd)"

KERNEL_DIR=""

for dir in kernel kernel_source source android_kernel_xiaomi_onc android_kernel_xiaomi_onclite; do
  if [ -d "${dir}/fs" ] && [ -f "${dir}/fs/stat.c" ]; then
    KERNEL_DIR="${dir}"
    break
  fi
done

if [ -z "${KERNEL_DIR}" ]; then
  KERNEL_DIR="$(find . -maxdepth 3 -type f -path "*/fs/stat.c" | head -n 1 | sed 's#/fs/stat.c##' | sed 's#^\./##')"
fi

if [ -z "${KERNEL_DIR}" ] || [ ! -d "${KERNEL_DIR}" ]; then
  echo "ERROR: Kernel source folder tidak ditemukan."
  ls -la
  exit 1
fi

STAT_FILE="${KERNEL_DIR}/fs/stat.c"

if [ ! -f "${STAT_FILE}" ]; then
  echo "ERROR: ${STAT_FILE} tidak ditemukan."
  exit 1
fi

echo "Kernel dir: ${KERNEL_DIR}"
echo "Stat file : ${STAT_FILE}"

python3 - <<'PY'
from pathlib import Path
import re
import sys

candidates = [
    Path("kernel/fs/stat.c"),
    Path("kernel_source/fs/stat.c"),
    Path("source/fs/stat.c"),
    Path("android_kernel_xiaomi_onc/fs/stat.c"),
    Path("android_kernel_xiaomi_onclite/fs/stat.c"),
]

stat_file = None

for p in candidates:
    if p.exists():
        stat_file = p
        break

if stat_file is None:
    found = list(Path(".").glob("*/fs/stat.c"))
    if found:
        stat_file = found[0]

if stat_file is None:
    print("ERROR: fs/stat.c tidak ditemukan")
    sys.exit(1)

text = stat_file.read_text(errors="ignore")

if "ksu_handle_stat(&dfd, &filename" in text:
    print("Hook ksu_handle_stat sudah ada. Skip.")
    sys.exit(0)

extern_block = """
#ifdef CONFIG_KSU_MANUAL_HOOK
__attribute__((hot))
extern int ksu_handle_stat(int *dfd, const char __user **filename_user,
			   int *flags);
#endif

"""

# Biasanya kernel 4.9 memakai vfs_fstatat()
marker = re.search(r"\nint\s+vfs_fstatat\s*\(", text)
if not marker:
    marker = re.search(r"\nSYSCALL_DEFINE4\s*\(\s*newfstatat\s*,", text)

if not marker:
    print("ERROR: Tidak menemukan vfs_fstatat atau SYSCALL_DEFINE4(newfstatat).")
    print("Kirim bagian fs/stat.c sekitar vfs_fstatat.")
    sys.exit(1)

if "extern int ksu_handle_stat" not in text:
    text = text[:marker.start()+1] + extern_block + text[marker.start()+1:]

# Patch fungsi vfs_fstatat
m = re.search(
    r"int\s+vfs_fstatat\s*\(\s*int\s+dfd\s*,\s*const\s+char\s+__user\s+\*filename\s*,\s*struct\s+kstat\s+\*stat\s*,\s*int\s+flag\s*\)\s*\{",
    text,
    re.S
)

if not m:
    print("ERROR: Signature vfs_fstatat tidak cocok.")
    print("Coba cari manual: int vfs_fstatat(")
    sys.exit(1)

insert_at = m.end()

hook_block = """
#ifdef CONFIG_KSU_MANUAL_HOOK
	ksu_handle_stat(&dfd, &filename, &flag);
#endif

"""

text = text[:insert_at] + hook_block + text[insert_at:]

stat_file.write_text(text)

print(f"Patched file: {stat_file}")
PY

echo "==> Verify stat hook"
grep -n "ksu_handle_stat" "${STAT_FILE}" || {
  echo "ERROR: hook tetap tidak ditemukan setelah patch."
  exit 1
}

echo "==> Context:"
grep -n -A8 -B8 "ksu_handle_stat" "${STAT_FILE}" || true

echo "==> stat hook patch selesai"
