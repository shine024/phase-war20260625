extends Control
## 余烬要塞 · 房间详情面板 v22 视觉升级
## 点击房间（光点到达后）弹出：房间描述 + 状态相关操作。
##   废弃   → 修复成本 + [开始修复]（校验资源）
##   修复中 → 进度条 + 推进说明 + 反应堆冻结警示
##   可用   → 功能按钮：宿舍[睡觉推进天数] / 兵棋室[前往战场] / 其余 P2/P3 占位说明
## v22：右侧锚定"检查员卡片"布局（确定性定位，任何窗口尺寸都不出屏）；
##       面板框架/按钮四态走 PanelStyles 工厂；引言块 + 状态芯片 + 圆角进度条。

signal close_requested
signal sleep_requested
signal go_to_battle_requested
signal repair_started(room_id: String)
signal panel_action_done                    # 面板内动作完成（治疗等）→ 主场景刷新 HUD/光点
signal open_embedded_panel_requested(panel_id: String)   # P2 面板迁移：宿舍=背包/工坊=改造进化成长/通讯=商店势力/食堂=AFK

const BunkerRoomDefs = preload("res://data/bunker_room_defs.gd")
const HeroArchiveTexts = preload("res://data/hero_archive_texts.gd")
const DT = preload("res://resources/design_tokens.gd")
const PanelStyles = preload("res://scripts/ui/panel_styles.gd")

## 面板语义色：暖琥珀（余烬要塞的灯色）为主 accent，警示沿用既有橙
const ACCENT := Color(1.0, 0.72, 0.32)
const WARN_COL := Color(0.95, 0.66, 0.18)
const GOOD_COL := Color(0.3, 0.92, 0.5)

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
	# ⚠️ 必须用 anchors_AND_offsets 版本：set_anchors_preset 在节点已入树时会
	# "保持当前可见矩形"（size=0 → 偏移被烘焙成 -宽/-高），全屏锚点被抵消，
	# 面板会缩在左上角（v22 之前"面板出屏"bug 的根因）。
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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

	# 右侧锚定卡片：右对齐 + 垂直居中 + 高度自适应内容（固定宽 400）。
	# 确定性定位——expand 画布/任意窗口尺寸下都不可能裁切出屏。
	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.alignment = BoxContainer.ALIGNMENT_END
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hbox)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_right", 24)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(margin)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(400, 0)
	_panel.add_theme_stylebox_override("panel", PanelStyles.make_panel_frame(ACCENT))
	margin.add_child(_panel)

	var inner := PanelContainer.new()
	var inner_sb := StyleBoxFlat.new()
	inner_sb.bg_color = Color(0.05, 0.06, 0.09, 0.92)
	inner_sb.set_corner_radius_all(10)
	inner_sb.set_content_margin_all(18.0)
	inner.add_theme_stylebox_override("panel", inner_sb)
	_panel.add_child(inner)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	inner.add_child(vbox)

	# 标题行：发光竖条 + 房名 + 状态芯片 + 关闭
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	vbox.add_child(title_row)

	var bar := Panel.new()
	bar.custom_minimum_size = Vector2(4, 0)
	bar.size_flags_vertical = Control.SIZE_FILL
	bar.add_theme_stylebox_override("panel", PanelStyles.make_title_accent_bar(ACCENT))
	title_row.add_child(bar)

	_title_label = Label.new()
	_title_label.text = ""
	_title_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_LARGE)
	_title_label.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(_title_label)

	_state_chip = Label.new()
	_state_chip.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	_state_chip.add_theme_color_override("font_color", ACCENT)
	var chip_sb := StyleBoxFlat.new()
	chip_sb.bg_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.12)
	chip_sb.border_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.45)
	chip_sb.set_border_width_all(1)
	chip_sb.set_corner_radius_all(4)
	chip_sb.content_margin_left = 8.0
	chip_sb.content_margin_right = 8.0
	chip_sb.content_margin_top = 3.0
	chip_sb.content_margin_bottom = 3.0
	_state_chip.add_theme_stylebox_override("normal", chip_sb)
	title_row.add_child(_state_chip)

	_close_btn = _make_button("✕", "ghost", func(): close_requested.emit(), 32)
	_close_btn.focus_mode = Control.FOCUS_NONE
	title_row.add_child(_close_btn)

	# 分隔线
	vbox.add_child(_make_divider())

	# 描述（引言块：左 accent 竖线的暗底引文）
	var quote := PanelContainer.new()
	var quote_sb := StyleBoxFlat.new()
	quote_sb.bg_color = Color(1, 1, 1, 0.04)
	quote_sb.border_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.35)
	quote_sb.border_width_left = 2
	quote_sb.set_corner_radius_all(4)
	quote_sb.content_margin_left = 12.0
	quote_sb.content_margin_right = 10.0
	quote_sb.content_margin_top = 8.0
	quote_sb.content_margin_bottom = 8.0
	quote.add_theme_stylebox_override("panel", quote_sb)
	vbox.add_child(quote)

	_flavor_label = RichTextLabel.new()
	_flavor_label.bbcode_enabled = false
	_flavor_label.fit_content = true
	_flavor_label.custom_minimum_size = Vector2(0, 56)
	_flavor_label.add_theme_font_size_override("normal_font_size", DT.FONT_SIZE_BODY)
	_flavor_label.add_theme_color_override("default_color", DT.COLOR_TEXT_MID)
	_flavor_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quote.add_child(_flavor_label)

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
			_set_chip("废弃", Color(0.72, 0.66, 0.58))
			_build_locked_actions(room_id)
		BunkerRoomDefs.STATE_REPAIRING:
			_set_chip("修复中 %d%%" % int(round(progress * 100.0)), WARN_COL)
			_build_repairing_actions(room_id, progress)
		_:
			_set_chip("运转中", GOOD_COL)
			_build_active_actions(room_id)

