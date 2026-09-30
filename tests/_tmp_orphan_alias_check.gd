extends SceneTree
## 孤儿甄别第二轮：①12 个 ANIM_ALIAS 键的实际解析落点（空=站桩 bug，非空=别名被遮蔽）
## ②无别名关系的孤儿，在 UCT 卡 id 里按词根搜潜在归属（搜到=布线候选，搜不到=纯死资产）

const ALIAS_KEYS := [
	"ww1_sup_mg_nest", "ww2_boss_kingtiger", "ww2_inf_panzerschreck_e",
	"cold_arm_btr_e", "cold_air_m113_e", "cold_inf_ak", "mod_inf_delta_e",
	"mod_boss_command", "mod_air_apache_e", "fut_air_drone", "fut_arm_mech_e",
	"fut_boss_nexus",
]
## 词根 → 孤儿目录（无别名关系的 25 个）
const ROOT_HINTS := {
	"cold_mig": ["mig"],
	"fut_hovertank": ["hovertank", "hover"],
	"mod_abrams": ["abrams"],
	"mod_apache": ["apache"],
	"mod_mlrs": ["mlrs"],
	"mod_technical": ["technical"],
	"cold_btr": ["btr"],
	"cold_m113": ["m113"],
	"fut_drone": ["drone"],
	"fut_mech": ["mech"],
	"mod_delta": ["delta"],
	"ww1_mortar": ["mortar"],
	"ww2_para": ["para"],
	"ww2_tiger": ["tiger"],
	"ww1_rifle": ["inf_rifle"],
	"ww1_rolls": ["rolls"],
	"ww1_mgnest": ["mg_nest", "mgnest"],
	"cold_ak": ["_ak"],
}

func _initialize() -> void:
	var ufa := load("res://scripts/battle/unit_frame_anim.gd")
	var uct := load("res://data/unified_card_table.gd")
	print("== alias key resolution ==")
	for k in ALIAS_KEYS:
		var r := String(ufa.call("_resolve_key", k))
		print("  ", k, " -> '", r, "'", ("  ⚠️ 站桩!" if r.is_empty() else ""))
	print("== orphan owner hints (UCT id/name match) ==")
	for orphan in ROOT_HINTS.keys():
		var hits: Array[String] = []
		for cid in uct.get_all_card_ids():
			var low := String(cid).to_lower()
			for frag in ROOT_HINTS[orphan]:
				if low.contains(String(frag)):
					hits.append(String(cid))
					break
		print("  ", orphan, " <- ", str(hits))
	print("ALIAS_CHECK_DONE")
	quit(0)
