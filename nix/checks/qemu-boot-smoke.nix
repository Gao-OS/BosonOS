{ runCommand, qemuApp }:

runCommand "boson-qemu-runner-smoke" { } ''
  mkdir -p "$out"
  ${qemuApp}/bin/boson-qemu --smoke-test > "$out/console.log"
  grep -Fq 'gluon info: starting' "$out/console.log"
  grep -Fq 'Boson.Boot online' "$out/console.log"
''
