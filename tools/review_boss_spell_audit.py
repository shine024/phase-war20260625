#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
boss_spell_audit 截图 AI 评分适配器
================================================
v20.29: boss_spell_audit 的 mock boss 修复后（原在原点，boss 位效果全部错位），
需要重跑 AI 评分建立新基线。本脚本读取 docs/boss_spell_shots/manifest.json
（cells 格式），复用 review_vfx_realism 的 key/API/解析底层（call_agnes/
parse_critique——不复用 review_one，因其内部绑定 vfx_showcase 的提示模板），
用大招演出专属提示词逐帧评分。

用法:
  python tools/review_boss_spell_audit.py                 # 24 帧，温度 0.3 单次
  python tools/review_boss_spell_audit.py --deterministic # 降噪：温度 0 ×3 取中位（基线/对比必用）
  python tools/review_boss_spell_audit.py --limit 4       # 只评前 4 帧（验证）

输出:
  docs/boss_spell_report.md   人读报告（按评分升序）
  docs/boss_spell_scores.json 机读版（不覆盖历史 ai_scores.json，后者保留作修复前对照）
"""
import argparse
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request

TOOLS_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, TOOLS_DIR)
from review_vfx_realism import (  # noqa: E402
    load_keys, call_agnes, parse_critique, DEFAULT_HOST, DEFAULT_MODEL,
)

PROJECT_ROOT = os.path.dirname(TOOLS_DIR)
SHOTS_DIR = os.path.join(PROJECT_ROOT, "docs", "boss_spell_shots")
OUT_MD = os.path.join(PROJECT_ROOT, "docs", "boss_spell_report.md")
OUT_JSON = os.path.join(PROJECT_ROOT, "docs", "boss_spell_scores.json")

STAGE_ZH = {"warn": "预警阶段", "flight": "飞行阶段", "land": "落地爆炸", "after": "余波（烟柱/焦痕/残焰）"}


def user_prompt(cell: dict) -> str:
    stage = STAGE_ZH.get(cell.get("stage", ""), cell.get("stage", "?"))
    return f"""这是一款 2D 军事战术游戏的【boss 大招演出单帧截图】（暗色审计台：左侧三个青框=玩家单位 64px，右侧橙框=敌方相位师基地 96px；参考框/标尺/文字是审计台道具，不是被评估对象）。

- 大招：{cell.get('label', '?')}（{stage}）
- 本帧应表现：{cell.get('spec', '?')}
- 注意：这是多帧时间序列中的一帧——预警帧只要求威胁提示可读，飞行帧只要求弹体+拖尾，落地帧才要求爆炸层次，余波帧只要求烟柱/焦痕残留。不要拿落地帧的标准要求预警帧。

【评分基准】boss 大招应有：明确的方向叙事（从哪来→打到哪）、弹体/门/环等主体清晰、爆炸层次（闪光→火球→冲击波→烟）、规模与 boss 级匹配（明显大于普通命中）、配色与技能语义一致。

