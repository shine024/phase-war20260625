# -*- coding: utf-8 -*-
"""锚点修复(2026-10-16):恢复 26 卡锚态收敛回 HEAD 态。

矩阵审计结论(四态 HEAD/cur):
- gd 删 4 条:Hjson无 Hgd无 但 CgdTrue(我批 append 的四格锚)——m1a1/saint/mg42/zsu23
- json 删 16 条:Hjson无 但 CjsonTrue(我批 append)——A 类 16 卡
- gd 全文双逗号归单(我批 anchor_sync 行尾逗号叠加 bug,29 处;flak 三逗号)
其余(19 条 Hgd有已回 HEAD 值;7 条 Hjson有已回 HEAD 值)不动。
"""
import json
import re

ROOT = r"F:\godot fair duet\create\phase-war"
AJ = ROOT + r"\docs\敌我双方卡头脚和开火位置.json"
GD = ROOT + r"\data\muzzle_anchors.gd"

GD_DEL = ["mod_arm_m1a1", "ww1_saint", "ww2_mg42", "cold_sup_zsu23"]
JSON_DEL = [
    "fut_air_drone", "fut_air_heavy_carrier", "fut_arm_mech_e", "fut_arm_titan_mk2",
    "fut_arty_hel30", "fut_inf_x9", "fut_sup_nrepair", "mod_air_technical_e",
    "mod_inf_patriot", "ww1_arty_mortar", "ww1_boss_av7", "ww1_sup_ford_ambulance",
    "ww1_sup_mg_nest", "ww1_sup_vickers", "ww2_arty_pak40", "ww1_inf_mp18_x",
]

gd = open(GD, encoding="utf-8").read()
for uid in GD_DEL:
    pat = re.compile(r'\n\t"%s": \{[^}]*\},?' % uid)
    gd, n = pat.subn("", gd)
    print("gd del", uid, n)
while ",," in gd:
    gd = gd.replace(",,", ",")
open(GD, "w", encoding="utf-8").write(gd)

anchors = json.load(open(AJ, encoding="utf-8"))
before = len(anchors)
anchors = [a for a in anchors if a["id"] not in JSON_DEL]
print("json del %d (%d -> %d)" % (before - len(anchors), before, len(anchors)))
with open(AJ, "w", encoding="utf-8") as f:
    json.dump(anchors, f, ensure_ascii=False, separators=(",", ":"))
