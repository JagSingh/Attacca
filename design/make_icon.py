# (c) 2026 jag.m.singh@gmail.com
# Attacca app icon: a single tapered slur curving up like a smile beneath three ascending noteheads.
import math
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else "AppIcon.png"
S = 4096                      # supersampled canvas
k = S / 1024                  # design units are 1024-based

def P(x, y):
    return (x * k, y * k)

# ---------- background: deep indigo radial gradient ----------
yy, xx = np.mgrid[0:S, 0:S].astype(np.float32) / S
cx, cy = 0.30, 0.22
r = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
t = np.clip(r / 1.05, 0, 1)[..., None]
inner = np.array([38, 44, 104], np.float32)    # #262C68
outer = np.array([7, 9, 28], np.float32)       # #07091C
bg = inner * (1 - t) + outer * t
img = Image.fromarray(bg.astype(np.uint8), "RGB")

# ---------- geometry ----------
def bezier(p0, p1, p2, p3, n=400):
    pts = []
    for i in range(n + 1):
        u = i / n
        a, b, c, d = (1 - u) ** 3, 3 * u * (1 - u) ** 2, 3 * u ** 2 * (1 - u), u ** 3
        pts.append((a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0],
                    a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]))
    return pts

# Noteheads (centres), ascending left -> right
notes = [(300, 468), (512, 428), (724, 388)]   # gently ascending, sitting above the smile

# Slur: crescent between an outer and inner curve sharing endpoints
start, end = (222, 548), (802, 466)
# Smile: crescent opening upward. Chord slope ~ -0.14; outer (lower) edge dips ~190 below
# the chord, inner (upper) edge ~130 -> ~60 thick at the bottom, tapering to the tips.
outer_c = bezier(P(*start), P(355, 780), P(670, 736), P(*end))
inner_c = bezier(P(*start), P(358, 700), P(667, 656), P(*end))
slur_poly = outer_c + inner_c[::-1]

slur_mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(slur_mask).polygon(slur_poly, fill=255)

# Warm gradient along the slur: amber -> coral -> magenta
gx = np.clip((xx - 0.18) / 0.65, 0, 1)[..., None]
c1 = np.array([255, 196, 92], np.float32)     # amber
c2 = np.array([255, 94, 98], np.float32)      # coral
c3 = np.array([214, 80, 255], np.float32)     # magenta
grad = np.where(gx < 0.5, c1 + (c2 - c1) * (gx / 0.5), c2 + (c3 - c2) * ((gx - 0.5) / 0.5))
grad_img = Image.fromarray(grad.astype(np.uint8), "RGB")

# Glow under the slur
glow = slur_mask.filter(ImageFilter.GaussianBlur(38 * k))
glow = glow.point(lambda v: int(v * 0.85))
img = Image.composite(grad_img, img, glow)

# Note glow (soft, cool)
note_mask = Image.new("L", (S, S), 0)
nd = ImageDraw.Draw(note_mask)

def notehead(draw, cx_, cy_, w=132, h=94, angle=-22, fill=255):
    # rotated ellipse as polygon
    a = math.radians(angle)
    pts = []
    for i in range(240):
        th = 2 * math.pi * i / 240
        x, y = (w / 2) * math.cos(th), (h / 2) * math.sin(th)
        pts.append(((cx_ + x * math.cos(a) - y * math.sin(a)) * k,
                    (cy_ + x * math.sin(a) + y * math.cos(a)) * k))
    draw.polygon(pts, fill=fill)

for (x, y) in notes:
    notehead(nd, x, y)
note_glow = note_mask.filter(ImageFilter.GaussianBlur(30 * k)).point(lambda v: int(v * 0.35))
glow_col = Image.new("RGB", (S, S), (140, 160, 255))
img = Image.composite(glow_col, img, note_glow)

# Crisp slur and notes
img = Image.composite(grad_img, img, slur_mask)
note_col = Image.new("RGB", (S, S), (244, 240, 232))
img = Image.composite(note_col, img, note_mask)

# Downsample (antialias) and save opaque RGB (App Store icons must not have alpha)
img = img.resize((1024, 1024), Image.LANCZOS).convert("RGB")
img.save(OUT, "PNG", optimize=True)
print("saved", OUT, img.size, img.mode)
