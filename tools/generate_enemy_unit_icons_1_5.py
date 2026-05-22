#!/usr/bin/env python3
"""
WW1 enemy unit card icons #1–5.

Spec (manifest / sprite style):
  - True profile side view, orthographic
  - Unit faces LEFT (nose / barrel toward -x)
  - Fully transparent background (no level bg, no ground plane)
  - Semi-realistic WW1 metal: gradients, rivets, weathering
"""
from __future__ import annotations

import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
UNITS_DIR = ROOT / "assets" / "card_icons" / "units"
ICONS_DIR = ROOT / "assets" / "card_icons"
FRAMES_DIR = ROOT / "assets" / "cards" / "frames"
CARD_BG = ROOT / "assets" / "cards" / "backgrounds" / "bg_neutral.png"
PREVIEW_DIR = ROOT / "assets" / "card_icons" / "_generated_preview"

SIZE = 512
# Side profile baseline; unit mass sits above this Y.
GROUND_Y = 398

UNITS: list[dict] = [
    {
        "visual_id": "vis_player_001",
        "archetype_id": "foe_platform_ww1_light",
        "captured_id": "captured_foe_platform_ww1_light",
        "title": "威克斯侦察车",
        "kind": "scout_car",
    },
    {
        "visual_id": "vis_player_002",
        "archetype_id": "foe_platform_ww1_medium",
        "captured_id": "captured_foe_platform_ww1_medium",
        "title": "马克V型坦克",
        "kind": "mark5_tank",
    },
    {
        "visual_id": "vis_player_003",
        "archetype_id": "foe_platform_ww1_fort",
        "captured_id": "captured_foe_platform_ww1_fort",
        "title": "150mm岸防火炮",
        "kind": "coastal_gun",
    },
    {
        "visual_id": "vis_player_004",
        "archetype_id": "foe_platform_ww1_radar",
        "captured_id": "captured_foe_platform_ww1_radar",
        "title": "系留气球观测队",
        "kind": "balloon",
    },
    {
        "visual_id": "vis_player_005",
        "archetype_id": "foe_platform_ww1_medic",
        "captured_id": "captured_foe_platform_ww1_medic",
        "title": "福特T救护改装车",
        "kind": "ambulance",
    },
]


def ww1_palette() -> dict[str, tuple[int, int, int]]:
    return {
        "olive": (98, 92, 68),
        "olive_dark": (62, 58, 44),
        "olive_light": (132, 124, 96),
        "khaki": (118, 108, 82),
        "steel": (108, 112, 118),
        "steel_dark": (72, 76, 82),
        "steel_light": (148, 152, 158),
        "gunmetal": (58, 60, 64),
        "rust": (128, 82, 48),
        "wood": (88, 68, 48),
        "canvas": (196, 188, 168),
        "concrete": (96, 92, 86),
        "concrete_dark": (68, 64, 60),
        "sandbag": (124, 106, 78),
        "balloon": (178, 186, 172),
        "balloon_shade": (132, 140, 128),
        "rim": (240, 236, 220),
        "shadow": (32, 30, 28),
        "cross": (186, 38, 34),
        "glass": (160, 188, 200),
    }


def grad_box(
    size: tuple[int, int],
    top: tuple[int, int, int],
    bottom: tuple[int, int, int],
    horizontal: bool = False,
) -> Image.Image:
    w, h = size
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        for x in range(w):
            t = (x / max(w - 1, 1)) if horizontal else (y / max(h - 1, 1))
            px[x, y] = (
                int(top[0] + (bottom[0] - top[0]) * t),
                int(top[1] + (bottom[1] - top[1]) * t),
                int(top[2] + (bottom[2] - top[2]) * t),
            )
    return img


def paste_grad(
    canvas: Image.Image,
    box: tuple[int, int, int, int],
    top: tuple[int, int, int],
    bottom: tuple[int, int, int],
    horizontal: bool = False,
    mask: Image.Image | None = None,
) -> None:
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    if w < 1 or h < 1:
        return
    g = grad_box((w, h), top, bottom, horizontal).convert("RGBA")
    if mask is not None:
        g.putalpha(mask.resize((w, h), Image.Resampling.LANCZOS))
    else:
        g.putalpha(255)
    canvas.alpha_composite(g, (x0, y0))


