# BosonOS QEMU Boot Milestone Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Boot the Nix-built BosonOS root filesystem in headless QEMU, run Gluon as PID 1, start the Boson OTP release, and prove the chain with an automated serial-console smoke check.

**Architecture:** Nix assembles a portable x86_64 Linux kernel, a compressed initramfs, a static Gluon and BusyBox early userspace, and the transitive runtime closure required by the dynamically linked OTP release. QEMU boots the kernel and initramfs directly; Gluon mounts kernel filesystems, configures the console and hostname, launches the release with a controlled environment, forwards termination signals, reaps children, and applies the configured exit policy.

**Tech Stack:** Nix flakes and derivations, Linux x86_64 kernel, GNU cpio/gzip, QEMU TCG, Zig 0.15, Elixir/OTP release, BusyBox static.

---

### Task 1: Make the flake input portable

**Files:**
- Modify: `flake.nix`
- Modify: `flake.lock`
- Create: `nix/checks/flake-portable.nix`

- [ ] **Step 1: Write the failing portability check**

Create `nix/checks/flake-portable.nix` so the check rejects a machine-local path lock:

```nix
{ runCommand, flakeLock }:

runCommand "boson-flake-portable" { } ''
  if grep -q '"type": "path"' ${flakeLock}; then
    echo "flake.lock contains a machine-local path input" >&2
    exit 1
  fi
  touch "$out"
''
```

Expose it from `flake.nix` with `flakeLock = ./flake.lock;`.

- [ ] **Step 2: Run the check and verify it fails**

Run: `nix build .#checks.x86_64-linux.flake-portable --print-build-logs`

Expected: FAIL with `flake.lock contains a machine-local path input`.

- [ ] **Step 3: Pin nixpkgs through a portable URL**

Set the input in `flake.nix`:

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
};
```

Refresh only that lock entry:

```bash
nix flake lock --update-input nixpkgs
```

- [ ] **Step 4: Verify portability passes**

Run: `nix build .#checks.x86_64-linux.flake-portable --print-build-logs`

Expected: PASS and a store path for `boson-flake-portable`.

- [ ] **Step 5: Commit the portable input**

```bash
git add flake.nix flake.lock nix/checks/flake-portable.nix
git commit -m "fix(nix): pin portable nixpkgs input"
```

### Task 2: Define a self-contained rootfs contract

**Files:**
- Modify: `nix/checks/rootfs-build.nix`
- Modify: `nix/packages/busybox.nix`
- Modify: `nix/lib/mk-rootfs.nix`
- Modify: `rootfs/base/etc/gluon.conf`
- Modify: `flake.nix`

- [ ] **Step 1: Replace the rootfs alias check with behavioral assertions**

Use a check that requires a local static BusyBox, a valid init link, the runtime closure, and the supported Mix release command:

```nix
{ runCommand, rootfs, runtime }:

runCommand "boson-rootfs-contract" { } ''
  test "$(readlink ${rootfs}/rootfs/sbin/init)" = "gluon"
  test -x ${rootfs}/rootfs/sbin/gluon
  test -x ${rootfs}/rootfs/bin/busybox
  test "$(readlink ${rootfs}/rootfs/bin/sh)" = "busybox"
  test "$(readlink ${rootfs}/rootfs/srv/boson)" = "${runtime}"
  test -e ${rootfs}/rootfs${runtime}/bin/boson
  grep -qx 'release_command=start' ${rootfs}/rootfs/etc/gluon.conf
  touch "$out"
''
```

Pass `runtime` into the check from `flake.nix`.

- [ ] **Step 2: Run the rootfs check and verify it fails**

Run: `nix build .#checks.x86_64-linux.rootfs-build --print-build-logs`

Expected: FAIL because `/bin/busybox` is absent and `release_command` is `foreground`.

- [ ] **Step 3: Select a static BusyBox package**

Change `nix/packages/busybox.nix` to:

```nix
{ pkgsStatic }:

pkgsStatic.busybox
```

- [ ] **Step 4: Bundle the runtime closure and install local applets**

Update `mkRootfs` to build a closure manifest with `closureInfo`, copy every runtime store path under `rootfs/nix/store`, symlink `/srv/boson` to the copied runtime path, install BusyBox at `/bin/busybox`, and create relative applet links. The applet set must include the release script dependencies:

```text
awk basename cat cut date dd dirname dmesg echo grep hostname mkdir mount
od poweroff pwd readlink reboot sed sh sleep sync
```

Set writable runtime state outside the store by creating `/root` and `/run/boson` in the base rootfs.

- [ ] **Step 5: Correct the Gluon release command**

