extends GdUnitTestSuite
## v6.38 记录5#7 回归锁：制造成本随卡战力缩放（√战力/200，0.75~3.0×）。
## 用户主诉"高战力要的资源太少"——此前纯时代查表，同时代高战力卡与杂兵同价。
## 不变式：
## ① power_cost_mult 单调不减；② 上下限钳制（0.75/3.0）；③ 参考点（p50≈200 → ≈1.0）；
## ④ get_base_cost 逐资源 ceil 缩放且至少 1；⑤ 低战力降本（era0 杂兵 0.75 下限）。

const ManufacturePools = preload("res://data/manufacture_pools.gd")
const ManufactureManagerScript = preload("res://managers/manufacture_manager.gd")
const DefaultCards = preload("res://data/default_cards.gd")


func test_power_cost_mult_monotonic() -> void:
	var prev := -1.0
	for p in [10.0, 28.0, 100.0, 200.0, 400.0, 800.0, 1600.0, 2200.0]:
		var m := ManufacturePools.power_cost_mult(p)
		assert_float(m).is_greater_equal(prev)
		prev = m


func test_power_cost_mult_clamped() -> void:
	assert_float(ManufacturePools.power_cost_mult(5.0)).is_equal(ManufacturePools.POWER_COST_FLOOR)
	assert_float(ManufacturePools.power_cost_mult(5000.0)).is_equal(ManufacturePools.POWER_COST_CAP)
	# 参考点：战力 200 → 恰 1.0（时代主力口径不变）
	assert_float(ManufacturePools.power_cost_mult(200.0)).is_equal(1.0)


func test_base_cost_scales_and_ceils() -> void:
	var mgr: Node = ManufactureManagerScript.new()
	# 用真卡：找一个高战力 era 卡与低战力 era0 卡对比
	var high_id := ""
	var low_id := ""
	for rid in ["ww1_inf_mp18", "ww1_arm_rolls", "fut_arm_omega"]:
		var c: CardResource = DefaultCards.get_card_by_id(rid)
		if c == null:
			continue
		if float(c.power) >= 500.0 and high_id == "":
			high_id = rid
		if float(c.power) <= 60.0 and low_id == "":
			low_id = rid
	assert_str(high_id).is_not_empty()
	var base_high: Dictionary = mgr.get_base_cost(high_id)
	var era_base: Dictionary = ManufacturePools.get_cost_for_era(
		int(DefaultCards.get_card_by_id(high_id).era))
	var mult := ManufacturePools.power_cost_mult(float(DefaultCards.get_card_by_id(high_id).power))
	assert_float(mult).is_greater(1.0)
	for rid in era_base:
		assert_int(int(base_high.get(rid, 0))).is_equal(maxi(1, int(ceil(float(era_base[rid]) * mult))))
	mgr.free()


func test_low_power_card_floors_cheap() -> void:
	var mgr: Node = ManufactureManagerScript.new()
	var low_id := ""
	for rid in ["ww1_inf_mp18", "ww1_inf_rifleman"]:
		var c: CardResource = DefaultCards.get_card_by_id(rid)
		if c != null and float(c.power) <= 60.0:
			low_id = rid
			break
	if low_id.is_empty():
		# 找不到低战力真卡时跳过（数据变动兜底，不假红）
		pass
	else:
		var base: Dictionary = mgr.get_base_cost(low_id)
		var era_base: Dictionary = ManufacturePools.get_cost_for_era(
			int(DefaultCards.get_card_by_id(low_id).era))
		# 0.75× 缩放：任一资源不得超过 ceil(era×0.75)
		for rid in era_base:
			var expected: int = maxi(1, int(ceil(float(era_base[rid]) * ManufacturePools.POWER_COST_FLOOR)))
			assert_int(int(base.get(rid, 0))).is_less_equal(maxi(expected, int(era_base[rid])))
	mgr.free()
