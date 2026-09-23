# -*- coding: utf-8 -*-
"""把审计的像素吸附结果（sx/sy）应用到两张锚点表 + 玩家 JSON。
只更新 snap 后有变化的已标注条目（fx>=0）；MISSING 单位不在此域。"""
import re, json
from pathlib import Path

audit = Path(".godot/agent_tools/fire_audit.txt").read_text(encoding="utf-8").splitlines()
updates = {}  # (side, id) -> (fx, fy_pct)
for l in audit:
    p = l.split("|")
    if len(p) < 12 or not p[2].startswith("st="):
        continue
    kv = {}
    for seg in p[2:]:
        a = seg.split("=")
        if len(a) == 2:
            kv[a[0]] = a[1]
    if "fx" not in kv or float(kv["fx"]) < 0:
        continue
    sx, sy = float(kv.get("sx", "-1")), float(kv.get("sy", "-1"))
    fx, fy = float(kv["fx"]), float(kv["fy"])
    if sx < 0 or (abs(sx - fx) < 5e-4 and abs(sy - fy) < 5e-4):
        continue
    updates[(p[0], p[1])] = (sx, sy * 100.0)
print("snap updates:", len(updates))

srcA = Path("data/card_foot_anchors.gd").read_text(encoding="utf-8")
ff_map = {m.group(1): float(m.group(2)) for m in re.finditer(r'"([\w]+)": ([\d.]+),', srcA.split("const FOOT_FRAC")[1].split("\n}")[0])}


def fx_s(v):
    return ("%.4f" % v).rstrip("0").rstrip(".") if v != int(v) else str(int(v))


# ── 我方表
p2 = Path("data/player_muzzle_anchors.gd")
src2 = p2.read_text(encoding="utf-8")
n2 = 0
for (side, id_), (sx, sy) in updates.items():
    if side != "P":
        continue
    pat = re.compile(r'(\t"%s": \{"fireX": )([\d.]+)(, "fireY_pct": )([\d.]+)' % re.escape(id_))
    src2, n = pat.subn(lambda m: '%s%s%s%s' % (m.group(1), fx_s(sx), m.group(3), fx_s(sy)), src2, count=1)
    n2 += n
p2.write_text(src2, encoding="utf-8")
print("player snapped:", n2)

# ── 敌方表（键解析：直查 → 剥 foe_ → platform 映射）
p = Path("data/muzzle_anchors.gd")
src = p.read_text(encoding="utf-8")
keys = set(re.findall(r'\t"([\w]+)": \{"fireX"', src))
plat = {m.group(1): m.group(2) for m in re.finditer(r'"([\w]+)":\s*"([\w]+)"', src)}
n1 = 0
for (side, id_), (sx, sy) in updates.items():
    if side != "E":
        continue
    base = id_[4:] if id_.startswith("foe_") else id_
    hit = next((k for k in [id_, base, plat.get(base, "")] if k and k in keys), None)
    if hit is None:
        print("  !! no key for", id_)
        continue
    pat = re.compile(r'(\t"%s": \{"fireX": )([\d.]+)(, "fireY_pct": )([\d.]+)' % re.escape(hit))
    src, n = pat.subn(lambda m: '%s%s%s%s' % (m.group(1), fx_s(sx), m.group(3), fx_s(sy)), src, count=1)
    n1 += n
p.write_text(src, encoding="utf-8")
print("enemy snapped:", n1)

# ── JSON
jp = Path("docs/敌我双方卡头脚和开火位置.json")
data = json.loads(jp.read_text(encoding="utf-8"))
by_id = {e["id"]: e for e in data}
nj = 0
for (side, id_), (sx, sy) in updates.items():
    if side != "P" or id_ not in by_id:
        continue
    by_id[id_]["fireX"] = round(sx, 4)
    by_id[id_]["fireY_pct"] = round(sy, 2)
    nj += 1
jp.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ": ")), encoding="utf-8")
print("json snapped:", nj)
