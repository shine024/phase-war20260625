#!/usr/bin/env python3
"""
Read the CSV and generate weapon name suffixes for all _unit() calls in default_cards.gd.
"""
import csv
import re

cards = []
with open(r"D:\godotplay\godot fair duel\phase-war\docs\战斗卡武器配置.csv", "r", encoding="utf-8-sig") as f:
    reader = csv.reader(f)
    header = next(reader)
    for row in reader:
        if not row[1]:
            continue
        cards.append({
            "id": row[1],
            "w_light": row[6] if row[6] else "",
            "w_armor": row[9] if row[9] else "",
            "w_air": row[12] if row[12] else "",
        })

lookup = {c["id"]: c for c in cards}

with open(r"D:\godotplay\godot fair duel\phase-war\data\default_cards.gd", "r", encoding="utf-8") as f:
    content = f.read()

count = 0
result = []
lines = content.split("\n")
for line in lines:
    if "_unit(" in line and "list.append" in line:
        m = re.search(r'_unit\("([^"]+)"', line)
        if m:
            card_id = m.group(1)
            info = lookup.get(card_id)
            if info:
                wl = info["w_light"]
                wa = info["w_armor"]
                wai = info["w_air"]
                line = re.sub(r',\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)\)',
                              lambda mm: f',{mm.group(1)},{mm.group(2)},{mm.group(3)}, "{wl}", "{wa}", "{wai}")', line)
                count += 1
    result.append(line)

new_content = "\n".join(result)

with open(r"D:\godotplay\godot fair duel\phase-war\data\default_cards.gd", "w", encoding="utf-8") as f:
    f.write(new_content)

print(f"Updated {count} _unit() calls in default_cards.gd")
