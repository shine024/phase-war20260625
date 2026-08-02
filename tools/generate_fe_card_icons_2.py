#!/usr/bin/env python3
"""补生成 2 张卡（fe_frontier_veteran / fe_frontier_mixed_company）"""
import json, os, subprocess, time, sys
sys.stdout.reconfigure(encoding='utf-8', line_buffering=True)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_FILE = os.path.join(ROOT, "tools", "_api_key.txt")
with open(KEY_FILE, "r", encoding="utf-8") as f:
    API_KEY = f.read().strip()
BASE_URL = "https://apihub.agnes-ai.cn/v1"
MODEL = "agnes-image-2.0-flash"
OUTPUT_DIR = os.path.join(ROOT, "docs", "待生成卡图_14张fe")

STRICT = ("STRICTLY a pure 2D side profile silhouette view, absolutely NO front view, "
    "NO three-quarter view, NO perspective depth, flat orthographic game sprite, "
    "single subject only centered, clean pure white background with NO ground, "
    "NO shadow, NO floor, NO reflection, NO watermark, NO signature, NO text, "
    "NO extra sketches, NO character faces visible, NO environment, "
    "studio isolated product shot style. ")
NEG = ("不要：三分之四视角、斜侧视、透视 perspective、广角、仰视、俯视、等距 isometric、"
    "鸟瞰 top-down、看到顶部、背景场景、地面、投影底板、文字、水印、logo、人物。")

UNITS = [
    {"fname": "fe_frontier_veteran", "display": "边境老兵",
     "prompt": STRICT + (
        "现代科幻身经百战的老兵步兵，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
        "科幻硬表面精锐人形单位设定图，以【现代·轻装】边境老兵为主体，"
        "完整单位居中入镜，模块化战术外骨骼、突击步枪与多功能背包轮廓清晰，"
        "磨损但保养良好的合金装甲与战术挂载结构明确，中度磨损，"
        "低饱和卡其绿主色，局部亮琥珀色传感器与眼缝发光，沉稳老兵质感，"
        "干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEG)},
    {"fname": "fe_frontier_mixed_company", "display": "混编突击队",
     "prompt": STRICT + (
        "近未来科幻混编三位一体突击队，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
        "科幻硬表面中型装甲单位设定图，以【近未来·装甲】混编突击队为主体，"
        "完整单位居中入镜，轮式装甲车体、顶部防空导弹与侧挂步兵战斗舱轮廓清晰，"
        "棱角分明的多任务合金装甲与三系武器挂载结构明确，轻度磨损，"
        "低饱和军绿主色，局部亮琥珀色多功能传感器与核心发光，全能突击质感，"
        "干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEG)},
]

def gen(prompt, out):
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": "1024x1024", "n": 1})
    tmp = out + ".payload.json"
    with open(tmp, "w", encoding="utf-8") as f: f.write(payload)
    resp = out + ".resp.json"
    r = subprocess.run(["curl","--http1.1","-4","-s","-X","POST",BASE_URL+"/images/generations",
        "-H","Authorization: Bearer "+API_KEY,"-H","Content-Type: application/json",
        "--data-binary","@"+tmp,"-o",resp,"--max-time","120"],
        capture_output=True, text=True, timeout=150)
    try: os.unlink(tmp)
    except: pass
    if r.returncode != 0: return False, "curl exit "+str(r.returncode)
    content = open(resp, encoding="utf-8").read()
    try: os.unlink(resp)
    except: pass
    try: data = json.loads(content)
    except: return False, "not JSON: "+content[:200]
    if "data" not in data or len(data["data"])==0:
        err = data.get("error",{})
        return False, "no data: "+(err.get("message",str(data)[:200]) if isinstance(err,dict) else str(data)[:200])
    url = data["data"][0].get("url","")
    if not url: return False, "no url"
    subprocess.run(["curl","--http1.1","-4","-s","-L","-o",out,url,"--max-time","120"],
        capture_output=True, text=True, timeout=150)
    if os.path.exists(out) and os.path.getsize(out)>1000:
        return True, "OK ("+str(os.path.getsize(out))+" bytes)"
    return False, "download failed"

os.makedirs(OUTPUT_DIR, exist_ok=True)
print("BASE_URL:", BASE_URL, "| 生成", len(UNITS), "张", flush=True)
for i, u in enumerate(UNITS):
    out = os.path.join(OUTPUT_DIR, u["fname"]+".png")
    print("["+str(i+1)+"/"+str(len(UNITS))+"] "+u["display"]+"...", flush=True)
    ok, msg = gen(u["prompt"], out)
    if ok:
        print("  OK:", msg, flush=True)
    else:
        print("  FAIL:", msg, "重试...", flush=True)
        time.sleep(3)
        ok2, msg2 = gen(u["prompt"], out)
        print("  RETRY:", "OK" if ok2 else "FAIL", msg2, flush=True)
    time.sleep(1)
print("DONE", flush=True)
