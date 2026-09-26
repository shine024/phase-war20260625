extends GdUnitTestSuite
## v32.3 C2 回归锁：背包空槽"只增不减棘轮"修复。
## 原缺陷：_ensure_min_card_slots 把空槽占位计入卡数 → 目标=含空槽总数+整行，
## 每次装备/移除净增 5 空槽直到 50 上限（实机验收："装配一个卡，背包多出几个空槽"）。
## v6.30（记录3#1/#3 用户拍板）：补位改**整行制**——基准=grid.columns（实际列数），
## 目标=ceil(卡数/列数)×列数 + 一整行；残行（"一行+零散几格"）根因即旧常数 6 与
## 实际列数（6~14 宽度自适应）取模对不齐。
## 本测试用脚本级实例 + 假卡子节点直测计数规则（不实例化整个面板场景）；
## grid.columns 显式设 6 模拟真实面板（_apply_backpack_grid_layout 已先设好列数）。

const BackpackPanelScript = preload("res://scenes/ui/backpack_panel.gd")

var _panel: Control = null
var _grid: GridContainer = null


func before_test() -> void:
	_panel = BackpackPanelScript.new()
	_grid = GridContainer.new()
	_grid.columns = 6  # 真实面板由 _apply_backpack_grid_layout 设定，测试显式对齐
	_panel.add_child(_grid)


func after_test() -> void:
	if is_instance_valid(_panel):
		# 回收被修剪进池的空槽（池节点已不在树里，free() 不会级联到它们）
		for ph in _panel._empty_slot_pool:
			if is_instance_valid(ph):
				ph.free()
		_panel._empty_slot_pool.clear()
		_panel.free()


func _add_fake_card() -> void:
	# 假卡 = 无任何 meta 的子节点（_ensure 的计数规则：非 resource/hint/empty 即为卡）
	_grid.add_child(Control.new())


func _count(kind: String) -> int:
	var n := 0
	for child in _grid.get_children():
		if child.has_meta(kind) and bool(child.get_meta(kind)):
			n += 1
	return n


func _total_children() -> int:
	return _grid.get_child_count()


func test_initial_slots_one_row_margin() -> void:
	for i in 3:
		_add_fake_card()
	_panel._ensure_min_card_slots(_grid)
	# 3 张卡 6 列 → 1 整行 + 多一整行 = 12 → 空槽 9（整行制：末行必满）
	assert_int(_count("is_empty_slot")).is_equal(9)
	assert_int(_total_children()).is_equal(12)


func test_remove_card_does_not_grow_slots() -> void:
	for i in 3:
		_add_fake_card()
	_panel._ensure_min_card_slots(_grid)
	# 连续移除卡（模拟装备扣卡），总数不得净增（3→2→1 张都在同一行内）
	for expected_cards: int in [2, 1]:
		var removed: Control = _grid.get_child(0)
		_grid.remove_child(removed)
		removed.free()  # 及时释放：孤儿节点会污染测试报告
		_panel._ensure_min_card_slots(_grid)
		var empties := _count("is_empty_slot")
		assert_int(_total_children()).is_equal(12)
		assert_int(empties).is_equal(12 - expected_cards)


func test_legacy_bloat_trims_back() -> void:
	# 模拟旧档残留：2 张卡 + 48 个空槽（棘轮膨胀态）→ 收敛回整行 12
	for i in 2:
		_add_fake_card()
	for i in 48:
		var ph := Panel.new()
		ph.set_meta("is_empty_slot", true)
		_grid.add_child(ph)
	_panel._ensure_min_card_slots(_grid)
	assert_int(_count("is_empty_slot")).is_equal(10)
	assert_int(_total_children()).is_equal(12)


func test_empty_hint_and_resource_slots_not_counted() -> void:
	# is_empty_hint（空状态提示）与 is_resource_slot（资源格）都不计入卡数
	var hint := Control.new()
	hint.set_meta("is_empty_hint", true)
	_grid.add_child(hint)
	var res := Control.new()
	res.set_meta("is_resource_slot", true)
	_grid.add_child(res)
	_add_fake_card()
	_panel._ensure_min_card_slots(_grid)
	# 1 张真实卡 → 2 整行 = 12 → 空槽 11
	assert_int(_count("is_empty_slot")).is_equal(11)


func test_full_row_boundary() -> void:
	# v6.30 整行制边界：卡数恰为列数整数倍时（6 张 6 列=1 满行）仍多补一整行，
	# 7 张（1 满行+1 张）补到 3 整行——任何卡数下末行必满
	for i in 6:
		_add_fake_card()
	_panel._ensure_min_card_slots(_grid)
	assert_int(_total_children()).is_equal(12)
	var extra := Control.new()
	_grid.add_child(extra)
	_panel._ensure_min_card_slots(_grid)
	assert_int(_total_children()).is_equal(18)
	extra.free()
