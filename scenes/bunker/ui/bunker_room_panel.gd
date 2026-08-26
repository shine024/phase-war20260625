extends Control
## 余烬要塞 · 房间详情面板 v21 P1
## 点击房间（光点到达后）弹出：房间描述 + 状态相关操作。
##   废弃   → 修复成本 + [开始修复]（校验资源）
##   修复中 → 进度条 + 推进说明 + 反应堆冻结警示
##   可用   → 功能按钮：宿舍[睡觉推进天数] / 兵棋室[前往战场] / 其余 P2/P3 占位说明

signal close_requested
signal sleep_requested
signal go_to_battle_requested
signal repair_started(room_id: String)
signal panel_action_done                    # 面板内动作完成（治疗等）→ 主场景刷新 HUD/光点
signal open_embedded_panel_requested(panel_id: String)   # P2 面板迁移：宿舍=背包/工坊=改造进化成长/通讯=商店势力/食堂=AFK

const BunkerRoomDefs = preload("res://data/bunker_room_defs.gd")
const HeroArchiveTexts = preload("res://data/hero_archive_texts.gd")
const DT = preload("res://resources/design_tokens.gd")

var _def: Dictionary = {}
var _manager: Node = null
var _title_label: Label
var _state_chip: Label
var _flavor_label: RichTextLabel
var _action_box: VBoxContainer
var _close_btn: Button
var _dim: ColorRect
var _panel: PanelContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()

## manager = BunkerManager（bunker_main 注入）
func open_room(def: Dictionary, manager: Node) -> void:
	_def = def
	_manager = manager
	visible = true
	_rebuild_content()

func close() -> void:
	visible = false

func is_open() -> bool:
	return visible

## ───────────────────── 构建 ─────────────────────

func _build() -> void:
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0, 0, 0, 0.55)
	add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(640, 420)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.075, 0.09, 0.14, 0.98)
	sb.border_color = Color(0, 0.941, 1, 0.55)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(DT.CORNER_RADIUS)
	sb.set_content_margin_all(DT.PADDING_LARGE)
	_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(vbox)

	# 标题行
	var title_row := HBoxContainer.new()
	vbox.add_child(title_row)
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_TITLE - 8)
	_title_label.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(_title_label)
	_state_chip = Label.new()
	_state_chip.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	title_row.add_child(_state_chip)
	_close_btn = Button.new()
	_close_btn.text = "✕"
	_close_btn.pressed.connect(func(): close_requested.emit())
	title_row.add_child(_close_btn)

	# 描述
	_flavor_label = RichTextLabel.new()
	_flavor_label.bbcode_enabled = false
	_flavor_label.fit_content = true
	_flavor_label.custom_minimum_size = Vector2(0, 72)
	_flavor_label.add_theme_font_size_override("normal_font_size", DT.FONT_SIZE_BODY)
	_flavor_label.add_theme_color_override("default_color", DT.COLOR_TEXT_DIM)
	vbox.add_child(_flavor_label)

	# 动作区（随状态重建）
	_action_box = VBoxContainer.new()
	_action_box.add_theme_constant_override("separation", 10)
	_action_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_action_box)

## ───────────────────── 状态内容 ─────────────────────

func _rebuild_content() -> void:
	if _def.is_empty() or _manager == null:
		return
	var room_id := str(_def["id"])
	var state: int = _manager.get_room_state(room_id)
	var progress: float = _manager.get_room_progress(room_id)

	_title_label.text = str(_def.get("name", ""))
	_flavor_label.text = str(_def.get("flavor", ""))

	for child in _action_box.get_children():
		child.queue_free()

	match state:
		BunkerRoomDefs.STATE_LOCKED:
			_state_chip.text = "[废弃]"
			_state_chip.add_theme_color_override("font_color", Color(0.55, 0.5, 0.45))
			_build_locked_actions(room_id)
		BunkerRoomDefs.STATE_REPAIRING:
			_state_chip.text = "[修复中 %d%%]" % int(round(progress * 100.0))
			_state_chip.add_theme_color_override("font_color", Color(0.9, 0.6, 0.1))
			_build_repairing_actions(room_id, progress)
		_:
			_state_chip.text = "[已恢复供电]"
			_state_chip.add_theme_color_override("font_color", Color(0.3, 0.92, 0.5))
			_build_active_actions(room_id)

