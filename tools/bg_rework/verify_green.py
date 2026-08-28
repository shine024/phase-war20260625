# -*- coding: utf-8 -*-
"""
绿修复验收：检查 green_fix.py 输出——绿标记漆是否残留、填充是否自然无缝。
用法：python tools/bg_rework/verify_green.py bg_level_24.png bg_level_29.png ...
"""
import sys, json, base64, ssl, urllib.request
sys.stdout.reconfigure(encoding="utf-8", errors="replace")

KEY = open("tools/_api_key.txt", encoding="utf-8").read().strip().splitlines()[0]
CHAT = "https://apihub.agnes-ai.com/v1/chat/completions"
ctx = ssl.create_default_context(); ctx.check_hostname = False; ctx.verify_mode = ssl.CERT_NONE
OPENER = urllib.request.build_opener(urllib.request.HTTPSHandler(context=ctx), urllib.request.ProxyHandler({}))  # 直连 opener：urlopen(context=) 会无视 install_opener 重建带系统代理的 opener，必须用 OPENER.open  # 绕过系统代理(本地VPN端口不在时urllib会拒连,curl不受影响)

DIR = "docs/重修背景图/"
names = sys.argv[1:]
if not names:
    import glob, os
    names = [os.path.basename(p) for p in sorted(glob.glob(DIR + "bg_level_*.png"))]

def b64(p):
    return base64.b64encode(open(p, "rb").read()).decode()

results = {}
for name in names:
    path = DIR + name
    body = {"model": "agnes-2.5-flash", "messages": [{"role": "user", "content": [
        {"type": "text", "text": """This game background was just edited: some unwanted objects (painted over with bright green marker by the user) were removed via masked inpainting, and the holes filled with matching scenery. Natural green GRASS or foliage drawn as part of the fill is FINE and expected.

Answer ONE line, format:
VERDICT | PASS or FAIL | if FAIL: say exactly what's wrong

FAIL means any of: (a) visible bright green MARKER PAINT still present (solid saturated green blobs with hard paint-like edges, NOT natural grass); (b) an obvious rectangular seam, color patch, or blurred smear where the fill meets the original; (c) a structurally impossible fill (e.g. ground horizon line broken or duplicated)."""},
        {"type": "image_url", "image_url": {"url": "data:image/png;base64," + b64(path)}}]}]}
    ans = ""
    for attempt in range(3):
        try:
            req = urllib.request.Request(CHAT, data=json.dumps(body).encode(),
                headers={"Authorization": "Bearer " + KEY, "Content-Type": "application/json"})
            r = OPENER.open(req, timeout=240)
            ans = json.loads(r.read().decode())["choices"][0]["message"]["content"].strip()
            break
        except Exception as e:
            print("  retry %d for %s: %r" % (attempt + 1, name, e), flush=True)
    print("=== %s ===" % name, flush=True)
    print(ans[:400], flush=True)
    results[name] = ans

open("tools/bg_rework/_green_verify_results.txt", "w", encoding="utf-8").write(
    "\n\n".join("=== %s ===\n%s" % kv for kv in results.items()))
print("\nsaved tools/bg_rework/_green_verify_results.txt", flush=True)
