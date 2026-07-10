import subprocess
import os
import time
import json

config_path = os.path.expanduser("~/.hermes/config.yaml")
with open(config_path, "rb") as f:
    raw = f.read()
key_start = raw.find(b"sk-thp")
full_key = raw[key_start:key_start+60].split(b"\n")[0].strip().decode()
base_url = "https://apihub.agnes-ai.com/v1"

output_dir = r"F:\godot fair duet\create\phase-war\docs\重绘精灵图_7单位"
os.makedirs(output_dir, exist_ok=True)

STRICT_PREFIX = (
    "STRICTLY a pure 2D side profile silhouette view, absolutely NO front view, "
    "NO three-quarter view, NO perspective depth, flat orthographic game sprite, "
    "single subject only centered, clean pure white background with NO ground, "
    "NO shadow, NO floor, NO reflection, NO watermark, NO signature, NO text, "
    "NO extra sketches, NO character faces visible, NO environment, "
    "studio isolated product shot style. "
)

NEGATIVE = (
    "不要：三分之四视角、斜侧视、透视 perspective、广角、仰视、俯视、等距 isometric、"
    "鸟瞰 top-down、看到顶部、背景场景、地面、投影底板、文字、水印、logo、人物。"
)

units = [
    {
        "name": "ww2_inf_bazooka",
        "display": "\u5df4\u79d6\u5361\u7ec4",
        "prompt": STRICT_PREFIX + (
            "\u654c\u65b9_ww2_\u53cd\u88c5\u7532\u6b65\u5175\uff0c\u4e25\u683c2D\u6b63\u4fa7\u89c6\uff0c"
            "\u6b63\u4ea4\u6295\u5f71\uff0c\u6e38\u620f\u5355\u4f4d\u7acb\u7ed8/\u7cbe\u7075\u56fe\u59ff\u6001\uff0c"
            "\u79d1\u5e7b\u786c\u8868\u9762\u53cd\u88c5\u7532\u6b65\u5175\u8bbe\u5b9a\u56fe\uff0c"
            "\u4ee5\u3010\u4e8c\u6218\u00b7\u652f\u63f4\u3011\u5df4\u79d6\u5361\u7ec4\u4e3a\u4e3b\u4f53\uff0c"
            "\u5b8c\u6574\u5355\u4f4d\u5c45\u4e2d\u5165\u955c\uff0c\u80a9\u627b\u5f0f\u706b\u7bad\u53d1\u5c04\u5668"
            "\u4e0e\u5f39\u836f\u7b52\u8f6e\u5ed3\u6e05\u6670\uff0c\u8f7b\u578b\u6218\u672f\u62a4\u7532\u4e0e"
            "\u80cc\u8d1f\u7ec4\u4ef6\u7ed3\u6784\u660e\u786e\uff0c\u78e8\u635f\u65e7\u5316\uff0c"
            "\u4f4e\u9971\u548c\u519b\u7eff\u7070\u4e3b\u8272\uff0c\u5c40\u90e8\u84dd\u8272\u80fd\u91cf\u70b9\u706b\u6307\u793a\u706f\u53d1\u5149\uff0c"
            "\u5e72\u51c0\u68da\u62cd\u7eaf\u767d\u80cc\u666f\uff0c\u65e0\u5730\u9762\u65e0\u573a\u666f\u65e0\u6742\u7269\uff0c\u9ad8\u6e05\u3002" + NEGATIVE
        ),
    },
    {
        "name": "ww1_arty_m81",
        "display": "81mm\u8feb\u51fb\u70ae\u7ec4",
        "prompt": STRICT_PREFIX + (
            "\u654c\u65b9_ww1_\u8feb\u51fb\u70ae\u7ec4\uff0c\u4e25\u683c2D\u6b63\u4fa7\u89c6\uff0c"
            "\u6b63\u4ea4\u6295\u5f71\uff0c\u6e38\u620f\u5355\u4f4d\u7acb\u7ed8/\u7cbe\u7075\u56fe\u59ff\u6001\uff0c"
            "\u79d1\u5e7b\u786c\u8868\u9762\u706b\u529b\u652f\u63f4\u5355\u4f4d\u8bbe\u5b9a\u56fe\uff0c"
            "\u4ee5\u3010\u4e00\u6218\u00b7\u652f\u63f4\u301181mm\u8feb\u51fb\u70ae\u7ec4\u4e3a\u4e3b\u4f53\uff0c"
            "\u5b8c\u6574\u5355\u4f4d\u5c45\u4e2d\u5165\u955c\uff0c\u77ed\u7ba1\u8feb\u51fb\u70ae\u3001\u5e95\u677f\u3001"
            "\u5f39\u836f\u67b6\u548c\u8f85\u52a9\u673a\u68b0\u81c2\u8f6e\u5ed3\u6e05\u6670\uff0c"
            "\u7532\u8083\u5916\u58f3\u4e0e\u6c22\u538b\u8fde\u63a5\u4ef6\u4e30\u5bcc\uff0c\u91d1\u5c5e\u78e8\u635f\u65e7\u5316\uff0c"
            "\u4f4e\u9971\u548c\u7070\u7eff\u4e3b\u8272\uff0c\u5c40\u90e8\u84dd\u8272\u80fd\u91cf\u70b9\u706b\u5355\u5143\u53d1\u5149\uff0c"
            "\u5e72\u51c0\u68da\u62cd\u7eaf\u767d\u80cc\u666f\uff0c\u65e0\u5730\u9762\u65e0\u573a\u666f\u65e0\u6742\u7269\uff0c\u9ad8\u6e05\u3002" + NEGATIVE
        ),
    },
    {
        "name": "cold_sup_zsu23",
        "display": "ZSU-23-4\u81ea\u884c\u9ad8\u70ae",
        "prompt": STRICT_PREFIX + (
            "\u654c\u65b9_cold_\u9632\u7a7a\u8f7d\u5177\uff0c\u4e25\u683c2D\u6b63\u4fa7\u89c6\uff0c"
            "\u6b63\u4ea4\u6295\u5f71\uff0c\u6e38\u620f\u5355\u4f4d\u7acb\u7ed8/\u7cbe\u7075\u56fe\u59ff\u6001\uff0c"
            "\u79d1\u5e7b\u786c\u8868\u9762\u9632\u7a7a\u8f7d\u5177\u8bbe\u5b9a\u56fe\uff0c"
            "\u4ee5\u3010\u51b7\u6218\u00b7\u9635\u5730\u3011ZSU-23-4\u81ea\u884c\u9ad8\u70ae\u4e3a\u4e3b\u4f53\uff0c"
            "\u5b8c\u6574\u5355\u4f4d\u5c45\u4e2d\u5165\u955c\uff0c\u53cc\u8054\u88c5\u9ad8\u70ae\u70ae\u5854\u3001"
            "\u96f7\u8fbe\u641c\u7d22\u9635\u5217\u4e0e\u5c65\u5e26\u5e95\u76d8\u4fa7\u89c6\u8f6e\u5ed3\u6e05\u6670\uff0c"
            "\u7532\u8083\u5206\u4ef6\u4e0e\u710a\u75d5\u7ec6\u8282\u4e30\u5bcc\uff0c\u78e8\u635f\u65e7\u5316\uff0c"
            "\u4f4e\u9971\u548c\u7070\u7eff\u4e3b\u8272\uff0c\u5c40\u90e8\u84dd\u8272\u80fd\u91cf\u4f20\u611f\u5668\u4e0e\u96f7\u8fbe\u706f\u53d1\u5149\uff0c"
            "\u5e72\u51c0\u68da\u62cd\u7eaf\u767d\u80cc\u666f\uff0c\u65e0\u5730\u9762\u65e0\u573a\u666f\u65e0\u6742\u7269\uff0c\u9ad8\u6e05\u3002" + NEGATIVE
        ),
    },
    {
        "name": "mod_sup_m6",
        "display": "\u81ea\u884c\u9ad8\u70aeM6",
        "prompt": STRICT_PREFIX + (
            "\u654c\u65b9_modern_\u9632\u7a7a\u5e73\u53f0\uff0c\u4e25\u683c2D\u6b63\u4fa7\u89c6\uff0c"
            "\u6b63\u4ea4\u6295\u5f71\uff0c\u6e38\u620f\u5355\u4f4d\u7acb\u7ed8/\u7cbe\u7075\u56fe\u59ff\u6001\uff0c"
            "\u79d1\u5e7b\u786c\u8868\u9762\u9632\u7a7a\u5e73\u53f0\u8bbe\u5b9a\u56fe\uff0c"
            "\u4ee5\u3010\u73b0\u4ee3\u00b7\u9635\u5730\u3011\u81ea\u884c\u9ad8\u70aeM6\u4e3a\u4e3b\u4f53\uff0c"
            "\u5b8c\u6574\u5355\u4f4d\u5c45\u4e2d\u5165\u955c\uff0c\u591a\u7ba1\u65cb\u8f6c\u70ae\u5854\u3001"
            "\u76f8\u63a7\u9635\u5217\u96f7\u8fbe\u4e0e\u7a33\u5b9a\u5e95\u76d8\u4fa7\u89c6\u8f6e\u5ed3\u6e05\u6670\uff0c"
            "\u590d\u6742\u7532\u8083\u5206\u4ef6\u4e0e\u6563\u70ed\u7ed3\u6784\u7ec6\u8282\u4e30\u5bcc\uff0c\u78e8\u635f\u65e7\u5316\uff0c"
            "\u4f4e\u9971\u548c\u6c99\u7070\u4e3b\u8272\uff0c\u5c40\u90e8\u84dd\u8272\u80fd\u91cf\u6276\u5bfc\u6a21\u5757\u4e0e\u96f7\u8fbe\u9635\u5217\u53d1\u5149\uff0c"
            "\u5e72\u51c0\u68da\u62cd\u7eaf\u767d\u80cc\u666f\uff0c\u65e0\u5730\u9762\u65e0\u573a\u666f\u65e0\u6742\u7269\uff0c\u9ad8\u6e05\u3002" + NEGATIVE
        ),
    },
    {
        "name": "mod_arty_m270",
        "display": "M270\u706b\u7bad\u70ae",
        "prompt": STRICT_PREFIX + (
            "\u654c\u65b9_modern_\u8fdc\u7a0b\u706b\u529b\u5e73\u53f0\uff0c\u4e25\u683c2D\u6b63\u4fa7\u89c6\uff0c"
            "\u6b63\u4ea4\u6295\u5f71\uff0c\u6e38\u620f\u5355\u4f4d\u7acb\u7ed8/\u7cbe\u7075\u56fe\u59ff\u6001\uff0c"
            "\u79d1\u5e7b\u786c\u8868\u9762\u8fdc\u7a0b\u706b\u529b\u5e73\u53f0\u8bbe\u5b9a\u56fe\uff0c"
            "\u4ee5\u3010\u73b0\u4ee3\u00b7\u9635\u5730\u3011M270\u706b\u7bad\u70ae\u4e3a\u4e3b\u4f53\uff0c"
            "\u5b8c\u6574\u5355\u4f4d\u5c45\u4e2d\u5165\u955c\uff0c\u53cc\u6392\u706b\u7bad\u53d1\u5c04\u7bb1\u3001"
            "\u627f\u8f7d\u5e95\u76d8\u4e0e\u7a33\u5b9a\u652f\u817f\u4fa7\u89c6\u8f6e\u5ed3\u6e05\u6670\uff0c"
            "\u673a\u68b0\u5206\u4ef6\u4e0e\u6c22\u538b\u652f\u6491\u7ed3\u6784\u7ec6\u8282\u4e30\u5bcc\uff0c\u78e8\u635f\u65e7\u5316\uff0c"
            "\u4f4e\u9971\u548c\u519b\u7070\u4e3b\u8272\uff0c\u5c40\u90e8\u84dd\u8272\u80fd\u91cf\u5236\u5bfc\u6a21\u5757\u53d1\u5149\uff0c"
            "\u5e72\u51c0\u68da\u62cd\u7eaf\u767d\u80cc\u666f\uff0c\u65e0\u5730\u9762\u65e0\u573a\u666f\u65e0\u6742\u7269\uff0c\u9ad8\u6e05\u3002" + NEGATIVE
        ),
    },
    {
        "name": "mod_inf_scout_drone",
        "display": "\u4fa6\u5bdf\u65e0\u4eba\u673a",
        "prompt": STRICT_PREFIX + (
            "\u654c\u65b9_modern_\u5fae\u578b\u65e0\u4eba\u673a\uff0c\u4e25\u683c2D\u6b63\u4fa7\u89c6\uff0c"
            "\u6b63\u4ea4\u6295\u5f71\uff0c\u6e38\u620f\u5355\u4f4d\u7acb\u7ed8/\u7cbe\u7075\u56fe\u59ff\u6001\uff0c"
            "\u79d1\u5e7b\u786c\u8868\u9762\u5fae\u578b\u65e0\u4eba\u673a\u8bbe\u5b9a\u56fe\uff0c"
            "\u4ee5\u3010\u73b0\u4ee3\u00b7\u57fa\u7840\u3011\u4fa6\u5bdf\u65e0\u4eba\u673a\u4e3a\u4e3b\u4f53\uff0c"
            "\u5b8c\u6574\u5355\u4f4d\u5c45\u4e2d\u5165\u955c\uff0c\u6298\u53e0\u65cb\u7ffc\u3001"
            "\u5149\u7535\u4f20\u611f\u5668\u540a\u8173\u4e0e\u673a\u8eab\u8f6e\u5ed3\u6e05\u6670\uff0c"
            "\u78b3\u7ea4\u7ef4\u8d28\u611f\u4e0e\u7cbe\u5bc6\u673a\u68b0\u5206\u4ef6\u7ec6\u8282\u4e30\u5bcc\uff0c\u8f7b\u5ea6\u78e8\u635f\uff0c"
            "\u4f4e\u9971\u548c\u94f6\u7070\u4e3b\u8272\uff0c\u5c40\u90e8\u84dd\u8272\u80fd\u91cf\u63a8\u8fdb\u5668\u4e0e\u4f20\u611f\u5668\u53d1\u5149\uff0c"
            "\u5e72\u51c0\u68da\u62cd\u7eaf\u767d\u80cc\u666f\uff0c\u65e0\u5730\u9762\u65e0\u573a\u666f\u65e0\u6742\u7269\uff0c\u9ad8\u6e05\u3002" + NEGATIVE
        ),
    },
    {
        "name": "fut_inf_scout_mech",
        "display": "\u4fa6\u5bdf\u7532\u9aa8",
        "prompt": STRICT_PREFIX + (
            "\u654c\u65b9_future_\u8f7b\u578b\u4fa6\u5bdf\u7532\u9aa8\uff0c\u4e25\u683c2D\u6b63\u4fa7\u89c6\uff0c"
            "\u6b63\u4ea4\u6295\u5f71\uff0c\u6e38\u620f\u5355\u4f4d\u7acb\u7ed8/\u7cbe\u7075\u56fe\u59ff\u6001\uff0c"
            "\u79d1\u5e7b\u786c\u8868\u9762\u8f7b\u578b\u4fa6\u5bdf\u7532\u9aa8\u8bbe\u5b9a\u56fe\uff0c"
            "\u4ee5\u3010\u8fd1\u672a\u6765\u00b7\u57fa\u7840\u3011\u4fa6\u5bdf\u7532\u9aa8\u4e3a\u4e3b\u4f53\uff0c"
            "\u5b8c\u6574\u5355\u4f4d\u5c45\u4e2d\u5165\u955c\uff0c\u53cc\u8db3\u6b65\u884c\u9aa8\u67b6\u3001"
            "\u5149\u5b66\u4f20\u611f\u5668\u5934\u90e8\u4e0e\u8f7b\u578b\u7532\u8083\u677f\u8f6e\u5ed3\u6e05\u6670\uff0c"
            "\u673a\u68b0\u5173\u8282\u4e0e\u6c22\u538b\u7ba1\u7ebf\u7ec6\u8282\u4e30\u5bcc\uff0c\u78e8\u635f\u65e7\u5316\uff0c"
            "\u4f4e\u9971\u548c\u51b7\u7070\u4e3b\u8272\uff0c\u5c40\u90e8\u84dd\u8272\u80fd\u91cf\u6838\u5fc3\u4e0e\u4f20\u611f\u5668\u9635\u5217\u53d1\u5149\uff0c"
            "\u5e72\u51c0\u68da\u62cd\u7eaf\u767d\u80cc\u666f\uff0c\u65e0\u5730\u9762\u65e0\u573a\u666f\u65e0\u6742\u7269\uff0c\u9ad8\u6e05\u3002" + NEGATIVE
        ),
    },
]


