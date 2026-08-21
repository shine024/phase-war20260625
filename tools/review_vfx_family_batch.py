#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
VFX 单族 6 格合评（一次 API 调用评全部图）
================================================
一次调用把一个武器族的 6 张截图（我方/敌方 × 枪口/弹道/命中）发给 AI，
要求返回每张图的独立评分——比逐张评快 6 倍且 AI 能交叉对比。

用法:
  python tools/review_vfx_family_batch.py f08            # 只评 f08 族
  python tools/review_vfx_family_batch.py f08 f11        # 评多族
  python tools/review_vfx_family_batch.py --all          # 全 12 族

输出: 每族一行汇总 + 每格分数（与单格评审格式一致，可被既有分析脚本解析）
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
from review_vfx_realism import (  # noqa: E402
    load_keys, DEFAULT_HOST, DEFAULT_MODEL,
)

try:
    import urllib.request
    import urllib.error
except ImportError:
    pass

PROJECT_ROOT = os.path.dirname(TOOLS_DIR)
SHOTS_DIR = os.path.join(PROJECT_ROOT, "docs", "vfx_audit_shots")

KIND_ZH = {"muzzle": "开火（枪口火）", "impact": "命中", "trajectory": "弹道飞行（弹体/曳光/拖尾）"}
KIND_ORDER = ["player_muzzle", "enemy_muzzle", "player_trajectory", "enemy_trajectory", "player_impact", "enemy_impact"]

SYSTEM_PROMPT = "你是专业的 2D 游戏特效美术总监,擅长军事题材 VFX 的真实度评估。"

FAMILY_PROMPT = """这是一款 2D 战术游戏的【特效审计截图】（暗色审计台,非实战战场）。
本批发送【{family_label}】武器族的 {cells_desc} 截图。

⚠ 你必须逐张查看全部图并各自独立评分——任何一张漏评视为任务失败。

该族验收规格: {spec}
威力档位: power_tier={power_tier}（0轻/1中/2重）

评分要点:
- 枪口火: 瞬态爆发感、方向性、与武器族匹配的形态
- 弹道飞行: 弹体可见性、曳光/拖尾、族特征（曲射=弧线、激光=光束、霰弹=散布）
- 命中: 物理合理性（动能=火花锥、能量=烧灼）、层次感、规模与武器级别匹配

参照: 枪口火格=特效在青蓝色64px参考单位框旁;命中格=特效在橙红色64px参考框旁;弹道格=弹从左侧单位飞向右侧区域。参考框/标尺/文字标签是【审计台道具,不是被评估对象】。

【你的输出】只返回一个 JSON 数组（每张图一个对象，按发送顺序），不要任何前后文字:
[{{"id": "<图的id>", "realism_score": <1-10整数>, "verdict": "<一句话>"}}]"""


def call_agnes_multi(host, key, model, images_b64, user_text, timeout=120):
    """多图版本 call_agnes——一次发送 N 张图（最多 3 张，超过会被 API 丢弃）"""
    url = f"{host}/v1/chat/completions"
    content = [{"type": "text", "text": user_text}]
    for b64 in images_b64[:2]:  # 实测 3 张会 401，2 张稳定
        content.append({"type": "image_url", "image_url": {"url": f"data:image/png;base64,{b64}"}})
    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": content},
        ],
        "max_tokens": 4000,
        "temperature": 0.3,
    }
    req = urllib.request.Request(
        url, data=json.dumps(payload).encode(),
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
    )
    t0 = time.time()
    with urllib.request.urlopen(req, timeout=timeout) as r:
        body = r.read().decode("utf-8")
    j = json.loads(body)
    ch = j.get("choices", [{}])[0]
    content_str = ch.get("message", {}).get("content") or ""
    return content_str, time.time() - t0


