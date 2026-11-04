#!/bin/bash
# Assemble the AnyKernel3 zip from a build.sh stage dir.
# usage: package.sh <stage-dir> <out-zip>
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
STAGE=$(realpath "$1"); ZIP=$(realpath -m "$2")
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cp -r "$HERE/ak3/." "$WORK/"
cp "$STAGE/Image.lz4" "$WORK/"
mkdir -p "$WORK/modules/vendor/lib/modules" "$WORK/vendor_ramdisk/lib/modules"
cp "$STAGE"/*.ko "$WORK/modules/vendor/lib/modules/"
missing=0
for m in $(cat "$HERE/vendor_boot_modules.txt"); do
  if [ -f "$STAGE/$m" ]; then cp "$STAGE/$m" "$WORK/vendor_ramdisk/lib/modules/"; else echo "first-stage module not built: $m" >&2; missing=$((missing+1)); fi
done
# heatmap/touch_offload are the only two not in every build; anything else
# missing means the module set drifted from device/google/redbull.
[ "$missing" -le 2 ] || { echo "too many first-stage modules missing ($missing)" >&2; exit 1; }
cp "$STAGE/version.txt" "$WORK/version"
cd "$WORK" && rm -f "$ZIP" && zip -qr9 "$ZIP" . -x '.git*' 'README.md'
ls -la "$ZIP"
