extends PanelContainer
## 战前法则面板：展示可用法则、研究与装备状态（仅被动优先）

const PhaseLaws = preload("res://data/phase_laws.gd")

signal closed

@onready var env_label: Label = $Margin/VBox/EnvLabel
@onready var list_container: VBoxContainer = $Margin/VBox/ScrollContainer/LawList
@onready var close_btn: Button = $Margin/VBox/CloseButton
var _slots_refresh_pending: bool = false
var _plm: Node = null  ## 安全引用：PhaseLawManager 本地缓存
var _law_row_nodes: Dictionary = {}
## 每行法则面板（含未解锁），用于研究成功后局部替换，避免整表 queue_free
var _law_row_panels: Dictionary = {}

func _ready() -> void:
	close_btn.pressed.connect(_on_close)
	if SignalBus and SignalBus.has_signal("phase_slots_changed"):
		SignalBus.phase_slots_changed.connect(_on_phase_slots_changed)
	_refresh_env()
	_refresh_list()

# v6.2 修复 M12：断开信号，防止面板销毁后回调访问已释放节点
func _exit_tree() -> void:
	if SignalBus != null and SignalBus.has_signal("phase_slots_changed"):
		if SignalBus.phase_slots_changed.is_connected(_on_phase_slots_changed):
			SignalBus.phase_slots_changed.disconnect(_on_phase_slots_changed)

func _on_phase_slots_changed(_slots: Array) -> void:
	if _slots_refresh_pending:
		return
	_slots_refresh_pending = true
	call_deferred("_flush_slots_changed_refresh")

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree() and _slots_refresh_pending:
		call_deferred("_flush_slots_changed_refresh")

func _flush_slots_changed_refresh() -> void:
	if not _slots_refresh_pending:
		return
	if not is_visible_in_tree():
		return
	_slots_refresh_pending = false
	_refresh_rows_state_only()

func _on_close() -> void:
	closed.emit()

func _ensure_plm() -> void:
	if _plm != null and is_instance_valid(_plm):
		return
	_plm = get_node_or_null("/root/PhaseLawManager")

func _refresh_env() -> void:
	_ensure_plm()
	if not _plm or not _plm.has_method("get_current_env"):
		if env_label:
			env_label.text = "环境：未知"
		return
	var env: Dictionary = _plm.get_current_env()
	var parts: Array = []
	var weather := _env_value_label("weather", String(env.get("weather","?")))
	var terrain := _env_value_label("terrain", String(env.get("terrain","?")))
	var field := _env_value_label("energy_field", String(env.get("energy_field","?")))
	var tod := _env_value_label("time_of_day", String(env.get("time_of_day","?")))
	parts.append("☁ %s" % weather)
	parts.append("⛰ %s" % terrain)
	parts.append("⚡ %s" % field)
	parts.append("🕐 %s" % tod)
	if env_label:
		env_label.text = "  ".join(parts)

