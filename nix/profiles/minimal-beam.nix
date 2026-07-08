{ lib }:

{
  name = "minimal-beam";
  description = "Minimal Gluon plus BEAM runtime profile";
  debug = false;
  rescueShell = false;
  runtimeServices = [
    "boot"
    "bus"
    "device"
    "net"
    "console"
    "update"
  ];
}
