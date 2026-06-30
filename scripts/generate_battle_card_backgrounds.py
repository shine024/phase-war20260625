"""Generate battle-ready card backgrounds for all factions using agnes-image-2.0-flash API.

Output: assets/cards/battle_backgrounds_review/battle_bg_<faction>.png
"""
import os
import sys
import time
import requests

PROJECT_ROOT = r"F:\godot fair duet\create\phase-war"
OUTPUT_DIR = os.path.join(PROJECT_ROOT, "assets", "cards", "battle_backgrounds_review")
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Read API key from config.yaml dynamically
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
    # Remove any prefix like "api_key:" if present
    if ":" in api_key:
        api_key = api_key.split(":")[-1].strip().strip('"').strip("'")

BASE_URL = "https://apihub.agnes-ai.com/v1"

# Faction definitions with color themes and patterns
FACTIONS = {
    "iron_wall_corp": {
        "name_cn": "钢壁防务",
        "name_en": "Iron Wall Corp",
        "colors": "steel blue, gunmetal gray, silver",
        "theme": "military fortress, armored plates, reinforced concrete, defensive fortifications",
        "glow": "cool blue energy accents",
    },
    "nova_arms": {
        "name_cn": "新星兵工",
        "name_en": "Nova Arms",
        "colors": "burnt orange, rust red, dark brown",
        "theme": "heavy weaponry, ammunition crates, explosive ordnance, ballistic targets",
        "glow": "warm orange-red energy accents",
    },
    "aether_dynamics": {
        "name_cn": "以太动力",
        "name_en": "Aether Dynamics",
        "colors": "deep ocean blue, teal, electric cyan",
        "theme": "energy conduits, plasma fields, propulsion systems, power cores",
        "glow": "bright cyan-blue energy glow",
    },
    "quantum_logistics": {
        "name_cn": "量子后勤",
        "name_en": "Quantum Logistics",
        "colors": "forest green, emerald, olive",
        "theme": "supply chains, quantum entanglement nodes, logistics networks, data streams",
        "glow": "green quantum particle effects",
    },
    "helix_recon": {
        "name_cn": "螺旋侦察",
        "name_en": "Helix Recon",
        "colors": "desert sand, amber, khaki",
        "theme": "surveillance drones, radar arrays, reconnaissance equipment, scanning beams",
        "glow": "golden-yellow scanning pulses",
    },
    "void_research": {
        "name_cn": "虚空相位",
        "name_en": "Void Research",
        "colors": "deep purple, violet, magenta",
        "theme": "dimensional rifts, phase shifters, experimental physics lab, quantum portals",
        "glow": "purple void energy shimmer",
    },
    "frontier_union": {
        "name_cn": "边境联合",
        "name_en": "Frontier Union",
        "colors": "bronze, copper, warm gold",
        "theme": "frontier outpost, border patrol vehicles, communication towers, alliance symbols",
        "glow": "warm gold alliance beacon light",
    },
    "neutral": {
        "name_cn": "中立",
        "name_en": "Neutral",
        "colors": "slate gray, silver, cool white",
        "theme": "minimalist geometric pattern, subtle hexagonal grid, clean tactical design",
        "glow": "subtle white-blue ambient light",
    },
}

# Strict prefix for consistent style
STYLE_PREFIX = (
    "A professional card game background design, 5:8 portrait aspect ratio, "
    "dark atmospheric background with rich layered textures, "
    "high contrast suitable for placing game unit sprites on top, "
    "center has subtle brightness for unit visibility, "
    "edges darken with vignette effect, "
    "no text, no watermarks, no signatures, no characters, "
    "no ground, no floor, no shadows, no objects in center area, "
    "clean composition, vector illustration meets digital painting, "
    "1024x1638 pixels"
)


def generate_background(faction_id, faction_data):
    """Generate a single card background via the API."""
    prompt = (
        f"{STYLE_PREFIX}, "
        f"{faction_data['theme']}, "
        f"color palette of {faction_data['colors']}, "
        f"with {faction_data['glow']}, "
        f"representing the {faction_data['name_en']} ({faction_data['name_cn']}) faction, "
        f"intricate background details, "
        f"no Chinese characters, no kanji"
    )
    
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
        
        out_path = os.path.join(OUTPUT_DIR, f"battle_bg_{faction_id}.png")
        with open(out_path, "wb") as f:
            f.write(img_data)
        
        return True, out_path
        
    except Exception as e:
        return False, str(e)


def main():
    # Test API connection first
    print("Testing API connection...")
    test_payload = {
        "model": "agnes-image-2.0-flash",
        "prompt": "test",
        "n": 1,
        "size": "512x512",
    }
    headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
    try:
        test_resp = requests.post(
            f"{BASE_URL}/images/generations",
            headers=headers,
            json=test_payload,
            timeout=30,
        )
        if test_resp.status_code == 200:
            print("API connection OK")
        else:
            print(f"API test failed: {test_resp.status_code} - {test_resp.text[:200]}")
            return
    except Exception as e:
        print(f"API test error: {e}")
        return
    
    print(f"\nGenerating {len(FACTIONS)} card backgrounds...\n")
    
    results = []
    for fid, fd in FACTIONS.items():
        print(f"[{fid}] Generating...")
        ok, result = generate_background(fid, fd)
        if ok:
            print(f"  OK: {result}")
            results.append((fid, result, True))
        else:
            print(f"  FAIL: {result}")
            results.append((fid, result, False))
        time.sleep(3)  # Rate limit
    
    # Summary
    print(f"\n{'='*60}")
    print(f"Summary: {sum(1 for _,_,ok in results if ok)}/{len(results)} succeeded")
    for fid, result, ok in results:
        status = "OK" if ok else f"FAIL: {result}"
        print(f"  {fid}: {status}")


if __name__ == "__main__":
    main()
