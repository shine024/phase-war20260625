extends VBoxContainer
## 制造区域：入口为底部栏「制造」→ 直接弹出装配；信息库弹窗仍挂在本场景供 Main 打开。

signal closed

const DefaultCards = preload("res://data/default_cards.gd")
const EnemyArchetypes = preload("res://data/enemy_archetypes.gd")
const GC = preload("res://resources/game_constants.gd")
const PhaseLaws = preload("res://data/phase_laws.gd")
@onready var assemble_popup: PanelContainer = $AssemblePopup
@onready var info_popup: PopupPanel = $InfoPopup
@onready var assemble_tree: Tree = $AssemblePopup/Margin/VBox/ScrollContainer/AssembleTree
@onready var platform_label: Label = $AssemblePopup/Margin/VBox/ComboArea/PlatformLabel
@onready var weapon_label: Label = $AssemblePopup/Margin/VBox/ComboArea/WeaponLabel
@onready var card_info_label: Label = $AssemblePopup/Margin/VBox/ComboArea/CardInfoLabel
@onready var assemble_combined_btn: Button = $AssemblePopup/Margin/VBox/ComboArea/AssembleCombinedButton
@onready var assemble_single_btn: Button = $AssemblePopup/Margin/VBox/ComboArea/AssembleSingleButton

var _selected_platform_card: CardResource = null
var _selected_weapon_cards: Array[CardResource] = []

func _enqueue_backpack_fallback_if_needed(card_id: String) -> void:
	if card_id.is_empty():
		return
	# 优先走 SignalBus.card_added_to_backpack（SaveManager 已监听该信号并入队）。
	# 仅当 SignalBus 不可用时，才走直接 enqueue 兜底，避免同一次制造被重复入队。
	if (SignalBus == null) and SaveManager and SaveManager.has_method("enqueue_backpack_card_id"):
		SaveManager.enqueue_backpack_card_id(card_id)

func _build_card_tooltip(card: CardResource) -> String:
	if card == null:
		return ""
	var lines: Array = []
	var head: String = DefaultCards.safe_name(card)
	if String(card.rarity).length() > 0:
		head = "[%s] %s" % [String(card.rarity), DefaultCards.safe_name(card)]
	lines.append(head)
	if String(card.type_line).length() > 0:
		lines.append(String(card.type_line))
	var summary: String = ""
	summary = String(card.summary_line)
	if not summary.is_empty():
		lines.append(summary)
	if String(card.description).length() > 0:
		lines.append("")
		lines.append(String(card.description))
	return "\n".join(lines)

## 关闭装配区与信息库子 Popup；装配区用 Panel 而非 PopupPanel，避免残留独占输入假死
func close_embedded_popups() -> void:
	if assemble_popup and is_instance_valid(assemble_popup) and assemble_popup.visible:
		assemble_popup.visible = false
	if info_popup and is_instance_valid(info_popup) and info_popup.visible:
		info_popup.hide()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		call_deferred("close_embedded_popups")

func _ready() -> void:
	# Add close button handler for parent overlay
	var overlay = get_parent()
	if overlay and overlay.has_signal("close_requested"):
		overlay.close_requested.connect(_on_close_pressed)
	elif overlay and overlay.has_method("hide"):
		var close_btn = get_node_or_null("../CloseButton")
		if close_btn:
			close_btn.pressed.connect(func(): emit_signal("closed"))
	
	if assemble_tree:
		assemble_tree.item_selected.connect(_on_assemble_tree_item_selected)
	if assemble_combined_btn:
		assemble_combined_btn.pressed.connect(_on_assemble_combined)
	if assemble_single_btn:
		assemble_single_btn.pressed.connect(_on_assemble_single)
	if assemble_popup:
		var acb: Button = assemble_popup.get_node_or_null("Margin/VBox/CloseButton")
		if acb:
			# 装配区“关闭”应关闭整个制造界面，否则全屏 Overlay 会残留并吞掉点击
			acb.pressed.connect(_on_close_pressed)
	if info_popup:
		var icb: Button = info_popup.get_node_or_null("Margin/VBox/CloseButton")
		if icb:
			icb.pressed.connect(func() -> void: info_popup.hide())

