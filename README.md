# ReSukiSU / SUSFS build kit for Redmi 7 onclite / onc kernel 4.9

This kit was generated from crDroidAndroid-11.0-20240630-onclite-v7.39 `boot.img`:

- ROM sources: `https://xdaforums.com/t/crdroid-a11-7-39-onclite-signed.4679122/`
- Linux kernel: `4.9.337-Chidori-Kernel`
- Device family: Xiaomi Redmi 7 / Redmi Y3 (`onclite` / `onc`), Qualcomm msm8953/sdm632 family
- Boot image: Android boot header v1, no ramdisk
- Original boot.img SHA256: `6fa03f4c0adbe08af8a6dd465e68ded53863a3eb7d023e51c4d484f5fb572700`

Important limitation: this kit cannot magically compile from `boot.img` alone. You still need a bootable kernel source tree matching your ROM. The workflow defaults to a public onclite kernel source, but the safest source is the exact kernel source used by your ROM maintainer.

## What this kit does

1. Clones a kernel source repository.
2. Imports the config extracted from crDroidAndroid-11.0-20240630-onclite-v7.39 `boot.img` as a fallback defconfig.
3. Integrates ReSukiSU using its setup script.
4. Enables relevant config flags for non-GKI 4.9.
5. Optionally tries SUSFS 4.9 patch application.
6. Builds `Image.gz-dtb` / `Image.gz`.
7. Packages an AnyKernel3 flashable zip for onclite/onc/Redmi 7/ Redmi Y3


## Flashing

Before flashing, make sure you have backed up your `boot.img` in recovery such as Orange Fox or TWRP.

**HOW TO FLASH:**
```bash
fastboot flash boot boot.img
```

