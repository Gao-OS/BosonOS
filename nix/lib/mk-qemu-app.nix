{
  writeShellApplication,
  coreutils,
  gnugrep,
  qemu,
}:

{
  image,
  target,
}:

writeShellApplication {
  name = "boson-qemu";
  runtimeInputs = [
    coreutils
    gnugrep
    qemu
  ];
  text = ''
    qemu_args=(
      -machine "q35,accel=tcg"
      -cpu max
      -smp 2
      -m 1024M
      -nodefaults
      -serial stdio
      -display none
      -monitor none
      -no-reboot
      -kernel ${image}/${target.kernelTarget}
      -initrd ${image}/initramfs.cpio.gz
      -append "${builtins.concatStringsSep " " (target.commonCmdline or [ ])} rdinit=/sbin/gluon"
    )

    if [[ "''${1:-}" != "--smoke-test" ]]; then
      exec qemu-system-x86_64 "''${qemu_args[@]}" "$@"
    fi

    if (( $# != 1 )); then
      echo "usage: boson-qemu --smoke-test" >&2
      exit 2
    fi

    log="$(mktemp -t boson-qemu.XXXXXX.log)"
    qemu_pid=""
    cleanup() {
      if [[ -n "$qemu_pid" ]]; then
        kill "$qemu_pid" 2>/dev/null || true
        wait "$qemu_pid" 2>/dev/null || true
      fi
      rm -f "$log"
    }
    trap cleanup EXIT INT TERM

    qemu-system-x86_64 "''${qemu_args[@]}" >"$log" 2>&1 &
    qemu_pid=$!

    booted=false
    for ((attempt = 0; attempt < 90; attempt++)); do
      if grep -Fq "gluon info: starting" "$log"; then
        if grep -Fq "Boson.Boot online" "$log"; then
          booted=true
          break
        fi
      fi

      if ! kill -0 "$qemu_pid" 2>/dev/null; then
        break
      fi
      sleep 1
    done

    cat "$log"
    if [[ "$booted" != true ]]; then
      echo "BosonOS did not reach the runtime boot marker" >&2
      exit 1
    fi
  '';
}
