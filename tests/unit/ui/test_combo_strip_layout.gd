class_name ComboStripLayoutTest
extends GdUnitTestSuite
## v6.35.2 回归锁：组合技条布局（用户拍板移除 🤝n/5 搭档钮与 🛡n/6 套装钮）。
##
## 根因复盘（实机"组合技框和关卡信息框重叠"）：v21 P2/R1-8 两个聚合钮把条子
## custom_minimum_size 撑到 468px（rect 8..480），而 TopHudBar 的关卡信息 Capsule
## 实测左缘 x=435（探针实测 rect P(435,1) S(410,52)）——x∈[435,480] 交叠，
## 聚合钮恰好在条子最右端被 Capsule 压住。移除后条子回 ~360px（8..368），
## 与 Capsule 左缘留 67px 间隙。
##
## 记录5#9（用户拍板）：6 图标改 GridContainer 两行制（一行 5 个）+ 图标悬停可弹
## tooltip（mouse_filter STOP）。
##
## 契约（scenes/ui/combo_status_strip.gd）：
## ① 条上恰好 6 个套路图标按钮，无任何聚合计数钮（"1/5"/"2/6"式按钮防复活）；
## ② custom_minimum_size.x ≤ 430（Capsule 左缘 435 − 8 偏移 = 预算上限）；
## ③ 悬停查询仍可用：_build_tooltip 对 6 套 id 均产出非空文本；
## ④ 图标 mouse_filter=STOP（悬停提示可达，IGNORE=零提示是记录5#9 主诉根因）；
## ⑤ 两行制：GridContainer columns=5（第 6 个换行）。

const StripScene := preload("res://scenes/ui/combo_status_strip.tscn")

var _strip: Control = null


func before_test() -> void:
	_strip = StripScene.instantiate()
	get_tree().root.add_child(_strip)
	for i in range(3):
		await get_tree().process_frame


func after_test() -> void:
	if is_instance_valid(_strip):
		_strip.queue_free()
	_strip = null


func _hbox_buttons() -> Array:
	var out: Array = []
	var stack: Array = [_strip]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Button:
			out.append(n)
		for c in n.get_children():
			stack.push_back(c)
	return out


## ① 6 个图标按钮、零聚合钮（回退旧代码/复活 🤝🛡 钮此断言必红）
func test_six_icon_buttons_no_aggregate_counters() -> void:
	var btns := _hbox_buttons()
	assert_int(btns.size()).is_equal(6)
	for b in btns:
		var text := String((b as Button).text)
		assert_bool(text.contains("/5")).is_false()
		assert_bool(text.contains("/6")).is_false()


## ② 宽度不越界：Capsule 左缘 435 − 条子偏移 8 = 427 上限（留 8px 余量取 430）
func test_strip_width_within_top_budget() -> void:
	assert_int(int(_strip.custom_minimum_size.x)).is_less_equal(430)
	var rect: Rect2 = _strip.get_global_rect()
	assert_int(int(rect.position.x + rect.size.x)).is_less_equal(435)


## ③ tooltip 链路健在
func test_tooltips_still_built() -> void:
	for entry in _strip.get("_icon_buttons"):
		var text := String((entry["btn"] as Button).tooltip_text)
		assert_bool(text.is_empty()).is_false()


## ④ 记录5#9：图标可悬停（mouse_filter STOP；IGNORE=悬浮零提示主诉根因）
func test_icon_buttons_hoverable() -> void:
	for entry in _strip.get("_icon_buttons"):
		var mf: int = (entry["btn"] as Control).mouse_filter
		assert_int(mf).is_not_equal(Control.MOUSE_FILTER_IGNORE)


## ⑤ 记录5#9：两行制——图标容器为 GridContainer 且 columns=5（第 6 个换行）
func test_two_row_grid_layout() -> void:
	var grid := _find_grid(_strip)
	assert_object(grid).is_not_null()
	assert_int((grid as GridContainer).columns).is_equal(5)
	assert_int((grid as GridContainer).get_child_count()).is_equal(6)


func _find_grid(n: Node) -> GridContainer:
	if n is GridContainer:
		return n
	for c in n.get_children():
		var g := _find_grid(c)
		if g != null:
			return g
	return null
