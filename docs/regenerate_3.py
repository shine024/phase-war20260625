import requests, json, os

with open(os.path.expanduser("~/.hermes/config.yaml"), "r") as f:
    for line in f:
        if "sk-thp" in line:
            key = line.strip().split('"')[1] if '"' in line else line.strip().split(":")[-1].strip().strip('"')
            break

BASE_URL = "https://apihub.agnes-ai.com/v1"
output_dir = r"F:\godot fair duet\create\phase-war\docs\rune_legendary_celtic"

TASKS = [
    ("celtic_attack_08.png", """Plan2_Celtic_Knot_Rune,
A single RPG rune icon for attack_08,
a dagger blade intersecting a target crosshair,
monochromatic crimson red color scheme (#ff2244),
intricate Celtic knot style with braided line patterns,
circular symmetrical design, single continuous intertwining line forming the rune shape,
ancient stone carving texture on the lines,
dark weathered circular background (#0d1b2a),
metallic crimson red line color with very strong glow,
strong contrast, vector illustration style,
no borders, no frames, no watermarks, no text, no Chinese characters, no kanji,
centered composition, 1024x1024px square canvas"""),
    ("celtic_attack_03.png", """Plan2_Celtic_Knot_Rune,
A single RPG rune icon for attack_03,
three curved wind streaks spiraling clockwise,
monochromatic crimson red color scheme (#ff2244),
intricate Celtic knot style with braided line patterns,
circular symmetrical design, single continuous intertwining line forming the rune shape,
ancient stone carving texture on the lines,
dark weathered circular background (#0d1b2a),
metallic crimson red line color with very strong glow,
strong contrast, vector illustration style,
no borders, no frames, no watermarks, no text, no Chinese characters, no kanji,
centered composition, 1024x1024px square canvas"""),
    ("celtic_mobility_03.png", """Plan2_Celtic_Knot_Rune,
A single RPG rune icon for mobility_03,
footprints forming a zigzag path,
monochromatic green color scheme (#44ff88),
intricate Celtic knot style with braided line patterns,
circular symmetrical design, single continuous intertwining line forming the rune shape,
ancient stone carving texture on the lines,
dark weathered circular background (#0d1b2a),
metallic green line color with very strong glow,
strong contrast, vector illustration style,
no borders, no frames, no watermarks, no text, no Chinese characters, no kanji,
centered composition, 1024x1024px square canvas"""),
]

for fname, prompt in TASKS:
    payload = {"model": "agnes-image-2.0-flash", "prompt": prompt, "image_size": "1024x1024"}
    headers = {"Authorization": f"Bearer {key}", "Content-Type": "application/json"}
    filepath = os.path.join(output_dir, fname)
    
    resp = requests.post(f"{BASE_URL}/images/generations", json=payload, headers=headers, timeout=120)
    data = resp.json()
    
    if resp.status_code == 200 and data.get("data") and data["data"][0].get("url"):
        img_resp = requests.get(data["data"][0]["url"])
        with open(filepath, "wb") as f:
            f.write(img_resp.content)
        print(f"OK {fname} ({len(img_resp.content)} bytes)")
    else:
        print(f"FAIL {fname}: {str(data)[:300]}")
