# -*- coding: utf-8 -*-
"""修复开火锚点批量写入的两处损伤：误插行 + fireY_pct 刻度（0-1 → 0-100）。"""
import re, json
from pathlib import Path

P = {
 "fut_swarm": (0.85, 0.38), "fut_nano_drone": (0.88, 0.42),
 "mod_fort_citadel": (0.84, 0.52), "ww2_fort_flak": (0.89, 0.33),
 "fe_iron_wall_bastion": (0.90, 0.52), "fe_iron_wall_juggernaut": (0.80, 0.64),
 "fe_nova_devastator": (0.93, 0.32), "fe_nova_ghost_sniper": (0.88, 0.60),
 "fe_aether_hover_cavalry": (0.72, 0.46), "fe_aether_swarm_queen": (0.92, 0.35),
 "fe_quantum_mobile_base": (0.90, 0.50), "fe_quantum_repair_drone": (0.63, 0.32),
 "fe_helix_phantom": (0.74, 0.58), "fe_helix_orbital_strike": (0.85, 0.40),
 "fe_void_phase_cannon": (0.90, 0.38), "fe_void_dimensional_soldier": (0.79, 0.58),
 "fe_frontier_veteran": (0.80, 0.38), "fe_frontier_mixed_company": (0.92, 0.32),
}
E = {
 "foe_ww1_arty_77mm": (0.12, 0.34), "foe_ww1_arty_m81": (0.08, 0.34),
 "foe_fut_arm_prism": (0.10, 0.42), "foe_fut_air_heavy_carrier": (0.10, 0.45),
 "ww1_inf_storm_e": (0.15, 0.38), "ww2_inf_para_e": (0.28, 0.45),
 "cold_arm_t72_e": (0.09, 0.43), "mod_inf_marine": (0.20, 0.36),
 "fut_arm_mech_e": (0.12, 0.42), "fut_inf_spectre_e": (0.15, 0.42),
 "fut_arm_colossus_e": (0.12, 0.42), "ww2_arty_pak40": (0.07, 0.36),
 "fut_inf_neural": (0.14, 0.40), "fut_arty_ssc1": (0.68, 0.25),
 "cold_air_strike_fighter": (0.07, 0.47), "cold_air_bomber": (0.08, 0.48),
 "ww2_air_me262": (0.07, 0.42), "ww2_air_meteor_e": (0.07, 0.46),
 "foe_ww1_sup_mp18": (0.14, 0.30), "foe_ww1_sup_engineer": (0.25, 0.42),
 "foe_ww2_arm_sherman": (0.10, 0.45), "foe_ww2_arm_tiger": (0.09, 0.44),
 "foe_ww2_inf_bazooka": (0.10, 0.40), "foe_cold_inf_btr60": (0.22, 0.32),
 "foe_mod_arm_m1a1": (0.10, 0.45), "foe_mod_arty_m270": (0.10, 0.32),
 "foe_fut_inf_scout_mech": (0.30, 0.35), "foe_fut_arm_nexus": (0.15, 0.45),
 "foe_fut_sup_bulwark": (0.10, 0.40), "foe_fut_arm_titan_mk2": (0.10, 0.30),
 "fut_inf_c96": (0.16, 0.40),
 "ww1_inf_mp18": (0.14, 0.35), "ww1_inf_rifle": (0.12, 0.36), "ww1_sup_mg_nest": (0.10, 0.40),
 "ww2_inf_thompson": (0.28, 0.46), "ww2_inf_garand": (0.13, 0.37), "ww2_sup_mg42": (0.09, 0.38),
 "ww2_arm_panther_e": (0.09, 0.45), "ww2_boss_kingtiger": (0.09, 0.46), "ww2_arm_garand_para": (0.16, 0.42),
 "ww2_arty_hummel": (0.08, 0.32), "ww2_sup_gmc_truck": (0.15, 0.45), "ww2_inf_kar98k": (0.10, 0.38),
 "cold_inf_ak": (0.20, 0.40), "cold_inf_m60": (0.22, 0.38), "cold_inf_spetsnaz_e": (0.18, 0.40),
 "mod_inf_delta_e": (0.12, 0.35), "mod_inf_patriot": (0.15, 0.30), "mod_arm_himars": (0.12, 0.32),
 "mod_sup_m4_carbine": (0.12, 0.36), "fut_inf_cyborg": (0.13, 0.42),
 "fut_arm_hk07": (0.10, 0.40), "fut_arty_hel30": (0.10, 0.40),
 "fut_arm_hovertank_e": (0.10, 0.45),
 "ww2_air_bomber": (0.08, 0.45), "ww2_air_dive_bomber": (0.07, 0.45),
 "mod_air_multirole": (0.07, 0.47), "mod_air_bomber": (0.08, 0.47),
 "fut_air_stealth_multirole": (0.07, 0.46), "fut_air_stealth_bomber": (0.06, 0.48),
 "ww1_fort_pillbox": (0.26, 0.47), "ww1_fort_artillery": (0.09, 0.37),
 "ww2_fort_flak": (0.11, 0.33), "cold_fort_radar": (0.40, 0.30),
 "mod_fort_citadel": (0.16, 0.52), "mod_fort_phalanx": (0.16, 0.48),
 "fut_fort_ion": (0.13, 0.43),
 "xeno_swarmling": (0.15, 0.55), "xeno_probe": (0.12, 0.33), "xeno_zealot": (0.12, 0.42),
 "xeno_stalker": (0.10, 0.40), "xeno_adept": (0.24, 0.48), "xeno_sentinel": (0.20, 0.45),
 "xeno_dragoon": (0.15, 0.40), "xeno_plasma_bug": (0.15, 0.45), "xeno_tripod": (0.20, 0.32),
 "xeno_hunter": (0.20, 0.34), "xeno_mimic": (0.30, 0.42), "xeno_biomorph": (0.12, 0.42),
 "xeno_dark_templar": (0.13, 0.45), "xeno_reaver": (0.12, 0.48), "xeno_interceptor": (0.10, 0.50),
 "xeno_carrier": (0.10, 0.50), "xeno_saucer": (0.50, 0.60), "xeno_templar": (0.28, 0.42),
 "xeno_thing": (0.28, 0.45), "xeno_mothership": (0.32, 0.52),
}


