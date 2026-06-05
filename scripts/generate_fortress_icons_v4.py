"""
Regenerate fortress and omega card icons - force true profile by describing ONLY side features visible.
"""
import os, json, base64, urllib.request, time

config = os.path.expanduser("~/.hermes/config.yaml")
api_key = ""
with open(config, "r") as f:
    for line in f:
        if "api_key:" in line and not line.strip().startswith("#"):
            api_key = line.strip().split("api_key:", 1)[1].strip()
            break

BASE_URL = "https://apihub.agnes-ai.com/v1/images/generations"
OUTPUT_DIR = r"F:\godot fair duet\create\phase-war\assets\card_icons"

CARDS = [
    # Each prompt describes ONLY features visible from strict side angle
    ("fort_ww1_pillbox", 
     "A WW1 concrete machine gun pillbox viewed from the EXACT side - ONLY the long rectangular side face is visible, NOT the front. One flat rectangular wall with a square machine gun firing slit, a small rectangular metal door, and stacked sandbag parapet along the top edge. Gray concrete with weathering cracks. Plain white background. Centered. No ground, no shadow, no perspective depth. Flat side elevation view."),
    ("fort_ww1_artillery",
     "A WW1 artillery gun shield emplacement viewed from the EXACT side - ONLY the side profile is visible. Long gun barrel pointing left with curved concrete gun shield, rectangular concrete base wall, side profile of the emplacement. Gray weathered concrete. Plain white background. Centered. No ground, no shadow. Flat side elevation view."),
    ("fort_ww2_bunker",
     "A WW2 concrete bunker MG position viewed from the EXACT side - ONLY one flat rectangular wall face is visible. Firing embrasures along the side wall, riveted steel door on the left edge, sandbag parapet along top. Gray concrete. Plain white background. Centered. No ground, no shadow. Strict flat side elevation."),
    ("fort_ww2_flak",
     "A German 88mm Flak tower viewed from the EXACT side - ONLY side profile visible. Long gun barrel pointing left, rotating platform base, rectangular concrete armor plate structure behind the gun. Weathered gray concrete and steel. Plain white background. Centered. No ground, no shadow. Strict flat side elevation."),
    ("fort_cold_missile",
     "A Cold War missile silo viewed from the EXACT side - ONLY side profile visible. Tall cylindrical concrete dome with vertical seam, rectangular blast door housing on the side, metallic launch rails running vertically, olive-drab painted steel surfaces. Plain white background. Centered. No ground, no shadow. Strict flat side elevation."),
    ("fort_cold_radar",
     "A Cold War military radar station viewed from the EXACT side - ONLY side profile visible. Large parabolic dish antenna seen from the edge as a thin arc, supporting tower structure, rectangular equipment shelter. Military green paint. Plain white background. Centered. No ground, no shadow. Strict flat side elevation."),
    ("fort_modern_citadel",
     "A modern armored fortress command center viewed from the EXACT side - ONLY one flat armor panel face is visible. Angular composite armor layers stacked vertically, rectangular steel door, communication antenna array on top, dark military gray composite panels. Plain white background. Centered. No ground, no shadow. Strict flat side elevation."),
    ("fort_modern_phalanx",
     "A Phalanx CIWS gun system viewed from the EXACT side - ONLY side profile visible. Multi-barrel Gatling gun assembly seen as a long cylinder, stabilized rectangular mount base, protective armored housing box, sensor dome. Dark gray military finish. Plain white background. Centered. No ground, no shadow. Strict flat side elevation."),
    ("fort_future_ion",
     "A futuristic ion cannon platform viewed from the EXACT side - ONLY side profile visible. Cylindrical white-gold armored body, circular blue energy rings visible as flat rings along the side, hexagonal armor panel pattern on the side face, glowing blue energy coils. Plain white background. Centered. No ground, no shadow. Strict flat side elevation."),
    ("fort_future_shield",
     "A futuristic energy shield generator dome viewed from the EXACT side - ONLY side profile visible. Large curved dome structure, hexagonal blue force field pattern glowing on the surface, metallic silver housing base, vertical glowing energy conduits. Plain white background. Centered. No ground, no shadow. Strict flat side elevation."),
    ("omega_platform",
     "An Omega-class floating warship viewed from the EXACT side - ONLY side profile visible. Massive hexagonal hull seen from the side with angular armor plating, white-gold composite panels, deck turrets visible as small towers on top, glowing blue energy cores embedded in hull. Plain white background. Centered. No ground, no shadow, no water, no battlefield. Strict flat side elevation.")
]

def generate_image(prompt, card_id, output_dir):
    data = {
        "model": "agnes-image-2.0-flash",
        "prompt": prompt,
        "image_size": "1024x1024",
    }
    
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }
    
    req = urllib.request.Request(BASE_URL, 
        data=json.dumps(data).encode("utf-8"), 
        headers=headers)
    
    try:
        with urllib.request.urlopen(req, timeout=300) as response:
            result = json.loads(response.read().decode("utf-8"))
            
            if "data" in result and len(result["data"]) > 0:
                item = result["data"][0]
                img_url = item.get("url")
                if img_url and "http" in str(img_url):
                    img_req = urllib.request.Request(img_url, headers={"User-Agent": "Mozilla/5.0"})
                    with urllib.request.urlopen(img_req, timeout=60) as img_resp:
                        img_data = img_resp.read()
                    
                    output_path = os.path.join(output_dir, f"{card_id}.png")
                    with open(output_path, "wb") as f:
                        f.write(img_data)
                    print(f"  OK: {card_id} -> {len(img_data):,} bytes")
                    return True
                
                print(f"  SKIP: no URL")
                return False
            else:
                print(f"  ERROR: unexpected response")
                return False
                
    except Exception as e:
        print(f"  ERROR: {e}")
        return False

if __name__ == "__main__":
    print(f"API: {BASE_URL}")
    print(f"Output: {OUTPUT_DIR}")
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    success = 0
    fail = 0
    
    for i, (card_id, prompt) in enumerate(CARDS):
        print(f"[{i+1}/{len(CARDS)}] {card_id}")
        if generate_image(prompt, card_id, OUTPUT_DIR):
            success += 1
        else:
            fail += 1
        time.sleep(3)
    
    print(f"\n=== Results ===")
    print(f"Success: {success}/{len(CARDS)}")
    print(f"Failed: {fail}/{len(CARDS)}")
