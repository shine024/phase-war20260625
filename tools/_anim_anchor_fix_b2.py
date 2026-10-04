# -*- coding: utf-8 -*-
"""锚点表修正：把 PA(player_muzzle_anchors)/EA(muzzle_anchors) 的 fireX/fireY_pct/ff
对齐到 B1 实测 + B2/fe 重建后雪碧图的真实炮口位置。

语义（与两表 get_fire_offset 公式严格一致）：
  px_x = (fireX - 0.5) * 256 * s ; py = -(1 - ff - fireY_pct/100) * 256 * s
关键事实（unit_frame_anim.gd 已证）：所有 sheet 原图统一朝左；
  敌方直接用 → 世界炮口 x = mx        → EA: fireX = mx/256
  我方 flip_h 镜像   → 世界炮口 x = 256-mx → PA: fireX = 1 - mx/256
  fireY_pct = my/256*100（距顶百分比，与镜像无关）
  PA 的 ff = anim.json foot_frac（距底，与纹理缩放同基）
只动本批触及单位（B1 实测 ∪ B2 重建）；每文件先备份。dry=只打印不改盘。
"""
import json, os, re, sys, io, shutil
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DRY = "dry" in sys.argv

# B1 实测炮口（正则提取，避免 import 副作用）
_b1_src = open(os.path.join(ROOT, "tools", "_anim_fix_b1_flash.py"), encoding="utf-8").read()
MUZZLE = {}
for _m in re.finditer(r'"([a-z0-9_]+)":\s*\(\((\d+),\s*(\d+)\),\s*"([a-z_]+)",\s*(-?[0-9]+),', _b1_src):
    MUZZLE[_m.group(1)] = (int(_m.group(2)), int(_m.group(3)))

# B1 补刀实测修正（_anim_fix_b1b_flash_left.py，网格放大定读；全部朝左开火）
MUZZLE.update({
    "cold_arm_t55": (6, 132), "cold_t72": (8, 180), "cold_inf_btr60": (94, 132),
    "fut_arm_hovertank": (12, 205), "mod_arm_himars": (114, 48), "ww1_arm_rolls": (4, 129),
    "ww2_arm_sherman": (12, 128), "ww2_inf_hellcat": (10, 131), "cold_sam7": (58, 8),
})

SKIP = {"ww2_sup_gmc_truck",  # 无开火（攻击=待机式）
        "vis_xeno_dark_templar"}  # 近战镰刀

DUMP = json.load(open(os.path.join(ROOT, "_anim_review", "card_anim_dump.json"), encoding="utf-8"))
rows = {}
for sec in ("players", "enemies", "platforms", "captured"):
    for r in DUMP.get(sec, []):
        if isinstance(r, dict) and r.get("id") and r["id"] not in rows:
            r["_sec"] = sec
            rows[r["id"]] = r

B2 = [l.split('"')[1] for l in open(os.path.join(ROOT, "tools", "_anim_redo_b2_rebuild.py"), encoding="utf-8")
      if l.strip().startswith('("')]


def detect_muzzle(anim_key):
    """build() 同款规则 @256：最左 24px 带(12px@256)实心行中位。所有 sheet 朝左 → 炮口在最左带。"""
    p = os.path.join(ROOT, "assets", "effects", "unit_anims", anim_key, "sheet_idle.png")
    if not os.path.isfile(p):
        return None
    im = np.asarray(Image.open(p).convert("RGBA"))
    fr = im[:, :256, :]
    solid = fr[:, :, 3] > 128
    cols = np.where(solid.any(axis=0))[0]
    if not len(cols):
        return None
    c0 = int(cols.min())
    tip = np.where(solid[:, c0:min(c0 + 12, 256)].any(axis=1))[0]
    if not len(tip):
        return None
    return (c0 + 3, int(np.median(tip)))


TOUCHED = {k for k in set(MUZZLE) | set(B2) if k not in SKIP}
targets = []
seen = set()
for rid, row in rows.items():
    ak = row.get("anim_key")
    if not ak or ak not in TOUCHED or rid in seen:
        continue
    seen.add(rid)
    mxmy = MUZZLE.get(ak) or detect_muzzle(ak)
    if not mxmy:
        print("!! 无炮口，跳过:", rid)
        continue
    aj = os.path.join(ROOT, "assets", "effects", "unit_anims", ak, "anim.json")
    ff_bot = json.load(open(aj, encoding="utf-8")).get("foot_frac")
    if ff_bot is None:
        print("!! 无 foot_frac，跳过:", rid)
        continue
    targets.append(dict(id=rid, sec=row["_sec"], ak=ak,
                        mx=mxmy[0], my=mxmy[1], ff_bot=float(ff_bot)))
print("目标 %d 单位" % len(targets))