func _build_locked_actions(room_id: String) -> void:
	var cost: Dictionary = _def.get("cost", {})
	var battles: int = int(_def.get("battles", 0))
	var info := _make_info_label()
	if _def.get("is_terminal", false):
		# P3：观星台显示实时解锁条件
		var cond: Dictionary = _manager.is_observatory_unlockable()
		if cond.get("ok", false):
			info.text = "终局之门即将开启……（P4 开放）"
		else:
			var reasons: Array = cond.get("reasons", [])
			info.text = "终局之门。尚缺条件：\n· " + "\n· ".join(reasons) + "\n（P4 开放）"
		_action_box.add_child(info)
		return
	info.text = "修复需求：%s · 完成战斗 %d 场" % [
		(BunkerRoomDefs.cost_text(cost) if not cost.is_empty() else "免费"), battles]
	_action_box.add_child(info)

	# P3：荣誉陈列室碎片门槛提示
	if room_id == "honor_hall":
		var gate := _make_info_label()
		gate.text = "★ 另需英雄遗物 %d 份（当前 %d）——击败驻守相位师获取" % [
			10, _manager.get_hero_fragment_count()]
		gate.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))
		_action_box.add_child(gate)

	# 深层设施前置警示（需反应堆电力，未上线时提示）
	if bool(_def.get("needs_power", false)) and not _manager.is_reactor_online():
		var warn := _make_info_label()
		warn.text = "⚠ 深层设施：反应堆未上线时修复进度将被冻结，建议先点亮反应堆核心。"
		warn.add_theme_color_override("font_color", Color(0.9, 0.6, 0.1))
		_action_box.add_child(warn)

	var btn := Button.new()
	btn.text = "开始修复（%s）" % (BunkerRoomDefs.cost_text(cost) if not cost.is_empty() else "免费")
	btn.custom_minimum_size = Vector2(0, 44)
	btn.pressed.connect(func(): _on_repair_pressed(room_id))
	_action_box.add_child(btn)

func _on_repair_pressed(room_id: String) -> void:
	var result: Dictionary = _manager.start_repair(room_id)
	if result.get("ok", false):
		repair_started.emit(room_id)
		_rebuild_content()
	else:
		var warn := _make_info_label()
		warn.text = "✖ " + str(result.get("reason", "无法修复"))
		warn.add_theme_color_override("font_color", DT.COLOR_DANGER)
		_action_box.add_child(warn)

func _build_repairing_actions(room_id: String, progress: float) -> void:
	var info := _make_info_label()
	if _manager.is_repair_frozen(room_id):
		info.text = "进度冻结中：反应堆未上线。每完成一场战斗本应推进一格，现在被冻结。"
		info.add_theme_color_override("font_color", Color(0.9, 0.6, 0.1))
	else:
		info.text = "每完成一场战斗推进一格（%d 场后恢复供电）。" % [
			ceil((1.0 - progress) * max(1, int(_def.get("battles", 1))))]
	_action_box.add_child(info)

	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0, 0, 0, 0.5)
	bar_bg.custom_minimum_size = Vector2(0, 14)
	_action_box.add_child(bar_bg)
	var fill := ColorRect.new()
	fill.color = Color(0.9, 0.6, 0.1)
	fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	fill.anchor_right = clampf(progress, 0.0, 1.0)
	bar_bg.add_child(fill)

