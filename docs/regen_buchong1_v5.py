#!/usr/bin/env python3
"""Regenerate all 36 enemy sprites from prompts file into 补充1/."""

import requests, os, sys, time, re

# Full API key (confirmed working by user)
API_KEY = "sk-thpXTkWon9RiLMdnsZgqlQUH7XI6SdlhLYsx7eQToj7GtIPv"
BASE_URL = "https://apihub.agnes-ai.com/v1"
MODEL = "agnes-image-2.0-flash"
TARGET_DIR = r"F:\godot fair duet\create\phase-war\assets\card_icons\补充1"
PROMPT_FILE = r"F:\godot fair duet\create\phase-war\docs\精灵图nano_banana2_enemy_prompts_36.md"

def parse_prompts():
    """Parse prompts from the markdown file."""
    with open(PROMPT_FILE, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Find all prompt blocks enclosed in backticks
    prompt_blocks = re.findall(r'`([^`]+)`', content)
    
    # Filter to only enemy prompts (start with enemy_/elite_/boss_)
    name_map = {}
    for block in prompt_blocks:
        if block.startswith(('enemy_', 'elite_', 'boss_')):
            match = re.match(r'(enemy_\w+|elite_\w+|boss_\w+)', block)
            if match:
                name_map[match.group(1)] = block
    
    return name_map

def generate_one(name, prompt):
    """Generate a single image."""
    filepath = os.path.join(TARGET_DIR, f"{name}.png")
    try:
        resp = requests.post(
            f"{BASE_URL}/images/generations",
            headers={"Authorization": f"Bearer {API_KEY}", "Content-Type": "application/json"},
            json={"model": MODEL, "prompt": prompt, "n": 1, "size": "1024x1024"},
            timeout=120
        )
        if resp.status_code != 200:
            return False, f"HTTP {resp.status_code}: {resp.text[:200]}"
        data = resp.json()
        if not data.get("data"):
            return False, f"No data: {data}"
        item = data["data"][0]
        url = item.get("url")
        if url:
            img_data = requests.get(url, timeout=60).content
            with open(filepath, "wb") as f:
                f.write(img_data)
            sz = os.path.getsize(filepath)
            return True, f"{os.path.basename(filepath)} ({sz:,} bytes)"
        elif item.get("b64_json"):
            with open(filepath, "wb") as f:
                f.write(bytes.fromhex(item["b64_json"]))
            sz = os.path.getsize(filepath)
            return True, f"{os.path.basename(filepath)} ({sz:,} bytes)"
        else:
            return False, "No url or b64_json"
    except Exception as e:
        return False, str(e)

def main():
    print(f"Parsing prompts from {PROMPT_FILE}...")
    name_map = parse_prompts()
    print(f"Found {len(name_map)} enemy prompts")
    
    # Clear old files
    if os.path.exists(TARGET_DIR):
        for f in os.listdir(TARGET_DIR):
            fp = os.path.join(TARGET_DIR, f)
            if os.path.isfile(fp) and f.endswith('.png'):
                os.remove(fp)
                imp = fp + '.import'
                if os.path.exists(imp):
                    os.remove(imp)
        print(f"Cleared {TARGET_DIR}")
    
    os.makedirs(TARGET_DIR, exist_ok=True)
    
    ok_count = 0
    fail_count = 0
    failed_names = []
    
    for i, (name, prompt) in enumerate(name_map.items(), 1):
        print(f"[{i}/{len(name_map)}] Generating {name}...")
        success, info = generate_one(name, prompt)
        if success:
            print(f"  OK {info}")
            ok_count += 1
        else:
            print(f"  FAIL {name}: {info}")
            fail_count += 1
            failed_names.append(name)
        time.sleep(3)
    
    print(f"\n补充1: Generated {ok_count}, Failed {fail_count}")
    if failed_names:
        print(f"Failed: {', '.join(failed_names)}")
    return fail_count

if __name__ == "__main__":
    sys.exit(main())
