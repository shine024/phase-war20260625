# -*- coding: utf-8 -*-
"""img25 新路线（f0+程序焰）验收页生成器（2026-09-30）。

复刻 tools/_tmp_img25_review88.py 形式，装 staging/hybrid/ 新产物 88 单位：
- 每行：单位信息（桶类/武器/标定来源）| 卡图 | idle 动画 | attack 动画 | 批注框
- 批注 localStorage 自动保存 + 导出 JSON / Markdown 修复单

用法：python tools/_tmp_img25_hybrid_review.py  →  tools/img25_hybrid_review.html
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import _tmp_img25_redo_88 as R
import _tmp_img25_batch_88 as B

OUT_HTML = os.path.join(ROOT, "tools", "img25_hybrid_review.html")

SLOW_WEAPONS = B.SLOW_WEAPONS


def bucket(key, weapon, energy, defensive):
    if key == "fut_nano_drone":
        return "B 生成动作帧"
    if defensive:
        return "D 防御脉冲"
    if energy:
        return "E 能量蓝白" if key != "ww1_flame" else "E 喷火橙黄"
    if weapon in SLOW_WEAPONS:
        return "S 慢速单向"
    return "A 速射回文"


def build_data():
    rep = {}
    rp = os.path.join(ROOT, ".godot", "unit_review", "img25_staging", "hybrid", "_batch_report.json")
    if os.path.exists(rp):
        rep = json.load(open(rp, encoding="utf-8"))
    out = []
    for (key, rel, weapon, energy, defensive) in R.U:
        web_d = "../.godot/unit_review/img25_staging/hybrid/" + key
        info = rep.get(key, {})
        mz = B.MUZZLE_OVERRIDE.get(key)
        u = {
            "key": key, "weapon": weapon, "bucket": bucket(key, weapon, energy, defensive),
            "card": "../assets/card_icons/" + rel,
            "counts": {"idle": 8, "attack": 12}, "fps": 8, "frame_size": 256,
            "idle_sheet": web_d + "/sheet_idle.png", "attack_sheet": web_d + "/sheet_attack.png",
            "tags": [],
        }
        if key in B.SKIP_DONE:
            u["tags"].append("B 桶已完成（f0+生成帧管线样例）")
        if mz:
            u["tags"].append("muzzle 人工标定 %s" % (mz,))
        else:
            u["tags"].append("muzzle 自动 %.2f" % info.get("conf", 0))
        out.append(u)
    return out


HTML = open(os.path.join(ROOT, "tools", "_tmp_img25_review88.py"), encoding="utf-8").read()
HTML = HTML[HTML.index('HTML = """') + len('HTML = """'):]
HTML = HTML[:HTML.rindex('"""')]


def main():
    data = build_data()
    html = HTML.replace("__DATA__", json.dumps(data, ensure_ascii=False, separators=(",", ":")))
    html = html.replace("img25 重生成验收工单", "img25 新路线（f0+程序焰）验收工单")
    open(OUT_HTML, "w", encoding="utf-8").write(html)
    print("已生成:", OUT_HTML, "单位:", len(data))


if __name__ == "__main__":
    main()
