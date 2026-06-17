"""
Generate the 3 missing WW1 cards.
"""
import os, json, urllib.request

BASE_URL = "https://apihub.agnes-ai.com/v1/images/generations"
OUTPUT_DIR = r"F:\godot fair duet\create\phase-war\assets\card_icons"

api_key = os.environ.get("SKIPPABLE_API_KEY", "")
if not api_key:
    config_path = os.path.expanduser("~/.hermes/config.yaml")
    try:
        with open(config_path, "r", encoding="utf-8") as f:
            for line in f:
                if "api_key:" in line and not line.strip().startswith("#"):
                    api_key = line.strip().split("api_key:", 1)[1].strip()
                    break
    except Exception:
        pass

CARDS = [
    ("ww1_105mm", "WW1 105mm howitzer, medium field artillery piece with large wheels and curved barrel, crew with field equipment, WW1 era artillery, realistic military illustration, isolated on white background, 1024x1024"),
    ("ww1_37mm", "WW1 37mm anti-aircraft gun, small caliber AA gun on elevated platform with ammunition crates, WW1 era early air defense weapon, realistic military illustration, isolated on white background, 1024x1024"),
    ("ww1_flame", "WW1 flame thrower operator, soldier carrying backpack flame thrower apparatus with protective gear, WW1 era assault infantry, realistic military illustration, isolated on white background, 1024x1024"),
]

for card_id, prompt in CARDS:
    data = json.dumps({"model": "agnes-image-2.0-flash", "prompt": prompt, "image_size": "1024x1024"}).encode("utf-8")
    headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
    req = urllib.request.Request(BASE_URL, data=data, headers=headers)
    with urllib.request.urlopen(req, timeout=300) as resp:
        result = json.loads(resp.read().decode("utf-8"))
    item = result["data"][0]
    img_url = item.get("url")
    img_req = urllib.request.Request(img_url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(img_req, timeout=60) as img_resp:
        img_data = img_resp.read()
    output_path = os.path.join(OUTPUT_DIR, f"{card_id}.png")
    with open(output_path, "wb") as f:
        f.write(img_data)
    print(f"OK: {card_id} ({len(img_data):,} bytes)")
