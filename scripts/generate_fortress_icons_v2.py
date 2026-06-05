"""
Regenerate fortress and omega card icons with strict side-view profile, no ground/shadow, 512x512 composition.
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

# All prompts strictly enforce: true profile side view, no ground, no shadow, no scene, pure white background
CARDS = [
    ("fort_ww1_pillbox", 
     "Military fortress card icon art, WW1 concrete machine gun pillbox Magerly, rectangular concrete bunker with sandbag parapet, twin machine gun firing slit visible on side face, riveted steel door, weathered gray concrete texture. Strict true profile side view, orthographic, centered composition, NO ground, NO shadow, NO scene, NO pedestal, plain white background only. 512x512, no text."),
    ("fort_ww1_artillery",
     "Military fortress card icon art, WW1 artillery gun shield and concrete emplacement, large field gun barrel with curved protective shield, reinforced concrete gun pit wall on side, spent shell casings implied by wall details. Strict true profile side view, orthographic, centered composition, NO ground, NO shadow, NO scene, NO pedestal, plain white background only. 512x512, no text."),
    ("fort_ww2_bunker",
     "Military fortress card icon art, WW2 reinforced concrete MG bunker, thick concrete walls with firing embrasures, interlocking steel door, barbed wire entanglements along top parapet only, weathered gray concrete. Strict true profile side view, orthographic, centered composition, NO ground, NO shadow, NO scene, NO pedestal, plain white background only. 512x512, no text."),
    ("fort_ww2_flak",
     "Military fortress card icon art, German 88mm Flak tower artillery emplacement, tall gun mount on rotating platform base, protective concrete apron visible as structure not ground, steel armor plate around breech. Strict true profile side view, orthographic, centered composition, NO ground, NO shadow, NO scene, NO pedestal, plain white background only. 512x512, no text."),
    ("fort_cold_missile",
     "Military fortress card icon art, Cold War nuclear missile silo launch tube, tall vertical concrete silo dome, missile launcher housing with blast doors slightly open, metallic launch rails, military olive-drab painted steel. Strict true profile side view, orthographic, centered composition, NO ground, NO shadow, NO scene, NO pedestal, plain white background only. 512x512, no text."),
    ("fort_cold_radar",
     "Military fortress card icon art, Cold War military radar installation, large parabolic dish antenna on rotating concrete pedestal base, equipment shelter with antenna array, military green paint. Strict true profile side view, orthographic, centered composition, NO ground, NO shadow, NO scene, NO pedestal, plain white background only. 512x512, no text."),
    ("fort_modern_citadel",
     "Military fortress card icon art, modern armored command fortress, angular stealth design with layered composite armor panels, reinforced concrete and steel base structure, communication array on top, dark military gray. Strict true profile side view, orthographic, centered composition, NO ground, NO shadow, NO scene, NO pedestal, plain white background only. 512x512, no text."),
    ("fort_modern_phalanx",
     "Military fortress card icon art, Phalanx CIWS close-in weapon system, multi-barrel Gatling gun assembly on stabilized mount, protective armored housing, sensor dome, dark gray military finish. Strict true profile side view, orthographic, centered composition, NO ground, NO shadow, NO scene, NO pedestal, plain white background only. 512x512, no text."),
    ("fort_future_ion",
     "Military fortress card icon art, futuristic orbital ion cannon platform, sleek white-gold armored cylindrical body, glowing blue energy rings and coils, hexagonal armor plating, metallic base mount. Strict true profile side view, orthographic, centered composition, NO ground, NO shadow, NO scene, NO pedestal, plain white background only. 512x512, no text."),
    ("fort_future_shield",
     "Military fortress card icon art, futuristic energy shield generator, large dome structure with hexagonal force field pattern glowing blue, metallic silver housing, glowing energy conduits. Strict true profile side view, orthographic, centered composition, NO ground, NO shadow, NO scene, NO pedestal, plain white background only. 512x512, no text."),
    ("omega_platform",
     "Military fortress card icon art, Omega-class ultimate floating warfare platform, massive hexagonal armored hull, sleek white-gold composite plating, multiple weapon turrets on deck, glowing blue energy cores, hovering warship side profile. Strict true profile side view, orthographic, centered composition, NO ground, NO shadow, NO scene, NO pedestal, NO battlefield, plain white background only. 512x512, no text.")
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
