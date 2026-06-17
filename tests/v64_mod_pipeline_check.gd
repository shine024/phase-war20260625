extends SceneTree
## v6.4 改造统一管线快速验证脚本（preload 模式，不依赖 autoload）
## 用法: godot --headless --script tests/v64_mod_pipeline_check.gd

const ModificationRegistry = preload("res://scripts/systems/modification_registry.gd")

func _init():
	print("=== v6.4 改造统一管线验证 ===")

	ModificationRegistry.register_all()
	var all_ids = ModificationRegistry.get_all_ids()
	var total = all_ids.size()
	print("[INFO] 改造条目总数: %d" % total)

	# 测试1: enh_hp_up 三级效果递增
	var base1 = {"max_hp": 100.0, "attack_light": 10.0, "attack_armor": 10.0, "attack_air": 10.0}
	var r1 = ModificationRegistry.apply_with_level(base1, [{id = "enh_hp_up", level = 1}])
	var r2 = ModificationRegistry.apply_with_level(base1, [{id = "enh_hp_up", level = 2}])
	var r3 = ModificationRegistry.apply_with_level(base1, [{id = "enh_hp_up", level = 3}])
	print("[TEST1] enh_hp_up Lv1/2/3 max_hp = %.1f / %.1f / %.1f" % [r1.max_hp, r2.max_hp, r3.max_hp])
	if r3.max_hp > r2.max_hp and r2.max_hp > r1.max_hp and r1.max_hp > base1.max_hp:
		print("  -> PASS: 三级递增正确")
	else:
		print("  -> FAIL: 三级递增异常")

	# 测试2: eom_infantry_tactics（敌源MOD迁移自系统C）
	# 该MOD的 level_effects 修改 max_hp + defense_*，不改 attack_*
	var base2 = {"attack_light": 20.0, "attack_armor": 20.0, "attack_air": 20.0,
				 "max_hp": 100.0, "defense_light": 5.0, "defense_armor": 5.0, "defense_air": 5.0}
	var r4 = ModificationRegistry.apply_with_level(base2, [{id = "eom_infantry_tactics", level = 1}])
	print("[TEST2] eom_infantry_tactics Lv1: max_hp=%.1f (base=100), defense_light=%.1f (base=5)" % [r4.max_hp, r4.defense_light])
	if r4.max_hp > base2.max_hp and r4.defense_light > base2.defense_light:
		print("  -> PASS: 敌源MOD生效")
	else:
		print("  -> FAIL: 敌源MOD未生效")

	# 测试3: enh_dmg_up 升级效果
	var base3 = {"attack_light": 10.0, "attack_armor": 10.0, "attack_air": 10.0, "max_hp": 50.0}
	var r5 = ModificationRegistry.apply_with_level(base3, [{id = "enh_dmg_up", level = 2}])
	print("[TEST3] enh_dmg_up Lv2 attack_light=%.1f (base=10.0)" % r5.attack_light)
	if r5.attack_light > base3.attack_light:
		print("  -> PASS: 词条升级生效")
	else:
		print("  -> FAIL: 词条升级未生效")

	# 测试4: 多条改造叠加
	var base4 = {"max_hp": 100.0, "attack_light": 10.0, "attack_armor": 10.0, "attack_air": 10.0,
				 "crit_chance": 0.0, "armor_penetration": 0.0}
	var mods4 = [
		{id = "enh_hp_up", level = 2},
		{id = "enh_crit", level = 1},
	]
	var r6 = ModificationRegistry.apply_with_level(base4, mods4)
	print("[TEST4] 多改造叠加: max_hp=%.1f crit_chance=%.2f" % [r6.max_hp, r6.crit_chance])
	if r6.max_hp > base4.max_hp and r6.crit_chance > base4.crit_chance:
		print("  -> PASS: 多改造叠加正确")
	else:
		print("  -> FAIL: 多改造叠加异常")

	# 测试5: 纯String格式兼容（无level，默认1级）
	var base5 = {"max_hp": 100.0, "attack_light": 10.0, "attack_armor": 10.0, "attack_air": 10.0}
	var r7 = ModificationRegistry.apply_with_level(base5, ["enh_hp_up"])
	print("[TEST5] 纯String格式 enh_hp_up max_hp=%.1f (base=100.0)" % r7.max_hp)
	if r7.max_hp > base5.max_hp:
		print("  -> PASS: 纯String格式兼容")
	else:
		print("  -> FAIL: 纯String格式异常")

	# 测试6: 抽样打印各类型条目数量
	var type_count = {}
	for mid in all_ids:
		var prefix = mid.split("_")[0]
		type_count[prefix] = type_count.get(prefix, 0) + 1
	print("[INFO] 各前缀分布: ", type_count)

	print("=== 验证完成 ===")
	quit()
