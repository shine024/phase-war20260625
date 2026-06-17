"""
Generate 6 missing mod slot_type icons using agnes-image API.

Slots: deception, enhancement, guidance, system, thrust, weapons
Style: Military UI icons, 512x512, SVG-style flat design, white background
Output: assets/ui/icons/mod_icons/mod_<slot>.png
"""
import os, json, urllib.request, io
from PIL import Image

BASE_URL = "https://apihub.agnes-ai.com/v1/images/generations"
OUTPUT_DIR = r"F:\godot fair duet\create\phase-war\assets\ui\icons\mod_icons"

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

ICONS = [
    ("deception",
     "Military electronic warfare decoy system icon, military deception and countermeasure device with radar jamming antennas, orange and black warning color scheme, top-down view, clean military equipment illustration, solid white background, professional SVG-style flat icon design, 512x512, no text no watermark"),
    ("enhancement",
     "Military armor enhancement icon, reinforced armored plate with bolt-on composite armor blocks, steel gray color with bolt details, isometric view, clean military equipment illustration, solid white background, professional SVG-style flat icon design, 512x512, no text no watermark"),
    ("guidance",
     "Military missile guidance system icon, precision guidance module with gyroscope and GPS receiver, silver and blue color scheme, technical front view, clean military equipment illustration, solid white background, professional SVG-style flat icon design, 512x512, no text no watermark"),
    ("system",
     "Military tactical communication system icon, centralized command and control system with multiple antenna arrays and communication panels, dark gray and green, top-down view, clean military equipment illustration, solid white background, professional SVG-style flat icon design, 512x512, no text no watermark"),
    ("thrust",
     "Military jet engine thrust vectoring nozzle icon, turbofan engine with 2D vectoring exhaust nozzle, metallic gray with heat discoloration, side view, clean military equipment illustration, solid white background, professional SVG-style flat icon design, 512x512, no text no watermark"),
    ("weapons",
     "Military weapons system icon, mounted twin-barrel autocannon weapon system on armored mount, dark olive green, top-down view, clean military equipment illustration, solid white background, professional SVG-style flat icon design, 512x512, no text no watermark"),
]

def generate_icon(name, prompt):
    """Generate icon via API and save."""
    data = json.dumps({
        "model": "agnes-image-2.0-flash",
        "prompt": prompt,
        "image_size": "512x512",
    }).encode("utf-8")
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }
    req = urllib.request.Request(BASE_URL, data=data, headers=headers)
    with urllib.request.urlopen(req, timeout=300) as resp:
        result = json.loads(resp.read().decode("utf-8"))
    if "data" in result and len(result["data"]) > 0:
        item = result["data"][0]
        img_url = item.get("url")
        if img_url and "http" in str(img_url):
            img_req = urllib.request.Request(img_url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(img_req, timeout=60) as img_resp:
                img_data = img_resp.read()
            img = Image.open(io.BytesIO(img_data)).resize((512, 512), Image.Resampling.LANCZOS)
            output_path = os.path.join(OUTPUT_DIR, f"mod_{name}.png")
            img.save(output_path, "PNG")
            size_kb = os.path.getsize(output_path) / 1024
            return True, size_kb
    return False, "No URL"

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    for name, prompt in ICONS:
        path = os.path.join(OUTPUT_DIR, f"mod_{name}.png")
        if os.path.exists(path):
            print(f"SKIP: mod_{name}.png (exists)")
            continue
        print(f"Generating mod_{name}.png...", end=" ")
        ok, detail = generate_icon(name, prompt)
        if ok:
            print(f"OK ({detail:.0f} KB)")
        else:
            print(f"FAIL: {detail}")

if __name__ == "__main__":
    main()
