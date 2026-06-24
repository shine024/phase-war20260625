#!/usr/bin/env python3
import requests, os, sys, time, re

API_KEY='sk-thpXTkWon9RiLMdnsZgqlQUH7XI6SdlhLYsx7eQToj7GtIPv'
BASE_URL = 'https://apihub.agnes-ai.com/v1'
MODEL = 'agnes-image-2.0-flash'
TARGET_DIR = r"F:\\godot fair duet\\create\\phase-war\\assets\\card_icons\\补充1"
PROMPT_FILE = r"F:\\godot fair duet\\create\\phase-war\\docs\\精灵图nano_banana2_enemy_prompts_36.md"

STRICT = (
    'STRICTLY a pure 2D side profile silhouette view, absolutely NO front view, '
    'NO three-quarter view, NO perspective depth, flat orthographic game sprite, '
    'single subject only centered, clean pure white background with NO ground, '
    'NO shadow, NO floor, NO reflection, NO watermark, NO signature, NO text, '
    'NO extra sketches, NO character faces visible, NO environment, '
    'studio isolated product shot style. '
)

def parse_prompts():
    with open(PROMPT_FILE, 'r', encoding='utf-8') as f:
        content = f.read()
    blocks = re.findall(r'`([^`]+)`', content)
    nm = {}
    for b in blocks:
        if b.startswith(('enemy_', 'elite_', 'boss_')):
            m = re.match(r'(enemy_\w+|elite_\w+|boss_\w+)', b)
            if m:
                nm[m.group(1)] = b
    return nm

def gen(name, prompt):
    fp = os.path.join(TARGET_DIR, name + '.png')
    full = STRICT + prompt
    for att in range(3):
        try:
            r = requests.post(BASE_URL+'/images/generations',
                headers={'Authorization': 'Bearer '+API_KEY, 'Content-Type': 'application/json'},
                json={'model': MODEL, 'prompt': full, 'n': 1, 'size': '1024x1024'}, timeout=120)
            if r.status_code != 200:
                time.sleep(5); continue
            d = r.json()
            if not d.get('data'):
                time.sleep(5); continue
            item = d['data'][0]
            url = item.get('url')
            if url:
                img = requests.get(url, timeout=60).content
                with open(fp, 'wb') as f: f.write(img)
                return True, os.path.getsize(fp)
            elif item.get('b64_json'):
                with open(fp, 'wb') as f: f.write(bytes.fromhex(item['b64_json']))
                return True, os.path.getsize(fp)
        except Exception as e:
            time.sleep(5)
    return False, 0

def main():
    nm = parse_prompts()
    print('Found '+str(len(nm))+' prompts')
    ok = fail = 0
    failed = []
    for i, (name, prompt) in enumerate(nm.items(), 1):
        print('['+str(i)+'/'+str(len(nm))+'] '+name+'...')
        s, sz = gen(name, prompt)
        if s:
            print('  OK ('+str(sz)+' bytes)')
            ok += 1
        else:
            print('  FAIL'); fail += 1; failed.append(name)
        time.sleep(3)
    print('\n补充1: Generated '+str(ok)+', Failed '+str(fail))
    if failed:
        print('Failed: '+', '.join(failed))
    return fail

if __name__ == '__main__':
    sys.exit(main())
