"""Regenerate artillery textures with better prompts for game use."""
import os, json, base64, urllib.request, time, sys
from PIL import Image
import io

config = os.path.expanduser("~/.hermes/config.yaml")
api_key = ""
with open(config, "r") as f:
    for line in f:
        if "api_key:" in line and not line.strip().startswith("#"):
            api_key = line.strip().split("api_key:", 1)[1].strip()
            break

BASE_URL = "https://apihub.agnes-ai.com/v1/images/generations"
MODEL = "agnes-image-2.0-flash"
SRC_DIR = r"F:\godot fair duet\create\phase-war\assets\effects\projectiles\artillery_anim"

# Better prompts - focus on just the effect element, not a complete scene
PROMPTS = {
    "weapon_artillery_muzzle": (
        "A large bright muzzle flash from an artillery cannon, viewed from the side, pure white background. "
        "An intense cone-shaped orange-yellow flame explosion coming out of a dark gun barrel tip on the left side. "
        "Grey smoke cloud expanding around the muzzle. Small sparks and embers scattered. "
        "NO tank body, NO tracks, NO ground. Only the muzzle flash and smoke cloud. "
        "Centered on 1024x1024, pure white #FFFFFF background, game asset quality."
    ),
    "weapon_artillery_impact": (
        "An artillery shell ground explosion, viewed from the side, pure white background. "
        "A fiery orange-red explosion crater with dirt, rocks, and metal debris flying outward and upward. "
        "Thick grey smoke cloud billowing from the impact point. Expanding shockwave ring at ground level. "
        "No ground plane visible, just the explosion effect floating against white. "
        "Centered on 1024x1024, pure white #FFFFFF background, game asset quality."
    ),
}


def make_request(prompt):
    data = json.dumps({
        "model": MODEL,
        "prompt": prompt,
        "n": 1,
        "size": "1024x1024",
    }).encode("utf-8")
    req = urllib.request.Request(BASE_URL, data=data, headers={
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    })
    try:
        with urllib.request.urlopen(req, timeout=180) as resp:
            result = json.loads(resp.read().decode("utf-8"))
            if "data" not in result or not result["data"]:
                return None
            img_info = result["data"][0]
            img_url = img_info.get("url", "")
            if not img_url:
                b64 = img_info.get("b64_json", "")
                if b64:
                    return base64.b64decode(b64)
                return None
            req2 = urllib.request.Request(img_url)
            with urllib.request.urlopen(req2, timeout=120) as resp2:
                return resp2.read()
    except Exception as e:
        print(f"  ERROR: {e}")
        return None


def remove_white_background(img_bytes, threshold=230):
    try:
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
    except Exception as e:
        print(f"  Pillow bg removal failed: {e}")
        return img_bytes


def main():
    for tex_name, prompt in PROMPTS.items():
        print(f"\n--- Regenerating: {tex_name} ---")
        print(f"Prompt: {prompt[:120]}...")
        img_bytes = make_request(prompt)
        if not img_bytes:
            print(f"  SKIP: Generation failed")
            continue
        
        # Save raw
        raw_path = os.path.join(SRC_DIR, tex_name + "_v2.png")
        with open(raw_path, "wb") as f:
            f.write(img_bytes)
        print(f"  Raw saved: {raw_path}")
        
        # Remove background
        transparent_bytes = remove_white_background(img_bytes)
        trans_path = os.path.join(SRC_DIR, tex_name + "_v2_transparent.png")
        with open(trans_path, "wb") as f:
            f.write(transparent_bytes)
        print(f"  Transparent saved: {trans_path}")
        time.sleep(1.5)

    print("\nDone. Check v2 files in:", SRC_DIR)


if __name__ == "__main__":
    main()
