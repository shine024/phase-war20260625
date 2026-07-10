import subprocess, os, json, time, sys

config_path = os.path.expanduser("~/.hermes/config.yaml")
with open(config_path, "rb") as f:
    raw = f.read()
key_start = raw.find(b"sk-thp")
full_key = raw[key_start:key_start+80].split(b"\n")[0].strip().decode("utf-8", errors="ignore")

API_URL = "https://apihub.agnes-ai.com/v1/images/generations"
HEADERS = {
    "Authorization": "Bearer " + full_key,
    "Content-Type": "application/json",
}

UNITS = [
    {
        "id": "cold_sup_zsu23",
        "name": "ZSU-23-4自行高炮",
        "prompt": """STRICTLY a pure 2D side profile silhouette view, absolutely NO front view, absolutely NO three-quarter view, flat orthographic game sprite, single subject only centered, clean pure white background with NO ground, NO shadow, NO floor, NO reflection, NO watermark, NO signature, NO text, NO extra sketches, NO character faces visible, NO environment, studio isolated product shot style.

A ZSU-23-4 Shilka self-propelled anti-aircraft gun on a tracked tank chassis. The vehicle has four long thin anti-aircraft cannons arranged in two pairs pointing upward at steep angle (45 degrees or more). The turret is box-shaped with a prominent rotating radar dome/search radar on top of the turret. The chassis is a tracked military vehicle similar to BMP-1 size, painted in olive drab green with rust weathering. Four guns are clearly visible from the side, angled sharply upward toward the sky. A search radar dish is mounted on top of the turret, rotating. Glowing cyan-blue energy accents on sensors and gun mounts. Clean vector art style, bold outlines, cel-shaded, flat shading with subtle gradients, game asset icon quality."""
    },
    {
        "id": "mod_sup_m6",
        "name": "自行高炮M6",
        "prompt": """STRICTLY a pure 2D side profile silhouette view, absolutely NO front view, absolutely NO three-quarter view, flat orthographic game sprite, single subject only centered, clean pure white background with NO ground, NO shadow, NO floor, NO reflection, NO watermark, NO signature, NO text, NO extra sketches, NO character faces visible, NO environment, studio isolated product shot style.

A M6 Half-Track Self-Propelled Anti-Aircraft Gun. The vehicle is a WWII-era half-track: front section has a cab with windshield and driver compartment (like a truck), rear section has continuous tracks instead of wheels. On top is a circular open-topped turret mounting twin 40mm Bofors anti-aircraft guns. Both guns are pointed sharply upward at a steep angle (60 degrees or more) for anti-aircraft use. The half-track body is painted in desert tan/sand color with heavy rust weathering streaks. Twin barrels are clearly visible from the side, both pointing up. Glowing cyan-blue energy accents on gun mounts and engine area. Clean vector art style, bold outlines, cel-shaded, flat shading with subtle gradients, game asset icon quality."""
    },
    {
        "id": "ww1_arty_m81",
        "name": "81mm迫击炮组",
        "prompt": """STRICTLY a pure 2D side profile silhouette view, absolutely NO front view, absolutely NO three-quarter view, flat orthographic game sprite, single subject only centered, clean pure white background with NO ground, NO shadow, NO floor, NO reflection, NO watermark, NO signature, NO text, NO extra sketches, NO character faces visible, NO environment, studio isolated product shot style.

An 81mm mortar team with the mortar weapon. The mortar consists of a very short stubby barrel (only about 1/4 the length of the base) mounted on a small bipod with exactly TWO legs (not three, not four). The barrel points straight up at 90 degree angle. Next to the mortar stands one soldier in WW1 uniform holding a round mortar shell. The mortar tube is thick and stubby, clearly much shorter than tall - it looks like a short pipe on a bipod. The bipod legs are simple thin rods splayed outward for stability. The soldier wears a WW1 era helmet and uniform in olive drab. The entire setup is compact and low to the ground. Glowing cyan-blue energy accents on the mortar sight and shell. Clean vector art style, bold outlines, cel-shaded, flat shading with subtle gradients, game asset icon quality."""
    },
]

output_dir = r"F:\godot fair duet\create\phase-war\docs\重绘精灵图_7单位"
os.makedirs(output_dir, exist_ok=True)

for unit in UNITS:
    uid = unit["id"]
    name = unit["name"]
    time.sleep(10)  # Wait between units to avoid rate limiting
    print(f"\n=== Generating: {name} ({uid}) ===")

    payload = {
        "model": "nano-banana-pro",
        "prompt": unit["prompt"],
        "size": "1024x1024",
        "quality": "hd",
        "response_format": "url",
    }

    for attempt in range(3):
        try:
            import urllib.request
            data = json.dumps(payload).encode("utf-8")
            req = urllib.request.Request(API_URL, data=data, headers=HEADERS, method="POST")
            with urllib.request.urlopen(req, timeout=120) as resp:
                body = json.loads(resp.read().decode("utf-8"))

            if "data" in body and len(body["data"]) > 0:
                img_url = body["data"][0].get("url", "")
                if img_url:
                    # Download image
                    img_req = urllib.request.Request(img_url, headers={"User-Agent": "Mozilla/5.0"})
                    with urllib.request.urlopen(img_req, timeout=120) as img_resp:
                        img_data = img_resp.read()
                    out_path = os.path.join(output_dir, f"{uid}.png")
                    with open(out_path, "wb") as out_f:
                        out_f.write(img_data)
                    print(f"OK: {len(img_data):,} bytes -> {out_path}")
                    break
                else:
                    print(f"No URL in response: {json.dumps(body, indent=2)[:200]}")
            elif "error" in body:
                print(f"API error: {body['error']}")
            else:
                print(f"Unexpected response: {json.dumps(body, indent=2)[:200]}")
        except Exception as e:
            print(f"Attempt {attempt+1} failed: {e}")
            time.sleep(15)
    else:
        print(f"FAILED after 3 attempts: {uid}")

print("\n=== Done ===")