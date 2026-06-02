## 数据完整性验证脚本
## 用于检查新系统的数据一致性

extends SceneTree

const INFANTRY_MODS = preload("res://data/modification_modules/infantry_mods.gd")
const ARMOR_MODS = preload("res://data/modification_modules/armor_mods.gd")
const ARTILLERY_MODS = preload("res://data/modification_modules/artillery_mods.gd")
const ANTI_AIR_MODS = preload("res://data/modification_modules/anti_air_mods.gd")
const AIR_MODS = preload("res://data/modification_modules/air_mods.gd")
const RECON_MODS = preload("res://data/modification_modules/recon_mods.gd")
const ENGINEER_MODS = preload("res://data/modification_modules/engineer_mods.gd")
const FORT_MODS = preload("res://data/modification_modules/fort_mods.gd")
const UNIVERSAL_MODS = preload("res://data/modification_modules/universal_mods.gd")

const MODIFICATION_REGISTRY = preload("res://scripts/systems/modification_registry.gd")
const UNIFIED_RANK_SYSTEM = preload("res://data/military_titles/unified_rank_system.gd")
const TITLE_DISPLAY_NAMES = preload("res://data/military_titles/title_display_names.gd")

## ─────────────────────────────────────────────
##  验证接口
## ─────────────────────────────────────────────

func _init() -> void:
	print("=== 数据完整性验证 ===")
	_validate_all()
	quit()

func _validate_all() -> void:
	var errors = []
	var warnings = []

	# 1. 军衔系统验证
	print("\n[1/5] 验证军衔系统...")
	var rank_errors = _validate_rank_system()
	errors.append_array(rank_errors)

	# 2. 改造模块数量验证
	print("\n[2/5] 验证改造模块数量...")
	var count_errors = _validate_modification_counts()
	errors.append_array(count_errors)

	# 3. 改造ID唯一性验证
	print("\n[3/5] 验证改造ID唯一性...")
	var id_errors = _validate_modification_ids()
	errors.append_array(id_errors)

	# 4. 改造数据完整性验证
	print("\n[4/5] 验证改造数据完整性...")
	var data_errors = _validate_modification_data()
	errors.append_array(data_errors)

	# 5. 冲突组一致性验证
	print("\n[5/5] 验证冲突组一致性...")
	var conflict_errors = _validate_conflict_groups()
	errors.append_array(conflict_errors)

	# 输出结果
	print("\n=== 验证结果 ===")
	if errors.is_empty():
		print("✓ 所有验证通过")
	else:
		print("✗ 发现 %d 个错误：" % errors.size())
		for error in errors:
			print("  - %s" % error)

	if not warnings.is_empty():
		print("⚠ %d 个警告：" % warnings.size())
		for warning in warnings:
			print("  - %s" % warning)

## ─────────────────────────────────────────────
##  具体验证函数
## ─────────────────────────────────────────────

func _validate_rank_system() -> Array:
	var errors = []

	# 检查等级1-10都有数据
	for level in range(1, 11):
		var data = UNIFIED_RANK_SYSTEM.get_rank_data(level)
		if data.is_empty():
			errors.append("Lv%d军衔数据为空" % level)
			continue

		# 检查必需字段
		if not data.has("level"):
			errors.append("Lv%d缺少level字段" % level)
		if not data.has("power_ratio_min"):
			errors.append("Lv%d缺少power_ratio_min字段" % level)
		if not data.has("cost_multiplier"):
			errors.append("Lv%d缺少cost_multiplier字段" % level)

	return errors

func _validate_modification_counts() -> Array:
	var errors = []

	var expected_counts = {
		infantry = 22,
		armor = 15,
		artillery = 12,
		anti_air = 12,
		air = 14,
		recon = 12,
		engineer = 10,
		fort = 10,
		universal = 10,
	}

	var actual_counts = {
		infantry = INFANTRY_MODS.get_all_mod_ids().size(),
		armor = ARMOR_MODS.get_all_mod_ids().size(),
		artillery = ARTILLERY_MODS.get_all_mod_ids().size(),
		anti_air = ANTI_AIR_MODS.get_all_mod_ids().size(),
		air = AIR_MODS.get_all_mod_ids().size(),
		recon = RECON_MODS.get_all_mod_ids().size(),
		engineer = ENGINEER_MODS.get_all_mod_ids().size(),
		fort = FORT_MODS.get_all_mod_ids().size(),
		universal = UNIVERSAL_MODS.get_all_mod_ids().size(),
	}

	for type in expected_counts.keys():
		var expected = expected_counts[type]
		var actual = actual_counts.get(type, 0)
		if actual != expected:
			errors.append("%s改造数量不符：预期%d，实际%d" % [type, expected, actual])

	return errors

func _validate_modification_ids() -> Array:
	var errors = []
	var all_ids = []

	var modules = [
		INFANTRY_MODS, ARMOR_MODS, ARTILLERY_MODS,
		ANTI_AIR_MODS, AIR_MODS, RECON_MODS,
		ENGINEER_MODS, FORT_MODS, UNIVERSAL_MODS,
	]

	for module in modules:
		var mod_ids = module.get_all_mod_ids()
		for mod_id in mod_ids:
			if mod_id in all_ids:
				errors.append("改造ID重复：%s" % mod_id)
			else:
				all_ids.append(mod_id)

	return errors

func _validate_modification_data() -> Array:
	var errors = []

	var modules = [
		INFANTRY_MODS, ARMOR_MODS, ARTILLERY_MODS,
		ANTI_AIR_MODS, AIR_MODS, RECON_MODS,
		ENGINEER_MODS, FORT_MODS, UNIVERSAL_MODS,
	]

	var required_fields = ["id", "name", "name_en", "prototype", "description", "rarity", "effects", "conflict_group"]

	for module in modules:
		var mod_ids = module.get_all_mod_ids()
		for mod_id in mod_ids:
			var data = module.get_mod_data(mod_id)

			if data.is_empty():
				errors.append("%s数据为空" % mod_id)
				continue

			for field in required_fields:
				if not data.has(field):
					errors.append("%s缺少字段：%s" % [mod_id, field])

			# 检查effects不为空
			if data.has("effects") and data.effects is Dictionary:
				if data.effects.is_empty():
					errors.append("%s的effects为空" % mod_id)

	return errors

func _validate_conflict_groups() -> Array:
	var errors = []

	var modules = [
		INFANTRY_MODS, ARMOR_MODS, ARTILLERY_MODS,
		ANTI_AIR_MODS, AIR_MODS, RECON_MODS,
		ENGINEER_MODS, FORT_MODS, UNIVERSAL_MODS,
	]

	# 检查同一冲突组内的改造
	var conflict_groups = {}

	for module in modules:
		var mod_ids = module.get_all_mod_ids()
		for mod_id in mod_ids:
			var data = module.get_mod_data(mod_id)
			var conflict_group = data.get("conflict_group", "")

			if conflict_group.is_empty():
				continue  # 无冲突组

			if not conflict_groups.has(conflict_group):
				conflict_groups[conflict_group] = []

			conflict_groups[conflict_group].append(mod_id)

	# 检查同一冲突组内的改造确实应该冲突（相同效果类型）
	var conflicting_types = {
		"ammunition": true,  # 弹药类型
		"optics": true,      # 光学设备
		"fire_rate": true,   # 射速
		"armor": true,       # 装甲
	}

	for group in conflict_groups.keys():
		if group in conflicting_types:
			continue  # 已知冲突组
		else:
			# 未知冲突组，发出警告
			print("  ⚠ 未知冲突组：%s（包含%d个改造）" % [group, conflict_groups[group].size()])

	return errors
