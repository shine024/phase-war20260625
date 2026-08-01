#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""审计我方所有战斗卡的实际取图，找出兵种错用。
模拟 ui_asset_loader.card_icon_path_for 的取图优先级。
"""
import re
import os
from pathlib import Path

ROOT = Path(r"D:/godotplay/godot fair duel/phase-war")

# 1. 我方卡元数据
with open(ROOT / "data/unified_card_table.gd", encoding="utf-8") as f:
    content = f.read()
pat = re.compile(r'"card_id":"([^"]+)"[^}]*?"display_name":"([^"]+)"[^}]*?"era":(\d+)[^}]*?"combat_kind":(\d+)')
card_meta = {}
for cid, dn, era, ck in pat.findall(content):
    card_meta[cid] = (dn, int(era), int(ck))

# 2. PLAYER_ICON_OVERRIDE
with open(ROOT / "scripts/ui_asset_loader.gd", encoding="utf-8") as f:
    ul = f.read()
# 只取 override 表内的条目（表在 const PLAYER_ICON_OVERRIDE = {...} 块内）
override = {}
in_ov = False
for line in ul.splitlines():
    if "const PLAYER_ICON_OVERRIDE" in line:
        in_ov = True
        continue
    if in_ov:
        if line.strip() == "}":
            in_ov = False
            continue
        m = re.search(r'"([^"]+)":\s*"vis_player_(\d+)"', line)
        if m:
            override[m.group(1)] = f"vis_player_{m.group(2)}"

# 3. vis_enemy_NNN -> (display_name, tags) 从 enemy_archetypes.gd + manifest
# 先从 enemy_archetypes.gd 提取所有 archetype 的 tags（硬编码部分）
with open(ROOT / "data/enemy_archetypes.gd", encoding="utf-8") as f:
    ea = f.read()
# 4. 用 Godot 已有的 audit 结果：之前 override.gd 跑出了 vis_enemy -> [dn, tags]
# 这里重新从 enemy_archetypes 提取——但 tags 分散。改用：直接读 foe_ archetype 的卡图
# 最稳：遍历 assets/card_icons/enemy/vis_enemy_*.png，它们的 tags 需要从 archetype 反查

# 实际上，最可靠的是用之前 override.gd 已经验证过的 vis_to_info（它通过 EA.resolve 拿到了）
# 这里硬编码之前 audit 得到的 vis_enemy -> [dn, tags]（来自 override.txt 输出）
VIS_INFO = {
    "vis_enemy_001": ("罗尔斯装甲车", ["vehicle","armored"]),
    "vis_enemy_002": ("FT-17轻型坦克", ["vehicle","armored"]),
    "vis_enemy_003": ("77mm野战炮", ["turret","sustained"]),
    "vis_enemy_004": ("骑兵斥候", ["infantry","frontline"]),
    "vis_enemy_005": ("工兵班", ["infantry","frontline"]),
    "vis_enemy_006": ("M18地狱猫", ["vehicle","armored"]),
    "vis_enemy_007": ("M4谢尔曼", ["vehicle","armored"]),
    "vis_enemy_008": ("虎式坦克", ["vehicle","armored"]),
    "vis_enemy_009": ("巴祖卡组", ["infantry","antitank"]),
    "vis_enemy_010": ("反坦克组", ["infantry","antitank"]),
    "vis_enemy_011": ("81mm迫击炮", ["turret","sustained"]),
    "vis_enemy_012": ("81mm迫击炮", ["turret","sustained"]),
    "vis_enemy_013": ("BTR-60装甲车", ["vehicle","armored"]),
    "vis_enemy_014": ("T-55坦克", ["vehicle","armored"]),
    "vis_enemy_015": ("BMP-1步战车", ["vehicle","armored"]),
    "vis_enemy_016": ("M113装甲车", ["vehicle","armored"]),
    "vis_enemy_017": ("ZSU-23-4自行高炮", ["turret","sustained"]),
    "vis_enemy_018": ("武装皮卡", ["infantry","frontline"]),
    "vis_enemy_019": ("M1A1坦克", ["vehicle","armored"]),
    "vis_enemy_020": ("自行高炮M6", ["turret","sustained"]),
    "vis_enemy_021": ("M270火箭炮", ["turret","sustained"]),
    "vis_enemy_022": ("侦察无人机", ["aircraft","fast"]),
    "vis_enemy_023": ("M1A2 SEP", ["vehicle","armored"]),
    "vis_enemy_024": ("侦察机甲", ["infantry","frontline"]),
    "vis_enemy_025": ("悬浮坦克", ["vehicle","armored"]),
    "vis_enemy_026": ("光棱坦克", ["vehicle","armored"]),
    "vis_enemy_027": ("重装机甲", ["vehicle","armored"]),
    "vis_enemy_028": ("虚空领主", ["vehicle","armored"]),
    "vis_enemy_030": ("壁垒", ["turret","sustained"]),
    "vis_enemy_031": ("泰坦Mk.II", ["vehicle","armored"]),
    "vis_enemy_032": ("暴风骑士", ["infantry","frontline"]),
    "vis_enemy_033": ("重装母舰", ["aircraft","fast"]),
    "vis_enemy_034": ("再生骨架", ["aircraft","fast"]),
    "vis_enemy_035": ("艾布拉姆斯Mk.II", ["vehicle","armored"]),
    "vis_enemy_036": ("步兵班·MP18", ["infantry","frontline"]),
    "vis_enemy_037": ("步兵班·步枪", ["infantry","backline"]),
    "vis_enemy_038": ("机枪巢", ["turret","sustained"]),
    "vis_enemy_039": ("迫击炮组", ["artillery","backline"]),
    "vis_enemy_040": ("暴风突击队", ["elite","infantry","fast"]),
    "vis_enemy_041": ("装甲车", ["elite","vehicle","armored"]),
    "vis_enemy_042": ("圣沙蒙坦克", ["boss","tank","armored"]),
    "vis_enemy_043": ("步兵班·汤普森", ["infantry","frontline"]),
    "vis_enemy_044": ("步枪班·加兰德", ["infantry","backline"]),
    "vis_enemy_045": ("MG42机枪组", ["turret","sustained"]),
    "vis_enemy_046": ("反坦克组", ["infantry","antitank"]),
    "vis_enemy_047": ("伞兵", ["elite","infantry","fast"]),
    "vis_enemy_048": ("黑豹坦克", ["elite","tank","armored"]),
    "vis_enemy_049": ("虎王坦克", ["boss","tank","armored"]),
    "vis_enemy_050": ("苏军步兵", ["infantry","frontline"]),
    "vis_enemy_051": ("美军步兵", ["infantry","frontline"]),
    "vis_enemy_052": ("BTR装甲车", ["vehicle","armored"]),
    "vis_enemy_053": ("M113装甲车", ["vehicle","support"]),
    "vis_enemy_054": ("特种部队", ["elite","infantry","fast"]),
    "vis_enemy_055": ("T-72坦克", ["elite","tank","armored"]),
    "vis_enemy_056": ("米格-29", ["boss","aircraft","fast"]),
    "vis_enemy_057": ("海军陆战队", ["infantry","frontline"]),
    "vis_enemy_058": ("皮卡武装", ["vehicle","fast"]),
    "vis_enemy_059": ("斯特赖克装甲车", ["vehicle","armored"]),
    "vis_enemy_060": ("火箭炮车", ["artillery","backline"]),
    "vis_enemy_061": ("三角洲部队", ["elite","infantry","fast"]),
    "vis_enemy_062": ("M1A2坦克", ["elite","tank","armored"]),
    "vis_enemy_063": ("阿帕奇直升机", ["elite","aircraft","fast"]),
    "vis_enemy_064": ("指挥中枢", ["boss","fortress"]),
    "vis_enemy_065": ("无人机群", ["aircraft","fast"]),
    "vis_enemy_066": ("机械步兵", ["infantry","frontline"]),
    "vis_enemy_067": ("机甲步兵", ["vehicle","armored"]),
    "vis_enemy_068": ("悬浮坦克", ["vehicle","armored"]),
    "vis_enemy_069": ("幽灵特工", ["elite","infantry","fast","stealth"]),
    "vis_enemy_070": ("巨神机甲", ["elite","tank","armored"]),
    "vis_enemy_071": ("风暴核心", ["boss","ultimate"]),
    "vis_enemy_072": ("机枪碉堡", ["fortress","immobile"]),
    "vis_enemy_074": ("碉堡", ["fortress","immobile"]),
    "vis_enemy_078": ("要塞核心", ["fortress","immobile"]),
    "vis_enemy_080": ("离子炮台", ["fortress","immobile"]),
    "vis_enemy_081": ("能量护盾发生器", ["fortress","immobile"]),
}

CK_NAME = {0: "步兵", 1: "装甲", 2: "支援", 3: "空中", 4: "堡垒"}

def kind_from_tags(tags):
    if "infantry" in tags or "antitank" in tags:
        return "步兵"
    if "aircraft" in tags:
        return "空中"
    if "tank" in tags or "armored" in tags or "vehicle" in tags:
        return "装甲"
    if "artillery" in tags:
        return "火炮"
    if "turret" in tags or "sustained" in tags:
        return "固定支援"
    if "fortress" in tags or "immobile" in tags:
        return "堡垒"
    if "boss" in tags or "ultimate" in tags:
        return "boss"
    return "?"

# 专属图集合
root_imgs = {p.stem for p in (ROOT / "assets/card_icons").glob("*.png")}
enemy_imgs = {p.stem for p in (ROOT / "assets/card_icons/enemy").glob("*.png")}

def resolve_icon(cid, era, ck):
    """模拟 card_icon_path_for 优先级"""
    # 0) 专属图 card_icons/{cid}.png
    if cid in root_imgs:
        return cid
    # 1) manifest foe 映射（复杂，跳过——override 会覆盖大部分）
    # 1.5) override
    if cid in override:
        return override[cid]
    # 2/3) archetype manifest / drop 反查：用同名 enemy 图
    if cid in enemy_imgs:
        return cid
    # 6) era_kind fallback
    return None  # 无法确定，跳过

problems = []
checked = 0
no_resolve = 0
no_tag = 0
for cid, (dn, era, ck) in sorted(card_meta.items()):
    checked += 1
    img_fn = resolve_icon(cid, era, ck)
    if img_fn is None:
        no_resolve += 1
        continue
    lookup = img_fn.replace("vis_player_", "vis_enemy_")
    info = VIS_INFO.get(lookup)
    if info is None:
        # 可能是专属图或未在 VIS_INFO，跳过
        no_tag += 1
        continue
    img_dn, tags = info
    img_kind = kind_from_tags(tags)
    ok = False
    if ck == 0 and img_kind == "步兵": ok = True
    elif ck == 1 and img_kind == "装甲": ok = True
    elif ck == 2 and img_kind in ("固定支援", "火炮"): ok = True
    elif ck == 3 and img_kind == "空中": ok = True
    elif ck == 4 and img_kind == "堡垒": ok = True
    if not ok and img_kind != "?":
        problems.append((cid, dn, CK_NAME.get(ck, "?"), img_dn, img_kind, img_fn))

print(f"已检查 {checked}，无法解析 {no_resolve}，无tag跳过 {no_tag}，疑点 {len(problems)}")
print("\n=== 疑点清单（兵种错用）===")
for p in problems:
    print(f"{p[0]} | 我方:{p[1]}({p[2]}) | 卡图:{p[3]}({p[4]}) | {p[5]}")
