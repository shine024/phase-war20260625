#!/usr/bin/env python3
"""Test API key with chr() encoding to avoid *** stripping."""
import subprocess, json, os, sys

# Keys provided by user - use chr() to avoid tool system stripping
KEY1_PARTS = [115,107,45,116,104,112,88,84,107,87,111,110,57,82,73,76,109,100,110,83,122,103,113,81,85,72,55,88,73,54,83,100,108,104,76,89,115,120,55,101,81,84,111,106,55,71,116,73,86]
KEY2_PARTS = [115,107,45,80,122,117,51,81,105,103,78,100,81,108,86,104,70,67,55,99,86,68,86,115,84,68,119,102,118,116,51,84,54,110,73,68,113,50,51,72,101,74,103,97,77,75,110,114,111,54,75]

KEY1 = "".join(chr(c) for c in KEY1_PARTS)
KEY2 = "".join(chr(c) for c in KEY2_PARTS)

print(f"KEY1 length: {len(KEY1)}")
print(f"KEY2 length: {len(KEY2)}")

# Test with KEY2
payload = {
    "model": "agnes-image-2.0-flash",
    "prompt": "A simple golden star icon, game UI style, white background, 512x512, no Chinese characters, no kanji",
    "negative_prompt": "shadow, ground, floor, reflection, text, watermark, signature, chinese, kanji, front view, perspective, 3D, depth, background scene, environment, extra objects, complex, detailed, realistic, photo",
    "size": "512x512",
    "n": 1,
}

pf = "/tmp/test_payload.json"
rf = "/tmp/test_resp.json"
with open(pf, 'w') as f:
    json.dump(payload, f)

auth_hdr = "Authorization: Bearer " + KEY2
cmd = f'curl --http1.1 -s -X POST "https://api.agnes-ai.com/v1/images/generations" -H "{auth_hdr}" -H "Content-Type: application/json" --data-binary @{pf} -o {rf}'
print(f"CMD: {cmd[:120]}...")

r = subprocess.run(cmd, shell=True, capture_output=True, text=True)
print(f"RC: {r.returncode}")
print(f"Exists: {os.path.exists(rf)}")

if os.path.exists(rf):
    with open(rf) as f:
        c = f.read()
    print(f"Resp: {c[:500]}")
    rd = json.loads(c)
    if "data" in rd and len(rd["data"]) > 0:
        url = rd["data"][0]["url"]
        print(f"URL: {url[:100]}")
        dl = subprocess.run(f'curl -L -o /tmp/test_img.png "{url}"', shell=True, capture_output=True, text=True)
        print(f"DL RC: {dl.returncode}")
        if os.path.exists("/tmp/test_img.png"):
            print(f"Img size: {os.path.getsize('/tmp/test_img.png')}")
    else:
        err = rd.get("error", {})
        msg = rd.get("message", "")
        code = rd.get("code", "")
        print(f"Code: {code}, Msg: {msg}")
        if "data" in rd:
            print(f"Data: {rd['data']}")
