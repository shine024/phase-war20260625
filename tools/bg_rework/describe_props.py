# -*- coding: utf-8 -*-
"""
用 agnes-2.5-flash 多模态视觉模型描述背景图下半部的近景大物体。
输出：每个物体的类别 + 估算像素框 + 明显尺寸分级（相对画面中的坦克/人比例）。
用法：
  python tools/bg_rework/describe_props.py <image_path>
"""
import sys, json, base64, ssl, urllib.request

KEY = open("tools/_api_key.txt", encoding="utf-8").read().strip().splitlines()[0]
CHAT = "https://apihub.agnes-ai.com/v1/chat/completions"

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

path = sys.argv[1] if len(sys.argv) > 1 else r"docs/重修背景图/bg_level_07.png"
b64 = base64.b64encode(open(path, "rb").read()).decode()

INSTR = """This is a 1280x720 side-scrolling game battle background. The BOTTOM HALF (y=360..720) is the combat ground where unit sprites will stand.

List EVERY distinct foreground prop/object sitting on that open ground in the bottom half (crates, ammo boxes, barrels, sandbag piles, planks, wire, vehicles, wreckage, rocks, tree trunks, etc).

For EACH object output one line in EXACTLY this format:
OBJECT | name | approx pixel bbox x0,y0,x1,y1 | approx height in px | looks-larger-than-a-tank? yes/no

A tank sprite in this game is roughly 250 px tall; a soldier roughly 120 px. Judge each prop against those scales.
Also add one final line:
GROUND | brief description of the clean open ground areas (material, color, where they are)
Do not describe sky or distant midground. Be precise and terse. No markdown."""

body = {"model": "agnes-2.5-flash", "messages": [{"role": "user", "content": [
    {"type": "text", "text": INSTR},
    {"type": "image_url", "image_url": {"url": "data:image/png;base64," + b64}}]}]}

req = urllib.request.Request(CHAT, data=json.dumps(body).encode(),
    headers={"Authorization": "Bearer " + KEY, "Content-Type": "application/json"})
r = urllib.request.urlopen(req, timeout=180, context=ctx)
d = json.loads(r.read().decode())
print(d["choices"][0]["message"]["content"])