def make_noise(w: int, h: int, seed: int, strength: int = 22) -> Image.Image:
    rng = random.Random(seed)
    layer = Image.new("L", (w, h))
    px = layer.load()
    for y in range(h):
        for x in range(w):
            px[x, y] = rng.randint(128 - strength, 128 + strength)
    return layer.filter(ImageFilter.GaussianBlur(0.8))


def weather_on(canvas: Image.Image, box: tuple[int, int, int, int], seed: int, amount: float = 0.22) -> None:
    x0, y0, x1, y1 = box
    region = canvas.crop(box)
    alpha = region.split()[3]
    w, h = x1 - x0, y1 - y0
    if w < 2 or h < 2:
        return
    noise = make_noise(w, h, seed)
    rgb = region.convert("RGB")
    mod = ImageChops.multiply(rgb, Image.merge("RGB", [noise, noise, noise]))
    blended = Image.blend(rgb, mod, amount)
    out = Image.merge("RGBA", (*blended.split(), alpha))
    canvas.paste(out, box, alpha)


def wheel_side(d: ImageDraw.ImageDraw, cx: int, cy: int, r: int, pal: dict) -> None:
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(*pal["steel_dark"], 255))
    d.ellipse((cx - r + 5, cy - r + 5, cx + r - 5, cy + r - 5), fill=(*pal["gunmetal"], 255))
    d.arc((cx - r, cy - r, cx + r, cy + r), 200, 340, fill=(*pal["steel_light"], 200), width=3)
    d.ellipse((cx - 4, cy - r + 6, cx + 4, cy - 2), fill=(*pal["rim"], 90))


def rivet_row(d: ImageDraw.ImageDraw, x0: int, y: int, x1: int, step: int, pal: dict) -> None:
    for x in range(x0, x1, step):
        d.ellipse((x - 2, y - 2, x + 2, y + 2), fill=(*pal["steel_dark"], 255))
        d.ellipse((x - 1, y - 3, x + 1, y - 1), fill=(*pal["rim"], 80))


def barrel_left(
    canvas: Image.Image,
    d: ImageDraw.ImageDraw,
    x_tip: int,
    y: int,
    length: int,
    thick: int,
    pal: dict,
) -> None:
    """Cylindrical gun barrel pointing left; x_tip is muzzle (smallest x)."""
    x_rear = x_tip + length
    paste_grad(canvas, (x_tip, y, x_rear, y + thick), pal["gunmetal"], pal["steel_light"], horizontal=True)
    d.ellipse((x_tip - 4, y + 1, x_tip + 8, y + thick - 1), fill=(*pal["steel_dark"], 255))
    d.rectangle((x_rear - 14, y - 3, x_rear, y + thick + 3), fill=(*pal["olive_dark"], 255))


def track_run(d: ImageDraw.ImageDraw, x0: int, x1: int, y: int, h: int, pal: dict) -> None:
    d.rounded_rectangle((x0, y, x1, y + h), radius=5, fill=(*pal["steel_dark"], 255), outline=(*pal["shadow"], 255), width=1)
    for tx in range(x0 + 8, x1 - 4, 14):
        d.rectangle((tx, y + 4, tx + 9, y + h - 5), fill=(*pal["gunmetal"], 255))
        d.line([(tx, y + 3), (tx + 4, y + h - 4)], fill=(*pal["steel_light"], 60), width=1)


# --- Units: profile facing LEFT (front at smaller x) ---


