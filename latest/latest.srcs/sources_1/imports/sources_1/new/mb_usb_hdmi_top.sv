// ============================================================
//  mb_usb_hdmi_top.sv
//  Top-level design for the Run 3 on the
//  Real Digital Urbana board. Connects the MicroBlaze USB keyboard block,
//  VGA timing, sprite physics, pixel compositing, and HDMI output
//  into one playable system.
//
//  Instantiates: mb_block (USB/UART), clk_wiz_0, vga_controller,
//  hdmi_tx_0, sprite, color_mapper, and two hex_driver displays.
//
//  Inputs:
//    Clk, reset_rtl_0           - 100 MHz board clock and reset.
//    gpio_usb_int_tri_i         - USB controller interrupt.
//    gpio_usb_rst_tri_o         - USB controller reset.
//    usb_spi_miso/mosi/sclk/ss  - SPI link to the USB keyboard chip.
//    uart_rtl_0_rxd/txd         - UART debug/console lines.
//
//  Outputs:
//    hdmi_tmds_clk_p/n          - Differential HDMI clock.
//    hdmi_tmds_data_p/n [2:0]   - Differential HDMI data lanes.
//    hex_segA, hex_gridA        - 7-segment display A (shows level).
//    hex_segB, hex_gridB        - 7-segment display B (shows keycode).
// ============================================================


module mb_usb_hdmi_top(
    input logic Clk,
    input logic reset_rtl_0,
    
    //USB signals
    input logic [0:0] gpio_usb_int_tri_i,
    output logic gpio_usb_rst_tri_o,
    input logic usb_spi_miso,
    output logic usb_spi_mosi,
    output logic usb_spi_sclk,
    output logic usb_spi_ss,
    
    //UART
    input logic uart_rtl_0_rxd,
    output logic uart_rtl_0_txd,
    
    //HDMI
    output logic hdmi_tmds_clk_n,
    output logic hdmi_tmds_clk_p,
    output logic [2:0]hdmi_tmds_data_n,
    output logic [2:0]hdmi_tmds_data_p,
        
    //HEX displays
    output logic [7:0] hex_segA,
    output logic [3:0] hex_gridA,
    output logic [7:0] hex_segB,
    output logic [3:0] hex_gridB
);
    
    logic [31:0] keycode0_gpio, keycode1_gpio;
    logic clk_25MHz, clk_125MHz, clk, clk_100MHz;
    logic locked;
    logic [9:0] drawX, drawY, SpriteX, SpriteY, ballsizesig;

    logic hsync, vsync, vde;
    logic [3:0] red, green, blue;
    logic reset_ah;
    
    logic lizard;
    
    assign reset_ah = reset_rtl_0;
    
    // sprites
    logic [11:0] rom_address;
    logic [1:0] rom_q;
        
    logic negedge_vga_clk;   
    
//    logic [15:0] walls;
    logic [3:0] perspective;
