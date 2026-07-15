{ runCommand, closureInfo }:

{
  name ? "boson-rootfs",
  base,
  gluon,
  runtime,
  busybox,
}:

let
  runtimeClosure = closureInfo {
    rootPaths = [ runtime ];
  };
in

runCommand name { } ''
  mkdir -p "$out/rootfs"
  cp -a ${base}/. "$out/rootfs/"
  chmod -R u+w "$out/rootfs"

  mkdir -p \
    "$out/rootfs/bin" \
    "$out/rootfs/sbin" \
    "$out/rootfs/srv" \
    "$out/rootfs/data" \
    "$out/rootfs/proc" \
    "$out/rootfs/sys" \
    "$out/rootfs/dev" \
    "$out/rootfs/run/boson" \
    "$out/rootfs/root" \
    "$out/rootfs/nix/store"

  find "$out/rootfs" -name .gitkeep -delete

  while IFS= read -r store_path; do
    cp -a --parents "$store_path" "$out/rootfs"
  done < ${runtimeClosure}/store-paths

  rm -rf "$out/rootfs/srv/boson"
  ln -s ${runtime} "$out/rootfs/srv/boson"

  install -Dm755 ${gluon}/sbin/gluon "$out/rootfs/sbin/gluon"
  ln -s gluon "$out/rootfs/sbin/init"

  install -Dm755 ${busybox}/bin/busybox "$out/rootfs/bin/busybox"
  for applet in \
    awk basename cat cut date dd dirname dmesg echo grep hostname ls mkdir \
    mount od poweroff ps pwd readlink reboot sed sh sleep sync
  do
    ln -s busybox "$out/rootfs/bin/$applet"
  done

  cat > "$out/manifest.txt" <<MANIFEST
  name=${name}
  init=/sbin/gluon
  runtime=/srv/boson/bin/boson
  MANIFEST
  chmod -R a+rX "$out"
''
