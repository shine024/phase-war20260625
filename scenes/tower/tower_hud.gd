extends Control
## 爬塔 HUD：显示层数/HP/金币/分数/遗物

const TowerRelics = preload("res://data/tower_relics.gd")

@onready var floor_label: Label = $HBox/FloorLabel
@onready var hp_label: Label = $HBox/HPLabel
@onready var hp_bar: ProgressBar = $HBox/HPBar
@onready var gold_label: Label = $HBox/GoldLabel
@onready var score_label: Label = $HBox/ScoreLabel
@onready var relic_container: HBoxContainer = $RelicRow


func update_display(floor_num: int, hp: int, max_hp: int, gold: int, score: int, relics: Array, is_active: bool) -> void:
	if not is_active:
		visible = false
		return
	visible = true

	if floor_label:
		floor_label.text = "第 %d/%d 层" % [floor_num, 30]
	if hp_label:
		hp_label.text = "%d/%d" % [hp, max_hp]
	if hp_bar:
		hp_bar.max_value = max(max_hp, 1)
		hp_bar.value = hp
		# 根据生命比例变色
		var ratio := float(hp) / float(max(max_hp, 1))
		if ratio > 0.6:
			hp_bar.modulate = Color(0.3, 1.0, 0.5)
		elif ratio > 0.3:
			hp_bar.modulate = Color(1.0, 0.85, 0.2)
		else:
			hp_bar.modulate = Color(1.0, 0.3, 0.3)
	if gold_label:
		gold_label.text = "%d" % gold
	if score_label:
		score_label.text = "%d" % score

	# 更新遗物图标
	if relic_container:
		for child in relic_container.get_children():
			child.queue_free()
		for relic_id in relics:
			var relic_data: Dictionary = TowerRelics.get_relic(relic_id) if TowerRelics else {}
			var icon := _create_relic_icon(relic_data)
			if icon:
				relic_container.add_child(icon)


func _create_relic_icon(relic_data: Dictionary) -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(28, 28)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED

	# 用颜色块代替图标
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(28, 28)
	var sb := StyleBoxFlat.new()
	var color: Color = relic_data.get("icon_color", Color(0.7, 0.7, 0.8))
	sb.bg_color = color
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(1)
	sb.border_color = color.lightened(0.3)
	panel.add_theme_stylebox_override("panel", sb)

	# 悬停提示
	var name_text: String = relic_data.get("name", "")
	var desc_text: String = relic_data.get("description", "")
	if not name_text.is_empty():
		panel.tooltip_text = "%s\n%s" % [name_text, desc_text]

	return panel
