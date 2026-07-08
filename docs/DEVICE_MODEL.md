# Device Model

BosonOS separates SoC-level support from board-level support.

SoC-level files define:

- Architecture.
- CPU family.
- Kernel version and target.
- Shared kernel config.
- Common patches.
- Bootloader type.
- Firmware family.
- Default console.
- Common kernel command line.

Board-level files define:

- DTB or FDT details.
- Bootloader binary selection.
- Panel quirks.
- Input quirks.
- Wi-Fi and Bluetooth firmware.
- Battery and power quirks.
- Extra kernel modules.

Device behavior after boot belongs in the BEAM runtime.
