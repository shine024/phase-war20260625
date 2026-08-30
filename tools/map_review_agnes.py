#!/usr/bin/env python3
"""主地图候选图视觉评审 —— 用 agnes-2.5-flash（多模态）按需求文档做眼感检查。

用法：
    python tools/map_review_agnes.py <候选图.png> [更多.png ...]

程序量化检查（tools/check_main_map.py）看不了"有没有农田房子/废墟年代感/文字水印"
这类语义项，本脚本把图发给 agnes 多模态模型按检查单打分。
"""
import base64
import io
import json
import sys
import urllib.request

from PIL import Image

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

API = "https://apihub.agnes-ai.cn/v1/chat/completions"
MODEL = "agnes-2.5-flash"
KEY = next(ln.strip() for ln in open("tools/_api_key.txt", encoding="utf-8") if ln.strip())

CHECKLIST = """你是游戏主地图验收员。这张图应当是：手绘水彩风格的俯视大陆战争地图，
陆地为格陵兰岛旋转90°横放（西端宽圆、东端收窄成尖角），海只在上下边缘条带和东尖角外侧。
请逐项检查并只输出一个 JSON 对象（不要 markdown 代码块，不要其他文字）：
{
 "contour_ok": 陆地轮廓是否为"西宽东尖"的横放格陵兰形（布尔),
 "contour_note": "轮廓主要偏差一句话",
 "scale_violation": 是否能看到单栋建筑/房屋/农田田块/道路线/战壕线等近距离人工物（true=违规),
 "violation_note": "违规物在哪、是什么；没有则空串",
 "ruins_gradient": 废墟痕迹是否呈西旧东新渐变（西=白垩色疤痕斑,中=灰焦/工业灰,东=深色废都块,东尖最密+青光)（布尔),
 "ruins_note": "废墟分布一句话",
 "gate": 东端尖角附近是否有纯黑圆盘+浅青环的传送门（布尔),
 "stripes": 是否存在横向条带/平行地貌带/网格经纬线（true=违规),
 "text_frame": 是否有文字/水印/画框/罗盘（true=违规),
 "cyan_excess": 是否被大面积纯青色支配（true=违规),
 "style_strength": "手绘水彩质感:强/中/弱",
 "overall": "pass 或 fail",
 "main_problem": "最需要修的一个问题，一句话"
}"""


def ask(image_path: str) -> str:
    im = Image.open(image_path).convert("RGB")
    w, h = im.size
    if w > 1280:
        im = im.resize((1280, int(h * 1280 / w)), Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=88)
    b64 = base64.b64encode(buf.getvalue()).decode()
    payload = {
        "model": MODEL,
        "messages": [{
            "role": "user",
            "content": [
                {"type": "text", "text": CHECKLIST},
                {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64," + b64}},
            ],
        }],
        "max_tokens": 2500,  # 推理模型：reasoning 也占预算，太小会空 content
        "temperature": 0.1,
    }
    req = urllib.request.Request(
        API, data=json.dumps(payload).encode(),
        headers={"Authorization": "Bearer " + KEY, "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=180) as r:
        data = json.loads(r.read().decode())
    return data["choices"][0]["message"]["content"]


def main() -> int:
    ok = True
    for p in sys.argv[1:]:
        print(f"\n══ 视觉评审 {p}")
        try:
            text = ask(p)
        except Exception as exc:
            print(f"   ✗ 视觉评审不可用：{exc}")
            ok = False
            continue
        t = text.strip()
        if t.startswith("```"):
            t = t.strip("`")
            t = t[t.index("{"):] if "{" in t else t
        try:
            verdict = json.loads(t[t.index("{"): t.rindex("}") + 1])
        except Exception:
            print(f"   ⚠ 非结构化回复：{text[:600]}")
            ok = False
            continue
        for k, v in verdict.items():
            mark = ""
            if isinstance(v, bool):
                mark = "✓" if (k in ("contour_ok", "ruins_gradient", "gate") and v) or \
                              (k in ("scale_violation", "stripes", "text_frame", "cyan_excess") and not v) \
                       else "✗"
            print(f"   {mark:1s} {k:16s} {v}")
        ok &= verdict.get("overall") == "pass"
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
