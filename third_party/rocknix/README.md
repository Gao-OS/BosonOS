# ROCKNIX Reference Area

This directory is for imported ROCKNIX hardware resources and notes only.

Rules:

- Keep imported files under `third_party/rocknix`.
- Preserve SPDX and license headers from the original files.
- Record the source branch, commit, and imported paths in `sources.lock`.
- Do not depend on ROCKNIX shell build scripts from BosonOS core.
- Reimplement kernel, boot, and image composition in Nix.
