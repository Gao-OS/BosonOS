{ runCommand, rootfs, runtime }:

runCommand "boson-rootfs-contract" { } ''
  test "$(readlink ${rootfs}/rootfs/sbin/init)" = "gluon"
  test -x ${rootfs}/rootfs/sbin/gluon
  test -x ${rootfs}/rootfs/bin/busybox
  test "$(readlink ${rootfs}/rootfs/bin/sh)" = "busybox"
  test "$(readlink ${rootfs}/rootfs/srv/boson)" = "${runtime}"
  test -e ${rootfs}/rootfs${runtime}/bin/boson
  grep -qx 'release_command=start' ${rootfs}/rootfs/etc/gluon.conf

  touch "$out"
''
