module alien_palette (
	input logic [1:0] index,
	output logic [3:0] red, green, blue
);

localparam [0:3][11:0] palette = {
	{4'hf, 4'hf, 4'hf}, // black to use as alien outline
	{4'h0, 4'hf, 4'h0}, // rgb(145, 144, 144) --> gray alien body color
	{4'hf, 4'h0, 4'h0}, // background -- red
	{4'hf, 4'h0, 4'h0} // 
};

assign {red, green, blue} = palette[index];

endmodule
