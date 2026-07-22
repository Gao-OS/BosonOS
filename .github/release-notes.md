## Platform status

BosonOS is experimental. This release publishes one boot-tested image:

| Target | Asset | Status |
| --- | --- | --- |
| QEMU x86_64 | `bosonos-qemu-x86_64-v__VERSION__.tar.gz` | Boot-tested in CI |
| QEMU AArch64 | Not published | Not implemented yet |
| RK3566 boards | Not published | Target structure only; hardware boot is not verified |

The x86_64 archive contains a Linux `bzImage`, `initramfs.cpio.gz`, and
`manifest.txt`. It is not an ISO, installed disk image, or package-manager
repository.

## Download and verify

```bash
version="__VERSION__"
tag="__TAG__"
archive="bosonos-qemu-x86_64-v$version.tar.gz"
base="https://github.com/__REPOSITORY__/releases/download/$tag"

curl -LO "$base/$archive"
curl -LO "$base/$archive.sha256"

if command -v sha256sum >/dev/null 2>&1; then
  sha256sum -c "$archive.sha256"
else
  shasum -a 256 -c "$archive.sha256"
fi

mkdir "bosonos-$version"
tar -xzf "$archive" -C "bosonos-$version"
cd "bosonos-$version"
```

## Run with QEMU

Install a recent `qemu-system-x86_64`, then run:

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

Successful boot reaches both serial markers:

```text
gluon info: starting
Boson.Boot online
```

Press `Ctrl+C` to stop QEMU.

## UTM status

UTM can run this image through its QEMU backend, but this release is not a
one-click UTM appliance: no `.utm`, ISO, or disk image is included.

- On an Intel Mac, configure an x86_64 QEMU VM.
- On Apple Silicon, select **Emulate** with architecture **x86_64**. An x86_64
  guest cannot use AArch64 hardware virtualization, so expect slower startup.
- Configure Q35, at least 1024 MiB RAM, and a serial device using UTM's
  **Built-in Terminal** mode.
- In UTM's advanced QEMU arguments, add paths to the extracted files:

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
- Native Apple Silicon support requires a future `qemu-aarch64` target and
  AArch64 release artifact.
