class_name CruiseMissileFlavorTest
extends GdUnitTestSuite
## v38.x F 条回归锁：发射井巡航导弹（cold_fort_missile"反舰巡航导弹"）分流。
## 弹道端 classify_indirect==CRUISE（陡升重弹冷白），命中端 spawn_cruise_impact
## 专属签名层；普通"导弹"/火箭弹不得被误分流。

func test_cruise_classified_as_cruise() -> void:
	assert_int(WeaponProjectileVfx.classify_indirect("反舰巡航导弹")).is_equal(
		WeaponProjectileVfx.IndirectFlavor.CRUISE)


func test_generic_missile_still_missile() -> void:
	# "巡航"关键词必须优先于通用"导弹"匹配（分支顺序回归锁）
	assert_int(WeaponProjectileVfx.classify_indirect("导弹")).is_equal(
		WeaponProjectileVfx.IndirectFlavor.MISSILE)


func test_rocket_untouched() -> void:
	assert_int(WeaponProjectileVfx.classify_indirect("火箭弹")).is_equal(
		WeaponProjectileVfx.IndirectFlavor.ROCKET)


func test_empty_and_unknown_untouched() -> void:
	assert_int(WeaponProjectileVfx.classify_indirect("")).is_equal(
		WeaponProjectileVfx.IndirectFlavor.NONE)


func test_cruise_missile_card_name_classifies() -> void:
	# 卡牌真名（data/unified_card_table.gd cold_fort_missile w_armor）端到端
	var card_name: String = "反舰巡航导弹"
	assert_int(WeaponProjectileVfx.classify_indirect(card_name)).is_equal(
		WeaponProjectileVfx.IndirectFlavor.CRUISE)