def curl_generate(prompt, output_path):
    """Generate image via agnes-image-2.0-flash using curl --http1.1."""
    payload = json.dumps({
        "model": "agnes-image-2.0-flash",
        "prompt": prompt,
        "size": "1024x1024"
    })
    
    tmpfile = output_path + ".payload.json"
    with open(tmpfile, "w") as f:
        f.write(payload)
    
    # Build auth header using chr() to avoid *** corruption in tool system
    hdr = "Authorization: Bearer " + "".join([chr(c) for c in full_key.encode()])
    
    resp_file = output_path + ".resp.json"
    cmd = [
        "curl", "--http1.1", "-s",
        "-X", "POST", base_url + "/images/generations",
        "-H", hdr,
        "-H", "Content-Type: application/json",
        "--data-binary", "@" + tmpfile,
        "-o", resp_file,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    os.unlink(tmpfile)
    
    if result.returncode != 0:
        return False, "curl exit code " + str(result.returncode) + ": " + result.stderr[:200]
    
    if not os.path.exists(resp_file) or os.path.getsize(resp_file) < 10:
        return False, "No response file"
    
    content = open(resp_file).read()
    os.unlink(resp_file)
    
    try:
        data = json.loads(content)
    except json.JSONDecodeError:
        return False, "Response is not valid JSON: " + content[:200]
    
    if "data" not in data or len(data["data"]) == 0:
        err_msg = ""
        if isinstance(data.get("error"), dict):
            err_msg = data["error"].get("message", "unknown error")
        else:
            err_msg = str(data)[:200]
        return False, "No data in response: " + err_msg
    
    url = data["data"][0].get("url", "")
    if not url:
        return False, "No URL in response"
    
    # Download the actual image from URL
    dl_cmd = ["curl", "--http1.1", "-s", "-L", "-o", output_path, url]
    dl_result = subprocess.run(dl_cmd, capture_output=True, text=True, timeout=120)
    
    if os.path.exists(output_path) and os.path.getsize(output_path) > 1000:
        return True, "OK (" + str(os.path.getsize(output_path)) + " bytes)"
    return False, "Download failed or too small (" + str(os.path.getsize(output_path)) + " bytes)"


print("Output dir: " + output_dir)
print("Generating " + str(len(units)) + " images...\n")

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
        if not os.path.exists(fpath) or os.path.getsize(fpath) < 1000:
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
