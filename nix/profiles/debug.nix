{ lib }:

{
  name = "debug";
  description = "Developer profile with BusyBox tools and verbose runtime logging";
  debug = true;
  rescueShell = true;
}
