{
  description = "BosonOS, a Nix-built Linux-hosted BEAM-first operating system substrate";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
  };

  outputs =
    { nixpkgs, ... }:
    let
      supportedSystems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      systemScope =
        system:
        let
          pkgs = import nixpkgs { inherit system; };

          target = import ./nix/targets/qemu/x86_64.nix { inherit (pkgs) lib; };
          profile = import ./nix/profiles/minimal-beam.nix { inherit (pkgs) lib; };

          mkBosonSystem = pkgs.callPackage ./nix/lib/mk-boson-system.nix { };
          mkRootfs = pkgs.callPackage ./nix/lib/mk-rootfs.nix { };
          mkKernel = pkgs.callPackage ./nix/lib/mk-kernel.nix { };
          mkImage = pkgs.callPackage ./nix/lib/mk-image.nix { };
          mkQemuApp = pkgs.callPackage ./nix/lib/mk-qemu-app.nix { };

          gluon = pkgs.callPackage ./nix/packages/gluon.nix { };
          runtime = pkgs.callPackage ./nix/packages/runtime.nix { };
          busybox = pkgs.callPackage ./nix/packages/busybox.nix { };
          kernel = pkgs.callPackage ./nix/packages/kernel.nix { inherit mkKernel target; };
          rootfs = pkgs.callPackage ./nix/packages/rootfs.nix {
            inherit
              mkRootfs
              gluon
              runtime
              busybox
              ;
          };
          qemuImage = pkgs.callPackage ./nix/images/qemu-x86_64.nix {
            inherit
              mkImage
              rootfs
              kernel
              target
              profile
              ;
          };
          rk3566PowkiddyRgb30Image = pkgs.callPackage ./nix/images/rk3566-powkiddy-rgb30.nix { };
          qemuApp = mkQemuApp {
            image = qemuImage;
            inherit target;
          };

          bosonSystem = mkBosonSystem {
            inherit
              target
              profile
              kernel
              gluon
              runtime
              rootfs
              ;
            image = qemuImage;
            qemu = qemuApp;
          };
        in
        {
          packages = {
            inherit gluon;
            boson-runtime = runtime;
            boson-rootfs = rootfs;
            boson-qemu-image = qemuImage;
            rk3566-powkiddy-rgb30-image = rk3566PowkiddyRgb30Image;
            boson-system = bosonSystem;
            default = qemuImage;
          };

          apps = {
            qemu = {
              type = "app";
              program = "${qemuApp}/bin/boson-qemu";
              meta.description = "Run the BosonOS QEMU first-milestone runner";
            };
            default = {
              type = "app";
              program = "${qemuApp}/bin/boson-qemu";
              meta.description = "Run the BosonOS QEMU first-milestone runner";
            };
          };

          checks = {
            flake-portable = pkgs.callPackage ./nix/checks/flake-portable.nix {
              flakeLock = ./flake.lock;
            };
            gluon-build = pkgs.callPackage ./nix/checks/gluon-build.nix { inherit gluon; };
            runtime-build = pkgs.callPackage ./nix/checks/runtime-build.nix { inherit runtime; };
            rootfs-build = pkgs.callPackage ./nix/checks/rootfs-build.nix { inherit rootfs; };
            qemu-boot-smoke = pkgs.callPackage ./nix/checks/qemu-boot-smoke.nix { inherit qemuApp; };
          };
        };
    in
    {
      packages = forAllSystems (system: (systemScope system).packages);
      apps = forAllSystems (system: (systemScope system).apps);
      checks = forAllSystems (system: (systemScope system).checks);
    };
}
