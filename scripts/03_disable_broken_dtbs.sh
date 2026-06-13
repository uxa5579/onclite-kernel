#!/usr/bin/env bash
set -euo pipefail

echo "==> Keep only onclite/SDM632 DTBs"

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

text = makefile.read_text(errors="ignore")

# Untuk Redmi 7/onclite, target aman adalah SDM632/onclite/onc.
# Semua DTB board lain seperti msm8953, apq8053, sdm450, sda450 akan dibuang dari build list.
allowed_prefixes = (
    "sdm632",
    "onclite",
    "onc",
)

dtb_token_re = re.compile(r'(?<![\w.-])([A-Za-z0-9_.+-]+\.dtbo?)(?![\w.-])')

kept = []
removed = []

def filter_dtb_token(match):
    token = match.group(1)
    base = token.lower()

    if base.startswith(allowed_prefixes):
        kept.append(token)
        return token

    removed.append(token)
    return ""

new_lines = []

for line in text.splitlines():
    original = line

    if ".dtb" in line or ".dtbo" in line:
        line = dtb_token_re.sub(filter_dtb_token, line)

        # Bersihkan whitespace berlebihan
        line = re.sub(r'[ \t]+', ' ', line).rstrip()

        stripped = line.strip()

        # Buang line dtb kosong
        if stripped in ["", "\\"]:
            continue

        if re.match(r'^dtb-[^=]+\+=\s*\\?$', stripped):
            continue

        if re.match(r'^dtbo-[^=]+\+=\s*\\?$', stripped):
            continue

    new_lines.append(line)

text = "\n".join(new_lines) + "\n"

# Bersihkan backslash kosong dan blank line berlebihan
text = re.sub(r'\n\s*\\\s*\n', '\n', text)
text = re.sub(r'\n{3,}', '\n\n', text)

makefile.write_text(text)

print(f"Patched Makefile: {makefile}")

kept_unique = sorted(set(kept))
removed_unique = sorted(set(removed))

print("")
print("==> Kept DTB/DTBO:")
for item in kept_unique:
    print(f"KEEP: {item}")

print("")
print("==> Removed non-onclite DTB/DTBO count:", len(removed_unique))
for item in removed_unique[:80]:
    print(f"REMOVE: {item}")

if len(removed_unique) > 80:
    print(f"... and {len(removed_unique) - 80} more removed")

if not kept_unique:
    print("ERROR: Tidak ada DTB SDM632/onclite/onc yang tersisa.")
    print("Isi Makefile backup masih ada di Makefile.bak")
    sys.exit(1)

# Validasi: jangan sampai DTB bermasalah masih tersisa
bad_patterns = [
    "apq8053",
    "msm8953",
    "sdm450",
    "sda450",
    "pmi8937",
    "pmi8940",
    "lite-dragon",
]

lower_text = text.lower()

for bad in bad_patterns:
    bad_dtb = re.findall(r'[A-Za-z0-9_.+-]*' + re.escape(bad) + r'[A-Za-z0-9_.+-]*\.dtbo?', lower_text)
    if bad_dtb:
        print(f"ERROR: masih ada DTB non-target/rusak mengandung {bad}:")
        for x in sorted(set(bad_dtb)):
            print("  " + x)
        sys.exit(1)

print("")
print("OK: Makefile sekarang hanya build DTB target SDM632/onclite/onc.")
PY

echo ""
echo "==> Verify remaining DTB entries in Makefile"
grep -nE "\.dtb|\.dtbo" "${QCOM_MAKEFILE}" || true

echo ""
echo "==> Available SDM632 DTS files:"
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
