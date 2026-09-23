extends GdUnitTestSuite
## v6.14.7 直入卡制造回归锁：era0/1 直入卡（无敌形原型）的 roll 口径必须走
## _pool_base（白板档 0.25），与 can_manufacture/get_effective_pool 的 UI 口径同源。
## 修复前 manufacture() 直查 get_intel_base（恒 0）→ 空池必失败"品质池异常"。

const MP = preload("res://data/manufacture_pools.gd")
const ManufactureManagerScript = preload("res://managers/manufacture_manager.gd")

var _mm: Node = null
var _direct_id := ""


func before_test() -> void:
	var mll: Node = get_node_or_null("/root/ManagerLazyLoader")
	assert_object(mll).is_not_null()
	if mll != null:
		mll.ensure_loaded("manufacture")
	_mm = get_node_or_null("/root/ManufactureManager")
	assert_object(_mm).is_not_null()
	# 取一张 era0 直入卡（直入卡含 era0/1；era0 免时代授权门，样本最稳）
	for rid in _mm.get_recipe_ids():
		if _mm.is_direct_pool_card(String(rid)):
			var card: CardResource = load("res://data/default_cards.gd").get_card_by_id(String(rid))
			if card != null and int(card.era) == 0:
				_direct_id = String(rid)
				break
	assert_str(_direct_id).is_not_empty()


func test_pool_base_white_tier_while_intel_zero() -> void:
	# 复现条件与修复口径：直入卡情报恒 0，但 _pool_base 抬到配方门 0.25
	assert_float(float(_mm.get_intel_base(_direct_id))).is_equal(0.0)
	assert_float(float(_mm._pool_base(_direct_id))).is_equal(MP.GATE_RECIPE)


func test_roll_with_pool_base_never_empty() -> void:
	# 修复行为：_pool_base 口径 roll 恒非空（白板档=普通 100%）
	for i in 20:
		var r: String = MP.roll_rarity(float(_mm._pool_base(_direct_id)), 0, 1.0)
		assert_str(r).is_not_empty()


func test_roll_with_raw_intel_empty_regardless_of_luck() -> void:
	# 旧行为锁：裸 intel 0 掷池恒空——保证该口径不会再被误用回 manufacture()
	for pity in 30:
		assert_str(MP.roll_rarity(0.0, pity, 1.0)).is_empty()


func test_ui_effective_pool_same_source() -> void:
	# UI 预览与 roll 同源：直入卡的有效概率池必须非空
	var pool: Array = _mm.get_effective_pool(_direct_id)
	assert_array(pool).is_not_empty()


func after_test() -> void:
	# 懒加载实例会以孤儿节点计进报表统计，测试完显式摘除
	#（MLL 缓存有 is_instance_valid 校验，后续用例会自动重建）
	if _mm != null and is_instance_valid(_mm):
		_mm.get_parent().remove_child(_mm)
		_mm.free()
	_mm = null
