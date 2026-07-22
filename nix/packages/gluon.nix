{
  lib,
  stdenvNoCC,
  zig_0_15,
}:

stdenvNoCC.mkDerivation {
  pname = "gluon";
  version = "0.1.0";

  src = ../../src/gluon;

  nativeBuildInputs = [ zig_0_15 ];

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild
    export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-global-cache"
    zig build \
      --cache-dir "$TMPDIR/zig-cache" \
      --global-cache-dir "$ZIG_GLOBAL_CACHE_DIR" \
      -Dcpu=baseline \
      -Doptimize=ReleaseSafe
    runHook postBuild
  '';

  doCheck = true;

  checkPhase = ''
    runHook preCheck
    zig build test \
      --cache-dir "$TMPDIR/zig-test-cache" \
      --global-cache-dir "$ZIG_GLOBAL_CACHE_DIR" \
      -Dcpu=baseline \
      -Doptimize=ReleaseSafe
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-global-cache"
    zig build \
      --cache-dir "$TMPDIR/zig-cache" \
      --global-cache-dir "$ZIG_GLOBAL_CACHE_DIR" \
      -Dcpu=baseline \
      -Doptimize=ReleaseSafe \
      --prefix "$out"
    mkdir -p "$out/sbin"
    mv "$out/bin/gluon" "$out/sbin/gluon"
    rmdir "$out/bin"
    runHook postInstall
  '';

  meta = {
    description = "Minimal Zig PID 1 runtime launcher for BosonOS";
    platforms = lib.platforms.linux;
  };
}
