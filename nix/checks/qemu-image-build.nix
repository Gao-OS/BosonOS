{ runCommand, image, target }:

runCommand "boson-qemu-image-contract" { } ''
  test -s ${image}/${target.kernelTarget}
  test -s ${image}/initramfs.cpio.gz
  grep -qx 'format=kernel-initramfs' ${image}/manifest.txt

  touch "$out"
''
