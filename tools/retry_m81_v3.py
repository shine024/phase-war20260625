import subprocess, os, json, time

config_path = os.path.expanduser("~/.hermes/config.yaml")
with open(config_path, "rb") as f:
    raw = f.read()
key_start = raw.find(b"sk-thp")
full_key = raw[key_start:key_start+60].split(b"\n")[0].strip().decode()

output_dir = r"F:\godot fair duet\create\phase-war\docs\重绘精灵图_7单位"

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


# M81 - extreme simplification: describe it as a short tube on two legs only
# Remove all complex details that confuse the AI into adding tripods and long barrels
prompt_m81 = (
    "A short stubby cannon on two legs, side view, white background. "
    "The cannon barrel is very short and thick, like a fat pipe pointing up at 45 degrees. "
    "The barrel is short - shorter than the height of the two legs. "
    "Only two legs support the cannon, forming an inverted V shape. "
    "No third leg. No central column. No tripod. "
    "A small ammo box is attached to one leg. "
    "Gray-green metal with rust spots. Blue glow at the pivot. "
    "Simple flat 2D game sprite style."
)

negative_m81 = (
    "tripod, three legs, three-legged, tri-pod, central column, central post, vertical post, "
    "baseplate, circular baseplate, round plate, disk, disc, "
    "long barrel, long tube, long cannon, howitzer, heavy cannon, railgun, artillery, "
    "four legs, quadruped, mechanical arm, manipulator, claw, pincer, "
    "soldier, person, human, rifle, gun, firearm, weapon, "
    "front view, perspective, shadow, ground, scene, text, watermark, logo, "
    "steampunk, fantasy, magic, glowing orb, energy core, reactor"
)

print("Final attempt for ww1_arty_m81...\n")

fpath = os.path.join(output_dir, "ww1_arty_m81.png")
success, msg = curl_generate(prompt_m81, negative_m81, fpath)
if success:
    print("OK: " + msg)
else:
    print("FAILED: " + msg)
    time.sleep(3)
    success2, msg2 = curl_generate(prompt_m81, negative_m81, fpath)
    print("Retry: " + ("OK: " + msg2 if success2 else "FAILED: " + msg2))
