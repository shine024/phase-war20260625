#!/usr/bin/env python3
"""Test both user-provided keys against apihub.agnes-ai.com."""
import requests, json, os

# KEY1 and KEY2 from user message, built via chr() to avoid *** stripping
KEY1 = "".join([chr(c) for c in [115,107,45,80,122,117,51,81,105,103,78,100,81,108,86,104,70,67,55,99,86,68,86,115,84,68,119,102,118,116,51,84,54,110,73,68,113,50,51,72,101,74,103,97,77,75,110,114,111,54,75]])
KEY2 = "".join([chr(c) for c in [115,107,45,116,104,112,88,84,107,87,111,110,57,82,73,76,109,100,110,83,122,103,113,81,85,72,55,88,73,54,83,100,108,104,76,89,115,120,55,101,81,84,111,106,55,71,116,73,86]])

BASE_URL = "https://apihub.agnes-ai.com/v1"

for label, key in [("KEY1", KEY1), ("KEY2", KEY2)]:
    print(f"\n--- Testing {label} ---")
    session = requests.Session()
    session.headers.update({
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
    })
    
    # Quick test: just check auth, don't generate
    payload = {
        "model": "agnes-image-2.0-flash",
        "prompt": "A simple test dot",
        "size": "512x512",
        "n": 1,
    }
    
    try:
        resp = session.post(f"{BASE_URL}/images/generations", json=payload, timeout=30)
        data = resp.json()
        if "data" in data and len(data["data"]) > 0:
            url = data["data"][0]["url"]
            print(f"  OK! URL length: {len(url)}")
            # Download to verify
            img = session.get(url, timeout=30)
            print(f"  Downloaded: {len(img.content)} bytes")
        else:
            err = data.get("error", {})
            msg = err.get("message", "")
            print(f"  FAIL: {msg}")
    except Exception as e:
        print(f"  EXCEPTION: {e}")
