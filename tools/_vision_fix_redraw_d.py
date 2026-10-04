# -*- coding: utf-8 -*-
## 视觉审计修复 D 组：3 张身份错卡原位重掷（图不对物）
##   mod_inf_technical 武装皮卡   018 现图=迷彩步战车 → 武装皮卡
##   fut_arm_prism     光棱坦克   026 现图=机械臂皮卡 → 棱镜激光坦克
##   mod_arm_abrams_mk2 艾布拉姆斯Mk.II 035 现图=T-55苏系 → M1A2 风格主战坦克
## 宪法: docs/统一化/STYLE_BIBLE.md 6.1 十段拼装 / 禁则12条 / 生成朝右 / 白底泛洪
## 共享说明: 018→platform_modern_light, 026→platform_future_heavy 同图受益（换血后更贴题）
## 用法:
##   python tools/_vision_fix_redraw_d.py            # 阶段1: 生成 raw 到 docs/待生成卡图_视觉修复D3/
##   python tools/_vision_fix_redraw_d.py --deploy   # 阶段2: 备份6文件→泛洪→512→player直出/enemy翻转→落盘
##   python tools/_vision_fix_redraw_d.py --preview  # 阶段3: 新旧对照图
import base64
import json
import os
import sys
import io
import time
import urllib.request

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_FILE = os.path.join(ROOT, "tools", "_api_key.txt")
with open(KEY_FILE, "r", encoding="utf-8") as f:
    API_KEY = f.readline().strip()
BASE_URL = "https://apihub.agnes-ai.com/v1/images/generations"
MODEL = "agnes-image-2.1-flash"
OUTDIR = os.path.join(ROOT, "docs", "待生成卡图_视觉修复D3")
BAK = os.path.join(ROOT, ".godot", "art_backup_visionfix_20261003", "cards")
os.makedirs(OUTDIR, exist_ok=True)

BASE_HEAD = ("single military unit or vehicle, full body, eye-level side view, facing right, "
             "unit fills about three quarters of the frame with even white margins, ")
LIGHT = "overcast diffused lighting, "
RIM_HIST = "one narrow cool sky-blue rim light along the back edge, "
RIM_SCIFI = "one narrow cyan rim light along the back edge, faint glow limited to emissive parts, "
PALETTE = ("muted cold palette of deep blue-grey steel and cold grey, ")
BRUSH = ("thick painterly illustration, clean painterly silhouettes defined by value contrast "
         "and a narrow rim light, smooth blended brushwork, hard-edge steel surfaces, ")
TAIL = "clean pure white background with NO ground"
NEG = "\ntext, perspective view, frame, ground, ceiling"

CASES = [
    ("mod_inf_technical", "vis_player_018", "vis_enemy_018",
     "modern " + BASE_HEAD + "historically accurate equipment detail, "
     "a single armed pickup truck with a mounted heavy machine gun on the open cargo bed, "
     "cab and truck bed clearly defined, four wheel pickup chassis, "
     + LIGHT + RIM_HIST + PALETTE + BRUSH + TAIL + NEG),
    ("fut_arm_prism", "vis_player_026", "vis_enemy_026",
     "near-future single hard-surface sci-fi unit or vehicle, full body, eye-level side view, facing right, "
     "a single tracked laser tank with a rotating turret carrying a large crystalline prism emitter cannon, "
     "sleek angular panel lines, layered hull armor, wide track runs, "
     "unit fills about three quarters of the frame with even white margins, "
     + LIGHT + RIM_SCIFI + PALETTE + BRUSH + TAIL + NEG),
    ("mod_arm_abrams_mk2", "vis_player_035", "vis_enemy_035",
     "modern " + BASE_HEAD + "historically accurate equipment detail, "
     "a single main battle tank with angular composite turret and top machine gun station, "
     "layered hull armor with side skirts, wide track runs, "
     + LIGHT + RIM_HIST + PALETTE + BRUSH + TAIL + NEG),
]