Set this exact line in `rootfs/base/etc/gluon.conf`:

```text
release_command=start
```

- [ ] **Step 6: Run the rootfs check and verify it passes**

Run: `nix build .#checks.x86_64-linux.rootfs-build --print-build-logs`

Expected: PASS.

- [ ] **Step 7: Commit the rootfs contract**

```bash
git add flake.nix nix/checks/rootfs-build.nix nix/packages/busybox.nix nix/lib/mk-rootfs.nix rootfs/base/etc/gluon.conf
git commit -m "feat(rootfs): bundle boot runtime closure"
```

### Task 3: Test and implement Gluon configuration and launch environment

**Files:**
- Modify: `src/gluon/build.zig`
- Modify: `src/gluon/src/config.zig`
- Modify: `src/gluon/src/runtime.zig`
- Modify: `nix/packages/gluon.nix`

- [ ] **Step 1: Add a Zig test build step**

Create a `test` step in `build.zig` using the same root module and target as the executable:

```zig
const unit_tests = b.addTest(.{
    .root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    }),
});
const run_unit_tests = b.addRunArtifact(unit_tests);
const test_step = b.step("test", "Run Gluon unit tests");
test_step.dependOn(&run_unit_tests.step);
```

- [ ] **Step 2: Write failing config tests**

Add tests in `config.zig` that require `start`, `/run/boson`, `/bin:/sbin`, and no BEAM distribution:

```zig
test "defaults launch a foreground Mix release without distribution" {
    const cfg = Config{};
    try std.testing.expectEqualStrings("start", cfg.release_command);
    try std.testing.expectEqualStrings("/run/boson", cfg.release_tmp);
    try std.testing.expectEqualStrings("/bin:/sbin", cfg.path);
    try std.testing.expectEqualStrings("none", cfg.release_distribution);
}
```

Add a parser test for `release_tmp`, `path`, and `release_distribution` overrides.

- [ ] **Step 3: Run the Zig tests and verify they fail**

Run from `src/gluon`: `nix shell nixpkgs#zig_0_15 -c zig build test`

Expected: FAIL because the new config fields and `start` default do not exist.

- [ ] **Step 4: Implement the config fields and parser cases**

Add these fields to `Config` and parse their matching keys:

```zig
release_command: []const u8 = "start",
release_tmp: []const u8 = "/run/boson",
path: []const u8 = "/bin:/sbin",
home: []const u8 = "/root",
term: []const u8 = "linux",
release_distribution: []const u8 = "none",
```

- [ ] **Step 5: Build an explicit child environment**

In `runtime.run`, load the inherited environment, override the boot contract, and set the child working directory:

```zig
var env_map = try std.process.getEnvMap(allocator);
defer env_map.deinit();
try env_map.put("PATH", cfg.path);
try env_map.put("HOME", cfg.home);
try env_map.put("TERM", cfg.term);
try env_map.put("RELEASE_TMP", cfg.release_tmp);
try env_map.put("RELEASE_DISTRIBUTION", cfg.release_distribution);

var child = std.process.Child.init(&argv, allocator);
child.env_map = &env_map;
child.cwd = cfg.release_path;
child.pgid = 0;
```

- [ ] **Step 6: Make the Nix package run tests before installation**

Run `zig build test` in `checkPhase` and set `doCheck = true` in `nix/packages/gluon.nix`.

- [ ] **Step 7: Verify tests pass**

Run: `nix build .#gluon --print-build-logs`

Expected: PASS with the Zig tests executed during the derivation.

- [ ] **Step 8: Commit config and environment behavior**

```bash
git add src/gluon/build.zig src/gluon/src/config.zig src/gluon/src/runtime.zig nix/packages/gluon.nix
git commit -m "feat(gluon): define runtime launch environment"
```

### Task 4: Implement Gluon PID 1 operations

**Files:**
- Modify: `src/gluon/src/main.zig`
- Modify: `src/gluon/src/mount.zig`
- Modify: `src/gluon/src/console.zig`
- Modify: `src/gluon/src/signals.zig`
- Modify: `src/gluon/src/runtime.zig`
- Modify: `src/gluon/src/reboot.zig`

- [ ] **Step 1: Write failing pure tests for mount and signal helpers**

Add a mount-result test proving that `SUCCESS` and `BUSY` are accepted while `PERM` is rejected. Add a signal test proving `record` followed by `take` returns the signal once and then clears it.

- [ ] **Step 2: Run tests and verify they fail**

Run from `src/gluon`: `nix shell nixpkgs#zig_0_15 -c zig build test`

Expected: FAIL because the helper behavior is not implemented.

