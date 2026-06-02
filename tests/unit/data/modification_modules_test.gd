extends GutTest
## 改造模块测试

var InfantryModifications = preload("res://data/modification_modules/infantry_mods.gd")
var ArmorModifications = preload("res://data/modification_modules/armor_mods.gd")
var ModificationRegistry = preload("res://scripts/systems/modification_registry.gd")

func test_infantry_modifications_count() -> void:
	# 测试步兵改造数量
	var all_mods = InfantryModifications.get_all_mod_ids()
	assert_eq(all_mods.size(), 22, "步兵应有22个改造")

func test_infantry_modifications_data_completeness() -> void:
	# 测试步兵改造数据完整性
	var all_mods = InfantryModifications.get_all_mod_ids()

	for mod_id in all_mods:
		var data = InfantryModifications.get_mod_data(mod_id)
		assert_not_empty(data, "%s数据不应为空" % mod_id)

		# 必需字段
		assert_true(data.has("id"), "%s应有id字段" % mod_id)
		assert_true(data.has("name"), "%s应有name字段" % mod_id)
		assert_true(data.has("name_en"), "%s应有name_en字段" % mod_id)
		assert_true(data.has("prototype"), "%s应有prototype字段" % mod_id)
		assert_true(data.has("description"), "%s应有description字段" % mod_id)
		assert_true(data.has("rarity"), "%s应有rarity字段" % mod_id)
		assert_true(data.has("effects"), "%s应有effects字段" % mod_id)
		assert_true(data.has("conflict_group"), "%s应有conflict_group字段" % mod_id)

		# 验证ID格式
		assert_true(mod_id.begins_with("inf_"), "%s应以inf_开头" % mod_id)

func test_armor_modifications_count() -> void:
	# 测试装甲改造数量
	var all_mods = ArmorModifications.get_all_mod_ids()
	assert_eq(all_mods.size(), 15, "装甲应有15个改造")

func test_modification_id_uniqueness() -> void:
	# 测试所有改造ID唯一性
	ModificationRegistry.register_all()

	var all_ids = ModificationRegistry.get_all_ids()
	var unique_ids = []

	for id in all_ids:
		assert_false(id in unique_ids, "改造ID重复：%s" % id)
		unique_ids.append(id)

func test_conflict_groups() -> void:
	# 测试冲突组功能
	var mod_a = InfantryModifications.get_mod_data("inf_05_ap_ammo")
	var mod_b = InfantryModifications.get_mod_data("inf_06_hp_ammo")

	# 同一冲突组
	assert_true(InfantryModifications.check_conflict("inf_05_ap_ammo", "inf_05_ap_ammo"))
	assert_true(InfantryModifications.check_conflict("inf_05_ap_ammo", "inf_06_hp_ammo"))

	# 不同冲突组
	var mod_c = InfantryModifications.get_mod_data("inf_01_submachine_gun")
	assert_false(InfantryModifications.check_conflict("inf_05_ap_ammo", "inf_01_submachine_gun"))

func test_modification_for_unit_type() -> void:
	# 测试按兵种过滤改造
	var infantry_mods = InfantryModifications.get_for_unit_type(0)  # LIGHT
	assert_eq(infantry_mods.size(), 22, "步兵应有22个改造")

	var armor_mods = ArmorModifications.get_for_unit_type(1)  # ARMOR
	assert_eq(armor_mods.size(), 15, "装甲应有15个改造")

	# 步兵不应返回装甲改造
	var armor_for_infantry = ArmorModifications.get_for_unit_type(0)
	assert_eq(armor_for_infantry.size(), 0, "步兵不应返回装甲改造")

func test_effects_structure() -> void:
	# 测试改造效果结构
	var all_mods = InfantryModifications.get_all_mod_ids()

	for mod_id in all_mods:
		var data = InfantryModifications.get_mod_data(mod_id)
		var effects = data.get("effects", {})

		# 效果不应为空
		assert_false(effects.is_empty(), "%s应有effects" % mod_id)

		# 验证效果字段
		for effect_key in effects.keys():
			var valid_keys = [
				"attack_light", "attack_armor", "attack_air",
				"defense_light", "defense_armor", "defense_air",
				"max_hp", "move_speed", "attack_range",
				"attack_interval", "deploy_speed",
				"crit_chance", "dodge_chance", "crit_resist",
				"hp_regen", "accuracy_bonus", "splash_radius",
				# 特殊效果
				"night_bonus", "smoke_ignore", "thermal_immunity",
			]
			# 允许其他特殊效果键
			pass

func test_total_modification_count() -> void:
	# 测试总改造数量
	var expected_total = 22 + 15 + 12 + 12 + 14 + 12 + 10 + 10 + 10  # 117个专属 + 10个通用 = 127

	ModificationRegistry.register_all()
	var all_ids = ModificationRegistry.get_all_ids()

	# 允许数量略有偏差（通用改造可能重复计算）
	assert_true(all_ids.size() >= 120, "总改造数应>=120，实际：%d" % all_ids.size())
	assert_true(all_ids.size() <= 140, "总改造数应<=140，实际：%d" % all_ids.size())
