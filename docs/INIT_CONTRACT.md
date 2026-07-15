# Init Contract

Gluon and the BEAM runtime communicate through a narrow process contract.

Gluon provides:

- A mounted early root filesystem.
- `/proc`, `/sys`, `/dev`, `/run`, and optionally `/data`.
- A controlled runtime environment.
- Console stdio attached to the configured console.
- `/srv/boson` as the runtime working directory.
- A dedicated process group for signal forwarding.

The default environment contract is:

```text
PATH=/bin:/sbin
HOME=/root
TERM=linux
LANG=C.UTF-8
RELEASE_TMP=/run/boson
RELEASE_DISTRIBUTION=none
```

The runtime provides:

- A single long-lived release process that remains attached to Gluon.
- OTP supervision for BosonOS services.
- Logging to stdout/stderr or the configured console.
- Clean exit when the system should apply `on_exit`.
- Non-zero exit or crash when Gluon should apply `on_crash`.

The default release command is:

```text
/srv/boson/bin/boson start
```

The release must remain attached to Gluon. A normal exit selects `on_exit`; a
non-zero exit or failed launch selects `on_crash`.
