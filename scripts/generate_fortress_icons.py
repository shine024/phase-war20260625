"""
Generate fortress and omega card icons using agnes-image model.
Does NOT use response_format (not supported). Returns URL only.
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
    ("fort_ww1_pillbox", "WW1 concrete machine gun pillbox with sandbag fortifications, gray concrete texture, military defensive fortification, realistic military photography, isolated on white background"),
    ("fort_ww1_artillery", "WW1 artillery fortress gun emplacement with protective concrete shield, large cannon barrel, muted earth tones, realistic military photography, isolated on white background"),
    ("fort_ww2_bunker", "WW2 concrete bunker with slit trenches and barbed wire, gray concrete defensive fortification, overcast sky, realistic military photography, isolated on white background"),
    ("fort_ww2_flak", "German 88mm Flak tower, tall concrete anti-aircraft gun platform, multiple gun barrels pointing up, weathered gray concrete, realistic military photography, isolated on white background"),
    ("fort_cold_missile", "Cold War era missile silo with concrete launcher structure, missile in launch position, military gray-green tones, photorealistic, isolated on white background"),
    ("fort_cold_radar", "Cold War military radar station with large rotating radar dish and concrete base, electronic warfare equipment, military green and gray, isolated on white background"),
    ("fort_modern_citadel", "Modern military citadel fortress, heavily armored command center, angular stealth design with layered armor plating, dark military gray, photorealistic, isolated on white background"),
    ("fort_modern_phalanx", "Modern Phalanx CIWS naval gun platform with rotating Gatling barrel, modern warship mounted defense system, dark gray military finish, photorealistic, isolated on white background"),
    ("fort_future_ion", "Futuristic orbital ion cannon platform, glowing blue energy coils, sleek white-gold armored base, sci-fi military, electric blue energy glow, isolated on white background"),
    ("fort_future_shield", "Futuristic energy shield generator dome, glowing hexagonal blue force field pattern, metallic silver with blue energy glow, sci-fi military, isolated on white background"),
    ("omega_platform", "Omega-class ultimate warfare platform, massive floating warship, sleek white and gold armor plating, glowing energy cores hovering above battlefield, epic sci-fi military art, isolated on white background")
]

def generate_image(prompt, card_id, output_dir, model="agnes-image-2.0-flash"):
    data = {
        "model": model,
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
                
                # Get URL
                img_url = item.get("url") or item.get("revised_prompt")
                if img_url and "http" in str(img_url):
                    # Download image from URL
                    img_req = urllib.request.Request(img_url, headers={"User-Agent": "Mozilla/5.0"})
                    with urllib.request.urlopen(img_req, timeout=60) as img_resp:
                        img_data = img_resp.read()
                    
                    output_path = os.path.join(output_dir, f"{card_id}.png")
                    with open(output_path, "wb") as f:
                        f.write(img_data)
                    print(f"  OK: {card_id} -> {len(img_data):,} bytes")
                    return True
                
                print(f"  SKIP: no image URL")
                print(f"  keys: {list(item.keys())}")
                print(f"  item: {str(item)[:300]}")
                return False
            
            print(f"  ERROR: unexpected response")
            print(f"  Response: {str(result)[:500]}")
            return False
                
    except Exception as e:
        print(f"  ERROR: {e}")
        import traceback
        traceback.print_exc()
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
    
    existing = [f for f in os.listdir(OUTPUT_DIR) if f.endswith('.png')]
    print(f"Total PNGs: {len(existing)}")