func _set_chip(text: String, col: Color) -> void:
	_state_chip.text = text
	_state_chip.add_theme_color_override("font_color", col)
	var sb: StyleBoxFlat = _state_chip.get_theme_stylebox("normal")
	sb.bg_color = Color(col.r, col.g, col.b, 0.12)
	sb.border_color = Color(col.r, col.g, col.b, 0.45)

func _build_locked_actions(room_id: String) -> void:
	var cost: Dictionary = _def.get("cost", {})
	var battles: int = int(_def.get("battles", 0))
	var info := _make_info_label()
	if _def.get("is_terminal", false):
		# 终局房间不占三态：芯片标"终局"，内容随解锁条件/抉择进度变化
		_set_chip("终局", ACCENT)
		var cond: Dictionary = _manager.is_observatory_unlockable()
		if not cond.get("ok", false):
			var reasons: Array = cond.get("reasons", [])
			info.text = "终局之门。尚缺条件：\n· " + "\n· ".join(reasons)
			_action_box.add_child(info)
			return
		# v22.3 P4：条件齐备 → 终局抉择入口（已抉择则显示徽记 + 重访）
		var chosen: Dictionary = _manager.get_chosen_ending()
		if not chosen.is_empty():
			info.text = "✔ %s（第 %d 天抵达）" % [chosen.get("emblem", ""), int(chosen.get("day", 0))]
			info.add_theme_color_override("font_color", GOOD_COL)
			_action_box.add_child(info)
			_action_box.add_child(_make_button("重访观星台 —— 回看结局",
				"ghost", func(): open_embedded_panel_requested.emit("observatory_ending"), 44))
		else:
			info.text = HeroArchiveTexts.OBSERVATORY_PROLOGUE
			info.add_theme_color_override("font_color", Color(0.78, 0.86, 0.98))
			_action_box.add_child(info)
			_action_box.add_child(_make_button("登上观星台 —— 终局抉择",
				"solid", func(): open_embedded_panel_requested.emit("observatory_ending"), 44))
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
		warn.add_theme_color_override("font_color", WARN_COL)
		_action_box.add_child(warn)

	var btn := _make_button(
		"开始修复（%s）" % (BunkerRoomDefs.cost_text(cost) if not cost.is_empty() else "免费"),
		"solid", func(): _on_repair_pressed(room_id), 44)
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
		info.add_theme_color_override("font_color", WARN_COL)
	else:
		info.text = "每完成一场战斗推进一格（%d 场后恢复供电）。" % [
			ceil((1.0 - progress) * max(1, int(_def.get("battles", 1))))]
	_action_box.add_child(info)

	# 圆角进度条（橙填充 + 百分比角标）
	var bar_bg := Panel.new()
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0, 0, 0, 0.55)
	bg_sb.border_color = Color(1, 1, 1, 0.08)
	bg_sb.set_border_width_all(1)
	bg_sb.set_corner_radius_all(4)
	bg_sb.set_content_margin_all(3.0)
	bar_bg.add_theme_stylebox_override("panel", bg_sb)
	bar_bg.custom_minimum_size = Vector2(0, 18)
	_action_box.add_child(bar_bg)

	var fill := Panel.new()
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = Color(0.95, 0.62, 0.15)
	fill_sb.set_corner_radius_all(3)
	fill.add_theme_stylebox_override("panel", fill_sb)
	fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	fill.anchor_right = clampf(progress, 0.02, 1.0)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bg.add_child(fill)

	var pct := _make_info_label()
	pct.text = "施工进度 %d%% · 由出击推进" % int(round(progress * 100.0))
	pct.add_theme_color_override("font_color", WARN_COL)
	_action_box.add_child(pct)

	# v22.1：修复中的房间直接给出击入口——修复进度靠"完成战斗"推进，
	# 玩家正站在这间房里时不该再绕去别处找打仗入口。
	var battle_btn := _make_button("前往战场 —— 完成战斗推进修复", "solid",
		func(): go_to_battle_requested.emit(), 44)
	_action_box.add_child(battle_btn)

