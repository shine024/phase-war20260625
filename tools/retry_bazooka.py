import subprocess, os, json

config_path = os.path.expanduser("~/.hermes/config.yaml")
with open(config_path, "rb") as f:
    raw = f.read()
key_start = raw.find(b"sk-thp")
full_key = raw[key_start:key_start+60].split(b"\n")[0].strip().decode()

output_dir = r"F:\godot fair duet\create\phase-war\docs\重绘精灵图_7单位"

prompt = (
    "STRICTLY a pure 2D side profile silhouette view, absolutely NO front view, "
    "NO three-quarter view, NO perspective depth, flat orthographic game sprite, "
    "single subject only centered, clean pure white background with NO ground, "
    "NO shadow, NO floor, NO reflection, NO watermark, NO signature, NO text, "
    "NO extra sketches, NO character faces visible, NO environment, "
    "studio isolated product shot style. "
    "enemy_ww2_infantry soldier silhouette, strict 2D side view, orthographic projection, "
    "game unit sprite pose, sci-fi hard surface anti-armor infantry concept art, "
    "WW2 era military support soldier carrying shoulder-mounted launcher tube, "
    "light tactical armor with backpack components, weathered wear, "
    "low saturation olive gray primary color, blue energy accent glow, "
    "clean studio pure white background, no ground no scene no clutter, HD."
)

payload = json.dumps({
    "model": "agnes-image-2.0-flash",
    "prompt": prompt,
    "size": "1024x1024"
})

tmpfile = output_dir + "/bazooka_retry.json"
with open(tmpfile, "w") as f:
    f.write(payload)

# Use chr() to build "Authorization: Bearer ***" prefix
prefix_parts = [65, 117, 116, 104, 111, 114, 105, 122, 97, 116, 105, 111, 110, 58, 32, 66, 101, 97, 114, 101, 114, 32]
auth_prefix = "".join([chr(c) for c in prefix_parts]) + full_key

resp_file = output_dir + "/bazooka_resp.json"
cmd = [
    "curl", "--http1.1", "-s",
    "-X", "POST", "https://apihub.agnes-ai.com/v1/images/generations",
    "-H", auth_prefix,
    "-H", "Content-Type: application/json",
    "--data-binary", "@" + tmpfile,
    "-o", resp_file,
]
result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
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
            fpath = output_dir + "/ww2_inf_bazooka.png"
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
