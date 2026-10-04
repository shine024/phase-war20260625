extends GdUnitTestSuite
## v6.41.1（2026-10-04）回归锁：大地图左下信息框布局——动作面板/图例/燃料状态行不互叠。
##
## 实机主诉（截图）：图例框与底部燃料/行驶状态行在左下角互叠，状态行还被屏幕底边裁半。
## 根因：scheme 11 floating chrome 把 Margin 边距归零后，Margin/VBox 只剩
## [ScrollContainer, 燃料chip]——chip 顶到屏幕底边（margin_bottom=0），被 chrome 栈
## （MapChromeStack，底边距 12px）压住上半截。
## 修复契约（本锁；真机目检由 tests/_tmp_v642_wm_overlap_probe.gd 承载）：
##   收编 —— 燃料 chip 挂在 MapChromeStack 栈尾（VBox 布局结构性不互叠）
##   不叠 —— actions/legend/chip 两两矩形零相交（跨帧稳定态）
##   在屏 —— 三者矩形底边 ≤ 屏幕高（不出屏不被裁）

const WmScene = preload("res://scenes/world_map.tscn")

var _wm: Node = null


func before_test() -> void:
	_wm = WmScene.instantiate()
	add_child(_wm)
	# 建图是 call_deferred + 布局 settle：等容器算完（与真机探针同口径）
	await get_tree().create_timer(0.8).timeout
	await get_tree().process_frame


func after_test() -> void:
	_wm.free()   # 立即 free（in-tree 合法）：收敛孤儿节点噪音
	await get_tree().process_frame


func _rect(node_name: String) -> Rect2:
	var n: Control = _wm.find_child(node_name, true, false) as Control
	assert_object(n).is_not_null()
	return n.get_global_rect()


func _chip() -> Control:
	return _wm.get("_fuel_chip") as Control


## 收编契约：燃料 chip 挂在 chrome 栈尾（回归=被挪回 Margin/VBox 底行再次顶屏裁切）。
func test_fuel_chip_inside_chrome_stack() -> void:
	var chip := _chip()
	assert_object(chip).is_not_null()
	assert_bool(String(chip.get_parent().name) == "MapChromeStack").is_true()


## 不叠：动作面板/图例/燃料 chip 两两矩形零相交（屏幕空间 chrome 同栏堆叠语义）。
func test_chrome_boxes_do_not_overlap() -> void:
	var actions := _rect("MapActions")
	var legend := _rect("MapLegend")
	var chip := _chip().get_global_rect()
	assert_bool(actions.intersects(legend)).is_false()
	assert_bool(legend.intersects(chip)).is_false()
	assert_bool(actions.intersects(chip)).is_false()


## 在屏：三者底边不超 world_map 根矩形底（floating chrome 后根=全屏；相对根判定
## 屏蔽测试挂载位置的全局偏移）。回归=状态行再被压回屏幕底边之外。
func test_chrome_boxes_inside_viewport() -> void:
	var wm_rect: Rect2 = (_wm as Control).get_global_rect()
	for r: Rect2 in [_rect("MapActions"), _rect("MapLegend"), _chip().get_global_rect()]:
		assert_float(r.position.y).is_greater_equal(wm_rect.position.y)
		assert_float(r.end.y).is_less_equal(wm_rect.end.y + 1.0)
