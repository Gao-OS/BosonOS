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

## Initial Commands

```bash
nix build .#gluon
nix build .#boson-runtime
nix build .#boson-rootfs
nix build .#boson-qemu-image
nix run .#qemu
nix flake check
```

The first milestone prioritizes a clean repository skeleton and build graph.
QEMU kernel boot and RK3566 images are intentionally marked as TODO stubs.

## Constraints

The target runtime must not grow into NixOS, systemd, D-Bus, NetworkManager, a
desktop stack, or an in-target package manager. Nix remains the host-side build
system. The target control plane belongs in the OTP supervision tree.
