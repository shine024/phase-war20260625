# -*- coding: utf-8 -*-
"""v6.15 用户实机反馈：敌方相位师 30 人的名字/称号全是异界神魔风（宙斯/托尔/阿扎托斯…），
与世界观严重脱节——宪法明确「驻守相位师首领＝迷失在时间里的车队同伴、曾经牺牲的英雄」，
且 hero_archive_texts（同伴档案）的 30 篇生前事迹/遗言早已是同伴基调。

本批：人名改中文人名（同源车队成员感），称号改为「生前事迹凝成的名号」——
与 deed 文案互相咬合（deed 已引用的称号保留：不可破之盾/万钧雷霆/永恒烈焰等 7 个）。
连带修正 015 存量矛盾：deed 写「熵减之焰」而旧 title 是「熵增炎魔」。

改动文件：enemy_phase_masters.json + 5 个时代分文件 + hero_archive_texts(027 deed 微调)
+ campaign_narrative(注释+L10 副句) + achievements/instruments/patterns/garrison/
level_information 的奥米伽引用 + 3 个测试探针。
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ── 人名（30；性别对齐 deed 代词）──
NAMES = {
    "钢铁先锋·马库斯": "沈铸城", "烈焰使者·伊格尼斯": "祝晚棠",
    "雷击者·沃尔特": "陆惊鸿", "虚空行者·奈克萨斯": "裴溯",
    "钢铁元帅·克劳斯": "霍北望", "炎魔女王·赫卡特": "姜拾烬",
    "雷神之子·索尔": "秦引路", "虚空领主·萨洛斯": "池晏",
    "钢铁军团长·费米": "靳承岗", "炎帝·普罗米修斯": "闻人烬",
    "雷皇·宙斯": "程默雷", "虚空虚主·阿扎托斯": "温折野",
    "钢铁烈焰·卡尔": "韩铸犁", "雷霆钢铁·维克多": "方镇流",
    "虚空烈焰·塞拉菲娜": "郁向暖", "不朽钢铁·阿特拉斯": "石顶安",
    "永恒炎魔·苏尔特": "江焚渡", "万雷之主·雷神": "纪回春",
    "虚空主宰·尼德霍格": "晏怀空", "钢铁雷霆·泰尔": "盛传书",
    "烈焰虚空·克尔加": "明未晞", "战争机器·铁骑": "宋卸甲",
    "火术宗师·凤凰": "楚再春", "风暴使者·赛勒斯": "岑风眠",
    "暗影主宰·深渊": "宿怀夜", "钢铁之神·赫淮斯托斯": "鲁满仓",
    "炎魔之神·赫卡特": "涂知温", "雷神·托尔": "端木近雨",
    "虚空女神·尼克斯": "叶掌灯", "全能相位师·奥米伽": "贺同舟",
}

# ── 称号（23 改 + 7 保留）──
TITLES = {
    "钢铁防线守卫": "十七天的防线", "火焰狂暴者": "过载之火",
    "闪电链大师": "七重闪电", "时空操纵者": "四十一秒的裂隙",
    "雷霆主宰": "一声没响的雷", "虚空君王": "四十天的夹层",
    "熔铸大师": "熔剑为犁", "电磁装甲师": "吞雷的装甲",
    "熵增炎魔": "熵减之焰", "世界承载者": "顶住塌方的人",
    "诸神黄昏": "烧桥的人", "雷霆化身": "圈外的雷",
    "电磁战神": "七岛的天线", "混沌炎魔": "混沌之焰",
    "钢铁风暴": "只缴不歼", "不死鸟": "灰烬里回来的人",
    "疾风迅雷": "让路的雷暴", "暗影之王": "八小时的影子",
    "锻造之神": "两百把锄头", "炼狱女王": "三十七度的火",
    "雷霆之神": "很近的雷雨", "夜之女神": "折下来的星空",
    "完美融合": "第三十一个",
}

# (file, [(old, new, expect_min), ...]) —— 数据字段形式
DATA_FILES = [
    "data/json/enemy_phase_masters.json",
    "data/enemy_phase_masters_ww1.gd",
    "data/enemy_phase_masters_ww2.gd",
    "data/enemy_phase_masters_cold.gd",
    "data/enemy_phase_masters_modern.gd",
    "data/enemy_phase_masters_future.gd",
]

# 裸名/特殊正文引用（先长后短）
SPECIAL = [
    ("data/hero_archive_texts.gd", [
        ("炼狱之焰她收放自如——", "她的火收放自如——", 1),
    ]),
    ("data/campaign_narrative.gd", [
        ("克劳斯守在这里。", "霍北望守在这里。", 1),
    ]),
    ("data/achievements_special.gd", [
        ("击败奥米伽相位师", "击败贺同舟", 1),
    ]),
    ("data/enemy_master_instruments.gd", [
        ('"display": "全能相位师·奥米伽"', '"display": "贺同舟"', 1),
    ]),
    ("data/enemy_phase_master_patterns.gd", [
        ("PATTERN_OMNI_ULTIMATE, # 奥米伽", "PATTERN_OMNI_ULTIMATE, # 贺同舟", 1),
    ]),
    ("data/level_information.gd", [
        ("摧毁奥米伽基地", "摧毁贺同舟基地", 1),
    ]),
    ("tests/master_power_smoke.gd", [
        ('"name": "钢铁先锋·马库斯"', '"name": "沈铸城"', 1),
        ('"name": "全能相位师·奥米伽"', '"name": "贺同舟"', 1),
    ]),
    ("tests/combat_power_comparison_smoke.gd", [
        ("全能相位师·奥米伽，第100关 boss", "贺同舟，第100关 boss", 1),
    ]),
    ("tests/_tmp_r4_narr_runner.gd", [
        ("钢铁元帅·克劳斯", "霍北望", 2),
        ("雷神之子·索尔", "秦引路", 1),
    ]),
]

DRY = "--dry" in sys.argv
report = []
fail = False

for rel in DATA_FILES:
    path = os.path.join(ROOT, rel)
    text = open(path, encoding="utf-8").read()
    n_name = n_title = 0
    for old, new in NAMES.items():
        tgt = '"name": "%s"' % old
        c = text.count(tgt)
        if c:
            text = text.replace(tgt, '"name": "%s"' % new)
            n_name += c
    for old, new in TITLES.items():
        tgt = '"title": "%s"' % old
        c = text.count(tgt)
        if c:
            text = text.replace(tgt, '"title": "%s"' % new)
            n_title += c
    report.append("%s: name x%d, title x%d" % (rel, n_name, n_title))
    if n_name == 0:
        report.append("  !! %s 无 name 替换命中" % rel)
        fail = True
    if not DRY:
        open(path, "w", encoding="utf-8", newline="\n").write(text)

# 裸名引用：数据文件之外的注释/正文（campaign_narrative 注释、garrison 等）
BARE_FILES = [
    "data/campaign_narrative.gd",
    "data/phase_master_garrison.gd",
    "data/enemy_phase_master_patterns.gd",
    "tests/_tmp_r4_narr_runner.gd",
]
for rel in BARE_FILES:
    path = os.path.join(ROOT, rel)
    text = open(path, encoding="utf-8").read()
    n = 0
    # 按长度降序替换，防短串误伤（克劳斯 vs 钢铁元帅·克劳斯；雷神·托尔 vs 雷神之子·索尔）
    for old in sorted(NAMES, key=len, reverse=True):
        c = text.count(old)
        if c:
            text = text.replace(old, NAMES[old])
            n += c
    report.append("%s: bare-name x%d" % (rel, n))
    if not DRY:
        open(path, "w", encoding="utf-8", newline="\n").write(text)

for rel, pairs in SPECIAL:
    path = os.path.join(ROOT, rel)
    text = open(path, encoding="utf-8").read()
    for old, new, expect in pairs:
        c = text.count(old)
        ok = c >= expect
        report.append("%s: %r x%d (expect>=%d %s)" % (rel, old[:20], c, expect, "OK" if ok else "MISS"))
        if not ok:
            fail = True
        if c and not DRY:
            text = text.replace(old, new)
    if not DRY:
        open(path, "w", encoding="utf-8", newline="\n").write(text)

print("\n".join(report))
print("DRY" if DRY else ("FAIL" if fail else "ALL DONE"))
