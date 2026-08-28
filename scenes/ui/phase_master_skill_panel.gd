extends PanelContainer
## ═══════════════════════════════════════════════════════════
##  相位师技能树面板（v8.x 新增，v9 重设计，v22 电路板重设计）
##
##  v22 方案3：Tab+列表 → 单板三轨电路板 + 底部探针详情栏。
##    主板（phase_master_skill_board.gd）：74 芯片 / 3 轨 / 16 层 /
##    走线通电可视化，跨系前置（奇点门关）全板可见。
##    探针栏：点选芯片 → 详情 + 「通电」按钮，失败原因点名。
##  保留：PanelChrome 外壳 / 去抖刷新 / 状态签名 / 音效 / Toast /
##    已解锁总览（改为弹层）/ growth_panel 入口契约（closed/_refresh/visible）
## ═══════════════════════════════════════════════════════════

const SkillTree = preload("res://data/phase_master_skill_tree.gd")
const UnlockLabels = preload("res://data/unlock_labels.gd")
const DT = preload("res://resources/design_tokens.gd")
const PanelStyles = preload("res://scripts/ui/panel_styles.gd")
const PanelChrome = preload("res://scenes/ui/components/panel_chrome.gd")
const SkillBoard = preload("res://scenes/ui/phase_master_skill_board.gd")

signal closed()

var _points_label: Label = null
var _board: SkillBoard = null
var _board_scroll: ScrollContainer = null
var _selected_id: String = ""
# ── 探针栏部件 ──
var _preview_chip: SkillBoard.ChipWidget = null
var _probe_name: Label = null
var _probe_meta: Label = null
var _probe_desc: Label = null
var _probe_unlock: Label = null
var _probe_req: Label = null
var _probe_action_label: Label = null
var _probe_action_btn: Button = null
# ── 总览弹层 ──
var _summary_overlay: PanelContainer = null
var _summary_container: ScrollContainer = null
# ── v9 perf: 去抖 + 状态签名（保留原机制）──
var _dirty: bool = false
var _refresh_queued: bool = false
var _rendered_sig: String = ""

## 管理器统一入口（--script 模式 autoload 不初始化，取 null 走断路态渲染）
func _mgr() -> Node:
	return get_node_or_null("/root/PhaseMasterSkillManager")


func _ready() -> void:
	custom_minimum_size = DT.PANEL_SIZE_MEDIUM
	anchors_preset = Control.PRESET_CENTER
	size = DT.PANEL_SIZE_MEDIUM
	add_theme_stylebox_override("panel", PanelStyles.make_panel_frame(DT.get_panel_accent("phase_master_skill")))
	_build_ui()
	var mgr := _mgr()
	if mgr != null:
		if not mgr.node_unlocked.is_connected(_on_node_unlocked):
			mgr.node_unlocked.connect(_on_node_unlocked)
		if not mgr.points_changed.is_connected(_on_points_changed):
			mgr.points_changed.connect(_on_points_changed)
	visibility_changed.connect(_on_visibility_changed)
	_refresh()


