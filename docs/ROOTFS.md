# Rootfs

The initial rootfs contains only the early runtime contract:

- `/sbin/init -> /sbin/gluon`
- `/sbin/gluon`
- `/etc/gluon.conf`
- `/etc/hostname`
- `/srv/boson`
- Standard early mount points.
- BusyBox applets for rescue and debugging.

The rootfs is assembled by `mkRootfs`. It copies the base tree from
`rootfs/base`, installs Gluon, installs the OTP release under `/srv/boson`, and
adds a small BusyBox shell surface.

The rootfs is not a NixOS closure and does not contain an in-target package
manager.
