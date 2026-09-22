# -*- coding: utf-8 -*-
"""按名专属弹道/命中贴图批量生成器（VFX_IMPACT_TEXTURE_TODO 64 条死链收编）

管线：WEAPON_ID_MAP 解析 → 分族 prompt（agnes-image-2.1-flash，白底正交侧视）
→ 下载 → flood_white_to_alpha → 内容 bbox 裁切 → 按族目标内容宽归一 → 落 PNG。
可断点续跑（已存在且过审的文件跳过）；3 key 轮换；上游错误换 key 重试。

用法：
  python tools/_tmp_gen_weapons_realistic.py --status          # 进度盘点
  python tools/_tmp_gen_weapons_realistic.py --only 100mm主炮  # 单条试产（proj+impact）
  python tools/_tmp_gen_weapons_realistic.py                   # 全量（61 id × 2 侧）
"""
import base64
import hashlib
import json
import os
import re
import subprocess
import sys
import time
from collections import deque

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAP_GD = os.path.join(ROOT, "data", "weapon_vfx_mapping.gd")
API_DOC = os.path.join(ROOT, "tools", "_agnes_image_api.md")
OUT_DIR = os.path.join(ROOT, "assets", "effects", "projectiles", "weapons_realistic")
BASE_URL = "https://apihub.agnes-ai.com/v1"
MODEL = "agnes-image-2.1-flash"

# ── 族定义：内容宽(px)=显示宽×33（proj_scale=0.30×0.10 恒定系数）──
# 弹体尺寸律：显示恒 < 58.9px（一个兵基准）
FAMILIES = {
    "energy":     {"proj_w": 900,  "impact_w": 900},
    "missile":    {"proj_w": 1300, "impact_w": 900},
    "rocket":     {"proj_w": 1200, "impact_w": 900},
    "mortar":     {"proj_w": 1000, "impact_w": 900},
    "shell_aa":   {"proj_w": 800,  "impact_w": 900},
    "mg":         {"proj_w": 650,  "impact_w": 900},
    "smallarms":  {"proj_w": 600,  "impact_w": 900},
    "shell_heavy":{"proj_w": 1000, "impact_w": 900},
}

def classify(name: str) -> str:
    if re.search(r"电磁炮|轨道炮|激光|离子|粒子|等离子", name):
        return "energy"
    if re.search(r"导弹", name):
        return "missile"
    if re.search(r"火箭", name):
        return "rocket"
    if re.search(r"迫击炮|榴弹炮|野战炮", name):
        return "mortar"
    if re.search(r"高炮|高射炮|近防炮", name):
        return "shell_aa"
    if re.search(r"机枪", name):
        return "mg"
    if re.search(r"步枪|冲锋枪|卡宾枪|马刀", name):
        return "smallarms"
    return "shell_heavy"

SUBJECT = {
    "energy":     "glowing energy bolt, bright cyan-white plasma lance with electric arc filaments, elongated horizontal shape",
    "missile":    "guided missile, slim grey-olive missile body with bright red tip and four tail fins, thin white vapor trail stub on the left",
    "rocket":     "rocket projectile, thick dark-green rocket with pointed warhead and small fins, exhaust flame stub on the left",
    "mortar":     "mortar bomb, teardrop shaped dark-grey bomb with small tail fins, horizontal nose-right orientation",
    "shell_aa":   "small rapid-fire autocannon tracer shell, slender brass-copper cartridge with glowing orange tracer tip",
    "mg":         "heavy machine gun cartridge, small brass bullet with copper jacket and bright tracer tip",
    "smallarms":  "rifle cartridge, slim small brass bullet with pointed copper tip",
    "shell_heavy":"large tank gun armor-piercing shell, polished dark-steel artillery shell with brass driving band, nose pointing right",
}

