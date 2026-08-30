class_name DropEscrowTest
extends GdUnitTestSuite
## v23.6(归仓)：DropManager 战利品暂存池单测
## 覆盖：deposit 聚合/类别判定、按类别收取、全收、存档往返、残留路由、退役类型过滤。
## 实例化局部 DropManager（Node.new+set_script），不动 autoload 存量状态；
## 收取断言用资源余额差值（claim 管线会乘符文产出加成，测试环境为 1.0）。

const DropTables = preload("res://resources/drop_tables.gd")
const _SOURCE := "res://managers/drop_manager.gd"
const _BasicResources = preload("res://data/basic_resources.gd")

var _dm: Node


func before_test() -> void:
	_dm = Node.new()
	_dm.set_script(load(_SOURCE))
	add_child(_dm)
	_dm.pending_drops.clear()
	_dm._escrow.clear()


func after_test() -> void:
	if _dm != null and is_instance_valid(_dm):
		if _dm.is_inside_tree():
			remove_child(_dm)
		_dm.queue_free()
	_dm = null


func _make_drop(item_id: String, drop_type: int, count: int) -> DropTables.DropResult:
	var entry = DropTables.DropEntry.new(item_id, drop_type, 1.0, count, count)
	return DropTables.DropResult.new(entry, count, "test")


func test_deposit_categorizes_and_aggregates() -> void:
	_dm.pending_drops.append(_make_drop("nano_materials", DropTables.DropType.MATERIAL, 30))
	_dm.pending_drops.append(_make_drop("alloy", DropTables.DropType.MATERIAL, 12))
	_dm.pending_drops.append(_make_drop("ww1_mauser", DropTables.DropType.DROPPED_CARD, 2))
	var moved: int = _dm.deposit_pending_to_escrow()
	assert_int(moved).is_equal(44)
	assert_array(_dm.pending_drops).is_empty()
	var cats: Array[String] = _dm.get_escrow_categories()
	assert_int(cats.size()).is_equal(2)
	assert_bool(cats.has("material")).is_true()
	assert_bool(cats.has("card")).is_true()
	assert_int(_dm.get_escrow_category_count("material")).is_equal(42)
	assert_int(_dm.get_escrow_category_count("card")).is_equal(2)
	assert_int(_dm.get_escrow_total_count()).is_equal(44)


func test_deposit_same_item_accumulates() -> void:
	_dm.pending_drops.append(_make_drop("nano_materials", DropTables.DropType.MATERIAL, 10))
	_dm.deposit_pending_to_escrow()
	_dm.pending_drops.append(_make_drop("nano_materials", DropTables.DropType.MATERIAL, 15))
	_dm.deposit_pending_to_escrow()
	assert_int(_dm.get_escrow_category_count("material")).is_equal(25)
	# 聚合后条目数有界：一个 item 一条
	assert_int(_dm._escrow.size()).is_equal(1)


func test_collect_only_requested_category() -> void:
	_dm.pending_drops.append(_make_drop("nano_materials", DropTables.DropType.MATERIAL, 25))
	_dm.pending_drops.append(_make_drop("ww1_mauser", DropTables.DropType.DROPPED_CARD, 2))
	_dm.deposit_pending_to_escrow()
	# get_total/has_method 在 autoload BasicResourceManager 上（与 game_manager.gd 同款守卫）
	var nano_before: int = BasicResourceManager.get_total(_BasicResources.ID_NANO_MATERIALS) \
			if BasicResourceManager.has_method("get_total") else -1
	var collected: Array = _dm.collect_escrow(["material"])
	assert_int(collected.size()).is_equal(1)
	assert_int(int(collected[0]["count"])).is_equal(25)
	# 材料已入账（测试环境符文加成为 0，倍率 1.0，应精确等于 25）
	if nano_before >= 0:
		var nano_after: int = BasicResourceManager.get_total(_BasicResources.ID_NANO_MATERIALS)
		assert_int(nano_after - nano_before).is_equal(25)
	# 卡类别仍在仓
	assert_int(_dm.get_escrow_category_count("card")).is_equal(2)
	assert_int(_dm.get_escrow_category_count("material")).is_equal(0)


func test_collect_all_empties_escrow() -> void:
	_dm.pending_drops.append(_make_drop("nano_materials", DropTables.DropType.MATERIAL, 5))
	_dm.pending_drops.append(_make_drop("crystal", DropTables.DropType.MATERIAL, 3))
	_dm.deposit_pending_to_escrow()
	var collected: Array = _dm.collect_escrow()
	assert_int(collected.size()).is_equal(2)
	assert_int(_dm.get_escrow_total_count()).is_equal(0)
	assert_array(_dm.get_escrow_categories()).is_empty()


func test_collect_empty_escrow_returns_empty() -> void:
	assert_array(_dm.collect_escrow()).is_empty()
	assert_array(_dm.collect_escrow(["material"])).is_empty()


func test_save_load_roundtrip() -> void:
	_dm.pending_drops.append(_make_drop("nano_materials", DropTables.DropType.MATERIAL, 40))
	_dm.pending_drops.append(_make_drop("ww1_mauser", DropTables.DropType.DROPPED_CARD, 3))
	_dm.deposit_pending_to_escrow()
	var saved: Dictionary = _dm.save_state()

	var restored := Node.new()
	restored.set_script(load(_SOURCE))
	add_child(restored)
	restored.load_state(saved)
	assert_int(restored.get_escrow_category_count("material")).is_equal(40)
	assert_int(restored.get_escrow_category_count("card")).is_equal(3)
	restored.queue_free()


func test_load_old_save_without_escrow_key() -> void:
	_dm.load_state({"story_reward_multiplier": 1.0})
	assert_int(_dm.get_escrow_total_count()).is_equal(0)


func test_stale_pending_routes_to_escrow() -> void:
	_dm.pending_drops.append(_make_drop("alloy", DropTables.DropType.MATERIAL, 7))
	_dm._auto_claim_pending_if_any()
	assert_array(_dm.pending_drops).is_empty()
	assert_int(_dm.get_escrow_category_count("material")).is_equal(7)


func test_retired_types_are_not_escrowed() -> void:
	_dm.pending_drops.append(_make_drop("energy_card_x", DropTables.DropType.ENERGY_CARD, 4))
	var moved: int = _dm.deposit_pending_to_escrow()
	assert_int(moved).is_equal(0)
	assert_array(_dm.get_escrow_categories()).is_empty()


func test_reset_clears_escrow() -> void:
	_dm.pending_drops.append(_make_drop("nano_materials", DropTables.DropType.MATERIAL, 9))
	_dm.deposit_pending_to_escrow()
	_dm.reset_to_defaults()
	assert_int(_dm.get_escrow_total_count()).is_equal(0)
	assert_array(_dm.pending_drops).is_empty()
