"""agnes-ai 生成 8 张粒子贴图（128x128 黑底实心）

按核武工作流：纯黑底 + 高对比主体，后续 PIL 阈值抠图。
每张贴图代表一种武器的粒子形状，让命中/枪口/拖尾有清晰轮廓。
"""
import json, os, subprocess, sys, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_FILE = os.path.join(ROOT, "tools", "_api_key.txt")
BASE_URL = "https://apihub.agnes-ai.cn/v1"
MODEL = "agnes-image-2.0-flash"
OUT_DIR = os.path.join(ROOT, "assets", "effects", "particle_textures")

# 8 张贴图：每张都是独立清晰的形状，128x128 实心
TEXTURES = [
    ("spark_metal", "single bright yellow-orange metal spark streak, elongated horizontal fiery line with glowing hot tip, like a bullet impact spark, solid bright yellow-orange color, top-down view, perfectly centered, solid pure black background #000000, high contrast, game VFX sprite texture, no background"),
    ("spark_energy", "single bright blue-white plasma energy arc, jagged lightning bolt shape with electric glow, crackling electricity, solid bright cyan-blue color, top-down view, perfectly centered, solid pure black background #000000, high contrast, game VFX sprite texture, no background"),
    ("spark_heavy", "single glowing orange metal shrapnel fragment, irregular jagged chunk with hot glowing edges, piece of debris, solid orange-red color, top-down view, perfectly centered, solid pure black background #000000, high contrast, game VFX sprite texture, no background"),
    ("smoke_generic", "single puffy gray smoke cloud ball, dense volumetric smoke puff, soft round cloud shape, solid gray color, top-down view, perfectly centered, solid pure black background #000000, high contrast, game VFX sprite texture, no background"),
    ("smoke_energy", "single glowing blue energy smoke cloud, plasma vapor wisp, electric blue translucent cloud, solid blue-cyan color, top-down view, perfectly centered, solid pure black background #000000, high contrast, game VFX sprite texture, no background"),
    ("muzzle_light", "muzzle flash from small firearm, bright orange-yellow flash burst, compact fireball with small sparks, centered explosion of light, solid bright orange color, top-down view, perfectly centered, solid pure black background #000000, high contrast, game VFX sprite texture, no background"),
    ("muzzle_heavy", "large cannon muzzle flash, big bright orange-red fireball blast with thick smoke ring, heavy artillery flash, solid bright orange-red color, top-down view, perfectly centered, solid pure black background #000000, high contrast, game VFX sprite texture, no background"),
    ("spark_ember", "single small glowing ember dot, bright orange fire point with soft yellow halo, tiny burning particle, solid bright orange color, top-down view, perfectly centered, solid pure black background #000000, high contrast, game VFX sprite texture, no background"),
]

def load_keys():
    with open(KEY_FILE, "r", encoding="utf-8") as f:
        keys = [ln.strip() for ln in f if ln.strip()]
    return keys

def mask(k):
    return k[:6]+"..."+k[-4:] if len(k)>12 else k[:3]+"..."+k[-3:]

def call_api(prompt, key, size, tag, out):
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": size, "n": 1})
    tmp = out + ".payload.json"
    resp = out + ".resp.json"
    with open(tmp, "w", encoding="utf-8") as f: f.write(payload)
    cmd = ["curl", "--http1.1", "-s", "-X", "POST", BASE_URL + "/images/generations",
           "-H", "Authorization: Bearer " + key, "-H", "Content-Type: application/json",
           "--data-binary", "@" + tmp, "-o", resp, "--max-time", "120"]
    subprocess.run(cmd, capture_output=True, text=True, timeout=150)
    try: os.unlink(tmp)
    except: pass
    if not os.path.exists(resp) or os.path.getsize(resp) < 10:
        return False, "无响应"
    content = open(resp, "r", encoding="utf-8", errors="replace").read()
    try: os.unlink(resp)
    except: pass
    try:
        data = json.loads(content)
    except:
        return False, "响应非JSON"
    if "data" not in data or len(data["data"]) == 0:
        return False, "无data"
    url = data["data"][0].get("url", "")
    if not url:
        b64 = data["data"][0].get("b64_json", "")
        if b64:
            import base64
            with open(out, "wb") as f: f.write(base64.b64decode(b64))
            return os.path.getsize(out) > 1000, "OK(b64)"
        return False, "无URL"
    subprocess.run(["curl", "--http1.1", "-s", "-L", "-o", out, url, "--max-time", "120"],
                   capture_output=True, text=True, timeout=150)
    return os.path.exists(out) and os.path.getsize(out) > 1000, "OK(url)"

def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    keys = load_keys()
    print(f"生成 {len(TEXTURES)} 张粒子贴图 (128x128)")
    print(f"Key: {len(keys)} 个")
    # 先删除旧的（避免跳过）
    for name, _ in TEXTURES:
        old = os.path.join(OUT_DIR, name + ".png")
        if os.path.exists(old):
            os.remove(old)
    ok = 0
    for i, (name, prompt) in enumerate(TEXTURES):
        out = os.path.join(OUT_DIR, name + ".png")
        key = keys[i % len(keys)]
        print(f"[{i+1}/{len(TEXTURES)}] {name} ...", end=" ", flush=True)
        success, msg = call_api(prompt, key, "1024x1024", name, out)
        print("OK" if success else "FAIL")
        if success: ok += 1
        else: print(f"    {msg}")
        if i < len(TEXTURES) - 1: time.sleep(3)
    print(f"\n完成: {ok}/{len(TEXTURES)}")

if __name__ == "__main__":
    main()
