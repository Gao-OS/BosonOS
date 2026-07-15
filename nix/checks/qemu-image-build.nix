{ runCommand, image }:

runCommand "boson-qemu-image-contract" { } ''
  test -s ${image}/bzImage
  test -s ${image}/initramfs.cpio.gz
  grep -qx 'format=kernel-initramfs' ${image}/manifest.txt

  touch "$out"
''
