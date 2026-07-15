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

## Bootable Target

`qemu-x86_64` is the first bootable BosonOS target. Its image contains a
nixpkgs Linux `bzImage`, a compressed initramfs, and a manifest. The initramfs
boots Gluon as PID 1, and Gluon starts the Boson OTP release.

The runtime closure is copied into the image under `/nix/store`, but the target
contains no Nix executable, NixOS module system, or package manager.

RK3566 targets and board definitions remain structural bring-up scaffolding.

## Build And Run

```bash
nix build .#gluon
nix build .#boson-runtime
nix build .#boson-rootfs
nix build .#boson-qemu-image
nix run .#qemu
nix flake check
```

`nix run .#qemu` starts a headless QEMU TCG guest with 1 GiB of memory. The
`qemu-boot-smoke` flake check requires both `gluon info: starting` and
`Boson.Boot online` on the serial console.

Manual releases use three separate workflows: `Release` creates the GitHub
release page, `Build Release Image` builds and uploads a selected device image,
and `E2E` downloads and boots the released QEMU artifact.

## Constraints

The target runtime must not grow into NixOS, systemd, D-Bus, NetworkManager, a
desktop stack, or an in-target package manager. Nix remains the host-side build
system. The target control plane belongs in the OTP supervision tree.
