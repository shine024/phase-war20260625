extends PanelContainer
## 词条管理面板（AffixPanel）
## 左栏：卡牌列表（含词条数量角标）
## 右栏：选中卡牌的强化类型选择（机体/武器）+ 词条详情

signal closed

const AffixDefs = preload("res://data/affix_definitions.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const EnemyPhaseEquipment = preload("res://data/enemy_phase_equipment.gd")
const PlatformDefaultWeapons = preload("res://data/platform_default_weapons.gd")
const GC = preload("res://resources/game_constants.gd")
const AffixRowScene = preload("res://scenes/ui/affix_row.tscn")

var _selected_card_id: String = ""
var _selected_affix_type: int = 0  # 0=机体, 1=武器

# 静态布局节点（已移至 affix_panel.tscn）
@onready var _nano_label: Label = $RootMargin/RootVBox/TitleHBox/NanoLabel
@onready var _card_list: VBoxContainer = $RootMargin/RootVBox/ContentHBox/LeftVBox/CardScroll/CardList
@onready var _selected_card_lbl: Label = $RootMargin/RootVBox/ContentHBox/RightVBox/SelectedCardLabel
@onready var _platform_btn: Button = $RootMargin/RootVBox/ContentHBox/RightVBox/TypeSelectBox/PlatformBtn
@onready var _weapon_btn: Button = $RootMargin/RootVBox/ContentHBox/RightVBox/TypeSelectBox/WeaponBtn
@onready var _affix_count_lbl: Label = $RootMargin/RootVBox/ContentHBox/RightVBox/AffixCountLabel
@onready var _affix_list: VBoxContainer = $RootMargin/RootVBox/ContentHBox/RightVBox/AffixScroll/AffixList
@onready var _empty_hint: Label = $RootMargin/RootVBox/ContentHBox/RightVBox/AffixScroll/AffixList/EmptyHint
@onready var _batch_cost_lbl: Label = $RootMargin/RootVBox/ContentHBox/RightVBox/BatchCostBar/BatchCostLabel
@onready var _batch_reroll_btn: Button = $RootMargin/RootVBox/ContentHBox/RightVBox/BatchCostBar/BatchRerollBtn

# 缓存样式（避免每次 .new()）
var _hover_style: StyleBoxFlat
var _pressed_style: StyleBoxFlat
var _card_normal_selected: StyleBoxFlat
var _card_normal_unselected: StyleBoxFlat
var _type_platform_active: StyleBoxFlat
var _type_platform_inactive: StyleBoxFlat
var _type_weapon_active: StyleBoxFlat
var _type_weapon_inactive: StyleBoxFlat
var _reroll_btn_disabled: StyleBoxFlat
var _reroll_btn_enabled: StyleBoxFlat
var _lock_btn_locked: StyleBoxFlat
var _lock_btn_unlocked: StyleBoxFlat

func _ready() -> void:
	# 初始化缓存样式
	_init_cached_styles()

	# 连接按钮信号
	$RootMargin/RootVBox/TitleHBox/CloseBtn.pressed.connect(func() -> void: emit_signal("closed"))
	_platform_btn.pressed.connect(func() -> void: _on_type_selected(0))
	_weapon_btn.pressed.connect(func() -> void: _on_type_selected(1))
	_batch_reroll_btn.pressed.connect(func() -> void: _on_batch_reroll_pressed())

	# 连接 AffixManager 信号
	ManagerLazyLoader.ensure_loaded("affix")
	var affix_mgr = get_node_or_null("/root/AffixManager")
	if affix_mgr:
		if not affix_mgr.affix_changed.is_connected(_on_affix_changed):
			affix_mgr.affix_changed.connect(_on_affix_changed)
	_refresh_card_list()

# ─────────────────────────────────────────────
#  缓存样式（替代运行时 .new()）
# ─────────────────────────────────────────────

func _init_cached_styles() -> void:
	_hover_style = _make_style_box(Color(0.18, 0.10, 0.28, 0.9), Color(0.80, 0.45, 1.0, 0.6), 1, 4)
	_pressed_style = _make_style_box(Color(0.28, 0.15, 0.45, 0.95), Color(0.80, 0.45, 1.0, 1.0), 2, 4)
	_card_normal_selected = _make_style_box(Color(0.25, 0.12, 0.40, 0.95), Color(0.80, 0.45, 1.0, 0.8), 1, 4)
	_card_normal_unselected = _make_style_box(Color(0.10, 0.08, 0.15, 0.80), Color(0.50, 0.30, 0.80, 0.35), 1, 4)
	_type_platform_active = _make_style_box(Color(0.2, 0.5, 0.3, 0.9), Color(0.4, 1.0, 0.6, 0.8), 1, 4)
	_type_platform_inactive = _make_style_box(Color(0.15, 0.15, 0.2, 0.8), Color(0.4, 0.4, 0.5, 0.3), 1, 4)
	_type_weapon_active = _make_style_box(Color(0.5, 0.2, 0.2, 0.9), Color(1.0, 0.4, 0.4, 0.8), 1, 4)
	_type_weapon_inactive = _make_style_box(Color(0.15, 0.15, 0.2, 0.8), Color(0.4, 0.4, 0.5, 0.3), 1, 4)
	_reroll_btn_disabled = _make_style_box(Color(0.12, 0.10, 0.15, 0.5), Color(0.4, 0.4, 0.5, 0.3), 1, 4)
	_reroll_btn_enabled = _make_style_box(Color(0.15, 0.25, 0.20, 0.9), Color(0.3, 0.8, 0.5, 0.7), 1, 4)
	_lock_btn_locked = _make_style_box(Color(0.25, 0.15, 0.10, 0.9), Color(1.0, 0.6, 0.2, 0.7), 1, 4)
	_lock_btn_unlocked = _make_style_box(Color(0.20, 0.15, 0.25, 0.9), Color(0.8, 0.45, 0.8, 0.7), 1, 4)

func _make_style_box(bg: Color, border: Color, bw: int, cr: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(cr)
	return s

# ─────────────────────────────────────────────
#  数据刷新
# ─────────────────────────────────────────────

func _refresh_card_list() -> void:
	for child in _card_list.get_children():
		child.queue_free()

	# 更新纳米材料显示
	_refresh_nano_label()

	# 直接从 BlueprintManager 获取已解锁蓝图列表
	var ids: Array = []

	if BlueprintManager:
		ids = BlueprintManager.get_unlocked_blueprint_ids()

	# 也从 BackpackPanel 获取额外制造的合成卡
	var bp: Node = get_node_or_null("/root/Main/PopupLayer/BackpackOverlay/BackpackVBox/CenterRow/BackpackCenter/BackpackPanel")
	if bp == null:
		bp = get_node_or_null("/root/Main/PopupLayer/BackpackOverlay/BackpackVBox/CenterRow/BackpackCenter/backpack_panel")
	if bp and bp.has_method("get_extra_card_ids"):
		var extra_ids: Array = bp.get_extra_card_ids()
		for eid in extra_ids:
			var eid_s: String = str(eid)
			if not eid_s.is_empty() and not ids.has(eid_s):
				ids.append(eid_s)

	# 过滤掉能量卡和法则卡
	var filtered: Array = []
	for id in ids:
		var id_s: String = str(id)
		if id_s.is_empty():
			continue
		if id_s.begins_with("energy"):
			continue
		if BlueprintManager and BlueprintManager.has_method("is_law_blueprint_id"):
			if BlueprintManager.is_law_blueprint_id(id_s):
				continue
		filtered.append(id_s)

	if filtered.is_empty():
		var hint := Label.new()
		hint.text = "暂无可用卡牌"
		hint.add_theme_font_size_override("font_size", 12)
		hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6, 0.8))
		_card_list.add_child(hint)
		return

	for card_id in filtered:
		var btn := _make_card_list_btn(card_id)
		_card_list.add_child(btn)

