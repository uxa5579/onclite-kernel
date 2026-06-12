#!/usr/bin/env bash
set -euo pipefail

echo "==> Apply ReSukiSU faccessat manual hook"

ROOT_DIR="$(pwd)"

KERNEL_DIR=""

for dir in kernel kernel_source source android_kernel_xiaomi_onc android_kernel_xiaomi_onclite; do
  if [ -d "${dir}/fs" ] && [ -f "${dir}/fs/access.c" ]; then
    KERNEL_DIR="${dir}"
    break
  fi
done

if [ -z "${KERNEL_DIR}" ]; then
  KERNEL_DIR="$(find . -maxdepth 3 -type f -path "*/fs/access.c" | head -n 1 | sed 's#/fs/access.c##' | sed 's#^\./##')"
fi

if [ -z "${KERNEL_DIR}" ] || [ ! -d "${KERNEL_DIR}" ]; then
  echo "ERROR: Kernel source folder tidak ditemukan."
  ls -la
  exit 1
fi

ACCESS_FILE="${KERNEL_DIR}/fs/access.c"

if [ ! -f "${ACCESS_FILE}" ]; then
  echo "ERROR: ${ACCESS_FILE} tidak ditemukan."
  exit 1
fi

echo "Kernel dir  : ${KERNEL_DIR}"
echo "Access file : ${ACCESS_FILE}"

python3 - <<'PY'
from pathlib import Path
import re
import sys

candidates = [
    Path("kernel/fs/access.c"),
    Path("kernel_source/fs/access.c"),
    Path("source/fs/access.c"),
    Path("android_kernel_xiaomi_onc/fs/access.c"),
    Path("android_kernel_xiaomi_onclite/fs/access.c"),
]

access_file = None

for p in candidates:
    if p.exists():
        access_file = p
        break

if access_file is None:
    found = list(Path(".").glob("*/fs/access.c"))
    if found:
        access_file = found[0]

if access_file is None:
    print("ERROR: fs/access.c tidak ditemukan")
    sys.exit(1)

text = access_file.read_text(errors="ignore")

if "ksu_handle_faccessat" in text:
    print("Hook ksu_handle_faccessat sudah ada. Skip.")
    sys.exit(0)

# Add extern declaration
extern_block = """
#ifdef CONFIG_KSU_MANUAL_HOOK
extern int ksu_handle_faccessat(int *dfd, struct filename **filename_ptr, int *mode);
#endif

"""

if "extern int ksu_handle_faccessat" not in text:
    # Find do_faccessat function
    m = re.search(r"(static\s+(?:long\s+)?int\s+do_faccessat\s*\()", text)
    if not m:
        print("ERROR: Tidak menemukan do_faccessat untuk tempat extern.")
        print("Coba cari fungsi dengan nama berbeda di fs/access.c")
        sys.exit(1)
    
    text = text[:m.start()] + extern_block + text[m.start():]

# Add hook call at start of do_faccessat
hook_block = """
#ifdef CONFIG_KSU_MANUAL_HOOK
	ksu_handle_faccessat(&dfd, &filename, &mode);
#endif

"""

m = re.search(
    r"(static\s+(?:long\s+)?int\s+do_faccessat\s*\([^)]*\)\s*\{)",
    text,
    re.S
)

if not m:
    print("ERROR: Fungsi do_faccessat tidak ditemukan.")
    print("Coba buka fs/access.c dan kirim bagian fungsi do_faccessat.")
    sys.exit(1)

func_start = m.end()

# Insert hook after function opening brace and variable declarations
# Look for the first substantial code line after declarations
window = text[func_start:func_start + 5000]

# Try multiple patterns to find a safe insertion point
insert_point = None

# Pattern 1: After variable declarations, before first if
m = re.search(r"\n\s*(?:if|return|access_flags_t)", window)
if m:
    insert_point = func_start + m.start()
else:
    # Pattern 2: After a few lines of the function
    lines = window.split('\n')
    for i, line in enumerate(lines[:10]):
        if line.strip() and not line.strip().startswith('//') and not re.match(r'^\s*\w+\s+\w+\s*=', line):
            if i > 0:
                insert_point = func_start + sum(len(l) + 1 for l in lines[:i])
                break

if insert_point is None:
    # Fallback: insert right after function opening
    insert_point = func_start + 1

text = text[:insert_point] + '\n' + hook_block + text[insert_point:]

access_file.write_text(text)

print(f"Patched file: {access_file}")
PY

echo "==> Verify hook"
grep -n "ksu_handle_faccessat" "${ACCESS_FILE}" || {
  echo "ERROR: hook tetap tidak ditemukan setelah patch."
  exit 1
}

echo "==> Context:"
grep -n -A3 -B3 "ksu_handle_faccessat" "${ACCESS_FILE}" || true

echo "==> Faccessat hook patch selesai"
