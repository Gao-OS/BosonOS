{ runCommand, flakeLock }:

runCommand "boson-flake-portable" { } ''
  if grep -q '"type": "path"' ${flakeLock}; then
    echo "flake.lock contains a machine-local path input" >&2
    exit 1
  fi

  touch "$out"
''
