#!/usr/bin/env bash
set -euo pipefail

echo "==> Apply ReSukiSU newfstat_ret manual hook"

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

if "ksu_handle_newfstat_ret(&fd, &statbuf)" in text:
    print("Hook ksu_handle_newfstat_ret sudah ada. Skip.")
    sys.exit(0)

extern_block = """
#ifdef CONFIG_KSU_MANUAL_HOOK
__attribute__((hot))
extern void ksu_handle_newfstat_ret(unsigned int *fd,
				    struct stat __user **statbuf_ptr);
#if defined(__ARCH_WANT_STAT64) || defined(__ARCH_WANT_COMPAT_STAT64)
extern void ksu_handle_fstat64_ret(unsigned long *fd,
				   struct stat64 __user **statbuf_ptr);
#endif
#endif

"""

if "extern void ksu_handle_newfstat_ret" not in text:
    marker = re.search(r"\nSYSCALL_DEFINE2\s*\(\s*newfstat\s*,", text)
    if not marker:
        print("ERROR: Tidak menemukan SYSCALL_DEFINE2(newfstat).")
        print("Kirim bagian fs/stat.c sekitar newfstat.")
        sys.exit(1)

    text = text[:marker.start()+1] + extern_block + text[marker.start()+1:]

def patch_func(text, syscall_name, hook_text):
    sig = re.search(r"SYSCALL_DEFINE2\s*\(\s*" + re.escape(syscall_name) + r"\s*,", text)
    if not sig:
        return text, 0

    brace = text.find("{", sig.end())
    if brace == -1:
        return text, 0

    # Cari akhir fungsi secara sederhana dengan bracket counter
    depth = 0
    end = None
    for i in range(brace, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                end = i
                break

    if end is None:
        return text, 0

    body = text[brace:end]

    if hook_text.strip() in body:
        return text, 0

    # Masukkan sebelum "return error;" terakhir di fungsi
    matches = list(re.finditer(r"\n\s*return\s+error\s*;", body))
    if not matches:
        return text, 0

    insert_at = brace + matches[-1].start()

    hook_block = "\n#ifdef CONFIG_KSU_MANUAL_HOOK\n\t" + hook_text + "\n#endif\n"

    text = text[:insert_at] + hook_block + text[insert_at:]
    return text, 1

text, n1 = patch_func(
    text,
    "newfstat",
    "ksu_handle_newfstat_ret(&fd, &statbuf);"
)

# Optional untuk 32-bit su, kalau fungsi fstat64 ada
text, n2 = patch_func(
    text,
    "fstat64",
    "ksu_handle_fstat64_ret(&fd, &statbuf);"
)

if n1 == 0:
    print("ERROR: Gagal patch SYSCALL_DEFINE2(newfstat).")
    print("Kirim bagian fs/stat.c sekitar SYSCALL_DEFINE2(newfstat).")
    sys.exit(1)

stat_file.write_text(text)

print(f"Patched file: {stat_file}")
print(f"newfstat patched: {n1}")
print(f"fstat64 patched : {n2}")
PY

echo "==> Verify newfstat_ret hook"
grep -n "ksu_handle_newfstat_ret" "${STAT_FILE}" || {
  echo "ERROR: hook tetap tidak ditemukan setelah patch."
  exit 1
}

echo "==> Context:"
grep -n -A8 -B8 "ksu_handle_newfstat_ret" "${STAT_FILE}" || true

echo "==> newfstat_ret hook patch selesai"