func _build_active_actions(room_id: String) -> void:
	var note := _make_info_label()
	note.text = str(_def.get("function_note", ""))
	_action_box.add_child(note)

	match room_id:
		"dormitory":
			var sleep_btn := Button.new()
			sleep_btn.text = "睡觉 —— 推进天数 · 精神 +20 · 存档"
			sleep_btn.custom_minimum_size = Vector2(0, 44)
			sleep_btn.pressed.connect(func(): sleep_requested.emit())
			_action_box.add_child(sleep_btn)
			var bp_btn := Button.new()
			bp_btn.text = "打开背包"
			bp_btn.custom_minimum_size = Vector2(0, 40)
			bp_btn.pressed.connect(func(): open_embedded_panel_requested.emit("backpack"))
			_action_box.add_child(bp_btn)
		"war_room":
			var go_btn := Button.new()
			go_btn.text = "前往战场（战区地图 · 选关出击）"
			go_btn.custom_minimum_size = Vector2(0, 44)
			go_btn.pressed.connect(func(): go_to_battle_requested.emit())
			_action_box.add_child(go_btn)
		"medical":
			var treat_btn := Button.new()
			treat_btn.text = "治疗 —— 消耗纳米 50 · 精神 +40（当前 %d）" % int(round(float(_manager.get_sanity())))
			treat_btn.custom_minimum_size = Vector2(0, 44)
			treat_btn.pressed.connect(_on_treat_pressed)
			_action_box.add_child(treat_btn)
		"workshop":
			_add_embedded_buttons([
				["改造", "modification"],
				["进化", "evolution"],
				["成长中枢", "growth"],
			])
		"comms":
			_add_embedded_buttons([
				["商店", "store"],
				["势力", "faction"],
			])
			# P3：预录来电（随碎片/反应堆进度变化）
			var call_lbl := _make_info_label()
			call_lbl.text = HeroArchiveTexts.comms_latest_call(
				_manager.get_hero_fragment_count(), _manager.is_reactor_online())
			call_lbl.add_theme_color_override("font_color", Color(0.62, 0.75, 0.85))
			_action_box.add_child(call_lbl)
		"mess_hall":
			var afk_btn := Button.new()
			afk_btn.text = "查看挂机收益（AFK）"
			afk_btn.custom_minimum_size = Vector2(0, 44)
			afk_btn.pressed.connect(func(): open_embedded_panel_requested.emit("afk"))
			_action_box.add_child(afk_btn)
		"archive":
			_add_embedded_buttons([
				["英雄档案", "hero_archive"],
				["情报中心", "intelligence"],
			])
		"honor_hall":
			_add_embedded_buttons([
				["纪念墙", "memorial"],
				["成就", "achievement"],
				["收藏图鉴", "collection"],
			])

## P2 面板迁移：一行生成多个嵌入面板按钮
func _add_embedded_buttons(entries: Array) -> void:
	for entry in entries:
		var btn := Button.new()
		btn.text = "打开" + str(entry[0])
		btn.custom_minimum_size = Vector2(0, 40)
		var panel_id: String = str(entry[1])
		btn.pressed.connect(func(): open_embedded_panel_requested.emit(panel_id))
		_action_box.add_child(btn)

func _on_treat_pressed() -> void:
	var result: Dictionary = _manager.medical_treatment()
	var lbl := _make_info_label()
	if result.get("ok", false):
		lbl.text = "✔ " + str(result.get("reason", ""))
		lbl.add_theme_color_override("font_color", DT.COLOR_GREEN_BRIGHT)
		panel_action_done.emit()
	else:
		lbl.text = "✖ " + str(result.get("reason", ""))
		lbl.add_theme_color_override("font_color", DT.COLOR_DANGER)
	_action_box.add_child(lbl)

func _make_info_label() -> Label:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_BODY)
	lbl.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(0, 22)
	return lbl

func _unhandled_input(event: InputEvent) -> void:
	# ESC 关闭面板
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_requested.emit()
		get_viewport().set_input_as_handled()
