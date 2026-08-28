# -*- coding: utf-8 -*-
"""放大裁片送视觉模型核对道具内容与精确范围。"""
import json, base64, ssl, urllib.request, sys

KEY = open("tools/_api_key.txt", encoding="utf-8").read().strip().splitlines()[0]
CHAT = "https://apihub.agnes-ai.com/v1/chat/completions"
ctx = ssl.create_default_context(); ctx.check_hostname = False; ctx.verify_mode = ssl.CERT_NONE

def b64(p):
    return base64.b64encode(open(p, "rb").read()).decode()

regions = [
    ("LEFT_CLUSTER",  "tools/bg_rework/_zoom_left.png",   (0, 500, 250, 720)),
    ("RIGHT_CLUSTER", "tools/bg_rework/_zoom_right.png",  (690, 510, 1040, 720)),
    ("FAR_RIGHT_CORNER", "tools/bg_rework/_zoom_farright.png", (1030, 540, 1280, 720)),
    ("MID_BAND",      "tools/bg_rework/_zoom_mid.png",    (600, 490, 1000, 660)),
]
from PIL import Image
im = Image.open("docs/重修背景图/bg_level_07.png").convert("RGB")
for name, out, box in regions:
    c = im.crop(box)
    c = c.resize((c.width * 2, c.height * 2), Image.LANCZOS)
    c.save(out)

content = [{"type": "text", "text": """Four zoomed crops (2x) of one 1280x720 game battlefield background, in order:
1) LEFT_CLUSTER = original pixels x0-250, y500-720
2) RIGHT_CLUSTER = x690-1040, y510-720
3) FAR_RIGHT_CORNER = x1030-1280, y540-720
4) MID_BAND = x600-1000, y490-660
In-game a tank unit sprite is ~82 px wide and ~70 px tall in the ORIGINAL image scale (so ~41px wide in these 2x crops... no, crops are zoomed 2x, so tank would be ~164px wide / ~140px tall on screen).

For EACH crop: list every man-made or distinct prop object (crates, sandbags, posts, barrels, rope, wire, tools, wreckage) with its bbox IN ORIGINAL IMAGE PIXELS (remember crops are 2x zoom, divide by 2 and add the offsets above), and its approximate height in original px. Mark each object BIG (>60px), MEDIUM (30-60px), or SMALL (<30px). Also say what the bare ground looks like. Terse lines, format:
<REGION> | <name> | x0,y0,x1,y1 | h<N>px | BIG/MEDIUM/SMALL"""}]
for _, out, _ in regions:
    content.append({"type": "image_url", "image_url": {"url": "data:image/png;base64," + b64(out)}})

body = {"model": "agnes-2.5-flash", "messages": [{"role": "user", "content": content}]}
req = urllib.request.Request(CHAT, data=json.dumps(body).encode(),
    headers={"Authorization": "Bearer " + KEY, "Content-Type": "application/json"})
r = urllib.request.urlopen(req, timeout=240, context=ctx)
print(json.loads(r.read().decode())["choices"][0]["message"]["content"])
