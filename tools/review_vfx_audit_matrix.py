#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
VFX 审计矩阵 AI 真实度评分（v17）
================================================
读取 vfx_audit_matrix.tscn 产出的 docs/vfx_audit_shots/*.png + manifest.json，
逐格调 Agnes 2.5 Flash 视觉模型对照武器族验收规格打分（复用 review_vfx_realism.py
的 API 基建），输出结构化报告并把分数徽章注入 tools/vfx_audit_review.html。

前置:先跑（窗口化,约1分钟）:
  godot --path . res://scenes/tools/vfx_audit_matrix.tscn

用法:
  python tools/review_vfx_audit_matrix.py              # 全量 48 格
  python tools/review_vfx_audit_matrix.py --limit 3    # 只评前 3 格(验证)
  python tools/review_vfx_audit_matrix.py --only f08   # 只评某族

输出:
  docs/vfx_realism_report_v17.md / .json   人类/机读报告
  tools/vfx_audit_review.html              注入每格分数徽章（原地更新）
"""
import argparse
import base64
import json
import os
import re
import sys
import time

TOOLS_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, TOOLS_DIR)
from review_vfx_realism import (  # noqa: E402  复用既有评分基建
    call_agnes, load_keys, parse_critique, DEFAULT_HOST, DEFAULT_MODEL,
)

PROJECT_ROOT = os.path.dirname(TOOLS_DIR)
SHOTS_DIR = os.path.join(PROJECT_ROOT, "docs", "vfx_audit_shots")
OUT_MD = os.path.join(PROJECT_ROOT, "docs", "vfx_realism_report_v17.md")
OUT_JSON = os.path.join(PROJECT_ROOT, "docs", "vfx_realism_report_v17.json")
HTML_PATH = os.path.join(TOOLS_DIR, "vfx_audit_review.html")

KIND_ZH = {"muzzle": "开火（枪口火）", "impact": "命中", "trajectory": "弹道飞行（弹体/曳光/拖尾）"}

def cell_prompt(cell: dict) -> str:
    kind = cell.get("kind", "impact")
    # v18: 弹道格专属判据——本格评的是"飞行的弹"（弹体可见性/曳光线/拖尾/族辨识度），
    # 不是命中爆炸。旧版把 trajectory 标成 impact，AI 拿命中规格判飞行截图全部失真。
    kind_note = ""
    if kind == "trajectory":
        kind_note = ("- 本格评的是【飞行中的弹】不是命中爆炸:弹体形状/可见性、曳光线、拖尾、"
                     "弹道形态是否符合该族（曲射应有弧线、激光应是光束、霰弹应散布）。"
                     "命中反馈不在本格评分范围。\n")
    return f"""这是一款 2D 战术游戏的【特效审计截图】（暗色审计台,非实战战场）。
- 武器族:{cell.get('family_label', '?')}（visual_wt={cell.get('family')}）
- 本格内容:{'我方' if cell.get('is_player') else '敌方'}单位的【{KIND_ZH.get(kind, '?')}】特效
- 威力档位:power_tier={cell.get('power_tier')}（0轻/1中/2重）
- 该族验收规格:{cell.get('spec', '?')}
{kind_note}- 画面参照:枪口火格=特效在青蓝色64px参考单位框旁;命中格=特效在橙红色64px参考框旁;弹道格=弹从左侧单位飞向右侧区域。参考框/标尺/文字标签是【审计台道具,不是被评估对象】。
- 重要:请以"该武器族的验收规格"+同风格 2D 军事游戏的高水准 VFX 为基准,只评估特效本身。不要因为画风是 2D 或背景简陋而直接给低分。

【你的输出】只返回一个 JSON 对象,不要任何前后文字,不要 markdown 代码块:
{{"realism_score": <1-10整数,10最真实>, "verdict": "<一句话总评>", "spec_match": "<对照验收规格,特效是否呈现了规格要求的形态,一句话>", "problems": ["<具体问题>"], "suggestions": [{{"type": "<param|texture|new_layer>", "detail": "<可执行建议>", "priority": "<high|med|low>"}}]}}

请诚实、具体、挑剔。"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--only", type=str, default="", help="只评文件名含该子串的格子（如 f08）")
    ap.add_argument("--host", default=DEFAULT_HOST)
    ap.add_argument("--model", default=DEFAULT_MODEL)
    args = ap.parse_args()

    manifest_path = os.path.join(SHOTS_DIR, "manifest.json")
    if not os.path.isfile(manifest_path):
        sys.exit("[FATAL] 缺 manifest.json——先跑 vfx_audit_matrix.tscn")
    cells = json.load(open(manifest_path, encoding="utf-8"))["cells"]
    if args.only:
        cells = [c for c in cells if args.only in c["file"]]
    if args.limit:
        cells = cells[:args.limit]

    keys = load_keys()
    results = []
    t_start = time.time()
    for i, cell in enumerate(cells):
        png = os.path.join(SHOTS_DIR, cell["file"])
        if not os.path.isfile(png):
            print(f"[{i+1}/{len(cells)}] 缺图跳过: {cell['file']}")
            continue
        b64 = base64.b64encode(open(png, "rb").read()).decode()
        last_err = None
        for attempt in range(3):  # 3 次重试,轮换 key
            key = keys[(i + attempt) % len(keys)]
            try:
                content, finish, usage, dt = call_agnes(
                    args.host, key, args.model, b64, cell_prompt(cell))
                critique, mode = parse_critique(content)
                if critique.get("realism_score", -1) < 0:
                    raise ValueError(f"无法解析评分: {content[:120]}")
                critique["mode"] = mode
                last_err = None
                break
            except Exception as e:
                last_err = e
                time.sleep(2 + attempt * 3)
        if last_err is not None:
            print(f"[{i+1}/{len(cells)}] ❌ {cell['file']}: {last_err}")
            critique = {"realism_score": -1, "verdict": f"评分失败: {last_err}", "problems": [], "suggestions": []}
        entry = dict(cell)
        entry["result"] = critique
        results.append(entry)
        score = critique.get("realism_score", -1)
        print(f"[{i+1}/{len(cells)}] {'✅' if score > 0 else '❌'} {cell['file']} → {score}/10 {critique.get('verdict', '')[:60]}")

    # ── 汇总报告 ──
    valid = [r for r in results if r["result"].get("realism_score", -1) > 0]
    avg = sum(r["result"]["realism_score"] for r in valid) / max(len(valid), 1)
    by_family = {}
    for r in valid:
        by_family.setdefault(r["family_label"], []).append(r["result"]["realism_score"])
    fam_lines = "".join(
        f"| {fam} | {sum(v)/len(v):.1f} | {len(v)} |\n"
        for fam, v in sorted(by_family.items(), key=lambda kv: sum(kv[1])/len(kv[1]))
    )
    rows = "".join(
        f"| {r['result']['realism_score']}/10 | {r['family_label']} | {'我方' if r['is_player'] else '敌方'} | {KIND_ZH.get(r['kind'], '')} | {r['result'].get('verdict', '')} |\n"
        for r in sorted(valid, key=lambda r: r["result"]["realism_score"])
    )
    md = f"""# VFX 审计矩阵 AI 真实度评分报告（v17）

- 生成时间: {time.strftime('%Y-%m-%d %H:%M:%S')}
- 视觉模型: `{args.model}`
- 评分数: {len(valid)}/{len(results)} 有效，平均 **{avg:.1f}/10**

## 按武器族均分（升序,最该改的在最前）
| 均分 | 族 | 格数 |
|---|---|---|
{fam_lines}
## 全部格子（按评分升序）
| 评分 | 族 | 侧 | 类别 | 一句话总评 |
|---|---|---|---|---|
{rows}
## 高优先级改进建议
"""
    for r in sorted(valid, key=lambda r: r["result"]["realism_score"])[:10]:
        for s in r["result"].get("suggestions", []):
            if s.get("priority") == "high":
                md += f"- **{r['file']}** [{s.get('type')}] {s.get('detail')}\n"
    open(OUT_MD, "w", encoding="utf-8").write(md)
    json.dump({"generated": time.strftime('%Y-%m-%d %H:%M:%S'), "avg": avg, "cells": results},
              open(OUT_JSON, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(f"\n报告: {OUT_MD}\n平均: {avg:.1f}/10 ({len(valid)} 格有效, 耗时 {time.time()-t_start:.0f}s)")

    # ── 分数徽章注入审查页（figcaption 前缀，按图片文件名定位）──
    if os.path.isfile(HTML_PATH):
        html = open(HTML_PATH, encoding="utf-8").read()
        # v20.20-fix: 注入不幂等——旧徽章插在 figcaption 与定位锚之间，二次运行
        # pattern 失配导致只注入部分格（2026-08-27 实测 72 格只注入 47）。先剥旧徽章。
        html = re.sub(
            r'<span style="color:#[0-9a-fA-F]{6};font-weight:bold">AI \d+/10</span> ｜ ',
            '', html)
        injected = 0
        for r in results:
            score = r["result"].get("realism_score", -1)
            if score < 0:
                continue
            color = "#7ee787" if score >= 7 else ("#f0d878" if score >= 5 else "#ff7b72")
            pat = (f"src=\"../docs/vfx_audit_shots/{r['file']}\" loading=\"lazy\">"
                   f"<figcaption>")
            rep = pat + f"<span style=\"color:{color};font-weight:bold\">AI {score}/10</span> ｜ "
            if pat in html:
                html = html.replace(pat, rep)
                injected += 1
        open(HTML_PATH, "w", encoding="utf-8").write(html)
        print(f"分数徽章已注入 {injected} 格: {HTML_PATH}")


if __name__ == "__main__":
    main()
