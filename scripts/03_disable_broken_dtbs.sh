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

makefile = Path("arch/arm64/boot/dts/qcom/Makefile")

if not makefile.exists():
    makefile = Path("kernel/arch/arm64/boot/dts/qcom/Makefile")

if not makefile.exists():
    found = list(Path(".").glob("*/arch/arm64/boot/dts/qcom/Makefile"))
    if found:
        makefile = found[0]

if not makefile.exists():
    raise SystemExit("ERROR: qcom Makefile tidak ditemukan")

text = makefile.read_text(errors="ignore")

broken_patterns = [
    r"apq8053-lite-dragon[^ \t\n\\]*\.dtb",
    r"msm8953-pmi8940[^ \t\n\\]*\.dtb",
    r"apq8053-pmi8940[^ \t\n\\]*\.dtb",
]

before = text

for pat in broken_patterns:
    text = re.sub(r"[ \t]*" + pat, "", text)

# Bersihkan line continuation kosong/aneh
text = re.sub(r"\\\n[ \t]*\\", r"\\", text)
text = re.sub(r"\n[ \t]*\n[ \t]*\n+", "\n\n", text)

makefile.write_text(text)

print(f"Patched: {makefile}")

for name in [
    "apq8053-lite-dragon",
    "msm8953-pmi8940",
    "apq8053-pmi8940",
]:
    if name in text:
        print(f"WARNING: masih ada {name}")
    else:
        print(f"OK: {name} sudah tidak ada")
PY

echo "==> Verify broken DTBs removed"
grep -nE "apq8053-lite-dragon|msm8953-pmi8940|apq8053-pmi8940" "${QCOM_MAKEFILE}" && {
  echo "ERROR: broken DTB masih ada di Makefile"
  exit 1
} || {
  echo "OK: broken DTB sudah bersih"
}

echo "==> Broken DTB disable selesai"
