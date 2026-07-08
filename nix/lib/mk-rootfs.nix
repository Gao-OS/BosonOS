{ runCommand, lib }:

{
  name ? "boson-rootfs",
  base,
  gluon,
  runtime,
  busybox,
}:

runCommand name { } ''
  mkdir -p "$out/rootfs"
  cp -a ${base}/. "$out/rootfs/"
  chmod -R u+w "$out/rootfs"

  mkdir -p \
    "$out/rootfs/bin" \
    "$out/rootfs/sbin" \
    "$out/rootfs/srv/boson" \
    "$out/rootfs/data" \
    "$out/rootfs/proc" \
    "$out/rootfs/sys" \
    "$out/rootfs/dev" \
    "$out/rootfs/run"

  find "$out/rootfs" -name .gitkeep -delete

  cp -a ${runtime}/. "$out/rootfs/srv/boson/"
  install -Dm755 ${gluon}/sbin/gluon "$out/rootfs/sbin/gluon"
  ln -s gluon "$out/rootfs/sbin/init"

  for applet in sh mount mkdir cat echo hostname dmesg reboot poweroff; do
    ln -s ${busybox}/bin/busybox "$out/rootfs/bin/$applet"
  done

  cat > "$out/manifest.txt" <<MANIFEST
  name=${name}
  init=/sbin/gluon
  runtime=/srv/boson/bin/boson
  MANIFEST
  chmod -R a+rX "$out"
''
