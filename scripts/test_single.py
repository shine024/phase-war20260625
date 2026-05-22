# -*- coding: utf-8 -*-
"""Test single image generation"""
import subprocess, json, sys, os, time, urllib.request

SCRIPT = r"F:\Program Files (x86)\WorkBuddy\resources\app\extensions\genie\out\extension\builtin\buddy-multimodal-generation\scripts\buddy-cloud.py"
TOKEN = "tk_0WnDqe2sNuuQvwYg78Lfu6vePXADe2r6"

prompt = "Flat design card frame border template, no fill, transparent background, subtle inner border line, color blue #66A6FF, sharp clean edges, center empty for card art, 512x512 PNG"
cmd = [sys.executable, SCRIPT, "image", prompt, "--token", TOKEN, "--poll-interval", "8", "--max-poll-time", "600"]

print("Submitting request...", flush=True)
proc = subprocess.run(cmd, capture_output=True, encoding="utf-8", errors="replace")
print(f"Return code: {proc.returncode}", flush=True)
print(f"Stdout: {proc.stdout[:300]}", flush=True)

data = json.loads(proc.stdout) if proc.stdout.strip() else {}
if "result_url" in data:
    url = data["result_url"]
    if isinstance(url, list):
        url = url[0]
    out = r"f:\godot fair duel\phase-war\assets\cards\frames\rare_test.png"
    urllib.request.urlretrieve(url, out)
    size = os.path.getsize(out)
    print(f"Downloaded rare_test.png: {size:,} B", flush=True)
else:
    print(f"API Error: {data}", flush=True)
