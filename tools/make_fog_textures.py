"""Builds the images of the fog that hides the second island.

Run from the project folder:  python3 tools/make_fog_textures.py
Writes:
  textures/fog_noise.png   512x512 tileable cloud density (fractal noise),
                           scrolled by shaders/fog_layer.gdshader
  textures/fog_puffs.png   1024x1024 sheet of 4 shaded cloud puffs (2x2),
                           drawn on camera-facing quads (shaders/fog_puff.gdshader)
  textures/season2.png     the "ZONE UNLOCKED ON SEASON 2, COMING SOON" title
The clouds are photographic-style fractal noise (1/f spectrum), not geometry,
so the fog reads like a real bank of mist. Needs numpy and Pillow.
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
RNG = np.random.default_rng(20240611)


def fractal(size, beta=2.3, low_cut=2.0):
    """Tileable fractal noise in 0..1: white noise shaped by a 1/f^beta spectrum."""
    f = np.fft.fftfreq(size) * size
    k = np.sqrt(f[None, :] ** 2 + f[:, None] ** 2)
    k[0, 0] = 1.0
    amp = 1.0 / np.power(np.maximum(k, low_cut), beta / 2.0)
    phase = np.exp(2j * np.pi * RNG.random((size, size)))
    n = np.real(np.fft.ifft2(amp * phase))
    n -= n.min()
    return n / n.max()


def billow(size):
    """Puffy cloud density: two fractal layers, the second warping the first."""
    a = fractal(size, 3.0)
    b = fractal(size, 2.6, 3.0)
    shift = ((b - 0.5) * size * 0.06).astype(int)
    rows = (np.arange(size)[:, None] + shift) % size
    warped = a[rows, np.arange(size)[None, :]]
    return np.clip(warped * 0.75 + b * 0.25, 0, 1)


def fog_noise():
    d = billow(512)
    d = np.clip((d - 0.3) / 0.55, 0, 1) ** 1.2
    Image.fromarray((d * 255).astype(np.uint8), "L").save("textures/fog_noise.png")


def puff(size, seed):
    """One cumulus puff: soft lobes (cauliflower shape) eroded by fractal
    noise, lit from the top so it has volume, with a wispy transparent edge."""
    rng = np.random.default_rng(seed)
    y, x = np.mgrid[0:size, 0:size] / (size - 1) * 1.6 - 0.8
    dens = np.zeros((size, size))
    for _ in range(14):
        a = rng.random() * np.pi * 2
        d = rng.random() ** 0.7 * 0.42
        cx, cy = np.cos(a) * d * 1.1, np.sin(a) * d * 0.75 - 0.05
        r = 0.18 + rng.random() * 0.2
        dens = np.maximum(dens, np.exp(-((x - cx) ** 2 + (y - cy) ** 2) / (r * r)))
    detail = fractal(size, 3.2, 3.0)
    fine = fractal(size, 2.2, 8.0)
    dens = dens * (0.55 + detail * 0.6) + (fine - 0.5) * 0.12
    dens = np.clip((dens - 0.28) / 0.55, 0, 1)
    dens = np.asarray(Image.fromarray((dens * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2))) / 255.0
    # Light from above: compare with the density a little higher up.
    up = np.roll(dens, 14, axis=0)
    shade = np.clip(0.78 + (dens - up) * 1.6 - (y + 1) * 0.18 + (detail - 0.5) * 0.3, 0, 1)
    light = np.array([252, 251, 255]) / 255.0
    dark = np.array([128, 136, 152]) / 255.0
    rgb = dark[None, None, :] + (light - dark)[None, None, :] * shade[:, :, None]
    border = np.clip((0.8 - np.maximum(np.abs(x), np.abs(y))) / 0.12, 0, 1)
    alpha = np.clip(dens * 1.25, 0, 1) ** 0.9 * border
    rgba = np.dstack([rgb, alpha])
    return Image.fromarray((rgba * 255).astype(np.uint8), "RGBA")


def fog_puffs():
    sheet = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    for i in range(4):
        sheet.paste(puff(512, 11 + i * 97), ((i % 2) * 512, (i // 2) * 512))
    sheet.save("textures/fog_puffs.png")


def gold_text(size, text, h):
    """Gold gradient letters with a dark outline, like a game title."""
    fnt = ImageFont.truetype(FONT, size)
    tmp = Image.new("L", (1, 1))
    l, t, r, b = ImageDraw.Draw(tmp).textbbox((0, 0), text, font=fnt, stroke_width=6)
    w = r - l
    mask = Image.new("L", (w + 20, h), 0)
    ImageDraw.Draw(mask).text((10 - l, (h - (b - t)) / 2 - t), text, font=fnt, fill=255)
    outline = Image.new("L", (w + 20, h), 0)
    ImageDraw.Draw(outline).text((10 - l, (h - (b - t)) / 2 - t), text, font=fnt, fill=255,
            stroke_width=6, stroke_fill=255)
    grad = np.zeros((h, w + 20, 4), np.uint8)
    for j in range(h):
        k = j / h
        top, mid, low = np.array([255, 236, 150]), np.array([236, 170, 50]), np.array([150, 90, 20])
        c = top + (mid - top) * (k / 0.55) if k < 0.55 else mid + (low - mid) * ((k - 0.55) / 0.45)
        grad[j, :, :3] = c
    grad[:, :, 3] = np.asarray(mask)
    out = Image.new("RGBA", (w + 20, h), (0, 0, 0, 0))
    out.paste((40, 22, 8, 255), (0, 0), outline)
    out.alpha_composite(Image.fromarray(grad, "RGBA"))
    return out


def white_text(size, text, h):
    fnt = ImageFont.truetype(FONT, size)
    tmp = Image.new("L", (1, 1))
    l, t, r, b = ImageDraw.Draw(tmp).textbbox((0, 0), text, font=fnt, stroke_width=4)
    out = Image.new("RGBA", (r - l + 20, h), (0, 0, 0, 0))
    ImageDraw.Draw(out).text((10 - l, (h - (b - t)) / 2 - t), text, font=fnt,
            fill=(246, 240, 228, 255), stroke_width=4, stroke_fill=(30, 26, 22, 255))
    return out


def season_title():
    w, h = 1024, 512
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    lines = [white_text(64, "ZONE UNLOCKED ON", 110), gold_text(150, "SEASON 2,", 200),
            white_text(78, "COMING SOON", 120)]
    y = 40
    for line in lines:
        img.alpha_composite(line, ((w - line.width) // 2, y))
        y += line.height
    # Soft dark halo so the title reads on white fog.
    halo = img.getchannel("A").filter(ImageFilter.GaussianBlur(22))
    shadow = Image.new("RGBA", (w, h), (20, 18, 26, 0))
    shadow.putalpha(halo.point(lambda a: int(a * 0.55)))
    shadow.alpha_composite(img)
    shadow.save("textures/season2.png")


def main():
    fog_noise()
    fog_puffs()
    season_title()
    print("textures/fog_noise.png, fog_puffs.png and season2.png written")


if __name__ == "__main__":
    main()
