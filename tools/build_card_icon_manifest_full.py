# -*- coding: utf-8 -*-
"""
生成「卡面文件名 ↔ 显示名」最全对照表（含逻辑存在但仓库尚无 PNG 的 id）。

输出：assets/card_icons/work_全卡面加工/卡面文件名与显示名_最全表.txt
运行：在仓库根目录  python tools/build_card_icon_manifest_full.py

最全表不包含武器相关：enemy_blueprints.gd 中 BLUEPRINT_NAME_MAP 的「# … - 武器」小节内
全部 bp_* id，以及 data/json/enemy_phase_weapons.json 中的装备 id（含仅磁盘存在、无其它数据源的武器图标名）。
"""
from __future__ import annotations

import glob
import json
import os
import re
from typing import Dict, List, Optional, Set, Tuple

REPO = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
CARD_ICONS = os.path.join(REPO, "assets", "card_icons")
OUT_DIR = os.path.join(CARD_ICONS, "work_全卡面加工")
OUT_FILE = os.path.join(OUT_DIR, "卡面文件名与显示名_最全表.txt")

# CardResource.get_shape_key() 聚合图（与 resources/card_resource.gd 一致）
SHAPE_KEYS: Dict[str, str] = {
    "hound": "平台占位图·侦察型（HOUND）",
    "guard": "平台占位图·护卫型（GUARD）",
    "titan": "平台占位图·泰坦型（TITAN）",
    "fortress": "平台占位图·要塞型（FORTRESS）",
    "radar": "平台占位图·雷达型（RADAR）",
    "scout": "平台占位图·轻侦察型（SCOUT）",
    "raider": "平台占位图·突击型（RAIDER）",
    "siege": "平台占位图·攻城型（SIEGE）",
    "carrier": "平台占位图·母舰型（CARRIER）",
    "medic": "平台占位图·维修型（MEDIC）",
    "stealth": "平台占位图·隐匿型（STEALTH）",
    "omega_platform": "平台占位图·全装型（OMEGA_PLATFORM）",
    "energy": "能量卡聚合占位",
    "law": "法则卡聚合占位（UI：无单独法则图时）",
    "unknown": "未知类型占位（异常/缺数据回退）",
}

# resolve_display 回退；最全表不收录仅磁盘存在、无数据定义的 id
UNMATCHED_SOURCE = "未匹配任何数据源"

ERA_PREFIX = ["ww1", "ww2", "cold", "modern", "near"]
ERA_LABEL = ["一战", "二战", "冷战", "现代", "近未来"]
GENERATED_PLATFORM_COUNTS = [10, 10, 9, 9, 10]
GENERATED_WEAPON_COUNTS = [0, 0, 0, 0, 0]
NAME_PREFIX_PLATFORM = ["铁壁", "霜脊", "风痕", "玄甲", "苍穹", "赤曜", "夜巡", "雷铸"]
NAME_PREFIX_WEAPON = ["裂空", "震锋", "霆火", "霜矛", "影刃", "炽线", "寒星", "鸣雷", "曙光", "流焰"]
NAME_SUFFIX_PLATFORM = ["战车", "机动架", "突击底盘", "防卫舱", "侦察座", "载具框架"]
NAME_SUFFIX_WEAPON = ["步枪", "机枪", "榴弹器", "导能炮", "脉冲炮", "光束枪", "穿甲矛", "战术炮"]

DROP_ALIASES: Dict[str, Tuple[str, str]] = {
    "energy_basic": ("energy_start_1", "掉落表别名"),
    "energy_advanced": ("energy_start_4", "掉落表别名"),
    "energy_quantum": ("energy_start_7", "掉落表别名"),
}


def _read(p: str) -> str:
    with open(p, encoding="utf-8") as f:
        return f.read()


def parse_default_cards(path: str) -> Dict[str, str]:
    out: Dict[str, str] = {}
    if not os.path.isfile(path):
        return out
    text = _read(path)
    pat = re.compile(
        r'list\.append\(_(platform|energy_start)\("([^"]+)",\s*"([^"]+)"'
    )
    for mo in pat.finditer(text):
        out[mo.group(2)] = mo.group(3)
    return out


