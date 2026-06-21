extends PanelContainer
class_name IntelHarvestDisplay
## v6.0: 战斗结算中的情报收获展示组件
## 显示每个被击败敌人的4维情报进度条 + 增长动画 + 揭示事件预览
##
## 使用方式：
##   var ui = IntelHarvestDisplay.new()
##   ui.set_data(harvest_data)
##   parent.add_child(ui)

const IntelDimensions = preload("res://data/intel_dimensions.gd")

var _card_entries: Array[Dictionary] = []
var _reveal_events: Array[Dictionary] = []
var _intel_item_drops: Array = []
var _im: Node = null  ## IntelManual引用

func _ready() -> void:
	_im = get_node_or_null("/root/IntelManual")
	_build_initial_ui()

func _build_initial_ui() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.14, 0.95)
	style.border_color = Color(0.25, 0.45, 0.75, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)

## 设置情报收获数据（由战斗结算调用）
## data格式: {"harvests": [...], "reveal_events": [...], "eom_drops": [...], "intel_item_drops": [...]}
func set_data(data: Dictionary) -> void:
	_card_entries.clear()
	for d in data.get("harvests", []):
		_card_entries.append(d)
	_reveal_events.clear()
	for d in data.get("reveal_events", []):
		_reveal_events.append(d)
	_intel_item_drops.clear()
	for d in data.get("intel_item_drops", []):
		_intel_item_drops.append(d)
	_refresh_ui()

func _refresh_ui() -> void:
	## 清除旧内容
	for child in get_children():
		if child.name != "_style_placeholder":
			child.queue_free()

	if _card_entries.is_empty() and _reveal_events.is_empty() and _intel_item_drops.is_empty():
		return

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	outer.name = "HarvestContent"

	## 标题
	var title := Label.new()
	title.text = "📊 情报收获"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0, 1.0))
	outer.add_child(title)

	## 按敌人分组显示
	for entry in _card_entries:
		if not entry is Dictionary:
			continue
		var card_box := _create_card_entry(entry)
		outer.add_child(card_box)

	## 敌源MOD碎片掉落预览
	## TODO: Phase 2整合

	## 情报道具掉落展示
	if not _intel_item_drops.is_empty():
		var item_title := Label.new()
		item_title.text = "📋 情报道具"
		item_title.add_theme_font_size_override("font_size", 13)
		item_title.add_theme_color_override("font_color", Color(0.75, 0.55, 0.95, 1.0))
		outer.add_child(item_title)
		for item in _intel_item_drops:
			if not item is Dictionary:
				continue
			var item_lbl := Label.new()
			var item_name: String = item.get("name", "未知道具")
			var item_desc: String = item.get("desc", "")
			item_lbl.text = "  ▸ %s — %s" % [item_name, item_desc]
			item_lbl.add_theme_font_size_override("font_size", 12)
			item_lbl.add_theme_color_override("font_color", Color(0.8, 0.65, 1.0, 1))
			outer.add_child(item_lbl)

	add_child(outer)

## 创建单个敌人的情报条目
func _create_card_entry(entry: Dictionary) -> PanelContainer:
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.18, 0.9)
	style.set_border_width_all(1)
	style.set_border_color(Color(0.2, 0.35, 0.55, 0.3))
	style.set_corner_radius_all(6)
	style.set_content_margin_all(6)
	box.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	box.add_child(vbox)

	## 敌人名称行
	var card_id: String = entry.get("card_id", "")
	var enemy_type: String = entry.get("enemy_type", "")
	var is_first: bool = entry.get("first_encounter", false)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)

	var icon_lbl := Label.new()
	icon_lbl.text = "🔵" if is_first else "⚔️"
	icon_lbl.add_theme_font_size_override("font_size", 12)
	name_row.add_child(icon_lbl)

	var name_lbl := Label.new()
	name_lbl.text = _get_enemy_display_name(card_id, enemy_type)
	if is_first:
		name_lbl.text += "  [首次遭遇]"
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95, 1.0))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_lbl)

	vbox.add_child(name_row)

	## 4维进度条
	var dims: Dictionary = entry.get("dimensions", {})
	for dim in IntelDimensions.ALL_DIMENSIONS:
		var delta: float = 0.0
		if dims.has(dim):
			# v6.6 修复：_merge_harvests 把维度存成 {"old_val":..,"new_val":..,"delta":..} 字典，
			# 而非直接 float。原 float(dims[dim]) 对 Dictionary 调用 float 触发
			# "Nonexistent 'float' constructor" 运行时错误（每次战斗结算必现）。
			# 兼容两种结构：Dictionary（合并后）取 "delta"，或直接数值（未合并）。
			var dim_val: Variant = dims[dim]
			if dim_val is Dictionary:
				delta = float(dim_val.get("delta", 0.0))
			elif dim_val is float or dim_val is int:
				delta = float(dim_val)

		if delta < 0.001:
			continue  ## 跳过无增长的维度

		var dim_row := _create_dimension_bar(card_id, enemy_type, dim, delta)
		vbox.add_child(dim_row)

	return box