func _make_card_list_btn(card_id: String) -> Button:
	var btn := Button.new()
	btn.name = "CardBtn_%s" % card_id

	var lines: Array[String] = _build_affix_card_lines(card_id)
	btn.text = "\n".join(lines)

	btn.add_theme_font_size_override("font_size", 12)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var target_height: int = maxi(56, 24 + lines.size() * 18)
	btn.custom_minimum_size = Vector2(0, target_height)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING

	var is_selected: bool = (_selected_card_id == card_id)
	if is_selected:
		btn.add_theme_color_override("font_color", Color(0.90, 0.60, 1.0, 1.0))
	else:
		btn.add_theme_color_override("font_color", Color(0.75, 0.75, 0.88, 0.9))
	btn.add_theme_stylebox_override("normal", _card_normal_selected if is_selected else _card_normal_unselected)
	btn.add_theme_stylebox_override("hover", _hover_style)
	btn.add_theme_stylebox_override("pressed", _pressed_style)

	btn.pressed.connect(func() -> void: _on_card_selected(card_id))
	return btn

func _build_affix_card_lines(card_id: String) -> Array[String]:
	var lines: Array[String] = []
	if card_id.is_empty():
		lines.append("未知机体")
		return lines
	var card: CardResource = _resolve_card_for_affix_list(card_id)
	if card == null:
		lines.append(card_id)
		return lines

	var machine_name: String = DefaultCards.safe_name(card)
	var weapon_names: Array[String] = []

	if card.card_type == GC.CardType.COMBAT_UNIT:
		if not card.source_platform_id.is_empty():
			machine_name = _resolve_card_name_by_id(card.source_platform_id)
		for wid_raw in card.source_weapon_ids:
			var wid: String = str(wid_raw)
			if wid.is_empty():
				continue
			weapon_names.append(_resolve_card_name_by_id(wid))
	elif card.card_type == GC.CardType.COMBAT_UNIT:
		machine_name = DefaultCards.safe_name(card)
		weapon_names.append(_suggest_weapon_name_for_platform(card))
	elif card.card_type == GC.CardType.COMBAT_UNIT:
		machine_name = "通用机体"
		weapon_names.append(DefaultCards.safe_name(card))
	else:
		machine_name = DefaultCards.safe_name(card)

	lines.append(machine_name)
	for weapon_name in weapon_names:
		lines.append("    · %s" % weapon_name)
	return lines

