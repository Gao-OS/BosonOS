{ lib }:

{
  name = "qemu-x86_64";
  soc = "qemu-pc";
  board = "qemu-x86_64";
  arch = "x86_64-linux";
  cpu = "x86_64";
  kernelTarget = "bzImage";
  bootloader = "qemu-direct";
  firmwareFamily = "qemu";
  defaultConsole = "ttyS0,115200";
  commonCmdline = [
    "console=ttyS0,115200"
    "panic=5"
  ];
}