def parse_phase_laws(path: str) -> Dict[str, str]:
    """只解析 LAWS 顶层条目（含 family/kind），避免把 research_req 等嵌套块当成 id。"""
    out: Dict[str, str] = {}
    if not os.path.isfile(path):
        return out
    lines = _read(path).splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        mo = re.match(r'^\t"([a-z0-9_]+)":\s*\{\s*$', line)
        if mo and not line.startswith("\t\t"):
            key = mo.group(1)
            window = "\n".join(lines[i : min(i + 30, len(lines))])
            if '"family":' in window and '"kind":' in window:
                for j in range(i + 1, min(i + 45, len(lines))):
                    nmo = re.search(r'"name":\s*"([^"]+)"', lines[j])
                    if nmo:
                        out[key] = nmo.group(1)
                        break
        i += 1
    return out


def parse_legacy_law_map(default_cards_path: str, law_names: Dict[str, str]) -> Dict[str, str]:
    out: Dict[str, str] = {}
    if not os.path.isfile(default_cards_path):
        return out
    lines = _read(default_cards_path).splitlines()
    capture = False
    for line in lines:
        if "const LEGACY_LAW_CARD_ID_MAP" in line:
            capture = True
            continue
        if capture:
            if line.strip() == "}":
                break
            m = re.search(r'"([^"]+)":\s*"([^"]+)"', line)
            if m:
                old_id, new_id = m.group(1), m.group(2)
                law_disp = law_names.get(new_id, new_id)
                out[old_id] = f"{law_disp}（存档兼容旧 id：{old_id} → {new_id}）"
    return out


def parse_blueprint_name_map(path: str, exclude_ids: Optional[Set[str]] = None) -> Dict[str, str]:
    out: Dict[str, str] = {}
    if not os.path.isfile(path):
        return out
    text = _read(path)
    a = text.find("const BLUEPRINT_NAME_MAP")
    b = text.find("static func get_all_enemy_blueprint_ids")
    if a < 0 or b < 0 or b <= a:
        return out
    chunk = text[a:b]
    skip = exclude_ids or set()
    for mo in re.finditer(r'"([^"]+)":\s*"([^"]+)"', chunk):
        k = mo.group(1)
        if k not in skip:
            out[k] = mo.group(2)
    return out


def parse_weapon_blueprint_ids(path: str) -> Set[str]:
    """BLUEPRINT_NAME_MAP 中「# … - 武器」小节内的 bp_* id（最全表不再收录武器蓝图行）。"""
    out: Set[str] = set()
    if not os.path.isfile(path):
        return out
    text = _read(path)
    a = text.find("const BLUEPRINT_NAME_MAP")
    b = text.find("static func get_all_enemy_blueprint_ids")
    if a < 0 or b < 0 or b <= a:
        return out
    chunk = text[a:b]
    in_weapons = False
    for line in chunk.splitlines():
        s = line.strip()
        if s.startswith("#") and "- 武器" in s:
            in_weapons = True
            continue
        if s.startswith("#") and "- 平台" in s:
            in_weapons = False
            continue
        if in_weapons:
            mo = re.search(r'"([a-z0-9_]+)":', line)
            if mo:
                out.add(mo.group(1))
    return out


def load_weapon_json_card_ids() -> Set[str]:
    """enemy_phase_weapons.json 顶层 id，用于从最全表排除（仍读文件仅构建排除集，不写入装备表）。"""
    p = os.path.join(REPO, "data", "json", "enemy_phase_weapons.json")
    out: Set[str] = set()
    if not os.path.isfile(p):
        return out
    try:
        obj = json.loads(_read(p))
    except json.JSONDecodeError:
        return out
    data = obj.get("data")
    if isinstance(data, dict):
        out.update(str(k) for k in data.keys())
    return out


def parse_enemy_blueprint_special_cards(path: str) -> Dict[str, str]:
    out: Dict[str, str] = {}
    if not os.path.isfile(path):
        return out
    text = _read(path)
    for mo in re.finditer(r'_p\("([^"]+)",\s*"([^"]+)"', text):
        out[mo.group(1)] = mo.group(2)
    return out


