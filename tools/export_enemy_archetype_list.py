# One-off / reusable: export fixed + generated enemy archetypes to docs/
import csv
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

ERA_PREFIX = ["ww1", "ww2", "cold", "modern", "near"]
ERA_LABEL = ["一战", "二战", "冷战", "现代", "近未来"]

ERA_KIND_PREFIXES = {
    0: {
        0: ["志愿兵", "突击队", "堑壕兵", "民兵", "征召兵"],
        1: ["装甲车", "侦察车", "突击炮", "运输车", "支援车"],
        2: ["机枪阵地", "迫击炮组", "野战炮", "碉堡", "防空炮"],
        3: ["医疗兵", "补给队", "通讯班", "工兵", "炊事班"],
    },
    1: {
        0: ["步兵班", "伞兵", "狙击手", "突击队", "侦察兵"],
        1: ["坦克", "装甲车", "自行火炮", "半履带车", "突击炮"],
        2: ["机枪组", "反坦克炮", "高射炮", "火箭炮", "固定阵地"],
        3: ["后勤班", "医疗队", "修理组", "通讯排", "补给队"],
    },
    2: {
        0: ["步兵", "特种兵", "侦察兵", "支援兵", "空降兵"],
        1: ["主战坦克", "步兵战车", "装甲运输", "自行火炮", "防空车"],
        2: ["机枪阵地", "反坦克导弹", "高射炮", "火箭炮", "岸防炮"],
        3: ["后勤组", "维修班", "医疗分队", "雷达站", "通讯中心"],
    },
    3: {
        0: ["陆战队员", "特种部队", "侦察兵", "突击队", "支援兵"],
        1: ["装甲车", "主战坦克", "步兵战车", "自行火炮", "防空系统"],
        2: ["机枪阵地", "反坦克组", "近防炮", "火箭炮", "导弹发射架"],
        3: ["后勤分队", "医疗队", "修理组", "无人机班", "电子战组"],
    },
    4: {
        0: ["机械步兵", "突击兵", "幽灵兵", "赛博兵", "猎杀者"],
        1: ["悬浮坦克", "机甲", "装甲车", "攻击平台", "运输舰"],
        2: ["能量炮台", "导弹阵地", "激光炮", "防御矩阵", "控制中心"],
        3: ["纳米维修", "能量补给", "战术支援", "数据单元", "相位站"],
    },
}

ERA_KIND_SUFFIXES = {
    0: {
        0: ["A队", "B队", "连", "排", "班"],
        1: ["Mk.I", "Mk.II", "型", "改进型", "改"],
        2: ["阵地", "阵位", "组", "班", "分队"],
        3: ["分队", "小组", "班", "组", "队"],
    },
    1: {
        0: ["班", "排", "分队", "组", "小队"],
        1: ["型", "改", "改进型", "后期型", "量产型"],
        2: ["组", "阵地", "炮位", "分队", "班"],
        3: ["班", "组", "分队", "小队", "队"],
    },
    2: {
        0: ["班", "排", "分队", "组", "小队"],
        1: ["型", "改进型", "后期型", "现代化", "升级型"],
        2: ["组", "阵地", "导弹连", "炮位", "分队"],
        3: ["分队", "小组", "班", "组", "队"],
    },
    3: {
        0: ["班", "分队", "组", "小队", "特遣队"],
        1: ["型", "改进型", "数字化", "先进型", "特种型"],
        2: ["组", "阵地", "系统", "炮位", "分队"],
        3: ["分队", "小组", "班", "特遣组", "支援队"],
    },
    4: {
        0: ["班", "小队", "特遣组", "猎杀组", "突击队"],
        1: ["型", "试验型", "量产型", "特种型", "精英型"],
        2: ["系统", "矩阵", "平台", "网络", "核心"],
        3: ["单元", "系统", "站", "中心", "节点"],
    },
}


