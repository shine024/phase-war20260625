#!/usr/bin/env python3
"""重试4张不严格侧视的图"""
import os, time, requests
from PIL import Image
from io import BytesIO

config_path = os.path.expanduser("~/.hermes/config.yaml")
with open(config_path, "rb") as f:
    raw = f.read()
idx = raw.find(b"sk-thp")
end = raw.find(b"\n", idx)
key_line = raw[idx:end].decode("utf-8", errors="replace").strip()
API_KEY=key_line.split(":")[-1].strip().strip("'\"")
BASE_URL = "https://apihub.agnes-ai.com/v1"

STRICT_PREFIX = (
    "STRICTLY a pure 2D side profile silhouette view, absolutely NO front view, "
    "NO three-quarter view, NO perspective depth, flat orthographic game sprite, "
    "single subject only centered, clean pure white background with NO ground, "
    "NO shadow, NO floor, NO reflection, NO watermark, NO signature, NO text, "
    "NO extra sketches, NO character faces visible, NO environment, "
    "studio isolated product shot style. "
    "The figure MUST be seen from a PERFECT side angle - only one eye visible, "
    "only one ear visible, body completely flat profile, arms and legs aligned in side view."
)

TARGET_DIR = r"F:\godot fair duet\create\phase-war\assets\card_icons\补充1"

PROMPTS = {
    "enemy_cold_rpg.png": (
        "enemy_cold_rpg (Cold War RPG-7 anti-tank infantry soldier) "
        "complete soldier figure in PERFECT strict side profile, wearing moderate body armor with helmet, "
        "holding RPG-7 anti-tank rocket launcher on shoulder with optical sight arm, "
        "rocket rounds on back rack, reinforced boot soles, full body visible from head to toe, "
        "low-saturation sand gray main color, blue energy glow on rocket fuse, "
        "weathered metal texture, 1024x1024"
    ),
    "enemy_cold_sam7.png": (
        "enemy_cold_sam7 (Cold War SA-7 surface-to-air missile infantry soldier) "
        "complete soldier figure in PERFECT strict side profile, wearing woodland combat uniform with tactical vest, "
        "holding SA-7 surface-to-air missile launcher on shoulder with tracking dish array, "
        "missile pod on back, radar warning receiver on chest, full body visible from head to toe, "
        "low-saturation woodland green main color, blue energy glow on tracking dish, "
        "weathered metal texture, 1024x1024"
    ),
    "enemy_future_spectre.png": (
        "enemy_future_spectre (Future cloaked special ops operative soldier) "
        "complete soldier figure in PERFECT strict side profile, wearing adaptive camouflage armor with light-bending paneling, "
        "holding compact plasma rifle with phase-shifting barrel, "
        "holographic sight overlay on helmet, compact utility harness, full body visible from head to toe, "
        "low-saturation deep gunmetal main color, blue energy glow on cloak nodes, "
        "weathered metal texture, 1024x1024"
    ),
    "enemy_ww2_bazooka.png": (
        "enemy_ww2_bazooka (WW2 bazooka anti-tank infantry soldier) "
        "complete soldier figure in PERFECT strict side profile, wearing light combat uniform with helmet, "
        "holding bazooka anti-tank rocket launcher on shoulder with mechanical aiming bracket, "
        "light combat vest, rocket pods on back, reinforced arm guard, full body visible from head to toe, "
        "low-saturation olive green main color, blue energy glow on rocket warhead, "
        "weathered metal texture, 1024x1024"
    ),
}


def auto_post_process(img_bytes):
    img = Image.open(BytesIO(img_bytes)).convert('RGB')
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
    return rgba


def generate_single(prompt_text, output_name):
    full_prompt = STRICT_PREFIX + prompt_text
    payload = {"model": "agnes-image-2.0-flash", "prompt": full_prompt, "n": 1, "size": "1024x1024"}
    headers = {"Authorization": f"Bearer {API_KEY}", "Content-Type": "application/json"}
    
    for attempt in range(3):
        try:
            resp = requests.post(f"{BASE_URL}/images/generations", json=payload, headers=headers, timeout=120)
            if resp.status_code != 200:
                time.sleep(5)
                continue
            data = resp.json()
            item = data.get("data", [{}])[0]
            img_url = item.get("url", "")
            if img_url:
                img_resp = requests.get(img_url, timeout=120)
                if img_resp.status_code != 200:
                    time.sleep(3)
                    continue
                rgba = auto_post_process(img_resp.content)
                out_path = os.path.join(TARGET_DIR, output_name)
                rgba.save(out_path, 'PNG')
                return True, os.path.getsize(out_path)
            elif item.get("b64_json"):
                img_data = bytes.fromhex(item["b64_json"])
                rgba = auto_post_process(img_data)
                out_path = os.path.join(TARGET_DIR, output_name)
                rgba.save(out_path, 'PNG')
                return True, os.path.getsize(out_path)
        except Exception as e:
            time.sleep(5)
    return False, 0


def main():
    ok = fail = 0
    failed = []
    names = list(PROMPTS.keys())
    for i, name in enumerate(names, 1):
        print(f"[{i}/{len(names)}] 生成 {name}...")
        s, sz = generate_single(PROMPTS[name], name)
        if s:
            print(f"  OK ({sz} bytes)")
            ok += 1
        else:
            print(f"  FAIL")
            fail += 1
            failed.append(name)
        time.sleep(3)
    print(f"\n完成: 成功={ok}, 失败={fail}")
    if failed:
        print(f"失败: {', '.join(failed)}")


if __name__ == '__main__':
    main()
