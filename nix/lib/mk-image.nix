{
  runCommand,
  coreutils,
  cpio,
  findutils,
  gzip,
}:

{
  name ? "boson-image",
  rootfs,
  kernel,
  target,
  profile,
}:

runCommand name
  {
    nativeBuildInputs = [
      coreutils
      cpio
      findutils
      gzip
    ];
  }
  ''
    mkdir -p "$out"
    install -Dm644 ${kernel}/${target.kernelTarget} "$out/${target.kernelTarget}"

    (
      cd ${rootfs}/rootfs
      find . -print0 \
        | sort -z \
        | cpio --null --create --format=newc --owner=0:0 --reproducible
    ) | gzip -n > "$out/initramfs.cpio.gz"

    cat > "$out/manifest.txt" <<MANIFEST
    format=kernel-initramfs
    target=${target.name or "unknown"}
    profile=${profile.name or "unknown"}
    kernel=${target.kernelTarget}
    initramfs=initramfs.cpio.gz
    MANIFEST
  ''
