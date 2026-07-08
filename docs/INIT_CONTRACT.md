# Init Contract

Gluon and the BEAM runtime communicate through a narrow process contract.

Gluon provides:

- A mounted early root filesystem.
- `/proc`, `/sys`, `/dev`, `/run`, and optionally `/data`.
- Environment inherited by the runtime release.
- Console stdio attached to the configured console.
- A working directory and release path under `/srv/boson`.

The runtime provides:

- A foreground release command that remains alive.
- OTP supervision for BosonOS services.
- Logging to stdout/stderr or the configured console.
- Clean exit when the system should apply `on_exit`.
- Non-zero exit or crash when Gluon should apply `on_crash`.

The default release command is:

```text
/srv/boson/bin/boson foreground
```
