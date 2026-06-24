#!/usr/bin/env python3
"""重试 enemy_cold_spetsnaz.png"""
import os, time, requests
from PIL import Image
from io import BytesIO

config_path = os.path.expanduser("~/.hermes/config.yaml")
with open(config_path, "rb") as f:
    raw = f.read()
idx = raw.find(b"sk-thp")
end = raw.find(b"\n", idx)
key_line = raw[idx:end].decode("utf-8", errors="replace").strip()
API_KEY = key_line.split(":")[-1].strip().strip("'\"")
BASE_URL = "https://apihub.agnes-ai.com/v1"

STRICT_PREFIX = (
    "STRICTLY a pure 2D side profile silhouette view, absolutely NO front view, "
    "NO three-quarter view, NO perspective depth, flat orthographic game sprite, "
    "single subject only centered, clean pure white background with NO ground, "
    "NO shadow, NO floor, NO reflection, NO watermark, NO signature, NO text, "
    "NO extra sketches, NO character faces visible, NO environment, "
    "studio isolated product shot style. "
)

TARGET_DIR = r"F:\godot fair duet\create\phase-war\assets\card_icons\补充1"

prompt_text = (
    "enemy_cold_spetsnaz (【冷战·精英】特种部队) "
    "sci-fi hard-surface elite Spetsnaz operator, lightweight tactical armor with integrated comms, "
    "suppressed assault rifle with modular attachments, night vision mount, compact utility harness, "
    "low-saturation deep charcoal main color, blue energy glow on NVG sensor, "
    "clean white background, no ground, no shadow, 1024x1024"
)

full_prompt = STRICT_PREFIX + prompt_text

for attempt in range(3):
    print(f"Attempt {attempt+1}...")
    payload = {"model": "agnes-image-2.0-flash", "prompt": full_prompt, "n": 1, "size": "1024x1024"}
    headers = {"Authorization": f"Bearer {API_KEY}", "Content-Type": "application/json"}
    resp = requests.post(f"{BASE_URL}/images/generations", json=payload, headers=headers, timeout=120)
    if resp.status_code != 200:
        print(f"  HTTP {resp.status_code}: {resp.text[:200]}")
        time.sleep(5)
        continue
    data = resp.json()
    item = data.get("data", [{}])[0]
    img_url = item.get("url", "")
    if img_url:
        img_resp = requests.get(img_url, timeout=120)
        if img_resp.status_code != 200:
            print(f"  Download failed: {img_resp.status_code}")
            time.sleep(3)
            continue
        img = Image.open(BytesIO(img_resp.content)).convert('RGB')
        arr = img.load()
        w, h = img.size
        bg = arr[w//2, 0]
        alpha = Image.new('L', (w, h), 255)
        al = alpha.load()
        for y in range(h):
            for x in range(w):
                r, g, b = arr[x, y]
                if max(abs(r-bg[0]), abs(g-bg[1]), abs(b-bg[2])) <= 25:
                    al[x, y] = 0
        rgba = img.convert('RGBA')
        rgba.putalpha(alpha)
        rgba = rgba.resize((512, 512), Image.LANCZOS)
        out_path = os.path.join(TARGET_DIR, "enemy_cold_spetsnaz.png")
        rgba.save(out_path, 'PNG')
        print(f"  OK: {out_path} ({os.path.getsize(out_path)} bytes)")
        break
    elif item.get("b64_json"):
        img_data = bytes.fromhex(item["b64_json"])
        img = Image.open(BytesIO(img_data)).convert('RGB')
        w, h = img.size
        arr = img.load()
        bg = arr[w//2, 0]
        alpha = Image.new('L', (w, h), 255)
        al = alpha.load()
        for y in range(h):
            for x in range(w):
                r, g, b = arr[x, y]
                if max(abs(r-bg[0]), abs(g-bg[1]), abs(b-bg[2])) <= 25:
                    al[x, y] = 0
        rgba = img.convert('RGBA')
        rgba.putalpha(alpha)
        rgba = rgba.resize((512, 512), Image.LANCZOS)
        out_path = os.path.join(TARGET_DIR, "enemy_cold_spetsnaz.png")
        rgba.save(out_path, 'PNG')
        print(f"  OK (b64): {out_path}")
        break
    else:
        print(f"  No URL/b64: {str(data)[:200]}")
        time.sleep(3)
