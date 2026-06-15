`timescale 1ns / 1ps
// ============================================================
//  alien_palette.sv
//  Combinational palette lookup for the alien sprite ROM.
//  Converts a 2-bit pixel index from alien_rom into 4-bit RGB
//  values. Index 0 is treated as transparent (sentinel color
//  0xF00, skipped by color_mapper). Lizard mode swaps the gray
//  alien colors for green tones.
//
//  Inputs:
//    index [1:0]  - Palette index from alien_rom (0 = transparent).
//    lizard       - Select lizard color scheme when high.
//
//  Outputs:
//    red, green, blue [3:0] - 4-bit RGB for the indexed pixel.
// ============================================================

module alien_palette (
    input  logic [1:0] index,
    input  logic lizard,
    output logic [3:0] red, green, blue
);

    always_comb begin
        if (~lizard) begin
            case (index)
                2'd0: {red, green, blue} = {4'hf, 4'h0, 4'h0};  // transparent
                2'd1: {red, green, blue} = {4'h9, 4'h9, 4'h9};  // RGB(153,153,153)
                2'd2: {red, green, blue} = {4'h4, 4'h4, 4'h4};  // RGB(73,73,73)
    //            2'd1: {red, green, blue} = {4'hf, 4'h0, 4'h0};  // RGB(153,153,153)
    //            2'd2: {red, green, blue} = {4'hf, 4'h0, 4'h0};  // RGB(73,73,73)
                2'd3: {red, green, blue} = {4'hf, 4'h0, 4'h0};  // RGB(2,2,2)
                default: {red, green, blue} = 12'h000;
            endcase
        end
        else begin
            case (index)
                2'd0: {red, green, blue} = {4'hf, 4'h0, 4'h0};  // transparent
                2'd1: {red, green, blue} = {4'h0, 4'h9, 4'h0};  // RGB(0,153,0)
                2'd2: {red, green, blue} = {4'h0, 4'h3, 4'h0};  // RGB(0,51,0)
    //            2'd1: {red, green, blue} = {4'hf, 4'h0, 4'h0};  // RGB(153,153,153)
    //            2'd2: {red, green, blue} = {4'hf, 4'h0, 4'h0};  // RGB(73,73,73)
                2'd3: {red, green, blue} = {4'hf, 4'h0, 4'h0};  // RGB(2,2,2)
            default: {red, green, blue} = 12'h000;
            endcase
        end
    end

endmodule
