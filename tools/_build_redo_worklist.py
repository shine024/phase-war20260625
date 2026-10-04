# -*- coding: utf-8 -*-
"""从审查页标注导出生成重做工作单。

规则（用户拍板 2026-10-03）：
  有备注 或 选定重做(r=yes)  -> 重做
  无备注 且 未选定(r!=yes)   -> 接受（不改）；若 a=alt:xxx 则只需接线换动画
"""
import json, re, sys, io

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

SRC = "card_anim_review_marks (要修改的).json"
OUT = "card_anim_redo_worklist.json"

data = json.load(open(SRC, encoding="utf-8"))
marks = data["marks"]

TAGMAP = {"clip": "clip_fix", "size": "size_fix", "bg": "bg_clean",
          "face": "face_fix", "diff": "anim_regen", "other": "anim_regen"}

out = {"source": data.get("exported"), "redo": {}, "accept": {}, "wire": {}}

for uid, m in marks.items():
    n = (m.get("n") or "").strip()
    p = set(m.get("p") or [])
    r = m.get("r") or ""
    a = m.get("a") or ""

    if not n and r != "yes":
        if a.startswith("alt:"):
            out["wire"][uid] = {"alt": a.split(":", 1)[1]}
        else:
            out["accept"][uid] = {"r": r}
        continue

    t = []
    def add(x):
        if x not in t:
            t.append(x)

    # 卡图类
    if "补卡图" in n:
        add("card_create")
    if "要用生图" in n or "卡图" in n or "图片" in n:
        add("card_regen")
    if re.search(r"没正侧面|不是正侧面|正侧方", n):
        add("side_view_fix")
    if "半身" in n or "全身" in n:
        add("framing_fix")
    # 开火 / 火光
    if re.search(r"没火光|没开火", n):
        add("attack_fire")
    elif "火光" in n:
        add("attack_fire")
    if "开火位置" in n:
        add("fire_anchor")
    if "方向反" in n:
        add("attack_regen")
    # 重做范围
    if re.search(r"全重做|都重做|都要重做|都要重作|都重生成|全重做", n):
        add("idle_regen"); add("attack_regen")
    else:
        if "待机" in n:
            add("idle_regen")
        if "攻击" in n:
            add("attack_regen")
    if "抬枪" in n or "攻击姿势" in n:
        add("codeanim_pose")
    if "摆动" in n or "太摆" in n:
        add("idle_amplitude")
    if "灯" in n:
        add("idle_regen")
    if "地面" in n or "背景" in n:
        add("bg_clean")
    if "抠" in n:
        add("clip_fix")
    if "调整大小" in n:
        add("size_fix")
    # 自动检测标签
    for tag in p:
        add(TAGMAP[tag])
    # r=yes 无备注无标签 = 整列重做
    if not t:
        add("idle_regen"); add("attack_regen")

    out["redo"][uid] = {"note": n, "tags": sorted(p), "alt": a, "tasks": t}

json.dump(out, open(OUT, "w", encoding="utf-8"), ensure_ascii=False, indent=1)

# ── 汇总 ──
print("重做 %d | 接受 %d | 接线 %d" % (len(out["redo"]), len(out["accept"]), len(out["wire"])))
print("接受:", ", ".join(sorted(out["accept"])))
print("接线:", ", ".join("%s->%s" % (k, v["alt"]) for k, v in out["wire"].items()))

hist = {}
for uid, e in out["redo"].items():
    for t in e["tasks"]:
        hist[t] = hist.get(t, 0) + 1
print("\n任务直方图:", ", ".join("%s=%d" % kv for kv in sorted(hist.items(), key=lambda x: -x[1])))

B1 = {"fire_anchor", "attack_fire", "clip_fix"}
B3 = {"codeanim_pose"}
B4 = {"card_create", "card_regen", "side_view_fix", "framing_fix"}
b1, b2, b3, b4, mix = [], [], [], [], []
for uid, e in out["redo"].items():
    ts = set(e["tasks"])
    if ts & B3:
        b3.append(uid)
    elif ts & B4:
        (b4 if not (ts - B4 - {"bg_clean", "size_fix"}) else mix).append(uid)
    elif ts <= B1:
        b1.append(uid)
    else:
        b2.append(uid)
for name, lst in (("B1锚点火光截断", b1), ("B2动画重做", b2), ("B3姿势脚本", b3), ("B4卡图", b4), ("MIX混合", mix)):
    print("\n[%s] %d" % (name, len(lst)))
    for u in sorted(lst):
        print("  %s  %s" % (u, "+".join(out["redo"][u]["tasks"])))