def gen_one(name, prompt, retries=4):
    out = os.path.join(OUTDIR, "%s_raw.png" % name)
    if os.path.isfile(out) and os.path.getsize(out) > 100000:
        print("[skip] %s raw 已存在" % name)
        return out
    body = json.dumps({"model": MODEL, "prompt": prompt, "size": "1152x768", "n": 1}).encode()
    for i in range(retries):
        req = urllib.request.Request(BASE_URL, data=body, headers={
            "Content-Type": "application/json", "Authorization": "Bearer " + API_KEY})
        try:
            t0 = time.time()
            with urllib.request.urlopen(req, timeout=180) as r:
                d = json.loads(r.read())
            item = d["data"][0]
            if item.get("b64_json"):
                png = base64.b64decode(item["b64_json"])
            else:
                with urllib.request.urlopen(item["url"], timeout=120) as r2:
                    png = r2.read()
            open(out, "wb").write(png)
            print("[gen] %s %.1fs %dKB" % (name, time.time() - t0, len(png) // 1024))
            return out
        except Exception as e:
            print("[retry%d] %s %s %s" % (i + 1, name, type(e).__name__, str(e)[:120]))
            time.sleep(50)
    raise RuntimeError("生成失败 " + name)


def flood_white_to_alpha(img, thresh=238):
    """从边缘泛洪清白底（tools/_tmp_b4_card_regen_b2.py 同款实现）"""
    from PIL import Image as PImage
    from collections import deque
    im = img.convert("RGBA")
    w, h = im.size
    px = im.load()
    seen = bytearray(w * h)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            r, g, b, a = px[x, y]
            if r >= thresh and g >= thresh and b >= thresh:
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            r, g, b, a = px[x, y]
            if r >= thresh and g >= thresh and b >= thresh:
                q.append((x, y))
    while q:
        x, y = q.popleft()
        if x < 0 or y < 0 or x >= w or y >= h or seen[y * w + x]:
            continue
        seen[y * w + x] = 1
        r, g, b, a = px[x, y]
        if r >= thresh and g >= thresh and b >= thresh:
            px[x, y] = (r, g, b, 0)
            q.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    return im


def fit_square(img, size):
    """透明后按内容 bbox contain 进 size 画布，内容占比 88%（deploy 终态口径）"""
    from PIL import Image as PImage
    bb = img.getchannel("A").getbbox()
    if not bb:
        return PImage.new("RGBA", (size, size), (0, 0, 0, 0))
    sub = img.crop(bb)
    w, h = sub.size
    scale = min(size * 0.88 / w, size * 0.88 / h)
    sub = sub.resize((max(1, int(w * scale)), max(1, int(h * scale))), PImage.LANCZOS)
    cv = PImage.new("RGBA", (size, size), (0, 0, 0, 0))
    cv.paste(sub, ((size - sub.width) // 2, (size - sub.height) // 2), sub)
    return cv


def stage_deploy():
    from PIL import Image
    os.makedirs(BAK, exist_ok=True)
    for name, p_rel, e_rel in [(c[0], c[1], c[2]) for c in CASES]:
        raw = os.path.join(OUTDIR, "%s_raw.png" % name)
        im = Image.open(raw)
        cut = fit_square(flood_white_to_alpha(im), 512)
        # 亮度门（黑剪影批次教训：本体必须是受光上色精灵）；不过则 gamma 0.82 中间调提亮一次复测
        import numpy as np
        def _stats(c):
            a = np.asarray(c)
            m = a[:, :, 3] > 16
            rgb = a[:, :, :3].astype(int)
            return (float(rgb[m].mean()) if m.any() else 0.0,
                    float((rgb.max(axis=2)[m] > 90).mean()) if m.any() else 0.0)
        body_mean, lit = _stats(cut)
        if body_mean < 55 or lit < 0.18:
            r, g, b, a = cut.split()
            lut = [int(round(255.0 * (i / 255.0) ** 0.82)) for i in range(256)]
            r, g, b = (ch.point(lut) for ch in (r, g, b))
            cut = Image.merge("RGBA", (r, g, b, a))
            body_mean, lit = _stats(cut)
        assert body_mean >= 55 and lit >= 0.18, "%s 亮度门不过 body=%.0f lit=%.2f" % (name, body_mean, lit)
        pp = os.path.join(ROOT, "assets", "card_icons", "player", "%s.png" % p_rel)
        ee = os.path.join(ROOT, "assets", "card_icons", "enemy", "%s.png" % e_rel)
        for f in (pp, ee):
            if os.path.isfile(f):
                dst = os.path.join(BAK, os.path.basename(f))
                if not os.path.isfile(dst):
                    with open(f, "rb") as a, open(dst, "wb") as b:
                        b.write(a.read())
        cut.save(pp)  # 生成即朝右 → player 直出
        cut.transpose(Image.FLIP_LEFT_RIGHT).save(ee)  # enemy = 水平翻转
        print("[deploy] %s → %s + %s (body=%.0f lit=%.2f)" % (name, os.path.basename(pp), os.path.basename(ee), body_mean, lit))
    print("deploy 完成; 备份于 .godot/art_backup_visionfix_20261003/cards/")


def stage_preview():
    from PIL import Image, ImageDraw, ImageFont
    f = ImageFont.truetype(r"C:\Windows\Fonts\msyh.ttc", 14)
    C = 230
    sheet = Image.new("RGB", (4 * (C + 8) + 16, len(CASES) * (C + 34) + 40), (14, 17, 21))
    d = ImageDraw.Draw(sheet)
    d.text((10, 8), "D组3卡重掷 [旧卡(朝左) | 新raw | 新player(朝右) | 新enemy(翻转朝左)]", fill=(238, 200, 120), font=f)
    y = 36
    for name, p_rel, e_rel in [(c[0], c[1], c[2]) for c in CASES]:
        d.rectangle([0, y, sheet.width, y + 20], fill=(26, 32, 40))
        d.text((8, y + 3), name, fill=(210, 220, 232), font=f)
        y += 22
        cells = []
        oe = Image.open(os.path.join(ROOT, "assets", "card_icons", "enemy", "%s.png" % e_rel)).convert("RGBA")
        raw = Image.open(os.path.join(OUTDIR, "%s_raw.png" % name)).convert("RGBA")
        np_ = Image.open(os.path.join(ROOT, "assets", "card_icons", "player", "%s.png" % p_rel)).convert("RGBA")
        ne = Image.open(os.path.join(ROOT, "assets", "card_icons", "enemy", "%s.png" % e_rel)).convert("RGBA")
        for im in (oe, raw, np_, ne):
            im.thumbnail((C, C), __import__("PIL.Image", fromlist=["LANCZOS"]).LANCZOS)
            bg = Image.new("RGB", (C, C), (40, 46, 54))
            bg.paste(im, ((C - im.width) // 2, (C - im.height) // 2), im)
            cells.append(bg)
        x = 8
        for c in cells:
            sheet.paste(c, (x, y))
            x += C + 8
        y += C + 10
    out = os.path.join(OUTDIR, "preview_D3.png")
    sheet.save(out)
    print("OK", out)


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    if mode == "--deploy":
        stage_deploy()
    elif mode == "--preview":
        stage_preview()
    else:
        for name, _, __, prompt in CASES:
            gen_one(name, prompt)
        print("阶段1完成: raw×3 →", OUTDIR)


if __name__ == "__main__":
    main()