IMPACT_DESC = {
    "energy":     "radial energy burst impact, bright blue-white plasma explosion radiating outward, electric arc star burst, cyan-blue glow",
    "missile":    "fiery orange explosion burst, bright yellow-orange fireball with black smoke puffs and red-hot debris flying outward",
    "rocket":     "fiery orange explosion burst, bright yellow-orange fireball with dark smoke and scattered glowing debris",
    "mortar":     "fiery orange ground-burst explosion, orange-yellow fireball with dirt debris and grey smoke tongues",
    "shell_aa":   "flak burst, radial orange sparks and small smoke puffs exploding outward in all directions from center",
    "mg":         "radial metal spark impact, bright yellow-white sparks radiating outward, tiny metallic flash",
    "smallarms":  "radial metal spark impact, bright yellow-white sparks radiating outward from center point",
    "shell_heavy":"fiery orange explosion burst, large yellow-orange fireball with grey-brown smoke and bright debris shards",
}

PROJ_PROMPT = (
    "2D game VFX sprite texture, single {subject}, perfectly horizontal orientation flying to the right, "
    "entire object fully inside frame with wide empty margins, clean vector-like game art, crisp silhouette, "
    "isolated on a solid pure white background #FFFFFF, no ground, no shadows, no motion blur, no text, "
    "no watermark, no frame, no extra objects"
)
IMPACT_PROMPT = (
    "2D game VFX sprite texture, {desc}, perfectly centered symmetrical star-burst, entire effect fully inside "
    "frame with wide empty margins, clean game art, isolated on a solid pure white background #FFFFFF, "
    "no ground, no shadows, no text, no watermark, no frame, no extra objects"
)

# ── 映射解析 ──

def load_map():
    txt = open(MAP_GD, "r", encoding="utf-8").read()
    return re.findall(r'"([^"]+)":\s*"([0-9a-f]{8})"', txt)

def load_keys():
    txt = open(API_DOC, "r", encoding="utf-8").read()
    return re.findall(r"sk-[A-Za-z0-9]+", txt)

# ── API ──

def call_api(prompt, key, size, out):
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": size, "n": 1})
    tmp, resp = out + ".payload.json", out + ".resp.json"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(payload)
    subprocess.run(["curl", "--http1.1", "-s", "-X", "POST", BASE_URL + "/images/generations",
                    "-H", "Authorization: Bearer " + key, "-H", "Content-Type: application/json",
                    "--data-binary", "@" + tmp, "-o", resp, "--max-time", "150"],
                   capture_output=True, text=True, timeout=180)
    try:
        os.unlink(tmp)
    except OSError:
        pass
    try:
        data = json.loads(open(resp, "r", encoding="utf-8", errors="replace").read())
    except Exception:
        data = {}
    try:
        os.unlink(resp)
    except OSError:
        pass
    if "data" not in data or not data["data"]:
        return False
    url = data["data"][0].get("url", "")
    if url:
        try:
            subprocess.run(["curl", "--http1.1", "-s", "-L", "-o", out, url, "--max-time", "150"],
                           capture_output=True, text=True, timeout=180)
            return os.path.getsize(out) > 1000
        except (OSError, subprocess.TimeoutExpired):
            return False
    b64 = data["data"][0].get("b64_json", "")
    if b64:
        try:
            with open(out, "wb") as f:
                f.write(base64.b64decode(b64))
            return os.path.getsize(out) > 1000
        except (OSError, ValueError):
            return False
    return False

# ── 后处理 ──

def flood_white_to_alpha(im, thresh=238):
    im = im.convert("RGBA")
    w, h = im.size
    work = im.copy()
    px = work.load()
    def is_white(p):
        return p[0] >= thresh and p[1] >= thresh and p[2] >= thresh
    seen = bytearray(w * h)
    dq = deque()
    for x in range(w):
        for y in (0, h - 1):
            if is_white(px[x, y]):
                dq.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if is_white(px[x, y]):
                dq.append((x, y))
    while dq:
        x, y = dq.popleft()
        if x < 0 or x >= w or y < 0 or y >= h:
            continue
        i = y * w + x
        if seen[i]:
            continue
        if not is_white(px[x, y]):
            continue
        seen[i] = 1
        px[x, y] = (255, 255, 255, 0)
        dq.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    return work

def content_bbox(im):
    alpha = im.getchannel("A")
    return alpha.getbbox()

