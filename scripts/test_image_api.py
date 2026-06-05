"""
Test agnes-ai API for image generation capabilities.
"""
import os, json, urllib.request

config = os.path.expanduser("~/.hermes/config.yaml")
api_key = ""
with open(config, "r") as f:
    for line in f:
        if "api_key:" in line and not line.strip().startswith("#"):
            api_key = line.strip().split("api_key:", 1)[1].strip()
            break

# Test 1: List available models
print("=== Test 1: Check available models ===")
models_url = "https://apihub.agnes-ai.com/v1/models"
models_req = urllib.request.Request(models_url, headers={"Authorization": f"Bearer {api_key}"})
try:
    with urllib.request.urlopen(models_req, timeout=30) as resp:
        data = json.loads(resp.read())
        models = data.get("data", [])
        print(f"Available models: {len(models)}")
        for m in models:
            print(f"  {m.get('id')}")
except Exception as e:
    print(f"Error: {e}")

# Test 2: Try image generation with different model names
print("\n=== Test 2: Image generation tests ===")
img_url = "https://apihub.agnes-ai.com/v1/images/generations"

for model_name in ["gpt-image-1", "dall-e-3", "dall-e-2", "flux-schnell", "flux-dev"]:
    data = {
        "model": model_name,
        "prompt": "a test image",
        "image_size": "1024x1024",
        "n": 1,
        "response_format": "url"
    }
    headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
    req = urllib.request.Request(img_url, data=json.dumps(data).encode("utf-8"), headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            result = json.loads(resp.read())
            print(f"  {model_name}: OK - {str(result)[:200]}")
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        print(f"  {model_name}: HTTP {e.code} - {body[:200]}")
    except Exception as e:
        print(f"  {model_name}: {e}")

# Test 3: Also try Zhipu API (OPENAI_API_KEY)
print("\n=== Test 3: Zhipu API image test ===")
env_file = os.path.expanduser("~/.hermes/.env")
zhipu_key = ""
with open(env_file, "r") as f:
    for line in f:
        if "OPENAI_API_KEY" in line:
            zhipu_key = line.split("=", 1)[1].strip().strip('"').strip("'")
            break

zhipu_url = "https://open.bigmodel.cn/api/paas/v4/images/generations"
data = {
    "model": "cogview-3",
    "prompt": "a test military tank icon on white background",
    "size": "1024x1024",
    "n": 1
}
headers = {"Authorization": f"Bearer {zhipu_key}", "Content-Type": "application/json"}
req = urllib.request.Request(zhipu_url, data=json.dumps(data).encode("utf-8"), headers=headers)
try:
    with urllib.request.urlopen(req, timeout=120) as resp:
        result = json.loads(resp.read())
        print(f"  Zhipu cogview-3: OK - {str(result)[:300]}")
except urllib.error.HTTPError as e:
    body = e.read().decode("utf-8", errors="replace")
    print(f"  Zhipu: HTTP {e.code} - {body[:300]}")
except Exception as e:
    print(f"  Zhipu: {e}")
