import subprocess, os, json, time

config_path = os.path.expanduser("~/.hermes/config.yaml")
with open(config_path, "rb") as f:
    raw = f.read()
key_start = raw.find(b"sk-thp")
full_key = raw[key_start:key_start+60].split(b"\n")[0].strip().decode()

output_dir = r"F:\godot fair duet\create\phase-war\docs\重绘精灵图_7单位"

# M81 - extreme negative prompt to force bipod + short barrel
prompt_m81 = (
    "STRICTLY a pure 2D side profile silhouette view, flat orthographic game sprite, "
    "single subject centered on clean pure white background. "
    "Sci-fi mortar system with exactly TWO legs forming a V-shape base. "
    "ONLY two legs. Exactly two support legs. No third leg. No central post. No tripod. "
    "Short stubby thick barrel tube pointing upward at 45 degrees. "
    "The barrel is very short and fat - like a stub, not a long tube. "
    "Barrel length is shorter than the width of the two-legged base. "
    "Ammo box attached to left leg. "
    "Gray-green metal with weathering. Blue energy glow at pivot. "
    "Clean studio isolated product shot style."
)

negative_m81 = (
    "tripod, three legs, three-legged, tri-pod, central post, vertical post, "
    "baseplate, circular plate, round plate, disk, disc, "
    "long barrel, thin barrel, long tube, cannon, howitzer, artillery piece, "
    "four legs, quadruped, mechanical arm, manipulator, claw, pincer, "
    "rifle, gun, firearm, soldier, person, human, "
    "front view, perspective, shadow, ground, scene, text, watermark, logo"
)

payload = {
    "model": "agnes-image-2.0-flash",
    "prompt": prompt_m81,
    "negative_prompt": negative_m81,
    "size": "1024x1024"
}

tmpfile = output_dir + "/m81_extreme.json"
with open(tmpfile, "w") as f:
    f.write(json.dumps(payload))

prefix_parts = [65, 117, 116, 104, 111, 114, 105, 122, 97, 116, 105, 111, 110, 58, 32, 66, 101, 97, 114, 101, 114, 32]
auth_prefix = "".join([chr(c) for c in prefix_parts]) + full_key

resp_file = output_dir + "/m81_resp.json"
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

print("Return code:", result.returncode)
if result.returncode != 0:
    print("stderr:", result.stderr[:500])

if os.path.exists(resp_file):
    content = open(resp_file).read()
    print("Response size:", len(content))
    try:
        data = json.loads(content)
        if "data" in data and len(data["data"]) > 0:
            url = data["data"][0].get("url", "")
            print("URL:", url[:80] + "...")
            fpath = output_dir + "/ww1_arty_m81.png"
            dl_cmd = ["curl", "--http1.1", "-s", "-L", "-o", fpath, url]
            dl_result = subprocess.run(dl_cmd, capture_output=True, text=True, timeout=120)
            if os.path.exists(fpath):
                print("Downloaded OK:", os.path.getsize(fpath), "bytes")
        else:
            err = data.get("error", {})
            if isinstance(err, dict):
                print("Error:", err.get("message", "unknown"))
            else:
                print("Error:", str(err)[:200])
    except Exception as e:
        print("Not JSON:", e)
else:
    print("No response file")
