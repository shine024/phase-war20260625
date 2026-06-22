import requests, json, os, time

API_KEY = os.environ.get("AGNES_API_KEY", "")
if not API_KEY:
    raise SystemExit("AGNES_API_KEY 环境变量未设置。请先 `set AGNES_API_KEY=<your_key>` 再运行。")
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

PLANS = [
    ("plan1", "Plan1_Minimalist_Geometric_Rune,",
     """A single RPG rune icon, minimalist geometric style.
A bold triangle pointing upward with a vertical line cutting through the center.
Monochromatic crimson red color scheme (#ff2244).
Dark circular background (#1a1a1a).
Subtle neon glow on edges.
Minimalist geometric style, 2-4 clean shapes only, flat vector style.
Transparent background, high contrast, sharp edges.
No gradients, no textures, no 3D effects.
No ornamental details, no borders, no frames, no watermarks, no text.
Centered composition, 1024x1024px square canvas."""),

    ("plan2", "Plan2_Celtic_Knot_Rune,",
     """A single RPG rune icon, Celtic knot style.
A bold triangle pointing upward with a vertical line cutting through the center, formed by intricate braided line patterns.
Monochromatic crimson red color scheme (#ff2244).
Circular symmetrical design, single continuous intertwining line.
Ancient stone carving texture on the lines.
Dark weathered circular background (#1a1a1a).
Metallic crimson red line color with subtle glow.
Strong contrast, vector illustration style.
No borders, no frames, no watermarks, no text.
Centered composition, 1024x1024px square canvas."""),

    ("plan3", "Plan3_Magic_Seal_Rune,",
     """A single RPG rune icon, magic seal style.
A bold triangle pointing upward with a vertical line cutting through the center as the central core symbol.
Monochromatic crimson red color scheme (#ff2244).
Concentric circular bands with wedge-shaped notches, dot markers, short dash lines on rings.
Stone or metal texture on the rings.
Dark circular background (#1a1a1a).
Subtle glowing magical energy emanating from center.
High contrast, sharp edges, flat vector style.
No borders, no frames, no watermarks, no text.
Centered composition, 1024x1024px square canvas."""),

    ("plan4", "Plan4_Monochrome_Totem_Rune,",
     """A single RPG rune icon, monochrome totem style.
A bold triangle pointing upward with a vertical line cutting through the center.
Monochromatic crimson red color scheme using 2-tone depth (base #ff2244 + lighter highlight).
Bold blocky shapes, tribal-like angular patterns.
Dark circular background (#1a1a1a).
Subtle glow on edges, matte texture, flat vector design.
Strong silhouette, no gradients.
No ornamental details, no borders, no frames, no watermarks, no text.
Centered composition, 1024x1024px square canvas."""),

    ("plan5", "Plan5_GameUI_Frame_Rune,",
     """A single RPG rune icon, game UI skill icon style.
A bold triangle pointing upward with a vertical line cutting through the center as the central rune symbol.
Monochromatic crimson red color scheme (#ff2244).
Circular base with decorative crimson metallic border.
Dark circular background (#1a1a1a).
Subtle glow effect, consistent UI design language.
Flat vector style, transparent background.
No watermarks, no text.
Centered composition, 1024x1024px square canvas."""),
]

def make_prompt(plan_prefix, plan_body, rune, rarity):
    return plan_body.replace("crimson red", rune["color"]).replace("#ff2244", rune["color_hex"]).replace(
        "A bold triangle pointing upward with a vertical line cutting through the center", rune["shape_desc"]
    ).replace("#1a1a1a", rarity["bg"]).replace("subtle", rarity["glow"].lower())

generated = []
failed = []

for plan_key, plan_prefix, plan_body in PLANS:
    for rune in RUNES:
        for rarity in RARITIES:
            filename = f"{plan_key}_{rune['id']}_{rarity['name']}.png"
            filepath = os.path.join(output_dir, filename)
            
            prompt = make_prompt(plan_prefix, plan_body, rune, rarity)
            
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
                    print(f"OK {plan_key}/{filename} ({len(img_resp.content)} bytes)")
                else:
                    failed.append((plan_key, filename, str(data)[:200]))
                    print(f"FAIL {plan_key}/{filename}: {str(data)[:200]}")
                
                time.sleep(3)
            except Exception as e:
                failed.append((plan_key, filename, str(e)))
                print(f"FAIL {plan_key}/{filename}: {e}")
                time.sleep(3)

print(f"\n=== Summary ===")
print(f"Generated: {len(generated)}/{len(generated)+len(failed)}")
if failed:
    print(f"Failed: {len(failed)}")
    for pk, fn, err in failed:
        print(f"  {pk}/{fn}: {err[:100]}")
