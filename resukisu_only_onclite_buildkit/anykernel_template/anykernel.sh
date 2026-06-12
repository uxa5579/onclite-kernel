# AnyKernel3 Ramdisk Mod Script
# osm0sis @ xda-developers

properties() { '
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=onclite
device.name2=onc
device.name3=Redmi 7
device.name4=Redmi Y3
supported.versions=10 - 16
supported.patchlevels=
'; }

block=/dev/block/bootdevice/by-name/boot;
is_slot_device=0;
ramdisk_compression=auto;
patch_vbmeta_flag=auto;

. tools/ak3-core.sh;

dump_boot;
write_boot;
