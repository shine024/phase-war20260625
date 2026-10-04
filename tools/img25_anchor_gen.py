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
        "【视角·硬性】纯侧面视角（正侧视图），面朝画面正左方，绝不朝右，绝不允许俯视、斜视或 3/4 视角。\n"
        "【构图】单主体居中，全身完整，四周留出约百分之五的空隙，主体任何部分不得触碰画布四边。\n"
        "【组成·硬性】部件组成与卡图完全一致，一个部件不许增、不许删、不许改："
        "严禁新增卡图中不存在的任何物体（无人机、僚机、浮游炮、额外人物、机械臂、背包、光环、平台、文字等）；"
        "严禁删除、替换或简化卡图已有的部件（炮塔、天线、桅杆、线圈塔、盾板、外挂武器、弹药箱等都要原位保留）。\n"
        "【配色·硬性】配色严格复刻卡图：明度、饱和度、色相以卡图为唯一标准——"
        "卡图是浅色、银白或沙色涂装就保持浅色，严禁整体压暗，严禁擅自改成黑色或深色涂装。\n"
        "【光照·硬性】主体完全受光、照明充足：高光、中间调、暗部层次分明，材质细节"
        "（纹理、徽标、舱盖、履带、武器结构）全部清晰可读。严禁画成黑色剪影，严禁逆光、背光或暗场照明，"
        "严禁把明度压到看不清细节——即使是深色涂装也必须保留高光与纹理层次，"
        "绝不允许输出单色深色轮廓块。\n"
        "【背景·硬性】整幅纯品红色 #FF00FF 平涂，主体轮廓之外没有任何杂色、阴影、地面、场景或渐变。\n"
        "【风格】无黑色描边、无轮廓线——直接上色的干净体积感画风，均匀顶光，轮廓清晰可读。\n"
        "【姿态·硬性】中性待机、不开火，姿态与卡图一致；画面中没有火光、硝烟、弹道、文字、水印、边框或任何附加物；"
        "卡图本体自带的常态光效（如线圈塔电弧、霓虹描线）是设备组成部分，必须保留。"
    )


def relight_prompt():
    """剪影废品回收 prompt（10-02 黑剪影批次 41 单位）：Image1=结构正确的深色废锚定，
    Image2=该单位正确配色标准（备份成品精灵 f0 品红底）。只修光照配色，不动结构。"""
    return (
        "第一张图是一张结构正确的 2D 游戏精灵锚定帧，但它被错误地画成了过暗的深色剪影；"
        "第二张图是同一单位的正确配色标准（官方成品精灵）。\n"
        "请输出一张新图，要求：\n"
        "【保持】完全保持第一张图的视角、构图、全部部件组成、姿态与大小——"
        "主体轮廓与第一张图逐部件重合，不新增、不删除、不简化任何部件；"
        "背景仍是整幅纯品红色 #FF00FF 平涂，无地面无阴影无场景。\n"
        "【只修光照与配色】严格按第二张图复刻主体涂装：色相、明度、饱和度、材质全部对齐第二张图——"
        "主体完全受光、色彩鲜明，高光与暗部层次分明，材质细节（纹理、徽标、舱盖、履带、武器结构）清晰可读；"
        "最亮处接近第二张图的高光亮度，最暗部位也不得比第二张图的最暗部位更暗。\n"
        "【严禁】黑色剪影、逆光、背光、暗场照明、整体压暗、单色深色轮廓块、"
        "改变视角或姿态、增删部件、文字、水印、边框。"
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


def lit_gate(im, ref_mean=None):
    """亮度门（10-02 黑剪影批次教训）：锚定帧本体必须是"受光的上色精灵"而非剪影。
    返回 (ok, info_dict)。判据：
    - bg_ok   边框中位色仍是品红系（R>150, G<110, B>90）——键控前提
    - body_px 本体像素（离背景色距>120）≥ 500
    - body_mean 本体平均亮度；给了 ref_mean 时要求 ≥ 0.55×ref（深色涂装按自身基准放行）
    - lit_frac 本体中 max(rgb)>90 的像素占比 ≥ 0.18
    """
    import numpy as np
    a = np.asarray(im.convert("RGB")).astype(int)
    bg = detect_bg_color(im)
    bg_ok = bool(bg[0] > 150 and bg[1] < 110 and bg[2] > 90)
    dist = np.sqrt(((a - bg) ** 2).sum(axis=2))
    body = dist > 120
    n = int(body.sum())
    info = {"bg_ok": bg_ok, "body_px": n, "bg": [round(float(v)) for v in bg]}
    if n < 500:
        info["verdict"] = "empty"
        return False, info
    rgb = a[body]
    mean = float(rgb.mean())
    lit = float((rgb.max(axis=1) > 90).mean())
    info.update(body_mean=round(mean, 1), lit_frac=round(lit, 2))
    ok = bg_ok and lit >= 0.18 and (ref_mean is None or mean >= ref_mean * 0.55)
    info["verdict"] = "pass" if ok else "dark"
    return ok, info


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
    import io as _io
    ok, info = lit_gate(Image.open(_io.BytesIO(raw)))
    print("亮度门:", json.dumps(info, ensure_ascii=False), flush=True)
    if not ok:
        print("!!! 剪影/暗场废品：请在 --subject 前先检查【光照·硬性】是否生效；"
              "重掷仍黑可用 relight_prompt() 回收（Image2=正确配色标准）", flush=True)
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
