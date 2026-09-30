# -*- coding: utf-8 -*-
"""img25 锚定帧先行路线 · 阶段0工具：卡图 -> 游戏锚定帧（2026-09-30 新路线）

用法:
    python tools/img25_anchor_gen.py <key> [卡图路径]
    python tools/img25_anchor_gen.py fut_nano_drone
    python tools/img25_anchor_gen.py fut_nano_drone --chroma-out

产出（只落 staging，绝不写 assets/）:
    .godot/unit_review/img25_staging/<key>_anchor_raw.png     原始出图（品红底）
    .godot/unit_review/img25_staging/<key>_anchor_preview.png 抠品红后的棋盘格透明预览（--chroma-out）

方法论来源: chongdashu/ai-game-spritesheets 02-south-anchor（锚定帧=真身，
后续所有动画帧以它为 Image 1 身份锚；品红 chroma 背景根治白底 flood_matte 三类废因）。
"""
import argparse
import base64
import io
import json
import os
import re
import subprocess
import sys
import time

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEYS = re.findall(r'sk-[A-Za-z0-9]{20,}',
                  open(os.path.join(ROOT, 'tools', '_agnes_image_api.md'), encoding='utf-8').read())
IMG_API = "https://apihub.agnes-ai.cn/v1/images/generations"
WORK = os.path.join(ROOT, ".godot", "unit_review")
OUT = os.path.join(WORK, "img25_staging")

# 品红 chroma 键（repo 02 阶段规则）
CHROMA = (255, 0, 255)


def data_uri(path):
    with open(path, "rb") as f:
        return "data:image/png;base64," + base64.b64encode(f.read()).decode()


def build_prompt(subject):
    return (
        "第一张图是参考卡图。把它转换成单个 2D 游戏精灵锚定帧：" + subject + "。\n"
        "【视角·硬性】纯侧面剪影，面朝画面正左方，绝不朝右，绝不允许俯视、斜视或 3/4 视角。\n"
        "【构图】单主体居中，全身完整，四周留出约百分之五的空隙，主体任何部分不得触碰画布四边。\n"
        "【背景·硬性】整幅纯品红色 #FF00FF 平涂，主体轮廓之外没有任何杂色、阴影、地面、场景或渐变。\n"
        "【风格】无黑色描边、无轮廓线——直接上色的干净体积感画风，均匀顶光，轮廓清晰可读，配色与卡图一致。\n"
        "【姿态·硬性】中性悬停待机：武器收拢不开火，画面中没有火光、烟、弹道、光效、文字、水印、边框或任何附加物。"
    )


def gen_image(payload_path, key_idx=0):
    for i in range(3):
        r = subprocess.run(["curl", "--http1.1", "-s", "-X", "POST", IMG_API,
                            "-H", "Authorization: Bearer " + KEYS[(key_idx + i) % len(KEYS)],
                            "-H", "Content-Type: application/json",
                            "--data-binary", "@" + payload_path, "--max-time", "360"],
                           capture_output=True, text=True, timeout=380)
        try:
            d = json.loads(r.stdout)
        except Exception:
            print("  响应非 JSON:", r.stdout[:120], flush=True)
            time.sleep(15)
            continue
        if d.get("error") or d.get("code"):
            print("  API 报错:", json.dumps(d, ensure_ascii=False)[:180], flush=True)
            time.sleep(15)
            continue
        item = (d.get("data") or [{}])[0]
        if item.get("b64_json"):
            return base64.b64decode(item["b64_json"])
        if item.get("url"):
            dl = subprocess.run(["curl", "--http1.1", "-s", "-L", item["url"], "--max-time", "120"],
                                capture_output=True, timeout=140)
            try:
                Image.open(io.BytesIO(dl.stdout)).load()
                return dl.stdout
            except Exception:
                print("  URL 图不完整，重试…", flush=True)
                time.sleep(8)
    return None


def detect_bg_color(im):
    """实测背景色（agnes 色号服从差：要 #FF00FF 实给玫红 ~(206,36,124)，09-30 实测）。
    取四边 3px 边框中位色。"""
    import numpy as np
    a = np.asarray(im.convert("RGB")).astype(int)
    h, w, _ = a.shape
    border = np.concatenate([a[:3].reshape(-1, 3), a[-3:].reshape(-1, 3),
                             a[:, :3].reshape(-1, 3), a[:, -3:].reshape(-1, 3)])
    return np.median(border, axis=0)