func _on_assemble_pressed() -> void:
	_selected_platform_card = null
	_selected_weapon_cards.clear()
	_refresh_assemble_tree()
	_update_combo_labels()
	if assemble_popup:
		assemble_popup.visible = true

func _refresh_assemble_tree() -> void:
	if not assemble_tree:
		return
	var root := assemble_tree.get_root()
	if root == null:
		root = assemble_tree.create_item()
	else:
		for child in root.get_children():
			child.free()
	var ids: Array = BlueprintManager.get_unlocked_blueprint_ids()
	var platform_cards: Array[CardResource] = []
	var law_cards: Array[CardResource] = []
	var energy_cards: Array[CardResource] = []
	for bid in ids:
		var card_id: String = bid as String
		var card: CardResource = DefaultCards.get_card_by_id(card_id)
		if not card:
			# 尝试作为法则卡处理
			var law_lookup_id: String = card_id
			if law_lookup_id.begins_with("law:"):
				law_lookup_id = law_lookup_id.substr(4)
			if not PhaseLaws.get_by_id(law_lookup_id).is_empty():
				card = DefaultCards.create_law_card_resource(law_lookup_id)
				if card:
					card.card_id = law_lookup_id  # 确保card_id是不带前缀的
		if not card:
			continue
		if card.card_type == GC.CardType.COMBAT_UNIT:
			platform_cards.append(card)
		elif card.card_type == GC.CardType.LAW:
			law_cards.append(card)
		elif card.card_type == GC.CardType.ENERGY:
			energy_cards.append(card)
	if platform_cards.is_empty() and law_cards.is_empty() and energy_cards.is_empty():
		return
	if not platform_cards.is_empty():
		var platform_item: TreeItem = assemble_tree.create_item(root)
		platform_item.set_text(0, "载具")
		platform_item.set_selectable(0, false)
		for c in platform_cards:
			var child_item: TreeItem = assemble_tree.create_item(platform_item)
			child_item.set_text(0, DefaultCards.safe_name(c))
			child_item.set_metadata(0, c.card_id)
			child_item.set_tooltip_text(0, _build_card_tooltip(c))
	if not law_cards.is_empty():
		var law_item: TreeItem = assemble_tree.create_item(root)
		law_item.set_text(0, "法则")
		law_item.set_selectable(0, false)
		for c in law_cards:
			var child_item: TreeItem = assemble_tree.create_item(law_item)
			child_item.set_text(0, DefaultCards.safe_name(c))
			child_item.set_metadata(0, c.card_id)
			child_item.set_tooltip_text(0, _build_card_tooltip(c))
	if not energy_cards.is_empty():
		var energy_item: TreeItem = assemble_tree.create_item(root)
		energy_item.set_text(0, "能量")
		energy_item.set_selectable(0, false)
		for c in energy_cards:
			var child_item: TreeItem = assemble_tree.create_item(energy_item)
			child_item.set_text(0, DefaultCards.safe_name(c))
			child_item.set_metadata(0, c.card_id)
			child_item.set_tooltip_text(0, _build_card_tooltip(c))

func _on_assemble_tree_item_selected() -> void:
	var item: TreeItem = assemble_tree.get_selected()
	if item == null:
		return
	var raw: Variant = item.get_metadata(0)
	if raw == null:
		return
	var card: CardResource = DefaultCards.get_card_by_id(str(raw))
	if not card:
		return
	if card.card_type == GC.CardType.COMBAT_UNIT:
		_selected_platform_card = card
		var max_w: int = max(_selected_platform_card.max_weapons, 1)
		if _selected_weapon_cards.size() > max_w:
			_selected_weapon_cards.resize(max_w)
	_update_combo_labels()

func _update_combo_labels() -> void:
	if card_info_label:
		if _selected_platform_card != null:
			var info = "%s\n%s\n重量: %d/%d" % [
				DefaultCards.safe_name(_selected_platform_card),
				_selected_platform_card.rarity,
				0,
				_selected_platform_card.weight_capacity
			]
			card_info_label.text = info
		else:
			card_info_label.text = "选择载具查看详情"
	if platform_label:
		platform_label.text = "已选载具：%s" % (DefaultCards.safe_name(_selected_platform_card) if _selected_platform_card else "—")
	if assemble_combined_btn:
		assemble_combined_btn.disabled = true
	var selected_item: TreeItem = assemble_tree.get_selected() if assemble_tree else null
	var can_single: bool = selected_item != null and selected_item.get_metadata(0) != null
	if assemble_single_btn:
		assemble_single_btn.disabled = not can_single

