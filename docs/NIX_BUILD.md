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
checks.x86_64-linux.qemu-image-build
checks.x86_64-linux.qemu-boot-smoke
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

The QEMU image output is a directory containing:

```text
bzImage
initramfs.cpio.gz
manifest.txt
```

`nix run .#qemu` boots those files directly with headless QEMU TCG. The complete
flake check boots the guest and verifies both Gluon and OTP serial markers.

Release automation is intentionally split:

1. Run `Release` with `version` and `git_ref` to create the GitHub release page.
2. Run `Build Release Image` with `version` and `device_id` to upload the image.
3. Run `E2E` with `version` to download, checksum, and boot the QEMU release.

The flake pins nixpkgs through `flake.lock`. Release builds use that lock and do
not override it with a moving channel.
