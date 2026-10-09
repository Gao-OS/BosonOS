{ runCommand, qemuApp }:

runCommand "boson-qemu-runner-smoke" { } ''
  mkdir -p "$out"
  ${qemuApp}/bin/boson-qemu --smoke-test > "$out/console.log"
  grep -Fq 'gluon info: starting' "$out/console.log"
  grep -Fq 'Boson.Runtime ready' "$out/console.log"
  ! grep -Eq 'Boson\.Runtime unavailable|gluon error:|Kernel panic' "$out/console.log"
  ! grep -Fq 'native name encoding of latin1' "$out/console.log"
''
