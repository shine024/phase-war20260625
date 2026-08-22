extends Node
## power_calibration_probe 的场景模式驱动（--script 模式全局类缓存易炸，见 weapon_dps_probe 踩坑）
##   godot --headless --path . res://tests/calib_scene_driver.tscn
const ProbeScript = preload("res://tests/power_calibration_probe.gd")

func _ready() -> void:
	await get_tree().process_frame
	# power_calibration_probe 是 SceneTree 脚本，此处借其逻辑改为 Node 版执行：
	# 直接复刻其 _initialize（autoload 已就绪）
	var EH = load("res://managers/evolution/evolution_helpers.gd")
	var PT = load("res://data/power_tiers.gd")
	var SAMPLES = [
		["WWI步兵", "ww1_mp18"], ["WW2步兵", "ww2_thompson"], ["现代步兵", "mod_marine"],
		["未来步兵", "fut_cyborg"], ["现代侦察", "mod_ranger"], ["WWI坦克", "ww1_arm_ft17"],
		["WW2坦克", "ww2_pz3"], ["冷战坦克", "cold_arm_t55"], ["现代坦克", "mod_arm_m1a1"],
		["未来坦克", "fut_arm_hovertank"],
	]
	var bpm: Node = get_node("/root/BlueprintManager")
	var ir: Node = get_node("/root/InstanceRegistry")
	print("=== 白板模板战力（v9.x 机制折算后基线，v9.x 原基线：mp18≈260 pz3≈720 m1a1≈1310） ===")
	for s in SAMPLES:
		var combat: float = EH.estimate_power_score(s[1], bpm)
		print("%-10s %-18s 白板 = %5d" % [s[0], s[1], int(combat)])
	print("")
	print("=== 投入档战力（强化5+2改 / 强化10+5改——本轮已修 mod id 空转 bug） ===")
	for s in SAMPLES:
		var iid: String = ir.create_instance(s[1]).instance_id
		var inst = ir.get_instance(iid)
		inst.enhance_level = 5
		inst.mods = [{"id": "arm_01_sloped_armor", "enabled": true}, {"id": "arm_05_smoothbore", "enabled": true}]
		var c5: float = EH.estimate_power_score(iid, bpm)
		inst.enhance_level = 10
		inst.mods = []
		for k in range(5):
			inst.mods.append({"id": "arm_01_sloped_armor", "enabled": true})
		var c10: float = EH.estimate_power_score(iid, bpm)
		print("%-10s 强化5+2改: %5d | 强化10+5改: %5d" % [s[0], int(c5), int(c10)])
		ir.dispose_instance(iid)
	get_tree().quit(0)
