# -*- coding: utf-8 -*-
"""
AI 视角重摄方案：让 img2img 模型把背景改为"远距 100 米长焦视角"，
地面物体因距离全部变小，从根本上解决近景道具比坦克大的比例失衡。

管线（复用 docs/3x3_vs_3x3/工作流定稿/背景图_3x3反推改图_工作流.py 已验证结构）：
  1. agnes-2.5-flash 反推原图：锁定时间/天气/色调/天空/地平线/地面材质（跳过前景物件）
  2. agnes-image-2.1-flash img2img：原图 base64（extra_body.image 数组，i2i 生效标志 = URL 含 /i2i/）
     + 反推描述 + 视角改写指令（100 米远距长焦 + 地面物体全部小 + 保留氛围）
  3. 下载 → 等比缩放裁剪到 1280x720
用法：python tools/bg_rework/ai_rework.py [in.png] [out.png]
"""
import sys, json, time, ssl, base64, urllib.request

KEY = open("tools/_api_key.txt", encoding="utf-8").read().strip().splitlines()[0]
CHAT = "https://apihub.agnes-ai.com/v1/chat/completions"
IMG = "https://apihub.agnes-ai.com/v1/images/generations"

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

src_path = sys.argv[1] if len(sys.argv) > 1 else "docs/重修背景图/bg_level_07.png"
out_path = sys.argv[2] if len(sys.argv) > 2 else "docs/重修背景图/bg_level_07_ai_50m.png"

# 反推指令：锁定氛围/天空/地面材质，跳过前景物件（3x3 工作流同款思想）
REVERSE_INSTR = ("Describe this game background image's VISUAL APPEARANCE in ONE flowing English paragraph "
    "for use as an image-generation prompt. Focus ONLY on: time of day, weather, color palette and mood, "
    "the SKY, and the distant horizon silhouette line. Then describe the ground MATERIAL and color only. "
    "Do NOT describe any foreground objects, props, debris, crates, sacks, planks, wire, barriers, mounds or "
    "structures — treat the foreground as empty open ground. "
    "Use neutral terms a landscape artist would use; avoid military/war/weapon/injury vocabulary.")

# 视角改写指令（用户方案：图片下边地面离拍摄者 100 米 → 长焦远距视角，物体全部因距离变小）
# 遵循已沉淀教训：不用百分比、正向描述目标形态、避开 line/band/strip/fog 词、人物正负双保险
MODIFY = ("Re-shoot the SAME scene from a MORE DISTANT viewpoint: the camera now stands about 50 meters away, "
    "so the whole battlefield is seen from a moderate remove. "
    "The ground strip at the very bottom edge of the frame is now 50 meters from the viewer. "
    "Because of this viewing distance, EVERYTHING resting on the ground reads as SMALL: "
    "the sandbag clusters, crates, wooden posts, barrels and rope coils that once loomed large in the near "
    "foreground are now removed or shrunk into small distant bits no bigger than a helmet. "
    "Keep the SAME weather, sky, color mood and ground material as the original. "
    "The ground is one continuous, fairly level open expanse stretching across the full frame width, "
    "dotted only with sparse low grass tufts, small pebbles and faint wheel tracks, "
    "so the open field where game units stand is clean and readable. "
    "Near the very bottom edge keep only a thin line of small natural ground details (stones, grass tufts). "
    "Natural ambient light. No people, no soldiers, no vehicles, no text, no UI, no watermark. "
    "No harsh edges or borders anywhere. Same painterly game-background art style as the original.")

def post(url, body, timeout=300):
    for a in range(1, 5):
        try:
            req = urllib.request.Request(url, data=json.dumps(body).encode(),
                headers={"Authorization": "Bearer " + KEY, "Content-Type": "application/json"})
            r = urllib.request.urlopen(req, timeout=timeout, context=ctx)
            return json.loads(r.read().decode())
        except urllib.error.HTTPError as e:
            err = e.read().decode()
            print("  HTTP %d %s" % (e.code, err[:200]))
            if a < 4:
                time.sleep(3); continue
            raise
        except Exception as e:
            print("  net err %r" % e)
            if a < 4:
                time.sleep(3); continue
            raise

src_bytes = open(src_path, "rb").read()
b64 = base64.b64encode(src_bytes).decode()

# ---------- 1) 反推 ----------
print("[1/3] reverse-engineering atmosphere ...")
body = {"model": "agnes-2.5-flash", "messages": [{"role": "user", "content": [
    {"type": "text", "text": REVERSE_INSTR},
    {"type": "image_url", "image_url": {"url": "data:image/png;base64," + b64}}]}]}
d = post(CHAT, body, timeout=180)
desc = d["choices"][0]["message"]["content"]
open("tools/bg_rework/_reverse_cache.txt", "w", encoding="utf-8").write(desc)
print("  desc:", desc[:160].replace("\n", " "))

# ---------- 2) img2img ----------
print("[2/3] img2img re-shoot (telephoto 100m) ...")
body = {"model": "agnes-image-2.1-flash", "prompt": desc + " " + MODIFY, "size": "1792x1024",
    "extra_body": {"image": ["data:image/png;base64," + b64], "response_format": "url"}}
d = post(IMG, body, timeout=600)
item = d["data"][0]
img_url = item.get("url", "")
print("  url path marker:", "/i2i/" in img_url and "i2i OK" or "WARNING not i2i")
if not img_url and item.get("b64_json"):
    raw = base64.b64decode(item["b64_json"])
else:
    req = urllib.request.Request(img_url)
    raw = urllib.request.urlopen(req, timeout=240, context=ctx).read()
open("tools/bg_rework/_ai_raw.png", "wb").write(raw)
print("  raw saved (%d bytes)" % len(raw))

# ---------- 3) 归一到 1280x720 ----------
from PIL import Image
import io
im = Image.open(io.BytesIO(raw)).convert("RGB")
w, h = im.size
print("[3/3] raw size %dx%d -> 1280x720" % (w, h))
target = 1280 / 720
if abs(w / h - target) > 0.01:
    if w / h > target:
        nw = int(h * target); x0 = (w - nw) // 2; im = im.crop((x0, 0, x0 + nw, h))
    else:
        nh = int(w / target); y0 = (h - nh) // 2; im = im.crop((0, y0, w, y0 + nh))
im = im.resize((1280, 720), Image.LANCZOS)
im.save(out_path)
print("saved:", out_path)
