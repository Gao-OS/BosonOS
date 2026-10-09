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
and the Boson runtime services. Each required component reports ready after
initialization; `Boson.Boot` monitors the full set and publishes readiness only
when all five are online.

The smoke check for each QEMU architecture proves the chain by requiring these
serial markers:

```text
gluon info: starting
Boson.Runtime ready
```

The normal smoke check observes ten stable seconds after readiness and rejects
component-unavailable, Gluon-error, and kernel-panic markers.

Machine actions follow the same ownership boundary:

```text
Boson.Boot.request_action(:reboot | :poweroff)
  -> atomic /run/boson/action file
  -> clean release exit
  -> Gluon consumes and removes the file
  -> reboot or poweroff
```

Gluon discards stale actions before launching the release. A runtime crash
selects `on_crash` even if an action was written. The private lifecycle smoke
image requests poweroff after readiness and verifies ordered markers followed
by a normal QEMU exit; published images do not request an automatic action.

RK3566 bootloader and image support remains structural and is not hardware
boot-verified.
