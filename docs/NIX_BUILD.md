# Nix Build

Nix is the host-side build system for BosonOS.

Initial flake outputs:

```text
packages.x86_64-linux.gluon
packages.x86_64-linux.boson-runtime
packages.x86_64-linux.boson-rootfs
packages.x86_64-linux.boson-qemu-image
apps.x86_64-linux.qemu
checks.x86_64-linux.gluon-build
checks.x86_64-linux.runtime-build
checks.x86_64-linux.rootfs-build
```

Useful commands:

```bash
nix build .#gluon
nix build .#boson-runtime
nix build .#boson-rootfs
nix build .#boson-qemu-image
nix run .#qemu
nix flake check
```

The QEMU image currently produces a rootfs tarball artifact. Real kernel and
initrd boot wiring is a later milestone.
