{ runCommand, qemuApp }:

runCommand "boson-qemu-runner-smoke" { } ''
  mkdir -p "$out"
  ${qemuApp}/bin/boson-qemu > "$out/output.txt"
''
