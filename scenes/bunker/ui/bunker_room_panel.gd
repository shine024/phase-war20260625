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
const GOOD_COL := DT.COLOR_GREEN_BRIGHT

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
	_dim.color = DT.COLOR_BACKDROP
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
	_panel.add_theme_stylebox_override("panel", PanelStyles.make_panel_frame_textured(ACCENT))
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
			# 有升级档的房间显示等级；无升级档（纪念碑/观星台）保持"运转中"
			var lv: int = _manager.get_room_level(room_id)
			_set_chip(("运转中 Lv%d" % lv) if _manager.get_max_room_level(room_id) > 1 else "运转中",
				GOOD_COL)
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

	# v26.12：掏资源前先告诉玩家这房间修好了有什么用 + 之后能升到什么（不靠猜）
	var fn := str(_def.get("function_note", ""))
	if not fn.is_empty():
		var fnote := _make_info_label()
		fnote.text = "修复后：%s" % fn
		fnote.add_theme_color_override("font_color", DT.COLOR_TEXT_MID)
		_action_box.add_child(fnote)
	var ups_text := BunkerRoomDefs.upgrade_lines_preview(room_id)
	if not ups_text.is_empty():
		var ups_lbl := _make_info_label()
		ups_lbl.text = ups_text
		_action_box.add_child(ups_lbl)

	# P3：荣誉陈列室碎片门槛提示
	if room_id == "honor_hall":
		var gate := _make_info_label()
		gate.text = "★ 另需同伴遗物 %d 份（当前 %d）——击败驻守相位师获取" % [
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

	# v26.12：修复中也能看到"修好了有什么用"
	var fn := str(_def.get("function_note", ""))
	if not fn.is_empty():
		var fnote := _make_info_label()
		fnote.text = "修复后：%s" % fn
		fnote.add_theme_color_override("font_color", DT.COLOR_TEXT_MID)
		_action_box.add_child(fnote)

	# 圆角进度条（橙填充）+ 百分比角标
	_action_box.add_child(_make_progress_bar(progress))

	var pct := _make_info_label()
	pct.text = "施工进度 %d%% · 由出击推进" % int(round(progress * 100.0))
	pct.add_theme_color_override("font_color", WARN_COL)
	_action_box.add_child(pct)

	# v22.1：修复中的房间直接给出击入口——修复进度靠"完成战斗"推进，
	# 玩家正站在这间房里时不该再绕去别处找打仗入口。
	var battle_btn := _make_button("前往战场 —— 完成战斗推进修复", "solid",
		func(): go_to_battle_requested.emit(), 44)
	_action_box.add_child(battle_btn)

## 圆角进度条（橙填充 + 暗底描边），修复/升级进度共用
func _make_progress_bar(progress: float) -> Panel:
	var bar_bg := Panel.new()
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = DT.COLOR_BACKDROP
	bg_sb.border_color = Color(1, 1, 1, 0.08)
	bg_sb.set_border_width_all(1)
	bg_sb.set_corner_radius_all(4)
	bg_sb.set_content_margin_all(3.0)
	bar_bg.add_theme_stylebox_override("panel", bg_sb)
	bar_bg.custom_minimum_size = Vector2(0, 18)

	var fill := Panel.new()
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = Color(0.95, 0.62, 0.15)
	fill_sb.set_corner_radius_all(3)
	fill.add_theme_stylebox_override("panel", fill_sb)
	fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	fill.anchor_right = clampf(progress, 0.02, 1.0)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bg.add_child(fill)
	return bar_bg

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
			var sleep_btn := _make_button(
				"睡觉 —— 推进天数 · 精神 +%d · 存档" % int(round(_manager.get_sleep_recovery())),
				"solid", func(): sleep_requested.emit(), 44)
			_action_box.add_child(sleep_btn)
			_action_box.add_child(_make_button("打开背包",
				"ghost", func(): open_embedded_panel_requested.emit("backpack"), 40))
		"war_room":
			_action_box.add_child(_make_button("前往战场（战区地图 · 选关出击）",
				"solid", func(): go_to_battle_requested.emit(), 44))
			_action_box.add_child(_make_button("任务",
				"ghost", func(): open_embedded_panel_requested.emit("quest"), 40))
			_build_sandbox_section()
		"medical":
			_action_box.add_child(_make_button(
				"治疗 —— 消耗纳米 %d · 精神 +%d（当前 %d）" % [
					_manager.get_medical_cost(), int(round(_manager.get_medical_recovery())),
					int(round(float(_manager.get_sanity())))],
				"solid", _on_treat_pressed, 44))
		"workshop":
			_add_embedded_buttons([
				["改造", "modification"],
				["制造中心", "evolution"],  # v26：进化退役，id 保留（护栏），仅改显示文案
				["词条工坊（洗练）", "affix"],  # v26.11(A1.1)：词缀洗练/锁定/Boss 词条池
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
					"领取每日配给 —— %s（每天一次）" % BunkerRoomDefs.cost_text(_manager.get_daily_ration()),
					"solid", _on_ration_pressed, 44))
		"archive":
			_add_embedded_buttons([
				["同伴档案", "hero_archive"],
				["情报中心", "intelligence"],
			])
			_build_analyzer_section()
		"depot":
			_action_box.add_child(_make_button("打印卡牌 —— 纳米打印机 · 公司补给",
				"solid", func(): open_embedded_panel_requested.emit("store"), 44))
			# v26 批次3：仓库 Lv3 战利品打印机说明
			if _manager.is_loot_printer_online():
				var loot_note := _make_info_label()
				loot_note.text = "✔ 战利品打印机已上线（Lv3）——每天醒来自动打印 1 张随机缴获卡入包。"
				loot_note.add_theme_color_override("font_color", GOOD_COL)
				_action_box.add_child(loot_note)
		"weather_station":
			_build_weather_section()
			_build_expedition_section()
		"honor_hall":
			_action_box.add_child(_make_button("符文圣所 —— 装备符文 · 搭配符文之语",
				"solid", func(): open_embedded_panel_requested.emit("runes"), 44))
			_add_embedded_buttons([
				["纪念墙", "memorial"],
				["成就", "achievement"],
				["收藏图鉴", "collection"],
			])
			_build_salute_section()

	# 升级区（v26 批次1）：有升级档的房间在功能按钮之后追加
	_build_upgrade_section(room_id)

## ───────────────────── 档案室：分析仪（v26 批次3） ─────────────────────

func _build_analyzer_section() -> void:
	_action_box.add_child(_make_divider())
	var st: Dictionary = _manager.analyzer_state()
	if not bool(st.get("online", false)):
		var lock_note := _make_info_label()
		lock_note.text = "分析仪：需档案室 Lv2 上线（烧缴获卡换情报）。"
		_action_box.add_child(lock_note)
		return
	var slot: Dictionary = st.get("slot", {})
	var status_lbl := _make_info_label()
	if slot.is_empty():
		status_lbl.text = "分析仪：待机中（今日已出炉 %d/%d）。" % [
			int(st.get("baked_today", 0)), int(st.get("daily_limit", 3))]
	else:
		status_lbl.text = "分析仪：分析中「%s」（%s）· 还需 %d 场战斗 · 今日 %d/%d" % [
			str(slot.get("archetype_id", "?")), str(slot.get("rarity", "?")),
			int(slot.get("battles_left", 0)),
			int(st.get("baked_today", 0)), int(st.get("daily_limit", 3))]
	_action_box.add_child(status_lbl)
	var full := int(st.get("baked_today", 0)) >= int(st.get("daily_limit", 3))
	if not slot.is_empty() or full:
		var busy_note := _make_info_label()
		busy_note.text = "今天不能再放卡了。" if full else "等它出炉后才能放下一张。"
		_action_box.add_child(busy_note)
		return
	_action_box.add_child(_make_button("放入缴获卡 —— 烧毁换情报（品质越高产出越多）",
		"solid", _on_analyzer_pick_pressed, 44))

func _on_analyzer_pick_pressed() -> void:
	var picker_script := preload("res://scenes/bunker/ui/bunker_analyzer_picker.gd")
	var picker: Control = picker_script.new()
	picker.setup(_manager)
	add_child(picker)

## ───────────────────── 气象站：地表探索（v26 批次3） ─────────────────────

func _build_expedition_section() -> void:
	if not _manager.is_expedition_online():
		var lock_note := _make_info_label()
		lock_note.text = "地表探索：需气象站 Lv3 解锁（日 1 次派遣，带回资源或缴获卡）。"
		_action_box.add_child(lock_note)
		return
	if _manager.expedition_used_today():
		var done_note := _make_info_label()
		done_note.text = "✔ 侦察队今日已派出——明天再来。"
		done_note.add_theme_color_override("font_color", GOOD_COL)
		_action_box.add_child(done_note)
		return
	_action_box.add_child(_make_button(
		"派遣侦察队 —— 日 1 次 · 带回资源包（40% 缴获卡）",
		"solid", _on_expedition_pressed, 44))

func _on_expedition_pressed() -> void:
	var result: Dictionary = _manager.start_expedition()
	if SignalBus and SignalBus.has_signal("show_toast"):
		SignalBus.show_toast.emit(String(result.get("reason", "")))
	_rebuild_content()

## ───────────────────── 兵棋室：沙盘演武（v26 批次4，Lv3） ─────────────────────

func _build_sandbox_section() -> void:
	if not _manager.is_sandbox_online():
		return
	_action_box.add_child(_make_divider())
	var head := _make_info_label()
	head.text = "沙盘演武（Lv3）——未上阵卡后台吃 50% 经验"
	head.add_theme_color_override("font_color", Color(0.62, 0.75, 0.85))
	_action_box.add_child(head)
	var sb_id := String(_manager.get_sandbox_instance_id())
	if not sb_id.is_empty():
		var ir: Node = get_node_or_null("/root/InstanceRegistry")
		var inst: CardResource = ir.get_instance(sb_id) if ir != null and ir.has_method("get_instance") else null
		var cur := _make_info_label()
		if inst != null:
			cur.text = "在盘：「%s」（Lv.%d）" % [inst.display_name, int(inst.card_level) if "card_level" in inst else 1]
		else:
			cur.text = "在盘卡已不存在（沙盘已清空）"
			_manager.clear_sandbox_card()
		cur.add_theme_color_override("font_color", GOOD_COL)
		_action_box.add_child(cur)
		_action_box.add_child(_make_button("撤下沙盘卡", "ghost",
			func():
				_manager.clear_sandbox_card()
				_rebuild_content(), 36))
	_action_box.add_child(_make_button("设置沙盘卡 —— 选择一张未上阵的卡",
		"solid" if sb_id.is_empty() else "ghost", _on_sandbox_pick_pressed, 40))

func _on_sandbox_pick_pressed() -> void:
	var picker_script := preload("res://scenes/bunker/ui/bunker_sandbox_picker.gd")
	var picker: Control = picker_script.new()
	picker.setup(_manager)
	add_child(picker)

## ───────────────────── 荣誉室：出征仪式（v26 批次4，Lv3） ─────────────────────

func _build_salute_section() -> void:
	if not _manager.is_salute_online():
		return
	_action_box.add_child(_make_divider())
	if _manager.is_salute_armed():
		var armed_note := _make_info_label()
		armed_note.text = "✔ 仪式加成在身——下一场战斗掉落收益 +10%。"
		armed_note.add_theme_color_override("font_color", GOOD_COL)
		_action_box.add_child(armed_note)
		return
	if _manager.salute_used_today():
		var done_note := _make_info_label()
		done_note.text = "✔ 今日已敬礼——明天再来。"
		done_note.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
		_action_box.add_child(done_note)
		return
	_action_box.add_child(_make_button(
		"出征仪式 —— 日 1 次敬礼 · 下一场掉落收益 +10%",
		"solid", _on_salute_pressed, 44))

func _on_salute_pressed() -> void:
	var result: Dictionary = _manager.do_salute()
	if SignalBus and SignalBus.has_signal("show_toast"):
		SignalBus.show_toast.emit(String(result.get("reason", "")))
	_rebuild_content()

## ───────────────────── 气象站：天气预报（v26 批次4，Lv2） ─────────────────────

func _build_weather_section() -> void:
	if not _manager.is_forecast_online():
		return
	_action_box.add_child(_make_divider())
	var w: Dictionary = _manager.get_today_weather()
	if w.is_empty():
		return
	var head := _make_info_label()
	head.text = "今日预报：「%s」—— %s" % [str(w.get("name", "?")), str(w.get("desc", ""))]
	head.add_theme_color_override("font_color", Color(0.62, 0.75, 0.85))
	_action_box.add_child(head)
	var eff := _make_info_label()
	var parts: Array = []
	for key in ["hp_pct", "atk_pct", "def_pct"]:
		var v: float = float(w.get(key, 0.0))
		if absf(v) > 0.0001:
			parts.append("%s %+d%%" % [ {"hp_pct": "生命", "atk_pct": "攻击", "def_pct": "防御"}[key], int(round(v * 100.0))])
	eff.text = "效果（我方全队）：" + ("、".join(parts) if not parts.is_empty() else "无")
	_action_box.add_child(eff)
	if _manager.is_weather_armed():
		var armed_note := _make_info_label()
		armed_note.text = "✔ 预报已锁定——下一场战斗生效。"
		armed_note.add_theme_color_override("font_color", GOOD_COL)
		_action_box.add_child(armed_note)
	else:
		_action_box.add_child(_make_button("锁定预报 —— 下一场战斗生效（负面预报可不锁）",
			"solid", _on_lock_weather_pressed, 40))

func _on_lock_weather_pressed() -> void:
	var result: Dictionary = _manager.lock_weather()
	if SignalBus and SignalBus.has_signal("show_toast"):
		SignalBus.show_toast.emit(String(result.get("reason", "")))
	_rebuild_content()

## ───────────────────── 升级区（v26 批次1） ─────────────────────

## ACTIVE 房间的升级区：升级中→进度条+出击入口；满级→✔；否则→效果预览+升级按钮。
## 无升级档的房间（纪念碑/观星台）不渲染任何内容。
func _build_upgrade_section(room_id: String) -> void:
	if _manager.get_max_room_level(room_id) <= 1:
		return
	var level: int = _manager.get_room_level(room_id)
	_action_box.add_child(_make_divider())

	if _manager.is_upgrading(room_id):
		var info := _make_info_label()
		if _manager.is_repair_frozen(room_id):
			info.text = "升级进度冻结：反应堆未上线，上线后继续推进。"
			info.add_theme_color_override("font_color", WARN_COL)
		else:
			info.text = "升级到 Lv%d 施工中——每完成一场战斗推进一格（房间功能不受影响）。" % (level + 1)
		_action_box.add_child(info)
		var prog: float = _manager.get_upgrade_progress(room_id)
		_action_box.add_child(_make_progress_bar(prog))
		var pct := _make_info_label()
		pct.text = "升级进度 %d%% · 由出击推进" % int(round(prog * 100.0))
		pct.add_theme_color_override("font_color", WARN_COL)
		_action_box.add_child(pct)
		_action_box.add_child(_make_button("前往战场 —— 完成战斗推进升级", "solid",
			func(): go_to_battle_requested.emit(), 40))
		return

	if level >= _manager.get_max_room_level(room_id):
		var done := _make_info_label()
		done.text = "✔ 已满级 Lv%d" % level
		done.add_theme_color_override("font_color", GOOD_COL)
		_action_box.add_child(done)
		return

	var upg: Dictionary = _manager.get_next_upgrade(room_id)
	var cost: Dictionary = upg.get("cost", {})
	var preview := _make_info_label()
	preview.text = "升级到 Lv%d：%s\n需求：%s · 完成战斗 %d 场" % [
		level + 1, str(upg.get("note", "")),
		(BunkerRoomDefs.cost_text(cost) if not cost.is_empty() else "免费"),
		int(upg.get("battles", 1))]
	_action_box.add_child(preview)
	_action_box.add_child(_make_button(
		"开始升级 Lv%d（%s）" % [level + 1, BunkerRoomDefs.cost_text(cost)],
		"solid", func(): _on_upgrade_pressed(room_id), 40))

func _on_upgrade_pressed(room_id: String) -> void:
	var result: Dictionary = _manager.start_upgrade(room_id)
	if result.get("ok", false):
		panel_action_done.emit()   # 升级扣了资源 → HUD 资源栏刷新
		_rebuild_content()
	else:
		var lbl := _make_info_label()
		lbl.text = "✖ " + str(result.get("reason", "无法升级"))
		lbl.add_theme_color_override("font_color", DT.COLOR_DANGER)
		_action_box.add_child(lbl)

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