def generated_display_name(
    label: str,
    is_weapon: bool,
    era: int,
    idx: int,
    prefix: str,
    bp_map: Dict[str, str],
) -> str:
    bp_idx = idx + 1
    card_id = f"bp_{prefix}_{bp_idx:03d}"
    if card_id in bp_map:
        return bp_map[card_id]
    prefix_pool = NAME_PREFIX_WEAPON if is_weapon else NAME_PREFIX_PLATFORM
    suffix_pool = NAME_SUFFIX_WEAPON if is_weapon else NAME_SUFFIX_PLATFORM
    p = prefix_pool[(era * 7 + idx) % len(prefix_pool)]
    s = suffix_pool[(era * 5 + idx * 2 + 1) % len(suffix_pool)]
    return f"{label}·{p}{s}"


def enumerate_generated_blueprint_ids(bp_map: Dict[str, str]) -> Dict[str, str]:
    out: Dict[str, str] = {}
    for era in range(5):
        prefix = ERA_PREFIX[era]
        label = ERA_LABEL[era]
        bp_idx = 1
        for i in range(GENERATED_PLATFORM_COUNTS[era]):
            id_key = f"bp_{prefix}_{bp_idx:03d}"
            bp_idx += 1
            out[id_key] = generated_display_name(label, False, era, i, prefix, bp_map)
        for i in range(GENERATED_WEAPON_COUNTS[era]):
            id_key = f"bp_{prefix}_{bp_idx:03d}"
            bp_idx += 1
            out[id_key] = generated_display_name(label, True, era, i, prefix, bp_map)
    return out


def load_json_equipment_data() -> Dict[str, Tuple[str, str]]:
    """id -> (显示名, 来源标签)"""
    out: Dict[str, Tuple[str, str]] = {}
    json_specs: List[Tuple[str, str]] = [
        ("enemy_phase_platforms.json", "敌方相位装备·平台 JSON"),
        ("enemy_phase_energy_cards.json", "敌方相位装备·能量 JSON"),
        ("enemy_phase_instruments.json", "敌方相位装备·相位仪 JSON"),
    ]
    for fname, tag in json_specs:
        p = os.path.join(REPO, "data", "json", fname)
        if not os.path.isfile(p):
            continue
        try:
            obj = json.loads(_read(p))
        except json.JSONDecodeError:
            continue
        if int(obj.get("schema_version", 0)) != 1:
            continue
        data = obj.get("data")
        if not isinstance(data, dict):
            continue
        for kid, v in data.items():
            if not isinstance(v, dict):
                continue
            name = str(v.get("name", kid))
            out[str(kid)] = (name, tag)
    return out


def collect_all_ids(
    default_names: Dict[str, str],
    law_names: Dict[str, str],
    bp_map: Dict[str, str],
    special_bp: Dict[str, str],
    gen_bp: Dict[str, str],
    equipment: Dict[str, Tuple[str, str]],
    legacy: Dict[str, str],
) -> Set[str]:
    ids: Set[str] = set()
    ids.update(default_names.keys())
    ids.update(law_names.keys())
    ids.update(bp_map.keys())
    ids.update(special_bp.keys())
    ids.update(gen_bp.keys())
    ids.update(equipment.keys())
    ids.update(legacy.keys())
    ids.update(DROP_ALIASES.keys())
    for _alias, (target, _note) in DROP_ALIASES.items():
        ids.add(target)
    ids.update(SHAPE_KEYS.keys())
    return ids


