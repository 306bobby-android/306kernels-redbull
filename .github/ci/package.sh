#!/bin/bash
# Assemble the AnyKernel3 zip from a build.sh stage dir.
# usage: package.sh <stage-dir> <out-zip>
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
STAGE=$(realpath "$1"); ZIP=$(realpath -m "$2")
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cp -r "$HERE/ak3/." "$WORK/"
# explicit multi-partition layout: anykernel.sh patches vendor_boot before boot
mkdir -p "$WORK/boot-files" "$WORK/modules/vendor/lib/modules"
cp "$STAGE/Image.lz4" "$WORK/boot-files/"
cp "$STAGE"/*.ko "$WORK/modules/vendor/lib/modules/"
cp "$STAGE/version.txt" "$WORK/version"
cd "$WORK" && rm -f "$ZIP" && zip -qr9 "$ZIP" . -x '.git*' 'README.md'
ls -la "$ZIP"
