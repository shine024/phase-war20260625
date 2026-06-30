"""Regenerate problematic card frame borders (epic + legendary) with stricter prompts."""
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

REGEN = {
    "epic": {
        "color_scheme": "vibrant cyan, deep blue, bright silver, electric purple accents",
        "border_style": "complex layered tactical armor plates with angular geometric filigree, reinforced corner emblems, hexagonal circuit patterns",
        "glow_level": "intense blue-purple energy glow at corner nodes and border seams",
        "ornament_level": "highly ornate layered armor with glowing tactical nodes",
        "name_cn": "史诗", "name": "Epic",
    },
    "legendary": {
        "color_scheme": "warm gold, amber, bronze, deep crimson red accents",
        "border_style": "ceremonial tactical armor with intricate engraved patterns, elaborate corner crests, layered golden armor plates with red energy veins",
        "glow_level": "radiant golden-orange energy glow with crimson pulse lines",
        "ornament_level": "maximum ornamentation - elaborate golden crests, engraved tactical patterns, radiant energy veins",
        "name_cn": "传说", "name": "Legendary",
    },
}

MAX_RETRIES = 3

# Strict negative prompt to prevent characters/armor in center
NEGATIVE = "character, person, human, humanoid, armor suit, robot, creature, monster, face, mask, figure, statue, object, item, weapon, vehicle, landscape, scene, background, scenery, environment, text, watermark, signature, chinese, kanji, japanese, korean, letter, word, phrase, sentence"

def generate_with_retry(rarity_id, rd):
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            prompt = (
                f"ABSTRACT CARD FRAME BORDER ONLY, no content inside the frame, "
                f"5:8 portrait aspect ratio, "
                f"a thick ornamental border on all four sides forming a rectangular frame, "
                f"center area is completely empty and transparent for card content, "
                f"NO characters, NO people, NO creatures, NO objects inside the frame, "
                f"NO armor suits, NO statues, NO figures, NO items, NO scenes, "
                f"the border design is {rd['border_style']}, "
                f"color palette of {rd['color_scheme']}, "
                f"{rd['glow_level']}, "
                f"{rd['ornament_level']}, "
                f"representing {rd['name_cn']} ({rd['name']}) rarity tier, "
                f"military sci-fi tactical aesthetic, "
                f"only decorative border elements on the edges, center is completely empty, "
                f"vector illustration meets digital painting, "
                f"1024x1638 pixels"
            )
            
            payload = {
                "model": "agnes-image-2.0-flash",
                "prompt": prompt,
                "negative_prompt": NEGATIVE,
                "n": 1,
                "size": "1024x1638",
            }
            
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
    print(f"Regenerating {len(REGEN)} problematic frame borders...\n")
    results = []
    for rid, rd in REGEN.items():
        print(f"[{rid}]")
        ok = generate_with_retry(rid, rd)
        results.append((rid, ok))
        print()
    
    print(f"\n{'='*60}")
    print(f"Regen Summary: {sum(1 for _,ok in results if ok)}/{len(results)} succeeded")
    for rid, ok in results:
        print(f"  {rid}: {'OK' if ok else 'FAILED'}")


if __name__ == "__main__":
    main()
