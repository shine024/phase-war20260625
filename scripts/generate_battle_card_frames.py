"""Generate high-quality card frame borders for all rarities using agnes-image-2.0-flash API.

Each rarity gets a distinct military/sci-fi themed frame with transparent center.
Output: assets/cards/battle_frames_review/border_<rarity>.png
"""
import os
import sys
import time
import requests

PROJECT_ROOT = r"F:\godot fair duet\create\phase-war"
OUTPUT_DIR = os.path.join(PROJECT_ROOT, "assets", "cards", "battle_frames_review")
os.makedirs(OUTPUT_DIR, exist_ok=True)

config_path = os.path.expanduser(r"C:\Users\jianchang.tan\.hermes\config.yaml")
api_key = ""
with open(config_path, "rb") as f:
    raw = f.read()
idx = raw.find(b"sk-thp")
if idx >= 0:
    end = raw.find(b"\n", idx)
    if end < 0:
        end = len(raw)
    api_key = raw[idx:end].decode().strip()
    if ":" in api_key:
        api_key = api_key.split(":")[-1].strip().strip('"').strip("'")

BASE_URL = "https://apihub.agnes-ai.com/v1"

RARITIES = {
    "common": {
        "name": "Common",
        "name_cn": "普通",
        "color_scheme": "steel gray, gunmetal, muted silver",
        "border_style": "simple straight edges, minimal geometric accents, clean tactical design",
        "glow_level": "subtle gray-blue ambient glow",
        "ornament_level": "minimal - just clean lines and subtle corner brackets",
    },
    "uncommon": {
        "name": "Uncommon",
        "name_cn": "优秀",
        "color_scheme": "dark teal, steel blue, silver accents",
        "border_style": "angled chamfered corners, reinforced corner brackets, subtle panel lines",
        "glow_level": "cool blue edge glow on corner joints",
        "ornament_level": "moderate - corner reinforcements and tactical grid accents",
    },
    "rare": {
        "name": "Rare",
        "name_cn": "稀有",
        "color_scheme": "electric blue, deep navy, bright silver",
        "border_style": "layered armor plate design, beveled edges, hexagonal mesh texture along borders",
        "glow_level": "bright blue energy glow along border seams",
        "ornament_level": "decorative - layered armor plates with energy seams and hexagonal patterns",
    },
    "epic": {
        "name": "Epic",
        "name_cn": "史诗",
        "color_scheme": "vibrant cyan, deep blue, bright silver, electric purple hints",
        "border_style": "ornate tactical armor with layered plates, intricate corner emblems, angular filigree",
        "glow_level": "strong blue-purple energy glow with pulsing corner nodes",
        "ornament_level": "highly decorative - complex layered armor with glowing nodes and tactical filigree",
    },
    "legendary": {
        "name": "Legendary",
        "name_cn": "传说",
        "color_scheme": "gold, amber, warm bronze, deep crimson accents",
        "border_style": "grand ornate armor with intricate engravings, elaborate corner crests, layered ceremonial plates",
        "glow_level": "intense golden-orange energy glow with radiant corner crowns",
        "ornament_level": "maximum ornamentation - elaborate crests, engraved patterns, radiant energy crown at corners",
    },
}

STYLE_PREFIX = (
    "A card game frame border design, 5:8 portrait aspect ratio, "
    "thick ornamental border surrounding a large transparent center area, "
    "the border is on all four sides forming a rectangular frame, "
    "center is completely transparent (alpha=0) for card content to show through, "
    "border has detailed texture and design, "
    "high contrast, game UI element, "
    "no text, no watermarks, no signatures, no Chinese characters, "
    "no characters, no creatures, no objects inside the frame, "
    "vector illustration meets digital painting, "
    "1024x1638 pixels"
)


def build_prompt(rarity_id, rarity_data):
    return (
        f"{STYLE_PREFIX}, "
        f"military sci-fi tactical armor aesthetic, "
        f"color palette of {rarity_data['color_scheme']}, "
        f"{rarity_data['border_style']}, "
        f"{rarity_data['glow_level']}, "
        f"{rarity_data['ornament_level']}, "
        f"representing {rarity_data['name_cn']} ({rarity_data['name']}) rarity tier, "
        f"no Chinese characters, no kanji"
    )


def generate_frame(rarity_id, rarity_data):
    prompt = build_prompt(rarity_id, rarity_data)
    
    payload = {
        "model": "agnes-image-2.0-flash",
        "prompt": prompt,
        "n": 1,
        "size": "1024x1638",
    }
    
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    
    try:
        resp = requests.post(
            f"{BASE_URL}/images/generations",
            headers=headers,
            json=payload,
            timeout=120,
        )
        resp.raise_for_status()
        data = resp.json()
        
        if "data" not in data or len(data["data"]) == 0:
            return False, "No data in response"
        
        item = data["data"][0]
        img_url = item.get("url")
        img_b64 = item.get("b64_json")
        
        if img_url:
            img_resp = requests.get(img_url, timeout=60)
            img_resp.raise_for_status()
            img_data = img_resp.content
        elif img_b64:
            import base64
            img_data = base64.b64decode(img_b64)
        else:
            return False, "No image data in response"
        
        out_path = os.path.join(OUTPUT_DIR, f"border_{rarity_id}.png")
        with open(out_path, "wb") as f:
            f.write(img_data)
        
        return True, out_path
        
    except Exception as e:
        return False, str(e)


def main():
    print(f"\nGenerating {len(RARITIES)} card frame borders...\n")
    
    results = []
    for rid, rd in RARITIES.items():
        print(f"[{rid}] Generating...")
        ok, result = generate_frame(rid, rd)
        if ok:
            print(f"  OK: {result}")
            results.append((rid, result, True))
        else:
            print(f"  FAIL: {result}")
            results.append((rid, result, False))
        time.sleep(3)
    
    print(f"\n{'='*60}")
    print(f"Summary: {sum(1 for _,_,ok in results if ok)}/{len(results)} succeeded")
    for rid, result, ok in results:
        status = "OK" if ok else f"FAIL: {result}"
        print(f"  {rid}: {status}")


if __name__ == "__main__":
    main()
