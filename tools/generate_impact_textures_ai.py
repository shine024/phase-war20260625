"""agnes-ai 生成 2 张放射状命中贴图（128x128 黑底实心）

区别于拖尾的顺向条纹，命中应是放射状爆点——让"飞行"和"撞击"形状可分。
"""
import json, os, subprocess, sys, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_FILE = os.path.join(ROOT, "tools", "_api_key.txt")
BASE_URL = "https://apihub.agnes-ai.cn/v1"
MODEL = "agnes-image-2.0-flash"
OUT_DIR = os.path.join(ROOT, "assets", "effects", "particle_textures")

TEXTURES = [
    ("impact_metal", "radial metal spark burst impact, bright yellow-orange sparks radiating outward in all directions from center point, like bullet hitting steel, symmetrical star burst pattern, solid bright yellow-orange color, top-down view, perfectly centered, solid pure black background #000000, high contrast, game VFX sprite texture"),
    ("impact_energy", "radial energy burst impact, bright blue-white plasma explosion radiating outward in all directions from center, electric arc star burst, symmetrical energy discharge, solid bright cyan-blue color, top-down view, perfectly centered, solid pure black background #000000, high contrast, game VFX sprite texture"),
]

def load_keys():
    with open(KEY_FILE, "r", encoding="utf-8") as f:
        return [ln.strip() for ln in f if ln.strip()]

def call_api(prompt, key, size, out):
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": size, "n": 1})
    tmp, resp = out + ".payload.json", out + ".resp.json"
    with open(tmp, "w", encoding="utf-8") as f: f.write(payload)
    subprocess.run(["curl", "--http1.1", "-s", "-X", "POST", BASE_URL + "/images/generations",
           "-H", "Authorization: Bearer " + key, "-H", "Content-Type: application/json",
           "--data-binary", "@" + tmp, "-o", resp, "--max-time", "120"],
           capture_output=True, text=True, timeout=150)
    try: os.unlink(tmp)
    except: pass
    content = open(resp, "r", encoding="utf-8", errors="replace").read()
    try: os.unlink(resp)
    except: pass
    data = json.loads(content)
    url = data["data"][0].get("url", "")
    if url:
        subprocess.run(["curl", "--http1.1", "-s", "-L", "-o", out, url, "--max-time", "120"],
                       capture_output=True, text=True, timeout=150)
        return os.path.getsize(out) > 1000
    b64 = data["data"][0].get("b64_json", "")
    if b64:
        import base64
        with open(out, "wb") as f: f.write(base64.b64decode(b64))
        return os.path.getsize(out) > 1000
    return False

def main():
    keys = load_keys()
    print(f"生成 {len(TEXTURES)} 张放射状命中贴图")
    for i, (name, prompt) in enumerate(TEXTURES):
        out = os.path.join(OUT_DIR, name + ".png")
        key = keys[i % len(keys)]
        print(f"[{i+1}/{len(TEXTURES)}] {name} ...", end=" ", flush=True)
        ok = call_api(prompt, key, "1024x1024", out)
        print("OK" if ok else "FAIL")
        if i < len(TEXTURES)-1: time.sleep(3)
    print("完成")

if __name__ == "__main__":
    main()
