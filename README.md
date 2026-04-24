# ece-385-run3

## Software Modules

`lw_usb/` - contains multiple C files used for implementing the SPI protocol with the MAX3421E chip to enables the FPGA to act as a USB host/controller and connect to keyboard peripheral

## Hardware Modules

`run3_top.sv` - Top level

`projection.sv` - 3D-to-2D projection math to calculate updated level state (uses bit manipulation with IEEE 754 standard for floating point multiplication)

`renderer.sv` - renders level state (calculated in software) onto the display 

`map_rom.sv` - BRAM for storing level data

`vga_controller.sv` - iterates through the display and draws the pixels

## IPs

`AXI-GPIO` - IP for GPIO communication between hardware and software