def draw_scout_car(canvas: Image.Image, pal: dict) -> None:
    d = ImageDraw.Draw(canvas)
    gy = GROUND_Y
    wheel_r = 28
    wheels = [(118, gy), (318, gy)]
    # Chassis
    body = [(95, gy - 6), (355, gy - 4), (348, gy - 52), (280, gy - 78), (140, gy - 82), (88, gy - 58)]
    d.polygon(body, fill=(*pal["olive"], 255), outline=(*pal["olive_dark"], 255), width=2)
    paste_grad(canvas, (100, gy - 78, 340, gy - 28), pal["olive_light"], pal["olive_dark"])
    # Front armor / radiator (left)
    d.polygon([(88, gy - 58), (108, gy - 72), (128, gy - 78), (118, gy - 42), (92, gy - 38)], fill=(*pal["steel"], 255))
    d.rectangle((96, gy - 36, 112, gy - 18), fill=(*pal["steel_dark"], 255))
    # Cabin + canvas
    d.polygon([(155, gy - 82), (248, gy - 86), (242, gy - 128), (162, gy - 122)], fill=(*pal["olive_dark"], 255), outline=(*pal["wood"], 255))
    paste_grad(canvas, (158, gy - 125, 245, gy - 84), pal["canvas"], pal["olive_dark"])
    d.rectangle((188, gy - 118, 218, gy - 100), fill=(*pal["glass"], 180))
    # Spare + stowage
    d.ellipse((300, gy - 48, 332, gy - 22), fill=(*pal["olive_dark"], 255), outline=(*pal["steel_dark"], 255))
    rivet_row(d, 130, gy - 55, 300, 18, pal)
    barrel_left(canvas, d, 72, gy - 52, 38, 8, pal)  # forward LMG
    for cx, cy in wheels:
        wheel_side(d, cx, cy, wheel_r, pal)
    weather_on(canvas, (88, gy - 130, 355, gy), 101)


def draw_mark5_tank(canvas: Image.Image, pal: dict) -> None:
    d = ImageDraw.Draw(canvas)
    gy = GROUND_Y
    track_h = 38
    track_run(d, 72, 400, gy - 8, track_h, pal)
    track_run(d, 72, 400, gy + track_h - 10, track_h, pal)
    # Rhomboid hull — front corner at left
    hull = [
        (78, gy + 18),
        (388, gy + 6),
        (318, gy - 168),
        (108, gy - 152),
    ]
    d.polygon(hull, fill=(*pal["olive"], 255), outline=(*pal["olive_dark"], 255), width=2)
    paste_grad(canvas, (110, gy - 155, 360, gy + 5), pal["olive_light"], pal["olive_dark"])
    # Roof highlight (upper face)
    d.polygon([(118, gy - 145), (305, gy - 158), (268, gy - 118), (135, gy - 108)], fill=(*pal["rim"], 35))
    # Sponsons
    d.rounded_rectangle((148, gy - 98, 198, gy - 68), radius=3, fill=(*pal["olive_dark"], 255))
    d.rounded_rectangle((248, gy - 102, 298, gy - 70), radius=3, fill=(*pal["olive_dark"], 255))
    # Turret
    d.rounded_rectangle((188, gy - 132, 268, gy - 92), radius=5, fill=(*pal["olive_dark"], 255), outline=(*pal["steel_dark"], 255))
    paste_grad(canvas, (192, gy - 128, 264, gy - 96), pal["olive_light"], pal["olive_dark"])
    barrel_left(canvas, d, 58, gy - 118, 145, 12, pal)
    d.ellipse((218, gy - 122, 238, gy - 102), fill=(36, 38, 34, 255))
    rivet_row(d, 125, gy - 90, 310, 16, pal)
    weather_on(canvas, (78, gy - 175, 395, gy + 35), 202)


