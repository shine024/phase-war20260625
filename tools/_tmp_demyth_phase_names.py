# -*- coding: utf-8 -*-
"""v6.15 续批：相位师命名去神魔化三件套（用户裁决"一起搞"）。
① 敌方相位师大招/技能名（enemy_master_instruments.gd 18 处 + desc 2 处；
   enemy_master_skill_tree.gd 14 处）——新名贴合各自主人新事迹。
② 玩家侧相位仪掉落名（phase_instruments.gd 8 处）——"XX之神"顶格档改"XX·传奇"，
   对齐"卫士/破坏者/风暴/行者"系列命名；desc 神魔词同步。
③ 战功榜（enemy_phase_leaderboard.gd 混融系别名对齐宪法"XX混融系"；
   leaderboard_detail_builders.gd TAG_ZH 5 处显示名）。
保留不动：终末/终焉/永夜/永恒黑暗（氛围词非神话专名）、神盾（军语通行译名）、
龙息（中性）、卡名层（captured/manifest 的"虚空领主"是缴获卡名）。
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DRY = "--dry" in sys.argv
fail = False

def patch_lines(rel, line_map):
    """按行号替换（1-based）；先 assert 旧串在行内，防行号漂移。"""
    global fail
    path = os.path.join(ROOT, rel)
    lines = open(path, encoding="utf-8").read().split("\n")
    for ln, (old, new) in line_map.items():
        idx = ln - 1
        if old not in lines[idx]:
            print("!! %s:%d 未找到 %r，实际: %r" % (rel, ln, old, lines[idx].strip()))
            fail = True
            continue
        lines[idx] = lines[idx].replace(old, new)
    if not DRY:
        open(path, "w", encoding="utf-8", newline="\n").write("\n".join(lines))
    print("%s: %d 行替换" % (rel, len(line_map)))

def patch_str(rel, pairs):
    """上下文串替换（每对验证命中次数）。"""
    global fail
    path = os.path.join(ROOT, rel)
    text = open(path, encoding="utf-8").read()
    for old, new, expect in pairs:
        c = text.count(old)
        if c != expect:
            print("!! %s: %r x%d != %d" % (rel, old[:24], c, expect))
            fail = True
            continue
        text = text.replace(old, new)
    if not DRY:
        open(path, "w", encoding="utf-8", newline="\n").write(text)
    print("%s: %d 组替换" % (rel, len(pairs)))

# ── ① 敌方大招（instruments，行号来自 2026-09-17 侦察）──
patch_lines("data/enemy_master_instruments.gd", {
    80:  ("地狱烈焰", "长廊之火"),          # 006 姜拾烬（pre"我烧过一条很长的走廊"）
    125: ("普罗米修斯之焰", "最后一根火柴"),  # 010 闻人烬（遗言）
    137: ("宙斯雷霆", "无声惊雷"),           # 011 程默雷（遗言"最响的雷是我一声没响的那道"）
    147: ("奥林匹斯之护", "云层之护"),       # 011（雷暴云压机场一整夜）
    159: ("深渊降临", "静默降临"),           # 012 温折野（pre"闯进我的静默"）
    258: ("诸神黄昏", "焚桥断后"),           # 017 江焚渡（烧桥断后）
    280: ("雷神之裁", "落雷为界"),           # 018 纪回春（雷围一圈焦土界）
    333: ("地狱火", "破晓信号"),             # 021 明未晞（信号弹→全城看见黎明）
    374: ("凤凰陨落", "灰烬复燃"),           # 023 楚再春（三次从灰烬燃起）
    384: ("凤凰灼烧", "余温灼烧"),           # 023（余温留给伤员）
    431: ("深渊降临", "收黑入怀"),           # 025 宿怀夜（遗言"把黑收进怀里养"）
    441: ("深渊吞噬", "夜幕合拢"),           # 025
    453: ("神之壁垒", "炉栅壁垒"),           # 026 鲁满仓（装甲熔成犁头与炉栅）
    463: ("神之熔炉", "百炼熔炉"),           # 026
    464: ("锻造钢铁神兵单位", "锻造钢铁重装单位"),
    472: ("魔神地狱火", "三十七度烈焰"),     # 027 涂知温（恒温三十七度）
    473: ("引爆地狱烈焰", "引燃一片火域"),
    482: ("末日审判", "烈焰极刑"),           # 027
    494: ("雷霆之锤", "近身雷雨"),           # 028 端木近雨（很近无害的雷雨）
    504: ("雷神审判", "自引雷霆"),           # 028（把雷霆引向自己）
})

# ── ① 敌方技能树（skill_tree）──
patch_lines("data/enemy_master_skill_tree.gd", {
    339: ("雷霆主宰", "无声之雷"),           # 011（旧 title 同名残留）
    431: ("电磁装甲师", "吞雷装甲"),         # 014（旧 title 残留）
    443: ("熵增炎魔", "减熵之焰"),           # 015（旧 title 残留+熵增矛盾）
    449: ("熵增之火", "减熵之火"),           # 015
    489: ("诸神黄昏", "断后之火"),           # 017
    512: ("凤凰重生", "火种不灭"),           # 017（重生类效果）
    565: ("虚空领主", "吞天"),               # 019 晏怀空（吞巡航导弹/天空）
    583: ("电磁战神", "装甲天线"),           # 020 盛传书（装甲当天线中转家书）
    601: ("混沌炎魔", "未晞之焰"),           # 021 明未晞（名字入技）
    726: ("神之光环", "淬火光环"),           # 026 鲁满仓（铁匠工序）
    738: ("神圣锻造", "锻炉之火"),           # 026
    744: ("神之庇护", "铁砧庇护"),           # 026
    788: ("雷霆之神", "引雷之躯"),           # 028（旧 title 残留）
    826: ("夜之女神", "点灯人"),             # 029 叶掌灯（旧 title 残留）
})

# ── ② 玩家侧相位仪（phase_instruments）──
patch_str("data/phase_instruments.gd", [
    ('"pi_steel_05", "钢铁之神"', '"pi_steel_05", "钢铁卫士·传奇"', 1),
    ('"神威钢躯：产兵全属性极限强化"', '"不朽钢躯：产兵全属性极限强化"', 1),
    ('"pi_flame_05", "炎魔之神"', '"pi_flame_05", "烈焰破坏者·传奇"', 1),
    ('"炎魔神躯：产兵攻击极限强化"', '"焚天炎躯：产兵攻击极限强化"', 1),
    ('"烈焰地狱：产兵攻击大幅强化"', '"烈焰燎原：产兵攻击大幅强化"', 1),
    ('"pi_thunder_05", "雷神"', '"pi_thunder_05", "雷霆风暴·传奇"', 1),
    ('"雷神之躯：产兵攻速极限强化"', '"极雷之躯：产兵攻速极限强化"', 1),
    ('"虚空主宰：产兵法抗极大幅强化"', '"虚空同调：产兵法抗极大幅强化"', 1),
    ('"pi_void_05", "虚空女神"', '"pi_void_05", "虚空行者·传奇"', 1),
    ('"虚空女神：产兵全属性极限强化"', '"折叠虚空：产兵全属性极限强化"', 1),
    ('"pi_voidflame_01", "熵增炎魔"', '"pi_voidflame_01", "熵焰卫士"', 1),
])

# ── ③ 战功榜（混融系对齐宪法 + TAG_ZH 显示名）──
patch_str("data/enemy_phase_leaderboard.gd", [
    ('"steel_flame": {"name": "钢铁烈焰"', '"steel_flame": {"name": "钢铁混融系"', 1),
    ('"thunder_steel": {"name": "雷霆钢铁"', '"thunder_steel": {"name": "雷霆混融系"', 1),
    ('"void_flame": {"name": "虚空烈焰"', '"void_flame": {"name": "虚空混融系"', 1),
    ('"steel_thunder": {"name": "钢铁雷霆"', '"steel_thunder": {"name": "钢铁混融系"', 1),
    ('"flame_void": {"name": "烈焰虚空"', '"flame_void": {"name": "烈焰混融系"', 1),
])
patch_str("scenes/ui/leaderboard/leaderboard_detail_builders.gd", [
    ('"thunder_god_aura": "雷神光环"', '"thunder_god_aura": "极雷光环"', 1),
    ('"god_of_thunder": "雷霆之神"', '"god_of_thunder": "引雷之躯"', 1),
    ('"void_goddess": "虚空女神"', '"void_goddess": "点灯人"', 1),
    ('"void_lord": "虚空领主"', '"void_lord": "吞天"', 1),
    ('"godly_aura": "神圣光环"', '"godly_aura": "淬火光环"', 1),
])

print("DRY" if DRY else ("FAIL" if fail else "ALL DONE"))
sys.exit(1 if (fail and not DRY) else 0)
