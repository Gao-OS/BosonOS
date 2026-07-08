# System Model

BosonOS is Nix-built, Linux-hosted, and BEAM-first.

Nix builds artifacts on the host:

- Gluon.
- The OTP runtime release.
- Kernel packages.
- Root filesystems.
- Boot partitions.
- Images.
- QEMU runners.
- Checks.

The target OS is not a NixOS system. It does not evaluate Nix modules at
runtime and does not use `nixosConfigurations` as the target model.

Linux provides the hardware compatibility layer. Gluon is PID 1. The BEAM
runtime owns the system control plane through OTP supervision.
