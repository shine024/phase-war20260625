## 新系统集成测试
## 测试改造系统和注册表（v6.11：军衔称号系统已移除）

extends SceneTree

const ModificationRegistry = preload("res://scripts/systems/modification_registry.gd")
const InfantryModifications = preload("res://data/modification_modules/infantry_mods.gd")

func _init() -> void:
	print("=== 新系统集成测试 ===")
	_test_all()
	quit()

func _test_all() -> void:
	var errors = []

	# 1. 测试改造注册表
	print("\n[1/3] 测试改造注册表...")
	if not _test_modification_registry():
		errors.append("改造注册表测试失败")

	# 2. 测试改造数据访问
	print("\n[2/3] 测试改造数据访问...")
	if not _test_mod_data_access():
		errors.append("改造数据访问测试失败")

	# 3. 测试ID格式验证
	print("\n[3/3] 测试ID格式验证...")
	if not _test_id_format():
		errors.append("ID格式验证失败")

	# 输出结果
	print("\n=== 测试结果 ===")
	if errors.is_empty():
		print("✓ 所有测试通过")
	else:
		print("✗ 测试失败：")
		for error in errors:
			print("  - %s" % error)

func _test_modification_registry() -> bool:
	# 注册所有改造
	ModificationRegistry.register_all()

	# 检查总数量
	var all_ids = ModificationRegistry.get_all_ids()
	print("  注册改造总数：%d" % all_ids.size())

	if all_ids.size() < 117:
		print("  ✗ 改造数量不足（预期>=117）")
		return false

	print("  ✓ 改造注册表正常")
	return true

func _test_mod_data_access() -> bool:
	# 测试步兵改造数据访问
	var mod_id = "inf_01_submachine_gun"
	var data = InfantryModifications.get_mod_data(mod_id)

	if data.is_empty():
		print("  ✗ 改造数据为空：%s" % mod_id)
		return false

	var required_fields = ["id", "name", "name_en", "prototype", "description", "rarity", "effects", "conflict_group"]
	for field in required_fields:
		if not data.has(field):
			print("  ✗ 缺少字段：%s" % field)
			return false

	print("  ✓ 改造数据访问正常")
	return true

func _test_id_format() -> bool:
	# 测试改造ID格式
	var all_ids = InfantryModifications.get_all_mod_ids()

	for mod_id in all_ids:
		if not mod_id.begins_with("inf_"):
			print("  ✗ ID格式错误：%s" % mod_id)
			return false

	print("  ✓ ID格式验证通过")
	return true
