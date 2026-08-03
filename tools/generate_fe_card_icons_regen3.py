#!/usr/bin/env python3
"""重生成 3 张 fe_* 卡图（fe_nova_devastator / fe_void_phase_cannon / fe_helix_phantom）。
下载后用 PIL 校验完整性，损坏则重试，最多 5 次。"""
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
    {
        "fname": "fe_nova_devastator",
        "display": "歼灭者自行火炮（新星兵工·支援）",
        "prompt": STRICT + (
            "近未来科幻终极自行火炮平台，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面重型支援单位设定图，以【近未来·支援】歼灭者自行火炮为主体，"
            "完整单位居中入镜，多联装重型火箭/榴弹发射管阵列、重型履带底盘与指挥塔轮廓清晰，"
            "棱角分明的合金装甲与多管炮结构明确，金属磨损旧化，"
            "低饱和军灰主色，局部橙红能量炮膛与火控核心发光，Boss级火力威压感，"
            "干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEG
        ),
    },
    {
        "fname": "fe_void_phase_cannon",
        "display": "相位炮台（虚空相位·相位武器）",
        "prompt": STRICT + (
            "近未来科幻相位武器平台炮台，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面重型堡垒单位设定图，以【近未来·堡垒】相位炮台为主体，"
            "完整单位居中入镜，巨型相位主炮管、能量聚能环与悬浮基座轮廓清晰，"
            "棱角分明的相位合金装甲与能量管线结构明确，轻度磨损，"
            "低饱和暗紫黑主色，局部强烈紫色相位能量核心与共鸣纹路发光，神秘虚空威压感，"
            "干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEG
        ),
    },
    {
        "fname": "fe_helix_phantom",
        "display": "幻影特工（螺旋侦察·光学迷彩）",
        "prompt": STRICT + (
            "近未来科幻光学迷彩超级侦察兵，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面精锐人形单位设定图，以【近未来·轻装】幻影特工为主体，"
            "完整单位居中入镜，流线型迷彩外骨骼、双持消音武器与战术目镜轮廓清晰，"
            "半透明光学迷彩涂层与液压关节结构明确，轻度磨损，"
            "低饱和暗紫主色，局部亮紫光学迷彩光晕与眼缝发光，神秘潜行感，"
            "干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEG
        ),
    },
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
    subprocess.run(["curl", "--http1.1", "-4", "-s", "-L", "-o", out, url, "--max-time", "120"],
        capture_output=True, text=True, timeout=150)
    if not (os.path.exists(out) and os.path.getsize(out) > 1000):
        return False, "download failed"
    try:
        with Image.open(out) as im:
            im.load()
        return True, f"{im.size[0]}x{im.size[1]} {os.path.getsize(out)}B"
    except Exception as e:
        try: os.unlink(out)
        except: pass
        return False, "truncated: " + str(e)[:80]


os.makedirs(OUT_DIR, exist_ok=True)
print("BASE:", BASE, "| 重生成", len(UNITS), "张\n", flush=True)
for u in UNITS:
    out = os.path.join(OUT_DIR, u["fname"] + ".png")
    print("[" + u["display"] + "]", flush=True)
    for attempt in range(1, 6):
        print("  attempt", attempt, "...", flush=True)
        ok, msg = gen_once(u["prompt"], out)
        print("   ", "OK" if ok else "FAIL", msg, flush=True)
        if ok:
            break
        time.sleep(3)
    print(flush=True)
print("DONE", flush=True)
