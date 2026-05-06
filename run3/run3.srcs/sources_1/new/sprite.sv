`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/29/2026 05:50:15 PM
// Design Name: 
// Module Name: sprite
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module sprite(
    input  logic        Reset,
    input  logic        frame_clk,
    input  logic [7:0]  keycode,
    input  logic [15:0]  walls,
                              
    output logic [9:0]  SpriteX,
    output logic [9:0]  SpriteY,
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
    parameter signed [10:0] Gravity      =  1;




    // W = 26 (1A), A = 4 (4), S = 22 (16), D = 7 (7)
    always_comb
    begin
        SpriteY_Motion_next = SpriteY_Motion;
        SpriteX_next = SpriteX;

        if (SpriteY >= SpriteY_Max)
            SpriteY_Motion_next = 11'sd0;
        else if (SpriteY >= SpriteY_Min)
            SpriteY_Motion_next = SpriteY_Motion + Gravity;

        if (keycode == 8'h1A) begin                         // W - jump
            if (walls[4 + floor_index] == 1'b1 && SpriteY >= SpriteY_Max)
                SpriteY_Motion_next = JumpVelocity;

        end 
//        else if (keycode == 8'h16 && SpriteY < SpriteY_Max) begin                // S - accelerate down
//            SpriteY_Motion_next = SpriteY_Step;
//        end

        if (keycode == 8'h4) begin
            SpriteX_next = SpriteX - 2'b10;
        end
        if (keycode == 8'h7) begin
            SpriteX_next = SpriteX + 2'b10;
        end
    end


    assign SpriteY_next = $signed({1'b0, SpriteY}) + SpriteY_Motion_next;

    assign SpriteY_Motion_msb = SpriteY_Motion_next[10];    


/*
    logic [3:0] shifted_walls;

    always_comb begin
        case (Perspective)
            4'b0100: // Base orientation - No change
                shifted_walls = walls;
            
            4'b1000: // Right shift once (Circular)
                shifted_walls = {walls[0], walls[3:1]};
            
            4'b0010: // Left shift once (Circular)
                shifted_walls = {walls[2:0], walls[3]};
            
            4'b0001: // Left shift twice (Circular)
                shifted_walls = {walls[1:0], walls[3:2]};
            
            default: // Default case for safety
                shifted_walls = walls;
        endcase
    end
*/

    always_comb begin
        if (SpriteX < SpriteX_Min + 50)  
            floor_index = 2'b00;
        else if (SpriteX < SpriteX_Min + 100) 
            floor_index = 2'b01;
        else if (SpriteX < SpriteX_Min + 150) 
            floor_index = 2'b10;
        else                                   
            floor_index = 2'b11;
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

    always_ff @(posedge frame_clk)
    begin: Move_Sprite
        if (Reset) begin
            SpriteX        <= SpriteX_Center;
            SpriteY        <= SpriteY_Center;
            SpriteY_Motion <= 11'sd0;
            Perspective    <= 4'b0100;          // Starting orientation
        end
        else if (((SpriteY >= SpriteY_Max) && (walls[4 + floor_index] == 1'b0)) || (((SpriteX <= SpriteX_Min) && (walls[8 + wall_index] == 1'b0)) || ((SpriteX >= SpriteX_Max) && (walls[wall_index] == 1'b0))))
        begin
        	SpriteY_Motion <= SpriteY_Motion_next;

            SpriteX <= SpriteX_Center;
            SpriteY <= SpriteY_Center;
        end
        else if (((SpriteX >= SpriteX_Min) && (SpriteX <= SpriteX_Max)))   // Consider adding a "alive" condition alive = ((if SpriteY == SpriteY_Min && no floor) || ((SpriteX <= SpriteX_Min && no wall) && (SpriteX >= SpriteX_Max && no wall)))
        begin   // If alive do this, otherwise stop motion and cut to death screen or smth
        	SpriteY_Motion <= SpriteY_Motion_next;
            
            SpriteY <= SpriteY_next;
            SpriteX <= SpriteX_next;

        end
        else if (((SpriteX <= SpriteX_Min) && (walls[8 + wall_index] == 1'b1))) begin
            SpriteY_Motion <= SpriteY_Motion_next;

            SpriteX <= SpriteX_Min + (200 - (SpriteY_Max - SpriteY_next));
            SpriteY <= SpriteY_Max;

            Perspective <= {Perspective[0], Perspective[3:1]};
        end
        else if (((SpriteX >= SpriteX_Max) && (walls[wall_index] == 1'b1))) begin
            SpriteY_Motion <= SpriteY_Motion_next;

            SpriteX <= SpriteX_Min + (SpriteY_Max - SpriteY_next);
            SpriteY <= SpriteY_Max;

            Perspective <= {Perspective[2:0], Perspective[3]};
        end
    end

endmodule