# ROCKNIX Import Policy

ROCKNIX may be used as a reference source for hardware bring-up resources.

Allowed imports:

- Kernel config.
- Linux patches.
- DTS files.
- Bootloader references.
- Device mapping notes.

Rules:

- Imported files must stay under `third_party/rocknix`.
- Preserve SPDX and license headers.
- Record source, branch, commit, and imported paths in `sources.lock`.
- Do not copy the ROCKNIX shell build system into BosonOS core.
- Reimplement image, kernel, and boot composition through Nix.

The first milestone reserves the import area but does not depend on ROCKNIX
build scripts.
