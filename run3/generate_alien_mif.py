from PIL import Image

img = Image.open("alien.png").convert("RGB")
w, h = img.size

with open("sprite.mif", "w") as f:
    f.write(f"WIDTH=12;\n")          # e.g. 4 bits R, 4 bits G, 4 bits B
    f.write(f"DEPTH={w*h};\n")
    f.write("ADDRESS_RADIX=UNS;\n")
    f.write("DATA_RADIX=HEX;\n")
    f.write("CONTENT BEGIN\n")
    for i, (r, g, b) in enumerate(img.getdata()):
        # Quantize to 4-bit per channel (12-bit color)
        r4 = r >> 4
        g4 = g >> 4
        b4 = b >> 4
        packed = (r4 << 8) | (g4 << 4) | b4
        f.write(f"  {i} : {packed:03X};\n")
    f.write("END;\n")