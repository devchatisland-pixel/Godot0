"""Builds textures/signs.png: one 1024x1024 sheet with every sign of the city.

Run from the project folder:  python3 tools/make_sign_atlas.py
Regions are listed in REGIONS and must match scripts/procedural/sign_atlas.gd.
Fonts: DejaVu Sans (free licence), from the system font folder.
"""
from PIL import Image, ImageDraw, ImageFilter, ImageFont

SIZE = 1024
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FONT_SERIF = "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"

# name: (x, y, w, h) in pixels
REGIONS = {
    "un_emblem": (0, 0, 256, 256),
    "dollar": (256, 0, 256, 256),
    "sign_post": (512, 0, 512, 128),
    "sign_museum": (512, 128, 512, 128),
    "neon_xxx": (0, 256, 512, 256),
    "neon_casino": (512, 256, 512, 256),
    "sign_hotel": (0, 512, 512, 128),
    "neon_bar": (0, 640, 512, 128),
    "sign_bank": (512, 512, 512, 128),
    "sign_prison": (512, 640, 512, 128),
    "movie": (0, 768, 512, 256),
    "neon_club": (512, 768, 512, 128),
    "sign_un": (512, 896, 512, 128),
}


def font(size, serif=False):
    return ImageFont.truetype(FONT_SERIF if serif else FONT, size)


def centered_text(draw, box, text, fnt, fill):
    x, y, w, h = box
    l, t, r, b = draw.textbbox((0, 0), text, font=fnt)
    draw.text((x + (w - (r - l)) / 2 - l, y + (h - (b - t)) / 2 - t), text, font=fnt, fill=fill)


def neon(img, name, text, color, size, border=True):
    """Neon tube text on a dark board: blurred glow + bright core."""
    x, y, w, h = REGIONS[name]
    board = Image.new("RGBA", (w, h), (24, 14, 36, 255))
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    if border:
        gd.rounded_rectangle((10, 10, w - 10, h - 10), radius=18, outline=color, width=8)
    centered_text(gd, (0, 0, w, h), text, font(size), color)
    blurred = glow.filter(ImageFilter.GaussianBlur(9))
    board.alpha_composite(blurred)
    board.alpha_composite(blurred)
    core = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    cd = ImageDraw.Draw(core)
    light = tuple(min(255, c + 140) for c in color[:3]) + (255,)
    if border:
        cd.rounded_rectangle((10, 10, w - 10, h - 10), radius=18, outline=light, width=3)
    centered_text(cd, (0, 0, w, h), text, font(size), light)
    board.alpha_composite(core)
    img.paste(board, (x, y))


