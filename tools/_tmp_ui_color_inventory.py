# -*- coding: utf-8 -*-
"""R-D1 颜色库存扫描：grep scenes/scripts/resources 下的 Color(...) 与 #hex 字面量，
按裁决表语义（金/血条绿/危险红/强调青）聚类输出 docs/UI颜色库存表_2026-09-20.md。
只统计被裁决表点名的字面量值；DT.* 引用不计。"""
import os, re, collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCAN_DIRS = ["scenes", "scripts", "resources", "managers", "data"]
SKIP_DIRS = {".godot", "_archived", "_art_backup", "addons"}

# 裁决表点名的字面量（float 归一化匹配）
TARGETS = {
    # 金
    "Color(1.0, 0.85, 0.35, 1)": "金 DT.COLOR_GOLD 本体（token 源，保留）",
    "Color(1, 0.85, 0.35, 1)": "金 DT.COLOR_GOLD 本体（token 源，保留）",
    "Color(0.85, 0.75, 0.35": "金旧档 → DT.COLOR_GOLD",
    "Color(0.9, 0.7, 0.3": "金旧档 → DT.COLOR_GOLD",
    "Color(0.941, 0.706, 0.161": "金旧档 → DT.COLOR_GOLD",
    "FFD700": "违禁纯金 → DT.COLOR_GOLD",
    "Color(1, 0.92, 0.55": "淡金 → DT.COLOR_GOLD_SOFT",
    "Color(1.0, 0.92, 0.55": "淡金 → DT.COLOR_GOLD_SOFT",
    "Color(0.992, 0.902, 0.541": "淡金 → DT.COLOR_GOLD_SOFT",
    # 血条绿
    "Color(0.2, 0.9, 0.4": "血条绿 DT.COLOR_HEALTH 旧值",
    "Color(0.2, 0.75, 0.35": "血条绿新基准（unit_hp_bar 实际值）",
    "Color(0.247, 0.902, 0.427": "血条绿 → 对齐 0.2/0.75/0.35",
    "Color(0.3, 0.92, 0.5": "GREEN_BRIGHT 亮绿强调（保留 token，不并入）",
    # 危险红
    "Color(0.9, 0.2, 0.2": "危险红 → COLOR_RED_DOWN",
    "Color(0.937, 0.267, 0.267": "危险红基准（COLOR_RED_DOWN 本体，保留）",
    "Color(1, 0.3, 0.3": "危险红 → COLOR_RED_DOWN",
    "Color(0.95, 0.4, 0.4": "危险红弱档 → COLOR_RED_DOWN",
    "Color(0.94, 0.27, 0.27": "危险红 → COLOR_RED_DOWN",
    "FF4466": "危险红 hex → COLOR_RED_DOWN",
    "ff7b72": "危险红 hex → COLOR_RED_DOWN",
    # 强调青双写法
    "Color(0, 0.941, 1": "青双写法 → 0, 0.94, 1",
}

pat_color = re.compile(r"Color\(([^)]*)\)")
pat_hex = re.compile(r"#[0-9a-fA-F]{6}\b")

def norm_rgb(rgb_str):
    parts = [p.strip() for p in rgb_str.split(",")]
    if len(parts) < 3:
        return None
    try:
        vals = [round(float(parts[i]), 3) for i in range(3)]
    except ValueError:
        return None
    def fmt(v):
        return str(int(v)) if v == int(v) else ("%g" % v)
    return "Color(%s, %s, %s" % (fmt(vals[0]), fmt(vals[1]), fmt(vals[2]))

hits = collections.defaultdict(list)  # target -> [(file, line, text)]
for d in SCAN_DIRS:
    base = os.path.join(ROOT, d)
    for dirpath, dirnames, filenames in os.walk(base):
        dirnames[:] = [x for x in dirnames if x not in SKIP_DIRS]
        for fn in filenames:
            if not fn.endswith((".gd", ".tscn", ".tres")):
                continue
            p = os.path.join(dirpath, fn)
            try:
                with open(p, encoding="utf-8", errors="ignore") as f:
                    for lineno, line in enumerate(f, 1):
                        if "DT." in line or "DesignTokens." in line:
                            # token 引用不扫，但同行带字面量的仍扫（半 token 半字面量）
                            if not (pat_color.search(line) or pat_hex.search(line)):
                                continue
                        for m in pat_color.finditer(line):
                            key = norm_rgb(m.group(1))
                            if key:
                                for t in TARGETS:
                                    if key.startswith(t.rstrip(", ").rstrip() ) or key == t:
                                        if t in key or key.startswith(t):
                                            hits[t].append((os.path.relpath(p, ROOT), lineno, line.strip()[:150]))
                                        break
                        for m in pat_hex.finditer(line):
                            h = m.group(0)
                            for t in ("FFD700", "FF4466", "ff7b72"):
                                if h.lower() == t.lower():
                                    hits[t].append((os.path.relpath(p, ROOT), lineno, line.strip()[:150]))
            except OSError:
                pass

out = ["# UI 颜色库存表（R-D1 裁决表点名值扫描）", "",
       "> 生成：tools/_tmp_ui_color_inventory.py（2026-09-20）",
       "> 范围 scenes/scripts/resources/managers/data 的 .gd/.tscn/.tres；DT.* 引用不计入。", ""]
total = 0
for t, lst in sorted(hits.items(), key=lambda kv: -len(kv[1])):
    total += len(lst)
    out.append("## %s — %d 处（%s）" % (t, len(lst), TARGETS[t]))
    for f, ln, txt in lst:
        out.append("- %s:%d `%s`" % (f, ln, txt))
    out.append("")
out.insert(5, "**总计 %d 处待收敛**（不含 token 源与 GREEN_BRIGHT 保留档的行数见明细）" % total)
with open(os.path.join(ROOT, "docs", "UI颜色库存表_2026-09-20.md"), "w", encoding="utf-8") as f:
    f.write("\n".join(out))
print("SCANNED_TOTAL=%d" % total)
for t, lst in sorted(hits.items(), key=lambda kv: -len(kv[1])):
    print("%-40s %d" % (t, len(lst)))