# fe_ 13 案：dump 是旧快照（anim_key 仍是旧族键），按新目录显式补目标
FE13 = ["fe_iron_wall_bastion", "fe_nova_devastator", "fe_nova_ghost_sniper",
        "fe_aether_hover_cavalry", "fe_aether_swarm_queen", "fe_quantum_mobile_base",
        "fe_quantum_repair_drone", "fe_helix_orbital_strike", "fe_void_phase_cannon",
        "fe_void_dimensional_soldier", "fe_frontier_veteran", "fe_frontier_mixed_company",
        "fe_iron_wall_juggernaut"]
_have = {t["id"] for t in targets}
for k in FE13:
    if k in _have:
        continue
    mxmy = detect_muzzle(k)
    aj = os.path.join(ROOT, "assets", "effects", "unit_anims", k, "anim.json")
    ff_bot = json.load(open(aj, encoding="utf-8")).get("foot_frac") if os.path.isfile(aj) else None
    if not mxmy or ff_bot is None:
        print("!! fe 缺料，跳过:", k, mxmy, ff_bot)
        continue
    targets.append(dict(id=k, sec="players", ak=k, mx=mxmy[0], my=mxmy[1], ff_bot=float(ff_bot)))
print("补 fe 后目标 %d 单位" % len(targets))


def fmt(v):
    return ("%.4f" % v).rstrip("0").rstrip(".")


def patch_table(path, const_name, side):
    """side='PA'|'EA'。"""
    txt = open(path, encoding="utf-8").read()
    mb = re.search(r"const %s: Dictionary = \{(.*?)\n\}" % const_name, txt, re.S)
    body = mb.group(1)
    entries = dict(re.findall(r'"([a-z0-9_]+)":\s*\{([^}]*)\}', body))
    changed, added = 0, 0
    for t in targets:
        if side == "PA" and t["sec"] not in ("players", "captured", "platforms"):
            continue
        if side == "EA" and t["sec"] != "enemies":
            continue
        mx, my, fb = t["mx"], t["my"], t["ff_bot"]
        fy = my / 256.0 * 100.0  # fireY_pct=距顶百分比
        fx = (1.0 - mx / 256.0) if side == "PA" else (mx / 256.0)  # 阵营镜像，唯二公式
        new_pair = '"fireX": %s, "fireY_pct": %s' % (fmt(fx), fmt(round(fy, 2)))
        if t["id"] in entries:
            old = entries[t["id"]]
            new = re.sub(r'"fireX":\s*[0-9.]+,\s*"fireY_pct":\s*[0-9.]+', new_pair, old)
            if side == "PA":
                new = re.sub(r'"ff":\s*[0-9.]+', '"ff": %s' % fmt(fb), new)
            if new != old:
                new_body = body.replace('"%s": {%s}' % (t["id"], old), '"%s": {%s}' % (t["id"], new), 1)
                txt = txt[:mb.start(1)] + new_body + txt[mb.end(1):]
                mb = re.search(r"const %s: Dictionary = \{(.*?)\n\}" % const_name, txt, re.S)
                body = mb.group(1)
                entries[t["id"]] = new
                changed += 1
        else:
            parts = [new_pair]
            if side == "PA":
                parts.append('"ff": %s' % fmt(fb))
                parts.append('"hf": %s' % fmt(max(fb, 0.02)))
            ins = '\t"%s": {%s},\n' % (t["id"], ", ".join(parts))
            body = body + ins
            txt = txt[:mb.start(1)] + body + txt[mb.end(1):]
            mb = re.search(r"const %s: Dictionary = \{(.*?)\n\}" % const_name, txt, re.S)
            entries[t["id"]] = ", ".join(parts)
            added += 1
    if not DRY:
        bdir = os.path.join(ROOT, ".godot", "art_backup_b2_rebuild_20261003", "_anchors")
        os.makedirs(bdir, exist_ok=True)
        bp = os.path.join(bdir, os.path.basename(path))
        if not os.path.isfile(bp):
            shutil.copy2(path, bp)
        open(path, "w", encoding="utf-8").write(txt)
    print("%s: 改 %d 增 %d%s" % (side, changed, added, " (dry)" if DRY else ""))
    # 样例打印
    for t in targets[:0]:
        pass
    for tid in (t["id"] for t in targets):
        if tid in entries and (tid.startswith(("cold_t72", "ww2_panther", "cold_arm_t55", "fe_", "ww2_air"))):
            print("  样例 %s: %s" % (tid, entries[tid]))


PA_P = os.path.join(ROOT, "data", "player_muzzle_anchors.gd")
EA_P = os.path.join(ROOT, "data", "muzzle_anchors.gd")
patch_table(PA_P, "PLAYER_MUZZLE", "PA")
patch_table(EA_P, "MUZZLE", "EA")
