#!/usr/bin/env bash
set -euo pipefail

echo "==> Apply ReSukiSU execveat manual hook"

ROOT_DIR="$(pwd)"

KERNEL_DIR=""

for dir in kernel kernel_source source android_kernel_xiaomi_onc android_kernel_xiaomi_onclite; do
  if [ -d "${dir}/fs" ] && [ -f "${dir}/fs/exec.c" ]; then
    KERNEL_DIR="${dir}"
    break
  fi
done

if [ -z "${KERNEL_DIR}" ]; then
  KERNEL_DIR="$(find . -maxdepth 3 -type f -path "*/fs/exec.c" | head -n 1 | sed 's#/fs/exec.c##' | sed 's#^\./##')"
fi

if [ -z "${KERNEL_DIR}" ] || [ ! -d "${KERNEL_DIR}" ]; then
  echo "ERROR: Kernel source folder tidak ditemukan."
  ls -la
  exit 1
fi

EXEC_FILE="${KERNEL_DIR}/fs/exec.c"

if [ ! -f "${EXEC_FILE}" ]; then
  echo "ERROR: ${EXEC_FILE} tidak ditemukan."
  exit 1
fi

echo "Kernel dir: ${KERNEL_DIR}"
echo "Exec file : ${EXEC_FILE}"

python3 - <<'PY'
from pathlib import Path
import re
import sys

candidates = [
    Path("kernel/fs/exec.c"),
    Path("kernel_source/fs/exec.c"),
    Path("source/fs/exec.c"),
    Path("android_kernel_xiaomi_onc/fs/exec.c"),
    Path("android_kernel_xiaomi_onclite/fs/exec.c"),
]

exec_file = None

for p in candidates:
    if p.exists():
        exec_file = p
        break

if exec_file is None:
    found = list(Path(".").glob("*/fs/exec.c"))
    if found:
        exec_file = found[0]

if exec_file is None:
    print("ERROR: fs/exec.c tidak ditemukan")
    sys.exit(1)

text = exec_file.read_text(errors="ignore")

if "ksu_handle_execveat(&fd, &filename, &argv, &envp, &flags)" in text:
    print("Hook ksu_handle_execveat sudah ada. Skip.")
    sys.exit(0)

extern_block = """
#ifdef CONFIG_KSU_MANUAL_HOOK
extern int ksu_handle_execveat(int *fd, struct filename **filename_ptr,
                               void *argv, void *envp, int *flags);
#endif

"""

if "extern int ksu_handle_execveat" not in text:
    m = re.search(r"(static\s+int\s+do_execveat_common\s*\()", text)
    if not m:
        print("ERROR: Tidak menemukan do_execveat_common untuk tempat extern.")
        sys.exit(1)

    text = text[:m.start()] + extern_block + text[m.start():]

hook_block = """
#ifdef CONFIG_KSU_MANUAL_HOOK
	ksu_handle_execveat(&fd, &filename, &argv, &envp, &flags);
#endif

"""

m = re.search(
    r"static\s+int\s+do_execveat_common\s*\([^)]*\)\s*\{",
    text,
    re.S
)

if not m:
    print("ERROR: Fungsi do_execveat_common tidak ditemukan.")
    sys.exit(1)

func_start = m.end()
window = text[func_start:func_start + 7000]

# Lokasi paling aman untuk Linux 4.9: setelah deklarasi variable, sebelum if (IS_ERR(filename))
target = re.search(r"\n\s*if\s*\(\s*IS_ERR\s*\(\s*filename\s*\)\s*\)", window)

if not target:
    print("ERROR: Tidak menemukan baris if (IS_ERR(filename)) di do_execveat_common.")
    print("Coba buka kernel/fs/exec.c dan kirim bagian fungsi do_execveat_common.")
    sys.exit(1)

insert_at = func_start + target.start()

text = text[:insert_at] + hook_block + text[insert_at:]

exec_file.write_text(text)

print(f"Patched file: {exec_file}")
PY

echo "==> Verify hook"
grep -n "ksu_handle_execveat" "${EXEC_FILE}" || {
  echo "ERROR: hook tetap tidak ditemukan setelah patch."
  exit 1
}

echo "==> Context:"
grep -n -A5 -B5 "ksu_handle_execveat" "${EXEC_FILE}" || true

echo "==> Execveat hook patch selesai"
