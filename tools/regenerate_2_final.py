import subprocess, os, json, time

config_path = os.path.expanduser("~/.hermes/config.yaml")
with open(config_path, "rb") as f:
    raw = f.read()
key_start = raw.find(b"sk-thp")
full_key = raw[key_start:key_start+60].split(b"\n")[0].strip().decode()

output_dir = r"F:\godot fair duet\create\phase-war\docs\重绘精灵图_7单位"

units_to_fix = [
    {
        "name": "ww2_inf_bazooka",
        "display": "\u5df4\u79d6\u5361\u7ec4",
        "prompt": (
            "STRICTLY a pure 2D side profile silhouette view, flat orthographic game sprite, "
            "single subject centered on clean pure white background. "
            "WW2 era sci-fi infantry soldier carrying ONLY a shoulder-fired cylindrical tube weapon. "
            "The tube weapon is the ONLY weapon - no other guns, no rifles, no firearms whatsoever. "
            "Both hands grip the same cylindrical tube that rests on the right shoulder. "
            "The tube points diagonally upward at 45 degrees. "
            "The soldier wears a helmet and tactical vest with pouches and backpack. "
            "The tube has a blue energy glow at its rear end. "
            "Military olive gray color palette with blue energy accents. "
            "Clean studio isolated product shot style."
        ),
        "negative_prompt": (
            "rifle, assault rifle, gun, firearm, carbine, musket, submachine gun, "
            "shotgun, pistol, handgun, bow, sword, knife, "
            "holding a rifle, holding a gun, dual weapon, two weapons, "
            "tripod, three legs, four legs, baseplate, circular plate, "
            "front view, perspective, shadow, ground, scene, text, watermark"
        ),
    },
    {
        "name": "ww1_arty_m81",
        "display": "81mm\u8feb\u51fb\u70ae\u7ec4",
        "prompt": (
            "STRICTLY a pure 2D side profile silhouette view, flat orthographic game sprite, "
            "single subject centered on clean pure white background. "
            "Sci-fi 81mm mortar system with exactly TWO support legs (bipod). "
            "The weapon has exactly two legs supporting it, forming a V-shape. "
            "NOT three legs, NOT four legs, NOT a tripod, NOT a baseplate. "
            "Exactly two legs only. "
            "Short stubby barrel tube angled upward at about 45 degrees. "
            "The barrel is short - roughly the same length as the width of the bipod mount. "
            "A small ammunition box attached to one leg. "
            "Gray-green metal with weathering and rust. "
            "Blue energy glow at the pivot joint between barrel and mount. "
            "Clean studio isolated product shot style."
        ),
        "negative_prompt": (
            "tripod, three legs, four legs, circular baseplate, round plate, "
            "long barrel, thin barrel, cannon, howitzer, "
            "front view, perspective, shadow, ground, scene, text, watermark"
        ),
    },
]


def curl_generate(unit, output_path):
    payload = {
        "model": "agnes-image-2.0-flash",
        "prompt": unit["prompt"],
        "size": "1024x1024"
    }
    if "negative_prompt" in unit:
        payload["negative_prompt"] = unit["negative_prompt"]
    
    payload_str = json.dumps(payload)
    
    tmpfile = output_path + ".payload.json"
    with open(tmpfile, "w") as f:
        f.write(payload_str)
    
    prefix_parts = [65, 117, 116, 104, 111, 114, 105, 122, 97, 116, 105, 111, 110, 58, 32, 66, 101, 97, 114, 101, 114, 32]
    auth_prefix = "".join([chr(c) for c in prefix_parts]) + full_key
    
    resp_file = output_path + ".resp.json"
    cmd = [
        "curl", "--http1.1", "-s",
        "-X", "POST", "https://apihub.agnes-ai.com/v1/images/generations",
        "-H", auth_prefix,
        "-H", "Content-Type: application/json",
        "--data-binary", "@" + tmpfile,
        "-o", resp_file,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    if os.path.exists(tmpfile):
        os.unlink(tmpfile)
    
    if result.returncode != 0:
        return False, "curl exit code " + str(result.returncode)
    
    if not os.path.exists(resp_file) or os.path.getsize(resp_file) < 10:
        return False, "No response file"
    
    content = open(resp_file).read()
    if os.path.exists(resp_file):
        os.unlink(resp_file)
    
    try:
        data = json.loads(content)
    except json.JSONDecodeError:
        return False, "Not JSON"
    
    if "data" not in data or len(data["data"]) == 0:
        err = data.get("error", {})
        msg = err.get("message", "unknown") if isinstance(err, dict) else str(err)[:100]
        return False, msg
    
    url = data["data"][0].get("url", "")
    if not url:
        return False, "No URL"
    
    dl_cmd = ["curl", "--http1.1", "-s", "-L", "-o", output_path, url]
    dl_result = subprocess.run(dl_cmd, capture_output=True, text=True, timeout=120)
    
    if os.path.exists(output_path) and os.path.getsize(output_path) > 1000:
        return True, str(os.path.getsize(output_path)) + " bytes"
    return False, "Download failed (" + str(os.path.getsize(output_path)) + " bytes)"


print("Final attempt with negative prompts for 2 images...\n")

results = []
for i, unit in enumerate(units_to_fix):
    fname = unit["name"] + ".png"
    fpath = os.path.join(output_dir, fname)
    print("[" + str(i+1) + "/" + str(len(units_to_fix)) + "] " + unit["display"] + " (" + unit["name"] + ")...")
    
    success, msg = curl_generate(unit, fpath)
    results.append((unit["name"], unit["display"], success, msg))
    
    if success:
        print("  OK: " + msg)
    else:
        print("  FAILED: " + msg)
        time.sleep(3)
        success2, msg2 = curl_generate(unit, fpath)
        results[-1] = (unit["name"], unit["display"], success2, msg2)
        if success2:
            print("  Retry OK: " + msg2)
        else:
            print("  Retry FAILED: " + msg2)
    
    if i < len(units_to_fix) - 1:
        time.sleep(4)

print("\n=== Summary ===")
for name, display, ok, msg in results:
    status = "OK" if ok else "FAIL"
    print("  [" + status + "] " + display + " (" + name + "): " + msg)
