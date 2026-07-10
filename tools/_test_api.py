import urllib.request, json

API_KEY = "thpXTkWon9RiLMdnsZgqlQUH7XI6SdlhLYsx7eQToj7GtIPv"
BASE_URL = "https://apihub.agnes-ai.com/v1"

payload = {
    "model": "agnes-image-2.0-flash",
    "prompt": "test",
    "size": "512x512",
    "n": 1,
}
headers = {
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json",
}

req = urllib.request.Request(
    f"{BASE_URL}/images/generations",
    data=json.dumps(payload).encode(),
    headers=headers,
    method="POST"
)

try:
    with urllib.request.urlopen(req, timeout=30) as resp:
        result = json.loads(resp.read())
    print(f"API test: SUCCESS - got {len(result.get('data', []))} images")
except Exception as e:
    print(f"API test: FAILED - {e}")
