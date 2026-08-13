#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
VFX 真实度自动诊断(Phase 1)——视觉审阅脚本
================================================
读取 vfx_showcase 场景产出的 user://vfx_shots/manifest.json + PNG,逐张调
Agnes 2.5 Flash 视觉模型做"真实感"评分,输出结构化诊断报告。

前置:先跑 res://scenes/tools/vfx_showcase.tscn 产出截图与 manifest。
  (窗口化跑:godot --path . --rendering-driver opengl3 res://scenes/tools/vfx_showcase.tscn)

用法:
  python tools/review_vfx_realism.py                # 全量
  python tools/review_vfx_realism.py --limit 3      # 只评前 3 张(验证)
  python tools/review_vfx_realism.py --shots-dir PATH --out-md PATH

输出:
  docs/vfx_realism_report.md   人类可读报告(总览表 + 详情 + 高优先级汇总)
  docs/vfx_realism_report.json 机读版
  docs/vfx_realism_shots/      截图副本(报告内引用,自包含)
"""
import argparse
import base64
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

# ---- 配置 ----
DEFAULT_HOST = "https://apihub.agnes-ai.cn"   # .cn 可用; .com 证书过期
DEFAULT_MODEL = "agnes-2.5-flash"
KEY_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "_api_key.txt")
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS_DIR = os.path.join(PROJECT_ROOT, "docs")
SHOTS_COPY_DIR = os.path.join(DOCS_DIR, "vfx_realism_shots")
DEFAULT_OUT_MD = os.path.join(DOCS_DIR, "vfx_realism_report.md")
DEFAULT_OUT_JSON = os.path.join(DOCS_DIR, "vfx_realism_report.json")
MAX_TOKENS = 1500   # 允许 reasoning(~200) + 详细 JSON(~600+)

SYSTEM_PROMPT = (
    "你是一位 2D 军事/战术游戏的资深 VFX 美术指导,精通一战到近未来各时代弹药、爆炸、"
    "能量武器的【真实物理视觉特征】。你的任务:对比真实参考,评估游戏内某个视觉特效截图的"
    "【真实感】,并给出具体、可执行的改进建议。建议必须具体到可操作(改哪个粒子参数/重生哪张贴图/"
    "补哪一层),不要空泛的'加更多粒子'之类的废话。"
)

def user_prompt(shot: dict) -> str:
    return f"""这是一款 2D 战术游戏的【实战场景截图】。
- 特效类别:{shot.get('category', '?')}
- 应表现的内容:{shot.get('description', '?')}
- 时代背景:{shot.get('era', '?')}
- 参考武器/类型:{shot.get('ref_weapon', '?')}
- 重要:这是叠加在战场背景与一辆敌方装甲目标之上的实战画面。背景、装甲载具、脚下阴影都是【场景上下文,不是被评估对象】——请只评估【特效本身】在该战斗场景中是否读起来像一次真实的命中/开火/爆裂。特效叠在目标上、读起来像"打中了装甲并溅起火花/烟尘/破片"才是高分;孤立漂浮、与场景脱节的粒子才是低分。不要因为画风是 2D 就直接给低分——请以"同风格 2D 军事游戏的高水准 VFX"为基准评分。

【真实感参考基准】(对比用):
- 爆炸/地面爆裂:应有体积感火球(非平面圆盘)、翻滚的黑/灰烟柱、向外扩散的尘土环、地面焦痕、四散的碎片/破片、瞬时强光高光;颜色从核心白→黄→橙→暗红渐变,外圈带黑烟。
- 子弹/动能命中金属:明亮的金属火花锥(细长、向上扇散)、少量烟、可能的破片;绝非平面色块。
- 能量武器/激光:高亮核心 + 辉光晕 + 残留电弧或余晖;颜色饱和带辉光。
- 穿透/闪电:锐利的线状光迹 + 分支 + 末端命中闪光。
- 蘑菇云/核爆:明显的蘑菇形(茎 + 冠)、翻滚烟尘、强烈火光、冲击波环、地面大面积焦痕。

【你的输出】只返回一个 JSON 对象,不要任何前后文字,不要 markdown 代码块:
{{"realism_score": <1-10整数,10最真实>, "verdict": "<一句话总评>", "problems": ["<具体问题,如'火球是平面圆盘缺体积感'/'完全没有烟雾'/'颜色过饱和偏卡通'>"], "suggestions": [{{"type": "<param|texture|new_layer>", "detail": "<可执行建议>", "priority": "<high|med|low>"}}]}}

type 含义:param=改粒子/几何参数(数量/寿命/颜色梯度/尺寸/速度)即可改善;texture=贴图本身不够真实需 AI 重新生成;new_layer=缺一整层效果(如完全没烟雾层/没碎片层)需新增。
请诚实、具体、挑剔。"""


def load_keys() -> list:
    if not os.path.isfile(KEY_FILE):
        sys.exit(f"[FATAL] 找不到 key 文件: {KEY_FILE}")
    keys = [ln.strip() for ln in open(KEY_FILE, encoding="utf-8").read().splitlines() if ln.strip()]
    if not keys:
        sys.exit(f"[FATAL] {KEY_FILE} 无有效 key")
    return keys


def locate_shots_dir(override: str) -> str:
    if override:
        return override
    # 从 project.godot 读 config/name
    name = "phase-war"
    pg = os.path.join(PROJECT_ROOT, "project.godot")
    if os.path.isfile(pg):
        m = re.search(r'config/name\s*=\s*"([^"]+)"', open(pg, encoding="utf-8").read())
        if m:
            name = m.group(1)
    appdata = os.environ.get("APPDATA", "")
    for cand in (
        os.path.join(appdata, "Godot", "app_userdata", name, "vfx_shots"),
        os.path.join(appdata, "Godot", "app_userdata", "Phase War", "vfx_shots"),
    ):
        if os.path.isdir(cand):
            return cand
    sys.exit(f"[FATAL] 找不到 vfx_shots 目录(尝试过 app_userdata/{name})。用 --shots-dir 显式指定。")


def call_agnes(host: str, key: str, model: str, b64: str, user_text: str, temperature: float = 0.3, timeout: int = 90):
    url = f"{host}/v1/chat/completions"
    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": [
                {"type": "text", "text": user_text},
                {"type": "image_url", "image_url": {"url": f"data:image/png;base64,{b64}"}},
            ]},
        ],
        "max_tokens": MAX_TOKENS,
        "temperature": temperature,
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
    msg = ch.get("message", {})
    content = msg.get("content") or msg.get("reasoning_content") or ""
    return content, ch.get("finish_reason"), j.get("usage", {}), time.time() - t0


def _regex_score(text: str) -> int:
    m = re.search(r'realism_score["\']?\s*[:=]\s*"?(\d{1,2})"?', text)
    return int(m.group(1)) if m else -1


def _regex_verdict(text: str) -> str:
    m = re.search(r'"verdict"\s*:\s*"((?:[^"\\]|\\.)*)"', text)
    if not m:
        return ""
    try:
        return m.group(1).encode("utf-8").decode("unicode_escape")
    except Exception:
        return m.group(1)


def parse_critique(text: str):
    """始终返回至少含 realism_score 的 dict(正则兜底),JSON 完整时再补全详情字段。"""
    text = (text or "").strip()
    # 去掉可能的 ```json 包裹
    text = re.sub(r"^```(?:json)?\s*", "", text)
    text = re.sub(r"\s*```\s*$", "", text)
    base = {
        "realism_score": _regex_score(text),
        "verdict": "",
        "problems": [],
        "suggestions": [],
    }
    start = text.find("{")
    end = text.rfind("}")
    if start < 0 or end <= start:
        base["verdict"] = text[:200]
        return base, "regex_fallback"
    blob = text[start:end + 1]
    if not base["verdict"]:
        base["verdict"] = _regex_verdict(text)
    # 尝试完整 JSON 解析(原样 + 容忍尾随逗号两版)
    for attempt_blob in (blob, re.sub(r",\s*([}\]])", r"\1", blob)):
        try:
            obj = json.loads(attempt_blob)
            obj.setdefault("realism_score", base["realism_score"])
            obj.setdefault("verdict", base["verdict"] or "")
            obj.setdefault("problems", [])
            obj.setdefault("suggestions", [])
            return obj, None
        except Exception:
            continue
    # JSON 整体坏:至少保留正则抽到的 score/verdict
    return base, "json_partial_fallback"


def review_one(host, keys, model, png_path, shot, temperature=0.3):
    with open(png_path, "rb") as f:
        b64 = base64.b64encode(f.read()).decode()
    last_err = None
    for attempt, key in enumerate(keys * 2):  # 轮换 + 各重试一轮
        try:
            content, finish, usage, dt = call_agnes(host, key, model, b64, user_prompt(shot), temperature=temperature)
            obj, perr = parse_critique(content)
            return {
                "content_raw_head": content[:300],
                "finish_reason": finish,
                "usage": usage,
                "elapsed_s": round(dt, 1),
                "parse_error": perr,
                "critique": obj,
            }
        except urllib.error.HTTPError as e:
            last_err = f"HTTP {e.code}: {e.read().decode('utf-8', 'ignore')[:200]}"
            if e.code in (401, 403):  # key 问题 → 轮换
                continue
            if attempt >= len(keys):  # 其他 HTTP 错误,轮换一轮后放弃
                break
        except Exception as e:
            last_err = f"{type(e).__name__}: {e}"
            if attempt >= len(keys):
                break
        time.sleep(1.5)
    return {"content_raw_head": "", "finish_reason": "error", "elapsed_s": 0,
            "parse_error": last_err, "critique": {"realism_score": -1, "verdict": f"评估失败: {last_err}",
            "problems": [], "suggestions": []}}


def review_one_deterministic(host, keys, model, png_path, shot, n=3):
    """降噪评估:温度 0 + 跑 n 次取分数中位数,用中位数那次的结构化结果。
    压制视觉模型 ±2-3 的单次抖动,让增量改动的涨跌可被可信度量。"""
    runs = []
    last = None
    for _ in range(n):
        res = review_one(host, keys, model, png_path, shot, temperature=0.0)
        last = res
        c = res.get("critique") or {}
        if c.get("realism_score", -1) >= 0:
            runs.append(res)
    if not runs:
        return last  # 全失败,返回最后一次(含错误信息)
    runs.sort(key=lambda r: (r.get("critique") or {}).get("realism_score", -1))
    pick = runs[len(runs) // 2]
    pick["denoise"] = {
        "runs": len(runs),
        "scores": [(r.get("critique") or {}).get("realism_score", -1) for r in runs],
    }
    return pick


def score_text(s):
    try:
        v = int(s)
    except Exception:
        return "??"
    return f"{v}/10"


def write_report(results, out_md, out_json, model):
    os.makedirs(os.path.dirname(out_md), exist_ok=True)
    os.makedirs(SHOTS_COPY_DIR, exist_ok=True)
    # 复制截图
    for r in results:
        dst = os.path.join(SHOTS_COPY_DIR, r["file"])
        if os.path.isfile(r["png_path"]):
            with open(r["png_path"], "rb") as src, open(dst, "wb") as dstf:
                dstf.write(src.read())
    # JSON
    json_out = {
        "model": model,
        "generated_at": time.strftime("%Y-%m-%d %H:%M:%S"),
        "results": [{k: v for k, v in r.items() if k != "png_path"} for r in results],
    }
    with open(out_json, "w", encoding="utf-8") as f:
        json.dump(json_out, f, ensure_ascii=False, indent=2)

    # Markdown
    scored = sorted(results, key=lambda r: (r["critique"].get("realism_score", -1) if r["critique"] else -1))
    lines = []
    lines.append("# VFX 真实度诊断报告")
    lines.append("")
    lines.append(f"- 生成时间:{time.strftime('%Y-%m-%d %H:%M:%S')}")
    lines.append(f"- 视觉模型:`{model}`")
    lines.append(f"- 评估特效数:{len(results)}")
    valid = [r for r in results if r["critique"] and r["critique"].get("realism_score", -1) >= 0]
    if valid:
        avg = sum(r["critique"]["realism_score"] for r in valid) / len(valid)
        lines.append(f"- 平均真实度评分:{avg:.1f}/10(共 {len(valid)} 张有效)")
    lines.append("")
    lines.append("## 总览(按评分升序,最该改的在最前)")
    lines.append("| 评分 | 类别 | 特效 | 一句话总评 |")
    lines.append("|---|---|---|---|")
    for r in scored:
        c = r["critique"] or {}
        lines.append(f"| {score_text(c.get('realism_score', -1))} | {r['category']} | {r['file']} | {(c.get('verdict','') or '').replace('|','/')[:80]} |")
    lines.append("")
    # 高优先级汇总
    lines.append("## 高优先级问题汇总(high)")
    lines.append("")
    hi_any = False
    for r in results:
        c = r["critique"] or {}
        for s in c.get("suggestions", []):
            if str(s.get("priority", "")).lower() == "high":
                hi_any = True
                lines.append(f"- **{r['file']}** [{s.get('type','?')}] {s.get('detail','')}")
    if not hi_any:
        lines.append("_(无 high 优先级建议)_")
    lines.append("")
    # 详情
    lines.append("## 详情")
    lines.append("")
    for r in scored:
        c = r["critique"] or {}
        lines.append(f"### {r['file']} — {r['category']} / {r.get('era','')} / {r.get('ref_weapon','')}")
        lines.append("")
        lines.append(f"![{r['file']}](vfx_realism_shots/{r['file']})")
        lines.append("")
        lines.append(f"应表现:{r.get('description','')}")
        lines.append("")
        sc = c.get("realism_score", -1)
        lines.append(f"- **评分**:{score_text(sc)} — {c.get('verdict','')}")
        if r.get("parse_error"):
            lines.append(f"- _解析备注:{r['parse_error']}_")
        if c.get("problems"):
            lines.append("- **问题**:")
            for p in c["problems"]:
                lines.append(f"  - {p}")
        if c.get("suggestions"):
            lines.append("- **建议**:")
            for s in c["suggestions"]:
                lines.append(f"  - `[{s.get('priority','?')}/{s.get('type','?')}]` {s.get('detail','')}")
        lines.append("")
    with open(out_md, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(f"\n[OK] 报告已写:{out_md}")
    print(f"[OK] 机读版:{out_json}")
    print(f"[OK] 截图副本:{SHOTS_COPY_DIR}")


def main():
    ap = argparse.ArgumentParser(description="VFX 真实度视觉诊断")
    ap.add_argument("--limit", type=int, default=0, help="只评前 N 张(0=全量)")
    ap.add_argument("--shots-dir", default="", help="覆盖 vfx_shots 目录位置")
    ap.add_argument("--host", default=DEFAULT_HOST)
    ap.add_argument("--model", default=DEFAULT_MODEL)
    ap.add_argument("--out-md", default=DEFAULT_OUT_MD)
    ap.add_argument("--out-json", default=DEFAULT_OUT_JSON)
    ap.add_argument("--deterministic", action="store_true",
                    help="降噪:温度0 + 每张跑3次取中位数(压制 ±2-3 单次抖动,增量改动必用)")
    args = ap.parse_args()

    shots_dir = locate_shots_dir(args.shots_dir)
    manifest_path = os.path.join(shots_dir, "manifest.json")
    if not os.path.isfile(manifest_path):
        sys.exit(f"[FATAL] 找不到 manifest:{manifest_path}(先跑 vfx_showcase.tscn)")
    manifest = json.load(open(manifest_path, encoding="utf-8"))
    keys = load_keys()
    print(f"shots_dir = {shots_dir}")
    print(f"keys = {len(keys)} 个, model = {args.model}, host = {args.host}")

    # 展平为 capture 列表
    tasks = []
    for shot in manifest.get("shots", []):
        for cap in shot.get("captures", []):
            tasks.append({
                "id": shot["id"],
                "category": shot.get("category", ""),
                "description": shot.get("description", ""),
                "era": shot.get("era", ""),
                "ref_weapon": shot.get("ref_weapon", ""),
                "file": cap["file"],
                "png_path": os.path.join(shots_dir, cap["file"]),
            })
    if args.limit > 0:
        tasks = tasks[:args.limit]
    print(f"待评估:{len(tasks)} 张截图\n")

    model_label = args.model + (" [denoise t=0,median/3]" if args.deterministic else "")
    print(f"模式: {'降噪(温度0,×3取中位数)' if args.deterministic else '常规(温度0.3,单次)'}\n")

    results = []
    for i, t in enumerate(tasks, 1):
        print(f"[{i}/{len(tasks)}] {t['file']} ...", end=" ", flush=True)
        if args.deterministic:
            res = review_one_deterministic(args.host, keys, args.model, t["png_path"], t, n=3)
        else:
            res = review_one(args.host, keys, args.model, t["png_path"], t)
        c = res["critique"] or {}
        dn = res.get("denoise")
        if dn:
            print(f"score={score_text(c.get('realism_score',-1))} (runs={dn['scores']}) {res.get('parse_error') or ''}")
        else:
            print(f"score={score_text(c.get('realism_score',-1))} ({res['elapsed_s']}s) {res.get('parse_error') or ''}")
        r = dict(t)
        r.update(res)
        results.append(r)

    write_report(results, args.out_md, args.out_json, model_label)


if __name__ == "__main__":
    main()