func _refresh_list() -> void:
	_law_row_nodes.clear()
	_law_row_panels.clear()
	for c in list_container.get_children():
		c.queue_free()
	_ensure_plm()
	if not _plm:
		return
	if not (_plm.has_method("get_all_law_status_for_current_env") and _plm.has_method("can_research_law") and _plm.has_method("research_law")):
		return
	var status_list: Array = _plm.get_all_law_status_for_current_env()
	status_list.sort_custom(func(a, b):
		return String(a.get("id","")) < String(b.get("id",""))
	)
	var equipped_passives: Array = _plm.equipped_passive_laws if "equipped_passive_laws" in _plm else []
	var equipped_actives: Array = _plm.equipped_active_laws if "equipped_active_laws" in _plm else []
	var passive_statuses: Array = []
	var active_statuses: Array = []
	var unlocked_count: int = 0
	var can_research_count: int = 0
	for s in status_list:
		if not s is Dictionary:
			continue
		if bool(s.get("unlocked", false)):
			unlocked_count += 1
		if bool(s.get("can_research", false)):
			can_research_count += 1
		var law_id_s: String = String(s.get("id", ""))
		if law_id_s.is_empty():
			continue
		var cfg_s: Dictionary = PhaseLaws.get_by_id(law_id_s)
		if cfg_s.is_empty():
			continue
		var kind_s: String = String(cfg_s.get("kind", ""))
		if kind_s == "passive":
			passive_statuses.append(s)
		elif kind_s == "active":
			active_statuses.append(s)
	# 主动法则区放在上方，便于看到新加的战争魔法
	if active_statuses.size() > 0:
		var active_label := Label.new()
		active_label.text = "⚔  主动法则（战争魔法）"
		active_label.add_theme_font_size_override("font_size", 13)
		active_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3, 1))
		list_container.add_child(active_label)
		for s in active_statuses:
			if not s is Dictionary:
				continue
			var law_id_a: String = String(s.get("id",""))
			if law_id_a.is_empty():
				continue
			var cfg_a: Dictionary = PhaseLaws.get_by_id(law_id_a)
			if cfg_a.is_empty():
				continue
			var row_a := _make_law_row(law_id_a, cfg_a, s, equipped_actives.has(law_id_a), true)
			list_container.add_child(row_a)
		# 分隔
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 12)
		list_container.add_child(spacer)
	# 被动法则区
	if passive_statuses.size() > 0:
		var passive_label := Label.new()
		passive_label.text = "🛡  被动法则"
		passive_label.add_theme_font_size_override("font_size", 13)
		passive_label.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0, 1))
		list_container.add_child(passive_label)
		for s in passive_statuses:
			if not s is Dictionary:
				continue
			var law_id: String = String(s.get("id",""))
			if law_id.is_empty():
				continue
			var cfg: Dictionary = PhaseLaws.get_by_id(law_id)
			if cfg.is_empty():
				continue
			var row := _make_law_row(law_id, cfg, s, equipped_passives.has(law_id))
			list_container.add_child(row)

func _refresh_rows_state_only() -> void:
	if _law_row_nodes.is_empty():
		_refresh_list()
		return
	_ensure_plm()
	if not _plm or not _plm.has_method("get_all_law_status_for_current_env"):
		return
	var status_by_id: Dictionary = {}
	for s in _plm.get_all_law_status_for_current_env():
		if s is Dictionary:
			var sid: String = String(s.get("id", ""))
			if not sid.is_empty():
				status_by_id[sid] = s
	var equipped_passives: Array = _plm.equipped_passive_laws if "equipped_passive_laws" in _plm else []
	var equipped_actives: Array = _plm.equipped_active_laws if "equipped_active_laws" in _plm else []
	for law_id in _law_row_nodes.keys():
		var row_info: Dictionary = _law_row_nodes[law_id]
		var panel: PanelContainer = row_info.get("panel")
		if panel == null or not is_instance_valid(panel):
			continue
		var title: Label = row_info.get("title")
		var env_hint: Label = row_info.get("env_hint")
		var slot_hint: Label = row_info.get("slot_hint")
		var is_active_law: bool = bool(row_info.get("is_active", false))
		var st: Dictionary = status_by_id.get(law_id, {})
		var unlocked: bool = bool(st.get("unlocked", false))
		var can_research: bool = bool(st.get("can_research", false))
		var env_ok: bool = bool(st.get("env_ok", false))
		var is_equipped: bool = equipped_actives.has(law_id) if is_active_law else equipped_passives.has(law_id)
		_apply_row_state_visual(panel, title, env_hint, slot_hint, unlocked, can_research, env_ok, is_equipped, is_active_law)

