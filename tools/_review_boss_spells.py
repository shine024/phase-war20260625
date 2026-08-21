#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""boss 大招演出 AI 真实度评分（一次性，复用 review_vfx_realism 基建）"""
import base64, json, os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from review_vfx_realism import call_agnes, load_keys, parse_critique

SHOT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "docs", "boss_spell_shots")
cells = json.load(open(os.path.join(SHOT, "manifest.json"), encoding="utf-8"))["cells"]
keys = load_keys()
results = []
for i, c in enumerate(cells):
    b64 = base64.b64encode(open(os.path.join(SHOT, c["file"]), "rb").read()).decode()
    prompt = f"""这是 2D 侧视战术游戏的敌方 boss 大招演出审计截图（暗色审计台）。
- 大招类别:{c.get('label','?')} — 阶段:{c.get('stage','?')}
- 该演出验收规格:{c.get('spec','?')}
- 画面参照:左侧三个青色64px框=我方单位;右侧橙红96px框=敌方相位师基地。参考框/标尺是审计台道具,不是被评估对象。
- 请以"侧视 2D 军事游戏的高水准 boss 大招演出"为基准,只评估特效本身。不要因画风 2D 或背景简陋直接给低分。
只返回 JSON:{{"realism_score": <1-10整数>, "verdict": "<一句话总评>", "problems": ["<具体问题>"], "suggestions": [{{"type":"<param|texture|new_layer>","detail":"<可执行建议>","priority":"<high|med|low>"}}]}}
请诚实、具体、挑剔。"""
    last_err = None
    for attempt in range(3):
        try:
            content, _, _, _ = call_agnes("https://apihub.agnes-ai.cn", keys[(i+attempt) % len(keys)], "agnes-2.5-flash", b64, prompt)
            critique, mode = parse_critique(content)
            if critique.get("realism_score", -1) < 0: raise ValueError("no score")
            break
        except Exception as e:
            last_err = e; time.sleep(2)
    if last_err: critique = {"realism_score": -1, "verdict": str(last_err), "problems": [], "suggestions": []}
    results.append({"cell": c, "result": critique})
    print(f"[{i+1}/{len(cells)}] {c['file']} → {critique.get('realism_score')}/10 {critique.get('verdict','')[:70]}")
valid = [r for r in results if r["result"].get("realism_score", -1) > 0]
print(f"\n平均: {sum(r['result']['realism_score'] for r in valid)/max(len(valid),1):.1f}/10 ({len(valid)}/{len(results)} 有效)")
json.dump(results, open(os.path.join(SHOT, "ai_scores.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
