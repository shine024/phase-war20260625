extends GdUnitTestSuite
## 改造模块测试
# v7.x: 原 extends GutTest + GUT API（assert_eq/assert_not_empty/assert_true/assert_false），
# 迁移到 GdUnit4 链式 API（assert_int/assert_array/assert_bool + override_failure_message）。
# 静态数据类（InfantryModifications 等 extends RefCounted，方法为 static func）可 ClassName.method() 调用。

var InfantryModifications = preload("res://data/modification_modules/infantry_mods.gd")
var ArmorModifications = preload("res://data/modification_modules/armor_mods.gd")
var ModificationRegistry = preload("res://scripts/systems/modification_registry.gd")

func test_infantry_modifications_count() -> void:
	var all_mods = InfantryModifications.get_all_mod_ids()
	# 批次8（2026-08-23）：inf_23~27（战斗兴奋剂/巷战/医疗牺牲/化学弹头/凝固汽油）加入后 22→27
	assert_int(all_mods.size()).override_failure_message("步兵应有27个改造").is_equal(27)

func test_infantry_modifications_data_completeness() -> void:
	var all_mods = InfantryModifications.get_all_mod_ids()
	for mod_id in all_mods:
		var data = InfantryModifications.get_mod_data(mod_id)
		assert_dict(data).is_not_empty()
		assert_bool(data.has("id")).is_true()
		assert_bool(data.has("name")).is_true()
		assert_bool(data.has("name_en")).is_true()
		assert_bool(data.has("prototype")).is_true()
		assert_bool(data.has("description")).is_true()
		assert_bool(data.has("rarity")).is_true()
		assert_bool(data.has("effects")).is_true()
		assert_bool(data.has("conflict_group")).is_true()
		# 验证ID格式
		assert_bool(mod_id.begins_with("inf_")).is_true()

func test_armor_modifications_count() -> void:
	var all_mods = ArmorModifications.get_all_mod_ids()
	# 批次8（2026-08-23）：arm_16（战斗狂热）加入后 15→16
	assert_int(all_mods.size()).override_failure_message("装甲应有16个改造").is_equal(16)

func test_modification_id_uniqueness() -> void:
	ModificationRegistry.register_all()
	var all_ids = ModificationRegistry.get_all_ids()
	var unique_ids: Array = []
	for id in all_ids:
		assert_bool(not (id in unique_ids)).override_failure_message("改造ID重复：%s" % id).is_true()
		unique_ids.append(id)

func test_conflict_groups() -> void:
	# 同一冲突组
	assert_bool(InfantryModifications.check_conflict("inf_05_ap_ammo", "inf_05_ap_ammo")).is_true()
	assert_bool(InfantryModifications.check_conflict("inf_05_ap_ammo", "inf_06_hp_ammo")).is_true()
	# 不同冲突组
	assert_bool(InfantryModifications.check_conflict("inf_05_ap_ammo", "inf_01_submachine_gun")).is_false()

func test_modification_for_unit_type() -> void:
	var infantry_mods = InfantryModifications.get_for_unit_type(0)  # LIGHT
	assert_int(infantry_mods.size()).is_equal(27)
	var armor_mods = ArmorModifications.get_for_unit_type(1)  # ARMOR
	assert_int(armor_mods.size()).is_equal(16)
	# 步兵不应返回装甲改造
	var armor_for_infantry = ArmorModifications.get_for_unit_type(0)
	assert_int(armor_for_infantry.size()).is_equal(0)

func test_effects_structure() -> void:
	var all_mods = InfantryModifications.get_all_mod_ids()
	for mod_id in all_mods:
		var data = InfantryModifications.get_mod_data(mod_id)
		var effects = data.get("effects", {})
		assert_bool(not effects.is_empty()).is_true()

func test_total_modification_count() -> void:
	ModificationRegistry.register_all()
	var all_ids = ModificationRegistry.get_all_ids()
	# 批次8（2026-08-23）：全模块注册总数实测 184（原 120-140 区间过期；
	# registry 注释里"154 条"亦为旧值）。精确锁定防未来无感知增删。
	# v21 P1：新增 6 个行为改写型传奇改造（gen_converted_munitions 等）→ 184+6=190
	assert_int(all_ids.size()).is_equal(190)