def chroma_key(im, tol=85):
    """色度键控 v1：自适应背景采样（边框中位色）+ 边缘连通判定。
    tol=85 时连"贴地阴影"（与背景色距 ~62）也一并吃掉（09-30 fut_nano_drone 实测）。"""
    import numpy as np
    from collections import deque
    rgb = im.convert("RGB")
    a = np.asarray(rgb).astype(int)
    bg = detect_bg_color(rgb)
    dist = np.sqrt(((a - bg) ** 2).sum(axis=2))
    near = dist < tol
    h, w = near.shape
    bg = np.zeros_like(near, dtype=bool)
    dq = deque()
    for x in range(w):
        for y in (0, h - 1):
            if near[y, x] and not bg[y, x]:
                bg[y, x] = True
                dq.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if near[y, x] and not bg[y, x]:
                bg[y, x] = True
                dq.append((y, x))
    while dq:
        y, x = dq.popleft()
        for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if 0 <= ny < h and 0 <= nx < w and near[ny, nx] and not bg[ny, nx]:
                bg[ny, nx] = True
                dq.append((ny, nx))
    out = im.convert("RGBA")
    alpha = np.where(bg, 0, 255).astype('uint8')
    out.putalpha(Image.fromarray(alpha))
    return out


def checkerboard(size=16):
    from PIL import ImageDraw
    tile = Image.new("RGB", (size * 2, size * 2), (200, 200, 200))
    d = ImageDraw.Draw(tile)
    d.rectangle([size, 0, size * 2, size], fill=(240, 240, 240))
    d.rectangle([0, size, size, size * 2], fill=(240, 240, 240))
    return tile


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("key")
    ap.add_argument("card", nargs="?")
    ap.add_argument("--subject", default="参考图中的这架未来派纳米武装无人机（无人飞行器，画面中绝不允许出现任何人物）")
    ap.add_argument("--chroma-out", action="store_true")
    args = ap.parse_args()

    card = args.card or os.path.join(ROOT, "assets", "card_icons", "player", args.key + ".png")
    if not os.path.exists(card):
        print("卡图不存在:", card)
        sys.exit(1)
    os.makedirs(OUT, exist_ok=True)

    card_img = Image.open(card).convert("RGB").resize((512, 512), Image.LANCZOS)
    buf = card_img  # Data URI 直接用 512 版
    import tempfile
    uri = "data:image/png;base64," + base64.b64encode(_png_bytes(buf)).decode()
    payload = os.path.join(OUT, "_anchor_payload.json")
    with open(payload, "w", encoding="utf-8") as f:
        f.write(json.dumps({"model": "agnes-image-2.5-flash",
                            "prompt": build_prompt(args.subject),
                            "size": "1K", "ratio": "1:1",
                            "extra_body": {"image": [uri], "response_format": "b64_json"}},
                           ensure_ascii=False))
    print("生成中…", flush=True)
    t0 = time.time()
    raw = gen_image(payload)
    if raw is None:
        print("生成失败（3 掷皆废）")
        sys.exit(2)
    raw_path = os.path.join(OUT, args.key + "_anchor_raw.png")
    with open(raw_path, "wb") as f:
        f.write(raw)
    print("OK %s (%.0fs)" % (raw_path, time.time() - t0))

    if args.chroma_out:
        keyed = chroma_key(Image.open(io.BytesIO(raw)))
        board = checkerboard()
        bg = Image.new("RGB", keyed.size)
        for y in range(0, keyed.size[1], 32):
            for x in range(0, keyed.size[0], 32):
                bg.paste(board, (x, y))
        bg.paste(keyed, (0, 0), keyed)
        prev = os.path.join(OUT, args.key + "_anchor_preview.png")
        bg.save(prev)
        print("OK", prev)


def _png_bytes(im):
    b = io.BytesIO()
    im.save(b, "PNG")
    return b.getvalue()


if __name__ == "__main__":
    main()
