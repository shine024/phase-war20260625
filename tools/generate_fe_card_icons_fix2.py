#!/usr/bin/env python3
"""补生成 2 张损坏卡（fe_aether_hover_cavalry / fe_helix_phantom）。
下载后立即用 PIL 验证完整性，损坏则重试，最多 4 次。"""
import json, os, subprocess, sys, time
sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY = open(os.path.join(ROOT, "tools", "_api_key.txt"), encoding="utf-8").read().strip()
BASE = "https://apihub.agnes-ai.cn/v1"
OUT_DIR = os.path.join(ROOT, "docs", "待生成卡图_14张fe")

STRICT = ("STRICTLY a pure 2D side profile silhouette view, absolutely NO front view, "
    "NO three-quarter view, NO perspective depth, flat orthographic game sprite, "
    "single subject only centered, clean pure white background with NO ground, "
    "NO shadow, NO floor, NO reflection, NO watermark, NO signature, NO text, "
    "NO extra sketches, NO character faces visible, NO environment, "
    "studio isolated product shot style. ")
NEG = ("不要：三分之四视角、斜侧视、透视 perspective、广角、仰视、俯视、等距 isometric、"
    "鸟瞰 top-down、看到顶部、背景场景、地面、投影底板、文字、水印、logo、人物。")

UNITS = [
    {"fname": "fe_aether_hover_cavalry", "display": "以太骑兵",
     "prompt": STRICT + (
        "近未来科幻悬浮摩托突击队，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
        "科幻硬表面高速轻型单位设定图，以【近未来·轻装】以太骑兵为主体，"
        "完整单位居中入镜，悬浮摩托底盘、能量推进器与骑乘士兵轮廓清晰，"
        "流线型悬浮车体与侧挂武器结构明确，轻度磨损，"
        "低饱和亮青蓝主色，局部强烈蓝色悬浮能量场与推进尾焰发光，极速穿插感，"
        "干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEG)},
    {"fname": "fe_helix_phantom", "display": "幻影特工",
     "prompt": STRICT + (
        "近未来科幻光学迷彩超级侦察兵，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
        "科幻硬表面精锐人形单位设定图，以【近未来·轻装】幻影特工为主体，"
        "完整单位居中入镜，流线型迷彩外骨骼、双持消音武器与战术目镜轮廓清晰，"
        "半透明光学迷彩涂层与液压关节结构明确，轻度磨损，"
        "低饱和暗紫主色，局部亮紫光学迷彩光晕与眼缝发光，神秘潜行感，"
        "干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEG)},
]


def gen_once(prompt, out):
    payload = json.dumps({"model": "agnes-image-2.0-flash", "prompt": prompt, "size": "1024x1024", "n": 1})
    tmp = out + ".payload.json"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(payload)
    resp = out + ".resp.json"
    r = subprocess.run(["curl", "--http1.1", "-4", "-s", "-X", "POST", BASE + "/images/generations",
        "-H", "Authorization: Bearer " + KEY, "-H", "Content-Type: application/json",
        "--data-binary", "@" + tmp, "-o", resp, "--max-time", "120"],
        capture_output=True, text=True, timeout=150)
    try: os.unlink(tmp)
    except: pass
    if r.returncode != 0:
        return False, "curl exit " + str(r.returncode)
    content = open(resp, encoding="utf-8").read()
    try: os.unlink(resp)
    except: pass
    try: data = json.loads(content)
    except: return False, "not JSON: " + content[:150]
    if "data" not in data or not data["data"]:
        err = data.get("error", {})
        return False, "no data: " + (err.get("message", "") if isinstance(err, dict) else "")
    url = data["data"][0].get("url", "")
    if not url:
        return False, "no url"
    # 下载
    subprocess.run(["curl", "--http1.1", "-4", "-s", "-L", "-o", out, url, "--max-time", "120"],
        capture_output=True, text=True, timeout=150)
    if not (os.path.exists(out) and os.path.getsize(out) > 1000):
        return False, "download failed"
    # PIL 完整性校验
    try:
        with Image.open(out) as im:
            im.load()
        return True, f"{im.size[0]}x{im.size[1]} {os.path.getsize(out)}B"
    except Exception as e:
        try: os.unlink(out)
        except: pass
        return False, "truncated: " + str(e)[:80]


os.makedirs(OUT_DIR, exist_ok=True)
for u in UNITS:
    out = os.path.join(OUT_DIR, u["fname"] + ".png")
    print("[" + u["display"] + "]", flush=True)
    for attempt in range(1, 5):
        print("  attempt", attempt, "...", flush=True)
        ok, msg = gen_once(u["prompt"], out)
        print("   ", "OK" if ok else "FAIL", msg, flush=True)
        if ok:
            break
        time.sleep(3)
    print(flush=True)
print("DONE", flush=True)
