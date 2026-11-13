#!/bin/bash
# Build the redbull kernel the way vendor/lineage/build/tasks/kernel.mk does
# (LLVM=1 LLVM_IAS=1, redbull_defconfig, LTO/CFI as configured), then stage
# Image.lz4 and the stripped in-tree modules for packaging.
#
# usage: build.sh <kernel-tree> <out-dir> <stage-dir>
# env:   CLANG_BIN (required) - path to the AOSP clang bin dir
#        LOCALVERSION         - version suffix, default -306kernels
#        KERNEL_LTO           - full (defconfig, default) or thin
set -euo pipefail
TREE=$(realpath "$1"); OUT=$(realpath -m "$2"); STAGE=$(realpath -m "$3")
: "${CLANG_BIN:?set CLANG_BIN to the clang bin dir}"
export PATH="$CLANG_BIN:$PATH"
# LOCALVERSION must be *set* (even if empty) or setlocalversion appends "+"
# whenever HEAD is not an annotated tag.
export LOCALVERSION="${LOCALVERSION--306kernels}"
export KBUILD_BUILD_USER=306kernels KBUILD_BUILD_HOST=github
MK=(make -C "$TREE" O="$OUT" ARCH=arm64 LLVM=1 LLVM_IAS=1 -j"$(nproc)")

"${MK[@]}" redbull_defconfig
# Full LTO is what the defconfig and the ROM builds use; its single ld.lld
# link needs ~10 GB, so the workflow adds swap. Same knob vendor/lineage's
# kernel.mk exposes as KERNEL_LTO; codegen only, no ABI change.
if [ "${KERNEL_LTO:-full}" = thin ]; then
  "$TREE/scripts/config" --file "$OUT/.config" -e THINLTO
  "${MK[@]}" olddefconfig
fi
"${MK[@]}" Image.lz4 modules
rm -rf "$STAGE"; mkdir -p "$STAGE"
"${MK[@]}" INSTALL_MOD_PATH="$STAGE/mod" INSTALL_MOD_STRIP=1 modules_install >/dev/null
cp "$OUT/arch/arm64/boot/Image.lz4" "$STAGE/"
find "$STAGE/mod" -name '*.ko' -exec mv -t "$STAGE/" {} +
rm -rf "$STAGE/mod"
sed -n 's/^#define UTS_RELEASE "\(.*\)"/\1/p' "$OUT/include/generated/utsrelease.h" | tee "$STAGE/version.txt"
ls "$STAGE"/*.ko | wc -l
