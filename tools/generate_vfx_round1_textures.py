"""agnes-ai 生成 v26.11 视觉轮 2 张新粒子贴图（黑底生成 + PIL 抠图）

1. energy_muzzle_jet.png  (1024x1024, 内容横向能量喷流) — 替换误用的
   weapon_artillery_muzzle.png（暖色炮口焰照片，蓝 ramp 乘出橄榄泥点）。
2. smoke_puff_light.png   (128x128, 浅灰白软烟团) — 弹道尾烟专用（旧
   smoke_generic 均值 0.40 过暗，MIX 叠加读成黑泥团）。

失败自动回退 PIL 程序化生成（径向渐变 + 噪声），保证管线不断。
"""
import base64
import json
import os
import subprocess

from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_FILE = os.path.join(ROOT, "tools", "_api_key.txt")
BASE_URL = "https://apihub.agnes-ai.cn/v1"
MODEL = "agnes-image-2.0-flash"
OUT_DIR = os.path.join(ROOT, "assets", "effects", "particle_textures")

TEXTURES = [
    ("energy_muzzle_jet", 1024,
     "single horizontal plasma energy jet streak, a bright white-hot core beam "
     "running horizontally across the center with cyan-blue electric glow and "
     "tapered pointed ends, thin crackling energy filaments hugging the core, "
     "perfectly centered vertically, spanning most of the canvas width, solid "
     "pure black background #000000, high contrast, game VFX sprite texture"),
    ("smoke_puff_light", 128,
     "single soft pale light-grey smoke puff ball, bright monochrome gunsmoke "
     "cloud, soft round shape with wispy edges, evenly lit bright grey, "
     "top-down view, perfectly centered, solid pure black background #000000, "
     "game VFX sprite texture"),
]


def load_keys():
    with open(KEY_FILE, "r", encoding="utf-8") as f:
        return [ln.strip() for ln in f if ln.strip().startswith("sk-")]


def call_api(prompt, key, size, out):
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": f"{size}x{size}", "n": 1})
    tmp, resp = out + ".payload.json", out + ".resp.json"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(payload)
    subprocess.run(
        ["curl", "--http1.1", "-s", "-X", "POST", BASE_URL + "/images/generations",
         "-H", "Authorization: Bearer " + key, "-H", "Content-Type: application/json",
         "--data-binary", "@" + tmp, "-o", resp, "--max-time", "120"],
        capture_output=True, text=True, timeout=150)
    if os.path.exists(tmp):
        os.unlink(tmp)
    if not os.path.exists(resp) or os.path.getsize(resp) < 10:
        return False
    content = open(resp, "r", encoding="utf-8", errors="replace").read()
    os.unlink(resp)
    try:
        data = json.loads(content)
    except Exception:
        return False
    if "data" not in data or not data["data"]:
        return False
    url = data["data"][0].get("url", "")
    b64 = data["data"][0].get("b64_json", "")
    if b64:
        with open(out, "wb") as f:
            f.write(base64.b64decode(b64))
        return os.path.getsize(out) > 1000
    if not url:
        return False
    subprocess.run(["curl", "--http1.1", "-s", "-L", "-o", out, url, "--max-time", "120"],
                   capture_output=True, text=True, timeout=150)
    return os.path.exists(out) and os.path.getsize(out) > 1000


def fallback_jet(path, size):
    """程序化横向能量喷流：白热核心横带 + 青色辉光 + 两端收尖。"""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    cy = size / 2
    half_len = size * 0.46
    for y in range(size):
        for x in range(size):
            dx = (x - size / 2) / half_len
            dy = (y - cy) / (size * 0.16)
            if abs(dx) > 1.0:
                continue
            taper = 1.0 - dx * dx
            core = max(0.0, 1.0 - abs(dy) / max(taper, 0.05))
            glow = max(0.0, 1.0 - abs(dy) / (max(taper, 0.05) * 2.2))
            v = core ** 1.5 * 255 + glow ** 2.0 * 140
            v = min(v, 255.0)
            if v > 8:
                r = int(min(255, v * 1.0))
                g = int(min(255, v * (0.98 if core > 0.5 else 0.92)))
                b = int(min(255, v * (0.92 if core > 0.5 else 1.0)))
                px[x, y] = (r, g, b, int(min(255, v)))
    path.save(img) if False else img.save(path)


def fallback_smoke(path, size):
    """程序化浅灰烟团：径向衰减 + 噪声揉边。"""
    import random
    random.seed(7)
    img = Image.new("L", (size, size), 0)
    px = img.load()
    cx = cy = size / 2
    for y in range(size):
        for x in range(size):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5 / (size * 0.42)
            n = random.uniform(0.72, 1.0)
            v = max(0.0, 1.0 - d) ** 1.6 * 235 * n
            px[x, y] = int(min(255, v))
    img = img.filter(ImageFilter.GaussianBlur(3))
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    opx = out.load()
    for y in range(size):
        for x in range(size):
            a = px[x, y]
            if a > 0:
                opx[x, y] = (208, 206, 202, a)
    out.save(path)


def extract_luma_alpha(src_path, out_path, tint=(255, 255, 255)):
    """黑底生成图 → 亮度即 alpha（黑底抠图通用法）。"""
    img = Image.open(src_path).convert("RGBA")
    img.thumbnail((1024, 1024), Image.LANCZOS)
    # 居中裁方
    w, h = img.size
    s = min(w, h)
    img = img.crop(((w - s) // 2, (h - s) // 2, (w + s) // 2, (h + s) // 2))
    px = img.load()
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    opx = out.load()
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            r, g, b, _a = px[x, y]
            lum = max(r, g, b)
            if lum < 14:
                continue
            opx[x, y] = (tint[0], tint[1], tint[2], min(255, int(lum * 1.05)))
    out.save(out_path)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    keys = load_keys()
    for name, size, prompt in TEXTURES:
        raw = os.path.join(OUT_DIR, name + "_raw.png")
        out = os.path.join(OUT_DIR, name + ".png")
        ok = False
        for k in keys:
            if call_api(prompt, k, size, raw):
                ok = True
                break
        if ok:
            tint = (255, 255, 255) if name == "energy_muzzle_jet" else (208, 206, 202)
            try:
                extract_luma_alpha(raw, out, tint)
                print(f"[OK] {name} <- API")
            except Exception as e:
                print(f"[FALLBACK] {name} extract fail: {e}")
                if name == "energy_muzzle_jet":
                    fallback_jet(out, 256)
                else:
                    fallback_smoke(out, 128)
        else:
            print(f"[FALLBACK] {name} <- PIL")
            if name == "energy_muzzle_jet":
                fallback_jet(out, 256)
            else:
                fallback_smoke(out, 128)
        if os.path.exists(raw):
            os.unlink(raw)
        print("  ->", out, os.path.getsize(out), "bytes")


if __name__ == "__main__":
    main()
