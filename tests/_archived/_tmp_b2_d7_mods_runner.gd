extends Node
## 批次② Task 7 runner：十文件条目数/字段完整性/Registry 注册冒烟（202 条数量锁）

const SOURCES := {
	"InfantryModifications": ["res://data/modification_modules/infantry_mods.gd", 27],
	"UniversalModifications": ["res://data/modification_modules/universal_mods.gd", 31],
	"AirModifications": ["res://data/modification_modules/air_mods.gd", 25],
	"ArtilleryModifications": ["res://data/modification_modules/artillery_mods.gd", 23],
	"ArmorModifications": ["res://data/modification_modules/armor_mods.gd", 18],
	"AntiAirModifications": ["res://data/modification_modules/anti_air_mods.gd", 17],
	"EngineerModifications": ["res://data/modification_modules/engineer_mods.gd", 16],
	"EnhancementModifications": ["res://data/modification_modules/enhancement_mods.gd", 16],
	"ReconModifications": ["res://data/modification_modules/recon_mods.gd", 15],
	"FortModifications": ["res://data/modification_modules/fort_mods.gd", 14],
}

## 抽查 10 条（含批准样例 inf_01/inf_02/enh_shield_kill）
const SPOT_IDS := [
	"inf_01_submachine_gun", "inf_02_assault_rifle", "enh_shield_kill",
	"gen_16_emp_pulse", "air_13_ejection_seat", "art_13_apfsds_sabot",
	"arm_05_smoothbore", "aa_06_laser", "rec_13_target_designator", "for_14_bomb_shelter",
]


func _ready() -> void:
	var failures: Array[String] = []
	var total := 0
	for class_key in SOURCES:
		var path: String = SOURCES[class_key][0]
		var expect: int = SOURCES[class_key][1]
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			failures.append("%s 加载失败" % path)
			continue
		var data: Dictionary = script.DATA
		if data.size() != expect:
			failures.append("%s 条目数 %d != %d" % [path, data.size(), expect])
		for mod_id in data:
			var e: Dictionary = data[mod_id]
			if str(e.get("name", "")).is_empty():
				failures.append("%s:%s name 为空" % [path, mod_id])
			if str(e.get("description", "")).is_empty():
				failures.append("%s:%s description 为空" % [path, mod_id])
		total += data.size()
	if total != 202:
		failures.append("合计 %d != 202" % total)

	# Registry 域冒烟：注册 + 抽查 get_data
	ModificationRegistry.register_all()
	for mod_id in SPOT_IDS:
		var d: Dictionary = ModificationRegistry.get_data(mod_id)
		if d.is_empty():
			failures.append("Registry 未收录 %s" % mod_id)
		elif str(d.get("description", "")).is_empty():
			failures.append("Registry %s description 为空" % mod_id)

	if failures.is_empty():
		print("B2_D7_BOOT_OK total=202 spot=10 registry=pass")
		get_tree().quit(0)
	else:
		for f in failures:
			push_error("B2_D7_BOOT_FAIL: %s" % f)
		get_tree().quit(1)
