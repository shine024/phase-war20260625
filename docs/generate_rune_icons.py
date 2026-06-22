import requests, json, os, time

API_KEY = "***"
BASE_URL = "https://apihub.agnes-ai.com/v1"

output_dir = r"F:\godot fair duet\create\phase-war\docs\rune_design_comparison"
os.makedirs(output_dir, exist_ok=True)

RUNES = [
    {"id": "attack_01", "name": "力量", "category": "attack", "color": "crimson red", "color_hex": "#ff2244",
     "shape_desc": "a bold triangle pointing upward with a vertical line cutting through the center"},
    {"id": "defense_04", "name": "磐石", "category": "defense", "color": "cyan blue", "color_hex": "#4488ff",
     "shape_desc": "a shield outline with a thick diamond cross inside"},
    {"id": "energy_05", "name": "超载", "category": "energy", "color": "electric yellow", "color_hex": "#ffdd44",
     "shape_desc": "a zigzag lightning bolt with small circles at each vertex"},
]

RARITIES = [
    {"name": "common", "glow": "subtle", "bg": "dark charcoal #1a1a1a"},
    {"name": "rare", "glow": "medium", "bg": "dark navy #0d1b2a"},
    {"name": "epic", "glow": "strong", "bg": "dark purple #1a0a2e"},
    {"name": "legendary", "glow": "very strong", "bg": "dark gold #1a1500"},
]

PLAN1_PREFIX = "Plan1_Minimalist_Geometric_Rune,"

def generate_prompt(rune, rarity, plan_prefix):
    return f"""{plan_prefix}
A single RPG rune icon for "{rune['name']}" ({rune['id']}), 
{rune['shape_desc']},
monochromatic {rune['color']} color scheme ({rune['color_hex']}), 
dark circular background ({rarity['bg']}), 
{rarity['glow']} neon glow on edges, 
minimalist geometric style, 2-4 clean shapes only, 
flat vector style, transparent background, 
high contrast, sharp edges, no gradients, no textures, no 3D effects, 
no ornamental details, no borders, no frames, no watermarks, no text,
centered composition, 1024x1024px square canvas"""

generated = []
failed = []

for rune in RUNES:
    for rarity in RARITIES:
        filename = f"plan1_{rune['id']}_{rarity['name']}.png"
        filepath = os.path.join(output_dir, filename)
        
        prompt = generate_prompt(rune, rarity, PLAN1_PREFIX)
        
        payload = {
            "model": "agnes-image-2.0-flash",
            "prompt": prompt,
            "image_size": "1024x1024"
        }
        
        headers = {
            "Authorization": f"Bearer {API_KEY}",
            "Content-Type": "application/json"
        }
        
        try:
            resp = requests.post(f"{BASE_URL}/images/generations", json=payload, headers=headers, timeout=120)
            data = resp.json()
            
            if resp.status_code == 200 and data.get("data") and data["data"][0].get("url"):
                img_url = data["data"][0]["url"]
                img_resp = requests.get(img_url)
                with open(filepath, "wb") as f:
                    f.write(img_resp.content)
                generated.append(filename)
                print(f"OK {filename} ({len(img_resp.content)} bytes)")
            else:
                failed.append((filename, str(data)[:200]))
                print(f"FAIL {filename}: {str(data)[:200]}")
            
            time.sleep(3)
        except Exception as e:
            failed.append((filename, str(e)))
            print(f"FAIL {filename}: {e}")
            time.sleep(3)

print(f"\n=== Summary ===")
print(f"Generated: {len(generated)}/{len(generated)+len(failed)}")
if failed:
    print(f"Failed: {len(failed)}")
    for fn, err in failed:
        print(f"  {fn}: {err[:100]}")
