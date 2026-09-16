extends GdUnitTestSuite
## v6.14.6 卸下改造回归锁（用户拍板方案 A：图纸返还 + 纳米实付 50%）
## 出厂赠品（gift）特殊口径：纳米 0 返、无图纸返还、件消失。

const MOD_ID := "inf_07_optical_scope"
const BP := "blueprint_inf_07_optical_scope"


func _make_card() -> CardResource:
	return InstanceRegistry.create_instance("ww1_mp18")


func test_uninstall_returns_blueprint_and_half_nano() -> void:
	var card := _make_card()
	assert_int(card.mods.size()).is_equal(0)
	card.mods.append({id = MOD_ID, installed_at = 0, enabled = true, paid_cost = 100})
	var bp_before := IntelItemBag.get_count(BP)
	var r: Dictionary = BlueprintManager.uninstall_modification(card, 0)
	assert_bool(r.success).is_true()
	assert_int(card.mods.size()).is_equal(0)
	assert_int(r.refunded_nano).is_equal(50)
	assert_str(r.returned_blueprint).is_equal(BP)
	assert_int(IntelItemBag.get_count(BP)).is_equal(bp_before + 1)


func test_uninstall_gift_no_refund() -> void:
	# 出厂赠品：paid_cost=0 + gift → 纳米 0 返、图纸不返还（其图纸从未存在）
	var card := _make_card()
	card.mods.append({id = MOD_ID, installed_at = 0, enabled = true, paid_cost = 0, gift = true})
	var bp_before := IntelItemBag.get_count(BP)
	var r: Dictionary = BlueprintManager.uninstall_modification(card, 0)
	assert_bool(r.success).is_true()
	assert_int(r.refunded_nano).is_equal(0)
	assert_str(r.returned_blueprint).is_equal("")
	assert_int(IntelItemBag.get_count(BP)).is_equal(bp_before)


func test_uninstall_invalid_slot_fails() -> void:
	var card := _make_card()
	var r: Dictionary = BlueprintManager.uninstall_modification(card, 3)
	assert_bool(r.success).is_false()
