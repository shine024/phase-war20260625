#!/usr/bin/env python3
"""gen_roster.py — Read player data + enemy source, generate phase_master_roster.gd"""
import sys, os

BASE = "D:/godotplay/phase-war"
sys.path.insert(0, f"{BASE}/scripts")

# Import player data
from gen_roster_players_1 import P1
from gen_roster_players_2 import P2
player_masters = P1 + P2

# ─── Parse enemy source data from GDScript ───
FACTION_MAP = {"steel":"iron_bastion","flame":"crimson_blade","thunder":"sun_forge","void":"void_walkers"}

def map_faction(f):
    if f in FACTION_MAP: return FACTION_MAP[f]
    parts = [FACTION_MAP.get(p.strip(), p.strip()) for p in f.split("/")]
    return "/".join(parts) if len(parts) > 1 else parts[0]

def parse_enemy_json(filepath):
    import json
    with open(filepath, "r", encoding="utf-8") as f:
        data = json.load(f)
    return data.get("data", [])

enemies_raw = parse_enemy_json(f"{BASE}/data/json/enemy_phase_masters.json")
print(f"Parsed {len(enemies_raw)} enemies")

# Convert enemies to new unified format
enemy_masters = []
for i, e in enumerate(enemies_raw, 1):
    eid = f"enemy_master_{i:03d}"
    pi = e.get("phase_instrument", "steel_guardian_mk1")
    ul = e.get("unit_limit", 5)
    # Extract traits (simplified)
    traits = []
    for t in e.get("traits", []):
        traits.append({"id": t.get("id", f"enemy_trait_{i}"), "name": t.get("name", ""), "description": t.get("description", "")})
    # Extract spells
    active_spells = []
    for s in e.get("active_spells", []):
        active_spells.append({
            "id": s.get("id", f"enemy_spell_{i}"),
            "name": s.get("name", ""),
            "cooldown": s.get("cooldown", 10.0),
            "mana_cost": s.get("mana_cost", 50),
            "effect": s.get("effect", ""),
            "params": s.get("params", {})
        })
    passive_spells = []
    for s in e.get("passive_spells", []):
        passive_spells.append({
            "id": s.get("id", f"enemy_passive_{i}"),
            "name": s.get("name", ""),
            "effect": s.get("effect", ""),
            "params": s.get("params", {})
        })
    # Extract equipment
    eq = e.get("equipment", {})
    equip_out = {}
    if isinstance(eq, dict):
        equip_out["platforms"] = eq.get("platforms", [])
        equip_out["weapons"] = eq.get("weapons", [])
        equip_out["energy_cards"] = eq.get("energy_cards", [])

    faction = map_faction(e.get("faction", "iron_bastion"))

    enemy_masters.append({
        "id": eid,
        "name": e.get("name", f"敌方相位师_{i:03d}"),
        "title": e.get("title", ""),
        "faction": faction,
        "side": "enemy",
        "source_id": e.get("id", ""),
        "difficulty": e.get("difficulty", 1),
        "phase_instrument": pi,
        "unit_limit": ul,
        "engraved_affixes": [],
        "traits": traits,
        "active_spells": active_spells,
        "passive_spells": passive_spells,
        "equipment": equip_out,
    })

print(f"Converted {len(enemy_masters)} enemies")

# ─── Generate GDScript file ───
all_masters = player_masters + enemy_masters
print(f"Total masters: {len(all_masters)}")

def dict_to_gd(d, indent=2):
    """Convert a Python dict/list to GDScript-like format."""
    return _convert(d, indent)