def fx_s(v):
    return ("%.4f" % v).rstrip("0").rstrip(".") if v != int(v) else str(int(v))


def fy_s(v):
    return ("%.2f" % (v * 100.0)).rstrip("0").rstrip(".")


# ═══ 1) 敌方 muzzle_anchors.gd ═══
p = Path("data/muzzle_anchors.gd")
lines = p.read_text(encoding="utf-8").splitlines(keepends=True)
dict_start = next(i for i, l in enumerate(lines) if l.startswith("const MUZZLE"))
dict_end = next(i for i in range(dict_start, len(lines)) if lines[i].startswith("}"))
stray = [i for i, l in enumerate(lines)
         if (i < dict_start or i > dict_end) and re.match(r'\t"[\w]+": \{"fireX"', l)]
for i in sorted(stray, reverse=True):
    del lines[i]
src = "".join(lines)
head, rest = src.split("const MUZZLE: Dictionary = {", 1)
dict_txt, tail = rest.split("\n}", 1)
entries = re.findall(r'\t"([\w]+)": \{"fireX": [\d.]+, "fireY_pct": [\d.]+\}', dict_txt)
plat = {m.group(1): m.group(2) for m in re.finditer(r'"([\w]+)":\s*"([\w]+)"', src)}
keymap = {k: k for k in entries}
for id_ in E:
    base = id_[4:] if id_.startswith("foe_") else id_
    for cand in [id_, base, plat.get(base, "")]:
        if cand and cand in entries:
            keymap[id_] = cand
            break
