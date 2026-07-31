extends SceneTree
## v8.5 改造/情报面板修复验证（单文件 load 模式，秒级）
## 验证 4 个改动文件的语法 + 关键数据正确性

const MOD_FILES = [
	"res://data/modification_modules/armor_mods.gd",
	"res://data/modification_modules/anti_air_mods.gd",
	"res://scripts/systems/modification_registry.gd",
	"res://scenes/ui/card_info_panel.gd",
]

func _init():
	var ok := true
	# 1. 4 文件 load 编译检查
	for path in MOD_FILES:
		var s := load(path)
		if s == null:
			printerr("FAIL load: ", path)
			ok = false
		else:
			print("OK load: ", path)

	# 2. 关键数据正确性
	if ok:
		var Armor = load("res://data/modification_modules/armor_mods.gd")
		var AA = load("res://data/modification_modules/anti_air_mods.gd")

		# arm_12: 删射程/烟雾，改暴击
		var thermal: Dictionary = Armor.DATA.get("arm_12_thermal_sight", {})
		var t_eff: Dictionary = thermal.get("effects", {})
		assert(not t_eff.has("attack_range"), "arm_12 不应再有 attack_range")
		assert(not t_eff.has("smoke_ignore"), "arm_12 不应再有 smoke_ignore")
		assert(t_eff.get("crit_chance") == 0.15, "arm_12 crit_chance 应为 0.15")
		print("OK arm_12_thermal_sight: crit_chance=0.15，已删 attack_range/smoke_ignore")

		# arm_14: 描述含"+30%"，effects 保留 mine_immunity
		var mine: Dictionary = Armor.DATA.get("arm_14_mine_plow", {})
		assert(mine.get("description", "").find("+30%") >= 0, "arm_14 描述应含 +30%")
		assert(mine.effects.has("mine_immunity"), "arm_14 effects 应保留 mine_immunity")
		print("OK arm_14_mine_plow: 描述含+30%，mine_immunity 保留")

		# aa_06: 迁移到真拦截，无限充能
		var laser: Dictionary = AA.DATA.get("aa_06_laser", {})
		var l_eff: Dictionary = laser.get("effects", {})
		assert(l_eff.has("intercept_system"), "aa_06 应有 intercept_system")
		assert(not l_eff.has("missile_intercept"), "aa_06 不应再有 missile_intercept")
		assert(l_eff.get("intercept_charges") == -1, "aa_06 intercept_charges 应为 -1（无限）")
		print("OK aa_06_laser: intercept_system=0.30, charges=-1（无限）")

		# card_info_panel: _UNIT_MECHANISM_DESC 含传统兵种
		var Panel = load("res://scenes/ui/card_info_panel.gd")
		var inst: Node = Panel.new()
		var desc: Dictionary = inst.get("_UNIT_MECHANISM_DESC")
		for key in ["infantry", "recon", "armor", "artillery", "anti_air", "air", "engineer_class", "fort"]:
			assert(desc.has(key), "_UNIT_MECHANISM_DESC 缺 key: " + key)
		# engineer 文案不应再含"维修/布雷/净化"
		var eng_text: String = desc.get("engineer", "")
		assert(eng_text.find("维修") < 0 and eng_text.find("布雷") < 0 and eng_text.find("净化") < 0,
			"engineer 文案不应含维修/布雷/净化: " + eng_text)
		print("OK _UNIT_MECHANISM_DESC: 8 传统兵种全在，engineer 文案已修正")
		inst.free()

	print("\n=== 验证结果: %s ===" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
