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
	# v27 改造2.0：inf_28~35（普及档 6 + 触发式击杀敷料 + 医疗链套装件）加入后 27→35
	assert_int(all_mods.size()).override_failure_message("步兵应有35个改造").is_equal(35)

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
	# v26：arm_17 附加钢板 + arm_18 炮盾加入后 16→18
	# v27 改造2.0：arm_19~23（普及档 3 + 触发式反击脉冲 + 数据链）加入后 18→23
	assert_int(all_mods.size()).override_failure_message("装甲应有23个改造").is_equal(23)

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
	assert_int(infantry_mods.size()).is_equal(35)
	var armor_mods = ArmorModifications.get_for_unit_type(1)  # ARMOR
	assert_int(armor_mods.size()).is_equal(23)
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
	# v26：新增 12 条（air+6 轰炸主题/armor+2 era0-1 补强/aa+2 对空反制/fort+1 防空洞/gen+1 吸波涂层）→ 190+12=202
	# v27 改造2.0：新增 47 条（普及档 common 10/uncommon 12/rare 12/epic 7/legendary 3/mythic 3，
	# 含 6 条触发式 + 3 条 mythic 行为改写 + 4 个新套装件）→ 202+47=249
	assert_int(all_ids.size()).is_equal(249)