func _resolve_card_for_affix_list(card_id: String) -> CardResource:
	if card_id.is_empty():
		return null
	if DefaultCards:
		var card: CardResource = DefaultCards.get_card_by_id(card_id)
		if card != null:
			return card
	return EnemyPhaseEquipment.get_equipment_blueprint(card_id)

func _resolve_card_name_by_id(card_id: String) -> String:
	if card_id.is_empty():
		return "未知武器"
	var card: CardResource = _resolve_card_for_affix_list(card_id)
	if card != null and not card.display_name.is_empty():
		return DefaultCards.safe_name(card)
	return card_id

func _suggest_weapon_name_for_platform(platform_card: CardResource) -> String:
	if platform_card == null:
		return "通用机枪"
	var weapon_id: String = PlatformDefaultWeapons.resolve_default_weapon_id(platform_card.card_id)
	var weapon_name: String = _resolve_card_name_by_id(weapon_id)
	return weapon_name if not weapon_name.is_empty() else "通用机枪"

## 获取词条的唯一key（卡牌ID + 强化类型）
func _get_affix_key(card_id: String, affix_type: int) -> String:
	return "%s_%d" % [card_id, affix_type]

func _on_card_selected(card_id: String) -> void:
	_selected_card_id = card_id
	# 默认选择平台强化
	_selected_affix_type = 0
	_refresh_card_list()
	_update_type_buttons()
	_refresh_affix_detail()
	_refresh_batch_cost_bar()

func _on_type_selected(affix_type: int) -> void:
	_selected_affix_type = affix_type
	_update_type_buttons()
	_refresh_affix_detail()
	_refresh_batch_cost_bar()

func _update_type_buttons() -> void:
	if _selected_affix_type == 0:
		_platform_btn.add_theme_stylebox_override("normal", _type_platform_active)
		_weapon_btn.add_theme_stylebox_override("normal", _type_weapon_inactive)
	else:
		_platform_btn.add_theme_stylebox_override("normal", _type_platform_inactive)
		_weapon_btn.add_theme_stylebox_override("normal", _type_weapon_active)

