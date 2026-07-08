{ runCommand }:

runCommand "boson-rk3566-kernel-stub" { } ''
  mkdir -p "$out"
  cat > "$out/README" <<README
  TODO: build the RK3566 Linux Image using the BosonOS mkKernel abstraction.
  ROCKNIX resources may be referenced only from third_party/rocknix.
  README
''
