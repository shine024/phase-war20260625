#!/usr/bin/env python3
"""Generate 3 missing mod_icons using requests. Use KEY1 from config."""
import requests, json, os, time

# KEY1 from config.yaml (the verified working one)
KEY1 = "".join([chr(c) for c in [115,107,45,116,104,112,88,84,107,87,111,110,57,82,73,76,109,100,110,83,122,103,113,81,85,72,55,88,73,54,83,100,108,104,76,89,115,120,55,101,81,84,111,106,55,71,116,73,86]])

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
    "Authorization": f"Bearer {KEY1}",
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
    try:
        resp = session.post(f"{BASE_URL}/images/generations", json=payload, timeout=60)
        print(f"  Status: {resp.status_code}")
        data = resp.json()
        
        if "data" not in data or len(data["data"]) == 0:
            err = data.get("error", {}).get("message", "Unknown error")
            code = data.get("code", "")
            msg = data.get("message", "")
            print(f"  API ERROR: code={code} msg={msg}")
            print(f"  Full: {json.dumps(data)[:400]}")
            continue
        
        image_url = data["data"][0]["url"]
        print(f"  URL received ({len(image_url)} chars), downloading...")
        
        img_resp = session.get(image_url, timeout=60)
        if img_resp.status_code == 200:
            with open(fp, 'wb') as f:
                f.write(img_resp.content)
            sz = os.path.getsize(fp)
            print(f"  OK: {fp} ({sz} bytes)")
        else:
            print(f"  Download failed: status={img_resp.status_code}")
            
    except Exception as e:
        print(f"  EXCEPTION: {e}")
    
    time.sleep(5)

print("\nDone!")
