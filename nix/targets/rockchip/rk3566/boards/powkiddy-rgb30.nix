{ lib }:

{
  name = "powkiddy-rgb30";
  soc = "rockchip-rk3566";
  dtb = "rk3566-powkiddy-rgb30.dtb";
  fdtType = "dtb";
  bootloaderBinary = "TODO";
  panelQuirks = [ "square-panel" ];
  inputQuirks = [ ];
  wifiBluetoothFirmware = [ ];
  batteryPowerQuirks = [ ];
  extraKernelModules = [ ];
}
