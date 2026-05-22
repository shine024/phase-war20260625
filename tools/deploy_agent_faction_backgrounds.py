#!/usr/bin/env python3
"""Crop agent faction backgrounds to exact 5:8 (500×800) without stretch."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SRC_DIR = Path(r"C:/Users/jianchang.tan/.cursor/projects/f-godot-fair-duet-create-phase-war/assets")
OUT_DIR = ROOT / "assets" / "cards" / "backgrounds_choice" / "agent_heraldic"
UNIT_SAMPLE = ROOT / "assets" / "card_icons" / "units" / "vis_player_002.png"
FRAME_SAMPLE = ROOT / "assets" / "cards" / "frames" / "epic.png"

TARGET_W, TARGET_H = 500, 800
ASPECT = TARGET_W / TARGET_H  # 0.625 = 5:8

FILES = [
    "bg_neutral.png",
    "bg_iron_wall_corp.png",
    "bg_nova_arms.png",
    "bg_aether_dynamics.png",
    "bg_quantum_logistics.png",
    "bg_helix_recon.png",
    "bg_void_research.png",
    "bg_frontier_union.png",
]

LABELS = ["中立", "钢壁", "新星", "以太", "量子", "螺旋", "虚空", "边境"]


def crop_to_aspect(img: Image.Image, aspect: float) -> Image.Image:
    w, h = img.size
    current = w / h
    if abs(current - aspect) < 0.002:
        return img
    if current > aspect:
        # too wide → crop width
        new_w = int(round(h * aspect))
        left = (w - new_w) // 2
        return img.crop((left, 0, left + new_w, h))
    # too tall → crop height
    new_h = int(round(w / aspect))
    top = (h - new_h) // 2
    return img.crop((0, top, w, top + new_h))


def process_one(src: Path, dst: Path) -> tuple[tuple[int, int], tuple[int, int]]:
    raw = Image.open(src).convert("RGB")
    src_size = raw.size
    cropped = crop_to_aspect(raw, ASPECT)
    out = cropped.resize((TARGET_W, TARGET_H), Image.Resampling.LANCZOS)
    dst.parent.mkdir(parents=True, exist_ok=True)
    out.save(dst, optimize=True)
    return src_size, cropped.size


def preview_sheet(images: dict[str, Image.Image]) -> Image.Image:
    pad = 14
    cols = 4
    sheet = Image.new("RGB", (cols * (TARGET_W + pad) + pad, 2 * (TARGET_H + pad + 22) + pad + 28), (12, 14, 20))
    d = ImageDraw.Draw(sheet)
    d.text((pad, 6), "Agent heraldic — 5:8 center crop 500×800 (no stretch)", fill=(255, 210, 130))
    for i, (name, img) in enumerate(images.items()):
        c, r = i % cols, i // cols
        ox = pad + c * (TARGET_W + pad)
        oy = pad + 26 + r * (TARGET_H + pad + 22)
        sheet.paste(img, (ox, oy))
        d.text((ox + 4, oy + TARGET_H + 4), LABELS[i], fill=(220, 225, 235))
    return sheet


def mockup_sheet(images: dict[str, Image.Image]) -> Image.Image:
    pad = 12
    cols = 4
    unit = frame = None
    if UNIT_SAMPLE.is_file():
        unit = Image.open(UNIT_SAMPLE).convert("RGBA")
        unit.thumbnail((340, 340), Image.Resampling.LANCZOS)
    if FRAME_SAMPLE.is_file():
        frame = Image.open(FRAME_SAMPLE).convert("RGBA")
    sheet = Image.new("RGBA", (cols * (TARGET_W + pad) + pad, 2 * (TARGET_H + pad) + pad), (14, 18, 28, 255))
    for i, (name, bg) in enumerate(images.items()):
        c, r = i % cols, i // cols
        card = Image.new("RGBA", (TARGET_W, TARGET_H), (0, 0, 0, 255))
        card.paste(bg)
        if unit:
            card.alpha_composite(unit, ((TARGET_W - unit.width) // 2, int(TARGET_H * 0.18)))
        if frame:
            card.alpha_composite(frame, (0, 0))
        sheet.alpha_composite(card, (pad + c * (TARGET_W + pad), pad + r * (TARGET_H + pad)))
    return sheet


def main() -> None:
    built: dict[str, Image.Image] = {}
    for fname in FILES:
        src = SRC_DIR / fname
        if not src.is_file():
            src = OUT_DIR / fname
        if not src.is_file():
            print(f"SKIP missing {fname}")
            continue
        dst = OUT_DIR / fname
        src_size, crop_size = process_one(src, dst)
        built[fname] = Image.open(dst).convert("RGB")
        kb = dst.stat().st_size // 1024
        print(f"{fname}: {src_size} -> crop {crop_size} -> {TARGET_W}x{TARGET_H} ({kb} KB)")

    choice = ROOT / "assets" / "cards" / "backgrounds_choice"
    preview_sheet(built).save(choice / "_preview_factions_agent_heraldic.png")
    mockup_sheet(built).save(choice / "_mockup_factions_agent_heraldic.png")
    print(f"Wrote previews under {choice}")


if __name__ == "__main__":
    main()
