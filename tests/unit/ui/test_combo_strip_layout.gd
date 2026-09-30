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
## 契约（scenes/ui/combo_status_strip.gd）：
## ① 条上恰好 6 个套路图标按钮，无任何聚合计数钮（"1/5"/"2/6"式按钮防复活）；
## ② custom_minimum_size.x ≤ 430（Capsule 左缘 435 − 8 偏移 = 预算上限）；
## ③ 悬停查询仍可用：_build_tooltip 对 6 套 id 均产出非空文本。

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
