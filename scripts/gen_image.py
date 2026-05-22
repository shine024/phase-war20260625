# -*- coding: utf-8 -*-
"""
Generate image via buddy-cloud.py, extract result_url, download to dest.
All logging goes to stderr so stdout is clean for JSON parsing.
Usage: python gen_image.py "prompt" "output.png" [--token TOKEN]
Handles rate-limit (retry), timeout, and download failures.
"""
import subprocess
import json
import sys
import os
import re
import urllib.request
import urllib.error
import time

SCRIPT = r"F:\Program Files (x86)\WorkBuddy\resources\app\extensions\genie\out\extension\builtin\buddy-multimodal-generation\scripts\buddy-cloud.py"

def win_path(p: str) -> str:
    r"""Convert git-bash-style /f/... paths to Windows F:\... paths."""
    m = re.match(r"/([a-z])/(.*)", p)
    if m:
        p = f"{m.group(1).upper()}:\\{m.group(2)}"
    return p.replace("/", "\\")

def run_buddy(prompt: str, token: str) -> dict:
    cmd = [
        sys.executable, SCRIPT, "image", prompt,
        "--token", token,
        "--poll-interval", "8",
        "--max-poll-time", "600",
    ]
    proc = subprocess.run(cmd, capture_output=True, encoding="utf-8", errors="replace")
    try:
        return json.loads(proc.stdout) if proc.stdout.strip() else {}
    except json.JSONDecodeError:
        # Parse stderr for error info
        return {"error": "PARSE_FAILED", "raw": proc.stdout[:500]}

def download(url: str, dest: str, retries: int = 3) -> bool:
    dest_win = win_path(dest)
    os.makedirs(os.path.dirname(dest_win), exist_ok=True)
    for attempt in range(retries):
        try:
            urllib.request.urlretrieve(url, dest_win)
            size = os.path.getsize(dest_win)
            print(f"[OK] {os.path.basename(dest_win)} {size:,} B", file=sys.stderr, flush=True)
            return True
        except Exception as e:
            print(f"[WARN] DL attempt {attempt+1} failed: {e}", file=sys.stderr, flush=True)
            if attempt < retries - 1:
                time.sleep(3)
    return False

def gen_and_download(prompt: str, output_path: str, token: str) -> bool:
    print(f"[GEN] {os.path.basename(win_path(output_path))} ...", file=sys.stderr, flush=True)

    for attempt in range(5):
        result = run_buddy(prompt, token)

        if "result_url" in result:
            url = result["result_url"]
            if isinstance(url, list):
                url = url[0]
            return download(url, output_path)

        msg = result.get("message", "")
        if "上限" in msg or "limit" in msg.lower() or "quota" in msg.lower():
            wait = (attempt + 1) * 20
            print(f"[RATE] Limit hit, waiting {wait}s...", file=sys.stderr, flush=True)
            time.sleep(wait)
            continue

        if "error" in result:
            print(json.dumps(result), file=sys.stderr, flush=True)
            return False

        print(f"[WARN] Unexpected response: {str(result)[:200]}", file=sys.stderr, flush=True)
        time.sleep(5)

    print("[ERR] Max retries exceeded", file=sys.stderr, flush=True)
    return False

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: gen_image.py \"prompt\" \"output.png\"", file=sys.stderr)
        sys.exit(1)
    prompt = sys.argv[1]
    output = sys.argv[2]
    token = os.environ.get("BUDDY_CLOUD_TOKEN", "tk_0WnDqe2sNuuQvwYg78Lfu6vePXADe2r6")
    if not os.environ.get("BUDDY_CLOUD_TOKEN"):
        print("[WARN] Using hardcoded token (may be expired). Set BUDDY_CLOUD_TOKEN env var for fresh token.", file=sys.stderr)
    ok = gen_and_download(prompt, output, token)
    sys.exit(0 if ok else 1)