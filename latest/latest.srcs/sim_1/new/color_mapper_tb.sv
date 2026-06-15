// ============================================================
//  color_mapper_tb.sv
//  Testbench for color_mapper (stars background + alien sprite)
//
//  Simulates one full VGA frame (640x480 active pixels within
//  the 800x525 total timing window) by driving the vga_controller
//  directly - no AXI, no BRAM, no IP wrappers needed.
//
//  At the end of the first complete frame the testbench writes
//  a 24-bit BMP file called "color_mapper_sim.bmp" that shows
//  the tiled star background with the alien sprite centred at
//  (320, 240).
//
//  Modules required in the same compile unit / project:
//    vga_controller.sv
//    color_mapper.sv
//    stars_rom.sv
//    alien_rom.sv
//    alien_palette.sv
// ============================================================

`timescale 1ns / 1ps

module color_mapper_tb ();

    // --------------------------------------------------------
    // Clock & reset
    // --------------------------------------------------------
    // Real hardware uses 25 MHz pixel clock.
    // We keep the same period here so timing relationships
    // between vga_controller and color_mapper are realistic,
    // but you can speed it up by reducing CLK_HALF_PERIOD.
    localparam CLK_HALF_PERIOD = 20; // 20 ns half-period ? 25 MHz

    logic clk   = 1'b0;
    logic reset = 1'b1;

    always #CLK_HALF_PERIOD clk = ~clk;

    // --------------------------------------------------------
    // VGA controller outputs
    // --------------------------------------------------------
    logic        hs, vs, active_nblank, sync_unused;
    logic [9:0]  drawX, drawY;

    // --------------------------------------------------------
    // Sprite position - fixed at centre for the still frame
    // --------------------------------------------------------
    // color_mapper uses ?SpriteW / ?SpriteH around (SpriteX, SpriteY)
    // to decide when the sprite is active.  SpriteW=64, SpriteH=48 in
    // color_mapper.  To place the alien centred at (320,240) we set:
    //   SpriteX = 320, SpriteY = 240
    // The sprite_on region will therefore span roughly
    //   X ? [256, 384],  Y ? [192, 288]  (centre ? half-sprite)
    // SpriteX / SpriteY are now driven by the sprite module (same as top level)
    logic [9:0]  SpriteX, SpriteY;

    // --------------------------------------------------------
    // color_mapper outputs
    // --------------------------------------------------------
    logic [3:0] Red, Green, Blue;

    // --------------------------------------------------------
    // BMP capture array (800 ? 525, 24-bit BGR each pixel)
    // --------------------------------------------------------
    localparam BMP_WIDTH  = 800;
    localparam BMP_HEIGHT = 525;
    logic [23:0] bitmap [BMP_WIDTH][BMP_HEIGHT];

    integer i, j;

    // --------------------------------------------------------
    // Module instantiations
    // --------------------------------------------------------

    vga_controller vga_inst (
        .pixel_clk    (clk),
        .reset        (reset),
        .hs           (hs),
        .vs           (vs),
        .active_nblank(active_nblank),
        .sync         (sync_unused),
        .drawX        (drawX),
        .drawY        (drawY)
    );

    // --------------------------------------------------------
    // Sprite inputs (mirrors top-level wiring)
    // --------------------------------------------------------
    logic [7:0]  keycode_tb  = 8'h00;   // drive with desired USB keycode
    logic [15:0] walls_tb    = 16'hFFFF; // all walls/floors present
    logic [7:0]  curr_frame;
    logic [3:0]  perspective;
    logic        falling_msb;            // SpriteY_Motion_msb from sprite
    logic        falling;                // ~falling_msb -> color_mapper

    assign falling = ~falling_msb;

    // vs is the frame clock, matching the top-level connection
    sprite alien_instance (
        .Reset            (reset),
        .frame_clk        (vs),          // frame_clk = vsync, same as top level
        .walls            (walls_tb),
        .keycode          (keycode_tb),
        .SpriteX          (SpriteX),
        .SpriteY          (SpriteY),
        .curr_frame       (curr_frame),
        .Perspective      (perspective),
        .SpriteY_Motion_msb(falling_msb)
    );

    color_mapper dut (
        .clk    (clk),
        .SpriteX(SpriteX),
        .SpriteY(SpriteY),
        .falling(falling),
        .DrawX  (drawX),
        .DrawY  (drawY),
        .Red    (Red),
        .Green  (Green),
        .Blue   (Blue)
    );

    // --------------------------------------------------------
    // BMP writer task  (same format as the sample testbench)
    // --------------------------------------------------------
    task automatic save_bmp (input string filename);
        integer fptr;
        integer unsigned BMP_row_size;
        logic unsigned [31:0] BMP_header [0:12];

        begin
            BMP_row_size = 32'(BMP_WIDTH) & 32'hFFFC;
            if ((BMP_WIDTH & 32'd3) != 0)
                BMP_row_size = BMP_row_size + 4;

            fptr = $fopen(filename, "wb");
            if (fptr == 0) begin
                $display("ERROR: could not open '%s' for writing.", filename);
                $stop;
            end
            $display("Saving bitmap '%s' ?", filename);

            // File-size field in header
            BMP_header[0:12] = '{
                32'(BMP_row_size * BMP_HEIGHT * 3 + 54), // file size
                32'd0,                                    // reserved
                32'd54,                                   // pixel data offset
                32'd40,                                   // DIB header size
                32'(BMP_WIDTH),                           // image width
                32'(BMP_HEIGHT),                          // image height
                {16'd24, 16'd1},                          // bpp=24, planes=1
                32'd0,                                    // no compression
                32'(BMP_row_size * BMP_HEIGHT * 3),       // image size
                32'd2835,                                  // X ppm
                32'd2835,                                  // Y ppm
                32'd0,                                    // colours in table
                32'd0                                     // important colours
            };

            $fwrite(fptr, "BM");
            for (int h = 0; h < 13; h++)
                $fwrite(fptr, "%c%c%c%c",
                    BMP_header[h][ 7 -:8],
                    BMP_header[h][15 -:8],
                    BMP_header[h][23 -:8],
                    BMP_header[h][31 -:8]);

            // BMP rows are stored bottom-to-top
            for (int y = BMP_HEIGHT - 1; y >= 0; y--)
                for (int x = 0; x < BMP_WIDTH; x++)
                    // BMP pixel order is BGR
                    $fwrite(fptr, "%c%c%c",
                        bitmap[x][y][23:16],   // B
                        bitmap[x][y][15: 8],   // G
                        bitmap[x][y][ 7: 0]);  // R

            $fclose(fptr);
            $display("Done writing '%s'.", filename);
        end
    endtask

    // --------------------------------------------------------
    // Pixel capture:  record every active pixel into bitmap[]
    //
    // color_mapper registers sprite_on for one cycle, so the
    // RGB outputs are valid on the cycle *after* drawX/drawY
    // are presented.  We therefore sample on posedge clk and
    // use the registered drawX/drawY (one cycle delayed) so
    // that pixel coordinates and RGB stay aligned.
    // --------------------------------------------------------
    logic [9:0] drawX_d, drawY_d;
    logic        active_d;

    always_ff @(posedge clk) begin
        drawX_d  <= drawX;
        drawY_d  <= drawY;
        active_d <= active_nblank;
    end

    always_ff @(posedge clk) begin
        if (active_d && drawX_d < BMP_WIDTH && drawY_d < BMP_HEIGHT)
            // BMP24 stores pixels as BGR
            bitmap[drawX_d][drawY_d] <=
                { {Blue,  4'h0},   // byte 2 ? B (4-bit ? 8-bit)
                  {Green, 4'h0},   // byte 1 ? G
                  {Red,   4'h0} }; // byte 0 ? R
    end

    // --------------------------------------------------------
    // Stimulus / control
    // --------------------------------------------------------
    // One complete VGA frame = 800 ? 525 pixel-clock cycles.
    // We wait for two rising edges of vs (falling edge of vs
    // marks the end of one frame and the start of the vertical
    // sync pulse of the next).
    // --------------------------------------------------------

    initial begin : INIT_BITMAP
        // Pre-fill with a distinctive grey so we can see the
        // difference between "no pixel written" and black.
        for (j = 0; j < BMP_HEIGHT; j++)
            for (i = 0; i < BMP_WIDTH; i++)
                bitmap[i][j] = 24'h1A1A1A;
    end

    initial begin : STIMULUS
        // ---- reset ----
        reset = 1'b1;
        repeat (8) @(posedge clk);
        reset = 1'b0;
        
        // Force sprite_select to the frame you want to test
        // 0 = standing, 1 = left foot, 2 = right foot
        force dut.sprite_select = 2'b00;

        $display("Reset released - waiting for one complete frame ?");

        // Wait for first vs falling edge (start of vsync pulse)
        @(negedge vs);
        $display("First vsync detected - frame capture in progress ?");

        // Wait for vs to go high again (end of vsync pulse,
        // beginning of the active frame we want to capture)
        @(posedge vs);

        // Now wait for the *next* vs falling edge - by then the
        // entire active frame has been rendered and stored in bitmap[]
        @(negedge vs);
        $display("Frame complete - writing BMP ?");

        release dut.sprite_select;

        save_bmp("color_mapper_sim.bmp");
        $finish;
    end

endmodule