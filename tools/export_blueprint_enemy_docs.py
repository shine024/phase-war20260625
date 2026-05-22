# Regenerate docs/blueprint_enemy_full_table*.md and .csv from GD data files.
from __future__ import annotations

import csv
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

ERA_LABEL = ["一战", "二战", "冷战", "现代", "近未来"]
ERA_PREFIX = ["ww1", "ww2", "cold", "modern", "near"]
GENERATED_PLATFORM_COUNTS = [10, 10, 9, 9, 10]
GENERATED_WEAPON_COUNTS = [16, 16, 17, 17, 16]

NAME_PREFIX_PLATFORM = ["铁壁", "霜脊", "风痕", "玄甲", "苍穹", "赤曜", "夜巡", "雷铸"]
NAME_PREFIX_WEAPON = ["裂空", "震锋", "霆火", "霜矛", "影刃", "炽线", "寒星", "鸣雷", "曙光", "流焰"]
NAME_SUFFIX_PLATFORM = ["战车", "机动架", "突击底盘", "防卫舱", "侦察座", "载具框架"]
NAME_SUFFIX_WEAPON = ["步枪", "机枪", "榴弹器", "导能炮", "脉冲炮", "光束枪", "穿甲矛", "战术炮"]


def parse_blueprint_name_map(text: str) -> dict[str, str]:
    start = text.index("const BLUEPRINT_NAME_MAP: Dictionary = {")
    sub = text[start:]
    depth = 0
    started = False
    for i, ch in enumerate(sub):
        if ch == "{":
            depth += 1
            started = True
        elif ch == "}" and started:
            depth -= 1
            if depth == 0:
                block = sub[: i + 1]
                break
    else:
        raise RuntimeError("BLUEPRINT_NAME_MAP block not closed")
    out: dict[str, str] = {}
    for m in re.finditer(r'"(bp_[a-z0-9]+_\d{3})"\s*:\s*"([^"]+)"', block):
        out[m.group(1)] = m.group(2)
    return out


def parse_blueprint_enemy_map(text: str) -> list[dict[str, object]]:
    start = text.index("const BLUEPRINT_ENEMY_MAP: Dictionary = {")
    sub = text[start:]
    depth = 0
    started = False
    for i, ch in enumerate(sub):
        if ch == "{":
            depth += 1
            started = True
        elif ch == "}" and started:
            depth -= 1
            if depth == 0:
                block = sub[: i + 1]
                break
    else:
        raise RuntimeError("BLUEPRINT_ENEMY_MAP block not closed")
    rows: list[dict[str, object]] = []
    for m in re.finditer(
        r'"(bp_[a-z0-9]+_\d{3})"\s*:\s*\{\s*'
        r'"enemy_id"\s*:\s*"([^"]+)",\s*'
        r'"enemy_name"\s*:\s*"([^"]+)",\s*'
        r'"star_level"\s*:\s*(\d+),\s*'
        r'"drop_chance"\s*:\s*([0-9.]+),\s*'
        r'"era"\s*:\s*(\d+)\s*\}',
        block,
        re.DOTALL,
    ):
        era_i = int(m.group(6))
        rows.append(
            {
                "blueprint_id": m.group(1),
                "enemy_id": m.group(2),
                "enemy_name": m.group(3),
                "star_level": int(m.group(4)),
                "drop_chance": float(m.group(5)),
                "era": era_i,
                "era_label": ERA_LABEL[era_i] if 0 <= era_i < 5 else "",
            }
        )
    return rows


def parse_special_blueprints(text: str) -> list[tuple[str, str]]:
    """Order matches _create_all: _w then _p segments in file order."""
    start = text.index("static func _create_all()")
    end = text.index("list.append_array(_create_generated_blueprints())")
    block = text[start:end]
    out: list[tuple[str, str]] = []
    for m in re.finditer(r"list\.append\(_([wp])\(\"([^\"]+)\",\s*\"([^\"]+)\"", block):
        out.append((m.group(2), m.group(3)))
    return out


def fallback_generated_name(
    label: str, is_weapon: bool, era: int, loop_idx: int
) -> str:
    """Matches GD _generated_display_name when map miss (idx = loop index)."""
    prefix = ERA_PREFIX[era]
    card_id = f"bp_{prefix}_{loop_idx + 1:03d}"
    # Map is authoritative in practice; this matches GD fallback pools
    ppool = NAME_PREFIX_WEAPON if is_weapon else NAME_PREFIX_PLATFORM
    spool = NAME_SUFFIX_WEAPON if is_weapon else NAME_SUFFIX_PLATFORM
    p = ppool[(era * 7 + loop_idx) % len(ppool)]
    s = spool[(era * 5 + loop_idx * 2 + 1) % len(spool)]
    return f"{label}·{p}{s}"


