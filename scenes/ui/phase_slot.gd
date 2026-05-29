class_name PhaseSlot
extends PanelContainer

const GameConstants = preload("res://resources/game_constants.gd")
const UiAssetLoader = preload("res://scripts/ui_asset_loader.gd")
const CardFrameUi = preload("res://scripts/card_frame_ui.gd")
const CardBackgroundUi = preload("res://scripts/card_background_ui.gd")
const CardInfoPanel = preload("res://scenes/ui/card_info_panel.gd")

## 竖向格：窄宽高长，与背包卡、相位仪条视觉一致
const SLOT_SIZE: Vector2 = Vector2(50, 80)
const COMPACT_BOTTOM_TEXT_H := 30

var slot_index: int = 0
var current_card = null
var used_weight: int = 0
var weight_capacity: int = 0
var _is_weight_capped: bool = false
var _is_hovering: bool = false
var _tween = null

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
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

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
		if icon:
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
		var display_name: String = "能量" if c.card_type == GameConstants.CardType.ENERGY else String(c.display_name)
		if display_name.length() > 6:
			display_name = display_name.substr(0, 6)
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
		cost_label.text = "%d⚡" % int(c.energy_cost)
		cost_label.visible = true

	if xp_label:
		if weight_capacity > 0:
			xp_label.text = "%d/%d" % [used_weight, weight_capacity]
			xp_label.visible = true
		else:
			xp_label.text = ""
			xp_label.visible = false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb_event: InputEventMouseButton = event
		if mb_event.pressed:
			slot_clicked.emit(slot_index, mb_event.button_index)

func _on_mouse_entered() -> void:
	_is_hovering = true
	_show_card_info_panel()

func _on_mouse_exited() -> void:
	_is_hovering = false
	_hide_card_info_panel()

func _show_card_info_panel() -> void:
	if not _is_hovering:
		return
	var c: CardResource = current_card as CardResource
	if c == null:
		return

	var tree: SceneTree = get_tree()
	if not tree or not is_instance_valid(tree):
		return

	var root: Window = tree.root
	if root == null:
		return

	# 单例挂在 root，避免随 current_scene 切换重复创建
	var info_panel: Control = root.get_node_or_null("CardInfoPanel") as Control
	if info_panel == null:
		info_panel = CardInfoPanel.new() as Control
		info_panel.name = "CardInfoPanel"
		root.add_child(info_panel)

	if info_panel.has_method("show_card_info"):
		# 计算提示位置（优先在槽位右侧，超出屏幕则在左侧）
		var slot_rect: Rect2 = get_global_rect()
		var panel_pos: Vector2 = slot_rect.position + Vector2(slot_rect.size.x + 8.0, 0.0)
		
		# 检查是否超出屏幕右侧
		var viewport_size: Vector2 = tree.current_scene.get_viewport_rect().size
		if panel_pos.x + 400.0 > viewport_size.x:  # 假设面板宽度约400
			panel_pos.x = slot_rect.position.x - 408.0  # 移到左侧
		
		info_panel.show_card_info(c, panel_pos)

func _hide_card_info_panel() -> void:
	var tree: SceneTree = get_tree()
	if not tree or not is_instance_valid(tree):
		return

	var root: Window = tree.root
	if root == null:
		return

	var info_panel: Control = root.get_node_or_null("CardInfoPanel") as Control
	if info_panel != null and info_panel.has_method("hide_panel"):
		info_panel.hide_panel()