【你的输出】只返回一个 JSON 对象，不要 markdown 代码块：
{{"realism_score": <1-10整数,10最好>, "verdict": "<一句话总评>", "problems": ["<具体问题>"], "suggestions": ["<可执行建议>"]}}
请诚实、具体、挑剔。"""


def review_cell(host, keys, model, png_path, prompt, temperature=0.3):
    """单帧评分（key 轮换 + 各重试一轮，与 review_vfx_realism.review_one 同策略）。"""
    with open(png_path, "rb") as f:
        b64 = base64.b64encode(f.read()).decode()
    last_err = None
    for attempt, key in enumerate(keys * 2):
        try:
            content, finish, usage, dt = call_agnes(host, key, model, b64, prompt, temperature=temperature)
            obj, perr = parse_critique(content)
            return {
                "elapsed_s": round(dt, 1),
                "parse_error": perr,
                "critique": obj,
            }
        except urllib.error.HTTPError as e:
            last_err = f"HTTP {e.code}: {e.read().decode('utf-8', 'ignore')[:200]}"
            if e.code in (401, 403):
                continue
            if attempt >= len(keys):
                break
        except Exception as e:
            last_err = f"{type(e).__name__}: {e}"
            if attempt >= len(keys):
                break
        time.sleep(1.5)
    return {"elapsed_s": 0, "parse_error": last_err,
            "critique": {"realism_score": -1, "verdict": f"评估失败: {last_err}", "problems": [], "suggestions": []}}


def review_cell_deterministic(host, keys, model, png_path, prompt, n=3):
    """温度 0 跑 n 次取分数中位数（用中位那次的结构化结果）。"""
    runs = []
    last = None
    for _ in range(n):
        last = review_cell(host, keys, model, png_path, prompt, temperature=0.0)
        c = last.get("critique") or {}
        if c.get("realism_score", -1) >= 0:
            runs.append(last)
    if not runs:
        return last
    runs.sort(key=lambda r: (r.get("critique") or {}).get("realism_score", -1))
    pick = runs[len(runs) // 2]
    pick["denoise"] = {"runs": len(runs),
                       "scores": [(r.get("critique") or {}).get("realism_score", -1) for r in runs]}
    return pick


def main():
    ap = argparse.ArgumentParser(description="boss 大招截图 AI 评分（boss_spell_audit 专用）")
    ap.add_argument("--limit", type=int, default=0, help="只评前 N 帧(0=全量)")
    ap.add_argument("--only", default="", help="只评指定 case id（逗号分隔，如 chain,single,inferno）")
    ap.add_argument("--host", default=DEFAULT_HOST)
    ap.add_argument("--model", default=DEFAULT_MODEL)
    ap.add_argument("--deterministic", action="store_true",
                    help="降噪：温度 0 + 每帧 3 次取中位数（对比/基线必用）")
    args = ap.parse_args()

    manifest_path = os.path.join(SHOTS_DIR, "manifest.json")
    if not os.path.isfile(manifest_path):
        sys.exit(f"[FATAL] 找不到 manifest: {manifest_path}（先跑 boss_spell_audit.tscn）")
    manifest = json.load(open(manifest_path, encoding="utf-8"))
    cells = manifest.get("cells", [])
    if args.only:
        wanted = {s.strip() for s in args.only.split(",") if s.strip()}
        cells = [c for c in cells if c.get("id", "") in wanted]
    if args.limit > 0:
        cells = cells[:args.limit]
    keys = load_keys()
    print(f"shots_dir = {SHOTS_DIR}")
    print(f"keys = {len(keys)} 个, model = {args.model}, 帧数 = {len(cells)}")
    print(f"模式: {'降噪(t=0,×3中位)' if args.deterministic else '常规(t=0.3 单次)'}\n")

    results = []
    t_all = time.time()
    for i, cell in enumerate(cells):
        fname = cell.get("file", "")
        png = os.path.join(SHOTS_DIR, fname)
        if not os.path.isfile(png):
            print(f"[{i+1}/{len(cells)}] {fname} 缺文件，跳过")
            continue
        t0 = time.time()
        prompt = user_prompt(cell)
        if args.deterministic:
            r = review_cell_deterministic(args.host, keys, args.model, png, prompt, n=3)
        else:
            r = review_cell(args.host, keys, args.model, png, prompt)
        c = r.get("critique") or {}
        score = c.get("realism_score", -1)
        print(f"[{i+1}/{len(cells)}] {fname:34s} {score}/10  ({time.time()-t0:.1f}s)  {(c.get('verdict','') or '')[:60]}")
        results.append({
            "file": fname,
            "id": cell.get("id", ""),
            "label": cell.get("label", ""),
            "stage": cell.get("stage", ""),
            "spec": cell.get("spec", ""),
            "critique": c,
            "parse_error": r.get("parse_error", ""),
            "denoise": r.get("denoise"),
        })

    total = time.time() - t_all
    valid = [r for r in results if (r.get("critique") or {}).get("realism_score", -1) >= 0]
    avg = sum(r["critique"]["realism_score"] for r in valid) / len(valid) if valid else 0.0

    # 机读 JSON
    json_out = {
        "model": args.model,
        "deterministic": args.deterministic,
        "generated_at": time.strftime("%Y-%m-%d %H:%M:%S"),
        "note": "v20.29 mock boss 修复后的首份有效基线（修复前 ai_scores.json 的 boss 位效果为错位样本）",
        "avg_score": round(avg, 2),
        "results": results,
    }
    with open(OUT_JSON, "w", encoding="utf-8") as f:
        json.dump(json_out, f, ensure_ascii=False, indent=2)

    # Markdown 报告
    scored = sorted(results, key=lambda r: (r.get("critique") or {}).get("realism_score", -1))
    lines = [
        "# Boss 大招演出 AI 评分报告",
        "",
        f"- 生成时间：{time.strftime('%Y-%m-%d %H:%M:%S')}",
        f"- 模型：`{args.model}`" + ("（降噪 ×3 中位）" if args.deterministic else ""),
        f"- 帧数：{len(results)}（有效 {len(valid)}），平均 **{avg:.1f}/10**，耗时 {total/60:.1f} 分钟",
        "- 样本说明：v20.29 mock boss 修复后的首份有效基线（此前 boss 位效果截图在屏幕左上角，为错位样本）",
        "",
        "## 总览（评分升序，最该改的在最前）",
        "",
        "| 评分 | 大招 | 阶段 | 一句话总评 |",
        "|---|---|---|---|",
    ]
    for r in scored:
        c = r.get("critique") or {}
        v = (c.get("verdict", "") or "").replace("|", "/")[:70]
        lines.append(f"| {c.get('realism_score', -1)}/10 | {r['label']} | {STAGE_ZH.get(r['stage'], r['stage'])} | {v} |")
    lines += ["", "## 详情", ""]
    for r in scored:
        c = r.get("critique") or {}
        lines.append(f"### {r['file']} — {r['label']} / {STAGE_ZH.get(r['stage'], r['stage'])}")
        lines.append("")
        lines.append(f"应表现：{r.get('spec', '')}")
        lines.append("")
        lines.append(f"- **评分**：{c.get('realism_score', -1)}/10 — {c.get('verdict', '')}")
        if r.get("denoise"):
            lines.append(f"- 降噪 runs：{r['denoise'].get('scores')}")
        for p in c.get("problems", []):
            lines.append(f"- 问题：{p}")
        for s in c.get("suggestions", []):
            lines.append(f"- 建议：{s if isinstance(s, str) else json.dumps(s, ensure_ascii=False)}")
        lines.append("")
    with open(OUT_MD, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    print(f"\n[OK] 报告：{OUT_MD}")
    print(f"[OK] 机读：{OUT_JSON}")
    print(f"[OK] 平均 {avg:.1f}/10（{len(valid)}/{len(results)} 有效），总耗时 {total/60:.1f} 分钟")


if __name__ == "__main__":
    main()
