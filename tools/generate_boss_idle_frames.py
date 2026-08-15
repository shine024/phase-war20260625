"""BOSS 待机帧动画生成(agnes-image img2img + 黑底抠图) — P2

用法:
  python tools/generate_boss_idle_frames.py            # 试点 2 个 boss(f1~f5)
  python tools/generate_boss_idle_frames.py --all      # 全部 5 个 boss

流程:
  1. 取 boss 现有卡图(512 RGBA 透明) → 合成纯黑底 → base64
  2. img2img: "100% 相同,仅整体上移 N 像素(悬浮循环某相位)" → 黑底输出
  3. 黑底反抠(un-multiply:max 通道为 alpha,还原 RGB) → 透明 RGBA
  4. 存 assets/effects/unit_anims/<archetype_id>/idle_f1~f5.png
     (f0 不生成——直接复制原卡图,作为零漂移锚定帧)

BossIdleAnim.attach() 检测到 ≥2 帧自动播放,详见 docs/BOSS_IDLE_ANIM_SPEC.md
"""
import base64
import io
import json
import os
import ssl
import sys
import time
import urllib.request

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_FILE = os.path.join(ROOT, "tools", "_api_key.txt")
IMG = "https://apihub.agnes-ai.com/v1/images/generations"
MODEL = "agnes-image-2.1-flash"

# 帧位移(悬浮循环,f1~f5;f0=原图): 上移像素。f5≈回位 → 与 f0 无缝循环
FRAME_PX = [7, 12, 8, 3, 1]

TARGETS = [
    {
        "id": "cold_boss_mig",
        "base": "assets/card_icons/enemy/vis_enemy_056.png",
        "motion": "the whole aircraft body shifts straight UP by {px} pixels (hovering bob animation), everything else stays identical",
    },
    {
        "id": "fut_boss_nexus",
        "base": "assets/card_icons/enemy/vis_enemy_071.png",
        "motion": "the whole mech body shifts straight UP by {px} pixels and its glowing energy core brightens slightly (hovering bob animation). CRITICAL: the silhouette, wingspan and body width must stay EXACTLY the same as the input image, do not redraw the mech thinner or narrower, wings fully spread identically",
    },
]

TARGETS_ALL = TARGETS + [
    {
        "id": "ww1_boss_av7",
        "base": "assets/card_icons/enemy/vis_enemy_042.png",
        "motion": "the whole armored vehicle body shifts straight UP by {px} pixels (idle suspension bob animation). CRITICAL: silhouette, size and proportions must stay EXACTLY the same as the input image",
    },
    {
        "id": "ww2_boss_kingtiger",
        "base": "assets/card_icons/enemy/vis_enemy_049.png",
        "motion": "the whole heavy tank body shifts straight UP by {px} pixels (idle suspension bob animation). CRITICAL: silhouette, size and proportions must stay EXACTLY the same as the input image",
    },
    {
        "id": "mod_boss_command",
        "base": "assets/card_icons/enemy/vis_enemy_064.png",
        "motion": "the whole command vehicle shifts straight UP by {px} pixels and its radar dish rotates a few degrees (idle scanning animation). CRITICAL: silhouette and body width must stay EXACTLY the same as the input image",
    },
]


def load_keys():
    with open(KEY_FILE, encoding="utf-8") as f:
        return [ln.strip() for ln in f if ln.strip()]


def flatten_black(png_path):
    """透明卡图 → 纯黑底 PNG bytes(512)。"""
    im = Image.open(png_path).convert("RGBA")
    if im.size != (512, 512):
        im = im.resize((512, 512), Image.LANCZOS)
    bg = Image.new("RGBA", (512, 512), (0, 0, 0, 255))
    bg.alpha_composite(im)
    buf = io.BytesIO()
    bg.convert("RGB").save(buf, format="PNG")
    return buf.getvalue()


def key_black(im):
    """黑底 → 透明(v2 软阈值,不反预乘)。
    v1 反预乘把中间调吹白(均值 110→242)。v2: alpha=smooth(max通道),RGB 保持模型输出。
    """
    im = im.convert("RGB")
    px = im.load()
    out = Image.new("RGBA", im.size)
    po = out.load()
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            r, g, b = px[x, y]
            m = max(r, g, b)
            if m <= 18:
                po[x, y] = (0, 0, 0, 0)
            elif m >= 48:
                po[x, y] = (r, g, b, 255)
            else:
                a = (m - 18) * 255 // 30
                po[x, y] = (r, g, b, a)
    return out


def content_bbox(im):
    """alpha>32 的内容框。"""
    px = im.load()
    minx, miny, maxx, maxy = im.size[0], im.size[1], -1, -1
    for y in range(0, im.size[1], 2):
        for x in range(0, im.size[0], 2):
            if px[x, y][3] > 32:
                if x < minx: minx = x
                if x > maxx: maxx = x
                if y < miny: miny = y
                if y > maxy: maxy = y
    if maxx < 0:
        return None
    return (minx, miny, maxx, maxy)


