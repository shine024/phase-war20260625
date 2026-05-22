#!/usr/bin/env python3
"""Extract hardcoded data from GDScript const blocks into JSON files."""
import json
import re
import sys
import os

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_DIR = os.path.join(BASE, "data")
JSON_DIR = os.path.join(DATA_DIR, "json")
os.makedirs(JSON_DIR, exist_ok=True)


def extract_gdscript_const_dict(content: str, const_name: str) -> dict:
    """Extract a GDScript const Dictionary into a Python dict."""
    # Find const CONST_NAME[: Type] = { or := {
    pattern = rf'const\s+{const_name}\s*(?::\s*[\w\[\]]+)?\s*(?::=|=)\s*\{{'
    match = re.search(pattern, content)
    if not match:
        return {}
    start = match.end() - 1  # include the opening brace
    brace_count = 0
    i = start
    in_string = False
    string_char = None
    while i < len(content):
        c = content[i]
        if in_string:
            if c == '\\' and i + 1 < len(content):
                i += 2
                continue
            if c == string_char:
                in_string = False
        else:
            if c in ('"', "'"):
                in_string = True
                string_char = c
            elif c == '{':
                brace_count += 1
            elif c == '}':
                brace_count -= 1
                if brace_count == 0:
                    gdscript_str = content[start:i + 1]
                    return _parse_gd_dict(gdscript_str)
        i += 1
    return {}


def extract_gdscript_const_array(content: str, const_name: str) -> list:
    """Extract a GDScript const Array into a Python list."""
    pattern = rf'const\s+{const_name}\s*(?::\s*[\w\[\]]+)?\s*(?::=|=)\s*\['
    match = re.search(pattern, content)
    if not match:
        return []
    start = match.end() - 1  # include the opening bracket
    bracket_count = 0
    i = start
    in_string = False
    string_char = None
    while i < len(content):
        c = content[i]
        if in_string:
            if c == '\\' and i + 1 < len(content):
                i += 2
                continue
            if c == string_char:
                in_string = False
        else:
            if c in ('"', "'"):
                in_string = True
                string_char = c
            elif c == '[':
                bracket_count += 1
            elif c == ']':
                bracket_count -= 1
                if bracket_count == 0:
                    gdscript_str = content[start:i + 1]
                    return _parse_gd_array(gdscript_str)
        i += 1
    return []


def _parse_gd_dict(s: str) -> dict:
    """Parse GDScript dictionary literal to Python dict."""
    s = s.strip()
    if not s.startswith('{'):
        return {}
    inner = s[1:]
    result = {}
    depth = 0
    key = None
    in_string = False
    string_char = None
    i = 0
    while i < len(inner):
        c = inner[i]
        if in_string:
            if c == '\\' and i + 1 < len(inner):
                i += 2
                continue
            if c == string_char:
                in_string = False
            i += 1
            continue
        if c in ('"', "'"):
            # Try to read a full key: "key":
            if depth == 0 and key is None:
                end_q = inner.find(c, i + 1)
                if end_q > 0:
                    key = inner[i + 1:end_q]
                    # Skip to colon
                    colon_pos = inner.find(':', end_q + 1)
                    if colon_pos >= 0:
                        i = colon_pos + 1
                        # Skip whitespace
                        while i < len(inner) and inner[i] in ' \t\n\r':
                            i += 1
                        # Check what follows
                        if i < len(inner) and inner[i] == '{':
                            # Nested dict
                            brace_start = i
                            bd = 1
                            bc = i + 1
                            ns = False
                            nc = None
                            while bc < len(inner) and bd > 0:
                                cc = inner[bc]
                                if ns:
                                    if cc == '\\':
                                        bc += 2
                                        continue
                                    if cc == nc:
                                        ns = False
                                else:
                                    if cc in ('"', "'"):
                                        ns = True
                                        nc = cc
                                    elif cc == '{':
                                        bd += 1
                                    elif cc == '}':
                                        bd -= 1
                                bc += 1
                            result[key] = _parse_gd_dict(inner[brace_start:bc])
                            i = bc
                            key = None
                            continue
                        elif i < len(inner) and inner[i] == '[':
                            bracket_start = i
                            bd = 1
                            bc = i + 1
                            ns = False
                            nc = None
                            while bc < len(inner) and bd > 0:
                                cc = inner[bc]
                                if ns:
                                    if cc == '\\':
                                        bc += 2
                                        continue
                                    if cc == nc:
                                        ns = False
                                else:
                                    if cc in ('"', "'"):
                                        ns = True
                                        nc = cc
                                    elif cc == '[':
                                        bd += 1
                                    elif cc == ']':
                                        bd -= 1
                                bc += 1
                            result[key] = _parse_gd_array(inner[bracket_start:bc])
                            i = bc
                            key = None
                            continue
                        elif i < len(inner) and inner[i] == '"':
                            # String value
                            eq = inner.find('"', i + 1)
                            if eq > 0:
                                result[key] = inner[i + 1:eq]
                                i = eq + 1
                                key = None
                                continue
                        else:
                            # Number or identifier
                            match_val = re.match(r'([0-9eE.+\-]+|true|false)', inner[i:])
                            if match_val:
                                val_str = match_val.group(1)
                                if val_str == 'true':
                                    result[key] = True
                                elif val_str == 'false':
                                    result[key] = False
                                else:
                                    try:
                                        if '.' in val_str or 'e' in val_str or 'E' in val_str:
                                            result[key] = float(val_str)
                                        else:
                                            result[key] = int(val_str)
                                    except ValueError:
                                        result[key] = val_str
                                i += len(val_str)
                                key = None
                                continue
                    else:
                        i += 1
                    continue
        i += 1
    return result


