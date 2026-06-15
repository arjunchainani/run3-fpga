// ============================================================
//  sprite.sv
//  Player sprite controller for the alien platformer game.
//  Updates position each frame from keyboard input, applies
//  gravity and jumping, checks wall/floor collisions, rotates
//  perspective at screen edges, and advances level/frame counters.
//
//  Inputs:
//    Reset              - Active-high reset to center the sprite.
//    frame_clk          - Once-per-frame clock (typically vsync).
//    lizard             - Selects lizard mode (stronger jump).
//    keycode, keycode2  - USB keycodes for WASD movement/jump.
//    walls [15:0]       - Current frame wall bitmask from levels_rom.
//
//  Outputs:
//    SpriteX, SpriteY [9:0] - Top-left pixel coordinates on screen.
//    curr_frame [7:0]       - Animation frame index.
//    level [7:0]            - Current level number.
//    Perspective [3:0]      - View orientation after edge wraps.
//    SpriteY_Motion_msb     - Falling indicator (vertical motion sign).
// ============================================================

`timescale 1ns / 1ps

module sprite(
    input  logic        Reset,
    input  logic        frame_clk,
    input  logic lizard,
    input  logic [7:0]  keycode,
    input  logic [7:0]  keycode2,
    input  logic [15:0] walls,
                              
    output logic [9:0]  SpriteX,
    output logic [9:0]  SpriteY,
    output logic [7:0]  curr_frame, level,
    output logic [3:0]  Perspective,
    output logic SpriteY_Motion_msb
    );
    
    logic [9:0]  SpriteH;
    logic [9:0]  SpriteW;

    logic signed [10:0] SpriteY_Motion;
    logic signed [10:0] SpriteY_Motion_next;

    logic signed [10:0] SpriteY_next;
    logic [9:0] SpriteX_next;

    logic [1:0] wall_index;    
    logic [1:0] floor_index;

    logic [3:0] sub_counter;
    logic [5:0] frame_counter;
    
//    logic [1:0] gravity_counter;  // counts 0-3, adjust size for more frames

    assign SpriteH = 24;
    assign SpriteW = 32;

    
    parameter [9:0] SpriteX_Center = 288; 
    parameter [9:0] SpriteY_Center = 216;
    parameter [10:0] SpriteY_Max = 312;
    parameter [9:0] SpriteX_Max = 388;
    parameter [10:0] SpriteY_Min = 112;
    parameter [9:0] SpriteX_Min = 188; 
    parameter [10:0] SpriteY_Step = 1;
    parameter signed [10:0] JumpVelocity = -16;
    parameter signed [10:0] LizardVelocity = -20; 
    parameter signed [10:0] Gravity      =  1;

    parameter [8:0] max_level = 10;

    // W = 26 (1A), A = 4 (4), S = 22 (16), D = 7 (7)
    always_comb
    begin
        SpriteY_Motion_next = SpriteY_Motion;
        SpriteX_next = SpriteX;

        if (SpriteY >= SpriteY_Max)
            SpriteY_Motion_next = 11'sd0;
        else
//            SpriteY_Motion_next = (gravity_counter == 2'd0) ? SpriteY_Motion + Gravity : SpriteY_Motion;
            SpriteY_Motion_next = SpriteY_Motion + Gravity;

        if (keycode == 8'h1A && keycode2 == 8'h4) begin
            SpriteX_next = SpriteX - 2'b10;
            if (walls[4 + floor_index] == 1'b1 && SpriteY >= SpriteY_Max && (lizard == 1'b0))
                SpriteY_Motion_next = JumpVelocity;
            else if (walls[4 + floor_index] == 1'b1 && SpriteY >= SpriteY_Max && (lizard == 1'b1))
                SpriteY_Motion_next = LizardVelocity;
        end 


        else if (keycode == 8'h1A && keycode2 == 8'h7) begin
            SpriteX_next = SpriteX + 2'b10;
            if (walls[4 + floor_index] == 1'b1 && SpriteY >= SpriteY_Max && (lizard == 1'b0))
                SpriteY_Motion_next = JumpVelocity;
            else if (walls[4 + floor_index] == 1'b1 && SpriteY >= SpriteY_Max && (lizard == 1'b1))
                SpriteY_Motion_next = LizardVelocity;
        end

        else if (keycode == 8'h1A) begin                         // W - jump
            if (walls[4 + floor_index] == 1'b1 && SpriteY >= SpriteY_Max && (lizard == 1'b0))
                SpriteY_Motion_next = JumpVelocity;
            else if (walls[4 + floor_index] == 1'b1 && SpriteY >= SpriteY_Max && (lizard == 1'b1))
                SpriteY_Motion_next = LizardVelocity;
        end 
//        else if (keycode == 8'h16 && SpriteY < SpriteY_Max) begin                // S - accelerate down
//            SpriteY_Motion_next = SpriteY_Step;
//        end

        else if (keycode == 8'h4) begin
            SpriteX_next = SpriteX - 2'b10;
        end
        else if (keycode == 8'h7) begin
            SpriteX_next = SpriteX + 2'b10;
        end
    end


    assign SpriteY_next = $signed({1'b0, SpriteY}) + SpriteY_Motion_next;

    assign SpriteY_Motion_msb = SpriteY_Motion_next[10];    

    always_comb begin
        if (SpriteX < SpriteX_Min + 50)  
            floor_index = 2'b11;
        else if (SpriteX < SpriteX_Min + 100) 
            floor_index = 2'b10;
        else if (SpriteX < SpriteX_Min + 150) 
            floor_index = 2'b01;
        else                                   
            floor_index = 2'b00;
    end

    always_comb begin
        if (SpriteY < SpriteY_Min + 50)  
            wall_index = 2'b00;
        else if (SpriteY < SpriteY_Min + 100) 
            wall_index = 2'b01;
        else if (SpriteY < SpriteY_Min + 150) 
            wall_index = 2'b10;
        else                                   
            wall_index = 2'b11;
    end

    always_ff @(posedge frame_clk or posedge Reset)
    begin: Move_Sprite
        if (Reset) begin
            SpriteX        <= SpriteX_Center;
            SpriteY        <= SpriteY_Center;
            SpriteY_Motion <= 11'sd0;
            Perspective    <= 4'b0100;          // Starting orientation
            level <= 8'b0;
            curr_frame <= 8'b0;
            sub_counter <= 4'd0;
            frame_counter <= 6'd0;
//            gravity_counter <= 2'd0;
        end
        else if (((SpriteX >= SpriteX_Min) && (SpriteX <= SpriteX_Max)) && (((SpriteY >= SpriteY_Max) && (walls[4 + floor_index] == 1'b1)) || (SpriteY < SpriteY_Max)))   // Consider adding a "alive" condition alive = ((if SpriteY == SpriteY_Min && no floor) || ((SpriteX <= SpriteX_Min && no wall) && (SpriteX >= SpriteX_Max && no wall)))
        begin   // If alive do this, otherwise stop motion and cut to death screen or smth
        	SpriteY_Motion <= SpriteY_Motion_next;
//            gravity_counter <= gravity_counter + 2'd1;
            
            SpriteY <= SpriteY_next;
            SpriteX <= SpriteX_next;

            if (frame_counter == 6'd23) begin
                frame_counter <= 6'b0;
                curr_frame <= curr_frame + 1'b1;
            
                // Only count a level tick when curr_frame actually advances
                if (sub_counter == 4'd7) begin
                    sub_counter <= 4'd0;
                    level <= level + 8'b1;
                end else begin
                    sub_counter <= sub_counter + 4'd1;
                end
            end
            else begin
                frame_counter <= frame_counter + 1'b1;
            end        
        end
        else if (((SpriteX < SpriteX_Min) && (walls[8 + wall_index] == 1'b1))) begin
            SpriteY_Motion <= SpriteY_Motion_next;

            SpriteX <= SpriteX_Min + (200 - (SpriteY_Max - SpriteY_next));
            SpriteY <= SpriteY_Max;

            Perspective <= {Perspective[0], Perspective[3:1]};

            if (frame_counter == 6'd23) begin
                frame_counter <= 6'b0;
                curr_frame <= curr_frame + 1'b1;
            
                // Only count a level tick when curr_frame actually advances
                if (sub_counter == 4'd7) begin
                    sub_counter <= 4'd0;
                    level <= level + 8'b1;
                end else begin
                    sub_counter <= sub_counter + 4'd1;
                end
            end
            else begin
                frame_counter <= frame_counter + 1'b1;
            end
            
        end
        else if (((SpriteX > SpriteX_Max) && (walls[wall_index] == 1'b1))) begin
            SpriteY_Motion <= SpriteY_Motion_next;

            SpriteX <= SpriteX_Min + (SpriteY_Max - SpriteY_next);
            SpriteY <= SpriteY_Max;

            Perspective <= {Perspective[2:0], Perspective[3]};

            if (frame_counter == 6'd23) begin
                frame_counter <= 6'b0;
                curr_frame <= curr_frame + 1'b1;
            
                // Only count a level tick when curr_frame actually advances
                if (sub_counter == 4'd7) begin
                    sub_counter <= 4'd0;
                    level <= level + 8'b1;
                end else begin
                    sub_counter <= sub_counter + 4'd1;
                end
            end
            else begin
                frame_counter <= frame_counter + 1'b1;
            end
        end
        else begin // death
            SpriteY_Motion <= 11'sd0;

            SpriteX <= SpriteX_Center;
            SpriteY <= SpriteY_Max;

            curr_frame <= (level * 8);
            frame_counter <= 6'b0;
            sub_counter <= 4'd0;
            Perspective    <= 4'b0100;            
        end
    end

endmodule