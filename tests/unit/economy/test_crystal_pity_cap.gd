extends GdUnitTestSuite
## v6.19.1 核验清单#4 回归锁：晶体垫封顶——pity ≤ 阈值-1（不卖免费保底，
## 原 v32.0 TODO 落地）。部分成交：请求超额度时只成交到激活线前；已到线拒绝。

const ModManufacture = preload("res://data/mod_manufacture.gd")


func _mgr() -> Node:
	var mll = get_node_or_null("/root/ManagerLazyLoader")
	if mll == null:
		return null
	mll.ensure_loaded("manufacture")
	return get_node_or_null("/root/ManufactureManager")


func before_test() -> void:
	var mgr := _mgr()
	if mgr != null:
		mgr._mod_box_pity = 0
		BasicResourceManager.add_resource("crystal", 10000)


func after_test() -> void:
	var mgr := _mgr()
	if mgr != null:
		mgr._mod_box_pity = 0


func test_cap_rejects_when_pity_at_ready_line() -> void:
	var mgr := _mgr()
	mgr._mod_box_pity = ModManufacture.PITY_THRESHOLD - 1  # 已垫到激活线前
	var r: Dictionary = mgr.advance_mod_box_pity_with_crystals(1)
	assert_bool(bool(r.get("ok", false))).is_false()
	assert_int(mgr.get_mod_box_pity()).is_equal(ModManufacture.PITY_THRESHOLD - 1)


func test_partial_fill_only_to_ready_line() -> void:
	var mgr := _mgr()
	var r: Dictionary = mgr.advance_mod_box_pity_with_crystals(3)  # 请求 3 只成交到激活线前
	var expect: int = ModManufacture.PITY_THRESHOLD - 1
	assert_bool(bool(r.get("ok", false))).is_true()
	assert_int(int(r.get("advanced", 0))).is_equal(expect)
	assert_int(int(r.get("crystal_spent", 0))).is_equal(expect * 80)
	assert_bool(bool(r.get("capped", false))).is_true()
	assert_int(mgr.get_mod_box_pity()).is_equal(expect)


func test_below_cap_charges_full() -> void:
	var mgr := _mgr()
	var r: Dictionary = mgr.advance_mod_box_pity_with_crystals(1)
	assert_bool(bool(r.get("ok", false))).is_true()
	assert_int(int(r.get("crystal_spent", 0))).is_equal(80)
	assert_bool(bool(r.get("capped", true))).is_false()
	assert_int(mgr.get_mod_box_pity()).is_equal(1)
