# -*- coding: utf-8 -*-
"""v6.52 记录1#31：同伴档案 图↔名错配更名 + 006 deed 代词修正。

用户实机主诉"图片不合，中国人叫外国名，女名是男的"。目检 7 张立绘后定案：
图是真值（美术已定稿），名字向图对齐；deed 代词已跟图一致的，改名后自动理顺；
仅 006（塞尔焦=男名+男图，deed 误用"她"）是纯文本代词错。

更名对照（id 锁死，引用一律 id 查询——v6.42 拍板）：
  008 叶莲娜·索科洛娃(俄女) → 陆听澜   图=东亚中年男（二战军装）  deed"他"✓
  020 阿米娜·奥科耶(非女)   → 岳千钧   图=中国男 PLA 数码迷彩      deed"他"✓
  023 奥马尔·哈达德(阿男)   → 林晚炬   图=中国女军人 数码迷彩      deed"她"✓
  024 英格里德·索尔海姆(挪女)→ 程让之  图=中国男 PLA 头盔          deed"他"✓
  027 颂猜·威拉万(泰男)     → 温灼     图=东亚中年女 高领          deed"她"✓
  028 玛雅·奥杜亚(女)       → 雷既白   图=东亚男 高领              deed"他"✓

幂等：替换前先查旧名存在，重跑零改动。同步面：
  分时代数据×3 / JSON / instruments display / narrative 注释 / garrison 注释 / 档案代词
"""
import io
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

RENAMES = {
    "叶莲娜·索科洛娃": "陆听澜",
    "阿米娜·奥科耶": "岳千钧",
    "奥马尔·哈达德": "林晚炬",
    "英格里德·索尔海姆": "程让之",
    "颂猜·威拉万": "温灼",
    "玛雅·奥杜亚": "雷既白",
}

FILES = [
    "data/enemy_phase_masters_ww2.gd",
    "data/enemy_phase_masters_modern.gd",
    "data/enemy_phase_masters_future.gd",
    "data/json/enemy_phase_masters.json",
    "data/enemy_master_instruments.gd",
    "data/campaign_narrative.gd",
    "data/phase_master_garrison.gd",
]

def main():
    changed = []
    for rel in FILES:
        path = os.path.join(ROOT, rel)
        with io.open(path, "r", encoding="utf-8") as f:
            text = f.read()
        orig = text
        for old, new in RENAMES.items():
            text = text.replace(old, new)
        if text != orig:
            with io.open(path, "w", encoding="utf-8", newline="") as f:
                f.write(text)
            changed.append(rel)
    # 006 deed 代词：塞尔焦（男名+男图），deed 误用"她"
    p6 = os.path.join(ROOT, "data/hero_archive_texts.gd")
    with io.open(p6, "r", encoding="utf-8") as f:
        t6 = f.read()
    old6 = "她焚毁了自己的相位核心，只为把虫潮从撤离走廊引开。"
    new6 = "他焚毁了自己的相位核心，只为把虫潮从撤离走廊引开。"
    if old6 in t6:
        t6 = t6.replace(old6, new6)
        with io.open(p6, "w", encoding="utf-8", newline="") as f:
            f.write(t6)
        changed.append("data/hero_archive_texts.gd(006代词)")
    for c in changed:
        print("CHANGED:", c)
    if not changed:
        print("NO-OP (already applied)")
    # 校验：全库再无旧名残留
    leftover = []
    for rel in FILES + ["data/hero_archive_texts.gd"]:
        with io.open(os.path.join(ROOT, rel), "r", encoding="utf-8") as f:
            t = f.read()
        for old in RENAMES:
            if old in t:
                leftover.append(rel + ":" + old)
    print("LEFTOVER:", leftover if leftover else "none")

if __name__ == "__main__":
    main()
