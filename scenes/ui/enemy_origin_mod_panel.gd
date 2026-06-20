extends Control
class_name EnemyOriginModPanel
## v6.6: 敌源改造（D槽）装备面板
##
## 玩家在此面板为每张卡装备一个敌源MOD。
## D槽解锁条件：任意敌人的素材情报(material) ≥ GameConstants.ENEMY_ORIGIN_MOD_SLOT_UNLOCK_INTEL
##
## 数据流：
##   - 已解锁EOM列表、装备状态：EnemyOriginModManager
##   - 装备写入：BlueprintManager.blueprint_enemy_origin_mod[card_id]
##   - 战斗生效：battle_spawn_system._build_stats_cached → apply_eom_to_stats
##
## 使用方式：
##   var panel = EnemyOriginModPanel.create(popup_layer)
##   panel.open_for_card("u_inf_001")   # 可选：直接打开某张卡

const EnemyOriginMods = preload("res://data/enemy_origin_mods.gd")
const IntelDimensions = preload("res://data/intel_dimensions.gd")
const GC = preload("res://resources/game_constants.gd")

signal closed

var _parent_node: Node = null
var _selected_card_id: String = ""

# UI 引用
var _card_list_box: VBoxContainer = null
var _eom_list_box: VBoxContainer = null
var _detail_label: RichTextLabel = null
var _slot_status_label: Label = null

# ── 生命周期 ──────────────────────────────────────────────────────

static func create(parent: Node) -> EnemyOriginModPanel:
	var panel := EnemyOriginModPanel.new()
	panel._parent_node = parent
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(panel)
	return panel

func _ready() -> void:
	visible = true
	_build_ui()
	_refresh_card_list()
	_refresh_slot_status()

# ── 对外接口 ──────────────────────────────────────────────────────

## 直接打开某张卡的 EOM 配置
func open_for_card(card_id: String) -> void:
	_selected_card_id = card_id
	if is_inside_tree():
		_refresh_card_list(highlight=card_id)
		_refresh_eom_list()
		_refresh_slot_status()

# ── UI 构建 ────────────────────────────────────────────────────────

func _build_ui() -> void:
	# 暗色遮罩
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	# 中央面板
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(880, 560)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.04, 0.14, 0.98)
	panel_style.border_color = Color(0.55, 0.25, 0.85, 0.8)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.shadow_color = Color(0.5, 0.2, 0.9, 0.35)
	panel_style.shadow_size = 10
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(root_vbox)

	# 标题行
	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_FILL
	var title_lbl := Label.new()
	title_lbl.text = "⚙ 敌源改造 (D槽)"
	title_lbl.add_theme_font_size_override("font_size", 17)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.75, 1.0, 1.0))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_lbl)
	var close_btn := Button.new()
	close_btn.text = "✕ 关闭"
	close_btn.custom_minimum_size = Vector2(90, 30)
	var btn_style := _make_button_style()
	close_btn.add_theme_stylebox_override("normal", btn_style)
	close_btn.add_theme_color_override("font_color", Color(0.85, 0.75, 1.0, 1.0))
	close_btn.pressed.connect(_on_close)
	title_row.add_child(close_btn)
	root_vbox.add_child(title_row)

	# D槽状态提示
	_slot_status_label = Label.new()
	_slot_status_label.add_theme_font_size_override("font_size", 11)
	_slot_status_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.8, 1.0))
	_slot_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_vbox.add_child(_slot_status_label)

	# 主内容：左侧卡牌列表 + 右侧 EOM 列表/详情
	var content_hbox := HBoxContainer.new()
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hbox.add_theme_constant_override("separation", 12)
	root_vbox.add_child(content_hbox)

	# 左侧：卡牌列表
	var left_panel := _make_section("卡牌", 260)
	_card_list_box = left_panel["content"] as VBoxContainer
	content_hbox.add_child(left_panel["container"])

	# 右侧：EOM 列表
	var right_panel := _make_section("可装备的敌源改造", 320)
	_eom_list_box = right_panel["content"] as VBoxContainer
	content_hbox.add_child(right_panel["container"])

	# 详情区
	var detail_panel := _make_section("详情", 0)
	_detail_label = RichTextLabel.new()
	_detail_label.bbcode_enabled = true
	_detail_label.fit_content = true
	_detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_label.add_theme_font_size_override("font_size", 11)
	(detail_panel["content"] as VBoxContainer).add_child(_detail_label)
	detail_panel["container"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_hbox.add_child(detail_panel["container"])

func _make_section(title: String, width: float) -> Dictionary:
	var vbox := VBoxContainer.new()
	if width > 0:
		vbox.custom_minimum_size = Vector2(width, 0)
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	var header := Label.new()
	header.text = title
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", Color(0.8, 0.7, 0.95, 1.0))
	vbox.add_child(header)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 4)
	scroll.add_child(content)
	vbox.add_child(scroll)
	return {"container": vbox, "content": content}

