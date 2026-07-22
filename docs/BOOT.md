# Boot Chain

BosonOS boots through a small, explicit chain:

```text
bootloader -> Linux kernel -> /sbin/init -> Gluon -> BEAM runtime -> Boson supervision tree
```

On hardware, the bootloader loads the Linux kernel and target device tree. The
boot-tested QEMU targets load their kernels and `initramfs.cpio.gz` directly:

| Target | Kernel | QEMU executable | Machine | Serial console |
| --- | --- | --- | --- | --- |
| `qemu-x86_64` | `bzImage` | `qemu-system-x86_64` | `q35` | `ttyS0,115200` |
| `qemu-aarch64` | `Image` | `qemu-system-aarch64` | `virt` | `ttyAMA0,115200` |

In both paths, the kernel starts `/sbin/init`, which is a symlink to
`/sbin/gluon`.

Gluon mounts the kernel filesystems, configures hostname and console stdio, and
runs `/srv/boson/bin/boson start`. The release then starts `Boson.Supervisor`
and the Boson runtime services.

The smoke check for each QEMU architecture proves the chain by requiring these
serial markers:

```text
gluon info: starting
Boson.Boot online
```

RK3566 bootloader and image support remains structural and is not hardware
boot-verified.
