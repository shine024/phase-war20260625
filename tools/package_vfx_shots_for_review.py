#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把 VFX 截图打包成直接可传 DeepSeek 识图的文件夹(PDF 视觉不可靠时用)。

输出 docs/vfx_shots_for_deepseek/:
  01_冲锋枪SMG.png ... 31_导弹炮口火.png   (扁平编号,顺序明确)
  打分提示词.md                            (粘贴用:规则+每号对应说明+输出格式)

DeepSeek 网页识图对单张 PNG 最可靠。31 张可一次传(若卡顿则分 1-12/13-22/23-31 三批),
配合"打分提示词.md"里的同一提示词。
"""
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHOTS = os.path.join(os.environ["APPDATA"], "Godot", "app_userdata", "phase-war", "vfx_shots")
MANIFEST = os.path.join(SHOTS, "manifest.json")
OUT_DIR = os.path.join(ROOT, "docs", "vfx_shots_for_deepseek")
PROMPT_MD = os.path.join(OUT_DIR, "打分提示词.md")


def safe(s):
    return re.sub(r"[\\/:*?\"<>|]", "_", s)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    m = json.load(open(MANIFEST, encoding="utf-8"))
    flats = []  # (shot, cap_file, peak_idx)
    for s in m["shots"]:
        for pi, c in enumerate(s.get("captures", [])):
            flats.append((s, c["file"], pi))
    total = len(flats)
    print("打包 %d 张 PNG -> %s" % (total, OUT_DIR))

    listing = []  # (num, label, desc) for prompt
    for i, (s, cap_file, pi) in enumerate(flats, 1):
        num = "%02d" % i
        ref = safe(s.get("ref_weapon", ""))
        sid = s.get("id", "")
        # 多帧特效(核爆)区分帧
        tag = ""
        if s.get("category") == "核爆":
            tag = "_火球帧" if pi == 0 else "_蘑菇云帧"
        name = "%s_%s_%s%s.png" % (num, ref, sid, tag)
        src = os.path.join(SHOTS, cap_file)
        dst = os.path.join(OUT_DIR, name)
        with open(src, "rb") as a, open(dst, "wb") as b:
            b.write(a.read())
        label = "%s | %s%s" % (s.get("category", ""), s.get("ref_weapon", ""), (" (" + tag[1:] + ")" if tag else ""))
        listing.append((num, label, s.get("description", "")))
        print("  %s" % name)

    # 提示词 md
    L = []
    L.append("# DeepSeek 识图打分 —— Phase War VFX 真实度")
    L.append("")
    L.append("## 任务")
    L.append("下面我会上传若干张 **2D 战术游戏的战斗特效截图**(已按编号命名,如 `01_冲锋枪SMG.png`)。")
    L.append("请对**每一张**打真实度分(1-10 整数,10 最真实),并给**一句总评**。")
    L.append("")
    L.append("## 重要规则(务必遵守)")
    L.append("- 每张是 **2D 游戏的实战截图**:特效叠在**战场背景 + 装甲目标**之上。背景、载具、阴影是**场景上下文,不是评估对象**——只评估**特效本身**在该场景中是否读起来像一次真实的命中/开火/爆裂。")
    L.append("- **不要因为是 2D 画风就给低分**。基准是「**同风格 2D 军事游戏的高水准 VFX**」。孤立漂浮、与场景脱节、缺层次(无烟/无碎片/无闪光)才是低分。")
    L.append("- **你必须真的看图打分**。如果某张图你看不清/没收到,就标「未看清」不要瞎猜。")
    L.append("")
    L.append("## 真实感参考基准")
    L.append("- **爆炸/地面爆裂**:体积感火球(非平面圆盘)、翻滚黑/灰烟柱、扩散尘土环、地面焦痕、四散碎片、瞬时强光;核心 白→黄→橙→暗红 渐变。")
    L.append("- **子弹/动能命中金属**:明亮金属火花锥(细长、向上扇散)、少量烟、破片。")
    L.append("- **能量武器/激光**:高亮核心 + 辉光晕 + 残留电弧/余晖。")
    L.append("- **蘑菇云/核爆**:明显蘑菇形(茎+冠)、翻滚烟尘、火光、冲击波环、地面焦痕。")
    L.append("- **技能演出**(护盾/狂暴/传送门等):按「游戏内高水准特效」评,不要求照片真实,但看层次、辉光、动感是否到位。")
    L.append("")
    L.append("## 每张图对应什么(编号 → 内容)")
    L.append("")
    L.append("| 编号 | 内容 |")
    L.append("|---|---|")
    for num, label, desc in listing:
        L.append("| %s | %s |" % (num, label))
    L.append("")
    L.append("## 输出格式(严格按此)")
    L.append("```")
    L.append("01: X/10 — 一句总评")
    L.append("02: X/10 — 一句总评")
    L.append("...（逐号到 %s）" % listing[-1][0])
    L.append("```")
    L.append("")
    L.append("---")
    L.append("**说明**:共 %d 张。若一次传不完,分批传但都用本提示词;每批我只补「这批是哪几号」。" % total)
    L.append("打完我会和另一个模型的分数对比。")
    open(PROMPT_MD, "w", encoding="utf-8").write("\n".join(L))
    print("\n[OK] 提示词: %s" % PROMPT_MD)
    print("[OK] 共 %d 张 PNG + 1 个提示词,可直接传 DeepSeek 识图" % total)


if __name__ == "__main__":
    main()
