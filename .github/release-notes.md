## Platform status

BosonOS is experimental. This release publishes two boot-tested QEMU images:

| Target | Asset | Status |
| --- | --- | --- |
| QEMU x86_64 | `bosonos-qemu-x86_64-v__VERSION__.tar.gz` | Boot-tested in CI |
| QEMU AArch64 | `bosonos-qemu-aarch64-v__VERSION__.tar.gz` | Boot-tested in CI |
| RK3566 boards | Not published | Target structure only; hardware boot is not verified |

Each QEMU archive contains an architecture-specific Linux kernel,
`initramfs.cpio.gz`, and `manifest.txt`:

| `device_id` | Architecture | Kernel | QEMU executable | Machine | Serial console |
| --- | --- | --- | --- | --- | --- |
| `qemu-x86_64` | x86_64 | `bzImage` | `qemu-system-x86_64` | `q35` | `ttyS0,115200` |
| `qemu-aarch64` | AArch64 | `Image` | `qemu-system-aarch64` | `virt` | `ttyAMA0,115200` |

These are direct kernel/initramfs archives, not ISOs, installed disk images, or
package-manager repositories.

## Download and verify

Set `device_id` to the target matching the guest architecture:

```bash
version="__VERSION__"
tag="__TAG__"
device_id="qemu-aarch64" # qemu-x86_64 or qemu-aarch64

case "$device_id" in
  qemu-x86_64)
    kernel="bzImage"
    qemu_binary="qemu-system-x86_64"
    qemu_cpu="max"
    machine="q35,accel=tcg"
    console="ttyS0,115200"
    ;;
  qemu-aarch64)
    kernel="Image"
    qemu_binary="qemu-system-aarch64"
    qemu_cpu="cortex-a57"
    machine="virt,accel=tcg"
    console="ttyAMA0,115200"
    ;;
  *)
    echo "unsupported device_id: $device_id" >&2
    exit 2
    ;;
esac

archive="bosonos-$device_id-v$version.tar.gz"
base="https://github.com/__REPOSITORY__/releases/download/$tag"

curl -fLO "$base/$archive"
curl -fLO "$base/$archive.sha256"

if command -v sha256sum >/dev/null 2>&1; then
  sha256sum -c "$archive.sha256"
else
  shasum -a 256 -c "$archive.sha256"
fi

extract_dir="bosonos-$device_id-v$version"
mkdir -p "$extract_dir"
tar -xzf "$archive" -C "$extract_dir"
cd "$extract_dir"

printf 'kernel=%s qemu=%s cpu=%s machine=%s console=%s\n' \
  "$kernel" "$qemu_binary" "$qemu_cpu" "$machine" "$console"
```

## Run with QEMU

Install the QEMU system emulator for the selected architecture. Run the command
from the extracted directory.

### x86_64

```bash
qemu-system-x86_64 \
  -machine q35,accel=tcg \
  -cpu max \
  -smp 2 \
  -m 1024M \
  -nodefaults \
  -serial stdio \
  -display none \
  -monitor none \
  -no-reboot \
  -kernel bzImage \
  -initrd initramfs.cpio.gz \
  -append "console=ttyS0,115200 panic=5 rdinit=/sbin/gluon"
```

### AArch64

```bash
qemu-system-aarch64 \
  -machine virt,accel=tcg \
  -cpu cortex-a57 \
  -smp 2 \
  -m 1024M \
  -nodefaults \
  -serial stdio \
  -display none \
  -monitor none \
  -no-reboot \
  -kernel Image \
  -initrd initramfs.cpio.gz \
  -append "console=ttyAMA0,115200 panic=5 rdinit=/sbin/gluon"
```

Successful boot reaches both serial markers:

```text
gluon info: starting
Boson.Boot online
```

Press `Ctrl+C` to stop QEMU.

## UTM status

UTM can run these images through its QEMU backend, but setup remains manual.
This release includes no `.utm` bundle, ISO, or disk image.

- On Apple Silicon, download `qemu-aarch64`, create an ARM64/AArch64 VM, and
  select **Virtualize**. The guest matches the host architecture and can use
  hardware virtualization. Use the `virt` machine and `ttyAMA0` serial console.
- On an Intel Mac, download `qemu-x86_64` and create an x86_64 VM using the
  `q35` machine and `ttyS0` serial console.
- Allocate at least 1024 MiB of RAM and configure a serial device using UTM's
  **Built-in Terminal** mode.
- In UTM's advanced QEMU arguments, add the direct kernel arguments matching
  the selected artifact.

Apple Silicon (`qemu-aarch64`):

```text
-kernel "/absolute/path/to/Image"
-initrd "/absolute/path/to/initramfs.cpio.gz"
-append "console=ttyAMA0,115200 panic=5 rdinit=/sbin/gluon"
```

Intel (`qemu-x86_64`):

```text
-kernel "/absolute/path/to/bzImage"
-initrd "/absolute/path/to/initramfs.cpio.gz"
-append "console=ttyS0,115200 panic=5 rdinit=/sbin/gluon"
```

UTM documents architecture constraints in its
[System settings](https://docs.getutm.app/settings-qemu/system/), custom
arguments in [QEMU settings](https://docs.getutm.app/settings-qemu/qemu/), and
terminal setup in [Serial settings](https://docs.getutm.app/settings-qemu/devices/serial/).
The UTM path is currently experimental and is not exercised by BosonOS CI.

## Current limitations

- The root filesystem is an ephemeral initramfs.
- There is no installer or persistent system disk in this release.
- Boson runtime services are initial OTP supervision stubs.
