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
      -machine "${target.qemuMachine}"
      -cpu "${target.qemuCpu}"
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

    case "''${1:-}" in
      --smoke-test|--lifecycle-smoke-test) mode="$1" ;;
      *) exec ${target.qemuBinary} "''${qemu_args[@]}" "$@" ;;
    esac

    if (( $# != 1 )); then
      echo "usage: boson-qemu --smoke-test | --lifecycle-smoke-test" >&2
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
    trap cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM

    ${target.qemuBinary} "''${qemu_args[@]}" >"$log" 2>&1 &
    qemu_pid=$!

    failed() {
      grep -Eq 'Boson\.Runtime unavailable|gluon error:|Kernel panic' "$log"
    }

    lifecycle_failed() {
      grep -Eq 'gluon error:|Kernel panic' "$log" \
        || { grep -m 1 -E 'Boson\.Runtime stopping action=poweroff|Boson\.Runtime unavailable' "$log" \
          | grep -Fq 'Boson.Runtime unavailable'; }
    }

    if [[ "$mode" == "--lifecycle-smoke-test" ]]; then
      exited=false
      for ((attempt = 0; attempt < 120; attempt++)); do
        if lifecycle_failed; then
          cat "$log"
          echo "BosonOS lifecycle failed before normal poweroff" >&2
          exit 1
        fi
        if ! kill -0 "$qemu_pid" 2>/dev/null; then
          exited=true
          break
        fi
        sleep 1
      done

      if ! kill -0 "$qemu_pid" 2>/dev/null; then
        exited=true
      fi

      if [[ "$exited" != true ]]; then
        cat "$log"
        echo "BosonOS lifecycle did not power off within 120 seconds" >&2
        exit 1
      fi

      if wait "$qemu_pid"; then
        qemu_status=0
      else
        qemu_status=$?
      fi
      qemu_pid=""
      cat "$log"

      if (( qemu_status != 0 )) || lifecycle_failed; then
        echo "BosonOS lifecycle did not exit normally" >&2
        exit 1
      fi

      ready_line=$(grep -nF 'Boson.Runtime ready' "$log" | head -n 1 | cut -d: -f1)
      stopping_line=$(grep -nF 'Boson.Runtime stopping action=poweroff' "$log" | head -n 1 | cut -d: -f1)
      action_line=$(grep -nF 'gluon info: applying runtime action: poweroff' "$log" | head -n 1 | cut -d: -f1)

      if [[ -z "$ready_line" || -z "$stopping_line" || -z "$action_line" ]] \
        || ! (( ready_line < stopping_line && stopping_line < action_line )); then
        echo "BosonOS lifecycle markers are missing or out of order" >&2
        exit 1
      fi
      exit 0
    fi

    booted=false
    for ((attempt = 0; attempt < 90; attempt++)); do
      if failed || ! kill -0 "$qemu_pid" 2>/dev/null; then
        break
      fi
      if grep -Fq "gluon info: starting" "$log"; then
        if grep -Fq "Boson.Runtime ready" "$log"; then
          booted=true
          break
        fi
      fi

      sleep 1
    done

    if [[ "$booted" == true ]]; then
      for ((interval = 0; interval < 10; interval++)); do
        sleep 1
        if failed || ! kill -0 "$qemu_pid" 2>/dev/null; then
          booted=false
          break
        fi
      done
    fi

    cat "$log"
    if [[ "$booted" != true ]]; then
      echo "BosonOS did not remain ready for ten seconds" >&2
      exit 1
    fi
  '';
}
