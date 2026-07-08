# Boot Chain

BosonOS boots through a small, explicit chain:

```text
bootloader -> Linux kernel -> /sbin/init -> Gluon -> BEAM runtime -> Boson supervision tree
```

The bootloader loads the Linux kernel and target device tree. The kernel mounts
the initial root filesystem and starts `/sbin/init`, which is a symlink to
`/sbin/gluon`.

Gluon performs PID 1 setup and starts the BosonOS OTP release from
`/srv/boson/bin/boson`. After the release starts, responsibility moves to the
BEAM supervision tree.