func _build_ui() -> void:
	var main_vb := VBoxContainer.new()
	main_vb.name = "MainVBox"
	main_vb.add_theme_constant_override("separation", 6)
	add_child(main_vb)

	# —— 外壳标题栏 ——
	var chrome = PanelChrome.attach_to(main_vb, "相位师技能树", DT.get_panel_accent("phase_master_skill"), "CIRCUIT BOARD")
	chrome.closed.connect(_on_close_pressed)

	# —— 状态行：技能点 + 总览入口 ——
	var status_hb := HBoxContainer.new()
	status_hb.add_theme_constant_override("separation", 8)
	main_vb.add_child(status_hb)
	_points_label = Label.new()
	_points_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	_points_label.add_theme_color_override("font_color", DT.COLOR_TEXT_MID)
	status_hb.add_child(_points_label)
	status_hb.add_child(_make_spacer(true))
	# ⚡ 下一个：跳转到下一个可通电芯片（16 层滚动导航）
	var next_btn := Button.new()
	next_btn.text = "⚡ 下一个"
	next_btn.tooltip_text = "跳转到下一个可通电的芯片；若仅缺点数会跳到最接近的芯片并提示"
	next_btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	next_btn.add_theme_color_override("font_color", DT.COLOR_GOLD)
	next_btn.add_theme_color_override("font_hover_color", DT.COLOR_GOLD)
	next_btn.add_theme_color_override("font_pressed_color", DT.COLOR_GOLD)
	next_btn.add_theme_color_override("font_focus_color", DT.COLOR_GOLD)
	var nb_styles := PanelStyles.make_button_styles(DT.COLOR_GOLD, "ghost")
	next_btn.add_theme_stylebox_override("normal", nb_styles["normal"])
	next_btn.add_theme_stylebox_override("hover", nb_styles["hover"])
	next_btn.add_theme_stylebox_override("pressed", nb_styles["pressed"])
	next_btn.add_theme_stylebox_override("disabled", nb_styles["disabled"])
	next_btn.add_theme_stylebox_override("focus", nb_styles["focus"])
	next_btn.pressed.connect(_on_next_node_pressed)
	status_hb.add_child(next_btn)
	var overview_btn := Button.new()
	overview_btn.text = "📋 总览"
	overview_btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	overview_btn.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
	overview_btn.add_theme_color_override("font_hover_color", DT.COLOR_TEXT_BRIGHT)
	overview_btn.add_theme_color_override("font_pressed_color", DT.COLOR_TEXT_BRIGHT)
	overview_btn.add_theme_color_override("font_focus_color", DT.COLOR_TEXT_BRIGHT)
	var ob_styles := PanelStyles.make_button_styles(DT.get_panel_accent("phase_master_skill"), "ghost")
	overview_btn.add_theme_stylebox_override("normal", ob_styles["normal"])
	overview_btn.add_theme_stylebox_override("hover", ob_styles["hover"])
	overview_btn.add_theme_stylebox_override("pressed", ob_styles["pressed"])
	overview_btn.add_theme_stylebox_override("disabled", ob_styles["disabled"])
	overview_btn.add_theme_stylebox_override("focus", ob_styles["focus"])
	overview_btn.pressed.connect(_toggle_summary)
	status_hb.add_child(overview_btn)

	# —— 轨道标题行（与主板轨道列对齐，固定吸顶不随滚动）——
	var lane_bar := HBoxContainer.new()
	lane_bar.add_theme_constant_override("separation", 0)
	main_vb.add_child(lane_bar)
	var ruler_spacer := Control.new()
	ruler_spacer.custom_minimum_size = Vector2(SkillBoard.MARGIN_L + SkillBoard.RULER_W, 0)
	lane_bar.add_child(ruler_spacer)
	for lane_idx in SkillBoard.LANE_ORDER.size():
		var branch: String = String(SkillBoard.LANE_ORDER[lane_idx])
		var lane_title := Label.new()
		lane_title.text = "▎%s %s" % [SkillTree.get_branch_display_name(branch),
				["COMMAND", "INTEL", "FIRE"][lane_idx]]
		lane_title.custom_minimum_size = Vector2(SkillBoard.LANE_W, 0)
		lane_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lane_title.add_theme_font_size_override("font_size", DT.FONT_SIZE_BODY)
		lane_title.add_theme_color_override("font_color", SkillTree.get_branch_color(branch))
		lane_bar.add_child(lane_title)
		if lane_idx < SkillBoard.LANE_ORDER.size() - 1:
			var gap_spacer := Control.new()
			gap_spacer.custom_minimum_size = Vector2(SkillBoard.LANE_GAP, 0)
			lane_bar.add_child(gap_spacer)

	# —— 主板（纵向滚动）——
	var scroll := ScrollContainer.new()
	scroll.name = "BoardScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vb.add_child(scroll)
	_board_scroll = scroll
	_board = SkillBoard.new()
	scroll.add_child(_board)
	_board.chip_clicked.connect(_on_chip_selected)

	# —— 探针详情栏 ——
	main_vb.add_child(_build_probe_bar())


