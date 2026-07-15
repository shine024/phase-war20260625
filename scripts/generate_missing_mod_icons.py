#!/usr/bin/env python3
"""Generate 3 missing mod_icons."""
import requests, json, os, time

key = "sk-thpXTkWon9RiLMdnsZgqlQUH7XI6SdlhLYsx7eQToj7GtIPv"
BASE_URL = "https://apihub.agnes-ai.com/v1"
OUTPUT_DIR = r"F:\godot fair duet\create\phase-war\assets\ui\icons\mod_icons"

icons = [
    {
        "filename": "mod_special.png",
        "prompt": (
            "A flat 2D side-profile game icon of a glowing golden starburst emblem with radiating energy lines, "
            "symbolizing special legendary modifications. "
            "The starburst has 8 pointed rays with a bright golden yellow center fading to orange edges. "
            "Clean vector art style, thick dark outline, no shading depth. "
            "STRICTLY a pure 2D side profile silhouette view, absolutely NO front view, absolutely NO three quarter view, "
            "flat orthographic game sprite, single subject only centered, "
            "clean pure white background with NO ground, NO shadow, NO floor, NO reflection, NO watermark, NO signature, NO text, NO extra sketches. "
            "Game UI icon, 512x512, crisp edges, no Chinese characters, no kanji"
        ),
        "negative_prompt": (
            "shadow, ground, floor, reflection, text, watermark, signature, chinese, kanji, "
            "front view, perspective, 3D, depth, background scene, environment, extra objects, "
            "complex, detailed, realistic, photo"
        ),
    },
    {
        "filename": "mod_overdrive.png",
        "prompt": (
            "A flat 2D side-profile game icon of a lightning bolt striking through a power core, "
            "symbolizing overdrive phase overload energy surge. "
            "The lightning bolt is bright electric blue with white hot center, surrounded by crackling energy arcs. "
            "A circular power core behind it pulses with energy rings. "
            "Clean vector art style, thick dark outline, no shading depth. "
            "STRICTLY a pure 2D side profile silhouette view, absolutely NO front view, absolutely NO three quarter view, "
            "flat orthographic game sprite, single subject only centered, "
            "clean pure white background with NO ground, NO shadow, NO floor, NO reflection, NO watermark, NO signature, NO text, NO extra sketches. "
            "Game UI icon, 512x512, crisp edges, no Chinese characters, no kanji"
        ),
        "negative_prompt": (
            "shadow, ground, floor, reflection, text, watermark, signature, chinese, kanji, "
            "front view, perspective, 3D, depth, background scene, environment, extra objects, "
            "complex, detailed, realistic, photo"
        ),
    },
    {
        "filename": "mod_resonance.png",
        "prompt": (
            "A flat 2D side-profile game icon of concentric ripple waves emanating from a central crystal gem, "
            "symbolizing phase resonance. "
            "The central element is a hexagonal purple crystal with rippling wave rings expanding outward in alternating purple and blue tones. "
            "Clean vector art style, thick dark outline, no shading depth. "
            "STRICTLY a pure 2D side profile silhouette view, absolutely NO front view, absolutely NO three quarter view, "
            "flat orthographic game sprite, single subject only centered, "
            "clean pure white background with NO ground, NO shadow, NO floor, NO reflection, NO watermark, NO signature, NO text, NO extra sketches. "
            "Game UI icon, 512x512, crisp edges, no Chinese characters, no kanji"
        ),
        "negative_prompt": (
            "shadow, ground, floor, reflection, text, watermark, signature, chinese, kanji, "
            "front view, perspective, 3D, depth, background scene, environment, extra objects, "
            "complex, detailed, realistic, photo"
        ),
    },
]

session = requests.Session()
session.headers.update({
    "Authorization": f"Bearer {key}",
    "Content-Type": "application/json",
})

for icon_def in icons:
    fn = icon_def["filename"]
    fp = os.path.join(OUTPUT_DIR, fn)
    
    payload = {
        "model": "agnes-image-2.0-flash",
        "prompt": icon_def["prompt"],
        "negative_prompt": icon_def["negative_prompt"],
        "size": "512x512",
        "n": 1,
    }
    
    print(f"\n[{fn}] POST...")
    resp = session.post(f"{BASE_URL}/images/generations", json=payload, timeout=60)
    data = resp.json()
    
    if "data" not in data or len(data["data"]) == 0:
        err = data.get("error", {}).get("message", "Unknown error")
        code = data.get("code", "")
        msg = data.get("message", "")
        print(f"  API ERROR: code={code} msg={msg}")
        continue
    
    image_url = data["data"][0]["url"]
    print(f"  URL received ({len(image_url)} chars)")
    
    # Try downloading WITHOUT the auth header (URL may be pre-signed)
    dl_session = requests.Session()
    img_resp = dl_session.get(image_url, timeout=60)
    if img_resp.status_code == 200:
        with open(fp, 'wb') as f:
            f.write(img_resp.content)
        sz = os.path.getsize(fp)
        print(f"  OK: {fp} ({sz} bytes)")
    else:
        print(f"  Download failed: status={img_resp.status_code}")
        print(f"  Response: {img_resp.text[:200]}")
    
    time.sleep(5)

print("\nDone!")
