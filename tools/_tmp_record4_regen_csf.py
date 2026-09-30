# -*- coding: utf-8 -*-
"""记录4 三轮：cold_air_strike_fighter 卡图重生成（用户拍板"重生成"）。
旧图整体半透明发灰（solid 2.0% vs 健康轰炸机 6.0%），参数救不了，走 agnes 文生图。

管线：3 key 轮换出 3 候选 → flood 白底转透明 → 裁内容 → 按 mod_air_multirole /
cold_air_bomber 健康标定合成 512×512（翼展 ~84% 宽、竖直带心 y≈255）→ 审计输出。
用法：python tools/_tmp_record4_regen_csf.py gen   （生成+合成+审计）
      python tools/_tmp_record4_regen_csf.py apply 1   （选 N 号候选落盘敌我两版，先备份）
"""
import base64
import io
import json
import os
import re
import subprocess
import sys
from collections import deque

from PIL import Image
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_MD = os.path.join(ROOT, "tools", "_agnes_image_api.md")
BASE_URL = "https://apihub.agnes-ai.cn/v1"
MODEL = "agnes-image-2.1-flash"
SIZE = "1152x768"
RAW_DIR = os.path.join(ROOT, ".godot", "csf_regen")
ENEMY = os.path.join(ROOT, "assets", "card_icons", "enemy", "cold_air_strike_fighter.png")
PLAYER = os.path.join(ROOT, "assets", "card_icons", "player", "cold_air_strike_fighter.png")
BAK = os.path.join(ROOT, ".godot", "art_backup_csf_regen_20260926")

PROMPT = (
    "军事卡牌游戏 2D 插画素材：单架冷战时期双发重型喷气式战斗轰炸机，"
    "标准纯侧面正交视角，机头明确朝向画面左侧，平直水平飞行姿态。"
    "机身涂装为清晰实心的深灰蓝双色迷彩，边缘线干净锐利，涂装完全填实不透明，"
    "机身占画面宽度八成以上，位于画面正中偏下。座舱盖、脊背、两侧进气道、后掠主翼、"
    "双垂尾、尾喷口细节完整清晰可辨。背景为纯净无缝纯白色，画面中只有这一架飞机，"
    "没有任何地面、云朵、导弹尾焰、阴影、文字、边框和水印。"
)

os.makedirs(RAW_DIR, exist_ok=True)


def load_keys():
    src = open(KEY_MD, "r", encoding="utf-8").read()
    return re.findall(r"sk-[A-Za-z0-9]{20,}", src)


def call_api(prompt, key, out):
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": SIZE, "n": 1})
    tmp, resp = out + ".payload.json", out + ".resp.json"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(payload)
    subprocess.run(["curl", "--http1.1", "-s", "-X", "POST", BASE_URL + "/images/generations",
                    "-H", "Authorization: Bearer " + key, "-H", "Content-Type: application/json",
                    "--data-binary", "@" + tmp, "-o", resp, "--max-time", "180"],
                   capture_output=True, text=True, timeout=200)
    try:
        os.unlink(tmp)
    except OSError:
        pass
    content = open(resp, "r", encoding="utf-8", errors="replace").read()
    try:
        os.unlink(resp)
    except OSError:
        pass
    try:
        data = json.loads(content)
    except json.JSONDecodeError:
        print("  非法响应: " + content[:120])
        return None
    item = (data.get("data") or [{}])[0]
    url = item.get("url", "")
    b64 = item.get("b64_json", "")
    if b64:
        return base64.b64decode(b64)
    if url:
        r = subprocess.run(["curl", "--http1.1", "-s", "-L", url, "--max-time", "120"],
                           capture_output=True, timeout=150)
        return r.stdout or None
    print("  无图像: " + content[:160])
    return None


