extends GdUnitTestSuite
## v6.23 卡牌信息框避让 toast 堆叠区回归锁（build/记录.txt 主诉⑥：
## "单位部署次数已尽"toast 盖住敌方信息框）。
## 覆盖 _avoid_toast_zone 三分支：无 toast 跳过 / 相交左移 / 左侧放不下下移。

const PANEL_SCENE := "res://scenes/ui/card_info_panel.tscn"

var _panel: Node = null
var _fake_toast: Control = null


func before_test() -> void:
	_panel = (load(PANEL_SCENE) as PackedScene).instantiate()
	add_child(_panel)


func after_test() -> void:
	_clear_fake_toast()
	if is_instance_valid(_panel):
		_panel.free()
	_panel = null


func _clear_fake_toast() -> void:
	if _fake_toast != null and is_instance_valid(_fake_toast):
		_fake_toast.get_parent().remove_child(_fake_toast)
		_fake_toast.free()
	_fake_toast = null


func _toast_container() -> Control:
	var tm: Node = get_tree().root.get_node_or_null("/root/ToastManager")
	assert_object(tm).is_not_null()
	return tm.get_toast_container() as Control


## 塞一条假 toast 让容器有实际高度（空 VBox 高 0，intersects 恒 false）
func _install_fake_toast() -> void:
	var cont := _toast_container()
	_fake_toast = PanelContainer.new()
	var lbl := Label.new()
	lbl.text = "该单位部署次数已耗尽，本场战斗无法再部署。"
	lbl.custom_minimum_size = Vector2(272.0, 40.0)
	_fake_toast.add_child(lbl)
	cont.add_child(_fake_toast)
	await get_tree().process_frame  # 容器排序一帧，get_global_rect 生效


func test_no_toast_passthrough() -> void:
	var pos := Vector2(100.0, 300.0)
	var out: Vector2 = _panel._avoid_toast_zone(pos, 560.0, 400.0, 720.0)
	assert_vector(out).is_equal(pos)


func test_intersect_shifts_left() -> void:
	await _install_fake_toast()
	var cont := _toast_container()
	var tr: Rect2 = cont.get_global_rect()
	assert_float(tr.size.y).is_greater(0.0)
	# 面板右上角恰压住 toast 区（信息框默认从单位右上偏移 (60,-80)，右上单位即撞 toast 区）
	var pos := Vector2(tr.position.x + 50.0, tr.position.y + 20.0)
	var out: Vector2 = _panel._avoid_toast_zone(pos, 560.0, 400.0, 720.0)
	# 1280 视口 toast 区左侧空间充足 → 左移到 toast 左缘 - 面板宽 - 8
	assert_vector(out).is_equal(Vector2(tr.position.x - 560.0 - 8.0, pos.y))


func test_no_left_room_falls_below() -> void:
	await _install_fake_toast()
	var cont := _toast_container()
	var tr: Rect2 = cont.get_global_rect()
	# 模拟窄面板占满 toast 左侧空间：面板 x 使其左缘已贴近屏幕左（左移放不下）
	# 直接用超大面板宽触发左移失败分支
	var pos := Vector2(tr.position.x + 50.0, tr.position.y + 20.0)
	var huge_w: float = tr.position.x  # 左移需要 x - huge_w - 8 < 8 → 必然失败
	var out: Vector2 = _panel._avoid_toast_zone(pos, huge_w, 400.0, 720.0)
	assert_vector(out).is_equal(Vector2(pos.x, tr.end.y + 8.0))


func test_disjoint_passthrough() -> void:
	await _install_fake_toast()
	# 面板在左下角，与右上 toast 区不相交 → 原样
	var pos := Vector2(40.0, 500.0)
	var out: Vector2 = _panel._avoid_toast_zone(pos, 300.0, 150.0, 720.0)
	assert_vector(out).is_equal(pos)
