{
  mkImage,
  rootfs,
  kernel,
  target,
  profile,
}:

mkImage {
  name = "boson-qemu-aarch64-image";
  inherit
    rootfs
    kernel
    target
    profile
    ;
}
