extends Control
## 卡牌词条悬停提示 - 显示卡牌的词条信息

const GC = preload("res://resources/game_constants.gd")
const AffixDefs = preload("res://data/affix_definitions.gd")
const DefaultCards = preload("res://data/default_cards.gd")

var _card: CardResource = null
var _tooltip_panel: PanelContainer = null
var _content_vbox: VBoxContainer = null
var _affix_manager: Node = null
var _cached_card_id: String = ""

func _ready() -> void:
	visible = false
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## 显示卡牌的词条提示
func show_for_card(card: CardResource, global_pos: Vector2) -> void:
	if card == null:
		hide_tooltip()
		return
	
	_card = card
	_ensure_tooltip_ui()
	_refresh_content()
	
	if _tooltip_panel == null:
		return
	
	# 计算位置（避免超出屏幕）
	var viewport_size: Vector2 = get_viewport_rect().size
	var tooltip_size: Vector2 = _tooltip_panel.get_combined_minimum_size()
	
	var pos: Vector2 = global_pos + Vector2(10, 10)
	if pos.x + tooltip_size.x > viewport_size.x:
		pos.x = global_pos.x - tooltip_size.x - 10
	if pos.y + tooltip_size.y > viewport_size.y:
		pos.y = viewport_size.y - tooltip_size.y - 10
	
	_tooltip_panel.global_position = pos
	visible = true

## 隐藏提示
func hide_tooltip() -> void:
	visible = false
	_card = null
	_cached_card_id = ""

## 确保UI结构存在
func _ensure_tooltip_ui() -> void:
	if _tooltip_panel != null:
		return
	
	# 主面板
	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.name = "TooltipPanel"
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.08, 0.12, 0.98)
	panel_style.border_color = Color(0.60, 0.35, 1.0, 0.8)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	panel_style.shadow_size = 4
	_tooltip_panel.add_theme_stylebox_override("panel", panel_style)
	
	add_child(_tooltip_panel)
	
	# 边距容器
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	_tooltip_panel.add_child(margin)
	
	# 内容容器
	_content_vbox = VBoxContainer.new()
	_content_vbox.name = "ContentVBox"
	_content_vbox.add_theme_constant_override("separation", 6)
	margin.add_child(_content_vbox)

## 刷新内容
func _refresh_content() -> void:
	if _affix_manager == null or not is_instance_valid(_affix_manager):
		ManagerLazyLoader.ensure_loaded("affix")
		_affix_manager = get_node_or_null("/root/AffixManager")
	if _content_vbox == null or _card == null or _affix_manager == null:
		return
	if _cached_card_id == _card.card_id and _content_vbox.get_child_count() > 0:
		return
	
	# 清除旧内容
	for child in _content_vbox.get_children():
		child.queue_free()
	
	# 获取词条（合并机体_0 + 武器_1 两套）
	var all_affixes: Array = []
	for at in [0, 1]:
		var key := "%s_%d" % [_card.card_id, at]
		var sub: Array = _affix_manager.get_card_affixes(key)
		all_affixes.append_array(sub)
	var affixes: Array = all_affixes
	_cached_card_id = _card.card_id
	
	# 卡牌名称标题
	var title_hbox := HBoxContainer.new()
	title_hbox.add_theme_constant_override("separation", 6)
	_content_vbox.add_child(title_hbox)
	
	# 类型色块
	var type_color := _get_card_type_color(_card.card_type)
	var type_dot := Label.new()
	type_dot.text = "■"
	type_dot.add_theme_color_override("font_color", type_color)
	type_dot.add_theme_font_size_override("font_size", 10)
	title_hbox.add_child(type_dot)
	
	# 卡牌名
	var name_label := Label.new()
	name_label.text = _card.display_name if not _card.display_name.is_empty() else DefaultCards.get_safe_display_name(_card.card_id)
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(0.0, 0.94, 1.0, 1.0))
	title_hbox.add_child(name_label)
	
	# 分割线
	if affixes.size() > 0:
		var sep := HSeparator.new()
		sep.add_theme_color_override("color", Color(0.60, 0.35, 1.0, 0.4))
		_content_vbox.add_child(sep)
	
	# 词条列表
	if affixes.is_empty():
		var empty_label := Label.new()
		empty_label.text = "暂无词条"
		empty_label.add_theme_font_size_override("font_size", 11)
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55, 0.8))
		_content_vbox.add_child(empty_label)
	else:
		var affix_title := Label.new()
		affix_title.text = "✦ 词条加成 (%d/%d)" % [int(affixes.size()), AffixDefs.MAX_AFFIX_SLOTS]
		affix_title.add_theme_font_size_override("font_size", 11)
		affix_title.add_theme_color_override("font_color", Color(0.80, 0.50, 1.0, 1.0))
		_content_vbox.add_child(affix_title)
		
		for affix in affixes:
			_add_affix_row(affix as AffixResource)