def parse_family_scores(text, expected=2):
    """解析 JSON 数组格式的评分（期望 expected 个对象，允许 ±1）"""
    # 剥离可能的 markdown 代码块包裹
    text = re.sub(r"^```(json)?\s*", "", text.strip())
    text = re.sub(r"\s*```\s*$", "", text)
    def _try_parse(s):
        try:
            arr = json.loads(s)
            if isinstance(arr, list) and abs(len(arr) - expected) <= 1 and len(arr) >= 1:
                # 兼容 {"image":1,"score":6.5} 和 {"id":"xxx","realism_score":N} 两种格式
                normalized = []
                for i, e in enumerate(arr):
                    if not isinstance(e, dict):
                        continue
                    score = e.get("realism_score", e.get("score", -1))
                    if score is None:
                        score = -1
                    cid = e.get("id", e.get("image", f"unknown_{i}"))
                    verdict = e.get("verdict", e.get("reason", ""))
                    normalized.append({"id": str(cid), "realism_score": score, "verdict": verdict})
                return normalized if normalized else None
        except json.JSONDecodeError:
            pass
        return None
    # 先直接解析
    result = _try_parse(text)
    if result:
        return result
    # 再提取 JSON 数组片段
    m = re.search(r"\[[\s\S]*\]", text)
    if m:
        result = _try_parse(m.group(0))
        if result:
            return result
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("families", nargs="*", help="族代码（如 f08 f11）")
    ap.add_argument("--all", action="store_true", help="评全部 12 族")
    ap.add_argument("--host", default=DEFAULT_HOST)
    ap.add_argument("--model", default=DEFAULT_MODEL)
    args = ap.parse_args()

    manifest_path = os.path.join(SHOTS_DIR, "manifest.json")
    if not os.path.isfile(manifest_path):
        sys.exit("[FATAL] 缺 manifest.json——先跑 vfx_audit_matrix.tscn")
    cells = json.load(open(manifest_path, encoding="utf-8"))["cells"]

    if args.all:
        fams = sorted(set(c["family"] for c in cells))
    elif args.families:
        fams = []
        for f in args.families:
            f = f.strip().lstrip("f").lstrip("F")
            try:
                fams.append(int(f))
            except ValueError:
                sys.exit(f"[FATAL] 无效族代码: {f}")
    else:
        sys.exit("用法: review_vfx_family_batch.py f08 [f11 ...] 或 --all")

    keys = load_keys()
    # 剔除失效 key（预热测试：发一条极小请求验证 401）
    valid_keys = []
    for k in keys:
        try:
            req = urllib.request.Request(
                f"{args.host}/v1/chat/completions",
                data=json.dumps({"model": args.model, "messages": [{"role": "user", "content": "hi"}], "max_tokens": 1}).encode(),
                headers={"Authorization": f"Bearer {k}", "Content-Type": "application/json"},
            )
            urllib.request.urlopen(req, timeout=10)
            valid_keys.append(k)
        except urllib.error.HTTPError as e:
            if e.code == 401:
                print(f"  [key] 跳过失效 key: {k[:8]}...")
            else:
                valid_keys.append(k)  # 其他错误（如 400）说明 key 有效
        except Exception:
            valid_keys.append(k)  # 超时等无法判断，保留
    if not valid_keys:
        sys.exit("[FATAL] 全部 key 失效")
    keys = valid_keys
    print(f"[keys] {len(keys)}/{len(load_keys())} 个可用")
    ki = 0
    all_scores = {}

    for fam in fams:
        fam_cells = [c for c in cells if c["family"] == fam]
        if not fam_cells:
            continue
        # 按 KIND_ORDER 排序
        by_key = {}
        for c in fam_cells:
            key = f"{'player' if c.get('is_player') else 'enemy'}_{c.get('kind', 'impact')}"
            by_key[key] = c
        ordered = [by_key.get(k) for k in KIND_ORDER if k in by_key]
        if len(ordered) < 6:
            print(f"[f{fam:02d}] 跳过：只有 {len(ordered)} 格（需 6 格）")
            continue

        # 加载图片
        images = []
        for c in ordered:
            png = os.path.join(SHOTS_DIR, c["file"])
            if not os.path.isfile(png):
                break
            images.append(base64.b64encode(open(png, "rb").read()).decode())
        if len(images) < 6:
            print(f"[f{fam:02d}] 跳过：缺图")
            continue

        profile = fam_cells[0]

        # v19: 分 3 批（2+2+2）——实测 6 张丢图、3 张 401、2 张稳定
        batches = [
            (["player_muzzle", "enemy_muzzle"]),
            (["player_trajectory", "enemy_trajectory"]),
            (["player_impact", "enemy_impact"]),
        ]

        all_entries = []
        for batch_keys in batches:
            batch_cells = [by_key.get(k) for k in batch_keys if k in by_key]
            batch_imgs = []
            for c in batch_cells:
                if c is None:
                    continue
                png = os.path.join(SHOTS_DIR, c["file"])
                if os.path.isfile(png):
                    batch_imgs.append(base64.b64encode(open(png, "rb").read()).decode())
            if not batch_imgs:
                continue

            prompt = FAMILY_PROMPT.format(
                family_label=profile.get("family_label", "?"),
                spec=profile.get("spec", "?"),
                power_tier=profile.get("power_tier", 0),
                cells_desc=", ".join(batch_keys),
            )

            result = None
            for attempt in range(3):
                key = keys[ki % len(keys)]
                ki += 1
                try:
                    content, dt = call_agnes_multi(args.host, key, args.model, batch_imgs, prompt)
                    parsed = parse_family_scores(content, expected=len(batch_imgs))
                    if parsed:
                        result = parsed
                        break
                except Exception as e:
                    print(f"  重试 {attempt+1}: {e}")
                    time.sleep(2 + attempt * 3)

            if result is None:
                print(f"[f{fam:02d}] ❌ {batch_keys} 评分失败")
                continue
            all_entries.extend(result)

        if not all_entries:
            print(f"[f{fam:02d}] ❌ 全部评分失败")
            continue

        # 输出（合并两批结果）
        print(f"\n[f{fam:02d}] {profile.get('family_label', '?')}")
        fam_scores = []
        for entry in all_entries[:6]:
            raw = entry.get("realism_score", -1)
            if raw is None:
                raw = -1
            score = int(raw)
            cid = entry.get("id", "?")
            verdict = entry.get("verdict", "")[:70]
            fam_scores.append(score)
            print(f"  {cid:22s} {score:2d}/10  {verdict}")
        if fam_scores:
            avg = sum(fam_scores) / len(fam_scores)
            print(f"  {'─'*40}")
            print(f"  {'族均分':22s} {avg:.2f}")
            all_scores[f"f{fam:02d}"] = {
                "scores": {e.get("id", f"unknown_{i}"): e.get("realism_score", -1) for i, e in enumerate(all_entries[:6])},
                "avg": round(avg, 2),
            }

    # 总汇总
    if all_scores:
        total_avg = sum(v["avg"] for v in all_scores.values()) / len(all_scores)
        print(f"\n{'='*50}")
        print(f"总计: {len(all_scores)} 族, 总均分 {total_avg:.2f}/10")
        for fam_id in sorted(all_scores.keys()):
            v = all_scores[fam_id]
            print(f"  {fam_id}: {v['avg']:.2f}")


if __name__ == "__main__":
    main()
