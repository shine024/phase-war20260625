extends Control
class_name SynthesisPanel
## v6.6: 卡牌合成（混血卡）面板
##
## 玩家选择两张相同基础卡的势力变体，消耗资源合成混血卡。
## 合成条件：同 base_card_id、不同 faction_id、双方势力等级 > 0。
##
## 数据流：
##   - 可合成判定：SynthesisManager.can_synthesize
##   - 执行合成：SynthesisManager.synthesize（自动消耗资源 + 注册卡 + 入背包）
##   - 结果展示：本面板显示混血卡属性

const SynthesisRecipes = preload("res://data/synthesis_recipes.gd")
const GC = preload("res://resources/game_constants.gd")

signal closed

var _parent_node: Node = null
var _selected_a: String = ""
var _selected_b: String = ""

var _card_a_label: Label = null
var _card_b_label: Label = null
var _result_label: RichTextLabel = null
var _cost_label: Label = null
var _synth_btn: Button = null
var _card_list_box: VBoxContainer = null

static func create(parent: Node) -> SynthesisPanel:
	var panel := SynthesisPanel.new()
	panel._parent_node = parent
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(panel)
	return panel

func _ready() -> void:
	visible = true
	_build_ui()
	_refresh_card_list()
	_update_selection_display()

# ── UI 构建 ────────────────────────────────────────────────────────

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 520)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.12, 0.98)
	style.border_color = Color(0.3, 0.5, 0.75, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.2, 0.4, 0.7, 0.35)
	style.shadow_size = 10
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	# 标题行
	var title_row := HBoxContainer.new()
	var title := Label.new()
	title.text = "⚗ 卡牌合成（混血卡）"
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "✕ 关闭"
	close_btn.custom_minimum_size = Vector2(90, 30)
	close_btn.add_theme_stylebox_override("normal", _btn_style())
	close_btn.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0, 1.0))
	close_btn.pressed.connect(_on_close)
	title_row.add_child(close_btn)
	root.add_child(title_row)

	# 说明
	var hint := Label.new()
	hint.text = "选择两张相同基础卡、不同势力的变体，合成混血卡（融合双方势力加成）"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8, 1.0))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(hint)

	# 选中显示行
	var sel_row := HBoxContainer.new()
	sel_row.add_theme_constant_override("separation", 12)
	_card_a_label = _make_slot_label("卡牌 A: 未选择")
	_card_b_label = _make_slot_label("卡牌 B: 未选择")
	sel_row.add_child(_card_a_label)
	sel_row.add_child(_card_b_label)
	root.add_child(sel_row)

	# 主内容区
	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	root.add_child(content)

	# 左：卡牌列表
	var left_vbox := VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(280, 0)
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left_header := Label.new()
	left_header.text = "势力变体卡（点击选择 A/B）"
	left_header.add_theme_font_size_override("font_size", 12)
	left_header.add_theme_color_override("font_color", Color(0.75, 0.8, 0.95, 1.0))
	left_vbox.add_child(left_header)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_card_list_box = VBoxContainer.new()
	_card_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_list_box.add_theme_constant_override("separation", 4)
	scroll.add_child(_card_list_box)
	left_vbox.add_child(scroll)
	content.add_child(left_vbox)

	# 右：结果 + 费用 + 合成按钮
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 8)

	var cost_header := Label.new()
	cost_header.text = "合成费用"
	cost_header.add_theme_font_size_override("font_size", 13)
	cost_header.add_theme_color_override("font_color", Color(0.85, 0.78, 0.5, 1.0))
	right_vbox.add_child(cost_header)
	_cost_label = Label.new()
	_cost_label.add_theme_font_size_override("font_size", 11)
	_cost_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6, 1.0))
	_cost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_vbox.add_child(_cost_label)

	var result_header := Label.new()
	result_header.text = "合成结果预览"
	result_header.add_theme_font_size_override("font_size", 13)
	result_header.add_theme_color_override("font_color", Color(0.5, 0.9, 0.6, 1.0))
	right_vbox.add_child(result_header)
	_result_label = RichTextLabel.new()
	_result_label.bbcode_enabled = true
	_result_label.fit_content = true
	_result_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_result_label.add_theme_font_size_override("font_size", 11)
	right_vbox.add_child(_result_label)

	_synth_btn = Button.new()
	_synth_btn.text = "⚗ 合成"
	_synth_btn.custom_minimum_size = Vector2(0, 38)
	_synth_btn.add_theme_font_size_override("font_size", 13)
	var synth_style := _btn_style()
	synth_style.bg_color = Color(0.2, 0.4, 0.3, 0.92)
	_synth_btn.add_theme_stylebox_override("normal", synth_style)
	_synth_btn.add_theme_color_override("font_color", Color(0.85, 0.95, 0.85, 1.0))
	_synth_btn.disabled = true
	_synth_btn.pressed.connect(_on_synthesize)
	right_vbox.add_child(_synth_btn)
	content.add_child(right_vbox)

