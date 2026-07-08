{
  mkImage,
  rootfs,
  kernel,
  target,
  profile,
}:

mkImage {
  name = "boson-qemu-x86_64-image";
  inherit
    rootfs
    kernel
    target
    profile
    ;
}
