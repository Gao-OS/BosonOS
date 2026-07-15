# Rootfs

The initial rootfs contains only the early runtime contract:

- `/sbin/init -> /sbin/gluon`
- `/sbin/gluon`
- `/etc/gluon.conf`
- `/etc/hostname`
- `/srv/boson -> /nix/store/...-boson-runtime-...`
- The runtime's transitive store closure under `/nix/store`.
- Standard early mount points.
- A static BusyBox and applets for release startup, rescue, and debugging.

The rootfs is assembled by `mkRootfs`. It copies the base tree from
`rootfs/base`, installs Gluon and BusyBox, copies the Nix store paths required by
the OTP release, and links `/srv/boson` to that copied release path.

The QEMU image packs this tree as a reproducible `newc` initramfs compressed
with deterministic gzip settings. The target has store paths because Nix built
the release, but it has no Nix command, NixOS runtime, or in-target package
manager.
