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

`Boson.Boot` coordinates required-component readiness, monitors health, and
accepts one-shot reboot or poweroff requests. The BEAM runtime writes the
atomic `/run/boson/action` handoff and exits cleanly; Gluon consumes that
bounded request and performs the machine operation. A runtime crash always
selects Gluon's configured crash policy.

Bus, Device, Net, Console, and Update participate in the lifecycle contract but
remain stubs for their control-bus, hardware, network, console, and update
services. Persistent `/data`, OTA, real device services, and RK3566 hardware
boot remain outside this milestone.
