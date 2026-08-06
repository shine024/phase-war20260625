"""粒子贴图 + 爆炸帧序列生成（agnes-ai API）

为 Phase War v9.2 真实感提升生成 14 张 VFX 贴图。
用法: cd tools && python generate_particle_and_explosion_vfx.py
"""
import json
import os
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_FILE = os.path.join(ROOT, "tools", "_api_key.txt")
BASE_URL = "https://apihub.agnes-ai.cn/v1"
MODEL = "agnes-image-2.0-flash"
PARTICLE_DIR = os.path.join(ROOT, "assets", "effects", "particle_textures")
EXPLOSION_DIR = os.path.join(ROOT, "assets", "effects", "explosion_frames")

TEXTURES = [
    ("particle_spark", "32x32", PARTICLE_DIR, "bright orange-yellow elongated spark streak, fiery metal spark flying, glowing tip with trailing ember, top-down view, perfectly centered, solid pure black background #000000, high contrast, game VFX sprite texture"),
    ("particle_smoke", "32x32", PARTICLE_DIR, "small puffy smoke ball, volumetric gray-white smoke cloud, soft edges, subtle inner glow, top-down view, perfectly centered, symmetrical, solid pure black background #000000, high contrast, game VFX sprite texture"),
    ("particle_shrapnel", "32x32", PARTICLE_DIR, "metallic shrapnel fragment, jagged irregular shape, warm steel-gray body with orange edge glow from heat, top-down view, perfectly centered, solid pure black background #000000, high contrast, game VFX sprite texture"),
    ("particle_ember", "32x32", PARTICLE_DIR, "small glowing ember dot, bright orange core with soft yellow halo, single point of light, warm fire color, top-down view, perfectly centered, solid pure black background #000000, high contrast, game VFX sprite texture"),
]
for i in range(6):
    phase = ["beginning", "expanding", "peak", "fading", "dissipating", "aftermath"][i]
    TEXTURES.append(("explosion_conv_f%d" % i, "512x512", EXPLOSION_DIR, 
        "military explosive fireball %s, bright orange-red flame core with yellow-white hottest center, thick smoke billowing outward, top-down view, perfectly centered, symmetrical, solid pure black background #000000, high contrast, game VFX sprite texture, frame %d of 6" % (phase, i+1)))
    TEXTURES.append(("explosion_energy_f%d" % i, "512x512", EXPLOSION_DIR,
        "energy explosion %s, bright white-blue plasma sphere with electric arcs radiating outward, glowing energy rim, top-down view, perfectly centered, symmetrical, solid pure black background #000000, high contrast, game VFX sprite texture, frame %d of 6" % (phase, i+1)))

def load_keys():
    with open(KEY_FILE, "r", encoding="utf-8") as f:
        keys = [ln.strip() for ln in f if ln.strip()]
    if not keys:
        sys.exit("ERROR: " + KEY_FILE + " 为空")
    return keys

def mask(key):
    return key[:6] + "..." + key[-4:] if len(key) > 12 else key[:3] + "..." + key[-3:]

def call_api(prompt, key, size, tag, output_path):
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": size, "n": 1})
    tmpfile = output_path + ".payload.json"
    resp_file = output_path + ".resp.json"
    with open(tmpfile, "w", encoding="utf-8") as f:
        f.write(payload)
    cmd = ["curl", "--http1.1", "-s", "-X", "POST", BASE_URL + "/images/generations",
           "-H", "Authorization: Bearer " + key, "-H", "Content-Type: application/json",
           "--data-binary", "@" + tmpfile, "-o", resp_file, "--max-time", "120"]
    subprocess.run(cmd, capture_output=True, text=True, timeout=150)
    try: os.unlink(tmpfile)
    except: pass
    if not os.path.exists(resp_file) or os.path.getsize(resp_file) < 10:
        return False, "无响应文件"
    content = open(resp_file, "r", encoding="utf-8", errors="replace").read()
    try: os.unlink(resp_file)
    except: pass
    try:
        data = json.loads(content)
    except:
        return False, "响应非 JSON"
    if "data" not in data or len(data["data"]) == 0:
        return False, "无 data"
    url = data["data"][0].get("url", "")
    if not url:
        b64 = data["data"][0].get("b64_json", "")
        if b64:
            import base64
            with open(output_path, "wb") as f:
                f.write(base64.b64decode(b64))
            return os.path.getsize(output_path) > 1000, "OK(b64)"
        return False, "无 URL"
    dl_cmd = ["curl", "--http1.1", "-s", "-L", "-o", output_path, url, "--max-time", "120"]
    subprocess.run(dl_cmd, capture_output=True, text=True, timeout=150)
    return os.path.exists(output_path) and os.path.getsize(output_path) > 1000, "OK(url)"

def main():
    os.makedirs(PARTICLE_DIR, exist_ok=True)
    os.makedirs(EXPLOSION_DIR, exist_ok=True)
    keys = load_keys()
    print("粒子+爆炸帧生成: %d 张" % len(TEXTURES))
    print("Key: %s 个" % len(keys))
    success = failed = 0
    for i, (tid, size, d, prompt) in enumerate(TEXTURES):
        out = os.path.join(d, tid + ".png")
        if os.path.exists(out) and os.path.getsize(out) > 1000:
            print("[%d/%d] %s 已存在，跳过" % (i+1, len(TEXTURES), tid))
            success += 1; continue
        key = keys[i % len(keys)]
        print("[%d/%d] %s (%s) ..." % (i+1, len(TEXTURES), tid, size), end=" ", flush=True)
        ok, msg = call_api(prompt, key, size, tid, out)
        print("OK" if ok else "FAIL")
        if ok: success += 1
        else: failed += 1
        if i < len(TEXTURES) - 1: time.sleep(3)
    print("完成: %d/%d" % (success, len(TEXTURES)))
    if failed: print("失败: %d 张" % failed)

if __name__ == "__main__":
    main()
