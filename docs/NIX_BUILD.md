# Nix Build

Nix is the host-side build system for BosonOS.

The flake supports `x86_64-linux` and `aarch64-linux`. Both systems expose the
same logical output names, represented below by `<system>`:

```text
packages.<system>.gluon
packages.<system>.boson-runtime
packages.<system>.boson-rootfs
packages.<system>.boson-qemu-image
apps.<system>.qemu
checks.<system>.gluon-build
checks.<system>.runtime-build
checks.<system>.rootfs-build
checks.<system>.qemu-image-build
checks.<system>.qemu-boot-smoke
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

The shorthand commands select the current host system. Use fully qualified
attributes to select an image architecture explicitly on a matching Linux
builder:

```bash
nix build .#packages.x86_64-linux.boson-qemu-image
nix build .#packages.aarch64-linux.boson-qemu-image
```

The QEMU image output is a directory containing the target kernel plus the same
initramfs and manifest:

| Target | Kernel | Other files |
| --- | --- | --- |
| `qemu-x86_64` | `bzImage` | `initramfs.cpio.gz`, `manifest.txt` |
| `qemu-aarch64` | `Image` | `initramfs.cpio.gz`, `manifest.txt` |

`nix run .#qemu` boots the files for the host system directly with headless QEMU
TCG. The flake check boots the guest for each checked system and verifies both
Gluon and OTP serial markers.

Release automation is intentionally split:

1. Run `Release` with `version` and `git_ref` to create the GitHub release page.
2. Run `Build Release Image` with `version` and `device_id` to upload the image.
3. Run `E2E` with `version` and `device_id` to download, checksum, and boot the
   selected QEMU release.

The flake pins nixpkgs through `flake.lock`. Release builds use that lock and do
not override it with a moving channel.
