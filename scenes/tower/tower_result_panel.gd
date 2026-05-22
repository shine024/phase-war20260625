extends Control
## 爬塔结束结算面板

const TowerRelics = preload("res://data/tower_relics.gd")

signal run_ended(action: String)  # "restart" or "return_title"

func _ready() -> void:
	visible = false


func show_result(run_data: Dictionary, victory: bool) -> void:
	visible = true

	# 清理旧内容
	for child in get_children():
		child.queue_free()

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(450, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var sb := StyleBoxFlat.new()
	if victory:
		sb.bg_color = Color(0.04, 0.12, 0.10, 0.98)
		sb.border_color = Color(0.0, 0.95, 0.7, 0.9)
		sb.shadow_color = Color(0.0, 0.95, 0.7, 0.3)
	else:
		sb.bg_color = Color(0.12, 0.04, 0.04, 0.98)
		sb.border_color = Color(0.9, 0.2, 0.2, 0.8)
		sb.shadow_color = Color(0.9, 0.2, 0.2, 0.3)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.shadow_size = 8
	panel.add_theme_stylebox_override("panel", sb)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# 标题
	var title := Label.new()
	title.text = "通关！" if victory else "爬塔结束"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if victory:
		title.add_theme_color_override("font_color", Color(0.2, 1.0, 0.7, 1))
	else:
		title.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3, 1))
	vbox.add_child(title)

	# 分隔线
	var sep := HSeparator.new()
	var sep_color := Color(0, 0.9, 0.7, 0.25) if victory else Color(0.9, 0.2, 0.2, 0.25)
	sep.add_theme_color_override("color", sep_color)
	vbox.add_child(sep)

	# 统计数据
	var stats: Dictionary = run_data.get("run_stats", {})
	var stat_lines: Array = [
		"到达层数: %d / %d" % [run_data.get("floor", 0), run_data.get("max_floor", 30)],
		"最终分数: %d" % run_data.get("score", 0),
		"总击杀数: %d" % stats.get("total_kills", 0),
		"通关层数: %d" % stats.get("floors_cleared", 0),
		"Boss 击败: %d" % stats.get("bosses_defeated", 0),
	]
	if victory:
		stat_lines.append("用时: %s" % _format_elapsed(run_data.get("start_time", 0)))

	for line in stat_lines:
		var lbl := Label.new()
		lbl.text = "  ▸ " + line
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0, 0.95))
		vbox.add_child(lbl)

	# 遗物列表
	var relics: Array = run_data.get("relics", []) as Array
	if not relics.is_empty():
		var relic_sep := HSeparator.new()
		relic_sep.add_theme_color_override("color", Color(0.6, 0.5, 1.0, 0.2))
		vbox.add_child(relic_sep)
		var relic_title := Label.new()
		relic_title.text = "◆ 获得遗物"
		relic_title.add_theme_font_size_override("font_size", 13)
		relic_title.add_theme_color_override("font_color", Color(0.6, 0.5, 1.0, 1))
		vbox.add_child(relic_title)

		for relic_id in relics:
			var relic_data: Dictionary = TowerRelics.get_relic(relic_id) if TowerRelics else {}
			var name: String = relic_data.get("name", relic_id)
			var rarity: String = relic_data.get("rarity", "common")
			var color: Color = TowerRelics.get_rarity_color(rarity) if TowerRelics else Color(0.75, 0.8, 0.85)
			var lbl := Label.new()
			lbl.text = "  ▸ %s (%s)" % [name, TowerRelics.get_rarity_display_name(rarity) if TowerRelics else rarity]
			lbl.add_theme_font_size_override("font_size", 12)
			lbl.add_theme_color_override("font_color", color)
			vbox.add_child(lbl)

	# 按钮行
	var btn_sep := HSeparator.new()
	btn_sep.add_theme_color_override("color", sep_color)
	vbox.add_child(btn_sep)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 16)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var restart_btn := Button.new()
	restart_btn.text = "再来一局"
	restart_btn.custom_minimum_size = Vector2(130, 42)
	restart_btn.add_theme_font_size_override("font_size", 14)
	restart_btn.add_theme_color_override("font_color", Color(0.0, 0.94, 1, 1))
	restart_btn.pressed.connect(func():
		visible = false
		run_ended.emit("restart")
	)
	btn_hbox.add_child(restart_btn)

	var title_btn := Button.new()
	title_btn.text = "返回标题"
	title_btn.custom_minimum_size = Vector2(130, 42)
	title_btn.add_theme_font_size_override("font_size", 14)
	title_btn.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85))
	title_btn.pressed.connect(func():
		visible = false
		run_ended.emit("return_title")
	)
	btn_hbox.add_child(title_btn)

	vbox.add_child(btn_hbox)
	add_child(panel)


func _format_elapsed(start_time: float) -> String:
	if start_time <= 0:
		return "?"
	var elapsed := Time.get_unix_time_from_system() - start_time
	var minutes := int(elapsed) / 60
	var seconds := int(elapsed) % 60
	return "%d:%02d" % [minutes, seconds]
