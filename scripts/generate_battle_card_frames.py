"""Generate clean tech-style card frame borders for all rarities (agnes-image-2.0-flash).

Design language (v7.x 界面一致性修复): UNIFIED minimal sci-fi across all rarities —
deep metal base + thin energy line border + angular corner brackets.
Rarity is encoded ONLY by accent color + glow intensity, NEVER by ornament/engraving level
(previous "gold/ornate/ceremonial" prompts produced fantasy-RPG frames that clashed with
the dark tech UI — see docs/界面一致性/visual_audit_report.html P0).
Output: assets/cards/frames/<rarity>.png  (overwrites runtime path directly)
"""
import os
import sys
import time
import requests

PROJECT_ROOT = r"F:\godot fair duet\create\phase-war"
OUTPUT_DIR = os.path.join(PROJECT_ROOT, "assets", "cards", "frames")
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
        "accent_color": "gunmetal gray #6b7691",
        "glow_level": "no glow, flat matte finish",
    },
    "uncommon": {
        "name": "Uncommon",
        "name_cn": "优秀",
        "accent_color": "steel green #22c55e",
        "glow_level": "faint green edge glow, very subtle",
    },
    "rare": {
        "name": "Rare",
        "name_cn": "稀有",
        "accent_color": "electric blue #38bdf8",
        "glow_level": "medium blue edge glow along border lines",
    },
    "epic": {
        "name": "Epic",
        "name_cn": "史诗",
        "accent_color": "violet #c084fc",
        "glow_level": "strong violet glow at corner nodes and border seams",
    },
    "legendary": {
        "name": "Legendary",
        "name_cn": "传说",
        "accent_color": "amber #f59e0b",
        "glow_level": "intense amber glow with pulsing energy at corners",
    },
    "mythic": {
        "name": "Mythic",
        "name_cn": "神话",
        "accent_color": "red #ef4444",
        "glow_level": "maximum red glow with full-border pulsing energy veins",
    },
}

# Unified design language: ALL rarities share the same minimal sci-fi frame structure.
# Only the accent color and glow intensity differ. NO gold, NO ornate engravings, NO crests,
# NO ceremonial elements — those produced the fantasy-RPG clash reported in visual_audit.
STYLE_PREFIX = (
    "ABSTRACT CARD FRAME BORDER ONLY, no content inside the frame, "
    "5:8 portrait aspect ratio, "
    "a thin uniform-width border on all four sides forming a clean rectangular frame, "
    "minimal sci-fi tech aesthetic, flat dark metal base, "
    "simple angular corner brackets at the four corners, "
    "thin circuit-trace lines along the border, geometric not ornamental, "
    "center area is completely empty and transparent for card content, "
    "flat vector graphic style, clean, modern, game UI element, "
    "NO gold, NO bronze, NO engravings, NO crests, NO filigree, NO ornamental flourishes, "
    "NO characters, NO people, NO creatures, NO objects inside the frame, "
    "no text, no watermarks, no signatures, no Chinese characters, no kanji, "
    "1024x1638 pixels"
)

# Strict negative prompt to prevent characters/armor/ornament in center (from regenerate_bad_frames).
NEGATIVE = ("character, person, human, humanoid, armor suit, robot, creature, monster, face, mask, "
            "figure, statue, object, item, weapon, vehicle, landscape, scene, background, scenery, "
            "environment, gold, bronze, ornate, engraved, crest, filigree, flourish, ceremonial, "
            "medieval, fantasy, rune, text, watermark, signature, chinese, kanji, japanese, korean, "
            "letter, word, phrase, sentence")


def build_prompt(rarity_id, rarity_data):
    return (
        f"{STYLE_PREFIX}, "
        f"accent color: {rarity_data['accent_color']}, "
        f"glow: {rarity_data['glow_level']}, "
        f"this frame represents {rarity_data['name_cn']} ({rarity_data['name']}) rarity tier — "
        f"keep the SAME simple geometric structure as other tiers, only the color and glow differ"
    )


def generate_frame(rarity_id, rarity_data):
    prompt = build_prompt(rarity_id, rarity_data)

    payload = {
        "model": "agnes-image-2.0-flash",
        "prompt": prompt,
        "negative_prompt": NEGATIVE,
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
        
        out_path = os.path.join(OUTPUT_DIR, f"{rarity_id}.png")
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