func _make_law_row(law_id: String, cfg: Dictionary, st: Dictionary, is_equipped: bool, is_active_law: bool = false) -> Control:
	_ensure_plm()
	var env_ok: bool = bool(st.get("env_ok", false))
	var unlocked: bool = bool(st.get("unlocked", false))
	var can_research: bool = bool(st.get("can_research", false))
	# 状态边框颜色
	var border_color: Color
	var bg_color: Color
	if is_equipped:
		if is_active_law:
			border_color = Color(1.0, 0.85, 0.2, 0.7)
			bg_color     = Color(0.1, 0.08, 0.02, 0.9)
		else:
			border_color = Color(0.3, 0.9, 0.55, 0.65)
			bg_color     = Color(0.04, 0.1, 0.06, 0.9)
	elif unlocked:
		border_color = Color(0.35, 0.55, 0.85, 0.5)
		bg_color     = Color(0.04, 0.07, 0.13, 0.85)
	elif can_research:
		border_color = Color(0.6, 0.6, 0.3, 0.5)
		bg_color     = Color(0.08, 0.08, 0.04, 0.85)
	else:
		border_color = Color(0.25, 0.28, 0.35, 0.35)
		bg_color     = Color(0.04, 0.05, 0.08, 0.75)
	var panel := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = bg_color
	ps.border_color = border_color
	ps.border_width_left = 2
	ps.border_width_top = 1
	ps.border_width_right = 1
	ps.border_width_bottom = 1
	ps.corner_radius_top_left = 4
	ps.corner_radius_top_right = 4
	ps.corner_radius_bottom_right = 4
	ps.corner_radius_bottom_left = 4
	panel.add_theme_stylebox_override("panel", ps)
	var mg := MarginContainer.new()
	mg.add_theme_constant_override("margin_left", 10)
	mg.add_theme_constant_override("margin_right", 8)
	mg.add_theme_constant_override("margin_top", 6)
	mg.add_theme_constant_override("margin_bottom", 6)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	# 左侧文字区
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	var family_str: String = cfg.get("family", "")
	var family_suffix: String = "（%s）" % family_str if not family_str.is_empty() else ""
	title.text = "%s%s" % [cfg.get("name", law_id), family_suffix]
	title.add_theme_font_size_override("font_size", 13)
	var title_color: Color
	if is_equipped and is_active_law:
		title_color = Color(1.0, 0.9, 0.35, 1)
	elif is_equipped:
		title_color = Color(0.4, 1.0, 0.65, 1)
	elif unlocked:
		title_color = Color(0.75, 0.85, 1.0, 1)
	else:
		title_color = Color(0.55, 0.58, 0.65, 0.8)
	title.add_theme_color_override("font_color", title_color)
	v.add_child(title)
	# 短描述
	var desc_text := _build_short_desc(cfg)
	if not desc_text.is_empty():
		var desc := Label.new()
		desc.text = desc_text
		desc.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75, 0.8))
		desc.add_theme_font_size_override("font_size", 11)
		v.add_child(desc)
	# 知识值需求（未解锁时）
	if not unlocked and _plm:
		var req: Dictionary = cfg.get("research_req", {})
		for k in _plm.KNOWLEDGE_KEYS:
			if not req.has(k):
				continue
			var need: int = int(req[k])
			var have: int = _plm.get_knowledge(k) if _plm.has_method("get_knowledge") else 0
			var kn_label := Label.new()
			kn_label.text = "%s: %d/%d" % [_knowledge_short_label(k), have, need]
			var kn_color: Color = Color(0.3, 0.9, 0.5, 1) if have >= need else Color(0.6, 0.65, 0.75, 0.8)
			kn_label.add_theme_color_override("font_color", kn_color)
			kn_label.add_theme_font_size_override("font_size", 10)
			v.add_child(kn_label)
	# 环境适配提示（预创建，后续仅切换可见性，避免频繁增删节点）
	var env_hint: Label = null
	if unlocked:
		env_hint = Label.new()
		env_hint.text = "⚠ 当前环境不满足"
		env_hint.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2, 0.75))
		env_hint.add_theme_font_size_override("font_size", 10)
		env_hint.visible = not env_ok
		v.add_child(env_hint)
	row.add_child(v)
	# tooltip
	var detail_text := _build_detail_desc(cfg)
	panel.tooltip_text = detail_text
	# 右侧按钮
	var slot_hint: Label = null
	if not unlocked:
		# v7.x: 法则系统已废弃（red/blue 槽改用符文槽），研究按钮永久禁用避免玩家白耗知识。
		# 原 btn.disabled = not can_research 会让玩家点了"研究"消耗知识却发现法则无法装备使用。
		var btn := Button.new()
		btn.text = "研究"
		btn.custom_minimum_size = Vector2(72, 30)
		btn.add_theme_font_size_override("font_size", 12)
		btn.disabled = true  # 法则废弃，禁用研究
		btn.tooltip_text = "法则系统已废弃，请使用符文系统（迁移中）"
		btn.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5, 0.6))
		row.add_child(btn)
	else:
		slot_hint = Label.new()
		slot_hint.custom_minimum_size = Vector2(120, 0)
		if is_equipped:
			# v6.2 修复 M13：法则系统已废弃（red/blue 槽改用 rune 符文槽），修正误导文案
			slot_hint.text = "已装配\n（法则系统已废弃\n请迁移至符文）"
			slot_hint.add_theme_color_override("font_color", Color(0.95, 0.75, 0.3, 0.95))
		else:
			slot_hint.text = "法则系统已废弃\n请使用符文系统"
			slot_hint.add_theme_color_override("font_color", Color(0.55, 0.72, 0.88, 0.9))
		slot_hint.add_theme_font_size_override("font_size", 10)
		slot_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(slot_hint)
	mg.add_child(row)
	panel.add_child(mg)
	_law_row_panels[law_id] = panel
	if unlocked:
		_law_row_nodes[law_id] = {
			"panel": panel,
			"title": title,
			"env_hint": env_hint,
			"slot_hint": slot_hint,
			"is_active": is_active_law,
		}
	return panel


