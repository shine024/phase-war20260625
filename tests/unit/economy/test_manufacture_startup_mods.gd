extends GdUnitTestSuite
## v6.14.5 出厂随机改造回归锁：数量阶梯 / 稀有度上限 / 冲突组 / 时代带口径
## 纯选取函数（pick_startup_mods）为静态，无 autoload 依赖。

const ManufactureManagerScript = preload("res://managers/manufacture_manager.gd")
const Registry = preload("res://scripts/systems/modification_registry.gd")
const ModManufacture = preload("res://data/mod_manufacture.gd")


func test_common_grants_none() -> void:
	# 白板起步语义：普通品质不出厂改造
	assert_int((ManufactureManagerScript.pick_startup_mods("ww1_mp18", 0, "common") as Array).size())\
		.is_equal(0)


func test_rare_grants_two() -> void:
	assert_int((ManufactureManagerScript.pick_startup_mods("ww1_mp18", 0, "rare") as Array).size())\
		.is_equal(2)


func test_mythic_grants_five_within_quality_and_conflict_free() -> void:
	var granted: Array = ManufactureManagerScript.pick_startup_mods("ww1_mp18", 0, "mythic")
	assert_int(granted.size()).is_equal(5)
	var groups := {}
	for mid in granted:
		var md: Dictionary = Registry.get_data(String(mid))
		assert_bool(ModManufacture.rank_of(String(md.get("rarity", "common"))) <= ModManufacture.rank_of("mythic"))\
			.is_true()
		var g := String(md.get("conflict_group", ""))
		if not g.is_empty():
			assert_bool(groups.has(g)).is_false()
			groups[g] = true


func test_era_band_respected() -> void:
	# era0 卡的出厂件必须 era0 兼容（与安装口径 get_installable_mods_for_card 同源）
	for i in 20:
		for mid in ManufactureManagerScript.pick_startup_mods("ww1_mp18", 0, "rare"):
			assert_bool(Registry.is_mod_era_compatible(Registry.get_data(String(mid)), 0)).is_true()
