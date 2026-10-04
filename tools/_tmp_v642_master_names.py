#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""v6.42 记录6：相位师姓名多国化——用户拍板"相位师是多国的，不能只是中国名"。

28 位更名（时代贴合：WW1 欧陆 / WW2 苏德日美英 / 冷战美苏英匈 / 现代国际 / 未来国际），
保留 029 叶掌灯 / 030 贺同舟 两位中文锚点（终局叙事角色）。称号/台词一律不动，
只替换 name 字符串（含 legacy 表/叙事/装备/测试里的硬编码引用）。
可重跑（幂等：旧名不存在的文件零改动）。
"""
import io
import os

ROOT = os.path.join(os.path.dirname(__file__), "..")

RENAMES = {
    "沈铸城": "埃蒂安·勒梅特",   # 001 WW1 法
    "祝晚棠": "格蕾特·霍夫曼",   # 002 WW1 德
    "陆惊鸿": "尼古拉·沃罗诺夫", # 003 WW1 俄
    "裴溯": "埃里希·文德勒",     # 004 WW1 奥
    "霍北望": "阿奇博尔德·格雷", # 005 WW1 英
    "姜拾烬": "塞尔焦·费拉里",   # 006 WW1 意
    "秦引路": "穆斯塔法·德米拉", # 007 WW1 奥斯曼
    "池晏": "叶莲娜·索科洛娃",   # 008 WW2 苏
    "靳承岗": "奥托·施泰因贝格", # 009 WW2 德
    "闻人烬": "织田炎司",        # 010 WW2 日
    "程默雷": "弗兰克·莫里森",   # 011 WW2 美
    "温折野": "亚瑟·惠特克",     # 012 WW2 英
    "韩铸犁": "沃尔夫冈·布伦纳", # 013 冷战 东德
    "方镇流": "德米特里·杜宾",   # 014 冷战 苏
    "郁向暖": "薇拉·科瓦奇",     # 015 冷战 匈
    "石顶安": "罗伊·斯坦顿",     # 016 冷战 英
    "江焚渡": "杰克·伯恩斯",     # 017 冷战 美（Burns=焚 渊源保留）
    "纪回春": "谢尔盖·沃洛宁",   # 018 冷战 苏
    "晏怀空": "拉斐尔·埃斯皮诺萨", # 019 现代 拉美
    "盛传书": "阿米娜·奥科耶",   # 020 现代 尼日利亚
    "明未晞": "阿琼·梅农",       # 021 现代 印度
    "宋卸甲": "朴成宰",          # 022 现代 韩
    "楚再春": "奥马尔·哈达德",   # 023 现代 中东
    "岑风眠": "英格里德·索尔海姆", # 024 现代 北欧
    "宿怀夜": "维克多·内维斯",   # 025 未来 巴西
    "鲁满仓": "阿列克谢·莫罗佐夫", # 026 未来 俄
    "涂知温": "颂猜·威拉万",     # 027 未来 泰
    "端木近雨": "玛雅·奥杜亚",   # 028 未来 墨
    # 029 叶掌灯 / 030 贺同舟：保留中文名（终局叙事锚点）
}

FILES = [
    "data/json/enemy_phase_masters.json",
    "data/enemy_phase_masters_ww1.gd",
    "data/enemy_phase_masters_ww2.gd",
    "data/enemy_phase_masters_cold.gd",
    "data/enemy_phase_masters_modern.gd",
    "data/enemy_phase_masters_future.gd",
    "data/enemy_master_instruments.gd",
    "data/enemy_phase_master_patterns.gd",
    "data/campaign_narrative.gd",
    "data/achievements_special.gd",
    "data/level_information.gd",
    "data/phase_master_garrison.gd",
    "tests/combat_power_comparison_smoke.gd",
    "tests/master_power_smoke.gd",
    "tests/_playtest_scenarios_v2.gd",
]


def main() -> None:
    for rel in FILES:
        path = os.path.normpath(os.path.join(ROOT, rel))
        if not os.path.isfile(path):
            print("skip (missing):", rel)
            continue
        with io.open(path, encoding="utf-8") as f:
            text = f.read()
        changed = 0
        for old, new in RENAMES.items():
            n = text.count(old)
            if n:
                text = text.replace(old, new)
                changed += n
        if changed:
            with io.open(path, "w", encoding="utf-8", newline="") as f:
                f.write(text)
        print("%-46s %d replacement(s)" % (rel, changed))
    # 残留自检（除保留的两位中文锚点外应为零）
    leftovers = []
    for old in RENAMES:
        for rel in FILES:
            path = os.path.normpath(os.path.join(ROOT, rel))
            if not os.path.isfile(path):
                continue
            with io.open(path, encoding="utf-8") as f:
                if old in f.read():
                    leftovers.append((old, rel))
    print("LEFTOVERS:", leftovers if leftovers else "none")


if __name__ == "__main__":
    main()