func _refresh_law_row_after_research(law_id: String) -> void:
	var old_panel: PanelContainer = _law_row_panels.get(law_id) as PanelContainer
	if old_panel == null or not is_instance_valid(old_panel):
		_refresh_list()
		return
	var insert_idx: int = old_panel.get_index()
	list_container.remove_child(old_panel)
	old_panel.queue_free()
	_law_row_nodes.erase(law_id)
	_law_row_panels.erase(law_id)

	_ensure_plm()
	if not _plm or not _plm.has_method("get_all_law_status_for_current_env"):
		_refresh_list()
		return
	var st_found: Dictionary = {}
	for s in _plm.get_all_law_status_for_current_env():
		if s is Dictionary and String(s.get("id", "")) == law_id:
			st_found = s
			break
	if st_found.is_empty():
		_refresh_list()
		return
	var cfg: Dictionary = PhaseLaws.get_by_id(law_id)
	if cfg.is_empty():
		_refresh_list()
		return
	var passive_ids: Array = _plm.equipped_passive_laws if "equipped_passive_laws" in _plm else []
	var active_ids: Array = _plm.equipped_active_laws if "equipped_active_laws" in _plm else []
	var is_active_kind: bool = String(cfg.get("kind", "")) == "active"
	var is_equipped: bool = active_ids.has(law_id) if is_active_kind else passive_ids.has(law_id)
	var new_row := _make_law_row(law_id, cfg, st_found, is_equipped, is_active_kind)
	list_container.add_child(new_row)
	list_container.move_child(new_row, mini(insert_idx, list_container.get_child_count() - 1))

func _apply_row_state_visual(panel: PanelContainer, title: Label, env_hint: Label, slot_hint: Label, unlocked: bool, can_research: bool, env_ok: bool, is_equipped: bool, is_active_law: bool) -> void:
	var border_color: Color
	var bg_color: Color
	if is_equipped:
		if is_active_law:
			border_color = Color(1.0, 0.85, 0.2, 0.7)
			bg_color = Color(0.1, 0.08, 0.02, 0.9)
		else:
			border_color = Color(0.3, 0.9, 0.55, 0.65)
			bg_color = Color(0.04, 0.1, 0.06, 0.9)
	elif unlocked:
		border_color = Color(0.35, 0.55, 0.85, 0.5)
		bg_color = Color(0.04, 0.07, 0.13, 0.85)
	elif can_research:
		border_color = Color(0.6, 0.6, 0.3, 0.5)
		bg_color = Color(0.08, 0.08, 0.04, 0.85)
	else:
		border_color = Color(0.25, 0.28, 0.35, 0.35)
		bg_color = Color(0.04, 0.05, 0.08, 0.75)

	var ps: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
	if ps:
		ps.border_color = border_color
		ps.bg_color = bg_color

	if title:
		var title_color: Color
		if is_equipped and is_active_law:
			title_color = Color(1.0, 0.9, 0.35, 1)
		elif is_equipped:
			title_color = Color(0.4, 1.0, 0.65, 1)
		elif unlocked:
			title_color = Color(0.75, 0.85, 1.0, 1)
		else:
			title_color = Color(0.55, 0.58, 0.65, 0.8)
		title.add_theme_color_override("font_color", title_color)

	if env_hint:
		env_hint.visible = unlocked and not env_ok

	if slot_hint:
		if is_equipped:
			slot_hint.text = "已装配\n（相位仪槽）"
			slot_hint.add_theme_color_override("font_color", Color(0.45, 0.95, 0.65, 0.95))
		else:
			slot_hint.text = "法则系统已废弃\n请使用符文系统"
			slot_hint.add_theme_color_override("font_color", Color(0.55, 0.72, 0.88, 0.9))

