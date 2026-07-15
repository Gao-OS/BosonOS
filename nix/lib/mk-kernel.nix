{ runCommand }:

{
  name ? "boson-kernel",
  target,
  kernelPackage,
  version ? kernelPackage.version,
}:

runCommand name { } ''
  install -Dm644 \
    ${kernelPackage}/${target.kernelTarget} \
    "$out/${target.kernelTarget}"

  cat > "$out/manifest.txt" <<MANIFEST
  type=boson-kernel
  target=${target.name or "unknown"}
  version=${version}
  kernel=${target.kernelTarget}
  MANIFEST
''