def color_match(src, ref):
    """逐通道增益匹配:把 src 不透明区均值调到 ref 不透明区均值(修复模型提亮漂移)。"""
    sp, rp = src.load(), ref.load()
    sums = [0, 0, 0]; sumr = [0, 0, 0]; n = 0
    for y in range(0, src.size[1], 4):
        for x in range(0, src.size[0], 4):
            if sp[x, y][3] > 64 and rp[x, y][3] > 64:
                n += 1
                for c in range(3):
                    sums[c] += sp[x, y][c]; sumr[c] += rp[x, y][c]
    if n < 50:
        return src
    gains = []
    for c in range(3):
        ms = sums[c] / n; mr = sumr[c] / n
        gains.append(min(1.8, max(0.5, mr / max(ms, 1))))
    for y in range(src.size[1]):
        for x in range(src.size[0]):
            r, g, b, a = sp[x, y]
            if a > 0:
                sp[x, y] = (min(255, int(r * gains[0])), min(255, int(g * gains[1])),
                            min(255, int(b * gains[2])), a)
    return src


def normalize_to_base(frame, base, dy):
    """v2 关键矫正:生成图内容 bbox 缩放到 f0 尺寸,贴回 f0 中心(含本帧 dy 位移)。
    模型不守构图(实测小 ~20%),程序保证帧间尺寸/位置严格一致,只留内容差异。"""
    fb = content_bbox(frame)
    bb = content_bbox(base)
    if fb is None or bb is None:
        return frame
    content = frame.crop(fb)
    bw = bb[2] - bb[0]; bh = bb[3] - bb[1]
    fw = fb[2] - fb[0]; fh = fb[3] - fb[1]
    scale = min(bw / fw, bh / fh)
    nw, nh = max(1, int(fw * scale)), max(1, int(fh * scale))
    content = content.resize((nw, nh), Image.LANCZOS)
    canvas = Image.new("RGBA", base.size, (0, 0, 0, 0))
    cx = (bb[0] + bb[2]) // 2; cy = (bb[1] + bb[3]) // 2
    canvas.alpha_composite(content, (cx - nw // 2, cy - nh // 2 + dy))
    return canvas


def call_img2img(prompt, image_png_bytes, key, size="1024x1024"):
    b64 = base64.b64encode(image_png_bytes).decode()
    body = {
        "model": MODEL,
        "prompt": prompt,
        "size": size,
        "extra_body": {"image": ["data:image/png;base64," + b64], "response_format": "url"},
    }
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    req = urllib.request.Request(
        IMG, data=json.dumps(body).encode(),
        headers={"Authorization": "Bearer " + key, "Content-Type": "application/json"})
    r = urllib.request.urlopen(req, timeout=300, context=ctx)
    d = json.loads(r.read().decode())
    url = d["data"][0].get("url", "")
    if not url:
        raise RuntimeError("no url: " + str(d)[:200])
    with urllib.request.urlopen(url, timeout=120, context=ctx) as resp:
        return resp.read()


def main():
    targets = TARGETS_ALL if "--all" in sys.argv else TARGETS
    keys = load_keys()
    key_idx = 0
    for t in targets:
        out_dir = os.path.join(ROOT, "assets", "effects", "unit_anims", t["id"])
        os.makedirs(out_dir, exist_ok=True)
        base_path = os.path.join(ROOT, t["base"])
        if not os.path.exists(base_path):
            print("[%s] BASE MISSING: %s" % (t["id"], t["base"]))
            continue
        # f0 = 原卡图直接复制(零漂移锚定帧)
        base_im = Image.open(base_path).convert("RGBA")
        if base_im.size != (512, 512):
            base_im = base_im.resize((512, 512), Image.LANCZOS)
        base_im.save(os.path.join(out_dir, "idle_f0.png"))
        black_png = flatten_black(base_path)
        for i, dy in enumerate(FRAME_PX, start=1):
            out_png = os.path.join(out_dir, "idle_f%d.png" % i)
            if os.path.exists(out_png) and os.path.getsize(out_png) > 2000:
                print("[%s] f%d exists, skip" % (t["id"], i))
                continue
            prompt = (
                "Recreate this exact game card art character 100% identical: same character, "
                "same pose, same composition, same colors, same lighting, same framing, same size, centered. "
                "ONLY change: " + t["motion"].format(px=dy) + ". "
                "Solid pure black background #000000 everywhere around the character. "
                "Clean sharp edges, no text, no watermark, no border, no drop shadow on the black background."
            )
            ok = False
            for attempt in range(4):
                key = keys[key_idx % len(keys)]
                try:
                    raw = call_img2img(prompt, black_png, key)
                    im = Image.open(io.BytesIO(raw))
                    if im.size != (512, 512):
                        im = im.resize((512, 512), Image.LANCZOS)
                    # v2 流水线:软阈值抠图 → 色彩增益匹配(对 f0) → bbox 归一化(对 f0,含 dy)
                    keyed = key_black(im)
                    keyed = color_match(keyed, base_im)
                    keyed = normalize_to_base(keyed, base_im, -dy)  # 上移=负 y
                    keyed.save(out_png)
                    print("[%s] f%d OK (%.0fKB, key %d)" % (t["id"], i, os.path.getsize(out_png) / 1024, key_idx % len(keys)))
                    ok = True
                    break
                except Exception as e:
                    print("[%s] f%d try%d FAIL: %s" % (t["id"], i, attempt + 1, str(e)[:160]))
                    key_idx += 1  # 换 key 重试
                    time.sleep(3)
            if not ok:
                print("[%s] f%d GAVE UP" % (t["id"], i))
            time.sleep(2)
    print("DONE")


if __name__ == "__main__":
    main()
