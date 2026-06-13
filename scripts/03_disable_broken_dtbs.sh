#!/usr/bin/env bash
set -euo pipefail

echo "==> Disable broken/non-onclite DTBs"

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
  echo "WARNING: ${QCOM_MAKEFILE} tidak ada, skip."
  exit 0
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

broken_patterns = [
    "apq8053-lite-dragon",

    # Error lama
    "msm8953-pmi8940",
    "apq8053-pmi8940",

    # Error terbaru dari log kamu
    "msm8953-pmi8937",
    "apq8053-pmi8937",
]

print(f"Patch Makefile: {makefile}")

lines = text.splitlines(keepends=True)
new_lines = []

for line in lines:
    original = line

    # Hapus token .dtb yang match pattern rusak
    for name in broken_patterns:
        line = re.sub(r'(?<![\w.-])' + re.escape(name) + r'[\w.-]*\.dtb', '', line)

    # Bersihkan spasi berlebihan
    line = re.sub(r'[ \t]+', ' ', line)

    # Kalau line dtb jadi kosong, buang line-nya
    stripped = line.strip()

    if stripped in ["\\", ""]:
        continue

    if re.match(r'^dtb-[^=]+\+=\s*\\?$', stripped):
        continue

    if re.match(r'^dtb-[^=]+\+=\s*$', stripped):
        continue

    new_lines.append(line)

text = "".join(new_lines)

# Bersihkan backslash kosong / blank line berlebihan
text = re.sub(r'\n\s*\\\s*\n', '\n', text)
text = re.sub(r'\n{3,}', '\n\n', text)

makefile.write_text(text)

for name in broken_patterns:
    if re.search(re.escape(name) + r'[\w.-]*\.dtb', text):
        print(f"ERROR: masih ada broken DTB: {name}")
        sys.exit(1)
    else:
        print(f"OK: {name} sudah tidak ada")
PY

echo "==> Verify broken DTBs removed"

grep -nE "apq8053-lite-dragon|msm8953-pmi8940|apq8053-pmi8940|msm8953-pmi8937|apq8053-pmi8937" "${QCOM_MAKEFILE}" && {
  echo "ERROR: broken DTB masih ada di Makefile"
  exit 1
} || {
  echo "OK: broken DTB sudah bersih"
}

echo "==> Remaining onclite/onc/sdm632 candidates:"
find "${QCOM_DTS_DIR}" -maxdepth 1 -type f \( \
  -iname "*onclite*.dts" -o \
  -iname "*onclite*.dtsi" -o \
  -iname "*sdm632*.dts" -o \
  -iname "*sdm632*.dtsi" -o \
  -iname "*onc*.dts" -o \
  -iname "*onc*.dtsi" \
\) | sort || true

echo "==> Broken DTB disable selesai"