## 创建单个维度的进度条行
func _create_dimension_bar(card_id: String, enemy_type: String, dimension: String, delta: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	## 维度图标
	var icon_lbl := Label.new()
	icon_lbl.text = IntelDimensions.get_dim_icon(dimension)
	icon_lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(icon_lbl)

	## 维度名称
	var dim_lbl := Label.new()
	dim_lbl.text = IntelDimensions.get_dim_name(dimension)
	dim_lbl.add_theme_font_size_override("font_size", 10)
	dim_lbl.custom_minimum_size.x = 56
	dim_lbl.add_theme_color_override("font_color", IntelDimensions.get_dim_color(dimension))
	row.add_child(dim_lbl)

	## 进度条
	var progress := ProgressBar.new()
	progress.custom_minimum_size.x = 120
	progress.max_value = 100.0
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	## 获取当前情报值
	var current_pct: float = 0.0
	var new_pct: float = 0.0
	if _im and _im.has_method("get_dimension_progress"):
		current_pct = _im.get_dimension_progress(card_id, dimension) * 100.0
	new_pct = current_pct  ## delta已经被添加过了

	progress.value = new_pct

	## 进度条颜色
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = IntelDimensions.get_dim_color(dimension)
	bar_style.set_corner_radius_all(3)
	progress.add_theme_stylebox_override("fill", bar_style)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = IntelDimensions.DIM_BG_COLORS.get(dimension, Color(0.1, 0.1, 0.1))
	bg_style.set_corner_radius_all(3)
	progress.add_theme_stylebox_override("background", bg_style)

	row.add_child(progress)

	## 百分比文本
	var pct_lbl := Label.new()
	pct_lbl.text = "%.0f%%" % new_pct
	pct_lbl.add_theme_font_size_override("font_size", 10)
	pct_lbl.custom_minimum_size.x = 32
	pct_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9, 1.0))
	row.add_child(pct_lbl)

	## 增长量（绿色）
	var delta_lbl := Label.new()
	delta_lbl.text = "+%.0f%%" % (delta * 100.0)
	delta_lbl.add_theme_font_size_override("font_size", 10)
	delta_lbl.custom_minimum_size.x = 32
	delta_lbl.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5, 1.0))
	row.add_child(delta_lbl)

	## 揭示检查：按 card_id + dimension 精确匹配
	var found_reveal: Dictionary = {}
	for rev in _reveal_events:
		var rev_card: String = rev.get("card_id", "")
		var rev_dim: String = rev.get("dimension", "")
		if rev_card == card_id and rev_dim == dimension:
			found_reveal = rev
			break
	if not found_reveal.is_empty():
		var rev_icon := Label.new()
		rev_icon.text = " ✦新揭示!"
		rev_icon.add_theme_font_size_override("font_size", 10)
		rev_icon.add_theme_color_override("font_color", Color(0.95, 0.75, 0.3, 1.0))
		row.add_child(rev_icon)

	return row

## 获取敌人显示名称
func _get_enemy_display_name(card_id: String, enemy_type: String) -> String:
	## 优先从EnemyArchetypes获取名称
	if not card_id.is_empty():
		var config: Dictionary = EnemyArchetypes.get_config(card_id)
		if not config.is_empty():
			return config.get("display_name", "")
	## 尝试DefaultCards.get_safe_display_name（依次查DefaultCards→EnemyArchetypes）
	if not card_id.is_empty():
		var safe: String = _get_default_cards().get_safe_display_name(card_id)
		if not safe.is_empty() and safe != card_id:
			return safe
	## 兜底
	match enemy_type:
		"infantry": return "步兵部队"
		"flame": return "火焰兵"
		"heavy_armor": return "重装甲"
		"artillery": return "火炮单位"
		"stealth": return "隐匿单位"
		"air": return "空中单位"
		"boss_nano": return "纳米核心"
		"boss_phase": return "相位师"
		_: return card_id if not card_id.is_empty() else "未知敌人"

## 获取DefaultCards脚本引用
func _get_default_cards() -> GDScript:
	return preload("res://data/default_cards.gd")