## 添加单个词条行
func _add_affix_row(affix: AffixResource) -> void:
	if affix == null:
		return
	
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_content_vbox.add_child(row)
	
	# 稀有度标识
	var rarity_icon := Label.new()
	match affix.rarity:
		"common":    rarity_icon.text = "◇"
		"rare":      rarity_icon.text = "◆"
		"epic":      rarity_icon.text = "★"
		"legendary": rarity_icon.text = "✦"
		_:           rarity_icon.text = "·"
	rarity_icon.add_theme_font_size_override("font_size", 12)
	rarity_icon.add_theme_color_override("font_color", GC.get_rarity_color(affix.rarity))
	rarity_icon.custom_minimum_size = Vector2(16, 0)
	row.add_child(rarity_icon)
	
	# 词条信息容器
	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 2)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info_vbox)
	
	# 词条名称和等级
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 4)
	info_vbox.add_child(name_row)
	
	var name_label := Label.new()
	name_label.text = affix.affix_name
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95, 1.0))
	name_row.add_child(name_label)
	
	var lv_label := Label.new()
	lv_label.text = "Lv.%d" % affix.level
	lv_label.add_theme_font_size_override("font_size", 10)
	lv_label.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0, 0.9))
	name_row.add_child(lv_label)
	
	# 变异标识
	if affix.is_mutated:
		var mut_label := Label.new()
		mut_label.text = "[变]"
		mut_label.add_theme_font_size_override("font_size", 10)
		mut_label.add_theme_color_override("font_color", Color(1.0, 0.80, 0.1, 1.0))
		name_row.add_child(mut_label)
	
	# 词条效果
	var effect_label := Label.new()
	effect_label.text = affix.get_detailed_description().split("\n")[0]  # 只取第一行
	effect_label.add_theme_font_size_override("font_size", 10)
	effect_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.82, 0.9))
	info_vbox.add_child(effect_label)
	
	# 变异描述
	if affix.is_mutated and not affix.mutation_description.is_empty():
		var mut_desc := Label.new()
		mut_desc.text = "  ↳ %s" % affix.mutation_description
		mut_desc.add_theme_font_size_override("font_size", 9)
		mut_desc.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 0.85))
		info_vbox.add_child(mut_desc)

## 获取卡牌类型颜色
func _get_card_type_color(card_type: int) -> Color:
	match card_type:
		GC.CardType.COMBAT_UNIT: return Color(0.1, 0.5, 0.9, 1.0)
		GC.CardType.COMBAT_UNIT:   return Color(0.85, 0.45, 0.1, 1.0)
		GC.CardType.COMBAT_UNIT: return Color(0.55, 0.25, 0.9, 1.0)
		GC.CardType.ENERGY:   return Color(0.15, 0.75, 0.35, 1.0)
		GC.CardType.LAW:      return Color(0.95, 0.90, 0.60, 1.0)  # 金白 — 法则权威
		_:                    return Color(0.5, 0.5, 0.5, 1.0)