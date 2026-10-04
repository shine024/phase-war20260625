# -*- coding: utf-8 -*-
"""2026-10-03 战斗美术全链路静态审计（卡图/动作帧/弹道贴图/技能特效）。

四个维度:
  A. PNG import 侧车完整性 —— assets/ 全树 .png 必须有同名 .import（占位图假绿防线）
  B. unit_anims 结构校验 —— anim.json 合法性 / sheet 尺寸 vs counts / foot_frac 在位 /
     空帧 / 实心(alpha>=128)触边（帧缘振铃&裁切）/ outline.baked 标记
  C. 卡图覆盖 —— card_icons/player+enemy 对 unit_anims 键与战斗卡的缺口
  D. 特效贴图引用 —— assets/effects PNG 被源码引用情况（死链对棘轮基线 64）

输出: 控制台分节摘要 + JSON 落盘 .godot/battle_art_audit_1003.json
"""
import json
import os
import struct
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
OUT_JSON = os.path.join(ROOT, ".godot", "battle_art_audit_1003.json")

report = {"A_import": {}, "B_anims": {}, "C_cards": {}, "D_vfx": {}}

# ---------- A. import 侧车 ----------
missing_import = []
png_total = 0
for dp, _, fns in os.walk(os.path.join(ROOT, "assets")):
    for fn in fns:
        if not fn.lower().endswith(".png"):
            continue
        png_total += 1
        if fn + ".import" not in fns:
            missing_import.append(os.path.relpath(os.path.join(dp, fn), ROOT).replace(os.sep, "/"))
report["A_import"] = {"png_total": png_total, "missing": sorted(missing_import),
                      "missing_count": len(missing_import)}
print(f"[A] PNG total={png_total}  missing .import={len(missing_import)}")
for m in missing_import[:30]:
    print(f"    MISSING {m}")

# ---------- B. unit_anims ----------
UA = os.path.join(ROOT, "assets", "effects", "unit_anims")
anim_issues = []
dirs = sorted(d for d in os.listdir(UA) if os.path.isdir(os.path.join(UA, d)))


def png_size(path):
    with open(path, "rb") as f:
        head = f.read(24)
    if head[:8] != b"\x89PNG\r\n\x1a\n" or head[12:16] != b"IHDR":
        return None
    w, h = struct.unpack(">II", head[16:24])
    return w, h


def png_frames(path):
    """逐帧取 alpha 掩膜（PIL+numpy，毫秒级）。"""
    import numpy as np
    from PIL import Image
    try:
        img = Image.open(path).convert("RGBA")
    except Exception as e:  # noqa: BLE001
        return None, None, str(e)
    arr = np.asarray(img)
    return arr[:, :, 3], arr.shape[1], arr.shape[0], None


