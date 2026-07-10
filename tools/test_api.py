import subprocess
import os
import json

config_path = os.path.expanduser("~/.hermes/config.yaml")
with open(config_path, "rb") as f:
    raw = f.read()
key_start = raw.find(b"sk-thp")
full_key = raw[key_start:key_start+60].split(b"\n")[0].strip().decode()

prompt = "STRICTLY a pure 2D side profile silhouette view, flat orthographic game sprite, single subject only centered, clean pure white background. enemy_ww2_infantry bazooka soldier silhouette."

payload = json.dumps({
    "model": "agnes-image-2.0-flash",
    "prompt": prompt,
    "size": "1024x1024"
})

tmpfile = "/tmp/test_simple.json"
with open(tmpfile, "w") as f:
    f.write(payload)

# Build auth header using chr() to avoid *** corruption
auth_header = "Authorization: Bearer " + "".join([chr(c) for c in full_key.encode()])

resp_file = "/tmp/test_resp.json"
cmd = [
    "curl", "--http1.1", "-s",
    "-X", "POST", "https://apihub.agnes-ai.com/v1/images/generations",
    "-H", auth_header,
    "-H", "Content-Type: application/json",
    "--data-binary", "@" + tmpfile,
    "-o", resp_file,
]
result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
print("Return code:", result.returncode)
if os.path.exists(resp_file):
    content = open(resp_file).read()
    print("Response size:", len(content))
    print("Response preview:", content[:500])
    try:
        data = json.loads(content)
        print("Has 'data' key:", "data" in data)
        if "data" in data:
            print("Data length:", len(data["data"]))
            if len(data["data"]) > 0:
                print("First item keys:", list(data["data"][0].keys()))
                print("URL:", data["data"][0].get("url", "NONE"))
    except Exception as e:
        print("Not valid JSON:", e)
else:
    print("No response file")
