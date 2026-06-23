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
    ("enemy_ww1_infantry_basic.png", "enemy_ww1_infantry_basic", "WW1 basic infantry MP18, light armored mech infantry with short submachine gun, shoulder pads, knee guards, ammo pack, mechanical joints, low saturation army green and mud gray"),
    ("enemy_ww1_infantry_rifle.png", "enemy_ww1_infantry_rifle", "WW1 infantry with long rifle, medium armor with mechanical stock and receiver, rivets and straps, low saturation khaki gray"),
    ("enemy_ww1_mg_nest.png", "enemy_ww1_mg_nest", "WW1 fixed MG position with armored shield, ammo belt box, cooling shroud, support frame, low saturation army green gray"),
    ("enemy_ww2_infantry.png", "enemy_ww2_infantry", "WW2 basic infantry Thompson SMG, light armor with drum magazine, layered armor plates, tool bags, low saturation olive green"),
    ("enemy_ww2_rifleman.png", "enemy_ww2_rifleman", "WW2 rifleman Garand, semi-auto rifle, chest and shoulder armor with mechanical parts, low saturation army green and steel gray"),
    ("elite_ww1_storm.png", "elite_ww1_storm", "WW1 elite stormtrooper, reinforced chest armor, forearm shield, assault rifle with explosive components, low saturation iron gray"),
    ("elite_ww2_paratrooper.png", "elite_ww2_paratrooper", "WW2 elite paratrooper, lightweight armor with parachute rig, assault weapon, low saturation army green"),
    ("elite_cold_spetsnaz.png", "elite_cold_spetsnaz", "Cold War elite Spetsnaz special forces, sniper/special weapon with light high-mobility armor, low saturation dark gray"),
    ("elite_future_colossus.png", "elite_future_colossus", "Future elite Colossus heavy mech, thick torso, heavy armored limbs and main cannon, mechanical joints and hydraulics, low saturation titanium gray"),
    ("boss_ww2_kingtiger.png", "boss_ww2_kingtiger", "WW2 Boss King Tiger super-heavy tank, ultra thick front armor, long turret, heavy mechanical parts and rivets, low saturation steel gray and army green"),
    ("boss_cold_mig.png", "boss_cold_mig", "Cold War Boss MiG-29 fighter jet, fuselage, intakes, wings and ordnance strict side view, low saturation gray-blue"),
    ("boss_modern_command.png", "boss_modern_command", "Modern Boss command center platform, heavy core cabin, comm array and escort gun positions side profile, low saturation steel gray"),
    ("enemy_cold_ak.png", "enemy_cold_ak", "Cold War Soviet infantry AK rifle, modular armor, helmet and chest plate, low saturation gray-green"),
    ("enemy_cold_m60.png", "enemy_cold_m60", "Cold War US infantry M60 machine gun with ammo feed, protective vest and carrying rig, low saturation sand gray and army green"),
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
