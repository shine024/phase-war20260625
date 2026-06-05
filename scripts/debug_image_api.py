"""
Debug agnes-image API error.
"""
import os, json, urllib.request

config = os.path.expanduser("~/.hermes/config.yaml")
api_key = ""
with open(config, "r") as f:
    for line in f:
        if "api_key:" in line and not line.strip().startswith("#"):
            api_key = line.strip().split("api_key:", 1)[1].strip()
            break

BASE_URL = "https://apihub.agnes-ai.com/v1/images/generations"

# Try different parameter formats
tests = [
    ("default", {
        "model": "agnes-image-2.0-flash",
        "prompt": "a test military tank",
        "image_size": "1024x1024",
        "n": 1,
        "response_format": "b64_json"
    }),
    ("no_n", {
        "model": "agnes-image-2.0-flash",
        "prompt": "a test military tank",
        "image_size": "1024x1024",
        "response_format": "b64_json"
    }),
    ("no_response_format", {
        "model": "agnes-image-2.0-flash",
        "prompt": "a test military tank",
        "image_size": "1024x1024"
    }),
    ("size_1024x1024 string", {
        "model": "agnes-image-2.0-flash",
        "prompt": "a test military tank",
        "size": "1024x1024",
        "response_format": "b64_json"
    }),
    ("agnes-image-2.1-flash", {
        "model": "agnes-image-2.1-flash",
        "prompt": "a test military tank",
        "image_size": "1024x1024",
        "response_format": "b64_json"
    }),
    ("minimal agnes-image-2.0", {
        "model": "agnes-image-2.0-flash",
        "prompt": "test"
    }),
]

for name, data in tests:
    headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
    req = urllib.request.Request(BASE_URL, data=json.dumps(data).encode("utf-8"), headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            result = json.loads(resp.read())
            print(f"  {name}: OK - {str(result)[:200]}")
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        print(f"  {name}: HTTP {e.code} - {body[:300]}")
    except Exception as e:
        print(f"  {name}: {e}")
