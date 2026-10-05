# -*- coding: utf-8 -*-
"""MK11 贴边截断修复批（2026-10-05）：审查页 clip 探针命中的攻击条统一修复。
背景：v6.44 闭环审计发现 12 单位攻击帧贴边（idle 有富余的侧被攻击帧触到=部署 pop/像素截断）。
修法：整条攻击帧统一缩放（s=按最坏帧清空四边至 EDGE+1，cap≥0.80），
底缘=原内容底（地线不动，foot_frac 稳），水平=原内容质心。已烘描边随缩放略细，接受。
rolls/rolls_e/m4 等 12 案；备份 .godot/art_backup_mk11_20261005/（if-not-exists）。
用法: python tools/_mk11_clip_fix.py [plan|apply|verify]
"""
import io
import json
import os
import re
import shutil
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BAK = os.path.join(ROOT, ".godot", "art_backup_mk11_20261005")
EDGE = 2
MARGIN = EDGE + 1


def backup_once(path, unit):
    if not os.path.exists(path):
        return
    d = os.path.join(BAK, unit)
    os.makedirs(d, exist_ok=True)
    dst = os.path.join(d, os.path.basename(path))
    if not os.path.exists(dst):
        shutil.copy2(path, dst)
        print("  [bak] %s/%s" % (unit, os.path.basename(path)), flush=True)


def load_rows():
    html = open(os.path.join(ROOT, "tools", "card_anim_review.html"), encoding="utf-8").read()
    data = json.loads(re.search(r"const DATA = (\{.*?\});\n", html, re.S).group(1))
    rows = {}

    def richer(a, b):
        """同 id 多节行：优先带探针数据（sus/flags/anim 齐全）的那个。"""
        def score(r):
            return len(r.get("sus") or []) + len(r.get("flags") or []) + bool(r.get("anim"))
        return a if score(a) >= score(b) else b
    for sec in data["sections"]:
        for r in sec.get("rows", []):
            rows[r["id"]] = richer(rows.get(r["id"], r), r)
    return rows


def content_bbox(fr):
    import numpy as np
    al = np.asarray(fr)[:, :, 3]
    ys, xs = np.where(al > 10)
    if not len(ys):
        return None
    return (int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max()))


