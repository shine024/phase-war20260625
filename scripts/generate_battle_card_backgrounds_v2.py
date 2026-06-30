"""Generate battle-ready card backgrounds for all factions using agnes-image-2.0-flash API.

Corrected prompts: purely abstract/texture backgrounds, NO scenes, NO characters, NO objects.
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
    if ":" in api_key:
        api_key = api_key.split(":")[-1].strip().strip('"').strip("'")

BASE_URL = "https://apihub.agnes-ai.com/v1"

# Faction definitions - purely abstract backgrounds
FACTIONS = {
    "iron_wall_corp": {
        "name_en": "Iron Wall Corp",
        "name_cn": "钢壁防务",
        "colors": "steel blue, gunmetal gray, silver",
        "pattern": "layered armor plate silhouettes, geometric shield shapes, tactical grid lines, reinforced concrete textures",
        "vibe": "military fortress, defensive, impenetrable",
    },
    "nova_arms": {
        "name_en": "Nova Arms",
        "name_cn": "新星兵工",
        "colors": "burnt orange, rust red, dark brown, charcoal",
        "pattern": "explosive burst radiating lines, ammunition shell shapes, ballistic trajectory curves, heat distortion waves",
        "vibe": "heavy firepower, destructive power, war industry",
    },
    "aether_dynamics": {
        "name_en": "Aether Dynamics",
        "name_cn": "以太动力",
        "colors": "deep ocean blue, teal, electric cyan, dark navy",
        "pattern": "flowing energy wave patterns, plasma field rings, propulsion thrust lines, quantum energy ripples",
        "vibe": "advanced propulsion, energy technology, aerospace",
    },
    "quantum_logistics": {
        "name_en": "Quantum Logistics",
        "name_cn": "量子后勤",
        "colors": "forest green, emerald, olive, dark moss",
        "pattern": "network node connections, supply chain flow lines, quantum entanglement curves, data stream matrices",
        "vibe": "resource management, supply networks, sustainable tech",
    },
    "helix_recon": {
        "name_en": "Helix Recon",
        "name_cn": "螺旋侦察",
        "colors": "desert sand, amber, khaki, warm bronze",
        "pattern": "radar sweep arcs, scanning beam patterns, reconnaissance lens rings, surveillance grid overlays",
        "vibe": "intelligence gathering, surveillance, aerial recon",
    },
    "void_research": {
        "name_en": "Void Research",
        "name_cn": "虚空相位",
        "colors": "deep purple, violet, magenta, dark indigo",
        "pattern": "dimensional ripple waves, phase shift distortions, quantum portal rings, void energy spirals",
        "vibe": "experimental physics, dimensional research, unknown phenomena",
    },
    "frontier_union": {
        "name_en": "Frontier Union",
        "name_cn": "边境联合",
        "colors": "bronze, copper, warm gold, weathered leather brown",
        "pattern": "alliance badge geometry, frontier map grid lines, beacon pulse rings, territorial boundary marks",
        "vibe": "coalition, frontier expansion, allied forces",
    },
    "neutral": {
        "name_en": "Neutral",
        "name_cn": "中立",
        "colors": "slate gray, cool silver, dark charcoal",
        "pattern": "subtle hexagonal tessellation, clean tactical grid, minimal geometric accents",
        "vibe": "universal, clean, minimal, adaptable",
    },
}

# Core prompt template - ABSTRACT ONLY
def build_prompt(faction_id, faction_data):
    return (
        f"Abstract card game background design, {faction_data['pattern']}, "
        f"color palette of {faction_data['colors']}, "
        f"evoking a {faction_data['vibe']} atmosphere, "
        f"5:8 portrait aspect ratio, "
        f"dense layered texture with rich detail, "
        f"center area slightly brighter for content visibility, "
        f"edges darken with dramatic vignette, "
        f"high contrast suitable for game unit placement, "
        f"no characters, no people, no creatures, no objects, "
        f"no scenes, no landscapes, no architecture, no vehicles, "
        f"no text, no watermarks, no signatures, no Chinese characters, "
        f"no ground, no floor, no shadows, "
        f"purely abstract geometric and texture design, "
        f"vector illustration meets digital painting style, "
        f"1024x1638 pixels"
    )


def generate_background(faction_id, faction_data):
    """Generate a single card background via the API."""
    prompt = build_prompt(faction_id, faction_data)
    
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
    print(f"\nGenerating {len(FACTIONS)} abstract card backgrounds...\n")
    
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
