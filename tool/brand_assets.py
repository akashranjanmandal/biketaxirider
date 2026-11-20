"""Brand assets for Aamar Captain.

Full run (cuts the logo mark, wordmark and vehicle art out of the logo sheet,
then builds the launcher icon and launch screens):
    python tool/brand_assets.py <logo-sheet.png> assets/brand assets/launcher

Captain-only run (reuses assets/brand/logo_mark.png, already cut from the
sheet, and rebuilds the launcher icon and launch screens):
    python tool/brand_assets.py --captain assets/brand assets/launcher

The captain icon is the same mark on white with a small black "CAPTAIN" badge
under the pin. The pin, not the image's bounding box, is always centred."""
import os
import sys
from collections import deque
import numpy as np
from PIL import Image, ImageDraw, ImageFont

CAPTAIN_ONLY = sys.argv[1] == '--captain'
if CAPTAIN_ONLY:
    sys.argv.pop(1)
    src = None
    out = sys.argv[1]
else:
    src, out = sys.argv[1], sys.argv[2]
launcher = sys.argv[-1] if len(sys.argv) > (2 if CAPTAIN_ONLY else 3) else out
FONT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'google_fonts', 'PlusJakartaSans-ExtraBold.ttf')
if src:
    img = np.asarray(Image.open(src).convert('RGB')).astype(np.float32)
    BG = img[5, 5]