func _build_short_desc(cfg: Dictionary) -> String:
	var rt: Dictionary = cfg.get("runtime_tags", {})
	var effect: String = String(rt.get("effect",""))
	var value: float = float(rt.get("value",0.0))
	var duration: float = float(rt.get("duration", 0.0))
	var radius: float = float(rt.get("radius", 0.0))
	match effect:
		"armor_buff", "aegis_link", "fortify_protocol", "resonant_plate":
			return "被动：最大生命 +%d%%" % int(value * 100.0)
		"afterburn", "entropy_lens":
			return "被动：伤害 +%d%%" % int(value * 100.0)
		"arc_beacon":
			return "被动：攻速 +%d%%" % int(value * 100.0)
		"regen_out_of_combat":
			return "被动：脱战回复 %.1f/秒" % value
		"burn_on_hit":
			return "被动：受击伤害提高（系数 +%.0f%%）" % (value * 5.0)
		"aoe_emp":
			return "主动：EMP %.1f伤害，半径%.0f，持续%.1fs" % [value, radius, duration]
		"line_bombard":
			return "主动：线性轰炸 %.1f伤害，长度%.0f" % [value, radius]
		"chain_lightning":
			return "主动：链式放电 %.1f总伤害，半径%.0f" % [value, radius]
		"burn_mark":
			return "主动：灼烧 %.1f/秒，%.1fs，半径%.0f" % [value, duration, radius]
		"global_time_slow":
			return "主动：全局时缓 %.0f%%，持续%.1fs" % [value * 100.0, duration]
		"spawn_shield_wall":
			return "主动：护盾墙减伤 %.0f%%，持续%.1fs，半径%.0f" % [value * 100.0, duration, radius]
		"hp_shield_shift":
			return "主动：护盾转移 %.0f%%，持续%.1fs，半径%.0f" % [value * 100.0, duration, radius]
		"anchor_field":
			return "主动：锚定减速 %.0f%%，持续%.1fs，半径%.0f" % [value * 100.0, duration, radius]
		"scorch_wave":
			return "主动：灼浪 %.1f伤害，半径%.0f" % [value, radius]
		"ember_screen":
			return "主动：灰烬护幕 %.0f%%护盾，持续%.1fs，半径%.0f" % [value * 100.0, duration, radius]
		"core_rupture":
			return "主动：核心破裂 %.1f伤害，半径%.0f" % [value, radius]
		"ion_net":
			return "主动：离子网减速 %.0f%%，持续%.1fs，半径%.0f" % [value * 100.0, duration, radius]
		"surge_drive":
			return "主动：激涌驱动 +%.0f%%，持续%.1fs" % [value * 100.0, duration]
		"static_domain":
			return "主动：静电域 %.1f伤害，持续%.1fs，半径%.0f" % [value, duration, radius]
		"phase_cloak":
			return "主动：相位披幕 %.0f%%护盾，持续%.1fs，半径%.0f" % [value * 100.0, duration, radius]
		"gravity_well":
			return "主动：引力井 %.0f%%束缚，持续%.1fs，半径%.0f" % [value * 100.0, duration, radius]
		_:
			return "效果：%s (%.2f)" % [effect, value]

