# Gluon

Gluon is the minimal Zig PID 1 launcher for BosonOS.

It is responsible for:

- Starting as PID 1.
- Reading `/proc/cmdline`.
- Reading `/etc/gluon.conf`.
- Mounting `/proc`, `/sys`, `/dev`, and `/run`.
- Treating `/data` as an optional mount.
- Setting the hostname and console policy.
- Starting the BosonOS OTP release with an explicit environment.
- Forwarding termination signals to the runtime process group.
- Reaping adopted child processes.
- Clearing stale `/run/boson/action` content before launching the runtime.
- Consuming a bounded action file after a clean runtime exit.
- Applying the selected machine action or configured exit policy.

It is not responsible for:

- Service dependency graphs.
- Device management.
- Network management.
- D-Bus or policy engines.
- Login/session management.
- Package management.

Those responsibilities belong either to the kernel or to the BEAM control plane.

The current QEMU milestone implements `reboot`, `poweroff`, `hang`, and
`emergency_shell` exit policies. Gluon does not discover or supervise a graph of
independent services; its single long-lived child is the OTP release.

After mounting `/run`, PID 1 removes any stale action file. A cleanup failure
other than a missing file applies `on_crash` without launching the runtime.
Diagnostic execution outside PID 1 does not read or delete the action file.

After a clean release exit, Gluon reads at most 17 bytes and accepts only the
exact `reboot\n` or `poweroff\n` payload. It must remove the file before applying
the request. Missing content selects `on_exit`; invalid, oversized, unreadable,
or unremovable content selects `on_crash`. Non-zero or signaled runtime exits
always select `on_crash`, discarding pending content if possible.

The consumer logs `gluon info: applying runtime action: poweroff` (or `reboot`)
before invoking the existing machine-policy implementation. Component readiness
and recovery remain in `Boson.Boot`; this protocol adds no Gluon service
management or command execution.