def flood_white_to_alpha(im, white_t=238):
    """与边连通的近白区转透明（同 flood_white_to_alpha 口径）。"""
    im = im.convert("RGBA")
    a = np.array(im)
    h, w = a.shape[:2]
    white = (a[:, :, 0] >= white_t) & (a[:, :, 1] >= white_t) & (a[:, :, 2] >= white_t) & (a[:, :, 3] > 0)
    seen = np.zeros((h, w), bool)
    dq = deque()
    for x in range(w):
        for y in (0, h - 1):
            if white[y, x] and not seen[y, x]:
                seen[y, x] = True
                dq.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if white[y, x] and not seen[y, x]:
                seen[y, x] = True
                dq.append((y, x))
    while dq:
        y, x = dq.popleft()
        a[y, x, 3] = 0
        for ny, nx in ((y-1, x), (y+1, x), (y, x-1), (y, x+1)):
            if 0 <= ny < h and 0 <= nx < w and white[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                dq.append((ny, nx))
    return Image.fromarray(a)


def matte_and_compose(raw_bytes, out_png):
    im = Image.open(io.BytesIO(raw_bytes)).convert("RGB")
    im = flood_white_to_alpha(im)
    a = np.array(im)
    al = a[:, :, 3]
    ys, xs = np.where(al > 30)
    if len(xs) < 500:
        return None
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    content = im.crop((x0, y0, x1 + 1, y1 + 1))
    # 机身残留半透明白雾压制：低 alpha 段重映射（30-140 → 30-235 拉实）
    ca = np.array(content)
    lo, hi = 30, 235
    m = (ca[:, :, 3] >= lo) & (ca[:, :, 3] <= hi)
    ca[:, :, 3][m] = (lo + (ca[:, :, 3][m] - lo) * (hi - lo) / (hi - lo)).astype(np.uint8)
    content = Image.fromarray(ca)
    # 合成：翼展=512 的 84%，竖直带心 y=255（对齐 mod_air_multirole / cold_air_bomber 标定）
    tw = int(512 * 0.84)
    th = max(1, round(content.height * tw / content.width))
    content = content.resize((tw, th), Image.LANCZOS)
    canvas = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    px = (512 - tw) // 2
    py = 255 - th // 2
    canvas.paste(content, (px, py), content)
    canvas.save(out_png)
    return out_png


def audit(path):
    a = np.asarray(Image.open(path).convert("RGBA"))
    al = a[:, :, 3]
    ys, xs = np.where(al > 10)
    solid = 100 * (al > 200).mean()
    rgb = a[:, :, :3][al > 200]
    return {"bbox": (int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())),
            "solid": round(float(solid), 1), "meanV": round(float(rgb.mean()), 0)}


def main_gen():
    keys = load_keys()
    print("keys:", len(keys))
    results = []
    for i in range(3):
        out = os.path.join(RAW_DIR, "cand%d" % i)
        raw = call_api(PROMPT, keys[i % len(keys)], out)
        if raw is None:
            print("cand%d 生成失败" % i)
            continue
        open(out + ".raw.png", "wb").write(raw)
        composed = matte_and_compose(raw, out + ".png")
        if composed is None:
            print("cand%d 内容过少" % i)
            continue
        m = audit(composed)
        print("cand%d -> %s audit=%s" % (i, composed, m))
        results.append(i)
    if results:
        # 候选对比条
        strip = Image.new("RGB", (512 * len(results) + 8 * (len(results) - 1), 512), (60, 62, 70))
        for k, i in enumerate(results):
            c = Image.open(os.path.join(RAW_DIR, "cand%d.png" % i)).convert("RGB")
            strip.paste(c, (k * 520, 0))
        strip.save(os.path.join(RAW_DIR, "candidates.png"))
        print("对比图:", os.path.join(RAW_DIR, "candidates.png"))


def main_apply(idx):
    src = os.path.join(RAW_DIR, "cand%d.png" % idx)
    assert os.path.exists(src), "候选不存在"
    os.makedirs(BAK, exist_ok=True)
    import shutil
    shutil.copy2(ENEMY, os.path.join(BAK, "enemy_cold_air_strike_fighter.png"))
    shutil.copy2(PLAYER, os.path.join(BAK, "player_cold_air_strike_fighter.png"))
    im = Image.open(src)
    im.save(ENEMY)
    im.transpose(Image.FLIP_LEFT_RIGHT).save(PLAYER)
    print("applied cand%d -> enemy+player（原图备份 %s）" % (idx, BAK))


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "gen"
    if cmd == "gen":
        main_gen()
    elif cmd == "apply":
        main_apply(int(sys.argv[2]))
