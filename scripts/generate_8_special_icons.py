"""
Generate 8 special-style card icons with green screen (#00FF00) background.
After generation, remove green background and resize to 512x512.

Cards:
  1. ww1_rolls      - Rolls-Royce armored car
  2. ww1_77mm       - 77mm field gun
  3. ww1_cavalry    - Cavalry scout (horseback)
  4. ww1_engineer   - Combat engineer equipment
  5. ww2_tiger      - Tiger I heavy tank
  6. mod_technical  - Armed pickup truck
  7. mod_m1a2sep    - M1A2 SEP Abrams
  8. fut_nexus      - Sci-fi hover tank boss

Output: assets/card_icons/<card_id>.png (512x512, transparent)
"""
import os, json, urllib.request, time
from PIL import Image
import io

BASE_URL = "https://apihub.agnes-ai.com/v1/images/generations"
OUTPUT_DIR = r"F:\godot fair duet\create\phase-war\assets\card_icons"

# Read API key
api_key = os.environ.get("SKIPPABLE_API_KEY", "")
if not api_key:
    config_path = os.path.expanduser("~/.hermes/config.yaml")
    try:
        with open(config_path, "r", encoding="utf-8") as f:
            for line in f:
                if "api_key:" in line and not line.strip().startswith("#"):
                    api_key = line.strip().split("api_key:", 1)[1].strip()
                    break
    except Exception:
        pass

if not api_key:
    print("ERROR: No API key!")
    exit(1)

# Card definitions with prompts
CARDS = [
    ("ww1_rolls",
     "WWI Rolls-Royce armored car, true profile side view, orthographic projection, facing left, riveted steel armor body, four spoked wheels, rotating machine gun turret on top with mounted heavy machine gun, dull khaki and olive drab military paint, weathered metal with rust spots and rivets, semi-realistic hard-surface military illustration, pure #00FF00 green screen background, no ground no scene, 512x512, no text no watermark",
     "text, watermark, signature, ground, landscape, background scenery, multiple angles, 3/4 view, front view, facing right"),
    ("ww1_77mm",
     "WWI German 77mm FK 96 field gun artillery piece, true profile side view, orthographic projection, facing left (barrel pointing left), long thin artillery barrel with muzzle brake, angled steel gun shield, wooden spoked wheels, split trail carriage, dull gray-green military paint, weathered metal, semi-realistic hard-surface military illustration, pure #00FF00 green screen background, no ground no scene, 512x512, no text no watermark",
     "text, watermark, signature, ground, landscape, background scenery, multiple angles, 3/4 view, front view, facing right, crew, soldiers"),
    ("ww1_cavalry",
     "WWI cavalry scout on horseback, true profile side view, orthographic projection, facing left, rider in khaki military tunic and peaked cap holding cavalry carbine rifle and sheathed saber, brown war horse in full gallop pose, leather saddle and equipment, semi-realistic military illustration, pure #00FF00 green screen background, no ground no scene, 512x512, no text no watermark",
     "text, watermark, signature, ground, landscape, background scenery, multiple angles, 3/4 view, front view, facing right"),
    ("ww1_engineer",
     "WWI combat engineer squad equipment, true profile side view, orthographic projection, facing left, small Stokes mortar on ground mount with ammo boxes, engineering tools (shovel, pickaxe, barbed wire roll), sandbags, steel helmets stacked, dull khaki and olive equipment, weathered metal and wood, semi-realistic hard-surface military illustration, pure #00FF00 green screen background, no ground no scene, 512x512, no text no watermark",
     "text, watermark, signature, ground, landscape, background scenery, multiple angles, 3/4 view, front view, facing right, individual soldiers"),
    ("ww2_tiger",
     "WWII German Tiger I heavy tank, true profile side view, orthographic projection, facing left (turret and gun barrel pointing left), box-like welded steel hull armor, long 88mm KwK 36 gun barrel with muzzle brake, interleaved road wheels with track, angular turret with cupola, dunkelgelb dark yellow base with brown and green camouflage stripes, Zimmerit anti-magnetic coating texture, weathered metal with chips, semi-realistic hard-surface military illustration, pure #00FF00 green screen background, no ground no scene, 512x512, no text no watermark",
     "text, watermark, signature, ground, landscape, background scenery, multiple angles, 3/4 view, front view, facing right, King Tiger, Tiger II, Porsche turret, Schmalturm"),
    ("mod_technical",
     "modern technical armed pickup truck, true profile side view, orthographic projection, facing left, civilian Toyota Hilux pickup truck chassis, mounted heavy machine gun (DShK) on pedestal in truck bed, RPG launcher rack, rugged off-road tires, sun-bleached white and beige paint with rust, irregular militia aesthetic with welded makeshift gun mount, semi-realistic hard-surface military illustration, pure #00FF00 green screen background, no ground no scene, 512x512, no text no watermark",
     "text, watermark, signature, ground, landscape, background scenery, multiple angles, 3/4 view, front view, facing right, military APC, armored vehicle"),
    ("mod_m1a2sep",
     "modern US M1A2 SEP Abrams main battle tank, true profile side view, orthographic projection, facing left (turret and gun barrel pointing left), 120mm M256 smoothbore gun barrel with bore evacuator, CROWS II remote weapon station on turret roof, explosive reactive armor blocks on hull sides, TUSK urban survival kit panels, commander independent thermal viewer, desert tan CARC paint, weathered metal with dust, semi-realistic hard-surface military illustration, pure #00FF00 green screen background, no ground no scene, 512x512, no text no watermark",
     "text, watermark, signature, ground, landscape, background scenery, multiple angles, 3/4 view, front view, facing right, basic M1A2 without SEP upgrades, Leopard tank"),
    ("fut_nexus",
     "futuristic sci-fi super heavy hover tank boss unit, true profile side view, orthographic projection, facing left (main cannon pointing left), massive dual heavy plasma cannon barrels with blue-purple energy glow, hovering chassis with no wheels, energy shield emitters emitting translucent hexagonal barrier, 40mm grenade auto-cannon, glowing cyan reactor core vents, dark gunmetal armor plates with luminous energy lines, imposing scale, semi-realistic hard-surface sci-fi military illustration, pure #00FF00 green screen background, no ground no scene, 512x512, no text no watermark",
     "text, watermark, signature, ground, landscape, background scenery, multiple angles, 3/4 view, front view, facing right, conventional tank treads, wheels, medieval, organic alien biomass"),
]

