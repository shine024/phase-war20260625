"""Regenerate specific card frame borders in the unified minimal tech style (iteration entry point).

Shares the SAME design language as generate_battle_card_frames.py — deep metal base +
thin energy line border + angular corner brackets. Color + glow differ by rarity only.
Edit REGEN below to list which rarities to re-run.
"""
import os, time, base64, requests

PROJECT_ROOT = r"F:\godot fair duet\create\phase-war"
OUTPUT_DIR = os.path.join(PROJECT_ROOT, "assets", "cards", "frames")

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

# Re-run list: edit to pick which rarities to regenerate (defaults to all 6 for a full refresh).
REGEN = {
    "common": {
        "accent_color": "gunmetal gray #6b7691",
        "glow_level": "no glow, flat matte finish",
        "name_cn": "普通", "name": "Common",
    },
    "uncommon": {
        "accent_color": "steel green #22c55e",
        "glow_level": "faint green edge glow, very subtle",
        "name_cn": "优秀", "name": "Uncommon",
    },
    "rare": {
        "accent_color": "electric blue #38bdf8",
        "glow_level": "medium blue edge glow along border lines",
        "name_cn": "稀有", "name": "Rare",
    },
    "epic": {
        "accent_color": "violet #c084fc",
        "glow_level": "strong violet glow at corner nodes and border seams",
        "name_cn": "史诗", "name": "Epic",
    },
    "legendary": {
        "accent_color": "amber #f59e0b",
        "glow_level": "intense amber glow with pulsing energy at corners",
        "name_cn": "传说", "name": "Legendary",
    },
    "mythic": {
        "accent_color": "red #ef4444",
        "glow_level": "maximum red glow with full-border pulsing energy veins",
        "name_cn": "神话", "name": "Mythic",
    },
}

MAX_RETRIES = 3

# Strict negative prompt to prevent characters/armor/ornament in center + fantasy elements.
NEGATIVE = ("character, person, human, humanoid, armor suit, robot, creature, monster, face, mask, "
            "figure, statue, object, item, weapon, vehicle, landscape, scene, background, scenery, "
            "environment, gold, bronze, ornate, engraved, crest, filigree, flourish, ceremonial, "
            "medieval, fantasy, rune, text, watermark, signature, chinese, kanji, japanese, korean, "
            "letter, word, phrase, sentence")

def generate_with_retry(rarity_id, rd):
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            prompt = (
                f"ABSTRACT CARD FRAME BORDER ONLY, no content inside the frame, "
                f"5:8 portrait aspect ratio, "
                f"a thin uniform-width border on all four sides forming a clean rectangular frame, "
                f"minimal sci-fi tech aesthetic, flat dark metal base, "
                f"simple angular corner brackets at the four corners, "
                f"thin circuit-trace lines along the border, geometric not ornamental, "
                f"center area is completely empty and transparent for card content, "
                f"NO gold, NO bronze, NO engravings, NO crests, NO filigree, NO ornamental flourishes, "
                f"flat vector graphic style, clean, modern, game UI element, "
                f"NO characters, NO people, NO creatures, NO objects inside the frame, "
                f"accent color: {rd['accent_color']}, "
                f"glow: {rd['glow_level']}, "
                f"this frame represents {rd['name_cn']} ({rd['name']}) rarity tier — "
                f"keep the SAME simple geometric structure as other tiers, only the color and glow differ, "
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
            
            out_path = os.path.join(OUTPUT_DIR, f"{rarity_id}.png")
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
