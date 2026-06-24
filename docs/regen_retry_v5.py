#!/usr/bin/env python3
import requests, os, sys, time, re

with open(r'C:\Users\jianchang.tan\.hermes\config.yaml', 'rb') as f:
    raw = f.read()
idx = raw.find(b'sk-thp')
API_KEY = raw[idx:].split(b'\n')[0].decode().split(': ')[-1].strip()
BASE_URL = "https://apihub.agnes-ai.com/v1"
MODEL = "agnes-image-2.0-flash"
TARGET_DIR = r"F:\godot fair duet\create\phase-war\assets\card_icons\补充1"
PROMPT_FILE = r"F:\godot fair duet\create\phase-war\docs\精灵图nano_banana2_enemy_prompts_36.md"
FAILED_NAMES = ["enemy_ww1_mortar", "boss_cold_mig", "enemy_future_mech"]

def parse_prompt(name):
    with open(PROMPT_FILE, "r", encoding="utf-8") as f:
        content = f.read()
    for block in re.findall(r"`([^`]+)`", content):
        if block.startswith(name + "(") or block.startswith(name + "\uff08"):
            return block
    return None

def gen(name, prompt):
    fp = os.path.join(TARGET_DIR, name + ".png")
    for att in range(3):
        try:
            r = requests.post(BASE_URL+"/images/generations",
                headers={"Authorization": "Bearer "+API_KEY, "Content-Type": "application/json"},
                json={"model": MODEL, "prompt": prompt, "n": 1, "size": "1024x1024"}, timeout=120)
            if r.status_code != 200:
                time.sleep(5); continue
            d = r.json()
            if not d.get("data"):
                time.sleep(5); continue
            item = d["data"][0]
            url = item.get("url")
            if url:
                img = requests.get(url, timeout=60).content
                with open(fp, "wb") as f: f.write(img)
                return True, os.path.getsize(fp)
            elif item.get("b64_json"):
                with open(fp, "wb") as f: f.write(bytes.fromhex(item["b64_json"]))
                return True, os.path.getsize(fp)
        except Exception as e:
            print("    err att"+str(att+1)+": "+str(e)[:60])
            time.sleep(5)
    return False, 0

def main():
    print("Retrying "+str(len(FAILED_NAMES))+" failed items...")
    ok = fail = 0
    for name in FAILED_NAMES:
        prompt = parse_prompt(name)
        if not prompt:
            print("  SKIP: no prompt for "+name); fail+=1; continue
        print("  Gen "+name+"...")
        s, sz = gen(name, prompt)
        if s:
            print("  OK "+name+" ("+str(sz)+" bytes)"); ok+=1
        else:
            print("  FAIL "+name); fail+=1
        time.sleep(3)
    print("Retry: OK "+str(ok)+", Failed "+str(fail))
    return fail

if __name__ == "__main__":
    sys.exit(main())
