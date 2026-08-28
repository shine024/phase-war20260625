# -*- coding: utf-8 -*-
"""检查左上疑点小块(0,494,199,544)是什么。"""
import json, base64, ssl, urllib.request
from PIL import Image

KEY = open("tools/_api_key.txt", encoding="utf-8").read().strip().splitlines()[0]
CHAT = "https://apihub.agnes-ai.com/v1/chat/completions"
ctx = ssl.create_default_context(); ctx.check_hostname = False; ctx.verify_mode = ssl.CERT_NONE

def b64(p):
    return base64.b64encode(open(p, "rb").read()).decode()

# 原图与修复图各裁 (0,455,260,585) 3x 放大
pair = []
for src, tag in [("docs/重修背景图/bg_level_07.png", "ORIG"), ("docs/重修背景图/bg_level_07_fixed.png", "FIXED")]:
    im = Image.open(src).convert("RGB")
    c = im.crop((0, 455, 260, 585))
    c = c.resize((c.width * 3, c.height * 3), Image.LANCZOS)
    p = "tools/bg_rework/_suspect_%s.png" % tag
    c.save(p)
    pair.append(p)

content = [{"type": "text", "text": """Two 3x-zoom crops of the SAME region (original pixels x0-260, y455-585) of a game battlefield background. Image 1 = BEFORE fix, Image 2 = AFTER fix.

This y-band is just above/at the top of the unit standing zone (units' feet stand around y521-586). Distant midground (treeline/ruins) is SUPPOSED to be visible above y~455 and is fine to keep.

Questions (terse):
Q1 | In BEFORE: what distinct objects do you see in y494-544 (the band between the distant treeline and the ground)? bbox + height + man-made or natural?
Q2 | In AFTER: same question — did any man-made object survive the fix in y494-560?
Q3 | In AFTER: any hard seam, color step, or unnatural rectangle boundary visible around y500-560 / x0-260?"""}]
for p in pair:
    content.append({"type": "image_url", "image_url": {"url": "data:image/png;base64," + b64(p)}})

body = {"model": "agnes-2.5-flash", "messages": [{"role": "user", "content": content}]}
req = urllib.request.Request(CHAT, data=json.dumps(body).encode(),
    headers={"Authorization": "Bearer " + KEY, "Content-Type": "application/json"})
r = urllib.request.urlopen(req, timeout=240, context=ctx)
print(json.loads(r.read().decode())["choices"][0]["message"]["content"])
