### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers

### AnyKernel setup
# global properties
properties() { '
kernel.string=306kernels for Pixel 4a 5G / 5 / 5a (redbull) - KernelSU-Next, susfs, Droidspaces
do.devicecheck=1
do.modules=0
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
#   boot-files/Image.lz4            -> boot
#   modules/vendor/lib/modules/*.ko -> replaces whatever the ROM keeps in the
#                                      vendor_boot ramdisk and /vendor/lib/modules
# The Droidspaces cgroup/IPC options change struct layouts, so the ROM's own
# modules (built against Lineage's redbull_defconfig) fail their MODVERSIONS
# CRC check against this kernel. Shipping the matching set sidesteps that.
# Needs an ext4 /vendor with verification off, which Lineage/crDroid ship by
# default (vbmeta --flags 3).
#
# Order: pre-flight checks, vendor_boot, boot, /vendor. Anything the zip
# cannot replace, or that would not fit, aborts before a partition is touched.
# do.modules=0 because AK3's own push copies in find order; Lineage's vendor
# image ships with ~2 MB free, so the order and the fit are checked here.

## vendor_boot
BLOCK=vendor_boot;
IS_SLOT_DEVICE=1;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh;

MODSRC=$AKHOME/modules/vendor/lib/modules;
VENDORMODS=/vendor/lib/modules;

# swap_modules <dir> <label>: replace every .ko in <dir> with the one built
# alongside this kernel; abort if the ROM has one the build does not
swap_modules() {
  local ko n=0 missing;
  [ -d "$1" ] || abort "No modules found in $2 ($1). Aborting...";
  for ko in "$1"/*.ko; do
    [ -f "$ko" ] || continue;
    [ -f "$MODSRC/${ko##*/}" ] || missing="$missing ${ko##*/}";
  done;
  if [ "$missing" ]; then
    ui_print " " "$2 has modules this zip cannot replace:";
    for ko in $missing; do ui_print "  $ko"; done;
    abort "They would fail to load against this kernel. Aborting...";
  fi;
  for ko in "$1"/*.ko; do
    [ -f "$ko" ] || continue;
    cp -f "$MODSRC/${ko##*/}" "$ko";
    set_perm 0 0 644 "$ko";
    n=$((n+1));
  done;
  ui_print "$2: $n modules swapped";
}

# push_vendor_modules: overwrite each /vendor module in place (keeps its inode
# and SELinux label), biggest shrink first, so free space only grows until the
# last few files. ext4 holds 2% of the fs (15 MB here) back for metadata, which
# is more than Lineage's vendor image leaves free, so that reservation is
# dropped through sysfs for the duration of the copy.
push_vendor_modules() {
  local d name n=0 slot dev resv saved;
  ui_print " " "Pushing modules to $VENDORMODS...";
  if [ -d /dev/block/mapper ]; then
    for slot in "" _a _b; do
      blockdev --setrw /dev/block/mapper/vendor$slot 2>/dev/null;
    done;
  fi;
  mount -o rw,remount -t auto /vendor || abort "Could not remount /vendor read-write. Aborting...";
  dev=$(readlink -f "$(grep ' /vendor ' /proc/mounts | head -n1 | cut -d' ' -f1)");
  resv=/sys/fs/ext4/${dev##*/}/reserved_clusters;
  if [ -f "$resv" ]; then
    saved=$(cat "$resv");
    echo 0 > "$resv";
  fi;
  while read -r d name; do
    cat "$MODSRC/$name" > "$VENDORMODS/$name" || abort "Writing $name failed; re-flash this zip or the ROM. Aborting...";
    set_perm 0 0 644 "$VENDORMODS/$name";
    n=$((n+1));
  done < $AKHOME/vendor-order.sorted;
  sync;
  [ "$saved" ] && echo "$saved" > "$resv";
  mount -o ro,remount -t auto /vendor;
  ui_print "$VENDORMODS: $n modules swapped";
}

## pre-flight
mount | grep -q ' /vendor type ext4 ' || abort "/vendor is not mounted as ext4; cannot replace its modules. Aborting...";
[ -d $VENDORMODS ] || abort "$VENDORMODS is missing. Aborting...";
missing="";
delta=0;
: > $AKHOME/vendor-order;
for ko in $VENDORMODS/*.ko; do
  [ -f "$ko" ] || continue;
  name=${ko##*/};
  if [ -f "$MODSRC/$name" ]; then
    d=$(( $(wc -c < "$MODSRC/$name") - $(wc -c < "$ko") ));
    delta=$((delta + d));
    echo "$d $name" >> $AKHOME/vendor-order;
  else
    missing="$missing $name";
  fi;
done;
if [ "$missing" ]; then
  ui_print " " "$VENDORMODS has modules this zip cannot replace:";
  for ko in $missing; do ui_print "  $ko"; done;
  abort "They would fail to load against this kernel. Aborting...";
fi;
sort -n $AKHOME/vendor-order > $AKHOME/vendor-order.sorted;
# plan against the raw free space (push_vendor_modules lifts the ext4
# reservation): each in-place write frees the old file first, so the free
# space after every step is what must stay above the margin
free=$(df -Pk /vendor | tail -n1 | awk '{print ($2 - $3) * 1024}');
low=$free;
while read -r d name; do
  free=$((free - d));
  [ $free -lt $low ] && low=$free;
done < $AKHOME/vendor-order.sorted;
echo "/vendor: $((free + delta)) bytes free, modules grow by $delta, lowest point $low" >&2;
if [ $low -lt 524288 ]; then
  abort "Not enough free space on /vendor for the new modules (short by $(( (524288 - low) / 1024 )) KB). Aborting...";
fi;

# hdr v3 vendor_boot has a single ramdisk, which dump_boot unpacks to $RAMDISK
dump_boot;
swap_modules $RAMDISK/lib/modules vendor_boot;
write_boot;
## end vendor_boot install


## boot
BLOCK=boot;
IS_SLOT_DEVICE=1;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

# reset for boot patching
reset_ak;

# boot.img on redbull (hdr v3) is kernel + generic ramdisk; only the kernel changes
split_boot;
flash_boot;
## end boot install


## /vendor
push_vendor_modules;
## end /vendor install

## 306kernels epilogue
# update-binary's ui_printfile is not inherited by this shell
printfile() {
  local line pad;
  (ps; ps -A) 2>/dev/null | grep -q '[z]ygote' || [ -e /twres ] || pad='| ';
  while IFS='' read -r line || [ -n "$line" ]; do ui_print "$pad$line"; done < "$1";
}
ui_print " ";
ui_print "Support me on Ko-Fi!  ko-fi.com/306bobby";
ui_print " ";
printfile "$AKHOME/kofi-qr.txt";
ui_print " ";