func _build_probe_bar() -> Control:
	var probe := PanelContainer.new()
	probe.name = "ProbeBar"
	probe.custom_minimum_size = Vector2(0, 112)
	probe.add_theme_stylebox_override("panel", PanelStyles.make_panel_frame(DT.get_panel_accent("phase_master_skill")))

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	probe.add_child(hb)

	# 左：芯片预览（与主板芯片同渲染器）
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(SkillBoard.CHIP + 14, 80)
	hb.add_child(holder)
	_preview_chip = SkillBoard.ChipWidget.new()
	holder.add_child(_preview_chip)
	_preview_chip.set_interactive(false)

	# 中：详情
	var info_vb := VBoxContainer.new()
	info_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vb.add_theme_constant_override("separation", 2)
	hb.add_child(info_vb)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	info_vb.add_child(name_row)
	_probe_name = Label.new()
	_probe_name.add_theme_font_size_override("font_size", DT.FONT_SIZE_MEDIUM)
	name_row.add_child(_probe_name)
	_probe_meta = Label.new()
	_probe_meta.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	_probe_meta.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
	_probe_meta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(_probe_meta)

	_probe_desc = Label.new()
	_probe_desc.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	_probe_desc.add_theme_color_override("font_color", DT.COLOR_TEXT_MID)
	_probe_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_probe_desc.custom_minimum_size = Vector2(0, 32)
	info_vb.add_child(_probe_desc)

	_probe_unlock = Label.new()
	_probe_unlock.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	_probe_unlock.add_theme_color_override("font_color", DT.COLOR_VIOLET)
	info_vb.add_child(_probe_unlock)

	_probe_req = Label.new()
	_probe_req.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	info_vb.add_child(_probe_req)

	# 右：状态 / 通电按钮
	var action_vb := VBoxContainer.new()
	action_vb.custom_minimum_size = Vector2(150, 0)
	action_vb.add_theme_constant_override("separation", 6)
	action_vb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(action_vb)

	_probe_action_label = Label.new()
	_probe_action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_probe_action_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_BODY)
	action_vb.add_child(_probe_action_label)

	_probe_action_btn = Button.new()
	_probe_action_btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	_probe_action_btn.add_theme_color_override("font_color", DT.COLOR_VOID)
	_probe_action_btn.add_theme_color_override("font_hover_color", DT.COLOR_VOID)
	_probe_action_btn.add_theme_color_override("font_pressed_color", DT.COLOR_VOID)
	_probe_action_btn.add_theme_color_override("font_focus_color", DT.COLOR_VOID)
	var ub_styles := PanelStyles.make_button_styles(DT.COLOR_GOLD, "solid")
	_probe_action_btn.add_theme_stylebox_override("normal", ub_styles["normal"])
	_probe_action_btn.add_theme_stylebox_override("hover", ub_styles["hover"])
	_probe_action_btn.add_theme_stylebox_override("pressed", ub_styles["pressed"])
	_probe_action_btn.add_theme_stylebox_override("disabled", ub_styles["disabled"])
	_probe_action_btn.add_theme_stylebox_override("focus", ub_styles["focus"])
	_probe_action_btn.pressed.connect(_on_action_pressed)
	action_vb.add_child(_probe_action_btn)

	return probe


# ─────────────────────────────────────────────
#  选中与探针栏
# ─────────────────────────────────────────────

func _on_chip_selected(node_id: String) -> void:
	_selected_id = node_id
	_board.select(node_id)
	if SignalBus and SignalBus.has_signal("play_sound"):
		SignalBus.play_sound.emit("button")
	_update_probe()


