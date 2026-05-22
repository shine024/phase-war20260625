extends Control
## 爬塔层间奖励面板：三选一

signal reward_chosen(reward: Dictionary)
signal reward_skipped()

const TowerClimbManagerScript = preload("res://managers/tower_climb_manager.gd")
const TowerRelics = preload("res://data/tower_relics.gd")

var _choices: Array = []

func _ready() -> void:
	visible = false


func show_rewards(choices: Array, floor_num: int) -> void:
	_choices = choices
	visible = true

	# 清理旧内容
	for child in get_children():
		child.queue_free()

	# 外层居中容器
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# 面板容器
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(650, 0)
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
	center.add_child(panel)

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
	title.text = "层间奖励 — 第 %d 层" % floor_num
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.0, 0.94, 1, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# 分隔线
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0, 0.9, 1, 0.2))
	vbox.add_child(sep)

	# 三个奖励卡片
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	for i in range(mini(choices.size(), 3)):
		var card := _create_reward_card(choices[i] as Dictionary, i)
		hbox.add_child(card)

	# 跳过按钮
	var skip_btn := Button.new()
	skip_btn.text = "跳过奖励"
	skip_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	skip_btn.custom_minimum_size = Vector2(120, 38)
	skip_btn.add_theme_font_size_override("font_size", 14)
	skip_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	skip_btn.pressed.connect(func():
		visible = false
		reward_skipped.emit()
	)
	vbox.add_child(skip_btn)


func _create_reward_card(reward: Dictionary, index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(180, 220)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.15, 0.95)
	sb.set_border_width_all(2)

	# 根据奖励类型设置颜色
	var reward_type: int = reward.get("type", -1)
	var border_color := Color(0, 0.9, 0.7, 0.7)
	match reward_type:
		TowerClimbManagerScript.RewardType.RELIC:
			var rarity: String = reward.get("rarity", "common")
			if TowerRelics:
				border_color = TowerRelics.get_rarity_color(rarity)
		TowerClimbManagerScript.RewardType.HEAL, TowerClimbManagerScript.RewardType.MAX_HP_UP:
			border_color = Color(0.3, 1.0, 0.5, 0.8)
		TowerClimbManagerScript.RewardType.GOLD_BONUS:
			border_color = Color(1.0, 0.85, 0.2, 0.8)
		TowerClimbManagerScript.RewardType.NEW_LAW:
			border_color = Color(0.6, 0.4, 1.0, 0.8)

	sb.border_color = border_color
	sb.set_corner_radius_all(8)
	sb.shadow_color = border_color * Color(1, 1, 1, 0.2)
	sb.shadow_size = 4
	panel.add_theme_stylebox_override("panel", sb)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	# 奖励类型图标
	var type_label := Label.new()
	type_label.text = _get_reward_type_icon(reward_type)
	type_label.add_theme_font_size_override("font_size", 28)
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(type_label)

	# 奖励名称
	var name_label := Label.new()
	name_label.text = reward.get("name", "???")
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", border_color)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(name_label)

	# 奖励描述
	var desc_label := Label.new()
	desc_label.text = reward.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_label)

	# 选择按钮
	var select_btn := Button.new()
	select_btn.text = "选择"
	select_btn.custom_minimum_size = Vector2(120, 36)
	select_btn.add_theme_font_size_override("font_size", 14)
	select_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	select_btn.pressed.connect(func():
		visible = false
		reward_chosen.emit(reward)
	)
	vbox.add_child(select_btn)

	return panel


func _get_reward_type_icon(type: int) -> String:
	match type:
		TowerClimbManagerScript.RewardType.NEW_CARD: return "🃏"
		TowerClimbManagerScript.RewardType.UPGRADE_CARD: return "⬆"
		TowerClimbManagerScript.RewardType.NEW_LAW: return "📜"
		TowerClimbManagerScript.RewardType.RELIC: return "💎"
		TowerClimbManagerScript.RewardType.HEAL: return "❤"
		TowerClimbManagerScript.RewardType.MAX_HP_UP: return "🛡"
		TowerClimbManagerScript.RewardType.GOLD_BONUS: return "💰"
		TowerClimbManagerScript.RewardType.REMOVE_CARD: return "🗑"
		_: return "?"
