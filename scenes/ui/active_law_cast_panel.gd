extends PanelContainer
## 战斗中显示已装备的主动法则，点击后进入选点模式，再点战场释放

const PhaseLaws = preload("res://data/phase_laws.gd")

func _active_law_ui_log(message: String, data: Dictionary, hypothesis_id: String) -> void:
	var DebugLog = get_node_or_null("/root/DebugLog")
	if DebugLog:
		DebugLog.agent_log("active_law_cast_panel.gd", message, data, hypothesis_id, "H3")

@onready var hint_label: Label = $Margin/VBox/HintLabel
@onready var button_container: VBoxContainer = $Margin/VBox/ButtonContainer

func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	if SignalBus:
		SignalBus.active_law_cast_at.connect(_on_cast_done)
	refresh_list()

func _on_visibility_changed() -> void:
	if visible:
		refresh_list()

func _on_cast_done(_law_id: String, _world_pos: Vector2) -> void:
	if SignalBus:
		BattleInputState.pending_cast_law_id = ""
	refresh_list()
	_update_hint()

func refresh_list() -> void:
	for c in button_container.get_children():
		c.queue_free()
	_update_hint()
	var plm := get_node_or_null("/root/PhaseLawManager")
	if not plm:
		_active_law_ui_log("refresh_list_no_plm", {}, "H3")
		return
	var actives: Array = plm.equipped_active_laws if "equipped_active_laws" in plm else []
	var states: Dictionary = plm.active_law_states if "active_law_states" in plm else {}
	_active_law_ui_log("refresh_list_before_buttons", {
		"active_count": actives.size(),
		"equipped_actives": actives,
	}, "H3")
	for law_id in actives:
		var cfg: Dictionary = PhaseLaws.get_by_id(String(law_id))
		if cfg.is_empty():
			continue
		var name_str: String = cfg.get("name", law_id)
		var cost: Dictionary = cfg.get("battle_cost", {})
		var energy: float = float(cost.get("energy", 0))
		var nano: int = int(cost.get("nano", 0))
		var used: int = 0
		var limit: int = 999999
		if states.has(law_id):
			used = int(states[law_id].get("casts_used", 0))
			limit = int(states[law_id].get("casts_limit", 999999))
		var btn := Button.new()
		var display_name: String = name_str
		if name_str.length() > 8:
			display_name = name_str.substr(0, 7) + "…"
		btn.text = "%s (%d/%d) · %d⚡" % [display_name, used, limit, int(energy)]
		if nano > 0:
			btn.text += " %d纳米" % nano
		btn.add_theme_font_size_override("font_size", 12)
		btn.clip_contents = true
		var rt: Dictionary = cfg.get("runtime_tags", {})
		var effect: String = String(rt.get("effect", ""))
		var value: float = float(rt.get("value", 0.0))
		var radius: float = float(rt.get("radius", 0.0))
		var duration: float = float(rt.get("duration", 0.0))
		var target_side: String = String(rt.get("target_side", "ENEMY"))
		var target_type: String = String(rt.get("target_type", "ALL"))
		var detail: String = _format_active_law_summary(effect, value, radius, duration)
		btn.tooltip_text = "%s\n%s\n作用阵营：%s，目标类型：%s" % [name_str, detail, target_side, target_type]
		var can_use := used < limit
		btn.disabled = not can_use
		if can_use:
			btn.pressed.connect(_on_law_pressed.bind(String(law_id)))
		button_container.add_child(btn)

func _on_law_pressed(law_id: String) -> void:
	# 与 Main._on_law_slot_clicked 保持一致：进入选点前先确保 PLM 已装配该主动法则
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
		# 进入施法选点时，必须清空待部署状态，避免点击被部署分支抢占
		BattleInputState.pending_deploy_platform_card_id = ""
		BattleInputState.pending_deploy_origin_global = Vector2.ZERO
		BattleInputState.pending_cast_law_id = law_id
	_update_hint()

func _update_hint() -> void:
	if hint_label == null:
		return
	if SignalBus and not BattleInputState.pending_cast_law_id.is_empty():
		var name_str := BattleInputState.pending_cast_law_id
		var plm := get_node_or_null("/root/PhaseLawManager")
		if plm:
			var cfg: Dictionary = PhaseLaws.get_by_id(BattleInputState.pending_cast_law_id)
			if not cfg.is_empty():
				name_str = cfg.get("name", name_str)
		hint_label.text = "点击战场选择释放位置：%s" % name_str
		hint_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	else:
		hint_label.text = "主动法则（点击施放）"
		hint_label.remove_theme_color_override("font_color")

func _format_active_law_summary(effect: String, value: float, radius: float, duration: float) -> String:
	match effect:
		"aoe_emp":
			return "EMP 伤害 %.1f；半径 %.0f；持续 %.1fs" % [value, radius, duration]
		"line_bombard":
			return "线性轰炸 %.1f 伤害；长度 %.0f" % [value, radius]
		"chain_lightning":
			return "链式放电总伤害 %.1f；半径 %.0f" % [value, radius]
		"burn_mark":
			return "灼烧 %.1f/秒；持续 %.1fs；半径 %.0f" % [value, duration, radius]
		"global_time_slow":
			return "全局时缓 %.0f%%；持续 %.1fs" % [value * 100.0, duration]
		"spawn_shield_wall":
			return "护盾墙减伤 %.0f%%；持续 %.1fs；半径 %.0f" % [value * 100.0, duration, radius]
		"hp_shield_shift":
			return "护盾转移 %.0f%%；持续 %.1fs；半径 %.0f" % [value * 100.0, duration, radius]
		"anchor_field":
			return "锚定减速 %.0f%%；持续 %.1fs；半径 %.0f" % [value * 100.0, duration, radius]
		"scorch_wave":
			return "灼浪 %.1f 伤害；半径 %.0f" % [value, radius]
		"ember_screen":
			return "灰烬护幕 %.0f%% 护盾；持续 %.1fs；半径 %.0f" % [value * 100.0, duration, radius]
		"core_rupture":
			return "核心破裂 %.1f 伤害；半径 %.0f" % [value, radius]
		"ion_net":
			return "离子网减速/减攻速 %.0f%%；持续 %.1fs；半径 %.0f" % [value * 100.0, duration, radius]
		"surge_drive":
			return "激涌驱动 +%.0f%%；持续 %.1fs" % [value * 100.0, duration]
		"static_domain":
			return "静电域 %.1f 伤害；持续 %.1fs；半径 %.0f" % [value, duration, radius]
		"phase_cloak":
			return "相位披幕 %.0f%% 护盾；持续 %.1fs；半径 %.0f" % [value * 100.0, duration, radius]
		"gravity_well":
			return "引力井束缚 %.0f%%；持续 %.1fs；半径 %.0f" % [value * 100.0, duration, radius]
		_:
			return "效果：%s（%.2f）" % [effect, value]