def draw_coastal_gun(canvas: Image.Image, pal: dict) -> None:
    d = ImageDraw.Draw(canvas)
    gy = GROUND_Y
    # Concrete emplacement
    d.polygon([(68, gy + 18), (400, gy + 18), (385, gy - 42), (82, gy - 38)], fill=(*pal["concrete"], 255), outline=(*pal["concrete_dark"], 255), width=2)
    paste_grad(canvas, (75, gy - 40, 395, gy + 15), pal["concrete"], pal["concrete_dark"])
    # Sandbags
    for i, sx in enumerate(range(85, 395, 32)):
        sy = gy - 6 + (i % 2) * 6
        d.ellipse((sx - 16, sy - 10, sx + 16, sy + 10), fill=(*pal["sandbag"], 255), outline=(*pal["olive_dark"], 255))
    # Gun cradle + barrel left
    d.polygon([(195, gy - 52), (255, gy - 58), (248, gy - 82), (188, gy - 76)], fill=(*pal["steel"], 255))
    barrel_left(canvas, d, 42, gy - 72, 210, 16, pal)
    # Shield plate
    d.polygon([(168, gy - 95), (220, gy - 100), (215, gy - 135), (162, gy - 128)], fill=(*pal["olive"], 255), outline=(*pal["olive_dark"], 255))
    paste_grad(canvas, (165, gy - 132, 222, gy - 96), pal["olive_light"], pal["olive_dark"])
    rivet_row(d, 175, gy - 88, 215, 8, pal)
    weather_on(canvas, (68, gy - 140, 405, gy + 20), 303)


def draw_balloon(canvas: Image.Image, pal: dict) -> None:
    d = ImageDraw.Draw(canvas)
    gy = GROUND_Y
    # Basket on ground (left-heavy composition)
    d.rectangle((198, gy - 28, 278, gy + 12), fill=(*pal["wood"], 255), outline=(*pal["olive_dark"], 255), width=2)
    paste_grad(canvas, (200, gy - 26, 276, gy + 10), pal["wood"], pal["olive_dark"])
    for ox in (210, 248):
        d.line([(ox, gy - 28), (ox - 18, gy - 195)], fill=(*pal["olive_dark"], 220), width=2)
    # Envelope — profile ellipse, shading on rear (right) side
    env = (118, gy - 355, 358, gy - 145)
    d.ellipse(env, fill=(*pal["balloon"], 255), outline=(*pal["olive_dark"], 255), width=3)
    paste_grad(canvas, (env[0] + 20, env[1] + 15, env[2] - 30, env[3] - 20), pal["balloon"], pal["balloon_shade"], horizontal=True)
    d.arc(env, 70, 120, fill=(*pal["rim"], 70), width=14)
    for k in range(-4, 5):
        d.arc((env[0] + k * 6, env[1], env[2] + k * 4, env[3]), 200, 340, fill=None, width=1)
    # Observation slit facing left on basket
    d.rectangle((205, gy - 18, 228, gy - 6), fill=(*pal["glass"], 200))
    weather_on(canvas, (118, gy - 360, 360, gy + 15), 404)


def draw_ambulance(canvas: Image.Image, pal: dict) -> None:
    d = ImageDraw.Draw(canvas)
    gy = GROUND_Y
    # Frame
    d.rounded_rectangle((108, gy - 22, 358, gy + 4), radius=4, fill=(*pal["olive_dark"], 255), outline=(*pal["shadow"], 255))
    paste_grad(canvas, (110, gy - 20, 356, gy + 2), pal["olive"], pal["olive_dark"], horizontal=True)
    # Cargo box
    d.rounded_rectangle((118, gy - 92, 310, gy - 20), radius=3, fill=(*pal["canvas"], 255), outline=(*pal["olive_dark"], 255), width=2)
    paste_grad(canvas, (120, gy - 90, 308, gy - 22), (238, 234, 220), pal["khaki"])
    # Red cross (side face)
    cx, cy = 215, gy - 56
    d.rectangle((cx - 22, cy - 6, cx + 22, cy + 6), fill=(*pal["cross"], 255))
    d.rectangle((cx - 6, cy - 22, cx + 6, cy + 22), fill=(*pal["cross"], 255))
    # Cab (left/front)
    d.polygon([(108, gy - 22), (148, gy - 24), (152, gy - 72), (112, gy - 68)], fill=(*pal["olive"], 255))
    d.rectangle((118, gy - 62, 142, gy - 44), fill=(*pal["glass"], 190))
    d.rectangle((148, gy - 78, 168, gy - 48), fill=(*pal["olive_dark"], 255))
    wheel_side(d, 128, gy, 26, pal)
    wheel_side(d, 328, gy, 26, pal)
    weather_on(canvas, (108, gy - 95, 360, gy + 8), 505)


