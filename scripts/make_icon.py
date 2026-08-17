#!/usr/bin/env python3
"""Generate the Calculator iOS app icon (1024x1024) from the app's palette.

Renders a single master PNG that Xcode uses for every AppIcon size. The design
is a miniature of the running app: deep green-slate background, a warm off-white
display number up top, and a 3x3 button pad echoing the real key layout
(slate-teal numbers, a lavender "go" key).

Usage:  python3 scripts/make_icon.py
Output: Calculator/Assets.xcassets/AppIcon.appiconset/icon-1024.png

Requires Pillow:  pip3 install pillow
"""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

# --- Palette: the exact source-of-truth colors from ContentView.swift ----------
# (Red, Green, Blue) in 0-255, converted from the 0-1 values in the Color ext.
BG_TOP     = (33, 38, 37)      # slightly lighter than bg, for the top of the gradient
BG_BOTTOM = (20, 24, 23)      # Color.bg   = 0.095,0.115,0.110 -> #181D1C
NUM_BG     = (46, 82, 97)      # Color.numBg slate-teal #2e5261
TOP_BG     = (177, 167, 189)   # Color.topBg lavender #b1a7bd
WARM_INK   = (244, 237, 231)   # Color.warmInk          #f4ede7
DARK_INK   = (33, 46, 43)      # Color.darkInk          #212e2b

# --- Layout -------------------------------------------------------------------
S = 1024
PAD = 150              # outer padding around the content
GRID = 3               # 3x3 button pad
GAP = 26               # gap between buttons
TOP_MARGIN = 150       # vertical space above the grid for the display

img = Image.new("RGBA", (S, S), (0, 0, 0, 0))

# --- Background: rounded-rect "tile" with a subtle vertical gradient ----------
# iOS already masks the icon shape, but we paint our own rounded tile so the
# design reads well as a standalone asset and in previews.
gradient = Image.new("RGB", (S, S))
gdraw = ImageDraw.Draw(gradient)
for y in range(S):
    t = y / (S - 1)
    r = int(BG_TOP[0] + (BG_BOTTOM[0] - BG_TOP[0]) * t)
    g = int(BG_TOP[1] + (BG_BOTTOM[1] - BG_TOP[1]) * t)
    b = int(BG_TOP[2] + (BG_BOTTOM[2] - BG_TOP[2]) * t)
    gdraw.line([(0, y), (S, y)], fill=(r, g, b))

# Rounded-rect mask so corners are transparent outside the tile.
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius=220, fill=255)
img.paste(gradient, (0, 0), mask)
img.putalpha(mask)

draw = ImageDraw.Draw(img)

# --- Font resolution: prefer a system font, fall back to default --------------
def get_font(size):
    for name in (
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/SFN.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/Library/Fonts/Arial.ttf",
    ):
        try:
            return ImageFont.truetype(name, size)
        except Exception:
            pass
    return ImageFont.load_default()

# --- Display: a big warm off-white number in the upper third ------------------
# Sits clearly ABOVE the grid (the two are vertically separated, not overlaid).
# No thousands separator, and centered horizontally (the app right-aligns its
# live display, but the icon reads better with a centered, ungrouped number).
display_font = get_font(150)
disp_text = "1234.56"
# Center the display horizontally in the top region.
bbox = draw.textbbox((0, 0), disp_text, font=display_font)
tw = bbox[2] - bbox[0]
th = bbox[3] - bbox[1]
draw.text(((S - tw) / 2, TOP_MARGIN - th // 2 + bbox[1]), disp_text,
          font=display_font, fill=WARM_INK)

# --- Button grid: 3x3 below the display --------------------------------------
# The grid occupies the lower two-thirds; the display owns the top region.
grid_top = TOP_MARGIN + 190
grid_bottom = S - PAD
cell = (grid_bottom - grid_top - GAP * (GRID - 1)) // GRID
grid_actual = cell * GRID + GAP * (GRID - 1)
grid_left = (S - grid_actual) // 2
# Re-center the grid block vertically within its band.
grid_top = (grid_top + grid_bottom - grid_actual) // 2

# Rows mirror the app's numbers, with a lavender "=" as the "go" key so it pops
# (matching the app's use of lavender for the top row).
buttons = [
    ("7", NUM_BG, WARM_INK), ("8", NUM_BG, WARM_INK), ("9", NUM_BG, WARM_INK),
    ("4", NUM_BG, WARM_INK), ("5", NUM_BG, WARM_INK), ("6", NUM_BG, WARM_INK),
    ("1", NUM_BG, WARM_INK), ("2", NUM_BG, WARM_INK), ("=", TOP_BG, DARK_INK),
]

btn_font = get_font(int(cell * 0.5))
btn_radius = int(cell * 0.24)

for i, (label, bg, fg) in enumerate(buttons):
    row, col = divmod(i, GRID)
    x0 = grid_left + col * (cell + GAP)
    y0 = grid_top + row * (cell + GAP)
    # subtle shadow under each button for depth
    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [x0 + 6, y0 + 8, x0 + cell + 6, y0 + cell + 8],
        radius=btn_radius, fill=(0, 0, 0, 40))
    img = Image.alpha_composite(img, shadow)
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle([x0, y0, x0 + cell, y0 + cell],
                           radius=btn_radius, fill=bg)
    b = draw.textbbox((0, 0), label, font=btn_font)
    lw = b[2] - b[0]
    lh = b[3] - b[1]
    draw.text((x0 + (cell - lw) / 2 - b[0], y0 + (cell - lh) / 2 - b[1]),
              label, font=btn_font, fill=fg)

# --- Output -------------------------------------------------------------------
out_dir = Path("Calculator/Assets.xcassets/AppIcon.appiconset")
out_dir.mkdir(parents=True, exist_ok=True)
out = out_dir / "icon-1024.png"
img.save(out)
print(f"wrote {out} ({img.size[0]}x{img.size[1]})")
