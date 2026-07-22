{ lib }:

{
  name = "qemu-aarch64";
  soc = "qemu-virt";
  board = "qemu-aarch64";
  arch = "aarch64-linux";
  cpu = "aarch64";
  kernelTarget = "Image";
  bootloader = "qemu-direct";
  firmwareFamily = "qemu";
  defaultConsole = "ttyAMA0,115200";
  qemuBinary = "qemu-system-aarch64";
  qemuMachine = "virt,accel=tcg";
  qemuCpu = "max";
  commonCmdline = [
    "console=ttyAMA0,115200"
    "panic=5"
  ];
}
