#!/usr/bin/env python3
"""部署无人机群系列卡图：
  - 白底转透明 + 缩放512 + 复制到 enemy/ + 水平翻转到 player/
  与项目现有 vis_enemy_001~094 一致：512x512 RGBA 透明背景。
"""
import os
import subprocess
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(ROOT, "docs", "待生成卡图_无人机群")
ENEMY_DIR = os.path.join(ROOT, "assets", "card_icons", "enemy")
PLAYER_DIR = os.path.join(ROOT, "assets", "card_icons", "player")
OUT_SIZE = 512

# 文件名列表（无后缀）
FILES = [
    "fut_air_drone",
    "fe_aether_swarm_queen",
    "fut_swarm",
    "fut_attack_drone",
    "fut_nano_drone",
]


def white_to_alpha(img: Image.Image) -> Image.Image:
    """白底转透明（容差处理近白边缘）。"""
    rgb = img.convert("RGB")
    try:
        import numpy as np
        arr = np.array(rgb, dtype=np.int16)
        r, g, b = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]
        brightness = (r + g + b) / 3.0
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
    print(f"Deploying {len(FILES)} drone card icons...\n")
    print(f"Source:  {SRC_DIR}")
    print(f"Enemy:   {ENEMY_DIR}")
    print(f"Player:  {PLAYER_DIR}\n")

    ok = 0
    fail = 0
    for fname in FILES:
        src = os.path.join(SRC_DIR, f"{fname}.png")
        if not os.path.exists(src):
            print(f"SKIP {fname}: source not found at {src}")
            fail += 1
            continue

        try:
            img = Image.open(src)
            img = white_to_alpha(img)
            img = fit_square(img, OUT_SIZE)

            # Validate
            arr = list(img.getdata())
            non_trans = sum(1 for p in arr if p[3] > 0)
            if non_trans < 500:
                print(f"FAIL {fname}: too few non-transparent pixels ({non_trans})")
                fail += 1
                continue

            # Save enemy version
            enemy_path = os.path.join(ENEMY_DIR, f"{fname}.png")
            img.save(enemy_path, "PNG")
            print(f"OK enemy:  {fname}.png ({non_trans}px)")

            # Save player version (horizontal flip)
            player_path = os.path.join(PLAYER_DIR, f"{fname}.png")
            flipped = img.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            flipped.save(player_path, "PNG")
            print(f"OK player: {fname}.png (flipped)")

            ok += 1
        except Exception as e:
            print(f"FAIL {fname}: {e}")
            fail += 1

    print(f"\nDone: {ok} OK, {fail} FAIL")

    # Trigger Godot filesystem rescan via editor MCP if available
    try:
        result = subprocess.run(
            ["python", "-c", "import socket, json; s=socket.socket(); s.settimeout(3); s.connect(('127.0.0.1', 9920)); s.sendall((json.dumps({'id':1,'method':'editor.reload_filesystem'})+'\\n').encode()); buf=b''; \nwhile b'\\n' not in buf: c=s.recv(8192); \nif not c: break; buf+=c; s.close(); print(json.loads(buf.decode().strip()))"],
            capture_output=True, text=True, timeout=10
        )
        print(f"Filesystem rescan: {result.stdout[:100]}")
    except Exception:
        pass  # Editor not running, skip

    if fail > 0:
        import sys
        sys.exit(1)


if __name__ == "__main__":
    main()
