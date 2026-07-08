{ lib, runCommand }:

{
  target,
  profile,
  kernel,
  gluon,
  runtime,
  rootfs,
  image,
  qemu ? null,
}:

runCommand "boson-system-${target.name or "unknown"}" { } ''
  mkdir -p "$out"
  cat > "$out/manifest.txt" <<MANIFEST
  type=boson-system
  target=${target.name or "unknown"}
  profile=${profile.name or "unknown"}
  kernel=${kernel}
  gluon=${gluon}
  runtime=${runtime}
  rootfs=${rootfs}
  image=${image}
  MANIFEST
''
// {
  passthru = {
    type = "boson-system";

    inherit
      target
      profile
      kernel
      gluon
      runtime
      rootfs
      image
      ;

    qemu = qemu;

    packages = {
      inherit
        kernel
        gluon
        runtime
        rootfs
        image
        ;
    };
  };

  meta = {
    description = "Composed BosonOS target closure";
    targetName = target.name or "unknown";
    profileName = profile.name or "unknown";
  };
}
