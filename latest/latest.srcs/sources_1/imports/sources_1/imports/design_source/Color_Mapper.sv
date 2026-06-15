// ============================================================
//  Color_Mapper.sv
//  Per-pixel RGB compositor for the alien platformer display.
//  Each clock cycle selects a color for (DrawX, DrawY) by layering,
//  in priority order: the animated alien sprite, solid level walls,
//  the tiled starfield background, or black.
//
//  Also reads levels_rom to supply wall data to the sprite module,
//  rotates wall layouts based on perspective, toggles lizard mode
//  on key press, and cycles sprite animation frames on vsync.
//
//  Inputs:
//    clk, reset, vsync          - Pixel clock, reset, vertical sync.
//    falling                    - Sprite is moving downward (falling).
//    keycode [7:0]              - USB keycode (8 toggles lizard mode).
//    perspective [3:0]          - View rotation from sprite edge-wrap.
//    lvlcolor_red/green/blue    - Base wall tint for the current level.
//    curr_frame [7:0]           - Animation frame from sprite module.
//    SpriteX, SpriteY [9:0]     - Sprite top-left screen position.
//    DrawX, DrawY [9:0]         - Current pixel coordinates from VGA.
//
//  Outputs:
//    curr_walls [15:0]          - Perspective-corrected wall bitmask
//                                 forwarded to the sprite module.
//    lizard                     - Lizard mode flag (toggled by key 8).
//    Red, Green, Blue [3:0]     - 4-bit RGB for the current pixel.
// ============================================================


module  color_mapper ( input  logic clk,
                       input  logic reset,
                       input  logic vsync,
                       input  logic falling,
                       input  logic [7:0] keycode,
                       input  logic [3:0] perspective, lvlcolor_red, lvlcolor_green, lvlcolor_blue,
                       input  logic [7:0] curr_frame,
                       input  logic [9:0] SpriteX, SpriteY, DrawX, DrawY,
                       output logic [15:0] curr_walls,
                       output logic lizard,
                       output logic [3:0] Red, Green, Blue );
    
