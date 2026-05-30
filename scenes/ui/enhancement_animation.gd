class_name EnhancementAnimation
extends RefCounted
## 强化动画/粒子效果系统（从 card_enhancement_panel.gd 拆分）
## 负责：强化成功/失败动画、粒子效果、属性预览渲染

## 宿主引用（由 card_enhancement_panel 在 _ready 设置）
var _host: Node = null  # CardEnhancementPanel

func setup(host: Node) -> void:
	_host = host

## 强化成功时播放动画反馈
func play_success_animation(card_id: String) -> void:
	if not _host or not is_instance_valid(_host):
		return
	var result_label: Label = _host.result_label if "result_label" in _host else null
	if result_label:
		var t := _host.create_tween() if is_instance_valid(_host) else null
		if t:
			t.tween_property(result_label, "modulate", Color(1.0, 1.0, 0.3, 1.0), 0.1)
			t.tween_property(result_label, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.4)

## 强化失败时播放动画反馈
func play_failure_animation() -> void:
	if not _host or not is_instance_valid(_host):
		return
	var result_label: Label = _host.result_label if "result_label" in _host else null
	if result_label:
		var t := _host.create_tween() if is_instance_valid(_host) else null
		if t:
			t.tween_property(result_label, "modulate", Color(1.0, 0.3, 0.3, 1.0), 0.1)
			t.tween_property(result_label, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.4)

## 在父控件中添加属性预览区域（强化前后对比）
func add_attribute_preview(parent: Control, card_data: Variant, current_level: int, next_level: int) -> void:
	if not card_data:
		return

	var sep = VSeparator.new()
	sep.custom_minimum_size = Vector2(2, 0)
	parent.add_child(sep)

	var preview_label = Label.new()
	preview_label.text = "━━━ 属性预览 ━━━"
	preview_label.add_theme_font_size_override("font_size", 12)
	preview_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0, 1.0))
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(preview_label)

	var current_stats: Dictionary = get_card_attributes(card_data, current_level)
	var next_stats: Dictionary = get_card_attributes(card_data, next_level)
	for key in current_stats.keys():
		var current_val = current_stats[key]
		var next_val = next_stats[key]
		var increase: int = next_val - current_val

		var stat_row = HBoxContainer.new()
		stat_row.add_theme_constant_override("separation", 8)

		var key_label = Label.new()
		key_label.text = key + "："
		key_label.custom_minimum_size = Vector2(60, 0)
		key_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85, 1.0))
		stat_row.add_child(key_label)

		var current_label = Label.new()
		current_label.text = str(current_val)
		current_label.custom_minimum_size = Vector2(40, 0)
		stat_row.add_child(current_label)

		var arrow_label = Label.new()
		arrow_label.text = "→"
		arrow_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4, 1.0))
		stat_row.add_child(arrow_label)

		var next_label = Label.new()
		next_label.text = str(next_val)
		next_label.custom_minimum_size = Vector2(40, 0)
		next_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4, 1.0))
		stat_row.add_child(next_label)

		var increase_label = Label.new()
		increase_label.text = "(+%d)" % increase if increase > 0 else "(=)"
		increase_label.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0, 1.0))
		stat_row.add_child(increase_label)

		parent.add_child(stat_row)

## 根据卡牌数据和等级计算属性
func get_card_attributes(card_data: Variant, level: int) -> Dictionary:
	var stats := {}
	var GC = load("res://resources/game_constants.gd")

	if card_data is Dictionary:
		var energy_cost = card_data.get("energy_cost", 0)
		var card_type = card_data.get("card_type", 0)
		stats["能量消耗"] = energy_cost
		if card_type == GC.CardType.COMBAT_UNIT if GC else 0:
			var max_hp = card_data.get("max_hp", 100)
			var move_speed = card_data.get("move_speed", 100)
			stats["生命值"] = int(max_hp * (1.0 + (level - 1) * 0.1))
			stats["移速"] = int(move_speed * (1.0 + (level - 1) * 0.05))
	elif card_data is Object:
		stats["能量消耗"] = int(card_data.get("energy_cost", 0))
		if card_data.card_type == GC.CardType.COMBAT_UNIT if GC else 0:
			stats["生命值"] = int(card_data.max_hp * (1.0 + (level - 1) * 0.1))
			stats["移速"] = int(card_data.move_speed * (1.0 + (level - 1) * 0.05))

	return stats