def render_unit(kind: str, pal: dict) -> Image.Image:
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    drawers = {
        "scout_car": draw_scout_car,
        "mark5_tank": draw_mark5_tank,
        "coastal_gun": draw_coastal_gun,
        "balloon": draw_balloon,
        "ambulance": draw_ambulance,
    }
    drawers[kind](canvas, pal)
    return canvas


def save_unit(spec: dict, img: Image.Image) -> list[Path]:
    UNITS_DIR.mkdir(parents=True, exist_ok=True)
    written: list[Path] = []
    for path in (
        UNITS_DIR / f"{spec['visual_id']}.png",
        ICONS_DIR / f"{spec['archetype_id']}.png",
        ICONS_DIR / f"{spec['captured_id']}.png",
    ):
        img.save(path, optimize=True)
        written.append(path)
    return written


def compose_preview_card(unit_img: Image.Image, rarity: str = "common") -> Image.Image:
    w, h = 175, 245
    card = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    if CARD_BG.is_file():
        card.alpha_composite(Image.open(CARD_BG).convert("RGBA").resize((w, h), Image.Resampling.LANCZOS))
    fr = FRAMES_DIR / f"{rarity}.png"
    if fr.is_file():
        card.alpha_composite(Image.open(fr).convert("RGBA").resize((w, h), Image.Resampling.LANCZOS))
    uw, uh = int(w * 0.86), int(h * 0.48)
    unit = unit_img.resize((uw, uh), Image.Resampling.LANCZOS)
    card.alpha_composite(unit, ((w - uw) // 2, int(h * 0.10)))
    return card


def checker_bg(w: int, h: int, cell: int = 16) -> Image.Image:
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    for y in range(h):
        for x in range(w):
            t = (x // cell + y // cell) % 2
            px[x, y] = (46, 50, 56, 255) if t else (66, 70, 76, 255)
    return img


def compose_icon_sheet(units: list[Image.Image]) -> Image.Image:
    """Checkerboard strip to verify transparency."""
    cell, pad = 256, 16
    cols = len(units)
    w = cols * (cell + pad) + pad
    h = cell + pad * 2
    sheet = checker_bg(w, h)
    for i, img in enumerate(units):
        thumb = img.resize((cell, cell), Image.Resampling.LANCZOS)
        sheet.alpha_composite(thumb, (pad + i * (cell + pad), pad))
    return sheet


def main() -> None:
    pal = ww1_palette()
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    raw: list[Image.Image] = []
    previews: list[Image.Image] = []

    for i, spec in enumerate(UNITS, 1):
        img = render_unit(spec["kind"], pal)
        raw.append(img)
        paths = save_unit(spec, img)
        print(f"[{i}] {spec['title']} — profile left, transparent")
        for p in paths:
            print(f"    {p.relative_to(ROOT)} ({p.stat().st_size // 1024} KB)")
        previews.append(compose_preview_card(img, "uncommon" if i == 2 else "common"))

    sheet = compose_icon_sheet(raw)
    sheet.save(PREVIEW_DIR / "enemy_units_1_5_transparent.png")

    pad = 14
    pw = 175 + pad
    mock = Image.new("RGBA", (len(previews) * pw + pad, 245 + pad + 28), (18, 22, 30, 255))
    dr = ImageDraw.Draw(mock)
    for i, (spec, prev) in enumerate(zip(UNITS, previews)):
        ox = pad + i * pw
        mock.alpha_composite(prev, (ox, pad))
        dr.text((ox + 4, pad + 248), f"{i + 1}.{spec['title']}", fill=(210, 220, 235, 255))
    mock.save(PREVIEW_DIR / "enemy_units_1_5_preview.png")
    print(f"Wrote {PREVIEW_DIR / 'enemy_units_1_5_transparent.png'}")
    print(f"Wrote {PREVIEW_DIR / 'enemy_units_1_5_preview.png'}")


if __name__ == "__main__":
    main()
