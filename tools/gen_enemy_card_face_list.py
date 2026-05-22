# -*- coding: utf-8 -*-
"""生成 docs/enemy_card_face_ids_zh.tsv（固定原型 + 程序化敌人 ID 与中文名）。"""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
JSON_PATH = ROOT / "data/json/enemy_archetypes.json"
OUT_PATH = ROOT / "docs/enemy_card_face_ids_zh.tsv"

ERA_PREFIX = ["ww1", "ww2", "cold", "modern", "near"]
GENERATED_PER_ERA = 27

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


def generate_meaningful_enemy_name(era: int, kind: int, index: int) -> str:
    era_names = ["一战", "二战", "冷战", "现代", "近未来"]
    era_name = era_names[era] if 0 <= era < 5 else "未知"
    kind_prefixes = ERA_KIND_PREFIXES.get(era, {}).get(kind, ["单位"])
    kind_suffixes = ERA_KIND_SUFFIXES.get(era, {}).get(kind, [""])
    prefix = kind_prefixes[index % len(kind_prefixes)]
    suffix = kind_suffixes[(index + 1) % len(kind_suffixes)]
    if suffix:
        return f"{era_name}·{prefix}{suffix}"
    return f"{era_name}·{prefix}"


def main() -> None:
    data = json.loads(JSON_PATH.read_text(encoding="utf-8"))
    fixed = data.get("data", {})
    lines = ["id\t中文名"]
    for k in sorted(fixed.keys()):
        v = fixed[k]
        if isinstance(v, dict):
            name = str(v.get("display_name", "")).strip() or k
            lines.append(f"{k}\t{name}")

    for e in range(5):
        prefix = ERA_PREFIX[e]
        for i in range(GENERATED_PER_ERA):
            id_key = f"enemy_{prefix}_{i + 1:02d}"
            kind = i % 4
            name = generate_meaningful_enemy_name(e, kind, i // 4)
            lines.append(f"{id_key}\t{name}")

    OUT_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("Wrote", OUT_PATH, "lines", len(lines))


if __name__ == "__main__":
    main()
