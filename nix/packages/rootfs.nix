{
  mkRootfs,
  gluon,
  runtime,
  busybox,
}:

mkRootfs {
  name = "boson-rootfs";
  base = ../../rootfs/base;
  inherit
    gluon
    runtime
    busybox
    ;
}
