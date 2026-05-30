extends PanelContainer
## 统一的卡牌情报显示面板（背包、相位仪、商店复用）
## 显示卡牌的完整三维攻防信息

const DefaultCards = preload("res://data/default_cards.gd")
const UnitStatsTable = preload("res://resources/unit_stats_table.gd")
const BackpackCombatPreview = preload("res://scenes/ui/backpack_combat_preview.gd")
const RankDisplayUi = preload("res://scripts/rank_display_ui.gd")

var current_card: CardResource = null

@onready var name_label: Label = $Margin/VBox/HeaderPanel/NameLabel
@onready var type_label: Label = $Margin/VBox/TypeLabel
@onready var summary_label: Label = $Margin/VBox/StatsBox/SummaryLabel
@onready var desc_label: Label = $Margin/VBox/DescLabel
@onready var flavor_label: Label = $Margin/VBox/FlavorLabel
@onready var rank_badge_host: HBoxContainer = $Margin/VBox/RankBadgeHost

func _ready() -> void:
	visible = false
	z_index = 100

## 显示卡牌情报
func show_card_info(card: CardResource, at_position: Vector2 = Vector2.ZERO) -> void:
	if card == null:
		hide_panel()
		return
	
	current_card = card
	_refresh_display()
	visible = true
	
	# 如果提供了位置，定位到该位置
	if at_position != Vector2.ZERO:
		var container = get_parent()
		await get_tree().process_frame
		if not is_inside_tree():
			return
		var panel_w := size.x
		var panel_h := size.y
		if container is Control:
			var cw := (container as Control).size.x
			var ch := (container as Control).size.y
			position = Vector2(
				clampf(at_position.x, 8.0, maxf(8.0, cw - panel_w - 8.0)),
				clampf(at_position.y, 8.0, maxf(8.0, ch - panel_h - 8.0))
			)
		else:
			position = at_position

func _refresh_display() -> void:
	if current_card == null:
		return
	
	# 基本信息显示
	if name_label:
		name_label.text = current_card.display_name if not current_card.display_name.is_empty() else DefaultCards.get_safe_display_name(current_card.card_id)
	
	if type_label:
		var type_text = ""
		match current_card.card_type:
			0: # COMBAT_UNIT
				type_text = "战斗卡 — %s" % DefaultCards.get_platform_display_name(current_card.combat_kind)
			1: # ENERGY
				type_text = "能量卡"
			2: # LAW
				type_text = "法则卡"
		type_label.text = type_text
	
	# 显示三维攻防情报（使用 BackpackCombatPreview 统一格式）
	if summary_label:
		var preview: String = BackpackCombatPreview.build_line(current_card)
		if preview.begins_with("战斗中："):
			preview = preview.substr(5)  # 去掉前缀
		summary_label.text = preview
	
	# 描述文本
	if desc_label:
		desc_label.text = current_card.description
	
	# 风味文本
	if flavor_label:
		flavor_label.text = current_card.flavor_text
	
	# 显示星级/军衔信息
	if rank_badge_host:
		RankDisplayUi.clear_host(rank_badge_host)
		# 暂时跳过军衔显示，因为 RankDisplayUi 可能没有 resolve_from_card_id 方法
		rank_badge_host.visible = false

func hide_panel() -> void:
	visible = false
	current_card = null
