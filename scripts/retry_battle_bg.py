"""Retry script for failed card backgrounds - handles proxy issues with retries."""
import os
import sys
import time
import requests

PROJECT_ROOT = r"F:\godot fair duet\create\phase-war"
OUTPUT_DIR = os.path.join(PROJECT_ROOT, "assets", "cards", "battle_backgrounds_review")

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

# Failed factions to retry
FAILED_FACTIONS = {
    "nova_arms": {
        "colors": "burnt orange, rust red, dark brown, charcoal",
        "pattern": "explosive burst radiating lines, ammunition shell shapes, ballistic trajectory curves, heat distortion waves",
        "vibe": "heavy firepower, destructive power, war industry",
    },
    "aether_dynamics": {
        "colors": "deep ocean blue, teal, electric cyan, dark navy",
        "pattern": "flowing energy wave patterns, plasma field rings, propulsion thrust lines, quantum energy ripples",
        "vibe": "advanced propulsion, energy technology, aerospace",
    },
    "helix_recon": {
        "colors": "desert sand, amber, khaki, warm bronze",
        "pattern": "radar sweep arcs, scanning beam patterns, reconnaissance lens rings, surveillance grid overlays",
        "vibe": "intelligence gathering, surveillance, aerial recon",
    },
    "void_research": {
        "colors": "deep purple, violet, magenta, dark indigo",
        "pattern": "dimensional ripple waves, phase shift distortions, quantum portal rings, void energy spirals",
        "vibe": "experimental physics, dimensional research, unknown phenomena",
    },
    "neutral": {
        "colors": "slate gray, cool silver, dark charcoal",
        "pattern": "subtle hexagonal tessellation, clean tactical grid, minimal geometric accents",
        "vibe": "universal, clean, minimal, adaptable",
    },
}

MAX_RETRIES = 3
RETRY_DELAY = 5  # seconds

def generate_with_retry(faction_id, faction_data):
    """Try multiple times with increasing delays."""
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            prompt = (
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
            
            print(f"  Attempt {attempt}/{MAX_RETRIES}...")
            resp = requests.post(
                f"{BASE_URL}/images/generations",
                headers=headers,
                json=payload,
                timeout=120,
            )
            resp.raise_for_status()
            data = resp.json()
            
            if "data" not in data or len(data["data"]) == 0:
                raise ValueError("No data in response")
            
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
                raise ValueError("No image data")
            
            out_path = os.path.join(OUTPUT_DIR, f"battle_bg_{faction_id}.png")
            with open(out_path, "wb") as f:
                f.write(img_data)
            
            print(f"  SUCCESS: {out_path}")
            return True
            
        except Exception as e:
            print(f"  Error: {e}")
            if attempt < MAX_RETRIES:
                delay = RETRY_DELAY * attempt
                print(f"  Retrying in {delay}s...")
                time.sleep(delay)
    
    return False


def main():
    print(f"Retrying {len(FAILED_FACTIONS)} failed factions...\n")
    
    results = []
    for fid, fd in FAILED_FACTIONS.items():
        print(f"[{fid}]")
        ok = generate_with_retry(fid, fd)
        results.append((fid, ok))
        print()
    
    print(f"\n{'='*60}")
    print(f"Retry Summary: {sum(1 for _,ok in results if ok)}/{len(results)} succeeded")
    for fid, ok in results:
        print(f"  {fid}: {'OK' if ok else 'FAILED'}")


if __name__ == "__main__":
    main()
