### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers
# 本文件由 kernel-raphael-ci 在构建时覆盖到 AnyKernel3 仓库；@KERNEL_STRING@ 会被 CI 替换。
# 设计要点：
#   * Evolution-X cnb 的 BOARD_KERNEL_IMAGE_NAME 是未压缩的 Image（不是 Image.gz-dtb）
#   * 只刷 boot 分区：dtb 在 boot 头里沿用 ROM 自带的，dtbo 分区也不碰（ROM 的 dtbo 与 dts 同源）
#   * do.modules=1：CI 把本次编译的 .ko 打到 modules/vendor/lib/modules，刷机时覆盖 /vendor/lib/modules，
#     这样模块 vermagic 与本次内核严格一致（否则 CONFIG_MODULE_SIG_FORCE / vermagic 校验会让模块加载失败）

### AnyKernel setup
# global properties
properties() { '
kernel.string=@KERNEL_STRING@
do.devicecheck=1
do.modules=1
do.systemless=0
do.cleanup=1
do.cleanuponabort=1
device.name1=raphael
device.name2=raphaelin
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties

## boot shell variables
BLOCK=/dev/block/bootdevice/by-name/boot;
IS_SLOT_DEVICE=0;
RAMDISK_COMPRESSION=auto;
NO_BLOCK_DISPLAY=1
PATCH_VBMETA_FLAG=auto;

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh;

## AnyKernel install
split_boot;
flash_boot;
## end install
