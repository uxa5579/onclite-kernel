#!/usr/bin/env bash
set -euo pipefail

echo "==> Keep only onclite/SDM632 DTBs and DTBOs"

ROOT_DIR="$(pwd)"
KERNEL_DIR=""

if [ -d "arch/arm64/boot/dts/qcom" ]; then
  KERNEL_DIR="."
else
  for dir in kernel kernel_source source android_kernel_xiaomi_onc android_kernel_xiaomi_onclite; do
    if [ -d "${dir}/arch/arm64/boot/dts/qcom" ]; then
      KERNEL_DIR="${dir}"
      break
    fi
  done
fi

if [ -z "${KERNEL_DIR}" ]; then
  KERNEL_DIR="$(find . -maxdepth 5 -type d -path "*/arch/arm64/boot/dts/qcom" | head -n 1 | sed 's#/arch/arm64/boot/dts/qcom##' | sed 's#^\./##')"
fi

if [ -z "${KERNEL_DIR}" ] || [ ! -d "${KERNEL_DIR}" ]; then
  echo "ERROR: Kernel source folder tidak ditemukan."
  ls -la
  exit 1
fi

QCOM_DTS_DIR="${KERNEL_DIR}/arch/arm64/boot/dts/qcom"
QCOM_MAKEFILE="${QCOM_DTS_DIR}/Makefile"

echo "Kernel dir    : ${KERNEL_DIR}"
echo "QCOM DTS dir  : ${QCOM_DTS_DIR}"
echo "QCOM Makefile : ${QCOM_MAKEFILE}"

if [ ! -f "${QCOM_MAKEFILE}" ]; then
  echo "ERROR: ${QCOM_MAKEFILE} tidak ditemukan."
  exit 1
fi

cp "${QCOM_MAKEFILE}" "${QCOM_MAKEFILE}.bak"

python3 - <<'PY'
from pathlib import Path
import re
import sys

candidates = [
    Path("arch/arm64/boot/dts/qcom/Makefile"),
    Path("kernel/arch/arm64/boot/dts/qcom/Makefile"),
    Path("kernel_source/arch/arm64/boot/dts/qcom/Makefile"),
    Path("source/arch/arm64/boot/dts/qcom/Makefile"),
    Path("android_kernel_xiaomi_onc/arch/arm64/boot/dts/qcom/Makefile"),
    Path("android_kernel_xiaomi_onclite/arch/arm64/boot/dts/qcom/Makefile"),
]

makefile = None

for p in candidates:
    if p.exists():
        makefile = p
        break

if makefile is None:
    found = list(Path(".").glob("*/arch/arm64/boot/dts/qcom/Makefile"))
    if found:
        makefile = found[0]

if makefile is None:
    print("ERROR: qcom Makefile tidak ditemukan")
    sys.exit(1)

allowed_prefixes = (
    "sdm632",
    "onclite",
    "onc",
)

def is_allowed(token: str) -> bool:
    token = token.lower()
    return token.startswith(allowed_prefixes)

text = makefile.read_text(errors="ignore")
lines = text.splitlines()

dtb_token_re = re.compile(r'(?<![\w.-])([A-Za-z0-9_.+-]+\.dtbo?)(?![\w.-])')
base_line_re = re.compile(r'^\s*([A-Za-z0-9_.+-]+\.dtbo?)-base\s*:=')

kept = []
removed = []
new_lines = []

for raw_line in lines:
    line = raw_line
    lower = line.lower()

    if ".dtb" in lower or ".dtbo" in lower:
        base_match = base_line_re.match(line)

        # Hapus line seperti:
        # msm8953-cdp-overlay.dtbo-base := ...
        if base_match:
            base_target = base_match.group(1)
            if not is_allowed(base_target):
                removed.append(base_target + "-base")
                continue

        def replace_token(match):
            token = match.group(1)

            if is_allowed(token):
                kept.append(token)
                return token

            removed.append(token)
            return ""

        line = dtb_token_re.sub(replace_token, line)
        line = re.sub(r'[ \t]+', ' ', line).rstrip()

        stripped = line.strip()

        # Buang line kosong / line continuation kosong
        if stripped in ["", "\\"]:
            continue

        # Buang assignment dtb/dtbo yang sudah kosong
        if re.match(r'^(dtb|dtbo)-[^=]+\+=\s*\\?$', stripped):
            continue

    new_lines.append(line)

text = "\n".join(new_lines) + "\n"

# Bersihkan backslash kosong dan blank line berlebihan
text = re.sub(r'\n\s*\\\s*\n', '\n', text)
text = re.sub(r'\n{3,}', '\n\n', text)

makefile.write_text(text)

print(f"Patched Makefile: {makefile}")

print("")
print("==> Kept DTB/DTBO:")
for item in sorted(set(kept)):
    print(f"KEEP: {item}")

print("")
print("==> Removed DTB/DTBO / base entries:")
for item in sorted(set(removed))[:120]:
    print(f"REMOVE: {item}")

if len(set(removed)) > 120:
    print(f"... and {len(set(removed)) - 120} more removed")

# Validasi ketat: tidak boleh ada .dtb/.dtbo non-target tersisa, termasuk .dtbo-base
validation_lines = [
    l for l in text.splitlines()
    if not l.strip().startswith("#")
]
validation_text = "\n".join(validation_lines)

all_targets = re.findall(
    r'(?<![\w.-])([A-Za-z0-9_.+-]+\.dtbo?)(?:-base)?(?![\w.-])',
    validation_text,
    flags=re.I
)

bad_targets = sorted(set(t for t in all_targets if not is_allowed(t)))

if bad_targets:
    print("")
    print("ERROR: masih ada DTB/DTBO non-target:")
    for t in bad_targets:
        print("  " + t)
    sys.exit(1)

good_targets = sorted(set(t for t in all_targets if is_allowed(t)))

if not good_targets:
    print("")
    print("ERROR: tidak ada DTB/DTBO target SDM632/onclite/onc tersisa.")
    print("Backup Makefile ada di Makefile.bak")
    sys.exit(1)

print("")
print("OK: Makefile sekarang hanya menyisakan DTB/DTBO target SDM632/onclite/onc.")
PY

echo ""
echo "==> Verify remaining DTB/DTBO entries"
grep -nE "\.dtb|\.dtbo" "${QCOM_MAKEFILE}" || true

echo ""
echo "==> Available SDM632/onclite DTS files:"
find "${QCOM_DTS_DIR}" -maxdepth 1 -type f \( \
  -iname "sdm632*.dts" -o \
  -iname "sdm632*.dtsi" -o \
  -iname "*onclite*.dts" -o \
  -iname "*onclite*.dtsi" -o \
  -iname "onc*.dts" -o \
  -iname "onc*.dtsi" \
\) | sort || true

echo ""
echo "==> DTB filter selesai"