def plan_rows(rows):
    """clip 命中行（判据与探针一致：仅 idle 有富余的侧计数）。
    s 按计数侧约束算（内容重排=居中+地线锚定后清至 MARGIN），s 可为 1.0（纯居中重排）。"""
    from PIL import Image
    plans, seen = [], set()
    for rid, r in sorted(rows.items()):
        if "clip" not in (r.get("sus") or []):
            continue
        a = r.get("anim") or {}
        pa = (a.get("sheet_attack") or "").lstrip("./")
        pi = (a.get("sheet_idle") or "").lstrip("./")
        if not pa or pa in seen:
            continue
        seen.add(pa)
        idle = Image.open(os.path.join(ROOT, pi)).convert("RGBA")
        fs = idle.height
        fr = [content_bbox(idle.crop((i * fs, 0, (i + 1) * fs, fs)))
              for i in range(idle.width // fs)]
        fr = [c for c in fr if c]
        iL = min(c[0] for c in fr)
        iR = min(fs - 1 - c[2] for c in fr)
        iT = min(c[1] for c in fr)
        atk = Image.open(os.path.join(ROOT, pa)).convert("RGBA")
        s_min, hits = 1.0, []
        for i in range(atk.width // fs):
            c = content_bbox(atk.crop((i * fs, 0, (i + 1) * fs, fs)))
            if not c:
                continue
            x0, y0, x1, y1 = c
            hit = ((x0 <= EDGE and iL > EDGE) or (x1 >= fs - 1 - EDGE and iR > EDGE)
                   or (y0 <= EDGE and iT > EDGE))
            if not hit:
                continue
            cx = (x0 + x1) / 2.0
            s = 1.0
            if iL > EDGE or iR > EDGE:
                s = min(s, (fs / 2.0 - MARGIN) / max(cx - x0, x1 - cx, 1e-3))
            if iT > EDGE:
                s = min(s, (y1 + 1 - MARGIN) / max(y1 - y0 + 1, 1e-3))
            hits.append((i, c, s))
            s_min = min(s_min, s)
        if hits:
            plans.append(dict(rid=rid, atk=pa, fs=fs, s=max(s_min, 0.80),
                              iL=iL, iR=iR, iT=iT, hits=[h[0] + 1 for h in hits]))
    return plans


def apply_plan(p):
    from PIL import Image
    import numpy as np
    pa = os.path.join(ROOT, p["atk"])
    backup_once(pa, p["rid"])
    atk = Image.open(pa).convert("RGBA")
    fs = p["fs"]
    s = p["s"]
    iL, iR, iT = p["iL"], p["iR"], p["iT"]
    out = Image.new("RGBA", atk.size, (0, 0, 0, 0))
    for i in range(atk.width // fs):
        fr = atk.crop((i * fs, 0, (i + 1) * fs, fs))
        c = content_bbox(fr)
        if c is None:
            out.paste(fr, (i * fs, 0))
            continue
        x0, y0, x1, y1 = c
        cx = (x0 + x1) / 2.0
        # 逐帧安全比例：全局 s 基础上，受检侧的刀口帧（宽>250 等）局部再缩 ≤1%
        s_f = s
        if iL > EDGE or iR > EDGE:
            s_f = min(s_f, (fs / 2.0 - MARGIN) / max(cx - x0, x1 - cx, 1e-3))
        if iL > EDGE and iR > EDGE:
            s_f = min(s_f, (fs - 2.0 * MARGIN) / max(x1 - x0 + 1, 1e-3))
        if iT > EDGE:
            s_f = min(s_f, (y1 + 1 - MARGIN) / max(y1 - y0 + 1, 1e-3))
        crop = fr.crop((x0, y0, x1 + 1, y1 + 1))
        nw, nh = max(1, int(round(crop.width * s_f))), max(1, int(round(crop.height * s_f)))
        crop = crop.resize((nw, nh), Image.LANCZOS)
        base = Image.new("RGBA", (fs, fs), (0, 0, 0, 0))
        # 内容质心→格中心：按缩放后的质心左距 (cx-x0)*s 贴位（nw/2 在不对称内容上差半格，
        # 会把贴边侧顶回 EDGE 内——MK11 首轮 46 帧假修复的根因）
        px = int(round(fs / 2.0 - (cx - x0) * s_f))
        if iR > EDGE:                                 # 右侧受检：硬保右
            px = min(px, fs - MARGIN - nw)
        if iL > EDGE:                                 # 左侧受检：硬保左
            px = max(px, MARGIN)
        py = y1 + 1 - nh                              # 原地线不动
        if iT > EDGE:                                 # 顶缘受检：硬保顶
            py = max(py, MARGIN)
        base.paste(crop, (px, py), crop)
        out.paste(base, (i * fs, 0))
    out.save(pa)
    print("  [fix] %-28s s=%.3f 帧%s" % (p["rid"], s, p["hits"]), flush=True)


def verify(rows):
    import numpy as np
    from PIL import Image
    seen = set()
    bad = 0
    for rid, r in sorted(rows.items()):
        if "clip" not in (r.get("sus") or []):
            continue
        a = r.get("anim") or {}
        pa = (a.get("sheet_attack") or "").lstrip("./")
        pi = (a.get("sheet_idle") or "").lstrip("./")
        if not pa or pa in seen:
            continue
        seen.add(pa)
        idle = Image.open(os.path.join(ROOT, pi)).convert("RGBA")
        fs = idle.height
        fr = [content_bbox(idle.crop((i * fs, 0, (i + 1) * fs, fs)))
              for i in range(idle.width // fs)]
        fr = [c for c in fr if c]
        iL = min(c[0] for c in fr); iR = min(fs - 1 - c[2] for c in fr); iT = min(c[1] for c in fr)
        atk = Image.open(os.path.join(ROOT, pa)).convert("RGBA")
        res = []
        for i in range(atk.width // fs):
            c = content_bbox(atk.crop((i * fs, 0, (i + 1) * fs, fs)))
            if not c:
                continue
            hits = []
            if c[0] <= EDGE and iL > EDGE: hits.append("L")
            if c[2] >= fs - 1 - EDGE and iR > EDGE: hits.append("R")
            if c[1] <= EDGE and iT > EDGE: hits.append("T")
            if hits:
                res.append("f%d:%s" % (i + 1, "".join(hits)))
        print("  %-28s %s" % (rid, " ".join(res) if res else "OK"))
        bad += len(res)
    print("verify: %s" % ("仍有 %d 帧贴边" % bad if bad else "全部清零"))


def rescale_sheet(unit, kind, s):
    """size 修复：整条 sheet 内容统一缩 s，锚定内容底缘(地线)+水平质心。缩小 only。"""
    from PIL import Image
    import numpy as np
    pa = os.path.join(ROOT, "assets", "effects", "unit_anims", unit, "sheet_%s.png" % kind)
    if not os.path.isfile(pa):
        print("  [skip] %s 无 sheet_%s" % (unit, kind), flush=True)
        return
    backup_once(pa, unit)
    atk = Image.open(pa).convert("RGBA")
    fs = atk.height
    out = Image.new("RGBA", atk.size, (0, 0, 0, 0))
    for i in range(atk.width // fs):
        fr = atk.crop((i * fs, 0, (i + 1) * fs, fs))
        c = content_bbox(fr)
        if c is None:
            out.paste(fr, (i * fs, 0))
            continue
        x0, y0, x1, y1 = c
        cx = (x0 + x1) / 2.0
        crop = fr.crop((x0, y0, x1 + 1, y1 + 1))
        nw, nh = max(1, int(round(crop.width * s))), max(1, int(round(crop.height * s)))
        crop = crop.resize((nw, nh), Image.LANCZOS)
        base = Image.new("RGBA", (fs, fs), (0, 0, 0, 0))
        px = int(round(cx - nw / 2.0))                 # 水平质心不动
        py = y1 + 1 - nh                               # 地线不动
        base.paste(crop, (px, py), crop)
        out.paste(base, (i * fs, 0))
    out.save(pa)
    print("  [size] %-24s sheet_%-6s s=%.3f" % (unit, kind, s), flush=True)


def main():
    ph = sys.argv[1] if len(sys.argv) > 1 else "plan"
    rows = load_rows()
    if ph == "plan":
        for p in plan_rows(rows):
            print("  [plan] %-28s s=%.3f 帧%s" % (p["rid"], p["s"], p["hits"]), flush=True)
    elif ph == "apply":
        for p in plan_rows(rows):
            apply_plan(p)
    elif ph == "size":
        for unit, sz in (("fut_arm_colossus_e", 1.49), ("mod_air_multirole", 1.47),
                         ("fut_nano_drone", 1.51)):
            s = 1.0 / sz
            rescale_sheet(unit, "idle", s)
            rescale_sheet(unit, "attack", s)
    elif ph == "verify":
        verify(rows)


if __name__ == "__main__":
    main()
