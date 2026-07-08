{ runCommand }:

{
  name ? "boson-boot-partition",
  extlinux,
}:

runCommand name { } ''
  mkdir -p "$out/boot/extlinux"
  cp ${extlinux} "$out/boot/extlinux/extlinux.conf"
''
