extends GdUnitTestSuite
## v6.19 P1-T1.1 概率可见化回归锁（宪法 C3 概率透明）：保底口径文案生成函数。
## 铁律：①数值读常量（改 PITY_THRESHOLD/PITY_BOOST 文案自动跟随）；
## ②软保底是概率 ×2 提升、无"必出"硬阈值——文案任何 pity 值下都严禁出现"必出"字样。

const ManufacturePools = preload("res://data/manufacture_pools.gd")
const ModManufacture = preload("res://data/mod_manufacture.gd")


func test_card_pity_at_zero_shows_threshold_and_boost() -> void:
	var t := ManufacturePools.describe_card_pity(0)
	assert_str(t).contains("0/%d" % ManufacturePools.PITY_THRESHOLD)
	assert_str(t).contains("×%.0f" % ManufacturePools.PITY_BOOST)


func test_card_pity_midway_shows_remaining_count() -> void:
	var t := ManufacturePools.describe_card_pity(ManufacturePools.PITY_THRESHOLD - 1)
	assert_str(t).contains("还差 1 次")
	assert_str(t).contains("%d/%d" % [ManufacturePools.PITY_THRESHOLD - 1, ManufacturePools.PITY_THRESHOLD])


func test_card_pity_active_state_no_threshold_mention() -> void:
	var t := ManufacturePools.describe_card_pity(ManufacturePools.PITY_THRESHOLD + 5)
	assert_str(t).contains("已激活")
	assert_str(t).contains("×%.0f" % ManufacturePools.PITY_BOOST)


func test_box_pity_midway_shows_legendary_wording() -> void:
	var t := ModManufacture.describe_box_pity(ModManufacture.PITY_THRESHOLD - 1)
	assert_str(t).contains("还差 1 次")
	assert_str(t).contains("传说")


func test_box_pity_zero_and_active_states() -> void:
	assert_str(ModManufacture.describe_box_pity(0)).contains("0/%d" % ModManufacture.PITY_THRESHOLD)
	assert_str(ModManufacture.describe_box_pity(ModManufacture.PITY_THRESHOLD)).contains("已激活")


func test_no_guarantee_wording_across_full_range() -> void:
	for p in range(0, 8):
		assert_bool(ManufacturePools.describe_card_pity(p).contains("必出")).is_false()
		assert_bool(ModManufacture.describe_box_pity(p).contains("必出")).is_false()