func _refresh_affix_detail() -> void:
	# 清空旧内容（保留 EmptyHint）
	for child in _affix_list.get_children():
		if child.name != "EmptyHint":
			child.queue_free()

	# 更新卡牌名称
	if _selected_card_id.is_empty():
		_selected_card_lbl.text = "← 选择一张卡牌"
	else:
		var display_name: String = _selected_card_id
		var level: int = 1

		if BlueprintManager and BlueprintManager.has_method("get_card_level"):
			level = BlueprintManager.get_card_level(_selected_card_id)

		if DefaultCards != null:
			var card: CardResource = DefaultCards.get_card_by_id(_selected_card_id)
			if card:
				display_name = DefaultCards.safe_name(card)

		var type_str: String = "机体" if _selected_affix_type == 0 else "武器"
		_selected_card_lbl.text = "📋 %s [%s] Lv%d" % [display_name, type_str, level]

	# 获取当前类型的词条
	var affix_key: String = _get_affix_key(_selected_card_id, _selected_affix_type)
	var affixes: Array = []
	var affix_mgr = get_node_or_null("/root/AffixManager")
	if affix_mgr and not _selected_card_id.is_empty():
		affixes = affix_mgr.get_card_affixes(affix_key)

	# 更新词条数量显示
	_affix_count_lbl.text = "词条: %d/%d" % [int(affixes.size()), AffixDefs.MAX_AFFIX_SLOTS]

	if affixes.is_empty():
		_empty_hint.visible = true
		# 显示空槽提示
		var slot_hint := Label.new()
		slot_hint.text = "（空词条槽 ×%d）" % (AffixDefs.MAX_AFFIX_SLOTS)
		slot_hint.add_theme_font_size_override("font_size", 11)
		slot_hint.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5, 0.6))
		_affix_list.add_child(slot_hint)
	else:
		_empty_hint.visible = false
		for i in range(affixes.size()):
			var affix: AffixResource = affixes[i] as AffixResource
			var row := _make_affix_row(affix_key, affix, i, affix_mgr)
			_affix_list.add_child(row)

		# 空槽位显示
		var slot_count: int = AffixDefs.MAX_AFFIX_SLOTS
		var used: int = affixes.size()
		if used < slot_count:
			var slot_hint := Label.new()
			slot_hint.text = "（空词条槽 ×%d）" % (slot_count - used)
			slot_hint.add_theme_font_size_override("font_size", 11)
			slot_hint.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5, 0.6))
			_affix_list.add_child(slot_hint)

func _make_affix_row(affix_key: String, affix: AffixResource, slot_index: int, affix_mgr: Node = null) -> PanelContainer:
	var row: PanelContainer = AffixRowScene.instantiate()

	# 行样式（稀有度颜色动态）
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.12, 0.08, 0.20, 0.85)
	var rarity_color := GC.get_rarity_color(affix.rarity)
	row_style.border_color = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.5)
	row_style.set_border_width_all(1)
	row_style.set_corner_radius_all(5)
	row.add_theme_stylebox_override("panel", row_style)

	# 名称
	var name_lbl: Label = row.get_node("Margin/VBox/TopHBox/NameLabel")
	name_lbl.text = affix.get_display_name()
	name_lbl.add_theme_color_override("font_color", rarity_color)

	# 重随按钮
	var reroll_btn: Button = row.get_node("Margin/VBox/TopHBox/RerollBtn")
	var reroll_cost: int = AffixDefs.REROLL_COSTS[slot_index] if slot_index < AffixDefs.REROLL_COSTS.size() else AffixDefs.REROLL_COSTS.back()
	reroll_btn.text = "重随 %d纳" % reroll_cost
	reroll_btn.disabled = true
	_style_reroll_btn(reroll_btn, true)

	# 锁定按钮
	var lock_btn: Button = row.get_node("Margin/VBox/TopHBox/LockBtn")
	lock_btn.text = "🔓" if affix.is_locked else "🔒"
	_style_lock_btn(lock_btn, affix.is_locked)
	lock_btn.pressed.connect(func() -> void: _on_lock_pressed(affix_key, slot_index, affix.is_locked))

	# 描述
	var desc_lbl: Label = row.get_node("Margin/VBox/DescLabel")
	desc_lbl.text = affix.get_detailed_description()

	# 变异标记
	var mut_lbl: Label = row.get_node("Margin/VBox/MutLabel")
	if affix.is_mutated and not affix.mutation_description.is_empty():
		mut_lbl.text = "⚡ 变异: %s" % affix.mutation_description
		mut_lbl.visible = true
	else:
		mut_lbl.visible = false

	return row