func _make_slot_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9, 1.0))
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl

func _btn_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.22, 0.3, 0.46, 0.92)
	s.set_border_width_all(1)
	s.set_border_color(Color(0.4, 0.55, 0.85, 0.65))
	s.set_corner_radius_all(6)
	return s

# ── 数据刷新 ──────────────────────────────────────────────────────

## 获取玩家拥有的、可作为合成原料的卡（基础卡 + 势力变体）
func _refresh_card_list() -> void:
	if _card_list_box == null:
		return
	for child in _card_list_box.get_children():
		child.queue_free()

	var DefaultCards = preload("res://data/default_cards.gd")
	var fsm: Node = get_node_or_null("/root/FactionSystemManager")
	var candidates: Array = []  # [{card_id, name, faction, base_id}]
	# 收集玩家拥有的卡
	# v7.x 修复（卡片重复）：背包存 instance_id（cold_t72#1），蓝图存裸 card_id（cold_t72），
	# 按完整字符串作 dict key 会视为两条。归一化到 base card_id 后合并。
	var _ir: Node = get_node_or_null("/root/InstanceRegistry")
	var _norm := func(raw_id: String) -> String:
		if _ir != null and _ir.has_method("get_card_id_of"):
			return _ir.get_card_id_of(raw_id)
		var hi: int = raw_id.rfind("#")
		return raw_id.substr(0, hi) if hi >= 0 else raw_id
	var card_ids: Dictionary = {}
	if BlueprintManager and BlueprintManager.has_method("get_all_blueprint_ids"):
		for id_raw in BlueprintManager.get_all_blueprint_ids():
			card_ids[String(id_raw)] = true
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("get_pending_backpack_ids"):
		for idv in sm.get_pending_backpack_ids():
			var sid := String(idv)
			if not sid.is_empty():
				card_ids[String(_norm.call(sid))] = true

	for card_id in card_ids:
		var card: CardResource = DefaultCards.get_card_by_id(card_id)
		if card == null:
			continue
		if card.card_type != GC.CardType.COMBAT_UNIT:
			continue
		# 确定势力
		var faction := ""
		if fsm and fsm.has_method("get_faction_variant_base_id"):
			var base_id: String = fsm.get_faction_variant_base_id(card_id)
			if not base_id.is_empty():
				faction = card.faction_id if "faction_id" in card else ""
				if faction.is_empty() and card.base_card_id == base_id:
					# 尝试从 card_id 解析（faction_base 格式）
					var prefix := card_id.substr(0, card_id.length() - base_id.length())
					if not prefix.is_empty():
						faction = prefix
		if faction.is_empty() and "faction_id" in card and not String(card.faction_id).is_empty():
			faction = String(card.faction_id)
		if faction.is_empty():
			continue  # 无势力的卡不能合成
		# 势力等级需 > 0
		if fsm and fsm.has_method("get_faction_level"):
			if fsm.get_faction_level(faction) <= 0:
				continue
		candidates.append({"card_id": card_id, "name": _card_name(card), "faction": faction, "base_id": _get_base(card_id, fsm)})

	for c in candidates:
		_card_list_box.add_child(_make_candidate_button(c))

func _card_name(card: CardResource) -> String:
	if card.display_name != null and String(card.display_name) != "":
		return String(card.display_name)
	return card.card_id

func _get_base(card_id: String, fsm: Node) -> String:
	if fsm and fsm.has_method("get_faction_variant_base_id"):
		var b: String = fsm.get_faction_variant_base_id(card_id)
		if not b.is_empty():
			return b
	return card_id

func _make_candidate_button(c: Dictionary) -> Control:
	var btn := Button.new()
	btn.text = "%s  [%s]" % [String(c["name"]), String(c["faction"])]
	btn.custom_minimum_size = Vector2(0, 28)
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_stylebox_override("normal", _btn_style())
	btn.add_theme_color_override("font_color", Color(0.85, 0.88, 1.0, 1.0))
	# 高亮已选中
	if c["card_id"] == _selected_a or c["card_id"] == _selected_b:
		btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4, 1.0))
	btn.pressed.connect(_on_candidate_selected.bind(String(c["card_id"]), String(c["name"]), String(c["faction"]), String(c["base_id"])))
	return btn