func _make_button_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.28, 0.14, 0.46, 0.92)
	s.set_border_width_all(1)
	s.set_border_color(Color(0.6, 0.3, 0.9, 0.65))
	s.set_corner_radius_all(6)
	return s

# ── 数据刷新 ──────────────────────────────────────────────────────

## 刷新卡牌列表（玩家拥有的战斗卡）
func _refresh_card_list(highlight: String = "") -> void:
	if _card_list_box == null:
		return
	for child in _card_list_box.get_children():
		child.queue_free()

	var DefaultCards = preload("res://data/default_cards.gd")
	var card_ids: Array = []
	# 来源1：蓝图有副本的卡
	if BlueprintManager and BlueprintManager.has_method("get_all_blueprint_ids"):
		for id_raw in BlueprintManager.get_all_blueprint_ids():
			var card_id := String(id_raw)
			if not card_ids.has(card_id):
				card_ids.append(card_id)
	# 来源2：背包中的卡
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("get_pending_backpack_ids"):
		for idv in sm.get_pending_backpack_ids():
			var sid := String(idv)
			if not sid.is_empty() and not card_ids.has(sid):
				card_ids.append(sid)

	for card_id in card_ids:
		var card: CardResource = DefaultCards.get_card_by_id(card_id)
		if card == null:
			continue
		if card.card_type != GC.CardType.COMBAT_UNIT:
			continue
		_card_list_box.add_child(_make_card_button(card_id, card, highlight))

func _make_card_button(card_id: String, card: CardResource, highlight: String) -> Control:
	var btn := Button.new()
	btn.text = card.unit_name if card.unit_name != "" else card_id
	btn.custom_minimum_size = Vector2(0, 28)
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_stylebox_override("normal", _make_button_style())
	btn.add_theme_color_override("font_color", Color(0.85, 0.75, 1.0, 1.0))
	# 显示当前装备的 EOM 标记
	var eom_mgr := _get_eom_mgr()
	var equipped := ""
	if eom_mgr:
		equipped = eom_mgr.get_equipped_eom(card_id)
	if not equipped.is_empty():
		var mod := EnemyOriginMods.get_mod(equipped)
		btn.text += "  [" + String(mod.get("name", equipped)) + "]"
	if card_id == highlight or card_id == _selected_card_id:
		btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4, 1.0))
	btn.pressed.connect(_on_card_selected.bind(card_id))
	return btn

## 刷新右侧 EOM 列表（选中卡的可装备EOM）
func _refresh_eom_list() -> void:
	if _eom_list_box == null:
		return
	for child in _eom_list_box.get_children():
		child.queue_free()

	if _selected_card_id.is_empty():
		var hint := Label.new()
		hint.text = "← 请先选择一张卡牌"
		hint.add_theme_font_size_override("font_size", 11)
		hint.add_theme_color_override("font_color", Color(0.6, 0.55, 0.7, 1.0))
		_eom_list_box.add_child(hint)
		return

	var eom_mgr := _get_eom_mgr()
	if eom_mgr == null:
		_add_eom_hint("敌源改造系统未初始化")
		return

	# 卸载按钮（如果已装备）
	var equipped := eom_mgr.get_equipped_eom(_selected_card_id)
	if not equipped.is_empty():
		var unequip_btn := Button.new()
		unequip_btn.text = "🚫 卸载当前改造"
		unequip_btn.custom_minimum_size = Vector2(0, 30)
		var s := _make_button_style()
		s.bg_color = Color(0.5, 0.2, 0.2, 0.92)
		unequip_btn.add_theme_stylebox_override("normal", s)
		unequip_btn.add_theme_color_override("font_color", Color(1.0, 0.8, 0.8, 1.0))
		unequip_btn.pressed.connect(_on_unequip)
		_eom_list_box.add_child(unequip_btn)

	# D槽未解锁提示
	if not eom_mgr.is_slot_unlocked_for_card():
		_add_eom_hint("D槽未解锁\n需任意敌人的素材情报 ≥ %d%%" % [int(GC.ENEMY_ORIGIN_MOD_SLOT_UNLOCK_INTEL * 100)])
		return

	# 可装备的EOM列表
	var available: Array = eom_mgr.get_available_mods_for_card(_selected_card_id)
	if available.is_empty():
		_add_eom_hint("暂无可用改造\n通过战斗获取素材情报解锁更多敌源改造")
		return

	for mod in available:
		_eom_list_box.add_child(_make_eom_button(mod, equipped))

