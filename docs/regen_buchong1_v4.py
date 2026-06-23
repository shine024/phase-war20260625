import requests, json, os, time

with open(os.path.expanduser("~/.hermes/config.yaml"), "r") as f:
    for line in f:
        if "sk-thp" in line:
            key = line.strip().split('"')[1] if '"' in line else line.strip().split(":")[-1].strip().strip('"')
            break

BASE_URL = "https://apihub.agnes-ai.com/v1"
output_dir = r"F:\godot fair duet\create\phase-war\assets\card_icons\补充1"
os.makedirs(output_dir, exist_ok=True)

NEGATIVE = """Strict 2D true profile side view, orthographic projection, game unit sprite pose, sci-fi hard-surface mechanical concept art, subject centered in frame, complete unit fully visible in side profile, detailed mechanical parts, armor plating, weapons, weathered and worn metal texture, low saturation color scheme with blue energy glow accents, clean studio pure white background, no ground, no scene, no props, no shadows, no platform, no text, no watermark, no logo, no characters, high resolution."""

TASKS = [
    ("enemy_ww1_mg_nest.png", "enemy_ww1_mg_nest", "WW1 fixed MG position with armored shield, ammo belt box, cooling shroud, support frame, low saturation army green gray"),
    ("enemy_ww2_infantry.png", "enemy_ww2_infantry", "WW2 basic infantry Thompson SMG, light armor with drum magazine, layered armor plates, tool bags, low saturation olive green"),
    ("enemy_ww2_rifleman.png", "enemy_ww2_rifleman", "WW2 rifleman Garand, semi-auto rifle, chest and shoulder armor with mechanical parts, low saturation army green and steel gray"),
    ("elite_ww1_storm.png", "elite_ww1_storm", "WW1 elite stormtrooper, reinforced chest armor, forearm shield, assault rifle with explosive components, low saturation iron gray"),
    ("elite_ww2_paratrooper.png", "elite_ww2_paratrooper", "WW2 elite paratrooper, lightweight armor with parachute rig, assault weapon, low saturation army green"),
    ("enemy_cold_ak.png", "enemy_cold_ak", "Cold War Soviet infantry AK rifle, modular armor, helmet and chest plate, low saturation gray-green"),
    ("enemy_future_hovertank.png", "enemy_future_hovertank", "Future hover tank, suspension chassis, turret and thruster array side profile, anti-gravity energy glow, low saturation cold gray"),
    ("boss_modern_command.png", "boss_modern_command", "Modern Boss command center platform, heavy core cabin, comm array and escort gun positions side profile, low saturation steel gray"),
    ("fort_ww1_pillbox.png", "fort_ww1_pillbox", "WW1 pillbox bunker, thick concrete walls, machine gun emplacements, observation slits, reinforced entrance, low saturation gray-green"),
    ("fort_ww2_bunker.png", "fort_ww2_bunker", "WW2 coastal bunker, reinforced concrete, artillery observation post, anti-air platform, low saturation steel gray"),
]

generated = []
failed = []

for i, (fname, eid, desc) in enumerate(TASKS):
    prompt = f"{eid} - {desc}. {NEGATIVE}"
    payload = {"model": "agnes-image-2.0-flash", "prompt": prompt, "image_size": "1024x1024"}
    headers = {"Authorization": f"Bearer {key}", "Content-Type": "application/json"}
    filepath = os.path.join(output_dir, fname)

    try:
        resp = requests.post(f"{BASE_URL}/images/generations", json=payload, headers=headers, timeout=120)
        data = resp.json()
        if resp.status_code == 200 and data.get("data") and data["data"][0].get("url"):
            img_resp = requests.get(data["data"][0]["url"])
            with open(filepath, "wb") as f:
                f.write(img_resp.content)
            generated.append(fname)
            print(f"[{i+1}/{len(TASKS)}] OK {fname} ({len(img_resp.content)} bytes)")
        else:
            failed.append((fname, str(data)[:200]))
            print(f"[{i+1}/{len(TASKS)}] FAIL {fname}: {str(data)[:200]}")
        time.sleep(3)
    except Exception as e:
        failed.append((fname, str(e)))
        print(f"[{i+1}/{len(TASKS)}] FAIL {fname}: {e}")
        time.sleep(3)

print(f"\n补充1: Generated {len(generated)}, Failed {len(failed)}")
