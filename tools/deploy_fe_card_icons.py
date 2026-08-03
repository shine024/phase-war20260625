#!/usr/bin/env python3
"""部署 14 张 fe_* 势力专属卡图：白底转透明 + 缩放512 + 落盘到 assets/card_icons/{card_id}.png。

与 vis_enemy/vis_player 不同，fe_* 是纯我方卡，AI 已生成正确朝向：
  - 不需要水平翻转（直接用原图朝向）
  - 不复制到 enemy/ 子目录（fe_* 无敌方版本）
  - 落盘到 card_icons/ 根目录，文件名 = card_id.png
    → 走引擎查找链①优先级（res://assets/card_icons/{card_id}.png），
      无需改 PLAYER_ICON_OVERRIDE 表，零代码改动。

规格：512x512 RGBA 透明背景（与现有 vis_player_* 一致）。
"""
import os
import sys
from PIL import Image

sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(ROOT, "docs", "待生成卡图_14张fe")
DEST_DIR = os.path.join(ROOT, "assets", "card_icons")
OUT_SIZE = 512

FILES = [
    "fe_iron_wall_bastion", "fe_iron_wall_juggernaut",
    "fe_nova_devastator", "fe_nova_ghost_sniper",
    "fe_aether_hover_cavalry", "fe_aether_swarm_queen",
    "fe_quantum_mobile_base", "fe_quantum_repair_drone",
    "fe_helix_phantom", "fe_helix_orbital_strike",
    "fe_void_phase_cannon", "fe_void_dimensional_soldier",
    "fe_frontier_veteran", "fe_frontier_mixed_company",
]


def white_to_alpha(img: Image.Image) -> Image.Image:
    """白底转透明（容差处理近白边缘）。复用 deploy_card_icons_11.py 算法。"""
    rgb = img.convert("RGB")
    try:
        import numpy as np
        arr = np.array(rgb, dtype=np.int16)
        r, g, b = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]
        brightness = (r + g + b) / 3.0
        # 平滑过渡：brightness 240→alpha 0, brightness 200→alpha 255
        alpha = np.clip((240 - brightness) * 6.375, 0, 255).astype(np.uint8)
        out = np.dstack([
            arr[:, :, 0].astype(np.uint8),
            arr[:, :, 1].astype(np.uint8),
            arr[:, :, 2].astype(np.uint8),
            alpha,
        ])
        return Image.fromarray(out, "RGBA")
    except ImportError:
        px = rgb.load()
        w, h = rgb.size
        out = Image.new("RGBA", (w, h))
        opx = out.load()
        for y in range(h):
            for x in range(w):
                r, g, b = px[x, y]
                brightness = (r + g + b) / 3.0
                if brightness >= 240:
                    a = 0
                elif brightness <= 200:
                    a = 255
                else:
                    a = int((240 - brightness) / 40 * 255)
                opx[x, y] = (r, g, b, max(0, min(255, a)))
        return out


def fit_square(img: Image.Image, size: int) -> Image.Image:
    """裁剪到内容边界 + 等比缩放到 size x size（居中，88%留白）。"""
    img = img.convert("RGBA")
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    w, h = img.size
    scale = min(size / w, size / h) * 0.88
    nw, nh = max(1, int(w * scale)), max(1, int(h * scale))
    img = img.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(img, ((size - nw) // 2, (size - nh) // 2), img)
    return canvas


def main():
    print("Deploying 14 fe_* faction card icons...")
    print(f"  SRC:  {SRC_DIR}")
    print(f"  DEST: {DEST_DIR}")
    print(f"  Size: {OUT_SIZE}x{OUT_SIZE} RGBA transparent\n")

    if not os.path.isdir(DEST_DIR):
        print(f"ERROR: DEST dir does not exist: {DEST_DIR}")
        return

    ok = 0
    fail = 0
    for fname in FILES:
        src = os.path.join(SRC_DIR, fname + ".png")
        if not os.path.exists(src):
            print(f"  SKIP {fname}: source not found")
            fail += 1
            continue

        try:
            img = Image.open(src)
            img.load()  # 校验完整性
            # 白底转透明
            img = white_to_alpha(img)
            # 裁剪 + 缩放到 512x512（不翻转，fe_* AI 已生成正确朝向）
            img = fit_square(img, OUT_SIZE)
            # 落盘到根目录
            dest_path = os.path.join(DEST_DIR, fname + ".png")
            img.save(dest_path, "PNG")
            print(f"  OK {fname}.png  ({img.size[0]}x{img.size[1]} {img.mode})")
            ok += 1
        except Exception as e:
            print(f"  FAIL {fname}: {e}")
            fail += 1

    print(f"\nDone: {ok} OK, {fail} FAIL")
    print(f"Files at: {DEST_DIR}/fe_*.png")
    print(f"\n下一步：Godot 编辑器首次导入会自动生成 .import 文件（无需手动）。")


if __name__ == "__main__":
    main()