fixed = 0
for id_, (fx, fy) in E.items():
    k = keymap.get(id_)
    if k is None:
        continue
    pat = re.compile(r'\t"%s": \{"fireX": [\d.]+, "fireY_pct": [\d.]+\}' % re.escape(k))
    dict_txt, n = pat.subn('\t"%s": {"fireX": %s, "fireY_pct": %s}' % (k, fx_s(fx), fy_s(fy)), dict_txt, count=1)
    fixed += n
missing = [id_ for id_ in E if keymap.get(id_) is None]
add_txt = "".join('\t"%s": {"fireX": %s, "fireY_pct": %s},\n' % (id_, fx_s(E[id_][0]), fy_s(E[id_][1])) for id_ in missing)
dict_txt = dict_txt.rstrip("\n")
if not dict_txt.endswith("},"):
    dict_txt += ","
src = head + "const MUZZLE: Dictionary = {" + dict_txt + "\n" + add_txt + "}" + tail
p.write_text(src, encoding="utf-8")
print("enemy repaired: rewrote %d, appended %d, removed stray %d" % (fixed, len(missing), len(stray)))

# ═══ 2) 我方 player_muzzle_anchors.gd ═══
p2 = Path("data/player_muzzle_anchors.gd")
src2 = p2.read_text(encoding="utf-8")
bad = re.search(r'\treturn float\(PLAYER_MUZZLE\.get\(String\(card_id\)\.strip_edges\(\), \{\}\)\.get\("hf.*$', src2, re.DOTALL)
if bad:
    src2 = src2[:bad.start()] + '\treturn float(PLAYER_MUZZLE.get(String(card_id).strip_edges(), {}).get("hf", 0.15))\n'
for id_ in ["fut_swarm", "fut_nano_drone", "mod_fort_citadel", "ww2_fort_flak"]:
    fx, fy = P[id_]
    pat = re.compile(r'\t"%s": \{"fireX": [\d.]+, "fireY_pct": [\d.]+' % re.escape(id_))
    src2 = pat.sub('\t"%s": {"fireX": %s, "fireY_pct": %s' % (id_, fx_s(fx), fy_s(fy)), src2, count=1)
lines2 = src2.splitlines(keepends=True)
d_start = next(i for i, l in enumerate(lines2) if l.startswith("const PLAYER_MUZZLE"))
d_end = next(i for i in range(d_start, len(lines2)) if lines2[i].startswith("}"))
srcA = Path("data/card_foot_anchors.gd").read_text(encoding="utf-8")
ff_map = {m.group(1): float(m.group(2)) for m in re.finditer(r'"([\w]+)": ([\d.]+),', srcA.split("const FOOT_FRAC")[1].split("\n}")[0])}
hf_map = {m.group(1): float(m.group(2)) for m in re.finditer(r'"([\w]+)": ([\d.]+),', srcA.split("const HEAD_FRAC")[1].split("\n}")[0])}
fe_ids = [i for i in P if i.startswith("fe_")]
add2 = "".join('\t"%s": {"fireX": %s, "fireY_pct": %s, "ff": %s, "hf": %s},\n' % (
    id_, fx_s(P[id_][0]), fy_s(P[id_][1]), fx_s(ff_map.get(id_, 0.15)), fx_s(hf_map.get(id_, 0.15))) for id_ in fe_ids)
lines2.insert(d_end, add2)
p2.write_text("".join(lines2), encoding="utf-8")
print("player repaired: 4 rescaled, fe_ %d inserted into dict" % len(fe_ids))

# ═══ 3) JSON fireY_pct 修回百分比 ═══
jp = Path("docs/敌我双方卡头脚和开火位置.json")
data = json.loads(jp.read_text(encoding="utf-8"))
for e in data:
    if e["id"] in P:
        e["fireX"] = round(P[e["id"]][0], 4)
        e["fireY_pct"] = round(P[e["id"]][1] * 100.0, 2)
jp.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ": ")), encoding="utf-8")
print("json repaired")
