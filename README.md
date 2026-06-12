# ReSukiSU / SUSFS build kit for Redmi 7 onclite / onc kernel 4.9

This kit was generated from the uploaded `boot.img`:

- Linux kernel: `4.9.337-Chidori-Kernel`
- Device family: Xiaomi Redmi 7 / Redmi Y3 (`onclite` / `onc`), Qualcomm msm8953/sdm632 family
- Boot image: Android boot header v1, no ramdisk
- Original boot.img SHA256: `6fa03f4c0adbe08af8a6dd465e68ded53863a3eb7d023e51c4d484f5fb572700`

Important limitation: this kit cannot magically compile from `boot.img` alone. You still need a bootable kernel source tree matching your ROM. The workflow defaults to a public onclite kernel source, but the safest source is the exact kernel source used by your ROM maintainer.

## What this kit does

1. Clones a kernel source repository.
2. Imports the config extracted from your `boot.img` as a fallback defconfig.
3. Integrates ReSukiSU using its setup script.
4. Enables relevant config flags for non-GKI 4.9.
5. Optionally tries SUSFS 4.9 patch application.
6. Builds `Image.gz-dtb` / `Image.gz`.
7. Packages an AnyKernel3 flashable zip for onclite/onc.

## Fastest way: GitHub Actions

1. Create a new GitHub repository.
2. Upload the entire contents of this folder.
3. Go to **Actions > Build ReSukiSU onclite kernel > Run workflow**.
4. Use default values first.
5. Download the generated artifact zip.

Default workflow inputs:

```text
source_repo=https://github.com/onclite/android_kernel_xiaomi_onc.git
source_branch=
defconfig=onclite_defconfig
use_susfs=false
```

If `onclite_defconfig` does not exist in your chosen source, leave it blank or use `chatgpt_boot4_defconfig`, which is generated from your boot image config.

## Local build on Linux

```bash
sudo apt update
sudo apt install -y git curl build-essential bc bison flex libssl-dev libelf-dev zip unzip python3 clang lld llvm gcc-aarch64-linux-gnu gcc-arm-linux-gnueabi
bash scripts/01_fetch_sources.sh
bash scripts/02_prepare_defconfig.sh
bash scripts/03_integrate_resukisu.sh
bash scripts/04_enable_configs.sh
# Optional, can fail on many 4.9 trees:
USE_SUSFS=1 bash scripts/05_try_susfs.sh
bash scripts/06_build_kernel.sh
bash scripts/07_pack_anykernel.sh
```

Output should be in `out/` and `dist/`.

## Flashing

Flash only if you have a backup and know how to recover bootloop.

```bash
fastboot flash boot AnyKernel3 zip is NOT flashed with fastboot
```

AnyKernel3 zip must be flashed from recovery or a kernel flasher app. If you want a raw `boot.img`, use Magisk's `magiskboot` method to replace the `kernel` in your original `boot.img` with the built `Image.gz-dtb`.

