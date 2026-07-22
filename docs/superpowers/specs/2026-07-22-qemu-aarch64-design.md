# BosonOS QEMU AArch64 Design

## Goal

BosonOS `v0.0.2` will add a boot-tested generic AArch64 target alongside the
existing x86_64 target. Both release artifacts must boot Linux, run Gluon as
PID 1, and reach the `Boson.Boot online` OTP marker.

This milestone targets QEMU's generic `virt` machine and Apple Silicon UTM. It
does not claim RK3566 hardware support.

## Selected Approach

Each flake system builds a complete native target closure:

| Flake system | Boson target | Kernel | Console | QEMU machine |
| --- | --- | --- | --- | --- |
| `x86_64-linux` | `qemu-x86_64` | `bzImage` | `ttyS0,115200` | `q35` |
| `aarch64-linux` | `qemu-aarch64` | `Image` | `ttyAMA0,115200` | `virt` |

GitHub Actions will build AArch64 on the native `ubuntu-24.04-arm` runner.
This keeps the Linux kernel, static Gluon binary, BusyBox, Erlang runtime, and
Elixir release on one architecture without introducing OTP cross-compilation.

Rejected alternatives:

- Full x86-to-AArch64 cross-compilation adds ERTS release assembly complexity
  without helping the generic QEMU milestone.
- An ARM kernel around an x86_64 userspace would produce an artifact that
  cannot satisfy the BosonOS boot contract.

## Build Graph

The flake will expose the same logical package and app names for both systems:

```text
packages.<system>.gluon
packages.<system>.boson-runtime
packages.<system>.boson-rootfs
packages.<system>.boson-qemu-image
apps.<system>.qemu
checks.<system>.qemu-image-build
checks.<system>.qemu-boot-smoke
```

The target definition owns architecture-specific boot data, including the
kernel filename, QEMU executable, machine, CPU, and kernel command line. Shared
image and runner helpers consume those fields and contain no architecture
branches.

The AArch64 image contains:

```text
Image
initramfs.cpio.gz
manifest.txt
```

## Boot And Runtime Contract

The AArch64 runner uses `qemu-system-aarch64`, `-machine virt,accel=tcg`, and
the PL011 serial console at `ttyAMA0`. It direct-boots the Nix-built kernel and
initramfs with `rdinit=/sbin/gluon`.

Success requires both existing serial markers:

```text
gluon info: starting
Boson.Boot online
```

The PID 1 and OTP supervision contracts do not change. There is no new target
service manager, package manager, Nix runtime, or board-specific logic.

## CI And Release Contract

CI uses a two-entry native runner matrix. Each entry builds its image and runs
the QEMU boot smoke check. Source-level Elixir and Zig tests remain shared
because their behavior is architecture-independent.

`Build Release Image` accepts these device IDs:

```text
qemu-x86_64
qemu-aarch64
```

The workflow selects the matching native runner before building the release
tag. `v0.0.2` publishes these archives and checksum files:

```text
bosonos-qemu-x86_64-v0.0.2.tar.gz
bosonos-qemu-aarch64-v0.0.2.tar.gz
```

`E2E` accepts a device ID, downloads the matching archive, verifies its
checksum and kernel filename, then boots it with the matching QEMU binary and
console settings.

## UTM Contract

The release notes identify AArch64 as the preferred artifact on Apple Silicon.
It can use an AArch64 QEMU VM with the `virt` machine and serial terminal. The
archive remains a direct kernel/initramfs artifact rather than a one-click
`.utm`, ISO, installer, or persistent disk image.

## Verification

Completion requires:

1. Both flake systems evaluate with architecture-correct target metadata.
2. Native x86_64 and AArch64 CI image builds pass.
3. Both native QEMU smoke checks reach the Gluon and OTP markers.
4. Workflow lint and documentation consistency checks pass.
5. The `v0.0.2` release contains both archives and both checksum files.
6. Both released artifacts pass the manual E2E workflow.

