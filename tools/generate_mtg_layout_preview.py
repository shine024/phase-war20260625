#!/usr/bin/env python3
"""Preview MTG card layout at 175×245 (matches backpack_panel DETAIL_CARD_FACE_SIZE)."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "cards" / "frames_v2" / "_mtg_layout_175x245_preview.png"
UNIT = ROOT / "assets" / "card_icons" / "elite_cold_t72.png"
FRAME_LEG = ROOT / "assets" / "cards" / "frames_v2" / "frame_legendary.png"

W, H = 175, 245
ART_PCT = 58  # backpack_panel _pv_mtg_art_pct
PAD = 6
BG = (14, 20, 32, 255)
ZONE_OUTLINE = (80, 140, 200, 200)


def _font(size: int, bold: bool = False):
    candidates = [
        "C:/Windows/Fonts/msyh.ttc",
        "C:/Windows/Fonts/msyhbd.ttc" if bold else "",
        "C:/Windows/Fonts/segoeui.ttf",
    ]
    for p in candidates:
        if p and Path(p).is_file():
            try:
                return ImageFont.truetype(p, size)
            except OSError:
                pass
    return ImageFont.load_default()


def mtg_heights(slot_h: int, art_pct: int) -> tuple[int, int, int]:
    art_max = max(200, int((slot_h * 0.78) + 0.999))
    art_h = max(22, min(int(slot_h * art_pct / 100), art_max))
    hdr_h = max(16, min(32, int((slot_h * 0.042) + 0.999)))
    star_h = max(9, min(20, round(slot_h / 25))) + 4
    return hdr_h, art_h, star_h


def draw_zone_label(d: ImageDraw.ImageDraw, rect: tuple[int, int, int, int], title: str, sub: str, font, font_s):
    x0, y0, x1, y1 = rect
    d.rectangle(rect, outline=ZONE_OUTLINE, width=1)
    d.text((x0 + 4, y0 + 3), title, fill=(120, 200, 255, 255), font=font)
    if sub:
        d.text((x0 + 4, y0 + 16), sub, fill=(150, 165, 190, 220), font=font_s)


def paste_cover(canvas: Image.Image, tex: Image.Image, box: tuple[int, int, int, int]) -> None:
    x0, y0, x1, y1 = box
    cw, ch = x1 - x0, y1 - y0
    tw, th = tex.size
    scale = max(cw / tw, ch / th)
    sw, sh = int(tw * scale), int(th * scale)
    scaled = tex.resize((sw, sh), Image.Resampling.LANCZOS)
    ox = x0 + (cw - sw) // 2
    oy = y0 + (ch - sh) // 2
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    layer.paste(scaled, (ox, oy))
    canvas.alpha_composite(layer)


def build_card(show_guides: bool = True) -> Image.Image:
    hdr_h, art_h, star_h = mtg_heights(H, ART_PCT)
    body_h = H - PAD * 2 - hdr_h - art_h - star_h

    card = Image.new("RGBA", (W, H), BG)
    if FRAME_LEG.is_file():
        fr = Image.open(FRAME_LEG).convert("RGBA").resize((W, H), Image.Resampling.LANCZOS)
        card.alpha_composite(fr)

    d = ImageDraw.Draw(card)
    font = _font(10)
    font_b = _font(11, True)
    font_s = _font(8)

    ix0, iy0 = PAD, PAD
    ix1 = W - PAD

    # ── MtgHeader
    hy1 = iy0 + hdr_h
    header_rect = (ix0, iy0, ix1, hy1)
    d.rectangle(header_rect, fill=(22, 30, 48, 230))
    name = "T-72A 主战坦克"
    rank = "上尉"
    cost = "6⚡"
    d.text((ix0 + 4, iy0 + 2), name, fill=(240, 245, 255, 255), font=font_b)
    nw = d.textlength(name, font=font_b)
    d.text((ix0 + 4 + nw + 8, iy0 + 3), rank, fill=(180, 210, 255, 255), font=font)
    d.text((ix1 - 36, iy0 + 2), cost, fill=(245, 210, 90, 255), font=font_b)

    # ── MtgArtClip
    ay0, ay1 = hy1, hy1 + art_h
    art_rect = (ix0, ay0, ix1, ay1)
    d.rectangle(art_rect, fill=(8, 12, 20, 255))
    if UNIT.is_file():
        paste_cover(card, Image.open(UNIT).convert("RGBA"), art_rect)

    # ── MtgStarsRow
    sy0, sy1 = ay1, ay1 + star_h
    stars_rect = (ix0, sy0, ix1, sy1)
    d.rectangle(stars_rect, fill=(18, 26, 40, 240))
    for i in range(3):
        cx = ix0 + 8 + i * 14
        cy = sy0 + star_h // 2
        d.text((cx, cy - 6), "★", fill=(255, 200, 80, 255), font=_font(12))

    # ── NameLabel body
    by0, by1 = sy1, H - PAD
    body_rect = (ix0, by0, ix1, by1)
    d.rectangle(body_rect, fill=(16, 22, 34, 245))
    body = "载具 · 冷战\n精英 · 主战坦克\n战力 约 520"
    d.multiline_text((ix0 + 5, by0 + 4), body, fill=(185, 195, 215, 255), font=font, spacing=2)

    if show_guides:
        dg = ImageDraw.Draw(card)
        draw_zone_label(dg, header_rect, "MtgHeader", f"{hdr_h}px", font_s, font_s)
        draw_zone_label(dg, art_rect, "MtgArtClip", f"{art_h}px ({ART_PCT}%)", font_s, font_s)
        draw_zone_label(dg, stars_rect, "MtgStarsRow", f"{star_h}px", font_s, font_s)
        draw_zone_label(dg, body_rect, "NameLabel", f"~{body_h}px", font_s, font_s)
        dg.rectangle((0, 0, W - 1, H - 1), outline=(0, 240, 255, 180), width=2)
        dg.text((4, H - 14), f"{W}×{H} (5:7)", fill=(0, 220, 255, 255), font=font_s)

    return card


def build_annotated_sheet() -> Image.Image:
    card = build_card(show_guides=True)
    card_clean = build_card(show_guides=False)
    legend_h = 72
    sheet = Image.new("RGBA", (W * 2 + 48, H + legend_h + 32), (12, 16, 24, 255))
    sheet.alpha_composite(card, (16, 16))
    sheet.alpha_composite(card_clean, (W + 32, 16))
    d = ImageDraw.Draw(sheet)
    f = _font(10)
    d.text((16, H + 24), "左：分区标注（与代码比例一致）", fill=(200, 210, 230, 255), font=f)
    d.text((W + 32, H + 24), "右：无标注效果预览", fill=(200, 210, 230, 255), font=f)
    lines = [
        f"MtgHeader = clamp(h×4.2%, 16~32) → {mtg_heights(H, ART_PCT)[0]}px",
        f"MtgArtClip = h×{ART_PCT}% (meta _pv_mtg_art_pct) → {mtg_heights(H, ART_PCT)[1]}px",
        f"MtgStarsRow ≈ round(w/25)+4 → {mtg_heights(H, ART_PCT)[2]}px",
        "NameLabel = 剩余高度（类型/摘要/战力）",
    ]
    y = H + 40
    for line in lines:
        d.text((16, y), line, fill=(140, 160, 190, 255), font=_font(9))
        y += 14
    return sheet


def main() -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet = build_annotated_sheet()
    sheet.save(OUT)
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()