- [ ] **Step 3: Mount kernel filesystems with Linux syscalls**

Use `std.os.linux.mount` for these mounts, accepting `EBUSY` as already mounted:

```text
proc     -> /proc (proc)
sysfs    -> /sys  (sysfs)
devtmpfs -> /dev  (devtmpfs, nosuid)
tmpfs    -> /run  (tmpfs, nosuid|nodev, mode=0755)
```

Attempt `/data` only when enabled; report a warning rather than aborting boot when the optional mount is unavailable.

- [ ] **Step 4: Configure hostname and console descriptors**

Call the Linux `sethostname` syscall with the configured hostname. Open the configured console read/write and duplicate it onto file descriptors 0, 1, and 2 with `std.posix.dup2`.

- [ ] **Step 5: Install signal recording and supervise the child process group**

Install handlers for `SIGTERM`, `SIGINT`, and `SIGHUP`. Run a low-level `waitpid(-1, ...)` loop so Gluon can:

```text
- forward pending termination signals to the runtime process group
- identify the release process exit status
- reap adopted children
- distinguish normal exit, signal exit, and unknown status
```

- [ ] **Step 6: Apply real exit policies**

Implement:

```text
reboot          -> sync, then std.posix.reboot(.RESTART)
poweroff        -> sync, then std.posix.reboot(.POWER_OFF)
hang            -> sleep forever
emergency_shell -> run the configured shell on the console, then hang
```

- [ ] **Step 7: Correct startup ordering**

In `main.zig`, require PID 1 when booted normally, load config, mount `/proc`, read `/proc/cmdline`, configure hostname/console, then launch the runtime. Keep direct non-PID-1 execution available for unit tests and diagnostics without applying machine exit policies.

- [ ] **Step 8: Verify unit and package tests pass**

Run:

```bash
nix shell nixpkgs#zig_0_15 -c zig build test
nix build .#gluon --print-build-logs
```

Expected: PASS.

- [ ] **Step 9: Commit PID 1 behavior**

```bash
git add src/gluon/src/main.zig src/gluon/src/mount.zig src/gluon/src/console.zig src/gluon/src/signals.zig src/gluon/src/runtime.zig src/gluon/src/reboot.zig
git commit -m "feat(gluon): implement pid 1 boot operations"
```

### Task 5: Build a real kernel and initramfs image

**Files:**
- Create: `nix/checks/qemu-image-build.nix`
- Modify: `nix/lib/mk-kernel.nix`
- Modify: `nix/packages/kernel.nix`
- Modify: `nix/lib/mk-image.nix`
- Modify: `nix/images/qemu-x86_64.nix`
- Modify: `flake.nix`

- [ ] **Step 1: Write a failing image-content check**

Create a check requiring these image outputs:

```nix
{ runCommand, image }:

runCommand "boson-qemu-image-contract" { } ''
  test -s ${image}/bzImage
  test -s ${image}/initramfs.cpio.gz
  grep -qx 'format=kernel-initramfs' ${image}/manifest.txt
  touch "$out"
''
```

- [ ] **Step 2: Run the image check and verify it fails**

Run: `nix build .#checks.x86_64-linux.qemu-image-build --print-build-logs`

Expected: FAIL because the current artifact only contains rootfs tar files.

- [ ] **Step 3: Package the cached nixpkgs kernel**

Pass `linuxPackages.kernel` to `mkKernel` and copy `${kernelPackage}/bzImage` to the Boson kernel output with a manifest containing target and version.

- [ ] **Step 4: Produce a deterministic initramfs**

In `mkImage`, use GNU cpio `newc` format and `gzip -n`:

```bash
(
  cd ${rootfs}/rootfs
  find . -print0 \
    | sort -z \
    | cpio --null --create --format=newc --owner=0:0 --reproducible
) | gzip -n > "$out/initramfs.cpio.gz"
install -Dm644 ${kernel}/bzImage "$out/bzImage"
```

Write `format=kernel-initramfs` to `manifest.txt` with target, profile, kernel, and initramfs names.

- [ ] **Step 5: Verify the image check passes**

Run: `nix build .#checks.x86_64-linux.qemu-image-build --print-build-logs`

Expected: PASS.

- [ ] **Step 6: Commit the boot image**

```bash
git add flake.nix nix/checks/qemu-image-build.nix nix/lib/mk-kernel.nix nix/packages/kernel.nix nix/lib/mk-image.nix nix/images/qemu-x86_64.nix
git commit -m "feat(image): build qemu kernel and initramfs"
```

### Task 6: Boot QEMU and assert serial markers

