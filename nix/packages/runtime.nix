{
  lib,
  stdenvNoCC,
  elixir,
  erlang,
  lifecycleTestAction ? null,
}:

stdenvNoCC.mkDerivation {
  pname = "boson-runtime";
  version = "0.1.0";

  src = ../../src/runtime;

  nativeBuildInputs = [
    elixir
    erlang
  ];

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild
    export HOME="$TMPDIR/home"
    export MIX_HOME="$TMPDIR/mix"
    export HEX_HOME="$TMPDIR/hex"
    export REBAR_CACHE_DIR="$TMPDIR/rebar"
    export MIX_ENV=prod
    export ELIXIR_ERL_OPTIONS="+fnu"
    mkdir -p "$HOME" "$MIX_HOME" "$HEX_HOME" "$REBAR_CACHE_DIR"

    ${lib.optionalString (lifecycleTestAction != null) ''
      export BOSON_LIFECYCLE_TEST_ACTION=${lib.escapeShellArg lifecycleTestAction}
    ''}
    mix compile --no-deps-check
    mix release --overwrite --path "$out"
    runHook postBuild
  '';

  doCheck = true;

  checkPhase = ''
    runHook preCheck
    export MIX_ENV=test
    unset BOSON_LIFECYCLE_TEST_ACTION
    mix test
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    runHook postInstall
  '';

  meta = {
    description = "Minimal Elixir/OTP BosonOS runtime release";
    platforms = lib.platforms.linux;
  };
}