func _style_reroll_btn(btn: Button, disabled: bool) -> void:
	btn.add_theme_stylebox_override("normal", _reroll_btn_disabled if disabled else _reroll_btn_enabled)
	if disabled:
		btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55, 0.6))
	else:
		btn.add_theme_color_override("font_color", Color(0.5, 1.0, 0.7, 1.0))

func _style_lock_btn(btn: Button, is_locked: bool) -> void:
	btn.add_theme_stylebox_override("normal", _lock_btn_locked if is_locked else _lock_btn_unlocked)
	if is_locked:
		btn.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4, 1.0))
	else:
		btn.add_theme_color_override("font_color", Color(1.0, 0.6, 1.0, 1.0))

func _refresh_nano_label() -> void:
	if BlueprintManager and BlueprintManager.has_method("get_nano_materials"):
		_nano_label.text = "纳米: %d" % int(BlueprintManager.get_nano_materials())

func _refresh_batch_cost_bar() -> void:
	if _selected_card_id.is_empty():
		_batch_cost_lbl.text = "基础: 0  锁定额外: 0  合计: 0"
		_batch_reroll_btn.disabled = true
		return
	var affix_key: String = _get_affix_key(_selected_card_id, _selected_affix_type)
	var affix_mgr = get_node_or_null("/root/AffixManager")
	if affix_mgr == null or not affix_mgr.has_method("get_batch_reroll_cost"):
		_batch_reroll_btn.disabled = true
		return
	var info: Dictionary = affix_mgr.get_batch_reroll_cost(affix_key)
	var base_cost: int = int(info.get("base_cost", 0))
	var extra: int = int(info.get("extra_lock_cost", 0))
	var total: int = int(info.get("total_cost", 0))
	var locked_count: int = int(info.get("locked_count", 0))
	var reroll_count: int = int(info.get("reroll_count", 0))
	_batch_cost_lbl.text = "基础: %d  锁定额外: %d  合计: %d  （锁%d 洗%d）" % [base_cost, extra, total, locked_count, reroll_count]

	var nano: int = 0
	if BlueprintManager and BlueprintManager.has_method("get_nano_materials"):
		nano = int(BlueprintManager.get_nano_materials())
	_batch_reroll_btn.disabled = (total <= 0 or reroll_count <= 0 or nano < total)

# ─────────────────────────────────────────────
#  事件处理
# ─────────────────────────────────────────────

func _on_batch_reroll_pressed() -> void:
	var affix_mgr = get_node_or_null("/root/AffixManager")
	if affix_mgr == null or not affix_mgr.has_method("batch_reroll_affixes"):
		return
	if _selected_card_id.is_empty():
		return
	var affix_key: String = _get_affix_key(_selected_card_id, _selected_affix_type)
	var ok: bool = affix_mgr.batch_reroll_affixes(affix_key)
	if ok:
		_refresh_affix_detail()
		_refresh_card_list()
		_refresh_nano_label()
		_refresh_batch_cost_bar()

func _on_lock_pressed(affix_key: String, slot_index: int, is_currently_locked: bool) -> void:
	var affix_mgr = get_node_or_null("/root/AffixManager")
	if affix_mgr == null:
		return
	if is_currently_locked:
		affix_mgr.unlock_affix(affix_key, slot_index)
	else:
		affix_mgr.lock_affix(affix_key, slot_index)
	_refresh_affix_detail()
	_refresh_card_list()
	_refresh_batch_cost_bar()

func _on_affix_changed(card_id: String) -> void:
	_refresh_affix_detail()
	_refresh_card_list()
	_refresh_batch_cost_bar()

## 供蓝图库联动：直接打开指定卡牌与强化轨道
func open_for_card(card_id: String, affix_type: int = 0) -> void:
	_selected_card_id = card_id
	_selected_affix_type = 0 if affix_type != 1 else 1
	_refresh_card_list()
	_update_type_buttons()
	_refresh_affix_detail()
