# -*- coding: utf-8 -*-
"""锚点回退(2026-10-16):恢复多帧的 26 卡 fireX/fireY_pct 回 HEAD 值(配旧 sheet)。

对象=批量恢复 23 卡+zsu23+citadel+mp18_x。保留四格 7 卡锚(我批新值)不动。
两文件:docs/敌我双方卡头脚和开火位置.json + data/muzzle_anchors.gd。
ff/hf(foot_frac)不在锚文件回退范围——anim.json checkout 已回 HEAD 值,卡头 json
的 ff 字段随本脚本一并回 HEAD(它源自 anim.json 同源实测)。
"""
import json
import re
import subprocess

ROOT = r"F:\godot fair duet\create\phase-war"

RESTORE = [
    "fut_air_drone", "fut_air_heavy_carrier", "fut_arm_mech_e", "fut_arm_prism",
    "fut_arm_titan_mk2", "fut_arty_hel30", "fut_inf_x9", "fut_sup_nrepair",
    "mod_air_technical_e", "mod_arm_m1a1", "mod_inf_patriot",
    "ww1_arty_m81", "ww1_arty_mortar", "ww1_boss_av7", "ww1_fort_pillbox",
    "ww1_saint", "ww1_sup_ford_ambulance", "ww1_sup_mg_nest", "ww1_sup_vickers",
    "ww2_arty_m81", "ww2_arty_pak40", "ww2_fort_flak", "ww2_mg42",
    "cold_sup_zsu23", "mod_fort_citadel", "ww1_inf_mp18_x",
]


def head(path):
    return subprocess.run(["git", "show", "HEAD:" + path], cwd=ROOT, capture_output=True,
                          text=True, encoding="utf-8").stdout


# HEAD 锚值
old_json = json.loads(head("docs/敌我双方卡头脚和开火位置.json"))
old_by = {a["id"]: a for a in old_json}
old_gd = head("data/muzzle_anchors.gd")
old_gd_by = {}
for m in re.finditer(r'"([a-z0-9_]+)": \{([^}]*)\}', old_gd):
    old_gd_by[m.group(1)] = m.group(2)

# 现工作区
AJ = ROOT + "/docs/敌我双方卡头脚和开火位置.json"
GD = ROOT + "/data/muzzle_anchors.gd"
anchors = json.load(open(AJ, encoding="utf-8"))
by_id = {a["id"]: a for a in anchors}
gd = open(GD, encoding="utf-8").read()

n_json = n_gd = miss = 0
for uid in RESTORE:
    oj = old_by.get(uid)
    og = old_gd_by.get(uid)
    if oj is None and og is None:
        miss += 1
        print("无 HEAD 锚:", uid)
        continue
    if oj is not None and uid in by_id:
        by_id[uid].update({k: oj[k] for k in ("ff", "hf", "fireX", "fireY_pct") if k in oj})
        n_json += 1
    if og is not None:
        pat = re.compile(r'"%s": \{[^}]*\}' % uid)
        if pat.search(gd):
            gd = pat.sub('"%s": {%s},' % (uid, og), gd, count=1)
            n_gd += 1

with open(AJ, "w", encoding="utf-8") as f:
    json.dump(anchors, f, ensure_ascii=False, separators=(",", ":"))
with open(GD, "w", encoding="utf-8") as f:
    f.write(gd)
print("json 回退 %d, gd 回退 %d, 无 HEAD 锚 %d" % (n_json, n_gd, miss))
