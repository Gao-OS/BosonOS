{ runCommand, qemuApp }:

runCommand "boson-qemu-lifecycle-smoke" { } ''
  mkdir -p "$out"
  ${qemuApp}/bin/boson-qemu --lifecycle-smoke-test > "$out/console.log"
  grep -Fq 'Boson.Runtime ready' "$out/console.log"
  grep -Fq 'Boson.Runtime stopping action=poweroff' "$out/console.log"
  grep -Fq 'gluon info: applying runtime action: poweroff' "$out/console.log"
''
