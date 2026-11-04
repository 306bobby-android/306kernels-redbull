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

The ROM's own modules cannot be reused: the Droidspaces cgroup/IPC options
(`FAIR_GROUP_SCHED`, `CGROUP_DEVICE`, `CGROUP_PIDS`, `POSIX_MQUEUE`, ...)
change core struct layouts, so the MODVERSIONS CRCs of ~80% of exported
symbols differ from a stock Lineage build. Shipping the matching module set
is what keeps Wi-Fi, touch, audio and the rest working.

Because `/vendor` is written, the ROM must have AVB verification disabled
(`vbmeta --flags 3`), which stock LineageOS and crDroid builds do, and `/vendor`
must be ext4. After any ROM update, flash the zip again: the OTA restores the
stock kernel and modules together.

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
