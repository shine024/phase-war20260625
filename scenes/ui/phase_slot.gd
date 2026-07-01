class_name PhaseSlot
extends PanelContainer

const GameConstants = preload("res://resources/game_constants.gd")
const UiAssetLoader = preload("res://scripts/ui_asset_loader.gd")
const CardFrameUi = preload("res://scripts/card_frame_ui.gd")
const CardBackgroundUi = preload("res://scripts/card_background_ui.gd")
const DefaultCards = preload("res://data/default_cards.gd")

## 竖向格：窄宽高长，与背包卡、相位仪条视觉一致
const SLOT_SIZE: Vector2 = Vector2(50, 80)
const COMPACT_BOTTOM_TEXT_H := 30

var slot_index: int = 0
var current_card = null
var used_weight: int = 0
var weight_capacity: int = 0
var _is_weight_capped: bool = false
var _tween = null
## v7.x: 待绘制的费用文字（_draw 里画），空字符串不画
var _cost_draw_text: String = ""

signal slot_clicked(slot_index: int, mouse_button_index: int)
signal slot_drop_requested(slot_index, card)

func _ready() -> void:
	custom_minimum_size = SLOT_SIZE
	size_flags_horizontal = 0
	size_flags_vertical = 0
	clip_contents = false
	CardBackgroundUi.ensure_overlay(self)
	CardFrameUi.ensure_overlay(self)
	refresh_display()

func set_card(card) -> void:
	current_card = card
	refresh_display()

func get_card():
	return current_card

func refresh_display() -> void:
	var icon: TextureRect = get_node_or_null("MarginContainer/VBox/Icon") as TextureRect
	var name_label: Label = get_node_or_null("MarginContainer/VBox/NameLabel") as Label
	var cost_label: Label = get_node_or_null("MarginContainer/VBox/CostLabel") as Label
	var xp_label: Label = get_node_or_null("MarginContainer/VBox/XpLabel") as Label

	var c: CardResource = current_card as CardResource
	if c == null:
		CardFrameUi.clear_overlay(self)
		CardBackgroundUi.clear_overlay(self)
		# v7.x：空槽位清除费用绘制
		_cost_draw_text = ""
		queue_redraw()
		if icon:
			CardFrameUi.clear_cost_corner_badge(icon)
			icon.texture = null
			icon.visible = false
		if name_label:
			name_label.text = "空"
			name_label.visible = true
		if cost_label:
			cost_label.text = ""
		if xp_label:
			xp_label.text = ""
		return

	CardFrameUi.apply_slot_chrome(self, c)

	if icon:
		var art_h: float = maxf(18.0, float(SLOT_SIZE.y) - float(COMPACT_BOTTOM_TEXT_H) - 8.0)
		var art_w: float = float(SLOT_SIZE.x) - 8.0
		var tex: Texture2D = UiAssetLoader.load_tex(UiAssetLoader.card_icon_path_for(c))
		UiAssetLoader.setup_card_unit_icon(icon, tex, Vector2(art_w, art_h), true)

	if name_label:
		var display_name: String = "能量" if c.card_type == GameConstants.CardType.ENERGY else DefaultCards.safe_name(c)
		if display_name.length() > 6:
			display_name = display_name.substr(0, 6)
		# v7.x：同名卡追加序号后缀（#1/#2…），截断后追加
		display_name += DefaultCards.seq_suffix(c)
		name_label.text = display_name
		name_label.visible = true
		match c.rarity:
			"uncommon":
				name_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6, 1))
			"rare":
				name_label.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0, 1))
			"legendary":
				name_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.9, 1))
			_:
				name_label.add_theme_color_override("font_color", Color(0.9, 0.93, 1.0, 1))

	if cost_label:
		cost_label.text = ""
	# v7.x：费用用 _draw 直接画在卡牌左上角（绕过 PanelContainer 布局强制）
	_cost_draw_text = "%d⚡" % int(c.energy_cost)
	queue_redraw()

	if xp_label:
		if weight_capacity > 0:
			xp_label.text = "%d/%d" % [used_weight, weight_capacity]
			xp_label.visible = true
		else:
			xp_label.text = ""
			xp_label.visible = false

func _draw() -> void:
	# v7.x：费用文字直接画在卡牌左上角（绕过 PanelContainer 对子节点的布局强制管理）
	if _cost_draw_text.is_empty():
		return
	var font := get_theme_default_font()
	if font == null:
		return
	var fs: int = 10
	var ts: Vector2 = font.get_string_size(_cost_draw_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	# 左上角，留 2px 边距，在文字下层画个半透明深色小方块增强可读性
	var pos: Vector2 = Vector2(2.0, 2.0 + ts.y - 1.0)
	var box_rect: Rect2 = Rect2(1.0, 2.0, ts.x + 3.0, ts.y + 1.0)
	draw_rect(box_rect, Color(0.0, 0.0, 0.0, 0.55), true)
	# 金黄色费用文字 + 深色描边
	font.draw_string_outline(get_canvas_item(), pos, _cost_draw_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 1, Color(0.0, 0.0, 0.0, 0.95))
	font.draw_string(get_canvas_item(), pos, _cost_draw_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.85, 0.30, 1.0))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb_event: InputEventMouseButton = event
		if mb_event.pressed:
			slot_clicked.emit(slot_index, mb_event.button_index)