def resolve_display(
    card_id: str,
    default_names: Dict[str, str],
    law_names: Dict[str, str],
    bp_map: Dict[str, str],
    special_bp: Dict[str, str],
    gen_bp: Dict[str, str],
    equipment: Dict[str, Tuple[str, str]],
    legacy: Dict[str, str],
) -> Tuple[str, str]:
    """返回 (显示名, 来源简述)"""
    if card_id in default_names:
        return default_names[card_id], "DefaultCards.create_all"
    if card_id in law_names:
        return law_names[card_id], "PhaseLaws.LAWS"
    if card_id in special_bp:
        return special_bp[card_id], "EnemyBlueprints 精英掉落 _p"
    if card_id in gen_bp:
        return gen_bp[card_id], "EnemyBlueprints 生成蓝图"
    if card_id in equipment:
        return equipment[card_id][0], equipment[card_id][1]
    if card_id in bp_map and card_id not in gen_bp and card_id not in special_bp:
        return bp_map[card_id], "EnemyBlueprints.BLUEPRINT_NAME_MAP（全量；部分 id 当前掉落池未生成）"
    if card_id in legacy:
        return legacy[card_id], "LEGACY_LAW_CARD_ID_MAP"
    if card_id in DROP_ALIASES:
        tgt, note = DROP_ALIASES[card_id]
        dn = default_names.get(tgt, tgt)
        return f"{dn}（{note} → {tgt}）", "default_cards.gd 掉落别名"
    if card_id in SHAPE_KEYS:
        return SHAPE_KEYS[card_id], "CardResource 形状聚合键 / UI 回退"
    return ("（待补显示名：请与策划/数据表对齐后填写）", UNMATCHED_SOURCE)


def main() -> None:
    gd_default = os.path.join(REPO, "data", "default_cards.gd")
    gd_laws = os.path.join(REPO, "data", "phase_laws.gd")
    gd_enemy_bp = os.path.join(REPO, "data", "enemy_blueprints.gd")

    weapon_bp_ids = parse_weapon_blueprint_ids(gd_enemy_bp)
    weapon_json_ids = load_weapon_json_card_ids()
    exclude_weapon = weapon_bp_ids | weapon_json_ids

    default_names = parse_default_cards(gd_default)
    law_names = parse_phase_laws(gd_laws)
    legacy = parse_legacy_law_map(gd_default, law_names)
    bp_map = parse_blueprint_name_map(gd_enemy_bp, exclude_ids=weapon_bp_ids)
    special_bp = parse_enemy_blueprint_special_cards(gd_enemy_bp)
    gen_bp = enumerate_generated_blueprint_ids(bp_map)
    equipment = load_json_equipment_data()

    existing_png = {os.path.splitext(os.path.basename(p))[0] for p in glob.glob(os.path.join(CARD_ICONS, "*.png"))}

    all_ids = collect_all_ids(default_names, law_names, bp_map, special_bp, gen_bp, equipment, legacy)
    all_ids |= existing_png
    all_ids -= exclude_weapon

    rows: List[Tuple[str, str, str, str]] = []
    for cid in sorted(all_ids, key=lambda s: (s.count("_"), s)):
        fn = f"{cid}.png"
        has_png = cid in existing_png
        status = "已有PNG" if has_png else "无PNG·待补导出"
        disp, src = resolve_display(
            cid, default_names, law_names, bp_map, special_bp, gen_bp, equipment, legacy
        )
        rows.append((fn, disp, status, src))

    before_drop = len(rows)
    rows = [r for r in rows if r[3] != UNMATCHED_SOURCE]
    dropped = before_drop - len(rows)

    os.makedirs(OUT_DIR, exist_ok=True)
    n_have = sum(1 for r in rows if r[2] == "已有PNG")
    lines: List[str] = [
        "# 卡面文件名与显示名 · 最全表（自动生成；数据变更后请重跑 tools/build_card_icon_manifest_full.py）",
        "# 制表符分隔：文件名 | 显示名 | 资源状态 | 数据来源",
        "# 已排除：蓝图 BLUEPRINT_NAME_MAP「# … - 武器」小节内全部 id；enemy_phase_weapons.json 全部 id。",
        "# 已排除：未匹配任何数据源的条目（通常为 assets/card_icons 内无对应 id 定义的孤儿 PNG）。",
        f"# 统计：共 {len(rows)} 条；其中已有 PNG {n_have} 条；无 PNG 待导出 {len(rows) - n_have} 条"
        + (f"；本次剔除未匹配 {dropped} 条" if dropped else ""),
        "",
    ]
    for fn, disp, status, src in rows:
        lines.append(f"{fn}\t{disp}\t{status}\t{src}")

    with open(OUT_FILE, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("Wrote", len(rows), "rows ->", OUT_FILE)


if __name__ == "__main__":
    main()
