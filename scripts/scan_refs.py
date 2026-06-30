#!/usr/bin/env python3
"""Accurate res:// reference scan"""
import subprocess, os, json, re

BASE = r"D:\godotplay\godot fair duel\phase-war"

script = '#!/bin/bash\ncd "' + BASE + '"\ngrep -roh \'res://[^"\'"\'",;\\s)\\]]*\' . --include="*.gd" --include="*.tscn" --include="*.tres" 2>/dev/null | grep -v \'addons/\' | sort -u > /tmp/phase_war_refs.txt\n'

with open('/tmp/scan_refs.sh', 'w') as f:
    f.write(script)

subprocess.run(['bash', '/tmp/scan_refs.sh'], capture_output=True)

with open('/tmp/phase_war_refs.txt', 'r') as f:
    raw_refs = [l.strip() for l in f if l.strip()]

print(f"Raw refs: {len(raw_refs)}")

valid_refs = set()
for ref in raw_refs:
    after = ref[6:]
    if '/' not in after:
        continue
    if not any(after.endswith(ext) for ext in ['.gd', '.tscn', '.tres', '.png', '.jpg', '.ogg', '.wav', '.mp3', '.ttf', '.uid', '.import']):
        continue
    if '%' in after or '{' in after or '...' in after:
        continue
    valid_refs.add(ref)

print(f"Valid refs: {len(valid_refs)}")

missing_refs = []
for ref in sorted(valid_refs):
    r = subprocess.run(
        ['bash', '-c', f'test -f "{BASE}/{ref}" && echo Y || echo N'],
        capture_output=True, text=True
    )
    if r.stdout.strip() == 'N':
        missing_refs.append(ref)

print(f"Missing: {len(missing_refs)}")
for m in missing_refs[:30]:
    print(f"  {m}")