def meaningful_name(era: int, kind: int, index: int) -> str:
    era_name = ERA_LABEL[era] if 0 <= era < 5 else "未知"
    kp = ERA_KIND_PREFIXES.get(era, {}).get(kind, ["单位"])
    ks = ERA_KIND_SUFFIXES.get(era, {}).get(kind, [""])
    prefix = kp[index % len(kp)]
    suffix = ks[(index + 1) % len(ks)]
    if suffix:
        return f"{era_name}·{prefix}{suffix}"
    return f"{era_name}·{prefix}"


def parse_fixed_from_gd() -> list[tuple[str, str]]:
    text = (ROOT / "data" / "enemy_archetypes.gd").read_text(encoding="utf-8")
    start = text.index("const ARCHETYPES := {")
    end = text.index("const EnemyBlueprints")
    block = text[start:end]
    fixed: list[tuple[str, str]] = []
    for m in re.finditer(r'"([a-z0-9_]+)"\s*:\s*\{', block):
        key = m.group(1)
        sub = block[m.end() : m.end() + 3000]
        dm = re.search(r'"display_name"\s*:\s*"([^"]+)"', sub)
        if dm:
            fixed.append((key, dm.group(1)))
    return fixed


def era_label_for_fixed_id(eid: str) -> str:
    if "ww1" in eid:
        return "一战"
    if "ww2" in eid:
        return "二战"
    if "cold" in eid:
        return "冷战"
    if "modern" in eid:
        return "现代"
    if "future" in eid:
        return "近未来"
    return "-"


def era_label_for_generated_id(eid: str) -> str:
    m = re.match(r"enemy_(ww1|ww2|cold|modern|near)_", eid)
    if not m:
        return "-"
    return ERA_LABEL[ERA_PREFIX.index(m.group(1))]


def main() -> None:
    fixed = parse_fixed_from_gd()
    if len(fixed) != 36:
        raise SystemExit(f"expected 36 fixed archetypes, got {len(fixed)}")

    generated: list[tuple[str, str]] = []
    for e in range(5):
        pre = ERA_PREFIX[e]
        for i in range(27):
            idx = int(i / 4)
            kind = i % 4
            eid = f"enemy_{pre}_{i + 1:02d}"
            generated.append((eid, meaningful_name(e, kind, idx)))

    rows: list[dict[str, str]] = []
    for kid, name in fixed:
        rows.append(
            {
                "category": "fixed",
                "era": era_label_for_fixed_id(kid),
                "enemy_id": kid,
                "display_name": name,
            }
        )
    for kid, name in generated:
        rows.append(
            {
                "category": "generated",
                "era": era_label_for_generated_id(kid),
                "enemy_id": kid,
                "display_name": name,
            }
        )

    docs = ROOT / "docs"
    docs.mkdir(parents=True, exist_ok=True)

    csv_path = docs / "enemy_archetype_full_list.csv"
    with csv_path.open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(
            f, fieldnames=["category", "era", "enemy_id", "display_name"]
        )
        w.writeheader()
        w.writerows(rows)

    lines = [
        "# 敌人原型完整列表（固定 + 生成）",
        "",
        "数据来源：`data/enemy_archetypes.gd`（脚本解析 `ARCHETYPES`；生成名按 `_generate_meaningful_enemy_name` 规则复现）。",
        "",
        f"- **固定敌人**：{len(fixed)}",
        f"- **生成敌人**：{len(generated)}",
        f"- **合计**：{len(rows)}",
        "",
        "| 类别 | 时代 | 敌人ID | 中文显示名 |",
        "|---|---|---|---|",
    ]
    for r in rows:
        lines.append(
            f"| {r['category']} | {r['era']} | {r['enemy_id']} | {r['display_name']} |"
        )
    (docs / "enemy_archetype_full_list.md").write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {csv_path} and enemy_archetype_full_list.md ({len(rows)} rows)")


if __name__ == "__main__":
    main()
