# -*- coding: utf-8 -*-
"""
视觉抽检 flagged 重摄图：判定站立带内的高对比块是"远处地平线结构(正常透视)"
还是"站位区大道具(需重跑)"。
用法：python tools/bg_rework/vision_triage.py bg_level_31.png bg_level_32.png ...
"""
import sys, json, base64, ssl, urllib.request
from PIL import Image

KEY = open("tools/_api_key.txt", encoding="utf-8").read().strip().splitlines()[0]
CHAT = "https://apihub.agnes-ai.com/v1/chat/completions"
ctx = ssl.create_default_context(); ctx.check_hostname = False; ctx.verify_mode = ssl.CERT_NONE
OPENER = urllib.request.build_opener(urllib.request.HTTPSHandler(context=ctx), urllib.request.ProxyHandler({}))  # 直连 opener：urlopen(context=) 会无视 install_opener 重建带系统代理的 opener，必须用 OPENER.open  # 绕过系统代理(本地VPN端口不在时urllib会拒连,curl不受影响)

DIR = "docs/重修背景图/"
names = sys.argv[1:]

def b64(p):
    return base64.b64encode(open(p, "rb").read()).decode()

results = {}
for name in names:
    path = DIR + name
    im = Image.open(path).convert("RGB")
    # 站立带全景裁片（y455-680），1.5x
    band = im.crop((0, 440, 1280, 690))
    band = band.resize((int(band.width * 1.5), int(band.height * 1.5)), Image.LANCZOS)
    bp = "tools/bg_rework/_triage_band.png"
    band.save(bp)

    content = [{"type": "text", "text": """Image 1 = full game battle background (1280x720, telephoto 100m look). Image 2 = 1.5x zoom of the band y=440..690 where game unit sprites stand (tank sprite ~82px wide/~70px tall on image-1 scale).

The distant treeline/horizon structures near the TOP of image 2 (y=440..510 on image-1 scale) are DISTANT scenery seen from 100m away — they are correctly small due to distance and are FINE. Only objects that sit ON the open ground IN FRONT of that horizon (i.e. in y=510..690) matter.

Answer ONE line, format:
VERDICT | PASS or FAIL | if FAIL: list each offending object with bbox on image-1 scale + approx height + what it is
FAIL means: an object in y=510..690 that is as large as or larger than the tank scale (>60px tall) and clearly in the foreground/on the ground (not distant horizon scenery, not a flat wet patch/shadow on the ground)."""}]
    content.append({"type": "image_url", "image_url": {"url": "data:image/png;base64," + b64(path)}})
    content.append({"type": "image_url", "image_url": {"url": "data:image/png;base64," + b64(bp)}})

    body = {"model": "agnes-2.5-flash", "messages": [{"role": "user", "content": content}]}
    ok, ans = False, ""
    for attempt in range(3):
        try:
            req = urllib.request.Request(CHAT, data=json.dumps(body).encode(),
                headers={"Authorization": "Bearer " + KEY, "Content-Type": "application/json"})
            r = OPENER.open(req, timeout=240)
            ans = json.loads(r.read().decode())["choices"][0]["message"]["content"].strip()
            ok = True
            break
        except Exception as e:
            print("  retry %d for %s: %r" % (attempt + 1, name, e), flush=True)
    print("=== %s ===" % name, flush=True)
    print(ans[:600], flush=True)
    results[name] = ans

open("tools/bg_rework/_triage_results.txt", "w", encoding="utf-8").write(
    "\n\n".join("=== %s ===\n%s" % kv for kv in results.items()))
print("\nsaved tools/bg_rework/_triage_results.txt", flush=True)