## 更新选中状态显示、费用、合成按钮可用性
func _update_selection_display() -> void:
	if _card_a_label == null:
		return
	var synth: Node = _get_synth_mgr()
	var DefaultCards = preload("res://data/default_cards.gd")
	_card_a_label.text = "A: " + (_card_name_by_id(_selected_a) if not _selected_a.is_empty() else "未选择")
	_card_b_label.text = "B: " + (_card_name_by_id(_selected_b) if not _selected_b.is_empty() else "未选择")

	if _selected_a.is_empty() or _selected_b.is_empty() or synth == null:
		_cost_label.text = "请选择两张卡牌"
		_result_label.text = ""
		_synth_btn.disabled = true
		return

	var check: Dictionary = synth.can_synthesize(_selected_a, _selected_b)
	if not check.get("ok", false):
		var reason_map := {
			"different_base": "两张卡基础不同，无法合成",
			"same_faction": "两张卡势力相同，无法合成",
			"already_exists": "该混血卡已合成过",
			"invalid_card": "无效卡牌",
			"not_variant": "卡牌无势力归属",
		}
		_cost_label.text = "❌ " + reason_map.get(check.get("reason", "unknown"), check.get("reason", ""))
		_result_label.text = ""
		_synth_btn.disabled = true
		return

	# 显示费用
	var cost: Dictionary = SynthesisRecipes.get_synthesis_cost(check["base_card_id"], check["faction_a"], check["faction_b"])
	_cost_label.text = "研究点 ×%d  纳米材料 ×%d  合成许可 ×%d" % [
		int(cost.get("research_points", 0)), int(cost.get("nanomaterial", 0)), int(cost.get("synthesis_permit", 0))
	]
	# 检查资源是否足够
	var brm: Node = get_node_or_null("/root/BasicResourceManager")
	var affordable := true
	if brm:
		affordable = brm.can_afford("research_points", int(cost.get("research_points", 0))) if brm.has_method("can_afford") else true
		if affordable:
			affordable = brm.can_afford("nano_materials", int(cost.get("nanomaterial", 0))) if brm.has_method("can_afford") else true
		if affordable and int(cost.get("synthesis_permit", 0)) > 0:
			affordable = brm.can_afford("synthesis_permit", int(cost.get("synthesis_permit", 0))) if brm.has_method("can_afford") else true
	_synth_btn.disabled = not affordable
	if not affordable:
		_cost_label.text += "\n⚠ 资源不足"

	# 显示混血卡预览
	var hybrid_preview: Dictionary = SynthesisRecipes.calculate_hybrid_bonus(
		check["base_card_id"], check["faction_a"], check["faction_b"],
		synth._get_faction_level(check["faction_a"]), synth._get_faction_level(check["faction_b"])
	)
	var bb := "[b][color=#a0c8a0]混血卡: %s[/color][/b]\n" % check["hybrid_id"]
	bb += "[color=#9088a0]融合势力: %s × %s[/color]\n\n" % [check["faction_a"], check["faction_b"]]
	bb += "[b]加成预览:[/b]\n"
	for key in hybrid_preview:
		var v = hybrid_preview[key]
		if v is float and float(v) != 0.0:
			bb += "  %s: %+.0f%%\n" % [key, float(v) * 100.0]
		elif v is int and int(v) != 0:
			bb += "  %s: %+d\n" % [key, int(v)]
	_result_label.text = bb

func _card_name_by_id(card_id: String) -> String:
	var DefaultCards = preload("res://data/default_cards.gd")
	var card: CardResource = DefaultCards.get_card_by_id(card_id)
	if card:
		return _card_name(card)
	return card_id

# ── 事件 ──────────────────────────────────────────────────────────

func _on_candidate_selected(card_id: String, _name: String, _faction: String, _base: String) -> void:
	# 先填 A，再填 B；如果重复选择则重置
	if card_id == _selected_a:
		_selected_a = ""
	elif card_id == _selected_b:
		_selected_b = ""
	elif _selected_a.is_empty():
		_selected_a = card_id
	elif _selected_b.is_empty():
		_selected_b = card_id
	else:
		# 都已选，替换 A
		_selected_a = card_id
		_selected_b = ""
	_refresh_card_list()
	_update_selection_display()

func _on_synthesize() -> void:
	var synth: Node = _get_synth_mgr()
	if synth == null:
		return
	var result: Dictionary = synth.synthesize(_selected_a, _selected_b)
	if result.get("ok", false):
		_selected_a = ""
		_selected_b = ""
		_refresh_card_list()
		_result_label.text = "[b][color=#50d050]✓ 合成成功！混血卡已加入背包[/color][/b]"
		_synth_btn.disabled = true
		# 存档
		var sm := get_node_or_null("/root/SaveManager")
		if sm and sm.has_method("save_game"):
			sm.call_deferred("save_game")
	else:
		_cost_label.text = "❌ 合成失败: %s" % result.get("reason", "unknown")

func _on_close() -> void:
	closed.emit()
	queue_free()

func _get_synth_mgr() -> Node:
	var fsm: Node = get_node_or_null("/root/FactionSystemManager")
	if fsm and fsm.has_method("get_synthesis_manager"):
		return fsm.get_synthesis_manager()
	return null
