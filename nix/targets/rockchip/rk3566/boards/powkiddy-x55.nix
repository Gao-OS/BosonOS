{ lib }:

{
  name = "powkiddy-x55";
  soc = "rockchip-rk3566";
  dtb = "rk3566-powkiddy-x55.dtb";
  fdtType = "dtb";
  bootloaderBinary = "TODO";
  panelQuirks = [ ];
  inputQuirks = [ ];
  wifiBluetoothFirmware = [ ];
  batteryPowerQuirks = [ ];
  extraKernelModules = [ ];
}
