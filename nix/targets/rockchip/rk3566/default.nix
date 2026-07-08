{ lib }:

{
  name = "rockchip-rk3566";
  arch = "aarch64-linux";
  cpu = "cortex-a55";
  kernelVersion = "TODO";
  kernelTarget = "Image";
  bootloader = "u-boot";
  firmwareFamily = "rkbin";
  defaultConsole = "ttyS2,1500000";
  commonCmdline = [
    "console=ttyS2,1500000"
    "earlycon=uart8250,mmio32,0xfe660000"
    "panic=5"
  ];
  commonPatches = [
    "../../../third_party/rocknix/rk3566/patches"
  ];
  boards = {
    powkiddy-rgb30 = import ./boards/powkiddy-rgb30.nix { inherit lib; };
    powkiddy-x55 = import ./boards/powkiddy-x55.nix { inherit lib; };
    anbernic-rg353v = import ./boards/anbernic-rg353v.nix { inherit lib; };
  };
}
