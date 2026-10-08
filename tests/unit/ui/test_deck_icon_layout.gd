class_name DeckIconLayoutTest
extends GdUnitTestSuite
## 回归锁：改造舱操作台 DeckIcon 不得被垂直拉伸（2026-10-07 用户实机反馈
## "图标应该是在改造名前的小方块，不应该拉长"）。
## 根因：tscn 里 DeckIcon size_flags_vertical=3（EXPAND+FILL），DeckHBox 高度=
## 标题+最多 6 行效果+要求行 → 36×36 稀有度底座被拉成窄长条压满整个信息块。
## 契约：
## - DeckIcon 顶对齐（与 DeckNameLabel 同一顶缘），保持 36×36 最小尺寸
## - size_flags_vertical 不得含 EXPAND（防 tscn/代码复活）
## - 贴图拉伸模式必须保比例居中（KEEP_ASPECT_CENTERED，方块底座内不变形）

const ModPanelScene := preload("res://scenes/ui/modification_panel.tscn")
const MOD_ID := "rec_13_target_designator"


func _make_panel() -> Node:
	var panel: Node = ModPanelScene.instantiate()
	add_child(panel)
	return panel


func test_deck_icon_square_and_top_aligned() -> void:
	var panel := _make_panel()
	var reg: Node = get_node_or_null("/root/ModificationRegistry")
	if reg == null:
		print("  ModificationRegistry 不可达，跳过")
		panel.queue_free()
		return
	var mod_data: Dictionary = reg.get_data(MOD_ID)
	if mod_data.is_empty():
		print("  测试模块数据缺失，跳过")
		panel.queue_free()
		return
	panel.call("_on_mod_selected", MOD_ID, mod_data)
	# 布局落定等两帧（PanelContainer 强制布局在下一帧生效）
	await get_tree().process_frame
	await get_tree().process_frame

	var icon: Control = panel.get_node("%DeckIcon") as Control
	var name_lbl: Label = panel.get_node("%DeckNameLabel") as Label
	assert_object(icon).is_not_null()
	assert_object(name_lbl).is_not_null()

	# ① 防复活：垂直方向不得 EXPAND（3 = FILL|EXPAND）
	assert_int(icon.size_flags_vertical).is_equal(0)
	# ② 不拉长：保持 36×36 最小尺寸（修前实测被拉到 ~104 高）
	assert_float(icon.size.y).is_equal_approx(icon.custom_minimum_size.y, 0.5)
	assert_float(icon.size.x).is_equal_approx(icon.custom_minimum_size.x, 0.5)
	# ③ 顶对齐：图标顶缘与改造名顶缘同线（±2px）
	assert_float(absf(icon.global_position.y - name_lbl.global_position.y)).is_less_equal(2.0)
	# ④ 贴图保比例（若走了真图标分支）
	var tex: TextureRect = icon.get_node_or_null("DeckIconTex") as TextureRect
	if tex != null and tex.visible:
		assert_int(tex.stretch_mode).is_equal(TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	panel.queue_free()
