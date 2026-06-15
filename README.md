# FPGA Run 3 Implementation

Made by: Arjun Chainani, Adhav Saravanan

### In order to run the project, do the following:
- In Xilinx Vivado, open the `run3_attempt2.xpr` file in the `run3_attempt2` directory (loads the Vivado workspace)
- Generate the bitstream and export the hardware platform
- Launch the Xilinx Vitis IDE from Vivado and load the `workspace` folder in the `run3_attempt2` directory
- Update the Hardware Configuration in the Vitis workspace to make sure the hardware component of the project is up to date, and then build and deploy the software onto the FPGA board through Vitis' build and run features. (make sure to connect the Urbana board to a keyboard and display so that the game can be seen and played)!

### Video of our project working!

Check out a quick 10-second clip of our project in action at [this Youtube link](https://youtube.com/shorts/tAJDWRSAvd4?feature=share).

### Code Description (Hardware/HDL)

**`latest/latest.srcs/sources_1/imports/sources_1/new/mb_usb_hdmi_top.sv`** - Top-level module for the project. It wires together all subsystems: the MicroBlaze USB/SPI keyboard block, clock generation, VGA timing, sprite physics, pixel compositing, and HDMI output, and drives two 7-segment displays showing the current level and active keycode.

**`latest/latest.srcs/sources_1/imports/sources_1/imports/design_source/VGA_controller.sv`** - Standard 640×480 VGA sync signal generator clocked at 25 MHz. It maintains horizontal and vertical pixel counters and outputs `hsync`, `vsync`, `active_nblank`, and the current draw coordinates (`drawX`, `drawY`) consumed by the color mapper.

**`latest/latest.srcs/sources_1/imports/sources_1/imports/design_source/Color_Mapper.sv`** - Per-pixel RGB compositor that runs every pixel clock cycle. It layers the animated alien sprite, tiled level walls (with per-level color tinting), and a starfield background in priority order; it also reads `levels_rom`, applies perspective-based wall rotation, cycles animation frames on vsync, and handles lizard-mode toggling via keycode 8.

**`latest/latest.srcs/sources_1/imports/sources_1/imports/design_source/hex_driver.sv`** - Time-multiplexed driver for a 4-digit hexadecimal 7-segment display. It converts four 4-bit nibbles into active-low segment patterns and cycles through each digit using a free-running counter, allowing a single display to show all four values simultaneously.

**`latest/latest.srcs/sources_1/imports/sources_1/new/sprite.sv`** - Player sprite physics and state controller. Each vsync it reads WASD keycodes, applies gravity, checks wall/floor collision against the `levels_rom` bitmask, handles jumping (with a higher "lizard" jump variant), wraps the player at screen edges with a perspective rotation, and advances the level and animation frame counters.

**`latest/latest.srcs/sources_1/imports/sources_1/new/stars_rom.sv`** - Combinational ROM holding a 64×64 binary starfield tile (4096 bits). It is tiled across the entire background by `color_mapper` by masking `drawX` and `drawY` to 6-bit indices, producing a repeating star pattern.

**`latest/latest.srcs/sources_1/new/levels_rom.sv`** - 500-entry ROM that stores the wall layout for every game frame as a 16-bit bitmask (4 bits each for ceiling, left wall, floor, and right wall, each divided into 4 sections). The nine difficulty levels progress from a solid-walled tutorial through increasingly large and frequent gaps, culminating in a maximum-difficulty gauntlet.

**`latest/latest.srcs/sources_1/imports/sources_1/imports/alien/alien_rom.sv`** - Auto-generated sprite pixel ROM containing ten 64×48 animation frames as 2-bit-per-pixel palette indices: standing, left foot, right foot, jumping, and falling poses for both the alien and lizard characters. `color_mapper` selects the active frame based on `sprite_select`, `falling`, and `lizard` mode flags.

**`latest/latest.srcs/sources_1/imports/sources_1/imports/alien/alien_palette.sv`** - Combinational palette lookup that converts the 2-bit pixel index from `alien_rom` into 4-bit RGB. Index 0 maps to a sentinel red (transparent, skipped by `color_mapper`); indices 1–2 use gray tones for the alien or green tones for lizard mode.

**`latest/latest.srcs/sim_1/new/color_mapper_tb.sv`** - Simulation testbench for `color_mapper`. It instantiates the VGA controller and sprite module to drive realistic pixel coordinates, captures one complete 800×525-pixel frame into a memory array, and writes the result out as a 24-bit BMP file (`color_mapper_sim.bmp`) for visual verification.

### Code Description (Software/C)

The vast majority of those are Xilinx BSP/library files (generated boilerplate). Let me focus on just the user-written source files under `latest/software/run/src/`.Here are descriptions for all the user-authored C/H files under `latest/software/run/src/`:

---

**`latest/software/run/src/lw_usb_main.c`** - The MicroBlaze application entry point. It initializes the MAX3421E USB host chip and the AXI GPIO peripheral, then runs a polling loop that drives the USB state machine, detects keyboard or mouse connections, reads HID reports each iteration, and writes the first four keyboard keycodes out over GPIO to the FPGA fabric (where `mb_usb_hdmi_top.sv` picks them up as `keycode0_gpio`).

**`latest/software/run/src/platform.c`** - Xilinx-provided (lightly customized) platform initialization glue. It enables the MicroBlaze instruction and data caches on startup via `init_platform()` and disables them on shutdown via `cleanup_platform()`, with optional UART baud-rate configuration for 16550-style UARTs.

**`latest/software/run/src/platform.h`** - Header declaring the `init_platform()` and `cleanup_platform()` functions from `platform.c`, included by `lw_usb_main.c` to access platform setup routines.

**`latest/software/run/src/platform_config.h`** - Minimal configuration header with no active content; serves as a placeholder for board-specific defines (such as STDOUT routing) that `platform.c` would check via preprocessor guards.

**`latest/software/run/src/lw_usb/MAX3421E.c`** - Low-level driver for the MAX3421E USB host controller chip. It implements SPI read/write primitives over the Xilinx SPI peripheral, hardware and software reset sequencing, VBUS power switching, bus-speed probing (J/K/SE0/SE1 state detection), and the interrupt handler that advances the USB task state machine on connection/disconnection and bus events.

**`latest/software/run/src/lw_usb/MAX3421E.h`** - Header for `MAX3421E.c` defining all MAX3421E register addresses and bit masks (HIRQ, HIEN, MODE, HCTL, HRSL, etc.), SPI mode constants, host transfer token values, and function prototypes for the low-level SPI and chip control functions.

**`latest/software/run/src/lw_usb/USB.h`** - Defines the USB host state machine constants (detached, attached, addressing, configuring, running, error), standard USB request codes, descriptor type codes, and HID class request codes used throughout the USB stack.

**`latest/software/run/src/lw_usb/transfer.c`** - Implements the USB transfer layer and high-level state machine. It handles control transfers (setup, data, and status stages), dispatches packets to the MAX3421E with NAK retry and timeout logic, performs multi-packet IN transfers, and runs `USB_Task()` — the enumeration state machine that detects device attachment, assigns an address, and calls into the client driver table to identify and configure the connected HID device.

**`latest/software/run/src/lw_usb/transfer.h`** - Header for `transfer.c` declaring USB descriptor structures (`EP_RECORD`, `DEV_RECORD`, `SETUP_PKT`, etc.), standard request constants, HID class constants, control-transfer macro wrappers (`XferGetDevDescr`, `XferSetConf`, `XferGetIdle`, etc.), and function prototypes for the transfer and state machine functions.

**`latest/software/run/src/lw_usb/HID.c`** - Implements the HID class driver. `HIDKProbe` and `HIDMProbe` parse the device's configuration descriptor to detect boot-protocol keyboards and mice respectively, configure the device, and populate the endpoint table. `kbdPoll` and `mousePoll` issue interrupt-IN transfers to read 8-byte HID boot reports from the device.

**`latest/software/run/src/lw_usb/HID.h`** - Header for `HID.c` defining the `HID_DEVICE`, `BOOT_KBD_REPORT`, and `BOOT_MOUSE_REPORT` structures, and declaring the probe, poll, and event-handler function prototypes.

**`latest/software/run/src/lw_usb/usb_ch9.h`** - Defines C structures for all USB Chapter 9 standard descriptors (device, configuration, interface, endpoint, string, OTG, HID), endpoint attribute constants, and the `USB_DESCR` union used to parse raw descriptor bytes in `HID.c` and `transfer.c`.

**`latest/software/run/src/lw_usb/project_config.h`** - Top-level include aggregator for the `lw_usb` library. It pulls in all sub-headers (`GenericTypeDefs.h`, `MAX3421E.h`, `transfer.h`, etc.) and defines the USB timing constants used across the stack (`USB_SETTLE_TIME`, `USB_XFER_TIMEOUT`, `USB_NAK_LIMIT`, `USB_RETRY_LIMIT`).

**`latest/software/run/src/lw_usb/GenericTypeDefs.h`** - Defines the portable integer typedefs (`BYTE`, `WORD`, `DWORD`, `BOOL`, etc.) and their corresponding bit-field union variants (`BYTE_VAL`, `WORD_VAL`, `DWORD_VAL`) used throughout the USB library in place of standard C types.

**`latest/software/run/src/lw_usb/GenericMacros.h`** - Provides a small set of utility macros: `LOBYTE`/`HIBYTE` for extracting bytes from a word, and `bitset`/`bitclr` for single-bit manipulation, used across the USB driver files.