//    (* mark_debug = "true" *) logic sprite_on;
//    (* mark_debug = "true" *) logic [9:0] DrawX_debug, DrawY_debug;
//    assign DrawX_debug = DrawX;
//    assign DrawY_debug = DrawY;    
    logic sprite_on;
    
    logic [3:0] palette_red, palette_green, palette_blue;

    logic [4:0][15:0] walls;
    
    logic sprite_on_d;
    // logic mem_array [0:4095];
    logic pixel_output;
    logic [7:0] pixel_data, panel_output;
    logic [11:0] stars_rom_addr, alien_rom_addr;
    logic [18:0] panel_rom_addr;
    logic [4:0] SpriteH;
    logic [4:0] SpriteW;
    logic [1:0] alien_output;
    
    // flip flop to cycle between sprite states on every edge of vsync (negative edge since vsync is active low)
    logic [1:0] sprite_select;
    logic [7:0] prev_keycode;
    
    parameter int ANIM_FRAMES = 8;
    int frame_counter;
    
    always_ff @(posedge vsync or posedge reset) begin
        if (reset) begin
            sprite_select <= 2'b00;
            frame_counter <= 0;
            lizard <= 1'b0;
            prev_keycode <= 8'h0;
        end
        else begin
            if (keycode == 8'h8 && prev_keycode != 8'h8) begin  // only on fresh press
                lizard <= ~lizard;
            end
        
            if (frame_counter == ANIM_FRAMES - 1) begin
                frame_counter <= 0;
                if (sprite_select == 2'b10)
                    sprite_select <= 2'b00;
                else
                    sprite_select <= sprite_select + 2'b01;
            end
            else begin
                frame_counter <= frame_counter + 1;
            end
        end
    end
    
    assign SpriteH = 48;
    assign SpriteW = 64;

    assign stars_rom_addr = (DrawY[5:0] << 6) + DrawX[5:0];
    assign alien_rom_addr = sprite_on
        ? ((DrawY - SpriteY) * 64 + (DrawX - SpriteX))
        : 12'd0;
    assign panel_rom_addr = (640 * DrawY + DrawX);        

    levels_rom level_rom0(
        .addr(curr_frame),
        .data_out(walls[0])
    );

    levels_rom level_rom1(
        .addr(curr_frame + 1),
        .data_out(walls[1])
    );

    levels_rom level_rom2(
        .addr(curr_frame + 2),
        .data_out(walls[2])
    );

    levels_rom level_rom3(
        .addr(curr_frame + 3),
        .data_out(walls[3])
    );

    levels_rom level_rom4(
        .addr(curr_frame + 4),
        .data_out(walls[4])
    );

    panel_rom_mem panel_rom(
        .addr(panel_rom_addr),
        .data_out(panel_output)
    );

    stars_rom stars_rom(
        .addr(stars_rom_addr),
        .data_out(pixel_output)
    );

    alien_rom alien_rom(
//        .clk(clk),
        .sprite_select(sprite_select),
        .SpriteY(SpriteY),
        .falling(falling),
        .lizard(lizard),
        .addr(alien_rom_addr),
        .q(alien_output)
    );

    alien_palette alien_palette (
//        .clk   (clk),
        .index (alien_output),
        .lizard (lizard),
        .red   (palette_red),
        .green (palette_green),
        .blue  (palette_blue)
    );

 /* Old Ball: Generated square box by checking if the current pixel is within a square of length
    2BallS, centered at (BallX, BallY).  Note that this requires unsigned comparisons.

    if ((DrawX >= BallX - Ball_size) &&
       (DrawX <= BallX + Ball_size) &&
       (DrawY >= BallY - Ball_size) &&
       (DrawY <= BallY + Ball_size))
       )

     New Ball: Generates (pixelated) circle by using the standard circle formula.  Note that while 
     this single line is quite powerful descriptively, it causes the synthesis tool to use up three
     of the 120 available multipliers on the chip!  Since the multiplicants are required to be signed,
      we have to first cast them from logic to int (signed by default) before they are multiplied)./
*/
//    int DistX, DistY, Size;
//    assign DistX = DrawX - BallX;
//    assign DistY = DrawY - BallY;
//    assign Size = Ball_size;

    // Sprite dimensions (match the ROM exactly)
    localparam SPRITE_W = 64;
    localparam SPRITE_H = 48;
    
    always_comb begin : sprite_on_proc
        if (DrawX >= SpriteX && DrawX < SpriteX + SPRITE_W &&
            DrawY >= SpriteY && DrawY < SpriteY + SPRITE_H)
            sprite_on = 1'b1;
        else
            sprite_on = 1'b0;
    end
    always_ff @(posedge clk) begin
        sprite_on_d <= sprite_on;
    end

    logic [4:0][15:0] shifted_walls; 

    always_comb begin
        for (int i = 0; i < 5; i++) begin
            case (perspective)
                4'b0100: // No shift
                    shifted_walls[i] = walls[i];

                4'b1000: // Right shift
                    shifted_walls[i] = {walls[i][11:0], walls[i][15:12]};

                4'b0010: // Left shift
                    shifted_walls[i] = {walls[i][3:0], walls[i][15:4]};

                4'b0001: // Left shift twice
                    shifted_walls[i] = {walls[i][7:0], walls[i][15:8]};

                default: 
                    shifted_walls[i] = walls[i];
            endcase
        end
    end

    assign curr_walls = shifted_walls[2];

    always_comb
    begin:RGB_Display
        if ((sprite_on_d == 1'b1) && ~(palette_red == 4'hf && palette_blue == 4'h0 && palette_green == 4'h0)) begin 
            Red = palette_red;
            Green = palette_green;
            Blue = palette_blue;
        end
        else if ((panel_output != 8'h51) && (shifted_walls[panel_output[6:4]][panel_output[3:0]] == 1'b1)) begin
            Red   = (lvlcolor_red   > curr_frame[2:0]) ? (lvlcolor_red   - curr_frame[2:0]) : 4'h0;
            Green = (lvlcolor_green > curr_frame[2:0]) ? (lvlcolor_green - curr_frame[2:0]) : 4'h0;
            Blue  = (lvlcolor_blue  > curr_frame[2:0]) ? (lvlcolor_blue  - curr_frame[2:0]) : 4'h0;  
        end          
        else if (pixel_output == 1'b1) begin
            Red = 4'hf; 
            Green = 4'hf;
            Blue = 4'hf;
        end
        else begin
            Red = 4'h0; 
            Green = 4'h0;
            Blue = 4'h0;
        end
    end
     

endmodule