func _make_eom_button(mod: Dictionary, currently_equipped: String) -> Control:
	var mod_id := String(mod.get("id", ""))
	var tier := int(mod.get("_tier", 1))
	var btn := Button.new()
	btn.text = "%s  Lv%d" % [String(mod.get("name", mod_id)), tier]
	btn.custom_minimum_size = Vector2(0, 30)
	btn.add_theme_font_size_override("font_size", 11)
	var s := _make_button_style()
	if mod_id == currently_equipped:
		s.bg_color = Color(0.2, 0.45, 0.3, 0.92)
		btn.text += "  ✓"
	else:
		s.bg_color = Color(0.22, 0.18, 0.4, 0.92)
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_color_override("font_color", Color(0.9, 0.88, 1.0, 1.0))
	btn.pressed.connect(_on_eom_selected.bind(mod_id))
	# hover 显示详情
	btn.mouse_entered.connect(_show_detail.bind(mod_id))
	return btn

func _add_eom_hint(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.55, 0.7, 1.0))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_eom_list_box.add_child(lbl)

## 刷新顶部D槽解锁状态
func _refresh_slot_status() -> void:
	if _slot_status_label == null:
		return
	var eom_mgr := _get_eom_mgr()
	if eom_mgr == null:
		_slot_status_label.text = "敌源改造系统未初始化"
		return
	if eom_mgr.is_slot_unlocked_for_card():
		_slot_status_label.text = "✓ D槽已解锁"
		_slot_status_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.6, 1.0))
	else:
		_slot_status_label.text = "🔒 D槽未解锁：需任意敌人的素材情报 ≥ %d%%" % [int(GC.ENEMY_ORIGIN_MOD_SLOT_UNLOCK_INTEL * 100)]
		_slot_status_label.add_theme_color_override("font_color", Color(0.85, 0.7, 0.5, 1.0))

## 显示某个EOM的详情
func _show_detail(mod_id: String) -> void:
	if _detail_label == null or mod_id.is_empty():
		return
	var mod := EnemyOriginMods.get_mod(mod_id)
	if mod.is_empty():
		return
	var eom_mgr := _get_eom_mgr()
	var tier := 1
	if eom_mgr:
		tier = eom_mgr.get_effective_tier(mod_id)
	var effects := EnemyOriginMods.get_tier_effects(mod_id, tier)

	var bb := "[b][color=#c0a0e0]%s[/color][/b]\n" % String(mod.get("name", mod_id))
	bb += "[color=#9088a0]%s[/color]\n\n" % String(mod.get("desc", ""))
	bb += "[b]当前等级: Lv%d[/b]\n" % tier
	bb += "[color=#b0c8a0]%s[/color]\n" % _format_tier_desc(mod, tier)
	bb += "\n[color=#706880]敌源类型: %s[/color]" % String(mod.get("source_enemy_type", ""))
	bb += "\n[color=#9088a0]%s[/color]" % String(mod.get("flavor_text", ""))
	_detail_label.text = bb

func _format_tier_desc(mod: Dictionary, tier: int) -> String:
	var tiers: Array = mod.get("tiers", [])
	for t in tiers:
		if int(t.get("tier", 0)) == tier:
			return String(t.get("desc", ""))
	return ""

# ── 事件处理 ──────────────────────────────────────────────────────

func _on_card_selected(card_id: String) -> void:
	_selected_card_id = card_id
	_refresh_card_list(highlight=card_id)
	_refresh_eom_list()

func _on_eom_selected(mod_id: String) -> void:
	if _selected_card_id.is_empty():
		return
	var eom_mgr := _get_eom_mgr()
	if eom_mgr == null:
		return
	var ok := eom_mgr.equip_eom(_selected_card_id, mod_id)
	if ok:
		_refresh_card_list(highlight=_selected_card_id)
		_refresh_eom_list()
		# 装备后触发存档
		var sm := get_node_or_null("/root/SaveManager")
		if sm and sm.has_method("save_game"):
			sm.call_deferred("save_game")
	else:
		_show_detail(mod_id)  # 装备失败时至少刷新详情

func _on_unequip() -> void:
	if _selected_card_id.is_empty():
		return
	var eom_mgr := _get_eom_mgr()
	if eom_mgr == null:
		return
	eom_mgr.unequip_eom(_selected_card_id)
	_refresh_card_list(highlight=_selected_card_id)
	_refresh_eom_list()
	var sm := get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("save_game"):
		sm.call_deferred("save_game")

func _on_close() -> void:
	closed.emit()
	queue_free()

# ── 工具 ──────────────────────────────────────────────────────────

func _get_eom_mgr() -> Node:
	return get_node_or_null("/root/EnemyOriginModManager")
