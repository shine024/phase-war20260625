"""Retry script for failed card frame borders."""
import os, time, base64, requests

PROJECT_ROOT = r"F:\godot fair duet\create\phase-war"
OUTPUT_DIR = os.path.join(PROJECT_ROOT, "assets", "cards", "battle_frames_review")

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

FAILED = {
    "common": {
        "color_scheme": "steel gray, gunmetal, muted silver",
        "border_style": "simple straight edges, minimal geometric accents, clean tactical design",
        "glow_level": "subtle gray-blue ambient glow",
        "ornament_level": "minimal - just clean lines and subtle corner brackets",
        "name_cn": "普通", "name": "Common",
    },
    "rare": {
        "color_scheme": "electric blue, deep navy, bright silver",
        "border_style": "layered armor plate design, beveled edges, hexagonal mesh texture along borders",
        "glow_level": "bright blue energy glow along border seams",
        "ornament_level": "decorative - layered armor plates with energy seams and hexagonal patterns",
        "name_cn": "稀有", "name": "Rare",
    },
    "epic": {
        "color_scheme": "vibrant cyan, deep blue, bright silver, electric purple hints",
        "border_style": "ornate tactical armor with layered plates, intricate corner emblems, angular filigree",
        "glow_level": "strong blue-purple energy glow with pulsing corner nodes",
        "ornament_level": "highly decorative - complex layered armor with glowing nodes and tactical filigree",
        "name_cn": "史诗", "name": "Epic",
    },
    "legendary": {
        "color_scheme": "gold, amber, warm bronze, deep crimson accents",
        "border_style": "grand ornate armor with intricate engravings, elaborate corner crests, layered ceremonial plates",
        "glow_level": "intense golden-orange energy glow with radiant corner crowns",
        "ornament_level": "maximum ornamentation - elaborate crests, engraved patterns, radiant energy crown at corners",
        "name_cn": "传说", "name": "Legendary",
    },
}

MAX_RETRIES = 3

def generate_with_retry(rarity_id, rd):
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            prompt = (
                f"A card game frame border design, 5:8 portrait aspect ratio, "
                f"thick ornamental border surrounding a large transparent center area, "
                f"the border is on all four sides forming a rectangular frame, "
                f"center is completely transparent (alpha=0) for card content to show through, "
                f"border has detailed texture and design, "
                f"high contrast, game UI element, "
                f"no text, no watermarks, no signatures, no Chinese characters, "
                f"no characters, no creatures, no objects inside the frame, "
                f"vector illustration meets digital painting, "
                f"1024x1638 pixels, "
                f"military sci-fi tactical armor aesthetic, "
                f"color palette of {rd['color_scheme']}, "
                f"{rd['border_style']}, "
                f"{rd['glow_level']}, "
                f"{rd['ornament_level']}, "
                f"representing {rd['name_cn']} ({rd['name']}) rarity tier, "
                f"no Chinese characters, no kanji"
            )
            
            payload = {"model": "agnes-image-2.0-flash", "prompt": prompt, "n": 1, "size": "1024x1638"}
            headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
            
            print(f"  Attempt {attempt}/{MAX_RETRIES}...")
            resp = requests.post(f"{BASE_URL}/images/generations", headers=headers, json=payload, timeout=120)
            resp.raise_for_status()
            data = resp.json()
            
            if "data" not in data or len(data["data"]) == 0:
                raise ValueError("No data")
            
            item = data["data"][0]
            img_url = item.get("url")
            img_b64 = item.get("b64_json")
            
            if img_url:
                img_resp = requests.get(img_url, timeout=60)
                img_resp.raise_for_status()
                img_data = img_resp.content
            elif img_b64:
                img_data = base64.b64decode(img_b64)
            else:
                raise ValueError("No image data")
            
            out_path = os.path.join(OUTPUT_DIR, f"border_{rarity_id}.png")
            with open(out_path, "wb") as f:
                f.write(img_data)
            print(f"  SUCCESS: {out_path}")
            return True
            
        except Exception as e:
            print(f"  Error: {e}")
            if attempt < MAX_RETRIES:
                time.sleep(5 * attempt)
    return False


def main():
    print(f"Retrying {len(FAILED)} failed frame borders...\n")
    results = []
    for rid, rd in FAILED.items():
        print(f"[{rid}]")
        ok = generate_with_retry(rid, rd)
        results.append((rid, ok))
        print()
    
    print(f"\n{'='*60}")
    print(f"Retry Summary: {sum(1 for _,ok in results if ok)}/{len(results)} succeeded")
    for rid, ok in results:
        print(f"  {rid}: {'OK' if ok else 'FAILED'}")


if __name__ == "__main__":
    main()
