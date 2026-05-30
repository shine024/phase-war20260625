extends PanelContainer
## 已装备的法则一览框，可拖动标题栏移动位置

const PhaseLaws = preload("res://data/phase_laws.gd")

@onready var title_bar: Control = $Margin/VBox/TitleBar
@onready var list_container: VBoxContainer = $Margin/VBox/ListContainer
@onready var toggle_button: Button = $Margin/VBox/TitleBar/ToggleButton

var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _collapsed: bool = true

func _ready() -> void:
	if title_bar:
		title_bar.gui_input.connect(_on_title_bar_gui_input)
	if toggle_button:
		toggle_button.pressed.connect(_on_toggle_pressed)
	_update_collapsed_state()
	refresh_list()

func _input(event: InputEvent) -> void:
	if not is_inside_tree():
		return
	if _dragging:
		if event is InputEventMouseMotion:
			var rel: Vector2 = event.relative
			offset_left += int(rel.x)
			offset_top += int(rel.y)
			offset_right += int(rel.x)
			offset_bottom += int(rel.y)
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_dragging = false

func _on_title_bar_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# 按在标题栏空白处拖动；按钮自身点击由 pressed 信号处理
		if event.pressed and toggle_button and toggle_button.get_global_rect().has_point(event.global_position):
			return
		if event.pressed:
			_dragging = true
			_drag_start = get_global_mouse_position() - global_position
		else:
			_dragging = false

func _on_toggle_pressed() -> void:
	_collapsed = not _collapsed
	_update_collapsed_state()

func _update_collapsed_state() -> void:
	if list_container:
		list_container.visible = not _collapsed
	if toggle_button:
		toggle_button.text = "▲" if not _collapsed else "▼"

func refresh_list() -> void:
	for c in list_container.get_children():
		c.queue_free()
	var plm := get_node_or_null("/root/PhaseLawManager")
	if not plm:
		return
	var equipped_passives: Array = plm.equipped_passive_laws if "equipped_passive_laws" in plm else []
	var equipped_actives: Array = plm.equipped_active_laws if "equipped_active_laws" in plm else []
	var all_laws: Array[String] = []
	all_laws.append_array(equipped_passives)
	all_laws.append_array(equipped_actives)
	if all_laws.is_empty():
		var empty_label := Label.new()
		empty_label.text = "（尚未装配任何法则）"
		empty_label.add_theme_font_size_override("font_size", 11)
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		list_container.add_child(empty_label)
		return
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 4)
	for law_id in all_laws:
		var cfg: Dictionary = PhaseLaws.get_by_id(String(law_id))
		if cfg.is_empty():
			continue
		var kind := String(cfg.get("kind", ""))
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(64, 64)
		slot.size_flags_horizontal = Control.SIZE_FILL
		slot.size_flags_vertical = Control.SIZE_FILL
		var style := StyleBoxFlat.new()
		if kind == "active":
			style.bg_color = Color(0.9, 0.85, 0.55, 0.9) # 浅黄
		else:
			style.bg_color = Color(0.55, 0.7, 0.9, 0.9)  # 浅蓝（默认视为被动）
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.15, 0.15, 0.2, 1)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_right = 4
		style.corner_radius_bottom_left = 4
		slot.add_theme_stylebox_override("panel", style)
		var name_str: String = cfg.get("name", law_id)
		var vb := VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		var label := Label.new()
		label.text = name_str
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(label)
		slot.add_child(vb)
		slot.tooltip_text = _build_law_detail(cfg)
		# 主动法则：允许在战斗中点击此格子进入“选点施法”模式
		if kind == "active":
			slot.mouse_filter = Control.MOUSE_FILTER_STOP
			# gui_input(event) -> 传入 (event, law_id)
			slot.gui_input.connect(Callable(self, "_on_active_slot_gui_input").bind(String(law_id)))
		row.add_child(slot)
	list_container.add_child(row)

func _on_active_slot_gui_input(event: InputEvent, law_id: String) -> void:
	# 记录所有进入回调的事件，便于确认连接是否成功
	var is_mouse := event is InputEventMouseButton
	var mouse_event := event as InputEventMouseButton if is_mouse else null
	var pressed := is_mouse and mouse_event.pressed
	var button := mouse_event.button_index if is_mouse else -1
	_war_magic_log("active_slot_gui_input", {
		"law_id": law_id,
		"is_mouse": is_mouse,
		"pressed": pressed,
		"button": button,
	}, "H_click")
	if not (is_mouse and pressed and button == MOUSE_BUTTON_LEFT):
		return
	var in_battle: bool = (BattleManager != null and "battle_active" in BattleManager and BattleManager.battle_active)
	_war_magic_log("active_slot_clicked", {
		"law_id": law_id,
		"in_battle": in_battle,
	}, "H_click")
	if not in_battle:
		return
	# 与 Main 入口一致：先同步再兜底补入，避免 can_cast 判定“未装配”
	var pim: Node = PhaseInstrumentManager
	if pim and pim.has_method("sync_law_cards_to_phase_law_manager"):
		pim.sync_law_cards_to_phase_law_manager()
	var plm: Node = get_node_or_null("/root/PhaseLawManager")
	if plm and "equipped_active_laws" in plm:
		var actives: Array = plm.equipped_active_laws
		if not actives.has(law_id):
			actives.append(String(law_id))
			plm.equipped_active_laws = actives
			if plm.has_method("ensure_law_unlocked"):
				plm.ensure_law_unlocked(String(law_id))
			if "active_law_states" in plm and not plm.active_law_states.has(law_id):
				plm.active_law_states[law_id] = {"casts_used": 0, "casts_limit": 999999}
	if SignalBus:
		# 与其他入口保持一致：施法优先，清理待部署状态
		BattleInputState.pending_deploy_platform_card_id = ""
		BattleInputState.pending_deploy_origin_global = Vector2.ZERO
		BattleInputState.pending_cast_law_id = String(law_id)

func _build_law_detail(cfg: Dictionary) -> String:
	var lines: Array[String] = []
	var name := String(cfg.get("name", ""))
	var family := String(cfg.get("family", ""))
	var kind := String(cfg.get("kind", ""))
	if not name.is_empty():
		lines.append(name)
	if not family.is_empty():
		lines.append("流派：%s" % family)
	if not kind.is_empty():
		var kind_text := "被动" if kind == "passive" else "主动"
		lines.append("类型：%s" % kind_text)
	var rt: Dictionary = cfg.get("runtime_tags", {})
	if not rt.is_empty():
		var effect: String = String(rt.get("effect", ""))
		var value: float = float(rt.get("value", 0.0))
		var duration: float = float(rt.get("duration", 0.0))
		var target_side: String = String(rt.get("target_side", "ALLY"))
		var target_type: String = String(rt.get("target_type", "ALL"))
		var effect_line := ""
		match effect:
			"armor_buff":
				effect_line = "效果：我方载具最大生命 +%d%%" % int(value * 100.0)
			"burn_on_hit":
				if duration > 0.0:
					effect_line = "效果：攻击命中时附带灼烧，每秒 %.1f，持续 %.1f 秒" % [value, duration]
				else:
					effect_line = "效果：攻击命中时附带灼烧伤害"
			_:
				effect_line = "效果：%s (数值 %.2f)" % [effect, value]
		if not effect_line.is_empty():
			lines.append(effect_line)
		lines.append("作用阵营：%s，目标类型：%s" % [target_side, target_type])
	return "\n".join(lines)
