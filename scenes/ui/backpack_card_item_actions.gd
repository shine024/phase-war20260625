## BackpackCardItem Action Button / Info Panel / Hover logic
## 提取自 backpack_card_item.gd，class_name 用于跨文件引用
class_name BackpackCardItemActions
extends RefCounted

const GC = preload("res://resources/game_constants.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const CardInfoPanel = preload("res://scenes/ui/card_info_panel.gd")

## 鼠标进入 - 延迟显示统一情报面板
static func on_mouse_entered(item: PanelContainer) -> void:
	if not item.ENABLE_HOVER_AFFIX_TOOLTIP:
		return
	if item.card == null:
		return
	item._affix_hover_seq += 1
	var seq := item._affix_hover_seq
	var tree := item.get_tree()
	if tree == null or not is_instance_valid(tree):
		return
	var timer := tree.create_timer(item._AFFIX_HOVER_DELAY_SEC, false, false, true)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(item) or item.card == null:
			return
		if seq != item._affix_hover_seq:
			return
		if item.get_global_mouse_position().distance_to(item.global_position + item.size / 2.0) < item.size.length():
			show_card_info_panel(item)
	, CONNECT_ONE_SHOT)

## 鼠标离开 - 隐藏统一情报面板
static func on_mouse_exited(item: PanelContainer) -> void:
	if not item.ENABLE_HOVER_AFFIX_TOOLTIP:
		return
	item._affix_hover_seq += 1
	hide_card_info_panel(item)

## 显示统一卡牌情报面板
static func show_card_info_panel(item: PanelContainer) -> void:
	if item.card == null:
		return

	var tree: SceneTree = item.get_tree()
	if not tree or not is_instance_valid(tree):
		return

	var root: Window = tree.root
	if root == null:
		return

	# 单例挂在 root
	var info_panel: Control = root.get_node_or_null("CardInfoPanel") as Control
	if info_panel == null:
		info_panel = CardInfoPanel.new() as Control
		info_panel.name = "CardInfoPanel"
		root.add_child(info_panel)

	if info_panel.has_method("show_card_info"):
		var card_rect: Rect2 = item.get_global_rect()
		var panel_pos: Vector2 = card_rect.position + Vector2(card_rect.size.x + 8.0, 0.0)
		# 检查是否超出屏幕右侧
		var viewport_size: Vector2 = tree.current_scene.get_viewport_rect().size
		if panel_pos.x + 400.0 > viewport_size.x:
			panel_pos.x = card_rect.position.x - 408.0
		info_panel.show_card_info(item.card, panel_pos)

## 隐藏统一卡牌情报面板
static func hide_card_info_panel(item: PanelContainer) -> void:
	var tree: SceneTree = item.get_tree()
	if not tree or not is_instance_valid(tree):
		return
	var root: Window = tree.root
	if root == null:
		return
	var info_panel: Control = root.get_node_or_null("CardInfoPanel") as Control
	if info_panel != null and info_panel.has_method("hide_panel"):
		info_panel.hide_panel()
