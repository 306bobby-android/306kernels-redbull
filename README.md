# 306kernels-redbull

Kernel for the Pixel 4a 5G (bramble), Pixel 5 (redfin) and Pixel 5a (barbet)
with KernelSU-Next, susfs and Droidspaces support, built by GitHub Actions
into an AnyKernel3 zip.

Branch `17.0` is crDroid's `android_kernel_google_redbull` 17.0 (itself
LineageOS lineage-24.0 plus the KernelSU-Next/susfs/Droidspaces commits).
It is meant for crDroid 17 and LineageOS 24.0 builds of these devices, as well as derivatives .

## What the zip does

| part | from the zip | why |
| --- | --- | --- |
| `boot` | `Image.lz4` | the kernel |
| `vendor_boot` ramdisk `lib/modules/*.ko` | first-stage modules | built with this kernel |
| `/vendor/lib/modules/*.ko` | all other modules | built with this kernel |

The zip ships one copy of every module the build produces. This ensures no kernel vermagic issues or ABI instability with modules built in the vanilla ROM


## Flashing

Recovery: `adb sideload 306kernels-redbull-*.zip` (accept the unsigned-zip
prompt in Lineage recovery) or flash from the recovery's file picker.
KernelFlasher also works from a booted system.

Install the KernelSU-Next manager afterwards. The kernel side is sidex15's
`legacy-susfs-v2` tree (v3.4.0-legacy, UAPI 4), so use the **v3.4.0** manager
release; v3.4.1+ speak UAPI 5/6 and ksud will refuse to talk to this kernel.
For root hiding use the susfs module (sidex15/susfs4ksu-module).

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