def xxx_from_model(img, path):
    """The XXX neon: a front render of the "XXX Neon Sign" model (CC BY 4.0, Jimmy Johansson),
    tubes only, on a dark board with a soft glow. A flat texture instead of 40k polygons."""
    x, y, w, h = REGIONS["neon_xxx"]
    src = Image.open(path).convert("RGB")
    src.thumbnail((w - 16, h - 16), Image.LANCZOS)
    board = Image.new("RGBA", (w, h), (24, 14, 36, 255))
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    layer.paste(src.convert("RGBA"), ((w - src.width) // 2, (h - src.height) // 2))
    glow = layer.filter(ImageFilter.GaussianBlur(7))
    board.alpha_composite(glow)
    board.alpha_composite(glow)
    # Black parts of the render stay transparent: only the lit tubes are added.
    lit = layer.copy()
    px = lit.load()
    for j in range(h):
        for i in range(w):
            r, g, b, a = px[i, j]
            k = max(r, g, b)
            px[i, j] = (r, g, b, min(255, k * 3))
    board.alpha_composite(lit)
    img.paste(board, (x, y))


def plate(img, name, text, bg, fg, size, serif=False):
    x, y, w, h = REGIONS[name]
    board = Image.new("RGBA", (w, h), bg)
    d = ImageDraw.Draw(board)
    d.rectangle((6, 6, w - 7, h - 7), outline=fg, width=4)
    centered_text(d, (0, 0, w, h), text, font(size, serif), fg)
    img.paste(board, (x, y))


def movie(img):
    """The film on the drive-in screen: a sunset over the sea with palm trees."""
    x, y, w, h = REGIONS["movie"]
    c = Image.new("RGBA", (w, h), (0, 0, 0, 255))
    d = ImageDraw.Draw(c)
    horizon = int(h * 0.62)
    top, low = (70, 30, 110), (255, 140, 60)
    for j in range(horizon):
        t = j / horizon
        d.line((0, j, w, j), fill=tuple(int(a + (b - a) * t) for a, b in zip(top, low)) + (255,))
    d.ellipse((w * 0.5 - 60, horizon - 70, w * 0.5 + 60, horizon + 50), fill=(255, 220, 120, 255))
    for j in range(horizon, h):
        t = (j - horizon) / (h - horizon)
        d.line((0, j, w, j), fill=(int(120 - 80 * t), int(60 - 30 * t), int(110 - 40 * t), 255))
    for k in range(6):
        yy = horizon + 8 + k * 14
        d.line((w * 0.5 - 70 + k * 6, yy, w * 0.5 + 70 - k * 6, yy), fill=(255, 200, 110, 255), width=3)
    dark = (20, 10, 30, 255)
    for px, lean in ((70, 18), (440, -14)):
        d.line((px, h, px + lean, h - 150), fill=dark, width=9)
        for a in range(-2, 3):
            d.line((px + lean, h - 150, px + lean + a * 30, h - 150 + abs(a) * 14 + 6), fill=dark, width=7)
    d.rectangle((0, 0, w - 1, h - 1), outline=(240, 240, 240, 255), width=6)
    img.paste(c, (x, y))


def un_emblem(img, path):
    """The emblem in white on United Nations blue, like the flag."""
    x, y, w, h = REGIONS["un_emblem"]
    board = Image.new("RGBA", (w, h), (75, 146, 219, 255))
    src = Image.open(path).convert("RGBA")
    src.thumbnail((w - 30, h - 30), Image.LANCZOS)
    white = Image.new("RGBA", src.size, (255, 255, 255, 255))
    white.putalpha(src.getchannel("A"))
    board.alpha_composite(white, ((w - src.width) // 2, (h - src.height) // 2))
    img.paste(board, (x, y))


def dollar(img):
    x, y, w, h = REGIONS["dollar"]
    c = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(c)
    d.ellipse((8, 8, w - 8, h - 8), fill=(30, 90, 50, 255), outline=(240, 190, 60, 255), width=10)
    centered_text(d, (0, 0, w, h), "$", font(200), (250, 205, 70, 255))
    img.paste(c, (x, y), c)


def main():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    un_emblem(img, "tools/sign_sources/un_emblem.png")
    dollar(img)
    movie(img)
    xxx_from_model(img, "tools/sign_sources/xxx_neon_render.png")
    neon(img, "neon_casino", "CASINO", (255, 200, 40), 110)
    plate(img, "sign_hotel", "GRAND HOTEL", (110, 20, 40, 255), (240, 195, 70, 255), 50, serif=True)
    plate(img, "sign_post", "POST OFFICE", (30, 70, 160, 255), (255, 255, 255, 255), 62)
    plate(img, "sign_museum", "MUSEUM", (225, 215, 190, 255), (60, 50, 40, 255), 84, serif=True)
    neon(img, "neon_bar", "BAR", (90, 255, 120), 84)
    neon(img, "neon_club", "CLUB", (255, 90, 90), 84)
    plate(img, "sign_bank", "BANK", (20, 40, 70, 255), (240, 195, 70, 255), 84, serif=True)
    plate(img, "sign_prison", "PENITENTIARY", (40, 40, 44, 255), (235, 235, 230, 255), 56)
    plate(img, "sign_un", "UNITED NATIONS", (75, 146, 219, 255), (255, 255, 255, 255), 50)
    img.save("textures/signs.png")
    print("textures/signs.png written")


if __name__ == "__main__":
    main()
