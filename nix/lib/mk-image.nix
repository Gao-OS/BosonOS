{ runCommand, gnutar, gzip }:

{
  name ? "boson-image",
  rootfs,
  kernel ? null,
  target,
  profile,
}:

runCommand name { nativeBuildInputs = [ gnutar gzip ]; } ''
  mkdir -p "$out"

  tar --sort=name --mtime='UTC 1970-01-01' --owner=0 --group=0 --numeric-owner \
    -C ${rootfs}/rootfs \
    -cpf "$out/rootfs.tar" .
  gzip -n -c "$out/rootfs.tar" > "$out/rootfs.tar.gz"

  cat > "$out/README" <<README
  BosonOS image artifact

  Target: ${target.name or "unknown"}
  Profile: ${profile.name or "unknown"}

  This is a first-milestone QEMU image artifact containing a rootfs tarball.
  Kernel/initrd boot wiring is intentionally left as a TODO until Gluon and
  target kernel packaging are hardened.
  README
''
