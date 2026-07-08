{ writeText }:

{
  label ? "BosonOS",
  kernel ? "/boot/Image",
  fdt ? null,
  append ? "console=ttyS0",
}:

writeText "extlinux.conf" ''
  DEFAULT bosonos
  LABEL bosonos
    MENU LABEL ${label}
    LINUX ${kernel}
  ${if fdt == null then "" else "  FDT ${fdt}\n"}  APPEND ${append}
''
