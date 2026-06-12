#!/usr/bin/env bash
set -euo pipefail

echo "==> Apply ReSukiSU sys_reboot manual hook"

ROOT_DIR="$(pwd)"

KERNEL_DIR=""

for dir in kernel kernel_source source android_kernel_xiaomi_onc android_kernel_xiaomi_onclite; do
  if [ -d "${dir}/kernel" ]; then
    KERNEL_DIR="${dir}"
    break
  fi
done

if [ -z "${KERNEL_DIR}" ]; then
  KERNEL_DIR="$(find . -maxdepth 3 -type d -path "*/kernel" | head -n 1 | sed 's#/kernel##' | sed 's#^\./##')"
fi

if [ -z "${KERNEL_DIR}" ] || [ ! -d "${KERNEL_DIR}" ]; then
  echo "ERROR: Kernel source folder tidak ditemukan."
  ls -la
  exit 1
fi

REBOOT_FILE=""

if [ -f "${KERNEL_DIR}/kernel/reboot.c" ]; then
  REBOOT_FILE="${KERNEL_DIR}/kernel/reboot.c"
elif [ -f "${KERNEL_DIR}/kernel/sys.c" ]; then
  REBOOT_FILE="${KERNEL_DIR}/kernel/sys.c"
else
  echo "ERROR: kernel/reboot.c atau kernel/sys.c tidak ditemukan."
  exit 1
fi

echo "Kernel dir : ${KERNEL_DIR}"
echo "Reboot file: ${REBOOT_FILE}"

python3 - <<'PY'
from pathlib import Path
import re
import sys

candidates = [
    Path("kernel/kernel/reboot.c"),
    Path("kernel_source/kernel/reboot.c"),
    Path("source/kernel/reboot.c"),
    Path("android_kernel_xiaomi_onc/kernel/reboot.c"),
    Path("android_kernel_xiaomi_onclite/kernel/reboot.c"),
    Path("kernel/kernel/sys.c"),
    Path("kernel_source/kernel/sys.c"),
    Path("source/kernel/sys.c"),
    Path("android_kernel_xiaomi_onc/kernel/sys.c"),
    Path("android_kernel_xiaomi_onclite/kernel/sys.c"),
]

reboot_file = None

for p in candidates:
    if p.exists() and "SYSCALL_DEFINE4(reboot" in p.read_text(errors="ignore"):
        reboot_file = p
        break

if reboot_file is None:
    found = []
    found += list(Path(".").glob("*/kernel/reboot.c"))
    found += list(Path(".").glob("*/kernel/sys.c"))
    for p in found:
        if "SYSCALL_DEFINE4(reboot" in p.read_text(errors="ignore"):
            reboot_file = p
            break

if reboot_file is None:
    print("ERROR: Tidak menemukan file yang punya SYSCALL_DEFINE4(reboot).")
    sys.exit(1)

text = reboot_file.read_text(errors="ignore")

if "ksu_handle_sys_reboot(magic1, magic2, cmd, &arg)" in text:
    print("Hook ksu_handle_sys_reboot sudah ada. Skip.")
    sys.exit(0)

extern_block = """
#ifdef CONFIG_KSU_MANUAL_HOOK
extern int ksu_handle_sys_reboot(int magic1, int magic2, unsigned int cmd, void __user **arg);
#endif

"""

if "extern int ksu_handle_sys_reboot" not in text:
    marker = re.search(r"\nSYSCALL_DEFINE4\s*\(\s*reboot\s*,", text)
    if not marker:
        print("ERROR: Tidak menemukan SYSCALL_DEFINE4(reboot).")
        sys.exit(1)

    text = text[:marker.start()+1] + extern_block + text[marker.start()+1:]

m = re.search(r"SYSCALL_DEFINE4\s*\(\s*reboot\s*,", text)
if not m:
    print("ERROR: Fungsi reboot tidak ditemukan.")
    sys.exit(1)

brace = text.find("{", m.end())
if brace == -1:
    print("ERROR: Body reboot tidak ditemukan.")
    sys.exit(1)

window_start = brace + 1
window = text[window_start:window_start + 2500]

target = re.search(r"\n\s*/\*\s*We only trust the superuser", window)

if target:
    insert_at = window_start + target.start()
else:
    target = re.search(r"\n\s*if\s*\(\s*!ns_capable", window)
    if target:
        insert_at = window_start + target.start()
    else:
        # fallback: masukkan tepat setelah pembuka fungsi
        insert_at = window_start

hook_block = """
#ifdef CONFIG_KSU_MANUAL_HOOK
	ksu_handle_sys_reboot(magic1, magic2, cmd, &arg);
#endif

"""

text = text[:insert_at] + hook_block + text[insert_at:]

reboot_file.write_text(text)

print(f"Patched file: {reboot_file}")
PY

echo "==> Verify sys_reboot hook"
grep -n "ksu_handle_sys_reboot" "${REBOOT_FILE}" || {
  echo "ERROR: hook tetap tidak ditemukan setelah patch."
  exit 1
}

echo "==> Context:"
grep -n -A8 -B8 "ksu_handle_sys_reboot" "${REBOOT_FILE}" || true

echo "==> sys_reboot hook patch selesai"
