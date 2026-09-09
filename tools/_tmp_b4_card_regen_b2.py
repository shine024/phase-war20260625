#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""批次④ 批 2：卡图 C 档 3 张重生成（2026-09-09）。

清单（资产分档审计-2026-09-08 §卡图）：
  vis_player_001  禁则 3 炮塔白色字母标记（enemy 镜像必反字）+rim 缺位+暖 20-30%
  vis_player_075  禁则 11 Flak 88 画成科幻加特林塔（按二战写实防空重生成）
  fut_inf_c96     禁则 11 一战 C96 名画成现代战术步枪（按近未来冲锋枪设定重生成）

prompt=STYLE_BIBLE §6.1 十段拼装（era 插槽+三档构图串取至 even white margins 止
+6.1.2 主体句+固定锚段+负面栏五词）。宪法口径：生成一律 facing right，
player=直出，enemy=FLIP_LEFT_RIGHT（对调旧 deploy 模板的翻转目标）。
泛洪修正：边界泛洪白转透明（旧 white_to_alpha 全图亮度阈值会误抠浅色主体）。
"""
import json
import os
import subprocess
import sys
import time

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_FILE = os.path.join(ROOT, "tools", "_api_key.txt")
with open(KEY_FILE, "r", encoding="utf-8") as f:
    API_KEY = f.read().strip()
BASE_URL = "https://apihub.agnes-ai.com/v1"
MODEL = "agnes-image-2.0-flash"
OUT_DIR = os.path.join(ROOT, "docs", "待生成卡图_批2")
PLAYER_DIR = os.path.join(ROOT, "assets", "card_icons", "player")
ENEMY_DIR = os.path.join(ROOT, "assets", "card_icons", "enemy")
BACKUP_DIR = r"F:\godot fair duet\_art_backup"

RIM_REAL = "one narrow cool sky-blue rim light along the back edge"
RIM_SCIFI = "one narrow cyan rim light along the back edge, faint glow limited to emissive parts"
COMP_REAL = ("WWII single military unit or vehicle, full body, eye-level side view, facing "
             "right, historically accurate equipment detail, unit fills about three "
             "quarters of the frame with even white margins")
COMP_SCIFI = ("near-future single hard-surface sci-fi unit or vehicle, full body, eye-level "
              "side view, facing right, sleek angular panel lines, unit fills about three "
              "quarters of the frame with even white margins")
ANCHOR = ("overcast diffused lighting, {rim}, muted cold palette of deep blue-grey steel "
          "and cold grey, thick painterly illustration, clean painterly silhouettes defined "
          "by value contrast and a narrow rim light, smooth blended brushwork, hard-edge "
          "steel surfaces, clean pure white background with NO ground")
NEGATIVE = "text, perspective view, frame, ground, ceiling"

TANK = "a single tank with rotating turret and long main gun barrel, layered hull armor, wide track runs, plain unmarked hull"
FLAK = "a single anti-air gun mount with long barrel angled steeply upward on a cruciform platform, seat shield and ammunition racks"
INFANTRY_SCIFI = "a single foot soldier with shouldered compact energy SMG, full field pack and helmet, calm ready stance, plain unmarked field armor"

JOBS = [
    ("vis_player_001", COMP_REAL + ", " + TANK + ", " + ANCHOR.format(rim=RIM_REAL) + ". " + NEGATIVE),
    ("vis_player_075", COMP_REAL + ", " + FLAK + ", " + ANCHOR.format(rim=RIM_REAL) + ". " + NEGATIVE),
    ("fut_inf_c96", COMP_SCIFI + ", " + INFANTRY_SCIFI + ", " + ANCHOR.format(rim=RIM_SCIFI) + ". " + NEGATIVE),
]


def generate_image(prompt, output_path):
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": "1152x768", "n": 1})
    tmpfile = output_path + ".payload.json"
    with open(tmpfile, "w", encoding="utf-8") as f:
        f.write(payload)
    resp_file = output_path + ".resp.json"
    cmd = ["curl", "--http1.1", "-s", "-X", "POST", BASE_URL + "/images/generations",
           "-H", "Authorization: Bearer " + API_KEY,
           "-H", "Content-Type: application/json",
           "--data-binary", "@" + tmpfile, "-o", resp_file, "--max-time", "180"]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=200, encoding="utf-8")
    try:
        os.unlink(tmpfile)
    except OSError:
        pass
    if r.returncode != 0 or not os.path.exists(resp_file) or os.path.getsize(resp_file) < 10:
        return False, "curl/response failed"
    content = open(resp_file, encoding="utf-8").read()
    try:
        os.unlink(resp_file)
    except OSError:
        pass
    try:
        data = json.loads(content)
    except json.JSONDecodeError:
        return False, "not JSON: " + content[:120]
    url = None
    if isinstance(data.get("data"), list) and data["data"]:
        url = data["data"][0].get("url")
    if not url:
        return False, "no url: " + content[:120]
    dl = ["curl", "--http1.1", "-s", "-L", "-o", output_path, url, "--max-time", "180"]
    d = subprocess.run(dl, capture_output=True, timeout=200)
    if d.returncode != 0 or not os.path.exists(output_path) or os.path.getsize(output_path) < 50000:
        return False, "download failed"
    return True, "ok"


def flood_white_to_alpha(img: Image.Image, thresh: int = 238) -> Image.Image:
    """边界泛洪白转透明：只清除与图边连通的近白区，主体内部浅色/高光不动。"""
    rgb = img.convert("RGB")
    w, h = rgb.size
    px = rgb.load()
    from collections import deque
    def near_white(x, y):
        r, g, b = px[x, y]
        return r >= thresh and g >= thresh and b >= thresh
    visited = bytearray(w * h)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if near_white(x, y) and not visited[y * w + x]:
                visited[y * w + x] = 1
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if near_white(x, y) and not visited[y * w + x]:
                visited[y * w + x] = 1
                q.append((x, y))
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not visited[ny * w + nx] and near_white(nx, ny):
                visited[ny * w + nx] = 1
                q.append((nx, ny))
    out = rgb.convert("RGBA")
    opx = out.load()
    for y in range(h):
        base = y * w
        for x in range(w):
            if visited[base + x]:
                r, g, b, _ = opx[x, y]
                opx[x, y] = (r, g, b, 0)
    return out


def fit_square(img: Image.Image, size: int) -> Image.Image:
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


def main() -> int:
    os.makedirs(OUT_DIR, exist_ok=True)
    failed = []
    for fname, prompt in JOBS:
        raw = os.path.join(OUT_DIR, fname + "_raw.png")
        if not (os.path.exists(raw) and os.path.getsize(raw) > 50000):
            print("-- generate", fname, flush=True)
            ok, msg = generate_image(prompt, raw)
            if not ok:
                print("   FAIL:", msg, flush=True)
                failed.append(fname)
                continue
            time.sleep(2)
        im = Image.open(raw)
        print("   raw %s size=%s" % (fname, im.size), flush=True)

    if failed:
        print("[SUMMARY] failed:", ", ".join(failed))
        return 1

    # 部署（原图备份 → 泛洪 → 裁方 → player 直出 / enemy 翻转）
    os.makedirs(BACKUP_DIR, exist_ok=True)
    for fname, _ in JOBS:
        raw = os.path.join(OUT_DIR, fname + "_raw.png")
        for side, d in (("player", PLAYER_DIR), ("enemy", ENEMY_DIR)):
            orig = os.path.join(d, fname if side == "player" else fname.replace("vis_player_", "vis_enemy_").replace("fut_inf_", "fut_inf_"))
            if side == "enemy" and fname.startswith("fut_inf_"):
                orig = os.path.join(d, fname + ".png")
            if os.path.exists(orig):
                bdst = os.path.join(BACKUP_DIR, os.path.basename(orig).replace(".png", "-preB2-2026-09-09.png"))
                if not os.path.exists(bdst):
                    with open(orig, "rb") as fi, open(bdst, "wb") as fo:
                        fo.write(fi.read())
        cut = flood_white_to_alpha(Image.open(raw))
        sq = fit_square(cut, 512)
        # 宪法口径：player=直出（facing right），enemy=FLIP
        sq.save(os.path.join(PLAYER_DIR, fname + ".png"), "PNG")
        sq.transpose(Image.Transpose.FLIP_LEFT_RIGHT).save(
            os.path.join(ENEMY_DIR, fname + ".png"), "PNG")
        print("   deployed:", fname, "(player 直出 + enemy 翻转)", flush=True)
    print("[SUMMARY] deployed 3/3")
    return 0


if __name__ == "__main__":
    sys.exit(main())
