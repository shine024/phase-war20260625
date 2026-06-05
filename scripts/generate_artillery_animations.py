"""Generate artillery animation textures for INDIRECT weapon types (ROCKET/FLAK/MISSILE).

Generates 3 textures:
1. Ballistic arc trail - parabolic curve with smoke/ember trail
2. Muzzle blast - cannon firing with flash/smoke
3. Impact explosion - ground explosion with debris

Then removes white background using Pillow and deploys to the project.
"""
import os, json, base64, urllib.request, time, sys

# --- Config ---
config = os.path.expanduser("~/.hermes/config.yaml")
api_key = ""
with open(config, "r") as f:
    for line in f:
        if "api_key:" in line and not line.strip().startswith("#"):
            api_key = line.strip().split("api_key:", 1)[1].strip()
            break

if not api_key:
    print("ERROR: No API key found in config.yaml"); sys.exit(1)

BASE_URL = "https://apihub.agnes-ai.com/v1/images/generations"
MODEL = "agnes-image-2.0-flash"

PROJECT_DIR = r"F:\godot fair duet\create\phase-war"
SRC_DIR = os.path.join(PROJECT_DIR, "assets", "effects", "projectiles", "artillery_anim")
DEST_DIR = os.path.join(PROJECT_DIR, "assets", "effects", "projectiles", "weapons_realistic")
os.makedirs(SRC_DIR, exist_ok=True)

# --- Prompts ---
TEXTRUES = {
    "weapon_artillery_ballistic": (
        "A glowing parabolic ballistic arc trail against a pure white background. "
        "A smooth high arc curve from lower-left to upper-right with bright orange-yellow "
        "ember particles and grey smoke wisps following the curve path. "
        "Only the trail, NO shell, NO ground, NO explosion. "
        "Centered on 1024x1024, pure white #FFFFFF background, game asset quality."
    ),
    "weapon_artillery_muzzle": (
        "Close-up artillery cannon muzzle blast against a pure white background. "
        "A heavy tank gun barrel pointing right with bright orange-yellow muzzle flash "
        "bursting from the barrel tip. Grey-brown smoke cloud around the muzzle. "
        "Dust and dirt kicking up at the base. "
        "Centered on 1024x1024, pure white #FFFFFF background, game asset quality."
    ),
    "weapon_artillery_impact": (
        "Artillery shell impact explosion against a pure white background. "
        "Fiery orange-red explosion crater with debris and metal shrapnel flying outward. "
        "Thick grey smoke billowing upward. Expanding shockwave ring from the center. "
        "No ground visible, just the explosion effect. "
        "Centered on 1024x1024, pure white #FFFFFF background, game asset quality."
    ),
}


def make_request(prompt):
    """Make API request and return the image bytes. Returns None on failure."""
    data = json.dumps({
        "model": MODEL,
        "prompt": prompt,
        "n": 1,
        "size": "1024x1024",
    }).encode("utf-8")
    
    req = urllib.request.Request(
        BASE_URL,
        data=data,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
    )
    
    try:
        with urllib.request.urlopen(req, timeout=180) as resp:
            result = json.loads(resp.read().decode("utf-8"))
            if "data" not in result or not result["data"]:
                print(f"  ERROR: No data in response")
                return None
            img_info = result["data"][0]
            img_url = img_info.get("url", "")
            if not img_url:
                # Try b64_json
                b64 = img_info.get("b64_json", "")
                if b64:
                    print(f"  Got base64 ({len(b64)} chars)")
                    return base64.b64decode(b64)
                print(f"  ERROR: No URL or b64: {img_info.keys()}")
                return None
            print(f"  Downloading from: {img_url}")
            req2 = urllib.request.Request(img_url)
            with urllib.request.urlopen(req2, timeout=120) as resp2:
                return resp2.read()
    except Exception as e:
        print(f"  ERROR: {e}")
        return None


def remove_white_background(img_bytes, threshold=240):
    """Remove white background from image bytes, return new bytes with RGBA."""
    try:
        from PIL import Image
        import io
        img = Image.open(io.BytesIO(img_bytes)).convert("RGBA")
        w, h = img.size
        pixels = img.load()
        for y in range(h):
            for x in range(w):
                r, g, b, a = pixels[x, y]
                if r >= threshold and g >= threshold and b >= threshold:
                    pixels[x, y] = (0, 0, 0, 0)
        buf = io.BytesIO()
        img.save(buf, format="PNG")
        return buf.getvalue()
    except ImportError:
        print("  Pillow not installed - saving original")
        return img_bytes
    except Exception as e:
        print(f"  Pillow bg removal failed: {e} - saving original")
        return img_bytes


def main():
    import yaml
    from PIL import Image
    import io

    print("=== Step 1: Generating images via Agnes AI API ===\n")
    
    generated = {}
    for tex_name, prompt in TEXTRUES.items():
        print(f"--- Generating: {tex_name} ---")
        print(f"Prompt: {prompt[:120]}...")
        img_bytes = make_request(prompt)
        if img_bytes:
            # Check it's actually an image
            try:
                img = Image.open(io.BytesIO(img_bytes)).verify()
                print(f"  OK: {len(img_bytes)} bytes")
            except Exception as e:
                print(f"  WARNING: Not a valid image ({e}), trying to skip")
        
        out_path = os.path.join(SRC_DIR, tex_name + ".png")
        with open(out_path, "wb") as f:
            f.write(img_bytes)
        print(f"  Saved raw to: {out_path}")
        generated[tex_name] = out_path
        time.sleep(1.5)  # Rate limit

    print("\n=== Step 2: Removing white backgrounds ===\n")
    transparent = {}
    for tex_name, src_path in generated.items():
        print(f"--- Processing: {tex_name} ---")
        with open(src_path, "rb") as f:
            img_bytes = f.read()
        transparent_bytes = remove_white_background(img_bytes)
        
        out_path = os.path.join(SRC_DIR, tex_name + "_transparent.png")
        with open(out_path, "wb") as f:
            f.write(transparent_bytes)
        print(f"  Saved transparent to: {out_path}")
        transparent[tex_name] = out_path

    print("\n=== Step 3: Deployment plan ===\n")
    print("Generated files:")
    for k, v in transparent.items():
        print(f"  {k}: {v}")
    
    print("\nDeploy targets (in weapons_realistic/):")
    print("  weapon_artillery_ballistic.png -> 用于曲射弹道显示")
    print("  weapon_artillery_muzzle.png   -> 用于炮兵出膛动画")
    print("  weapon_artillery_impact.png   -> 用于炮弹命中爆炸")

    # Save manifest
    manifest = {
        "generated": generated,
        "transparent": transparent,
        "deploy": {
            "ballistic": "weapon_artillery_ballistic",
            "muzzle": "weapon_artillery_muzzle",
            "impact": "weapon_artillery_impact",
        }
    }
    with open(os.path.join(SRC_DIR, "manifest.json"), "w") as f:
        json.dump(manifest, f, indent=2)
    print(f"\nManifest saved to: {SRC_DIR}/manifest.json")


if __name__ == "__main__":
    main()
