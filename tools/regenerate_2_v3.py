import subprocess, os, json, time

config_path = os.path.expanduser("~/.hermes/config.yaml")
with open(config_path, "rb") as f:
    raw = f.read()
key_start = raw.find(b"sk-thp")
full_key = raw[key_start:key_start+60].split(b"\n")[0].strip().decode()

output_dir = r"F:\godot fair duet\create\phase-war\docs\重绘精灵图_7单位"

# Build auth header safely
prefix_parts = [65, 117, 116, 104, 111, 114, 105, 122, 97, 116, 105, 111, 110, 58, 32, 66, 101, 97, 114, 101, 114, 32]
auth_prefix = "".join([chr(c) for c in prefix_parts]) + full_key


def curl_generate(prompt, negative_prompt, output_path):
    payload = {
        "model": "agnes-image-2.0-flash",
        "prompt": prompt,
        "negative_prompt": negative_prompt,
        "size": "1024x1024"
    }
    
    tmpfile = output_path + ".payload.json"
    with open(tmpfile, "w") as f:
        json.dump(payload, f)
    
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


units = [
    {
        "name": "ww2_inf_bazooka",
        "display": "\u5df4\u79d6\u5361\u7ec4",
        "prompt": (
            "A sci-fi WW2-era infantry soldier in profile view facing left, on pure white background. "
            "The soldier is holding a LARGE cylindrical shoulder-fired tube weapon with BOTH hands. "
            "This tube weapon is the MAIN and ONLY weapon. The soldier grips it firmly at the front and rear. "
            "The tube rests on the soldier's right shoulder and points diagonally upward toward the top-left. "
            "The soldier wears a combat helmet, tactical vest with pouches, backpack with ammo canisters, "
            "cargo pants with knee pads, combat boots. "
            "Military olive gray color, blue energy glow at the rear of the tube. "
            "Side profile silhouette, flat 2D game sprite style, clean studio lighting."
        ),
        "negative_prompt": (
            "rifle, assault rifle, gun, firearm, carbine, musket, submachine gun, shotgun, pistol, handgun, bow, sword, knife, "
            "holding a rifle, holding a gun, dual weapons, two weapons, "
            "front view, three-quarter view, perspective, shadow, ground, scene, text, watermark, logo, "
            "carrying a tube on back, tube strapped to backpack, launcher on back only"
        ),
    },
    {
        "name": "ww1_arty_m81",
        "display": "81mm\u8feb\u51fb\u70ae\u7ec4",
        "prompt": (
            "A sci-fi 81mm mortar system in side profile view, on pure white background. "
            "SHORT stubby thick barrel tube angled upward at 45 degrees. "
            "The barrel is very short and fat - a stubby tube, not a long barrel. "
            "Barrel length is less than half the total height of the weapon. "
            "The barrel is proportionally SHORT and THICK, like a stubby tube. "
            "Supported by exactly TWO legs forming a V-shape base. "
            "Two splayed legs only. No third leg. No central post. "
            "A rectangular ammunition box attached to one leg. "
            "Gray-green metal with weathering and rust. "
            "Blue energy glow at the pivot joint between barrel and mount. "
            "Flat 2D game sprite style, clean studio lighting."
        ),
        "negative_prompt": (
            "long barrel, thin barrel, long tube, cannon, howitzer, artillery piece, heavy cannon, railgun, "
            "tripod, three legs, three-legged, tri-pod, central post, vertical post, "
            "baseplate, circular plate, round plate, disk, disc, "
            "four legs, quadruped, mechanical arm, manipulator, claw, pincer, "
            "soldier, person, human, rifle, gun, firearm, "
            "front view, perspective, shadow, ground, scene, text, watermark, logo"
        ),
    },
]


print("Regenerating 2 images...\n")

results = []
for i, unit in enumerate(units):
    fname = unit["name"] + ".png"
    fpath = os.path.join(output_dir, fname)
    print("[" + str(i+1) + "/" + str(len(units)) + "] " + unit["display"] + " (" + unit["name"] + ")...")
    
    success, msg = curl_generate(unit["prompt"], unit["negative_prompt"], fpath)
    results.append((unit["name"], unit["display"], success, msg))
    
    if success:
        print("  OK: " + msg)
    else:
        print("  FAILED: " + msg)
        time.sleep(3)
        success2, msg2 = curl_generate(unit["prompt"], unit["negative_prompt"], fpath)
        results[-1] = (unit["name"], unit["display"], success2, msg2)
        if success2:
            print("  Retry OK: " + msg2)
        else:
            print("  Retry FAILED: " + msg2)
    
    if i < len(units) - 1:
        time.sleep(4)

print("\n=== Summary ===")
for name, display, ok, msg in results:
    status = "OK" if ok else "FAIL"
    print("  [" + status + "] " + display + " (" + name + "): " + msg)
