#!/usr/bin/env bash
set -euo pipefail

echo "==> Pack AnyKernel3 zip"

ROOT_DIR="$(pwd)"
DIST_DIR="${ROOT_DIR}/dist"
AK_DIR="${ROOT_DIR}/AnyKernel3_work"

mkdir -p "${DIST_DIR}"

if [ ! -f "${DIST_DIR}/Image.gz-dtb" ]; then
  echo "ERROR: dist/Image.gz-dtb tidak ditemukan."
  ls -la "${DIST_DIR}" || true
  exit 1
fi

rm -rf "${AK_DIR}"

if [ -d "${ROOT_DIR}/anykernel_template" ]; then
  echo "Pakai anykernel_template lokal"
  cp -a "${ROOT_DIR}/anykernel_template" "${AK_DIR}"
else
  echo "Clone AnyKernel3 template"
  git clone --depth=1 https://github.com/osm0sis/AnyKernel3.git "${AK_DIR}"
  rm -rf "${AK_DIR}/.git" "${AK_DIR}/.github"
fi

cp "${DIST_DIR}/Image.gz-dtb" "${AK_DIR}/Image.gz-dtb"

cd "${AK_DIR}"

if [ -f "anykernel.sh" ]; then
  sed -i 's/^kernel\.string=.*/kernel.string=ReSukiSU-only onclite 4.9/' anykernel.sh || true
  sed -i 's/^do.devicecheck=.*/do.devicecheck=0/' anykernel.sh || true
  sed -i 's/^do.modules=.*/do.modules=0/' anykernel.sh || true
  sed -i 's/^do.systemless=.*/do.systemless=0/' anykernel.sh || true
fi

ZIP_NAME="ReSukiSU-onclite-4.9-AnyKernel3.zip"

zip -r9 "${DIST_DIR}/${ZIP_NAME}" . -x "*.git*" "README.md" "LICENSE" ".github/*"

echo "==> AnyKernel zip selesai:"
ls -lh "${DIST_DIR}/${ZIP_NAME}"
