from PIL import Image

img = Image.open("alien.png").convert("RGBA")
w, h = img.size
num_frames = 4  # however many frames in your spritesheet
frame_w = w // num_frames

with open("sprite_rom.sv", "w") as f:
    f.write("module sprite_rom (\n")
    f.write("    input  logic        clk,\n")
    f.write("    input  logic [11:0] addr,\n")  # adjust width as needed
    f.write("    output logic [11:0] data\n")   # 12-bit color (4R 4G 4B)
    f.write(");\n\n")
    f.write("    logic [11:0] mem [0:{}];\n\n".format(w * h - 1))
    f.write("    initial begin\n")

    for i, (r, g, b, a) in enumerate(img.getdata()):
        if a < 128:  # transparent pixel -> magic color
            packed = 0xF0F
        else:
            r4 = r >> 4
            g4 = g >> 4
            b4 = b >> 4
            packed = (r4 << 8) | (g4 << 4) | b4
        f.write(f"        mem[{i}] = 12'h{packed:03X};\n")

    f.write("    end\n\n")
    f.write("    always_ff @(posedge clk) begin\n")
    f.write("        data <= mem[addr];\n")
    f.write("    end\n\n")
    f.write("endmodule\n")