func _build_detail_desc(cfg: Dictionary) -> String:
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
			"aegis_link":
				effect_line = "效果：我方载具最大生命 +%d%%（护阵联结）" % int(value * 100.0)
			"fortify_protocol":
				effect_line = "效果：我方单位最大生命 +%d%%（固壁协议）" % int(value * 100.0)
			"resonant_plate":
				effect_line = "效果：我方载具最大生命 +%d%%（共振装甲）" % int(value * 100.0)
			"burn_on_hit":
				if duration > 0.0:
					effect_line = "效果：攻击命中时附带灼烧，每秒 %.1f，持续 %.1f 秒" % [value, duration]
				else:
					effect_line = "效果：攻击命中时附带灼烧伤害"
			"regen_out_of_combat":
				effect_line = "效果：脱战后每秒回复 %.1f 生命" % value
			"afterburn":
				effect_line = "效果：我方单位伤害 +%d%%" % int(value * 100.0)
			"entropy_lens":
				effect_line = "效果：我方单位伤害 +%d%%（熵镜）" % int(value * 100.0)
			"arc_beacon":
				effect_line = "效果：我方单位攻速提升（约 +%d%%）" % int(value * 100.0)
			"aoe_emp":
				effect_line = "效果：范围 EMP 造成 %.1f 伤害，半径 %.0f，持续 %.1f 秒" % [value, float(rt.get("radius", 0.0)), duration]
			"line_bombard":
				effect_line = "效果：线性轰炸造成 %.1f 伤害，轰炸长度 %.0f" % [value, float(rt.get("radius", 0.0))]
			"chain_lightning":
				effect_line = "效果：链式放电总伤害 %.1f，半径 %.0f（在目标间分摊）" % [value, float(rt.get("radius", 0.0))]
			"burn_mark":
				effect_line = "效果：灼烧印记每秒 %.1f，持续 %.1f 秒，半径 %.0f" % [value, duration, float(rt.get("radius", 0.0))]
			"global_time_slow":
				effect_line = "效果：全局时缓 %.0f%%，持续 %.1f 秒" % [value * 100.0, duration]
			"spawn_shield_wall":
				effect_line = "效果：生成护盾墙，范围减伤 %.0f%%，持续 %.1f 秒，半径 %.0f" % [value * 100.0, duration, float(rt.get("radius", 0.0))]
			"hp_shield_shift":
				effect_line = "效果：范围护盾转移 %.0f%%，持续 %.1f 秒，半径 %.0f" % [value * 100.0, duration, float(rt.get("radius", 0.0))]
			"anchor_field":
				effect_line = "效果：锚定力场减速 %.0f%%，持续 %.1f 秒，半径 %.0f" % [value * 100.0, duration, float(rt.get("radius", 0.0))]
			"scorch_wave":
				effect_line = "效果：范围灼浪即时伤害 %.1f，半径 %.0f" % [value, float(rt.get("radius", 0.0))]
			"ember_screen":
				effect_line = "效果：灰烬幕障提供 %.0f%% 护盾，持续 %.1f 秒，半径 %.0f" % [value * 100.0, duration, float(rt.get("radius", 0.0))]
			"core_rupture":
				effect_line = "效果：核心破裂造成 %.1f 高伤害，半径 %.0f" % [value, float(rt.get("radius", 0.0))]
			"ion_net":
				effect_line = "效果：离子网减速/减攻速 %.0f%%，持续 %.1f 秒，半径 %.0f" % [value * 100.0, duration, float(rt.get("radius", 0.0))]
			"surge_drive":
				effect_line = "效果：友军速度/攻速 +%.0f%%，持续 %.1f 秒" % [value * 100.0, duration]
			"static_domain":
				effect_line = "效果：静电域造成 %.1f 伤害并减攻速，持续 %.1f 秒，半径 %.0f" % [value, duration, float(rt.get("radius", 0.0))]
			"phase_cloak":
				effect_line = "效果：相位披幕提供 %.0f%% 护盾，持续 %.1f 秒，半径 %.0f" % [value * 100.0, duration, float(rt.get("radius", 0.0))]
			"gravity_well":
				effect_line = "效果：引力井束缚 %.0f%% 并附加伤害，持续 %.1f 秒，半径 %.0f" % [value * 100.0, duration, float(rt.get("radius", 0.0))]
			_:
				effect_line = "效果：%s (数值 %.2f)" % [effect, value]
		if not effect_line.is_empty():
			lines.append(effect_line)
		lines.append("作用阵营：%s，目标类型：%s" % [target_side, target_type])
	var env_req: Dictionary = cfg.get("env_req", {})
	if not env_req.is_empty():
		var env_parts: Array[String] = []
		if env_req.has("weather"):
			env_parts.append("天气 ∈ %s" % _join_env_values("weather", env_req["weather"]))
		if env_req.has("terrain"):
			env_parts.append("地形 ∈ %s" % _join_env_values("terrain", env_req["terrain"]))
		if env_req.has("energy_field"):
			env_parts.append("能量场 ∈ %s" % _join_env_values("energy_field", env_req["energy_field"]))
		if env_req.has("time_of_day"):
			env_parts.append("时间 ∈ %s" % _join_env_values("time_of_day", env_req["time_of_day"]))
		if env_parts.size() > 0:
			lines.append("环境需求：" + "；".join(env_parts))
	var cost: Dictionary = cfg.get("activate_cost", {})
	if not cost.is_empty():
		var nano_cost: int = int(cost.get("nano", 0))
		if nano_cost > 0:
			lines.append("战前纳米消耗：%d" % nano_cost)
	var battle_cost: Dictionary = cfg.get("battle_cost", {})
	if not battle_cost.is_empty():
		var energy_cost: float = float(battle_cost.get("energy", 0.0))
		var nano_cast: int = int(battle_cost.get("nano", 0))
		var cost_parts: Array[String] = []
		if energy_cost > 0.0:
			cost_parts.append("能量 %d" % int(energy_cost))
		if nano_cast > 0:
			cost_parts.append("纳米 %d" % nano_cast)
		if cost_parts.size() > 0:
			lines.append("战中施放消耗：" + "，".join(cost_parts))
	var cond: Dictionary = cfg.get("cast_conditions", {})
	if not cond.is_empty():
		var cond_parts: Array[String] = []
		if cond.has("min_friendly_units"):
			cond_parts.append("友军数 ≥ %d" % int(cond.get("min_friendly_units", 0)))
		if cond.has("max_cast_per_battle"):
			cond_parts.append("单局最多施放 %d 次" % int(cond.get("max_cast_per_battle", 0)))
		if cond_parts.size() > 0:
			lines.append("施放条件：" + "，".join(cond_parts))
	return "\n".join(lines)

func _env_value_label(env_key: String, raw: String) -> String:
	var maps: Dictionary = {
		"weather": {
			"clear": "晴朗",
			"rain": "降雨",
			"storm": "风暴",
			"fog": "迷雾",
		},
		"terrain": {
			"plain": "平原",
			"city": "城市",
			"mountain": "山地",
			"forest": "森林",
		},
		"energy_field": {
			"normal": "常规场",
			"high_field": "高能场",
			"nano_fog": "纳米雾",
			"void_rift": "虚空裂隙",
		},
		"time_of_day": {
			"day": "白天",
			"dusk": "黄昏",
			"night": "夜晚",
		},
	}
	var group: Dictionary = maps.get(env_key, {})
	if group.has(raw):
		return String(group[raw])
	return raw

func _join_env_values(env_key: String, values: Array) -> String:
	var out: Array[String] = []
	for v in values:
		out.append(_env_value_label(env_key, String(v)))
	return ", ".join(out)

func _knowledge_short_label(key: String) -> String:
	match key:
		"defense_knowledge":
			return "防御知识"
		"energy_knowledge":
			return "能量知识"
		"mobility_knowledge":
			return "机动知识"
		"mystic_knowledge":
			return "神秘知识"
		_:
			return key