def cutout(box, lo=30, hi=90):
    """Crop and make the background transparent. Only background reachable from
    the crop border is removed, so enclosed areas (the logo's inner circle) stay."""
    x0, y0, x1, y1 = box
    c = img[y0:y1, x0:x1]
    dist = np.abs(c - BG).sum(2)
    h, w = dist.shape
    near = dist < hi
    seen = np.zeros_like(near)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if near[y, x] and not seen[y, x]:
                seen[y, x] = True; q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if near[y, x] and not seen[y, x]:
                seen[y, x] = True; q.append((y, x))
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and near[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True; q.append((ny, nx))
    alpha = np.ones((h, w), np.float32)
    soft = np.clip((dist - lo) / (hi - lo), 0, 1)
    alpha[seen] = soft[seen]
    # un-premultiply the cream background out of semi-transparent edge pixels
    a = alpha[..., None]
    rgb = np.where(a > 0.02, (c - BG * (1 - a)) / np.maximum(a, 0.02), c)
    rgba = np.dstack([np.clip(rgb, 0, 255), alpha * 255]).astype(np.uint8)
    im = Image.fromarray(rgba)
    return im.crop(im.getbbox())


def save(im, name, folder=None):
    im.save(f'{folder or out}/{name}', optimize=True)
    print(name, im.size)


def cut_sheet():
    """Cuts the mark, wordmark and vehicle art; returns (mark, tip_x)."""
    mark = cutout((300, 140, 862, 586))   # pin + speed lines
    # remove the ground glow: under the pin, keep only the V that runs from the
    # pin's solid outline down to its tip
    m = np.asarray(mark).copy()
    h, w = m.shape[:2]
    solid = m[..., 3] > 240
    y0 = h - 70
    l0, r0 = np.where(solid[y0])[0][[0, -1]]
    r0 = min(r0, l0 + (r0 - l0))  # left edge of the V
    rows = np.where(solid[:, l0:r0 + 1].any(1))[0]
    tip_y = rows.max()
    tip_x = int(np.mean(np.where(solid[tip_y - 2])[0]))
    stem_l = int(np.where(solid[y0])[0][-1])  # right "a" stem keeps its own edge
    stem_bottom = int(np.where(solid[:, stem_l - 6])[0].max())
    xs = np.arange(w)
    for y in range(y0, h):
        t = min(1, (y - y0) / max(1, tip_y - y0))
        left = l0 + (tip_x - l0) * t - 2
        right = stem_l + 2 if y <= stem_bottom else 2 * tip_x - left
        keep = (xs >= left) & (xs <= right)
        if y > tip_y + 2:
            keep[:] = False
        m[y, ~keep, 3] = 0
    mark = Image.fromarray(m)
    bbox = mark.getbbox()
    mark = mark.crop(bbox)
    tip_x -= bbox[0]
    save(mark, 'logo_mark.png')

    word = cutout((150, 600, 1110, 752))
    save(word, 'wordmark.png')
    # dark-theme wordmark: navy "aamar" -> near white, keep the yellow "Bike"
    a = np.asarray(word).astype(np.float32)
    rgb, al = a[..., :3], a[..., 3:]
    navy = (rgb.max(2) < 120)[..., None]
    light = np.array([244, 245, 248], np.float32)
    save(Image.fromarray(np.dstack([np.where(navy, light, rgb), al]).astype(np.uint8)), 'wordmark_dark.png')

    for name, box in [('bike', (150, 880, 392, 1070)), ('car', (450, 880, 770, 1070)), ('rickshaw', (828, 880, 1080, 1070))]:
        save(cutout(box), f'v_{name}.png')
    return mark, tip_x


def find_tip(mark):
    """x of the pin's tip in an already-cut mark (lowest solid pixels)."""
    solid = np.asarray(mark)[..., 3] > 240
    rows = np.where(solid.any(1))[0]
    return float(np.mean(np.where(solid[rows.max() - 2])[0]))


if CAPTAIN_ONLY:
    mark = Image.open(f'{out}/logo_mark.png').convert('RGBA')
    tip_x = find_tip(mark)
else:
    mark, tip_x = cut_sheet()

# The pin's tip sits directly under the centre of its circle; that is the
# visual centre of the mark (the speed lines hang off to the left).
mark_cx = tip_x / mark.size[0]
print(f'mark visual centre x = {mark_cx:.4f} of width (kMarkCenterX in lib/ui/kit.dart)')


def place(canvas, im, scale, dy=0):
    """Put im on a square canvas with the pin (not the bounding box) centred.
    scale = how much of the canvas the mark's widest half-extent may use.
    Returns (canvas, bottom y of the placed mark)."""
    w, h = im.size
    cx = mark_cx * w
    half = max(cx, w - cx)
    s = canvas.size[0] * scale / (2 * half)
    im = im.resize((round(w * s), round(h * s)), Image.LANCZOS)
    x = round(canvas.size[0] / 2 - cx * s)
    y = (canvas.size[1] - im.size[1]) // 2 + dy
    canvas.alpha_composite(im, (x, y))
    return canvas, y + im.size[1]


def captain_icon(size, scale, transparent=False):
    """The mark with a black "CAPTAIN" badge under the pin, centred as a group."""
    canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0) if transparent else (255, 255, 255, 255))
    badge_h = round(size * .1)
    gap = round(size * .03)
    # lift the mark so mark + gap + badge sit centred vertically
    canvas, bottom = place(canvas, mark, scale, dy=-(badge_h + gap) // 2)
    font = ImageFont.truetype(FONT, round(badge_h * .5))
    text = 'CAPTAIN'
    tracking = badge_h * .07
    widths = [font.getlength(ch) for ch in text]
    text_w = sum(widths) + tracking * (len(text) - 1)
    badge_w = round(text_w + badge_h * 1.0)
    # draw at 4x and downsample for clean edges
    k = 4
    b = Image.new('RGBA', (badge_w * k, badge_h * k), (0, 0, 0, 0))
    d = ImageDraw.Draw(b)
    d.rounded_rectangle((0, 0, badge_w * k - 1, badge_h * k - 1), radius=badge_h * k // 2, fill=(15, 16, 19, 255))
    fk = ImageFont.truetype(FONT, round(badge_h * .5 * k))
    x = (badge_w * k - text_w * k) / 2
    for ch, cw in zip(text, widths):
        d.text((x, badge_h * k / 2), ch, font=fk, fill=(255, 255, 255, 255), anchor='lm')
        x += (cw + tracking) * k
    b = b.resize((badge_w, badge_h), Image.LANCZOS)
    canvas.alpha_composite(b, ((size - badge_w) // 2, bottom + gap))
    return canvas


save(captain_icon(1024, .66), 'icon.png', launcher)                            # iOS / legacy
save(captain_icon(1024, .48, transparent=True), 'icon_foreground.png', launcher)  # adaptive (66% safe zone)
# launch screens: just the mark, 128dp wide (512px at 4x) with the pin
# centred, matching SplashScreen in lib/ui/screens/onboarding.dart
launch_scale = lambda canvas: 2 * mark_cx * 512 / canvas
save(place(Image.new('RGBA', (1152, 1152), (0, 0, 0, 0)), mark, launch_scale(1152))[0], 'splash_android12.png', launcher)
save(place(Image.new('RGBA', (768, 768), (0, 0, 0, 0)), mark, launch_scale(768))[0], 'splash_logo.png', launcher)