func _update_probe() -> void:
	var mgr := _mgr()
	if _selected_id == "" or not SkillTree.get_skill(_selected_id).has("id"):
		# 默认态：图例 + 进度
		_probe_name.text = "相位师技能主板"
		_probe_name.add_theme_color_override("font_color", DT.get_panel_accent("phase_master_skill"))
		var unlocked_n: int = _board.count_unlocked(mgr)
		var avail: int = mgr.get_available_points() if mgr != null else 0
		_probe_meta.text = "已解锁 %d/%d · 可用技能点 %d" % [unlocked_n, _board.get_chip_count(), avail]
		_probe_desc.text = "点击芯片查看详情 · 悬停有说明 · 滚轮纵览 16 层电路"
		_probe_unlock.text = "通电态：分支色亮框=已通电 · 金色夹脚=可通电 · 暗芯断路=未解锁"
		_probe_unlock.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
		_probe_req.text = "器件式：方片=数值 · 八角=机制/能力 · 双列=战法 · 圆罐=卡片技能 · 双框=进化 · 紫色◈=奇点"
		_probe_req.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
		_preview_chip.visible = false
		_probe_action_label.visible = false
		_probe_action_btn.visible = false
		return

	var node: Dictionary = SkillTree.get_skill(_selected_id)
	var is_cap: bool = bool(node.get("capstone", false))
	var accent: Color = SkillTree.CAPSTONE_COLOR if is_cap \
			else SkillTree.get_branch_color(String(node.get("branch", "")))
	var cost := int(node.get("cost", 1))

	var powered: bool = mgr != null and mgr.is_unlocked(_selected_id)
	var can := false
	var missing_req := false
	if not powered and mgr != null:
		var can_dict: Dictionary = mgr.can_unlock_node(_selected_id)
		can = bool(can_dict.get("ok", false))
		missing_req = String(can_dict.get("reason", "")) == "requires_not_met"

	_preview_chip.visible = true
	_preview_chip.setup(node, accent)
	_preview_chip.apply_state(
			SkillBoard.ChipState.POWERED if powered
			else SkillBoard.ChipState.STANDBY if can
			else SkillBoard.ChipState.LOCKED)

	_probe_name.text = ("◈ " if is_cap else "") + String(node.get("name", ""))
	_probe_name.add_theme_color_override("font_color", accent if powered or is_cap else DT.COLOR_TEXT_BRIGHT)
	_probe_meta.text = "T%d · %s分支%s · %s · 消耗 %d点" % [
			int(node.get("tier", 0)),
			SkillTree.get_branch_display_name(String(node.get("branch", ""))),
			" · ◈奇点" if is_cap else "",
			SkillBoard.ChipWidget.type_label_of(node),
			cost]
	_probe_desc.text = String(node.get("desc", ""))

	# 解锁内容行
	var unlocks: Array = node.get("unlocks", [])
	var unlock_text := _format_unlocks(unlocks)
	_probe_unlock.visible = not unlock_text.is_empty()
	if unlock_text != "":
		_probe_unlock.text = "解锁：" + unlock_text
		_probe_unlock.add_theme_color_override("font_color", DT.COLOR_VIOLET)

	# 前置 / 点数行
	var requires: Array = node.get("requires", [])
	if powered:
		_probe_req.visible = false
	else:
		_probe_req.visible = true
		if missing_req:
			_probe_req.text = "⚠ 前置未满足：%s" % _format_missing_requires(requires)
			_probe_req.add_theme_color_override("font_color", Color(DT.COLOR_RED_DOWN.r, DT.COLOR_RED_DOWN.g, DT.COLOR_RED_DOWN.b, 0.9))
		elif can:
			_probe_req.visible = requires.size() > 0
			_probe_req.text = "前置已就绪"
			_probe_req.add_theme_color_override("font_color", DT.COLOR_GREEN_UP)
		else:
			_probe_req.text = "技能点不足（通电需 %d 点，可用 %d 点）" % [cost, mgr.get_available_points() if mgr != null else 0]
			_probe_req.add_theme_color_override("font_color", Color(DT.COLOR_RED_DOWN.r, DT.COLOR_RED_DOWN.g, DT.COLOR_RED_DOWN.b, 0.9))

	# 右侧动作区
	if powered:
		_probe_action_label.visible = true
		_probe_action_label.text = "✓ 已通电"
		_probe_action_label.add_theme_color_override("font_color", DT.COLOR_GREEN_BRIGHT)
		_probe_action_btn.visible = false
	else:
		_probe_action_label.visible = false
		_probe_action_btn.visible = true
		_probe_action_btn.text = "通电 (%d点)" % cost
		_probe_action_btn.disabled = not can


func _on_action_pressed() -> void:
	if _selected_id != "":
		_on_unlock_pressed(_selected_id)


# ─────────────────────────────────────────────
#  ⚡ 下一个：跳转到下一个可通电芯片
# ─────────────────────────────────────────────

func _on_next_node_pressed() -> void:
	var mgr := _mgr()
	if mgr == null or _board == null:
		return
	var nxt: Dictionary = _board.find_next(mgr)
	if String(nxt.get("id", "")) == "":
		if SignalBus and SignalBus.has_signal("show_toast"):
			SignalBus.show_toast.emit("没有可推进的芯片：先点亮前置节点")
		else:
			_show_temp_msg("没有可推进的芯片")
		return
	var nid := String(nxt["id"])
	_scroll_to_node(nid)
	_on_chip_selected(nid)
	_board.play_focus_pulse(nid)
	if String(nxt.get("kind", "")) == "no_points":
		if SignalBus and SignalBus.has_signal("show_toast"):
			SignalBus.show_toast.emit("技能点不足：先提升相位场等级获取技能点")
		else:
			_show_temp_msg("技能点不足")


