{ runCommand }:

runCommand "boson-rk3566-u-boot-stub" { } ''
  mkdir -p "$out"
  cat > "$out/README" <<README
  TODO: package RK3566 U-Boot/rkbin artifacts for supported boards.
  README
''
