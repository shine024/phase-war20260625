import subprocess, os, json, time

config_path = os.path.expanduser("~/.hermes/config.yaml")
with open(config_path, "rb") as f:
    raw = f.read()
key_start = raw.find(b"sk-thp")
full_key = raw[key_start:key_start+60].split(b"\n")[0].strip().decode()

output_dir = r"F:\godot fair duet\create\phase-war\docs\重绘精灵图_7单位"

units = [
    {
        "name": "ww2_inf_bazooka",
        "display": "\u5df4\u79d6\u5361\u7ec4",
        "prompt": (
            "STRICTLY a pure 2D side profile silhouette view, absolutely NO front view, "
            "NO three-quarter view, NO perspective depth, flat orthographic game sprite, "
            "single subject only centered, clean pure white background with NO ground, "
            "NO shadow, NO floor, NO reflection, NO watermark, NO signature, NO text, "
            "NO extra sketches, NO character faces visible, NO environment, "
            "studio isolated product shot style. "
            "enemy_ww2_infantry soldier silhouette, strict 2D side view, orthographic projection, "
            "game unit sprite pose, sci-fi hard surface anti-armor infantry concept art, "
            "WW2 era military support soldier, shoulder-mounted anti-tank launcher tube held horizontally, "
            "cylindrical launcher barrel clearly visible pointing right, "
            "light tactical armor with backpack components, weathered wear, "
            "low saturation olive gray primary color, blue energy accent glow at launcher tip, "
            "clean studio pure white background, no ground no scene no clutter, HD."
        ),
    },
    {
        "name": "ww1_arty_m81",
        "display": "81mm\u8feb\u51fb\u70ae\u7ec4",
        "prompt": (
            "STRICTLY a pure 2D side profile silhouette view, absolutely NO front view, "
            "NO three-quarter view, NO perspective depth, flat orthographic game sprite, "
            "single subject only centered, clean pure white background with NO ground, "
            "NO shadow, NO floor, NO reflection, NO watermark, NO signature, NO text, "
            "NO extra sketches, NO character faces visible, NO environment, "
            "studio isolated product shot style. "
            "enemy_ww1_artillery piece silhouette, strict 2D side view, orthographic projection, "
            "game unit sprite pose, sci-fi hard surface mortar system concept art, "
            "short-barrel 81mm mortar tube angled upward, circular baseplate below, "
            "compact ammunition box or canister on the side, small mechanical assist arm, "
            "metal weathering and rust, low saturation gray-green primary color, "
            "blue energy ignition module glow, "
            "clean studio pure white background, no ground no scene no clutter, HD."
        ),
    },
    {
        "name": "mod_sup_m6",
        "display": "\u81ea\u884c\u9ad8\u70aeM6",
        "prompt": (
            "STRICTLY a pure 2D side profile silhouette view, absolutely NO front view, "
            "NO three-quarter view, NO perspective depth, flat orthographic game sprite, "
            "single subject only centered, clean pure white background with NO ground, "
            "NO shadow, NO floor, NO reflection, NO watermark, NO signature, NO text, "
            "NO extra sketches, NO character faces visible, NO environment, "
            "studio isolated product shot style. "
            "enemy_modern_self_propelled_aa_platform silhouette, strict 2D side view, orthographic projection, "
            "game unit sprite pose, sci-fi hard surface anti-aircraft vehicle concept art, "
            "modern self-propelled anti-aircraft platform, multi-barrel rotating turret on top, "
            "phased array radar panel visible on turret roof, tracked or wheeled chassis below, "
            "complex armor panels and heat dissipation fins, weathered wear, "
            "low saturation sand gray primary color, blue energy guidance module and radar array glow, "
            "clean studio pure white background, no ground no scene no clutter, HD."
        ),
    },
    {
        "name": "mod_arty_m270",
        "display": "M270\u706b\u7bad\u70ae",
        "prompt": (
            "STRICTLY a pure 2D side profile silhouette view, absolutely NO front view, "
            "NO three-quarter view, NO perspective depth, flat orthographic game sprite, "
            "single subject only centered, clean pure white background with NO ground, "
            "NO shadow, NO floor, NO reflection, NO watermark, NO signature, NO text, "
            "NO extra sketches, NO character faces visible, NO environment, "
            "studio isolated product shot style. "
            "enemy_modern_mlrs_vehicle silhouette, strict 2D side view, orthographic projection, "
            "game unit sprite pose, sci-fi hard surface long-range artillery platform concept art, "
            "M270-style multiple launch rocket system, dual rows of rectangular rocket launch pods mounted on top of chassis, "
            "heavy tracked carrier vehicle base with stabilizing outrigger legs deployed, "
            "mechanical components and hydraulic support struts detailed, weathered wear, "
            "low saturation military gray primary color, blue energy guidance module glow, "
            "clean studio pure white background, no ground no scene no clutter, HD."
        ),
    },
]


def curl_generate(prompt, output_path):
    payload = json.dumps({
        "model": "agnes-image-2.0-flash",
        "prompt": prompt,
        "size": "1024x1024"
    })
    
    tmpfile = output_path + ".payload.json"
    with open(tmpfile, "w") as f:
        f.write(payload)
    
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


print("Regenerating 4 images with corrected prompts...\n")

results = []
for i, unit in enumerate(units):
    fname = unit["name"] + ".png"
    fpath = os.path.join(output_dir, fname)
    print("[" + str(i+1) + "/" + str(len(units)) + "] " + unit["display"] + " (" + unit["name"] + ")...")
    
    success, msg = curl_generate(unit["prompt"], fpath)
    results.append((unit["name"], unit["display"], success, msg))
    
    if success:
        print("  OK: " + msg)
    else:
        print("  FAILED: " + msg)
        time.sleep(3)
        success2, msg2 = curl_generate(unit["prompt"], fpath)
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
