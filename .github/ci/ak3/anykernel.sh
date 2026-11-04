### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers

### AnyKernel setup
# global properties
properties() { '
kernel.string=306kernels for Pixel 4a 5G / 5 / 5a (redbull) - KernelSU-Next, susfs, Droidspaces
do.devicecheck=1
do.modules=1
do.systemless=0
do.cleanup=1
do.cleanuponabort=0
device.name1=bramble
device.name2=redfin
device.name3=barbet
device.name4=
device.name5=
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties


### AnyKernel install
# The zip carries the kernel *and* every module built with it:
#   Image.lz4                       -> boot
#   vendor_ramdisk/lib/modules/*.ko -> vendor_boot ramdisk (first-stage modules)
#   modules/vendor/lib/modules/*.ko -> /vendor/lib/modules (do.modules=1)
# The Droidspaces cgroup/IPC options change struct layouts, so the ROM's own
# modules (built against Lineage's redbull_defconfig) fail their MODVERSIONS
# CRC check against this kernel. Shipping the matching set sidesteps that.
# Needs an ext4 /vendor with verification off, which Lineage/crDroid ship by
# default (vbmeta --flags 3).

## boot
BLOCK=boot;
IS_SLOT_DEVICE=1;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh;

# boot.img on redbull (hdr v3) is kernel + generic ramdisk; only the kernel changes
split_boot;
flash_boot;
## end boot install


## vendor_boot
vendor_boot_attributes() {
set_perm_recursive 0 0 755 644 $VENDORRD/lib/modules;
} # end attributes

BLOCK=vendor_boot;
IS_SLOT_DEVICE=1;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

# reset for vendor_boot patching
reset_ak;

# unpack the vendor ramdisk so the first-stage modules can be swapped in place
dump_boot;
write_boot;
## end vendor_boot install

## 306kernels epilogue
ui_print " ";
ui_print "Support me on Ko-Fi!  ko-fi.com/306bobby";
ui_print " ";
ui_printfile "$AKHOME/kofi-qr.txt";
ui_print " ";
