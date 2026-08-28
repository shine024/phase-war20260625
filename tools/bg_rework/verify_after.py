# -*- coding: utf-8 -*-
"""验收修复后的背景图：残留大道具？补丁痕迹/接缝/重复纹理？用法: python verify_after.py [image]"""
import sys, json, base64, ssl, urllib.request
from PIL import Image

KEY = open("tools/_api_key.txt", encoding="utf-8").read().strip().splitlines()[0]
CHAT = "https://apihub.agnes-ai.com/v1/chat/completions"
ctx = ssl.create_default_context(); ctx.check_hostname = False; ctx.verify_mode = ssl.CERT_NONE

def b64(p):
    return base64.b64encode(open(p, "rb").read()).decode()

FIXED = sys.argv[1] if len(sys.argv) > 1 else "docs/重修背景图/bg_level_07_fixed.png"
im = Image.open(FIXED).convert("RGB")
zooms = []
for i, box in enumerate([(0, 490, 260, 720), (300, 460, 680, 660), (680, 530, 1060, 720), (1020, 510, 1280, 720)]):
    c = im.crop(box)
    c = c.resize((c.width * 2, c.height * 2), Image.LANCZOS)
    p = "tools/bg_rework/_after_zoom_%d.png" % i
    c.save(p)
    zooms.append(p)

content = [{"type": "text", "text": """Image 1 = full game background (1280x720). Images 2-5 = 2x zooms of its bottom-left, bottom-center, bottom-middle-right and bottom-right corners.

IMPORTANT ZONES: the strip y=0..455 is DISTANT midground (treeline/ruins far away) — objects there are correctly small due to distance, IGNORE them entirely. The strip y=660..720 is the bottom-edge natural detail band (pebbles/small rocks, all tiny) — IGNORE it too. Your job: audit ONLY the open ground band y=455..660 where unit sprites will stand (a tank sprite there is ~82 px wide / ~70 px tall; a soldier ~41 px).

Answer TERSELY:
CHECK1 | In the band y=455..660 ONLY: any object that appears LARGER than or comparable to the tank scale (>60px tall)? bbox + what it is. Say NONE if none.
CHECK2 | In y=455..660: any visible patching artifacts, hard seams, obvious tiling repetition, or blur/texture inconsistency distinct from surrounding ground? Where?
CHECK3 | Overall: does the ground read as one continuous natural surface with consistent texture? Does the image keep a coherent painterly game-background style (no photorealism, no weird artifacts)?"""}]
content.append({"type": "image_url", "image_url": {"url": "data:image/png;base64," + b64(FIXED)}})
for p in zooms:
    content.append({"type": "image_url", "image_url": {"url": "data:image/png;base64," + b64(p)}})

body = {"model": "agnes-2.5-flash", "messages": [{"role": "user", "content": content}]}
req = urllib.request.Request(CHAT, data=json.dumps(body).encode(),
    headers={"Authorization": "Bearer " + KEY, "Content-Type": "application/json"})
r = urllib.request.urlopen(req, timeout=240, context=ctx)
print(json.loads(r.read().decode())["choices"][0]["message"]["content"])
