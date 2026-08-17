# 定标探针：5 时代 × 3 投入档的战力实测（战斗公式/meta 公式/档位映射）
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/power_calibration_probe.gd
extends SceneTree

const EH = preload("res://managers/evolution/evolution_helpers.gd")
const PT = preload("res://data/power_tiers.gd")

const SAMPLES := [
	["WWI步兵", "ww1_mp18"],
	["WW2步兵", "ww2_thompson"],
	["现代步兵", "mod_marine"],
	["未来步兵", "fut_cyborg"],
	["现代侦察", "mod_ranger"],
	["WWI坦克", "ww1_arm_ft17"],
	["WW2坦克", "ww2_pz3"],
	["冷战坦克", "cold_arm_t55"],
	["现代坦克", "mod_arm_m1a1"],
	["未来坦克", "fut_arm_hovertank"],
]

func _initialize() -> void:
	var bpm: Node = root.get_node_or_null("BlueprintManager")
	var ir: Node = root.get_node_or_null("InstanceRegistry")
	if bpm == null or ir == null:
		print("!! managers 未加载"); quit(1); return

	print("=== 白板模板战力（= 进化门槛目标侧候选基准） ===")
	for s in SAMPLES:
		var combat: float = EH.estimate_power_score(s[1], bpm)
		print("%-10s %-16s 白板战斗战力 = %5d   档位(现行阈值) = %s" % [s[0], s[1], int(combat), PT.get_tier_name(PT.get_tier_by_power(combat))])

	print("")
	print("=== 投入档战力（强化+改造实例） ===")
	for s in SAMPLES:
		var iid: String = ir.create_instance(s[1]).instance_id
		var inst = ir.get_instance(iid)
		inst.enhance_level = 5
		inst.mods = [{"id": "arm_01_reactive_armor", "enabled": true}, {"id": "arm_02_smoothbore", "enabled": true}]
		var c5: float = EH.estimate_power_score(iid, bpm)
		var m5: float = EH.estimate_power_score_meta_only(iid, bpm)
		inst.enhance_level = 10
		inst.mods = []
		for k in range(5):
			inst.mods.append({"id": "arm_01_reactive_armor", "enabled": true})
		var c10: float = EH.estimate_power_score(iid, bpm)
		var m10: float = EH.estimate_power_score_meta_only(iid, bpm)
		print("%-10s 强化5+2改: 战斗=%5d meta=%4d | 强化10+5改: 战斗=%5d meta=%4d" % [s[0], int(c5), int(m5), int(c10), int(m10)])
		ir.dispose_instance(iid)
	quit(0)