def build_all_blueprint_rows(name_map: dict[str, str]) -> list[dict[str, str]]:
    specials = parse_special_blueprints(
        (ROOT / "data" / "enemy_blueprints.gd").read_text(encoding="utf-8")
    )
    rows: list[dict[str, str]] = []
    for bid, bname in specials:
        rows.append(
            {
                "blueprint_id": bid,
                "blueprint_name": bname,
                "era": "",
                "enemy_id": "",
                "enemy_name": "",
                "drop_chance": "",
                "source": "special_blueprint",
            }
        )
    for era in range(5):
        prefix = ERA_PREFIX[era]
        label = ERA_LABEL[era]
        bp_idx = 1
        for i in range(GENERATED_PLATFORM_COUNTS[era]):
            bid = f"bp_{prefix}_{bp_idx:03d}"
            bp_idx += 1
            name = name_map.get(bid) or fallback_generated_name(label, False, era, i)
            rows.append(
                {
                    "blueprint_id": bid,
                    "blueprint_name": name,
                    "era": label,
                    "enemy_id": "",
                    "enemy_name": "",
                    "drop_chance": "",
                    "source": "generated_bp",
                }
            )
        for i in range(GENERATED_WEAPON_COUNTS[era]):
            bid = f"bp_{prefix}_{bp_idx:03d}"
            bp_idx += 1
            name = name_map.get(bid) or fallback_generated_name(label, True, era, i)
            rows.append(
                {
                    "blueprint_id": bid,
                    "blueprint_name": name,
                    "era": label,
                    "enemy_id": "",
                    "enemy_name": "",
                    "drop_chance": "",
                    "source": "generated_bp",
                }
            )
    return rows


def parse_archetype_explicit_drops() -> dict[str, tuple[str, str, float, int]]:
    """card_id -> (enemy_id, enemy_display, chance, era int from archetype)."""
    text = (ROOT / "data" / "enemy_archetypes.gd").read_text(encoding="utf-8")
    start = text.index("const ARCHETYPES := {")
    end = text.index("const EnemyBlueprints")
    block = text[start:end]
    out: dict[str, tuple[str, str, float, int]] = {}
    for m in re.finditer(
        r'"([a-z0-9_]+)"\s*:\s*\{([\s\S]*?)\n\t\},',
        block,
    ):
        eid = m.group(1)
        body = m.group(2)
        em = re.search(r'"display_name"\s*:\s*"([^"]+)"', body)
        ename = em.group(1) if em else eid
        er = re.search(r'"era"\s*:\s*(\d+)', body)
        era_i = int(er.group(1)) if er else 0
        for dm in re.finditer(
            r'\{\s*"card_id"\s*:\s*"([^"]+)"\s*,\s*"chance"\s*:\s*([0-9.]+)\s*\}',
            body,
        ):
            cid = dm.group(1)
            ch = float(dm.group(2))
            out[cid] = (eid, ename, ch, era_i)
    return out


def era_from_bp_id(bid: str) -> str:
    m = re.match(r"bp_(ww1|ww2|cold|modern|near)_", bid)
    if m:
        return ERA_LABEL[ERA_PREFIX.index(m.group(1))]
    return ""


def write_csv(path: Path, fieldnames: list[str], rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)