def _convert(val, indent):
    sp = " " * indent
    if isinstance(val, dict):
        if not val:
            return "{}"
        lines = []
        # Put id first if present
        if "id" in val:
            lines.append(f'{sp}"id": "{val["id"]}",')
            rest = {k: v for k, v in val.items() if k != "id"}
        else:
            rest = val
        for k, v in rest.items():
            if k == "id":
                continue
            converted = _convert(v, indent + 2)
            if isinstance(v, str):
                lines.append(f'{sp}"{k}": "{v}",')
            elif isinstance(v, (int, float, bool)):
                lines.append(f'{sp}"{k}": {str(v).lower() if isinstance(v, bool) else v},')
            elif isinstance(v, list):
                if not v:
                    lines.append(f'{sp}"{k}": [],')
                else:
                    inner = _convert(v, indent + 2)
                    lines.append(f'{sp}"{k}": {inner},')
            elif isinstance(v, dict):
                if not v:
                    lines.append(f'{sp}"{k}": {{}},')
                else:
                    inner = _convert(v, indent + 2)
                    lines.append(f'{sp}"{k}": {inner},')
        return "{\n" + "\n".join(lines) + "\n" + sp[:-2] + "}"
    elif isinstance(val, list):
        if not val:
            return "[]"
        items = []
        for item in val:
            if isinstance(item, dict):
                items.append(_convert(item, indent + 2))
            elif isinstance(item, list):
                items.append(_convert(item, indent + 2))
            elif isinstance(item, str):
                items.append(f'{sp}"{item}"')
            elif isinstance(item, bool):
                items.append(f"{sp}{str(item).lower()}")
            else:
                items.append(f"{sp}{item}")
        return "[\n" + ",\n".join(items) + "\n" + sp[:-2] + "]"
    elif isinstance(val, str):
        return f'"{val}"'
    elif isinstance(val, bool):
        return str(val).lower()
    else:
        return str(val)

# Build file
header = '''extends RefCounted
class_name PhaseMasterRoster
## 统一相位师名册 -- 50名相位师（20我方/中立 + 30敌方）
##
## 用于排行榜显示（排名、名称、势力、战力）和战斗力评估。
## 相位师没有"等级"概念，能力完全由相位仪+刻印+技能决定。
##
## 我方相位师(#001~#020)：包含完整技能/特质/装备数据
## 敌方相位师(#021~#050)：从enemy_phase_masters.gd转换，保留完整数据
##   额外字段 source_id 关联原始数据，difficulty 用于战斗匹配
##
## 势力映射（敌方旧势力->新势力）：
##   steel->iron_bastion | flame->crimson_blade | thunder->sun_forge | void->void_walkers
##   混合势力保留原名 | neutral/ashen_order/frost_crown 为新增势力
## 星级分界：1*(0-200) 2*(200-500) 3*(500-1000) 4*(1000-1800) 5*(1800-3000) 6*(3000-5000) 7*(5000+)

const ALL_MASTERS: Array[Dictionary] = [
'''

footer = """\n]

## 查找相位师 by id
static func find_by_id(master_id: String) -> Dictionary:
	for m in ALL_MASTERS:
		if m.get("id", "") == master_id:
			return m
	return {}

## 获取某方全部相位师
static func get_by_side(side: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for m in ALL_MASTERS:
		if m.get("side", "") == side:
			result.append(m)
	return result

## 获取某势力全部相位师
static func get_by_faction(faction: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for m in ALL_MASTERS:
		if m.get("faction", "") == faction:
			result.append(m)
	return result

## 获取排行榜数据 (id, name, faction, estimated_power)
## 实际战力由 MasterPowerEvaluator 计算
static func get_leaderboard() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for m in ALL_MASTERS:
		result.append({
			"id": m.get("id", ""),
			"name": m.get("name", ""),
			"title": m.get("title", ""),
			"faction": m.get("faction", ""),
			"side": m.get("side", ""),
		})
	return result
"""

# Convert all masters to GDScript dict format
master_entries = []
for m in all_masters:
    entry = _convert(m, 2)
    master_entries.append(entry)

body = ",\n".join(master_entries)

output = header + body + footer

outpath = f"{BASE}/data/phase_master_roster.gd"
with open(outpath, "w", encoding="utf-8") as f:
    f.write(output)

size = os.path.getsize(outpath)
print(f"Written {outpath}: {size} bytes, {len(all_masters)} masters")
