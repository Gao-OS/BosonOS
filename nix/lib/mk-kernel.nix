{ runCommand }:

{
  name ? "boson-kernel-stub",
  target,
  version ? "todo",
}:

runCommand name { } ''
  mkdir -p "$out/share/boson/kernel"
  cat > "$out/share/boson/kernel/README" <<README
  BosonOS kernel placeholder

  Target: ${target.name or "unknown"}
  Version: ${version}

  This first milestone keeps the kernel derivation as an explicit TODO.
  Real target kernels will be built through mkKernel without making the
  target runtime a NixOS system.
  README
''