def _parse_gd_array(s: str) -> list:
    """Parse GDScript array literal to Python list."""
    s = s.strip()
    if not s.startswith('['):
        return []
    inner = s[1:]
    result = []
    i = 0
    in_string = False
    string_char = None
    while i < len(inner):
        c = inner[i]
        if in_string:
            if c == '\\' and i + 1 < len(inner):
                i += 2
                continue
            if c == string_char:
                in_string = False
            i += 1
            continue
        if c in ('"', "'"):
            end_q = inner.find(c, i + 1)
            if end_q > 0:
                result.append(inner[i + 1:end_q])
                i = end_q + 1
                continue
        elif c == '{':
            brace_start = i
            bd = 1
            bc = i + 1
            ns = False
            nc = None
            while bc < len(inner) and bd > 0:
                cc = inner[bc]
                if ns:
                    if cc == '\\':
                        bc += 2
                        continue
                    if cc == nc:
                        ns = False
                else:
                    if cc in ('"', "'"):
                        ns = True
                        nc = cc
                    elif cc == '{':
                        bd += 1
                    elif cc == '}':
                        bd -= 1
                bc += 1
            result.append(_parse_gd_dict(inner[brace_start:bc]))
            i = bc
            continue
        elif c == '[':
            bracket_start = i
            bd = 1
            bc = i + 1
            ns = False
            nc = None
            while bc < len(inner) and bd > 0:
                cc = inner[bc]
                if ns:
                    if cc == '\\':
                        bc += 2
                        continue
                    if cc == nc:
                        ns = False
                else:
                    if cc in ('"', "'"):
                        ns = True
                        nc = cc
                    elif cc == '[':
                        bd += 1
                    elif cc == ']':
                        bd -= 1
                bc += 1
            result.append(_parse_gd_array(inner[bracket_start:bc]))
            i = bc
            continue
        elif c.isdigit() or c == '-':
            match_val = re.match(r'-?[0-9eE.]+', inner[i:])
            if match_val:
                val_str = match_val.group(1)
                try:
                    if '.' in val_str or 'e' in val_str or 'E' in val_str:
                        result.append(float(val_str))
                    else:
                        result.append(int(val_str))
                except ValueError:
                    pass
                i += len(val_str)
                continue
        i += 1
    return result


def write_json(data, filename):
    path = os.path.join(JSON_DIR, filename)
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent='\t')
    print(f"  Written: {path} ({os.path.getsize(path)} bytes)")


def main():
    # 1. enemy_phase_equipment.gd -> 4 dicts
    print("Processing enemy_phase_equipment.gd...")
    with open(os.path.join(DATA_DIR, "enemy_phase_equipment.gd"), 'r', encoding='utf-8') as f:
        eq_content = f.read()

    equipment_data = {}
    for const_name in ["PHASE_INSTRUMENTS", "WAR_PLATFORMS", "WAR_WEAPONS", "ENERGY_CARDS"]:
        print(f"  Extracting {const_name}...")
        data = extract_gdscript_const_dict(eq_content, const_name)
        equipment_data[const_name] = data
        print(f"    {len(data)} entries")

    write_json(equipment_data, "enemy_phase_equipment.json")

    # 2. achievement_definitions_extended.gd -> ACHIEVEMENTS dict
    print("Processing achievement_definitions_extended.gd...")
    with open(os.path.join(DATA_DIR, "achievement_definitions_extended.gd"), 'r', encoding='utf-8') as f:
        ach_content = f.read()

    ach_data = extract_gdscript_const_dict(ach_content, "ACHIEVEMENTS")
    print(f"  Extracted {len(ach_data)} achievements")
    write_json(ach_data, "achievement_definitions_extended.json")

    # 3. enemy_archetypes.gd -> ARCHETYPES dict
    print("Processing enemy_archetypes.gd...")
    with open(os.path.join(DATA_DIR, "enemy_archetypes.gd"), 'r', encoding='utf-8') as f:
        arch_content = f.read()

    arch_data = extract_gdscript_const_dict(arch_content, "ARCHETYPES")
    print(f"  Extracted {len(arch_data)} archetypes")
    write_json(arch_data, "enemy_archetypes.json")

    # 4. quest_definitions.gd -> QUESTS array
    print("Processing quest_definitions.gd...")
    with open(os.path.join(DATA_DIR, "quest_definitions.gd"), 'r', encoding='utf-8') as f:
        quest_content = f.read()

    quest_data = extract_gdscript_const_array(quest_content, "QUESTS")
    print(f"  Extracted {len(quest_data)} quests")
    write_json(quest_data, "quest_definitions.json")

    print("Done!")


if __name__ == "__main__":
    main()
