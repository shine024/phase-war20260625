extends Control
## 爬塔层间事件面板

signal event_choice_made(effect: Dictionary)

func _ready() -> void:
	visible = false


func show_event(event: Dictionary, current_gold: int) -> void:
	visible = true

	# 清理旧内容
	for child in get_children():
		child.queue_free()

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(500, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.08, 0.14, 0.98)
	sb.border_color = Color(0.6, 0.4, 1.0, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(0.6, 0.4, 1.0, 0.2)
	sb.shadow_size = 6
	panel.add_theme_stylebox_override("panel", sb)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	# 事件图标 + 标题
	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 10)
	var icon_label := Label.new()
	icon_label.text = _get_event_icon(event.get("icon", ""))
	icon_label.add_theme_font_size_override("font_size", 28)
	header.add_child(icon_label)
	var title_label := Label.new()
	title_label.text = event.get("name", "未知事件")
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(0.7, 0.5, 1.0, 1))
	header.add_child(title_label)
	vbox.add_child(header)

	# 事件描述
	var desc_label := Label.new()
	desc_label.text = event.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", Color(0.75, 0.8, 0.88))
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(desc_label)

	# 分隔线
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.6, 0.4, 1.0, 0.25))
	vbox.add_child(sep)

	# 选项按钮
	var choices: Array = event.get("choices", [])
	for choice in choices:
		var choice_dict: Dictionary = choice as Dictionary
		var text: String = choice_dict.get("text", "")
		var cost: Dictionary = choice_dict.get("cost", {})
		var effect: Dictionary = choice_dict.get("effect", {})

		# 显示费用
		if not cost.is_empty():
			var cost_parts: Array = []
			if cost.has("gold"):
				cost_parts.append("💰 %d" % cost["gold"])
			if cost.has("hp"):
				cost_parts.append("❤ %d" % cost["hp"])
			# 金币不足时显示红色
			var can_afford := true
			if cost.has("gold") and current_gold < int(cost["gold"]):
				can_afford = false
			text += "  [%s]" % ", ".join(cost_parts)
			if not can_afford:
				text += " (不足)"

		var btn := Button.new()
		btn.text = text
		btn.custom_minimum_size = Vector2(0, 42)
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0, 1))

		# 费用不足时禁用
		if cost.has("gold") and current_gold < int(cost["gold"]):
			btn.disabled = true
			btn.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))

		var captured_effect := effect.duplicate(true)
		var captured_cost := cost.duplicate(true)
		btn.pressed.connect(func():
			visible = false
			var merged := {"effect": captured_effect}
			merged.merge(captured_cost)
			# 重命名键以兼容
			if merged.has("gold"):
				merged["cost_gold"] = merged["gold"]
				merged.erase("gold")
			if merged.has("hp"):
				merged["cost_hp"] = merged["hp"]
				merged.erase("hp")
			event_choice_made.emit(merged)
		)
		vbox.add_child(btn)

	add_child(panel)


func _get_event_icon(icon_name: String) -> String:
	match icon_name:
		"merchant": return "🏪"
		"altar": return "⛩"
		"oracle": return "🔮"
		"blacksmith": return "⚒"
		"calamity": return "💀"
		"treasure": return "📦"
		"training": return "🎯"
		"portal": return "🔄"
		_: return "❓"