def main() -> None:
    map_path = ROOT / "data" / "blueprint_enemy_map.gd"
    bp_path = ROOT / "data" / "enemy_blueprints.gd"
    map_text = map_path.read_text(encoding="utf-8")
    bp_text = bp_path.read_text(encoding="utf-8")
    name_map = parse_blueprint_name_map(bp_text)
    strict = parse_blueprint_enemy_map(map_text)

    docs = ROOT / "docs"

    # --- Strict table (36 mapped bp_* only) ---
    strict_rows: list[dict[str, object]] = []
    for r in strict:
        bid = str(r["blueprint_id"])
        strict_rows.append(
            {
                "blueprint_id": bid,
                "blueprint_name": name_map.get(bid, ""),
                "era": r["era_label"],
                "star_level": r["star_level"],
                "drop_chance": f"{float(r['drop_chance']):.2f}",
                "enemy_id": r["enemy_id"],
                "enemy_name": r["enemy_name"],
            }
        )
    write_csv(
        docs / "blueprint_enemy_full_table.csv",
        [
            "blueprint_id",
            "blueprint_name",
            "era",
            "star_level",
            "drop_chance",
            "enemy_id",
            "enemy_name",
        ],
        strict_rows,
    )
    md_strict = [
        "# 蓝图-敌人完整对照表（严格映射）",
        "",
        f"数据来源：`data/blueprint_enemy_map.gd` + `data/enemy_blueprints.gd`（`BLUEPRINT_NAME_MAP` 显示名）。共 **{len(strict_rows)}** 条。",
        "",
        "| blueprint_id | blueprint_name | era | star_level | drop_chance | enemy_id | enemy_name |",
        "|---|---|---|---:|---:|---|---|",
    ]
    for row in strict_rows:
        md_strict.append(
            f"| {row['blueprint_id']} | {row['blueprint_name']} | {row['era']} | "
            f"{row['star_level']} | {row['drop_chance']} | {row['enemy_id']} | {row['enemy_name']} |"
        )
    (docs / "blueprint_enemy_full_table.md").write_text("\n".join(md_strict), encoding="utf-8")

    drops = parse_archetype_explicit_drops()
    all_rows = build_all_blueprint_rows(name_map)
    for row in all_rows:
        bid = row["blueprint_id"]
        if bid in drops:
            eid, ename, ch, era_i = drops[bid]
            row["enemy_id"] = eid
            row["enemy_name"] = ename
            row["drop_chance"] = f"{ch:.2f}"
            row["era"] = ERA_LABEL[era_i] if 0 <= era_i < 5 else ""
            row["source"] = "archetype_drops"
        elif row["source"] == "generated_bp" and not row["era"]:
            row["era"] = era_from_bp_id(bid)
        elif row["source"] == "generated_bp":
            pass
        else:
            row["source"] = "special_blueprint"

    # Expanded: all bp_* rows (130), regardless of drop match
    exp_rows = [r for r in all_rows if r["blueprint_id"].startswith("bp_")]
    for r in exp_rows:
        r["source"] = "archetype_drops" if r["enemy_id"] else "unmapped_or_generated"
    write_csv(
        docs / "blueprint_enemy_full_table_expanded.csv",
        [
            "blueprint_id",
            "blueprint_name",
            "era",
            "enemy_id",
            "enemy_name",
            "drop_chance",
            "source",
        ],
        exp_rows,
    )
    md_exp = [
        "# 蓝图-敌人扩展表（全部 `bp_*`）",
        "",
        f"共 **{len(exp_rows)}** 条。显式掉落来自 `data/enemy_archetypes.gd` 的 `drops`；"
        "其余为 `unmapped_or_generated`（含运行时自动补齐逻辑，未在表中展开）。",
        "",
        "| blueprint_id | blueprint_name | era | enemy_id | enemy_name | drop_chance | source |",
        "|---|---|---|---|---|---:|---|",
    ]
    for row in exp_rows:
        md_exp.append(
            f"| {row['blueprint_id']} | {row['blueprint_name']} | {row['era']} | "
            f"{row['enemy_id']} | {row['enemy_name']} | {row['drop_chance']} | {row['source']} |"
        )
    (docs / "blueprint_enemy_full_table_expanded.md").write_text("\n".join(md_exp), encoding="utf-8")

    # All: 143
    for r in all_rows:
        if r["source"] == "special_blueprint":
            if r["blueprint_id"] in drops:
                eid, ename, ch, era_i = drops[r["blueprint_id"]]
                r["enemy_id"] = eid
                r["enemy_name"] = ename
                r["drop_chance"] = f"{ch:.2f}"
                r["era"] = ERA_LABEL[era_i]
                r["source"] = "archetype_drops"
            else:
                r["source"] = "special_blueprint"
        elif r["enemy_id"]:
            r["source"] = "archetype_drops"
        elif r["source"] == "generated_bp":
            r["source"] = "unmapped_or_generated"
    write_csv(
        docs / "blueprint_enemy_full_table_all.csv",
        [
            "blueprint_id",
            "blueprint_name",
            "era",
            "enemy_id",
            "enemy_name",
            "drop_chance",
            "source",
        ],
        all_rows,
    )
    md_all = [
        "# 蓝图-敌人最终总表（特殊蓝图 + 全部 `bp_*`）",
        "",
        f"共 **{len(all_rows)}** 条（与 `enemy_blueprints.gd` 中总量一致）。",
        "",
        "| blueprint_id | blueprint_name | era | enemy_id | enemy_name | drop_chance | source |",
        "|---|---|---|---|---|---:|---|",
    ]
    for row in all_rows:
        md_all.append(
            f"| {row['blueprint_id']} | {row['blueprint_name']} | {row['era']} | "
            f"{row['enemy_id']} | {row['enemy_name']} | {row['drop_chance']} | {row['source']} |"
        )
    (docs / "blueprint_enemy_full_table_all.md").write_text("\n".join(md_all), encoding="utf-8")

    print(
        f"Strict {len(strict_rows)}, expanded {len(exp_rows)}, all {len(all_rows)} -> {docs}"
    )


if __name__ == "__main__":
    main()