func _on_assemble_combined() -> void:
	push_warning("[ManufacturePanel] 合成功能已废弃")
	return

func _on_assemble_single() -> void:
	var item: TreeItem = assemble_tree.get_selected() if assemble_tree else null
	if item == null:
		return
	var raw: Variant = item.get_metadata(0)
	if raw == null:
		return
	var card_id: String = str(raw)
	var card: CardResource = DefaultCards.get_card_by_id(card_id)

		# 如果是法则卡，尝试创建，同时修复 blueprint_id 匹配
	if card == null:
		var law_lookup_id: String = card_id
		if law_lookup_id.begins_with("law:"):
			law_lookup_id = law_lookup_id.substr(4)
		if not PhaseLaws.get_by_id(law_lookup_id).is_empty():
			card = DefaultCards.create_law_card_resource(law_lookup_id)
			if card:
				card.card_id = law_lookup_id
				# 确保 card_id 使用 BlueprintManager 中存储的格式（law:xxx）
				card_id = "law:" + law_lookup_id

	if card == null:
		return

	# 检查是否可以制造
	if BlueprintManager and BlueprintManager.has_method("can_manufacture") and not BlueprintManager.can_manufacture(card_id):
		var reason: String = "条件不足"
		if BlueprintManager.has_method("get_manufacture_info"):
			var info: Dictionary = BlueprintManager.get_manufacture_info(card_id)
			reason = String(info.get("reason", reason))
		push_error("[ManufacturePanel] 无法制造卡牌: %s（%s）" % [card_id, reason])
		return

	# 法则卡和能量卡：直接制造
	if card.card_type == GC.CardType.LAW or card.card_type == GC.CardType.ENERGY:
		if BlueprintManager and BlueprintManager.has_method("manufacture_card"):
			var manufactured_card: CardResource = BlueprintManager.manufacture_card(card_id)
			if manufactured_card:
				# 同步解锁法则到 PhaseLawManager
				if manufactured_card.card_type == GC.CardType.LAW:
					var law_id: String = manufactured_card.linked_law_id if manufactured_card.linked_law_id else manufactured_card.card_id
				var plm := get_node_or_null("/root/PhaseLawManager")
				if plm and plm.has_method("ensure_law_unlocked"):
					plm.ensure_law_unlocked(law_id)
						print("[ManufacturePanel] 法则已解锁: ", law_id)
				# 继承蓝图星级（已废弃，enhance_level 由养成系统管理）
				#if BlueprintManager.has_method("get_blueprint_star"):
				#	manufactured_card.star_level = BlueprintManager.get_blueprint_star(card_id)
				if SignalBus:
					_enqueue_backpack_fallback_if_needed(String(manufactured_card.card_id))
					SignalBus.card_added_to_backpack.emit(manufactured_card)
				print("[ManufacturePanel] 制造成功: ", DefaultCards.safe_name(manufactured_card))
		return

	# 平台和武器卡：原有逻辑
	if card:
	# 继承蓝图星级（已废弃，enhance_level 由养成系统管理）
	#if BlueprintManager and BlueprintManager.has_method("get_blueprint_star"):
	#	card.star_level = BlueprintManager.get_blueprint_star(card.card_id)
		var am: Node = get_node_or_null("/root/AffixManager")
		if am and am.has_method("grant_initial_affixes_for_card"):
			# 避开制造点击同帧的 UI 重建，减轻主线程尖峰。
			am.call_deferred("grant_initial_affixes_for_card", card)
		if SignalBus:
			_enqueue_backpack_fallback_if_needed(String(card.card_id))
			SignalBus.card_added_to_backpack.emit(card)

func refresh() -> void:
	_selected_platform_card = null
	_selected_weapon_cards.clear()
	_refresh_assemble_tree()
	_update_combo_labels()

func _on_close_pressed() -> void:
	close_embedded_popups()
	emit_signal("closed")
