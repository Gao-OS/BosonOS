{ lib }:

{
  name = "anbernic-rg353v";
  soc = "rockchip-rk3566";
  dtb = "rk3566-anbernic-rg353v.dtb";
  fdtType = "dtb";
  bootloaderBinary = "TODO";
  panelQuirks = [ ];
  inputQuirks = [ ];
  wifiBluetoothFirmware = [ ];
  batteryPowerQuirks = [ ];
  extraKernelModules = [ ];
}