for d in dirs:
    adir = os.path.join(UA, d)
    aj = os.path.join(adir, "anim.json")
    entry = {"dir": d}
    if not os.path.exists(aj):
        entry["err"] = "no_anim_json"
        anim_issues.append(entry)
        continue
    try:
        meta = json.load(open(aj, encoding="utf-8"))
    except Exception as e:
        entry["err"] = f"anim_json_parse:{e}"
        anim_issues.append(entry)
        continue
    fs = meta.get("frame_size")
    counts = meta.get("counts", {})
    if not fs or not counts:
        entry["err"] = "anim_json_missing_fields"
        anim_issues.append(entry)
        continue
    entry["frame_size"] = fs
    problems = []
    # sheet 文件与尺寸
    for kind in ("idle", "attack"):
        n = counts.get(kind, 0)
        sheet_rel = os.path.join(adir, f"sheet_{kind}.png")
        if n > 0:
            if not os.path.exists(sheet_rel):
                problems.append(f"missing_sheet_{kind}")
                continue
            if not os.path.exists(sheet_rel + ".import"):
                problems.append(f"missing_import_{kind}")
            w, h = png_size(sheet_rel)
            if w != n * fs or h != fs:
                problems.append(f"sheet_{kind}_dim:{w}x{h}!= {n}x{fs}")
        elif os.path.exists(sheet_rel):
            problems.append(f"stale_sheet_{kind}_count0")
    # 其它帧文件（attack_f0 之类的老约定也算，不报错）
    extras = [f for f in os.listdir(adir) if f.endswith(".png") and not f.startswith("sheet_")]
    entry["extras"] = sorted(extras)
    # foot_frac 契约（v6.38：sheet 动画必须有，缺=护盾脚线 ±5~15px 残差）
    if counts.get("idle", 0) > 0 and "foot_frac" not in meta:
        problems.append("no_foot_frac")
    if not meta.get("outline", {}).get("baked"):
        problems.append("outline_not_baked")
    # 帧级体检：空帧 / 实心触边
    for kind in ("idle", "attack"):
        n = counts.get(kind, 0)
        sheet_rel = os.path.join(adir, f"sheet_{kind}.png")
        if n <= 0 or not os.path.exists(sheet_rel):
            continue
        px, w, h, unp = png_frames(sheet_rel)
        if px is None:
            problems.append(f"sheet_{kind}_unparsed:{unp}")
            continue
        solid = px >= 128
        for fi in range(n):
            cell = solid[:, fi * fs:(fi + 1) * fs]
            solid_px = int(cell.sum())
            core = cell[2:h - 2, 2:fs - 2]          # 内芯
            touch = int(cell.sum() - core.sum())    # 边缘 2px 环上的实心像素
            if solid_px < 40:
                problems.append(f"{kind}_f{fi}_empty({solid_px})")
            if touch > 12:  # 淡尾描边 1-2px 允许；实心成片触边=裁切/振铃
                problems.append(f"{kind}_f{fi}_edge_touch({touch})")
    if problems:
        entry["problems"] = problems
        anim_issues.append(entry)

report["B_anims"] = {"dirs": len(dirs), "issues": anim_issues, "issue_count": len(anim_issues)}
print(f"[B] unit_anims dirs={len(dirs)}  issue dirs={len(anim_issues)}")
for e in anim_issues[:40]:
    print(f"    {e['dir']}: {e.get('err') or e.get('problems')}")

# ---------- C. 卡图覆盖 ----------
player_icons = {f[:-4] for f in os.listdir(os.path.join(ROOT, "assets", "card_icons", "player"))
                if f.endswith(".png")}
enemy_icons = {f[:-4] for f in os.listdir(os.path.join(ROOT, "assets", "card_icons", "enemy"))
               if f.endswith(".png")}
anim_keys = set(dirs)
report["C_cards"] = {
    "player_icons": len(player_icons), "enemy_icons": len(enemy_icons),
    "anim_keys_without_player_icon": sorted(anim_keys - player_icons),
    "anim_keys_without_enemy_icon": sorted(anim_keys - enemy_icons),
}
print(f"[C] player={len(player_icons)} enemy={len(enemy_icons)} anims={len(anim_keys)}")
print(f"    anim 无玩家卡图: {sorted(anim_keys - player_icons)}")
print(f"    anim 无敌方卡图: {sorted(anim_keys - enemy_icons)}")

# ---------- D. 特效贴图引用死链 ----------
effects_dir = os.path.join(ROOT, "assets", "effects")
fx_pngs = []
for dp, _, fns in os.walk(effects_dir):
    for fn in fns:
        if fn.endswith(".png"):
            rel = os.path.relpath(os.path.join(dp, fn), ROOT).replace(os.sep, "/")
            fx_pngs.append(rel)
src_blob = []
for dp, _, fns in os.walk(ROOT):
    if ".godot" in dp or "addons" in dp or "_archived" in dp or ".git" in dp:
        continue
    for fn in fns:
        if fn.endswith((".gd", ".tscn", ".tres", ".py")):
            try:
                src_blob.append(open(os.path.join(dp, fn), encoding="utf-8", errors="ignore").read())
            except OSError:
                pass
blob = "\n".join(src_blob)
dead = [rel for rel in fx_pngs if os.path.basename(rel) not in blob]
report["D_vfx"] = {"effects_png": len(fx_pngs), "unreferenced": sorted(dead),
                   "unref_count": len(dead)}
print(f"[D] effects png={len(fx_pngs)}  source-unreferenced={len(dead)}")
for r in sorted(dead)[:30]:
    print(f"    UNREF {r}")

json.dump(report, open(OUT_JSON, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print(f"[done] -> {OUT_JSON}")
