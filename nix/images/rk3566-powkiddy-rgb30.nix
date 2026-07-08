{
  runCommand,
}:

runCommand "boson-rk3566-powkiddy-rgb30-image-stub" { } ''
  mkdir -p "$out"
  cat > "$out/README" <<README
  TODO: build the RK3566 Powkiddy RGB30 image from the matrix target model.
  This stub exists to reserve the image entrypoint without blocking the first
  milestone on real RK3566 boot.
  README
''