def postprocess(raw_path, out_path, target_w, side, pad=16):
    try:
        im = Image.open(raw_path).convert("RGB")
    except Exception as e:
        return False, "broken image: %s" % type(e).__name__
    im = flood_white_to_alpha(im)
    bbox = content_bbox(im)
    if bbox is None:
        return False, "empty content"
    x0, y0, x1, y1 = bbox
    cw, ch = x1 - x0, y1 - y0
    if cw < 40 or ch < 12:
        return False, "content too small %dx%d" % (cw, ch)
    if side == "proj":
        ar = cw / float(ch)
        if ar < 1.2:
            return False, "proj not horizontal ar=%.2f" % ar
    else:
        ar = cw / float(ch)
        if ar > 2.2 or ar < 0.45:
            return False, "impact aspect off ar=%.2f" % ar
    crop = im.crop(bbox)
    scale = float(target_w) / cw
    nw, nh = target_w, max(2, int(ch * scale))
    crop = crop.resize((nw, nh), Image.LANCZOS)
    canvas = Image.new("RGBA", (nw + pad * 2, nh + pad * 2), (0, 0, 0, 0))
    canvas.paste(crop, (pad, pad), crop)
    canvas.save(out_path)
    return True, "%dx%d" % canvas.size

# ── 主流程 ──

def gen_one(name, sid, side, keys, key_idx):
    fam = classify(name)
    target_w = FAMILIES[fam]["proj_w" if side == "proj" else "impact_w"]
    out_path = os.path.join(OUT_DIR, "%s_%s.png" % (sid, side))
    if os.path.exists(out_path):
        return "skip"
    prompt = (PROJ_PROMPT if side == "proj" else IMPACT_PROMPT).format(
        subject=SUBJECT[fam], desc=IMPACT_DESC[fam])
    raw = out_path + ".raw.png"
    attempts = []
    for attempt in range(5):
        key = keys[(key_idx + attempt) % len(keys)]
        for size in ("1344x768", "1152x768", "1024x1024"):
            if call_api(prompt, key, size, raw):
                ok, info = postprocess(raw, out_path, target_w, side)
                try:
                    os.unlink(raw)
                except OSError:
                    pass
                if ok:
                    return "ok(%s,%s,%s)" % (size, fam, info)
                attempts.append("%s:%s" % (size, info))
        time.sleep(2)
    return "FAIL " + "; ".join(attempts[-3:])

def main():
    argv = sys.argv[1:]
    pairs = load_map()
    keys = load_keys()
    os.makedirs(OUT_DIR, exist_ok=True)
    if "--status" in argv:
        total = len(pairs)
        miss_p = [n for n, s in pairs if not os.path.exists(os.path.join(OUT_DIR, "%s_proj.png" % s))]
        miss_i = [n for n, s in pairs if not os.path.exists(os.path.join(OUT_DIR, "%s_impact.png" % s))]
        print("entries=%d distinct_sid=%d keys=%d" % (total, len(set(s for _, s in pairs)), len(keys)))
        print("proj missing: %d  impact missing: %d" % (len(miss_p), len(miss_i)))
        if miss_i:
            print("impact miss list:", miss_i[:8], "...")
        return
    if "--only" in argv:
        i = argv.index("--only")
        target = argv[i + 1]
        pairs = [(n, s) for n, s in pairs if n == target]
        if not pairs:
            print("no such weapon:", target)
            return
    todo = []
    seen = set()
    for n, s in pairs:
        for side in ("proj", "impact"):
            if (s, side) in seen:
                continue
            seen.add((s, side))
            if not os.path.exists(os.path.join(OUT_DIR, "%s_%s.png" % (s, side))):
                todo.append((n, s, side))
    shard, nshard = 0, 1
    if "--shard" in argv:
        i = argv.index("--shard")
        shard, nshard = (int(x) for x in argv[i + 1].split("/"))
        todo = [t for k, t in enumerate(todo) if k % nshard == shard]
    print("todo items: %d (shard %d/%d)" % (len(todo), shard, nshard))
    fails = 0
    key_idx = 0
    for i, (n, s, side) in enumerate(todo):
        r = gen_one(n, s, side, keys, key_idx)
        key_idx = (key_idx + 1) % len(keys)
        if r.startswith("FAIL"):
            fails += 1
        print("[%d/%d] %s(%s) %s -> %s" % (i + 1, len(todo), n, side, s[:8], r), flush=True)
        time.sleep(1)
    print("done. fails=%d" % fails)

if __name__ == "__main__":
    main()
