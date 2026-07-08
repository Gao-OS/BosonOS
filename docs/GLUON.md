# Gluon

Gluon is the minimal Zig PID 1 launcher for BosonOS.

It is responsible for:

- Starting as PID 1.
- Reading `/proc/cmdline`.
- Reading `/etc/gluon.conf`.
- Preparing required early mount points.
- Setting the hostname and console policy.
- Starting the BosonOS OTP release.
- Waiting for the runtime process.
- Applying a simple exit policy.

It is not responsible for:

- Service dependency graphs.
- Device management.
- Network management.
- D-Bus or policy engines.
- Login/session management.
- Package management.

Those responsibilities belong either to the kernel or to the BEAM control plane.
