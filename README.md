# BosonOS

BosonOS is an experimental operating system substrate:

- Nix builds the system artifacts.
- Linux provides the hardware compatibility layer.
- Gluon is the minimal Zig PID 1 process.
- The BEAM runtime owns system supervision and control.
- Targets are modeled as a SoC, board, and profile matrix.
- ROCKNIX is a reference/import source, not the base system.

BosonOS is not NixOS, not a ROCKNIX fork, and not a traditional Linux
distribution.

## Runtime Model

```text
Linux kernel
  ->
/sbin/init -> /sbin/gluon
  ->
Gluon, minimal Zig PID 1
  ->
BEAM / OTP release
  ->
BosonOS runtime supervision tree
```

## Boot-tested QEMU Targets

BosonOS provides boot-tested `qemu-x86_64` and `qemu-aarch64` targets:

| Target | Nix system | Kernel | QEMU machine | Serial console |
| --- | --- | --- | --- | --- |
| `qemu-x86_64` | `x86_64-linux` | `bzImage` | `q35` | `ttyS0,115200` |
| `qemu-aarch64` | `aarch64-linux` | `Image` | `virt` | `ttyAMA0,115200` |

Each image also contains a compressed initramfs and a manifest. The initramfs
boots Gluon as PID 1, and Gluon starts the Boson OTP release.

The runtime closure is copied into the image under `/nix/store`, but the target
contains no Nix executable, NixOS module system, or package manager.

RK3566 targets and board definitions remain structural bring-up scaffolding and
are not hardware boot-verified.

## Build And Run

```bash
nix build .#gluon
nix build .#boson-runtime
nix build .#boson-rootfs
nix build .#boson-qemu-image
nix run .#qemu
nix flake check

# Select an image output explicitly when using a matching Linux builder.
nix build .#packages.x86_64-linux.boson-qemu-image
nix build .#packages.aarch64-linux.boson-qemu-image
```

The flake exposes the same package, app, and check names for `x86_64-linux` and
`aarch64-linux`. `nix run .#qemu` selects the app for the host system and starts
a headless QEMU TCG guest with 1 GiB of memory. The `qemu-boot-smoke` flake
check requires both `gluon info: starting` and `Boson.Boot online` on the serial
console.

Manual releases use three separate workflows: `Release` creates the GitHub
release page, `Build Release Image` builds and uploads the selected `device_id`,
and `E2E` downloads and boots the released `device_id`. The latter two
workflows require both `version` and `device_id`.

## Constraints

The target runtime must not grow into NixOS, systemd, D-Bus, NetworkManager, a
desktop stack, or an in-target package manager. Nix remains the host-side build
system. The target control plane belongs in the OTP supervision tree.
