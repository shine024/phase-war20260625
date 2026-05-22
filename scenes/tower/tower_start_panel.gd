extends Control
## 爬塔起始套件选择面板

const TowerDefinitions = preload("res://data/tower_definitions.gd")

signal starter_selected(loadout_id: String)

func _ready() -> void:
	visible = false


func refresh() -> void:
	visible = true
	# 清理旧内容
	for child in get_children():
		child.queue_free()

	# 加载套件定义数据
	if not TowerDefinitions:
		return

	var tower_mgr = get_node_or_null("/root/TowerClimbManager")
	var unlocked_starters: Array = []
	if tower_mgr:
		unlocked_starters = tower_mgr.meta_progress.get("unlocked_starters", ["default", "scout", "heavy"])

	# 面板容器 — 宽度自适应窗口
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	var screen_w := float(ProjectSettings.get_setting("display/window/size/viewport_width"))
	if screen_w <= 0:
		screen_w = float(DisplayServer.window_get_size().x)
	var panel_w := clampf(screen_w * 0.75, 320.0, 700.0)
	panel.custom_minimum_size = Vector2(panel_w, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.12, 0.98)
	sb.border_color = Color(0.0, 0.9, 1, 0.7)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.shadow_color = Color(0.0, 0.9, 1, 0.2)
	sb.shadow_size = 8
	panel.add_theme_stylebox_override("panel", sb)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	# 标题
	var title := Label.new()
	title.text = "选择起始相位仪"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.0, 0.94, 1, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "每次爬塔从零开始，选择适合你的起始配置。"
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(desc)

	# 分隔线
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0, 0.9, 1, 0.2))
	vbox.add_child(sep)

	# 套件选项
	var loadouts: Dictionary = TowerDefinitions.STARTING_LOADOUTS
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	for loadout_id in loadouts:
		var loadout: Dictionary = loadouts[loadout_id]
		var is_unlocked: bool = unlocked_starters.has(loadout_id)

		var card := _create_loadout_card(loadout, is_unlocked, screen_w)
		hbox.add_child(card)

	vbox.add_child(hbox)

	# 返回按钮
	var back_btn := Button.new()
	back_btn.text = "返回"
	back_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	back_btn.custom_minimum_size = Vector2(120, 38)
	back_btn.add_theme_font_size_override("font_size", 14)
	back_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	back_btn.pressed.connect(func():
		visible = false
		get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
	)
	vbox.add_child(back_btn)

	add_child(panel)


func _create_loadout_card(loadout: Dictionary, is_unlocked: bool, screen_w: float) -> PanelContainer:
	var panel := PanelContainer.new()
	var card_w := clampf(screen_w * 0.18, 120.0, 180.0)
	var card_h := clampf(screen_w * 0.25, 160.0, 220.0)
	panel.custom_minimum_size = Vector2(card_w, card_h)

	var sb := StyleBoxFlat.new()
	if is_unlocked:
		sb.bg_color = Color(0.06, 0.10, 0.18, 0.95)
		sb.border_color = Color(0.0, 0.8, 0.9, 0.7)
	else:
		sb.bg_color = Color(0.08, 0.08, 0.10, 0.8)
		sb.border_color = Color(0.3, 0.3, 0.4, 0.5)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", sb)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	# 套件名称
	var name_label := Label.new()
	name_label.text = loadout.get("name", "???")
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if is_unlocked:
		name_label.add_theme_color_override("font_color", Color(0.0, 0.94, 1, 1))
	else:
		name_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
	vbox.add_child(name_label)

	# 描述
	var desc_label := Label.new()
	desc_label.text = loadout.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_label)

	# 属性
	var hp_text := "❤ %d" % loadout.get("starting_hp", 100)
	var energy_text := "⚡ %+d" % loadout.get("energy_bonus", 0)
	var stat_label := Label.new()
	stat_label.text = "%s  %s" % [hp_text, energy_text]
	stat_label.add_theme_font_size_override("font_size", 11)
	stat_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.85))
	stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stat_label)

	# 选择按钮
	if is_unlocked:
		var btn := Button.new()
		btn.text = "选择"
		btn.custom_minimum_size = Vector2(100, 34)
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_color_override("font_color", Color(1, 1, 1))
		var captured_id: String = loadout.get("id", "")
		btn.pressed.connect(func():
			visible = false
			starter_selected.emit(captured_id)
		)
		vbox.add_child(btn)
	else:
		var lock_label := Label.new()
		lock_label.text = "🔒 未解锁"
		lock_label.add_theme_font_size_override("font_size", 12)
		lock_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
		lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(lock_label)

	return panel
