# Boot Chain

BosonOS boots through a small, explicit chain:

```text
bootloader -> Linux kernel -> /sbin/init -> Gluon -> BEAM runtime -> Boson supervision tree
```

On hardware, the bootloader loads the Linux kernel and target device tree. The
QEMU target currently boots its `bzImage` and `initramfs.cpio.gz` directly. In
both cases, the kernel starts `/sbin/init`, which is a symlink to
`/sbin/gluon`.

Gluon mounts the kernel filesystems, configures hostname and console stdio, and
runs `/srv/boson/bin/boson start`. The release then starts `Boson.Supervisor`
and the Boson runtime services.

The QEMU smoke check proves the chain by requiring these serial markers:

```text
gluon info: starting
Boson.Boot online
```

RK3566 bootloader and image support is not boot-verified yet.
