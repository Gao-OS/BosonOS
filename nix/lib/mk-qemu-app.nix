{ writeShellApplication }:

{
  image,
  target,
}:

writeShellApplication {
  name = "boson-qemu";
  text = ''
    echo "BosonOS QEMU runner"
    echo "target: ${target.name or "qemu-x86_64"}"
    echo "image: ${image}"
    echo
    echo "TODO: wire kernel/initrd boot once the kernel package is real."
    echo "The first milestone provides a buildable rootfs image artifact."
  '';
}