## 平滑滚动主板使目标芯片居中（尊重减弱动效偏好）
func _scroll_to_node(node_id: String) -> void:
	if _board_scroll == null or _board == null:
		return
	var center: Vector2 = _board.get_chip_center(node_id)
	var sb: VScrollBar = _board_scroll.get_v_scroll_bar()
	var target := int(center.y - _board_scroll.size.y * 0.5)
	if sb != null:
		target = clampi(target, 0, int(sb.max_value))
	if DT.is_motion_reduce():
		_board_scroll.scroll_vertical = target
	else:
		create_tween().tween_property(_board_scroll, "scroll_vertical", target, 0.25) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# ─────────────────────────────────────────────
#  解锁链路（v9 逻辑原样保留 + 通电演出）
# ─────────────────────────────────────────────

func _on_unlock_pressed(node_id: String) -> void:
	var mgr := _mgr()
	if mgr == null:
		return
	var ok: bool = mgr.unlock_node(node_id)
	if not ok:
		var can: Dictionary = mgr.can_unlock_node(node_id)
		var reason: String = can.get("reason", "")
		if SignalBus and SignalBus.has_signal("play_sound"):
			SignalBus.play_sound.emit("error")
		if reason == "not_enough_points":
			_show_temp_msg("技能点不足")
		elif reason == "requires_not_met":
			var missing_str := _format_missing_requires(
					SkillTree.get_skill(node_id).get("requires", []))
			if missing_str.is_empty():
				_show_temp_msg("需先解锁前置节点")
			else:
				_show_temp_msg("需先解锁：%s" % missing_str)
	else:
		if SignalBus and SignalBus.has_signal("play_sound"):
			SignalBus.play_sound.emit("enhance")
		_emit_unlock_toast(node_id)
		_board.play_unlock_effect(node_id)
	_request_refresh()


## 解锁成功后发射 Toast 通知
func _emit_unlock_toast(node_id: String) -> void:
	var node: Dictionary = SkillTree.get_skill(node_id)
	if node.is_empty():
		return
	var node_name: String = String(node.get("name", node_id))
	var unlocks: Array = node.get("unlocks", [])
	var toast_lines: Array = ["⚡ 已通电：%s" % node_name]
	if not unlocks.is_empty():
		var unlock_descs: Array = []
		for u in unlocks:
			if not (u is Dictionary):
				continue
			var u_type: String = u.get("type", "")
			var u_id: String = str(u.get("id", ""))
			var label: Dictionary = UnlockLabels.get_unlock_label(u_type, u_id)
			if not label.is_empty():
				unlock_descs.append(String(label.get("desc", "")))
		if not unlock_descs.is_empty():
			toast_lines.append(String(unlock_descs[0]))
	if SignalBus and SignalBus.has_signal("show_toast"):
		SignalBus.show_toast.emit("\n".join(toast_lines))


## 格式化解锁内容为玩家可读文字（使用 UnlockLabels 翻译表）
func _format_unlocks(unlocks: Array) -> String:
	var parts: Array = []
	for u in unlocks:
		if not (u is Dictionary):
			continue
		var u_type: String = u.get("type", "")
		var u_id: String = str(u.get("id", u.get("era", "")))
		var label: Dictionary = UnlockLabels.get_unlock_label(u_type, u_id)
		if not label.is_empty():
			var icon: String = String(label.get("icon", ""))
			var name: String = String(label.get("name", u_id))
			parts.append("%s %s" % [icon, name] if not icon.is_empty() else name)
		else:
			match u_type:
				"phase_instrument":
					var PhaseInstrumentsCls = preload("res://data/phase_instruments.gd")
					var inst_cfg: Dictionary = PhaseInstrumentsCls.get_by_id(u_id)
					var inst_name: String = String(inst_cfg.get("name", u_id))
					parts.append("相位仪：%s" % inst_name)
				"concept_weapon": parts.append("概念武器[%s]" % u_id)
				"special_card": parts.append("特殊卡[%s]" % u_id)
				"evolution":
					var era: int = int(u.get("era", 0))
					var era_names: Array = ["一战", "二战", "冷战", "现代", "近未来"]
					var era_label: String = era_names[clampi(era, 0, 4)] if era >= 0 and era < 5 else "全时代"
					parts.append("进化解锁[%s]" % era_label)
				"affix": parts.append("词条赋予")
				_: parts.append("%s[%s]" % [u_type, u_id])
	return "、".join(parts)


