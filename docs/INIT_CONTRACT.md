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
- A stable `Boson.Boot.status/0` readiness and lifecycle status API.
- Clean exit after an atomic machine-action request, or to apply `on_exit`.
- Non-zero exit or crash when Gluon should apply `on_crash`.

The default release command is:

```text
/srv/boson/bin/boson start
```

The release must remain attached to Gluon. `Boson.Boot` owns readiness and
lifecycle decisions; Gluon performs the final machine operation.

## Readiness And Action Requests

`Boson.Boot.status/0` returns `phase` (`:starting`, `:ready`, or `:stopping`),
`started_at_ms`, `ready_at_ms`, sorted `online_components` and
`missing_components`, and `last_action`. The initial `Boson.Runtime ready`
marker appears once per application boot epoch, after all five required
components report ready. Component loss invalidates readiness; recovery emits
`Boson.Runtime recovered`. Boot restart rechecks live components without
repeating the initial marker.

`Boson.Boot.request_action/1` accepts only `:reboot` or `:poweroff`, and only
while ready. Unsupported, premature, and duplicate requests return errors.
Write failure preserves readiness. Successful requests enter `:stopping`,
retain their selected action during shutdown, and asynchronously stop the
release with status zero. Boot restart resumes a valid pending action;
malformed or unreadable pending content stops the release with non-zero status.

The fixed internal handoff path is `/run/boson/action`. Its only valid payloads
are these exact bytes, including the trailing newline:

```text
reboot\n
poweroff\n
```

The BEAM writer creates and syncs a private temporary file in `/run/boson`,
applies mode `0600`, and atomically renames it to `action`. This is an internal
runtime protocol, not a host-side command channel. Gluon clears stale content
before launching the release and bounds post-exit reads to 17 bytes (a 16-byte
limit plus one byte to detect overflow).

| Runtime result | Action file | Machine behavior |
| --- | --- | --- |
| Non-zero or signaled | Any | Remove if possible; apply `on_crash` |
| Zero | Missing | Apply `on_exit` |
| Zero | Exact `reboot\n` | Remove; reboot |
| Zero | Exact `poweroff\n` | Remove; power off |
| Zero | Invalid, unreadable, or oversized | Remove if possible; apply `on_crash` |
| Zero | Valid but removal fails | Apply `on_crash` without executing the request |

Arguments, extra tokens, service names, and arbitrary commands are rejected.