func _build_active_actions(room_id: String) -> void:
	var note := _make_info_label()
	note.text = str(_def.get("function_note", ""))
	_action_box.add_child(note)

	match room_id:
		"entry_hall":
			_add_embedded_buttons([
				["设置", "settings"],
				["帮助", "help"],
			])
		"monument":
			_add_embedded_buttons([
				["纪念碑", "memorial"],
			])
		"phase_lab":
			_add_embedded_buttons([
				["相位师技能 · 电路板主板", "phase_master_skill"],
				["相位仪调试 · 装备槽", "instruments"],
			])
		"dormitory":
			var sleep_btn := _make_button("睡觉 —— 推进天数 · 精神 +20 · 存档",
				"solid", func(): sleep_requested.emit(), 44)
			_action_box.add_child(sleep_btn)
			_action_box.add_child(_make_button("打开背包",
				"ghost", func(): open_embedded_panel_requested.emit("backpack"), 40))
		"war_room":
			_action_box.add_child(_make_button("前往战场（战区地图 · 选关出击）",
				"solid", func(): go_to_battle_requested.emit(), 44))
			_action_box.add_child(_make_button("任务",
				"ghost", func(): open_embedded_panel_requested.emit("quest"), 40))
		"medical":
			_action_box.add_child(_make_button(
				"治疗 —— 消耗纳米 50 · 精神 +40（当前 %d）" % int(round(float(_manager.get_sanity()))),
				"solid", _on_treat_pressed, 44))
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
				["排行榜", "leaderboard"],
			])
			# P3：预录来电（随碎片/反应堆进度变化）
			var call_lbl := _make_info_label()
			call_lbl.text = HeroArchiveTexts.comms_latest_call(
				_manager.get_hero_fragment_count(), _manager.is_reactor_online())
			call_lbl.add_theme_color_override("font_color", Color(0.62, 0.75, 0.85))
			_action_box.add_child(call_lbl)
		"mess_hall":
			# v22.3：AFK 面板依赖 main.gd 注入的 AFKModeManager，在基地内永远是死键——
			# 换成每日配给（挂机收益入口留在战区主界面）。
			if _manager.is_ration_claimed_today():
				var claimed := _make_info_label()
				claimed.text = "✔ 今日配给已领取——明天再来。"
				claimed.add_theme_color_override("font_color", GOOD_COL)
				_action_box.add_child(claimed)
			else:
				_action_box.add_child(_make_button(
					"领取每日配给 —— 纳米 120 · 合金 40（每天一次）",
					"solid", _on_ration_pressed, 44))
		"archive":
			_add_embedded_buttons([
				["英雄档案", "hero_archive"],
				["情报中心", "intelligence"],
			])
		"depot":
			_action_box.add_child(_make_button("打印卡牌 —— 纳米打印机 · 公司补给",
				"solid", func(): open_embedded_panel_requested.emit("store"), 44))
		"honor_hall":
			_action_box.add_child(_make_button("符文圣所 —— 装备符文 · 搭配符文之语",
				"solid", func(): open_embedded_panel_requested.emit("runes"), 44))
			_add_embedded_buttons([
				["纪念墙", "memorial"],
				["成就", "achievement"],
				["收藏图鉴", "collection"],
			])

## P2 面板迁移：一行生成多个嵌入面板按钮
func _add_embedded_buttons(entries: Array) -> void:
	for entry in entries:
		var panel_id: String = str(entry[1])
		_action_box.add_child(_make_button("打开" + str(entry[0]),
			"ghost", func(): open_embedded_panel_requested.emit(panel_id), 40))

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

## v22.3：食堂每日配给（成功后刷新 HUD 资源）
func _on_ration_pressed() -> void:
	var result: Dictionary = _manager.claim_daily_ration()
	if result.get("ok", false):
		panel_action_done.emit()
		_rebuild_content()
	else:
		var lbl := _make_info_label()
		lbl.text = "✖ " + str(result.get("reason", ""))
		lbl.add_theme_color_override("font_color", DT.COLOR_DANGER)
		_action_box.add_child(lbl)

## ───────────────────── 控件工厂 ─────────────────────

## 统一按钮：PanelStyles 四态 + 手型光标 + 点击音效
func _make_button(text: String, kind: String, cb: Callable, height := 40) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, height)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var styles: Dictionary = PanelStyles.make_button_styles(ACCENT, kind)
	btn.add_theme_stylebox_override("normal", styles["normal"])
	btn.add_theme_stylebox_override("hover", styles["hover"])
	btn.add_theme_stylebox_override("pressed", styles["pressed"])
	btn.add_theme_stylebox_override("disabled", styles["disabled"])
	btn.add_theme_stylebox_override("focus", styles["focus"])
	btn.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
	btn.add_theme_color_override("font_hover_color", DT.COLOR_TEXT)
	btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_BODY)
	btn.pressed.connect(func():
		SignalBus.play_sound.emit("button")
		cb.call())
	return btn

func _make_info_label() -> Label:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_BODY)
	lbl.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # 跟随面板定宽 → autowrap 生效
	lbl.custom_minimum_size = Vector2(0, 22)
	return lbl

func _make_divider() -> ColorRect:
	var d := ColorRect.new()
	d.color = Color(1, 1, 1, 0.07)
	d.custom_minimum_size = Vector2(0, 1)
	return d

func _unhandled_input(event: InputEvent) -> void:
	# ESC 关闭面板
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_requested.emit()
		get_viewport().set_input_as_handled()