## 格式化缺失前置：节点名（所属分支）列表。跨系前置在主板走线可见，
## 此处文字点名兜底（悬停 tooltip 之外的主动提示）。
func _format_missing_requires(requires: Array) -> String:
	var mgr := _mgr()
	var missing_names: Array = []
	for req in requires:
		if mgr != null and mgr.is_unlocked(String(req)):
			continue
		var req_node: Dictionary = SkillTree.get_skill(String(req))
		var req_name: String = String(req_node.get("name", String(req)))
		var req_branch: String = SkillTree.get_branch_display_name(SkillTree.get_branch_of(String(req)))
		missing_names.append("%s（%s分支）" % [req_name, req_branch])
	return "、".join(missing_names)


# ─────────────────────────────────────────────
#  已解锁总览弹层（原总览 Tab 改弹层）
# ─────────────────────────────────────────────

func _toggle_summary() -> void:
	if _summary_overlay == null:
		_build_summary_overlay()
	_populate_summary()
	_summary_overlay.visible = not _summary_overlay.visible


func _build_summary_overlay() -> void:
	_summary_overlay = PanelContainer.new()
	_summary_overlay.name = "SummaryOverlay"
	_summary_overlay.visible = false
	_summary_overlay.add_theme_stylebox_override("panel", PanelStyles.make_panel_frame(DT.COLOR_GOLD))
	add_child(_summary_overlay)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", DT.PADDING_MEDIUM)
	margin.add_theme_constant_override("margin_right", DT.PADDING_MEDIUM)
	margin.add_theme_constant_override("margin_top", DT.PADDING_MEDIUM)
	margin.add_theme_constant_override("margin_bottom", DT.PADDING_MEDIUM)
	_summary_overlay.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	margin.add_child(vb)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vb.add_child(header)
	var title := Label.new()
	title.text = "📋 已解锁总览"
	title.add_theme_font_size_override("font_size", DT.FONT_SIZE_MEDIUM)
	title.add_theme_color_override("font_color", DT.COLOR_GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "✕ 收起"
	close_btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	close_btn.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
	var cb_styles := PanelStyles.make_button_styles(DT.COLOR_GOLD, "ghost")
	close_btn.add_theme_stylebox_override("normal", cb_styles["normal"])
	close_btn.add_theme_stylebox_override("hover", cb_styles["hover"])
	close_btn.add_theme_stylebox_override("pressed", cb_styles["pressed"])
	close_btn.add_theme_stylebox_override("focus", cb_styles["focus"])
	close_btn.pressed.connect(func() -> void: _summary_overlay.visible = false)
	header.add_child(close_btn)

	_summary_container = ScrollContainer.new()
	_summary_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_summary_container)