**Files:**
- Modify: `nix/lib/mk-qemu-app.nix`
- Modify: `nix/checks/qemu-boot-smoke.nix`
- Modify: `flake.nix`

- [ ] **Step 1: Make the smoke check require a real boot**

Change the check to run:

```bash
${qemuApp}/bin/boson-qemu --smoke-test > "$out/console.log"
grep -Fq 'gluon info: starting' "$out/console.log"
grep -Fq 'Boson.Boot online' "$out/console.log"
```

- [ ] **Step 2: Run the smoke check and verify it fails**

Run: `nix build .#checks.x86_64-linux.qemu-boot-smoke --print-build-logs`

Expected: FAIL because the current runner only prints the placeholder text.

- [ ] **Step 3: Implement the direct-kernel QEMU runner**

Use the QEMU package supplied by Nix and these fixed boot arguments:

```text
-machine q35,accel=tcg
-cpu max
-m 512M
-nodefaults
-serial stdio
-display none
-no-reboot
-kernel <image>/bzImage
-initrd <image>/initramfs.cpio.gz
-append console=ttyS0,115200 rdinit=/sbin/gluon panic=1
```

Normal mode must `exec` QEMU interactively. Smoke mode must capture serial output, stop QEMU after both boot markers appear, fail after 90 seconds, and print the captured console log.

- [ ] **Step 4: Verify the real boot check passes**

Run: `nix build .#checks.x86_64-linux.qemu-boot-smoke --print-build-logs`

Expected: PASS with Linux, Gluon, and `Boson.Boot online` in the build log.

- [ ] **Step 5: Verify the user-facing runner**

Run: `timeout 30s nix run .#qemu`

Expected: the command times out because the runtime remains alive, and the console includes both required boot markers before timeout.

- [ ] **Step 6: Commit the runner and smoke test**

```bash
git add flake.nix nix/lib/mk-qemu-app.nix nix/checks/qemu-boot-smoke.nix
git commit -m "test(qemu): verify gluon starts beam runtime"
```

### Task 7: Document the bootable milestone

**Files:**
- Modify: `README.md`
- Modify: `docs/BOOT.md`
- Modify: `docs/GLUON.md`
- Modify: `docs/INIT_CONTRACT.md`
- Modify: `docs/ROOTFS.md`
- Modify: `docs/NIX_BUILD.md`

- [ ] **Step 1: Replace placeholder claims with the verified runtime contract**

Document that:

```text
- qemu-x86_64 is the first bootable target
- the image artifact contains bzImage and initramfs.cpio.gz
- /srv/boson points at a copied Nix store runtime closure
- no Nix executable or target package manager is present
- Gluon runs /srv/boson/bin/boson start
- RELEASE_TMP=/run/boson and RELEASE_DISTRIBUTION=none
- the QEMU check requires both Gluon and OTP serial markers
- RK3566 remains structural only
```

- [ ] **Step 2: Check documentation consistency**

Run:

```bash
rg -n 'foreground|rootfs tarball|QEMU.*placeholder|kernel.*placeholder' README.md docs
```

Expected: no stale first-milestone claims for the QEMU target.

- [ ] **Step 3: Commit documentation**

```bash
git add README.md docs
git commit -m "docs(boot): describe qemu vertical slice"
```

### Task 8: Run full verification

**Files:**
- Verify only

- [ ] **Step 1: Run formatting and unit tests**

```bash
(cd src/runtime && mix format --check-formatted && mix test)
(cd src/gluon && nix shell nixpkgs#zig_0_15 -c zig fmt --check src build.zig)
(cd src/gluon && nix shell nixpkgs#zig_0_15 -c zig build test)
```

Expected: `1 test, 0 failures`; Zig formatting and tests pass.

- [ ] **Step 2: Build all milestone artifacts**

```bash
nix build .#gluon .#boson-runtime .#boson-rootfs .#boson-qemu-image --print-build-logs
```

Expected: PASS.

- [ ] **Step 3: Run the complete flake check**

```bash
nix flake check --print-build-logs
```

Expected: all package, rootfs, image, and QEMU boot checks pass.

- [ ] **Step 4: Verify release workflow compatibility**

```bash
nix run nixpkgs#actionlint -- .github/workflows/*.yml
git diff --check main...HEAD
```

Expected: no workflow lint or whitespace errors. The existing `boson-qemu-image` package still produces a directory suitable for the build-release tar step.

- [ ] **Step 5: Inspect final branch state**

```bash
git status --short --branch
git log --oneline --decorate main..HEAD
```

Expected: a clean `codex/qemu-boot-milestone` worktree with cohesive conventional commits.