def generate_image(card_id, prompt, negative, output_dir, model="agnes-image-2.0-flash"):
    """Generate image via API."""
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
                img_url = item.get("url")
                if img_url and "http" in str(img_url):
                    img_req = urllib.request.Request(img_url, headers={"User-Agent": "Mozilla/5.0"})
                    with urllib.request.urlopen(img_req, timeout=60) as img_resp:
                        img_data = img_resp.read()
                    return img_data
            return None
    except Exception as e:
        print(f"  ERROR: {e}")
        return None


def remove_green_background(img_bytes):
    """Remove #00FF00 green screen background and convert to transparent PNG."""
    img = Image.open(io.BytesIO(img_bytes)).convert("RGBA")
    width, height = img.size

    # Create mask for green pixels
    pixels = img.load()
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            # Check if pixel is close to pure green #00FF00
            if g > 200 and r < 55 and b < 55:
                pixels[x, y] = (0, 0, 0, 0)  # Make transparent

    # Resize to 512x512
    img_resized = img.resize((512, 512), Image.Resampling.LANCZOS)

    # Convert to RGB then PNG (remove alpha if needed, but keep transparency)
    return img_resized


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    total = len(CARDS)
    success = 0
    failed = 0

    for i, (card_id, prompt, negative) in enumerate(CARDS):
        print(f"[{i+1}/{total}] Generating: {card_id}...")

        img_data = generate_image(card_id, prompt, negative, OUTPUT_DIR)
        if img_data is None:
            print(f"  FAIL: No image data from API")
            failed += 1
            continue

        try:
            img = remove_green_background(img_data)
            output_path = os.path.join(OUTPUT_DIR, f"{card_id}.png")
            img.save(output_path, "PNG")
            size_kb = os.path.getsize(output_path) / 1024
            print(f"  OK: {output_path} ({size_kb:.0f} KB)")
            success += 1
        except Exception as e:
            print(f"  FAIL: {e}")
            failed += 1

        if i < total - 1:
            time.sleep(3)

    print()
    print("=" * 50)
    print(f"Generated: {success}, Failed: {failed}")


if __name__ == "__main__":
    main()