func _populate_summary() -> void:
	if _summary_container == null:
		return
	for child in _summary_container.get_children():
		_summary_container.remove_child(child)
		child.queue_free()
	var vb := VBoxContainer.new()
	vb.name = "SummaryVBox"
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 6)
	_summary_container.add_child(vb)

	var mgr := _mgr()
	if mgr == null:
		var empty_label := Label.new()
		empty_label.text = "（技能管理器未加载）"
		empty_label.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
		vb.add_child(empty_label)
		return

	var header := Label.new()
	var unlocked_nodes: Array = mgr.get("_unlocked_nodes") if mgr.get("_unlocked_nodes") != null else []
	header.text = "▎ 已解锁内容（%d 个节点）" % unlocked_nodes.size()
	header.add_theme_font_size_override("font_size", DT.FONT_SIZE_MEDIUM)
	header.add_theme_color_override("font_color", DT.COLOR_GOLD)
	vb.add_child(header)

	var summary: Array = UnlockLabels.get_unlocked_summary(unlocked_nodes)
	if summary.is_empty():
		var none_label := Label.new()
		none_label.text = "尚未解锁任何内容。在主板上点亮芯片即可解锁兵种机制/卡片技能/战法。"
		none_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		none_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		vb.add_child(none_label)
		return

	var by_type: Dictionary = {}
	for item in summary:
		var t: String = String(item.get("type", ""))
		if not by_type.has(t):
			by_type[t] = []
		by_type[t].append(item)

	var type_titles: Dictionary = {
		"unit_mechanism": "🥷 兵种机制",
		"unit_ability": "⚔ 兵种能力",
		"card_skill": "💥 卡片定时技能",
		"tactic": "🔱 战法",
		"phase_instrument": "🔮 相位仪",
		"affix": "📊 词条系统",
		"evolution": "🧬 进化形态",
		"concept_weapon": "☢ 概念武器",
		"special_card": "🌟 特殊卡",
	}

	for t in by_type.keys():
		var items: Array = by_type[t]
		var type_label := Label.new()
		type_label.text = "— %s（%d）—" % [String(type_titles.get(t, t)), items.size()]
		type_label.add_theme_color_override("font_color", Color(0.65, 0.55, 0.95, 1))
		type_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_BODY)
		vb.add_child(type_label)
		for item in items:
			vb.add_child(_make_summary_row(item))


func _make_summary_row(item: Dictionary) -> Control:
	var hb := HBoxContainer.new()
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_theme_constant_override("separation", 8)
	var icon_label := Label.new()
	icon_label.text = String(item.get("icon", "•"))
	icon_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_BODY)
	hb.add_child(icon_label)
	var info_vb := VBoxContainer.new()
	info_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(info_vb)
	var name_label := Label.new()
	name_label.text = String(item.get("name", ""))
	name_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_BODY)
	name_label.add_theme_color_override("font_color", DT.COLOR_GREEN_BRIGHT)
	info_vb.add_child(name_label)
	var desc: String = String(item.get("desc", ""))
	if not desc.is_empty():
		var desc_label := Label.new()
		desc_label.text = desc
		desc_label.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
		desc_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		info_vb.add_child(desc_label)
	return hb


# ─────────────────────────────────────────────
#  刷新链路（v9 perf 机制原样保留）
# ─────────────────────────────────────────────

func _on_node_unlocked(_node_id: String) -> void:
	_request_refresh()


func _on_points_changed(_available: int) -> void:
	_request_refresh()


func _request_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	_refresh.call_deferred()


## 渲染状态签名 = 已解锁节点集合 + 可用点数（两者唯一决定三态渲染与按钮可用性）
func _current_state_signature() -> String:
	var mgr := _mgr()
	if mgr == null:
		return "no-mgr"
	return "%s:%d" % [mgr.get_unlocked_signature(), mgr.get_available_points()]


func _update_points_label() -> void:
	if _points_label == null:
		return
	var mgr := _mgr()
	if mgr == null:
		_points_label.text = "  （技能管理器未加载）"
		return
	var avail: int = mgr.get_available_points()
	var spent: int = mgr.get_spent_points()
	_points_label.text = "  可用技能点：%d（已用 %d）" % [avail, spent]


func _refresh() -> void:
	_refresh_queued = false
	if not visible:
		_dirty = true
		return
	_dirty = false
	_update_points_label()
	var sig: String = _current_state_signature()
	if sig == _rendered_sig:
		return
	_rendered_sig = sig
	_board.refresh(_mgr())
	_update_probe()


func _show_temp_msg(msg: String) -> void:
	if _points_label:
		var orig: String = _points_label.text
		_points_label.text = "  ⚠ %s" % msg
		await get_tree().create_timer(1.2).timeout
		if is_instance_valid(_points_label):
			_points_label.text = orig


func _on_visibility_changed() -> void:
	if visible:
		if _dirty:
			_refresh()
		if not DT.is_motion_reduce():
			modulate.a = 0.0
			create_tween().tween_property(self, "modulate:a", 1.0, DT.MOTION_FADE_IN)


func _on_close_pressed() -> void:
	hide_panel()


func hide_panel() -> void:
	visible = false
	closed.emit()


func _make_spacer(expand: bool) -> Control:
	var c := Control.new()
	if expand:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c
