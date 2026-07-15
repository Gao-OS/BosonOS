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
- Applying a simple exit policy.

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
