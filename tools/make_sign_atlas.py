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
    "card_ace_spades": (512 + 48, 16, 160, 224),
    "card_king_hearts": (768 + 48, 16, 160, 224),
    "neon_xxx": (0, 256, 512, 256),
    "neon_casino": (512, 256, 512, 256),
    "neon_hotel": (0, 512, 512, 128),
    "neon_bar": (0, 640, 512, 128),
    "sign_bank": (512, 512, 512, 128),
    "sign_prison": (512, 640, 512, 128),
    "card_queen_diamonds": (48, 768 + 16, 160, 224),
    "card_jack_clubs": (256 + 48, 768 + 16, 160, 224),
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


def plate(img, name, text, bg, fg, size, serif=False):
    x, y, w, h = REGIONS[name]
    board = Image.new("RGBA", (w, h), bg)
    d = ImageDraw.Draw(board)
    d.rectangle((6, 6, w - 7, h - 7), outline=fg, width=4)
    centered_text(d, (0, 0, w, h), text, font(size, serif), fg)
    img.paste(board, (x, y))


def card(img, name, rank, suit, red):
    x, y, w, h = REGIONS[name]
    c = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(c)
    d.rounded_rectangle((0, 0, w - 1, h - 1), radius=16, fill=(250, 248, 240, 255), outline=(40, 40, 40, 255), width=4)
    ink = (210, 30, 45, 255) if red else (25, 25, 30, 255)
    d.text((12, 6), rank, font=font(40), fill=ink)
    d.text((14, 48), suit, font=font(34), fill=ink)
    centered_text(d, (0, 20, w, h - 20), suit, font(110), ink)
    rot = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    rd = ImageDraw.Draw(rot)
    rd.text((12, 6), rank, font=font(40), fill=ink)
    rd.text((14, 48), suit, font=font(34), fill=ink)
    c.alpha_composite(rot.rotate(180))
    img.paste(c, (x, y), c)


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
    card(img, "card_ace_spades", "A", "♠", False)
    card(img, "card_king_hearts", "K", "♥", True)
    card(img, "card_queen_diamonds", "Q", "♦", True)
    card(img, "card_jack_clubs", "J", "♣", False)
    neon(img, "neon_xxx", "XXX", (255, 60, 200), 170)
    neon(img, "neon_casino", "CASINO", (255, 200, 40), 110)
    neon(img, "neon_hotel", "HOTEL", (60, 230, 255), 80)
    neon(img, "neon_bar", "BAR", (90, 255, 120), 84)
    neon(img, "neon_club", "CLUB", (255, 90, 90), 84)
    plate(img, "sign_bank", "BANK", (20, 40, 70, 255), (240, 195, 70, 255), 84, serif=True)
    plate(img, "sign_prison", "PENITENTIARY", (40, 40, 44, 255), (235, 235, 230, 255), 56)
    plate(img, "sign_un", "UNITED NATIONS", (75, 146, 219, 255), (255, 255, 255, 255), 50)
    img.save("textures/signs.png")
    print("textures/signs.png written")


if __name__ == "__main__":
    main()