//    assign walls = 16'b1111111111111111;
    
    logic falling;
    logic [7:0] curr_frame, level;
    logic [15:0] curr_walls;
        
    //Keycode HEX drivers
    hex_driver HexA (
        .clk(Clk),
        .reset(reset_ah),
        .in('{4'h0, 4'h0, level[7:4], level[3:0]}),  // 4 nibbles
        .hex_seg(hex_segA),
        .hex_grid(hex_gridA)
    );
    
    hex_driver HexB (
        .clk(Clk),
        .reset(reset_ah),
        .in({keycode0_gpio[15:12], keycode0_gpio[11:8], keycode0_gpio[7:4], keycode0_gpio[3:0]}),
        .hex_seg(hex_segB),
        .hex_grid(hex_gridB)
    );
    
    mb_block mb_block_i (
        .clk_100MHz(Clk),
        .gpio_usb_int_tri_i(gpio_usb_int_tri_i),
        .gpio_usb_keycode_0_tri_o(keycode0_gpio),
        .gpio_usb_keycode_1_tri_o(keycode1_gpio),
        .gpio_usb_rst_tri_o(gpio_usb_rst_tri_o),
        .reset_rtl_0(~reset_ah), //Block designs expect active low reset, all other modules are active high
        .uart_rtl_0_rxd(uart_rtl_0_rxd),
        .uart_rtl_0_txd(uart_rtl_0_txd),
        .usb_spi_miso(usb_spi_miso),
        .usb_spi_mosi(usb_spi_mosi),
        .usb_spi_sclk(usb_spi_sclk),
        .usb_spi_ss(usb_spi_ss)
    );
        
    //clock wizard configured with a 1x and 5x clock for HDMI
    clk_wiz_0 clk_wiz (
        .clk_out1(clk_25MHz),
        .clk_out2(clk_125MHz),
        .reset(reset_ah),
        .locked(locked),
        .clk_in1(Clk)
    );
    
    //VGA Sync signal generator
    vga_controller vga (
        .pixel_clk(clk_25MHz),
        .reset(reset_ah),
        .hs(hsync),
        .vs(vsync),
        .active_nblank(vde),
        .drawX(drawX),
        .drawY(drawY)
    );    

    //Real Digital VGA to HDMI converter
    hdmi_tx_0 vga_to_hdmi (
        //Clocking and Reset
        .pix_clk(clk_25MHz),
        .pix_clkx5(clk_125MHz),
        .pix_clk_locked(locked),
        .rst(reset_ah),
        //Color and Sync Signals
        .red(red),
        .green(green),
        .blue(blue),
        .hsync(hsync),
        .vsync(vsync),
        .vde(vde),
        
        //aux Data (unused)
        .aux0_din(4'b0),
        .aux1_din(4'b0),
        .aux2_din(4'b0),
        .ade(1'b0),
        
        //Differential outputs
        .TMDS_CLK_P(hdmi_tmds_clk_p),          
        .TMDS_CLK_N(hdmi_tmds_clk_n),          
        .TMDS_DATA_P(hdmi_tmds_data_p),         
        .TMDS_DATA_N(hdmi_tmds_data_n)          
    );

    //Ball Module
    sprite alien_instance(
        .Reset(reset_ah),
        .lizard(lizard),
        .frame_clk(vsync),                    //Figure out what this should be so that the ball will move
        .walls(curr_walls),
        .keycode(keycode0_gpio[7:0]),    //Notice: only one keycode connected to ball by default
        .keycode2(keycode0_gpio[15:8]),
        .SpriteX(SpriteX),
        .SpriteY(SpriteY),
        .curr_frame(curr_frame),
        .level(level),
        .Perspective(perspective),
        .SpriteY_Motion_msb(falling)
//        .BallS(ballsizesig)
    );
    
    logic [3:0] lvlcolor_red;
    logic [3:0] lvlcolor_blue;
    logic [3:0] lvlcolor_green;

    always_comb begin
        case (level[1:0])
            2'b00: begin 
                lvlcolor_red   = 4'hf;
                lvlcolor_green = 4'h0;
                lvlcolor_blue  = 4'h0;
            end
            2'b01: begin // Level 1: Greenish
                lvlcolor_red   = 4'h0;
                lvlcolor_green = 4'hf;
                lvlcolor_blue  = 4'h0;
            end
            2'b10: begin // Level 2: Bluish
                lvlcolor_red   = 4'h0;
                lvlcolor_green = 4'h0;
                lvlcolor_blue  = 4'hf;
            end
            2'b11: begin // Level 3: Yellow/Gold
                lvlcolor_red   = 4'hf;
                lvlcolor_green = 4'hd;
                lvlcolor_blue  = 4'h0;
            end
            default: begin 
                lvlcolor_red   = 4'hf;
                lvlcolor_green = 4'h0;
                lvlcolor_blue  = 4'h0;
            end
        endcase
    end

    //Color Mapper Module   
    color_mapper color_instance(
        .clk(clk_25MHz),
        .reset(reset_ah),
        .vsync(vsync),
        .keycode(keycode0_gpio[7:0]),
        .perspective(perspective),
        .lvlcolor_red(lvlcolor_red),
        .lvlcolor_green(lvlcolor_green),
        .lvlcolor_blue(lvlcolor_blue),
        .curr_frame(curr_frame),
        .SpriteX(SpriteX),
        .SpriteY(SpriteY),
        .falling(~falling),
        .DrawX(drawX),
        .DrawY(drawY),
        .curr_walls(curr_walls),
        .Red(red),
        .Green(green),
        .Blue(blue),
        .lizard(lizard)
    );
    
    // sprite stuff

    // read from ROM on negedge, set pixel on posedge
//    assign rom_address = ((drawX * 64) / 640) + (((drawY * 48) / 480) * 64);  
    
endmodule
