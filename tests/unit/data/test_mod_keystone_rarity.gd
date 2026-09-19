class_name ModKeystoneRarityTest
extends GdUnitTestSuite
## v6.16 门槛核心件 + 稀有度收敛回归锁。
## B 层数据契约：
##   - 10 条纯数值传奇降级 epic（传奇 49→39、史诗 78→88；总数 249 不变）
##   - 16 条 KEYSTONE_IDS 门槛件：全传奇、全带显式代价、注册表可查
##   - pct 数值帽分档：legendary 0.8 / mythic 1.0 / 其余 0.6

const ModRegistry = preload("res://scripts/systems/modification_registry.gd")

const DEMOTED := [
	"air_02_vector_thrust", "air_03_stealth_coating", "arm_09_turbine",
	"arm_23_platoon_datalink", "eng_11_breaching_charge", "for_06_radar",
	"for_10_command", "for_13_command_bunker", "inf_16_exoskeleton",
	"inf_35_field_hospital",
]


func _rarity_counts() -> Dictionary:
	ModRegistry.register_all()
	var counts: Dictionary = {}
	for mid in ModRegistry.get_all_ids():
		var r: String = String(ModRegistry.get_data(mid).get("rarity", "?"))
		counts[r] = int(counts.get(r, 0)) + 1
	return counts


func test_rarity_deflation() -> void:
	var counts := _rarity_counts()
	assert_int(int(counts.get("legendary", 0))).is_equal(39)
	assert_int(int(counts.get("epic", 0))).is_equal(88)
	assert_int(int(counts.get("mythic", 0))).is_equal(3)
	# 总数锁不变（与 modification_modules_test 同源）
	var total: int = 0
	for r in counts.keys():
		total += int(counts[r])
	assert_int(total).is_equal(249)


func test_demoted_are_epic_now() -> void:
	ModRegistry.register_all()
	for mid in DEMOTED:
		var data: Dictionary = ModRegistry.get_data(mid)
		assert_str(String(data.get("rarity", ""))).override_failure_message("%s 应已降级 epic" % mid).is_equal("epic")


func test_keystones_flagged_with_tradeoffs() -> void:
	ModRegistry.register_all()
	assert_int(ModRegistry.KEYSTONE_IDS.size()).is_equal(16)
	for mid in ModRegistry.KEYSTONE_IDS:
		var data: Dictionary = ModRegistry.get_data(mid)
		assert_bool(not data.is_empty()).override_failure_message("门槛件 %s 注册表取不到" % mid).is_true()
		assert_str(String(data.get("rarity", ""))).override_failure_message("%s 门槛件必须传奇" % mid).is_equal("legendary")
		assert_bool(bool(data.get("keystone", false))).override_failure_message("%s 缺 keystone 标记" % mid).is_true()
		# 显式代价：effects 或任一 level_effects 必含负值键（D2 独特件纪律）
		var has_cost: bool = _has_negative_value(data.get("effects", {}))
		for lv in (data.get("level_effects", {}) as Dictionary).keys():
			has_cost = has_cost or _has_negative_value(data.level_effects[lv])
		assert_bool(has_cost).override_failure_message("%s 门槛件缺显式代价" % mid).is_true()


func _has_negative_value(effects: Dictionary) -> bool:
	for k in effects.keys():
		var v: Variant = effects[k]
		if (v is float or v is int) and float(v) < 0.0:
			return true
	return false


func test_stat_value_cap_tiers() -> void:
	assert_float(ModRegistry.get_stat_value_cap("common")).is_equal(0.6)
	assert_float(ModRegistry.get_stat_value_cap("rare")).is_equal(0.6)
	assert_float(ModRegistry.get_stat_value_cap("epic")).is_equal(0.6)
	assert_float(ModRegistry.get_stat_value_cap("legendary")).is_equal(0.8)
	assert_float(ModRegistry.get_stat_value_cap("mythic")).is_equal(1.0)
	# 未知稀有度回退 0.6（宁紧勿松）
	assert_float(ModRegistry.get_stat_value_cap("???")).is_equal(0.6)
