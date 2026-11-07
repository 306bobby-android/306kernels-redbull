# 306kernels-redbull

Kernel for the Pixel 4a 5G (bramble), Pixel 5 (redfin) and Pixel 5a (barbet)
with KernelSU-Next, susfs and Droidspaces support, built by GitHub Actions
into an AnyKernel3 zip.

Branch `17.0` is crDroid's `android_kernel_google_redbull` 17.0 (itself
LineageOS lineage-24.0 plus the KernelSU-Next/susfs/Droidspaces commits).
It is meant for crDroid 17 and LineageOS 24.0 builds of these devices.

## What the zip does

| part | from the zip | why |
| --- | --- | --- |
| `boot` | `Image.lz4` | the kernel |
| `vendor_boot` ramdisk `lib/modules/*.ko` | first-stage modules | built with this kernel |
| `/vendor/lib/modules/*.ko` | all other modules | built with this kernel |

The zip ships one copy of every module the build produces. The installer
runs in this order, and nothing is flashed until the checks pass:

1. Pre-flight: `/vendor` must be mounted ext4, every `.ko` in
   `/vendor/lib/modules` must exist in the zip, and the module swap must fit.
2. `vendor_boot`: every `.ko` the ROM keeps in the ramdisk is replaced in
   place; `modules.load`/`modules.dep` and the DTB are untouched.
3. `boot`: the kernel is swapped, the generic ramdisk is untouched.
4. `/vendor/lib/modules`: each file is overwritten in place (same inode, so
   the SELinux label survives), largest shrink first.

Step 4 needs care. Lineage's vendor image ships with ~2 MB free and the
kernel keeps 2% of any ext4 filesystem (15 MB here) back for metadata, which
no normal write may use, so a naive copy fails with ENOSPC on the first
module. The installer drops that reservation via
`/sys/fs/ext4/<dev>/reserved_clusters` for the duration of the copy and
restores it afterwards; the pre-flight simulates the copy sequence against
the raw free space and aborts if any step would run short.

Checked against the LineageOS 24.0 redfin build of 2026-11-02 by running the
installer in a container against its `boot`, `vendor_boot` and `vendor`
images: the module sets match name for name, `depmod` yields identical
dependency, alias and softdep tables (so the ROM's `modules.*` stay valid),
and all 221 + 329 modules come out byte-identical to the build.

## Flashing

Recovery: `adb sideload 306kernels-redbull-*.zip` (accept the unsigned-zip
prompt in Lineage recovery) or flash from the recovery's file picker.
KernelFlasher also works from a booted system.

Install the KernelSU-Next manager afterwards. For root hiding use the susfs
module from the KernelSU-Next manager's module list (sidex15/susfs4ksu-module).

## Building

`.github/workflows/build.yml` runs on every push to `17.0` and on manual
dispatch (which also publishes a release). It uses the same clang as
LineageOS 24.0 (`clang-r596125`), `LLVM=1 LLVM_IAS=1`, `redbull_defconfig`,
and `LOCALVERSION=-306kernels`.

Locally:

```sh
CLANG_BIN=/path/to/clang-r596125/bin .github/ci/build.sh . out stage
.github/ci/package.sh stage 306kernels-redbull.zip
```
