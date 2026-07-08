{ lib }:

{
  name = "rescue";
  description = "Small rescue shell profile for early bring-up";
  debug = true;
  rescueShell = true;
  runtimeServices = [ ];
}
