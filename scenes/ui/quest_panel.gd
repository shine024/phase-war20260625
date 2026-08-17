extends PanelContainer
## 任务面板：委托/日常两标签，可接任务列表、已接任务与进度、接取/放弃

const QuestDefs = preload("res://data/quest_definitions.gd")
const CompanyDefs = preload("res://data/company_definitions.gd")
const DT = preload("res://resources/design_tokens.gd")
const PanelStyles = preload("res://scripts/ui/panel_styles.gd")
const PanelChrome = preload("res://scenes/ui/components/panel_chrome.gd")

signal closed

@onready var company_list: VBoxContainer = $Margin/VBox/TabContainer/CommissionTab/CompanySummary/Margin/CompanyList
@onready var commission_list: VBoxContainer = $Margin/VBox/TabContainer/CommissionTab/CommissionScroll/CommissionList
@onready var daily_list: VBoxContainer = $Margin/VBox/TabContainer/DailyTab/DailyScroll/DailyList
@onready var accepted_label: Label = $Margin/VBox/AcceptedLabel
@onready var tab_container: TabContainer = $Margin/VBox/TabContainer

# v8.x 性能：on_overlay_opened 拆帧重入守卫
var _open_refresh_inflight: bool = false

func _ready() -> void:
	# v7.x 面板统一：MEDIUM 档 + 青色签名框架 + PanelChrome 标题栏（右上 ✕ 关闭）
	custom_minimum_size = DT.PANEL_SIZE_MEDIUM
	var accent := DT.get_panel_accent("quest")
	add_theme_stylebox_override("panel", PanelStyles.make_panel_frame(accent))
	var chrome = PanelChrome.attach_to($Margin/VBox, "任务面板", accent, "QUESTS")
	chrome.closed.connect(_on_close)
	ManagerLazyLoader.ensure_loaded("quest")
	var QuestManager = get_node_or_null("/root/QuestManager")
	if QuestManager:
		QuestManager.quest_progress_changed.connect(_on_quest_changed)
		QuestManager.quest_completed.connect(_on_quest_completed)
	# v8.x 性能：_ready 只连信号，列表刷新交给 on_overlay_opened 拆帧。
	# QuestManager 信号 handler (_on_quest_changed/_on_quest_completed) 自身就是完整刷新流程，
	# 不依赖 _ready 设置任何状态，故窗口期安全。

## v8.x 性能：外部打开面板时调用（main.gd._open_overlay 分发）。
## 将任务/公司列表重建拆到下一帧，避开打开同帧的实例化尖峰。
## 仿 store_panel.on_overlay_opened 模式。
func on_overlay_opened() -> void:
	if _open_refresh_inflight:
		return
	_open_refresh_inflight = true
	call_deferred("_run_open_refresh_pipeline")

func _run_open_refresh_pipeline() -> void:
	if not is_visible_in_tree():
		_open_refresh_inflight = false
		return
	await get_tree().process_frame
	if not is_visible_in_tree():
		_open_refresh_inflight = false
		return
	_refresh_company_summary()
	_refresh_list()
	_open_refresh_inflight = false

## v7.x 修复 W6：面板释放时断开 autoload 信号，避免残留死 Callable
func _exit_tree() -> void:
	var QuestManager = get_node_or_null("/root/QuestManager")
	if QuestManager == null:
		return
	if QuestManager.has_signal("quest_progress_changed") and QuestManager.quest_progress_changed.is_connected(_on_quest_changed):
		QuestManager.quest_progress_changed.disconnect(_on_quest_changed)
	if QuestManager.has_signal("quest_completed") and QuestManager.quest_completed.is_connected(_on_quest_completed):
		QuestManager.quest_completed.disconnect(_on_quest_completed)

func _on_close() -> void:
	closed.emit()

func _on_quest_changed(_quest_id: String) -> void:
	# v9 perf：隐藏时跳过——战斗胜利时每个已接任务 emit 一次，同帧多次全量重建
	#（~58 任务行 + 7 公司行）；打开路径 on_overlay_opened 拆帧全量刷新，不漏内容
	if not is_visible_in_tree():
		return
	_refresh_company_summary()
	_refresh_list()

func _on_quest_completed(quest_id: String, rewards: Dictionary) -> void:
	if not is_visible_in_tree():
		return
	_refresh_company_summary()
	_refresh_list()

func _refresh_company_summary() -> void:
	if company_list == null:
		return
	for c in company_list.get_children():
		c.queue_free()
	var fsm: Node = get_node_or_null("/root/FactionSystemManager")
	var companies: Array = CompanyDefs.get_all()
	for cfg in companies:
		if not cfg is Dictionary:
			continue
		var cid: String = cfg.get("id", "")
		var cname: String = cfg.get("name", cid)
		var rep_value: int = 0
		if fsm != null and fsm.has_method("get_faction_reputation"):
			rep_value = int(fsm.get_faction_reputation(cid))
		# PanelContainer 包裹
		var panel := PanelContainer.new()
		var ps := StyleBoxFlat.new()
		ps.bg_color = Color(DT.COLOR_PANEL_DEEP.r, DT.COLOR_PANEL_DEEP.g, DT.COLOR_PANEL_DEEP.b, 0.9)
		ps.border_color = Color(DT.COLOR_KIND_ARMOR.r, DT.COLOR_KIND_ARMOR.g, DT.COLOR_KIND_ARMOR.b, 0.4)
		ps.border_width_left = 2
		ps.border_width_top = 0
		ps.border_width_right = 0
		ps.border_width_bottom = 0
		ps.corner_radius_top_left = 3
		ps.corner_radius_bottom_left = 3
		panel.add_theme_stylebox_override("panel", ps)
		var mg := MarginContainer.new()
		mg.add_theme_constant_override("margin_left", 8)
		mg.add_theme_constant_override("margin_right", 8)
		mg.add_theme_constant_override("margin_top", 4)
		mg.add_theme_constant_override("margin_bottom", 4)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		var name_label := Label.new()
		name_label.text = cname
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		name_label.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
		var rep_label := Label.new()
		rep_label.text = "声望：%d" % rep_value
		rep_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_XSMALL)
		rep_label.add_theme_color_override("font_color",
			DT.COLOR_GREEN_BRIGHT if rep_value > 0 else Color(DT.COLOR_TEXT_DIM.r, DT.COLOR_TEXT_DIM.g, DT.COLOR_TEXT_DIM.b, 0.7))
		rep_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(name_label)
		line.add_child(rep_label)
		mg.add_child(line)
		panel.add_child(mg)
		company_list.add_child(panel)

func _refresh_list() -> void:
	ManagerLazyLoader.ensure_loaded("quest")
	var quest_mgr = get_node_or_null("/root/QuestManager")
	if quest_mgr and quest_mgr.has_method("notify_fragments_changed"):
		quest_mgr.notify_fragments_changed()
	# 清空两个列表
	for c in commission_list.get_children():
		c.queue_free()
	for c in daily_list.get_children():
		c.queue_free()
	if not quest_mgr:
		return
	var accepted: Array = quest_mgr.get_accepted_quest_ids()
	accepted_label.text = "已接任务：%d / %d" % [int(accepted.size()), quest_mgr.MAX_ACCEPTED]
	var all_ids: Array = QuestDefs.get_available_ids()
	for qid in all_ids:
		var def: Dictionary = QuestDefs.get_by_id(qid)
		if def.is_empty():
			continue
		var is_accepted: bool = quest_mgr.is_accepted(qid)
		# v6.6(剧情): 隐藏任务在 reveal 前不出现在任务板（补剧情.txt 真实者支线）
		# 已接的任务无论 hidden 都显示（防止接取后 reveal 状态丢失导致任务消失）
		if not is_accepted and quest_mgr.has_method("is_quest_available") and not quest_mgr.is_quest_available(qid):
			continue
		var row: Control = _make_quest_row(qid, def, is_accepted)
		# 按 category 分流到对应 Tab 列表
		var category: String = def.get("category", "commission")
		match category:
			"daily":
				daily_list.add_child(row)
			_:
				commission_list.add_child(row)
	if daily_list.get_child_count() == 0:
		daily_list.add_child(_make_empty_hint("日常任务将在每日刷新时出现。"))

## v6.7(剧情任务): 空列表提示（v7.x: 加可选强调色，提升可读性）
func _make_empty_hint(text: String, color: Color = DT.COLOR_TEXT_DIM) -> Control:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl

func _make_quest_row(quest_id: String, def: Dictionary, is_accepted: bool) -> Control:
	var quest_mgr = get_node_or_null("/root/QuestManager")
	var is_completed: bool = not is_accepted and quest_mgr.is_completed_ever(quest_id) if quest_mgr else false
	var category: String = def.get("category", "commission")
	# v6.9: 动态任务（势力委托）视觉标记
	var is_dynamic: bool = bool(def.get("is_dynamic", false))
	# 根据状态确定边框颜色
	var border_color: Color
	var bg_color: Color
	if is_accepted:
		border_color = Color(DT.COLOR_GREEN_UP.r, DT.COLOR_GREEN_UP.g, DT.COLOR_GREEN_UP.b, 0.6)
		bg_color     = Color(DT.COLOR_GREEN_UP.r, DT.COLOR_GREEN_UP.g, DT.COLOR_GREEN_UP.b, 0.08)
	elif is_completed:
		border_color = Color(DT.COLOR_BORDER_DIM.r, DT.COLOR_BORDER_DIM.g, DT.COLOR_BORDER_DIM.b, 0.3)
		bg_color     = Color(DT.COLOR_SLOT_LOCKED.r, DT.COLOR_SLOT_LOCKED.g, DT.COLOR_SLOT_LOCKED.b, 0.75)
	elif is_dynamic:
		# v6.9: 势力动态委托用橙红边框（占领势力主题色）
		border_color = Color(DT.COLOR_ENERGY.r, DT.COLOR_ENERGY.g, DT.COLOR_ENERGY.b, 0.65)
		bg_color     = Color(DT.COLOR_ENERGY.r, DT.COLOR_ENERGY.g, DT.COLOR_ENERGY.b, 0.07)
	else:
		border_color = Color(DT.COLOR_KIND_ARMOR.r, DT.COLOR_KIND_ARMOR.g, DT.COLOR_KIND_ARMOR.b, 0.5)
		bg_color     = Color(DT.COLOR_PANEL_DEEP.r, DT.COLOR_PANEL_DEEP.g, DT.COLOR_PANEL_DEEP.b, 0.9)
	var panel := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = bg_color
	ps.border_color = border_color
	ps.border_width_left = 2
	ps.border_width_top = 1
	ps.border_width_right = 1
	ps.border_width_bottom = 1
	ps.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", ps)
	var mg := MarginContainer.new()
	mg.add_theme_constant_override("margin_left", 10)
	mg.add_theme_constant_override("margin_right", 8)
	mg.add_theme_constant_override("margin_top", 7)
	mg.add_theme_constant_override("margin_bottom", 7)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 标题
	var title_l := Label.new()
	var title_text: String = def.get("title", quest_id)
	title_l.text = title_text
	title_l.add_theme_font_size_override("font_size", DT.FONT_SIZE_BODY)
	var title_color: Color
	if is_accepted:
		title_color = DT.COLOR_GREEN_BRIGHT
	elif is_completed:
		title_color = Color(DT.COLOR_TEXT_DIM.r, DT.COLOR_TEXT_DIM.g, DT.COLOR_TEXT_DIM.b, 0.7)
	elif is_dynamic:
		# v6.9: 势力动态委托标题用暖橙，体现"势力委托"主题
		title_color = DT.COLOR_GOLD
	else:
		title_color = DT.COLOR_TEXT_BRIGHT
	title_l.add_theme_color_override("font_color", title_color)
	v.add_child(title_l)
	# 公司与奖励
	var company_id: String = def.get("company_id", "")
	if not company_id.is_empty():
		var company_cfg: Dictionary = CompanyDefs.get_by_id(company_id)
		var company_name: String = company_cfg.get("name", company_id)
		var rewards: Dictionary = def.get("rewards", {})
		var rep_text: String = ""
		if rewards.has("company_rep") and rewards["company_rep"] is Dictionary:
			var rep_dict: Dictionary = rewards["company_rep"]
			if rep_dict.has(company_id):
				var rv: int = int(rep_dict[company_id])
				if rv > 0:
					rep_text = "（完成 +%d 贡献）" % rv
		var company_l := Label.new()
		company_l.text = "▸ %s%s" % [company_name, rep_text]
		company_l.add_theme_font_size_override("font_size", DT.FONT_SIZE_XSMALL)
		company_l.add_theme_color_override("font_color", Color(DT.COLOR_KIND_ARMOR.r, DT.COLOR_KIND_ARMOR.g, DT.COLOR_KIND_ARMOR.b, 0.85))
		v.add_child(company_l)
	# 描述
	var desc_l := Label.new()
	desc_l.text = def.get("description", "")
	desc_l.add_theme_color_override("font_color",
		Color(DT.COLOR_TEXT_DIM.r, DT.COLOR_TEXT_DIM.g, DT.COLOR_TEXT_DIM.b, 0.7) if is_completed else Color(DT.COLOR_TEXT_MID.r, DT.COLOR_TEXT_MID.g, DT.COLOR_TEXT_MID.b, 0.85))
	desc_l.add_theme_font_size_override("font_size", DT.FONT_SIZE_XSMALL)
	desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc_l)
	row.add_child(v)
	# 右侧按钮区
	var btn_col := VBoxContainer.new()
	btn_col.add_theme_constant_override("separation", 4)
	btn_col.alignment = BoxContainer.ALIGNMENT_CENTER
	if is_accepted:
		var progress_l := Label.new()
		progress_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		progress_l.text = _format_progress(quest_id, def)
		progress_l.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		progress_l.add_theme_color_override("font_color", DT.COLOR_GREEN_UP)
		btn_col.add_child(progress_l)
		var abandon_btn := Button.new()
		abandon_btn.text = "放弃"
		abandon_btn.custom_minimum_size = Vector2(70, 28)
		var abandon_styles := PanelStyles.make_button_styles(DT.COLOR_RED_DOWN, "danger")
		abandon_btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		abandon_btn.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
		abandon_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
		abandon_btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
		abandon_btn.add_theme_color_override("font_focus_color", Color(1, 1, 1, 1))
		abandon_btn.add_theme_stylebox_override("normal", abandon_styles["normal"])
		abandon_btn.add_theme_stylebox_override("hover", abandon_styles["hover"])
		abandon_btn.add_theme_stylebox_override("pressed", abandon_styles["pressed"])
		abandon_btn.add_theme_stylebox_override("disabled", abandon_styles["disabled"])
		abandon_btn.pressed.connect(_on_abandon.bind(quest_id))
		btn_col.add_child(abandon_btn)
	else:
		if is_completed:
			var done_l := Label.new()
			done_l.text = "✓ 已完成"
			done_l.add_theme_color_override("font_color", Color(DT.COLOR_GREEN_UP.r, DT.COLOR_GREEN_UP.g, DT.COLOR_GREEN_UP.b, 0.75))
			done_l.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
			btn_col.add_child(done_l)
		else:
			var accept_btn := Button.new()
			accept_btn.text = "接取"
			accept_btn.custom_minimum_size = Vector2(70, 32)
			var accept_styles := PanelStyles.make_button_styles(DT.COLOR_GREEN_UP)
			accept_btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
			accept_btn.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
			accept_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
			accept_btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
			accept_btn.add_theme_color_override("font_focus_color", Color(1, 1, 1, 1))
			accept_btn.add_theme_stylebox_override("normal", accept_styles["normal"])
			accept_btn.add_theme_stylebox_override("hover", accept_styles["hover"])
			accept_btn.add_theme_stylebox_override("pressed", accept_styles["pressed"])
			accept_btn.add_theme_stylebox_override("disabled", accept_styles["disabled"])
			var can_accept: bool = quest_mgr.get_accepted_quest_ids().size() < quest_mgr.MAX_ACCEPTED if quest_mgr else false
			accept_btn.disabled = not can_accept
			accept_btn.pressed.connect(_on_accept.bind(quest_id))
			btn_col.add_child(accept_btn)
	row.add_child(btn_col)
	mg.add_child(row)
	panel.add_child(mg)
	return panel

func _format_progress(quest_id: String, def: Dictionary) -> String:
	var quest_mgr = get_node_or_null("/root/QuestManager")
	var otype: String = def.get("objective_type", "")
	var target: Variant = def.get("target", 0)
	var cur: int = quest_mgr.get_current_progress_for_quest(quest_id) if quest_mgr else 0
	var done: bool = quest_mgr.is_quest_done(quest_id) if quest_mgr else false

	match otype:
		"win_battles":
			return "胜利 %d / %d" % [cur, int(target)]
		"kill_enemies":
			return "击毁 %d / %d" % [cur, int(target)]
		"clear_level":
			return "已通关" if done else "目标：第 %d 关" % int(target)
		"clear_boss_count":
			return "Boss关 %d / %d" % [cur, int(target)]
		"clear_all_era":
			return "时代 %d / %d" % [cur, int(target)]
		"collect_fragments":
			# v7.3 修复 BUG-8: target 可能是 int 或 {total:N}
			var frag_tgt: int = int(target) if target is int else int(target.get("total", 1)) if target is Dictionary else 1
			return "蓝图 %d / %d" % [cur, frag_tgt]
		"enhance":
			return "强化 %d / %d" % [cur, int(target)]
		"collect_cards":
			return "卡片 %d / %d" % [cur, int(target)]
		"research_law":
			return "研究 %d / %d" % [cur, int(target)]
		"reach_reputation":
			return "声望 %d / %d" % [cur, int(target)]
		"buy_items":
			return "购买 %d / %d" % [cur, int(target)]
		"quick_win":
			# v7.3 完善 BUG-9: 显示目标阈值秒数
			var qw_tgt: float = float(target)
			if cur <= 0:
				return "目标：≤%.0f秒" % qw_tgt
			var best_time: float = 0.0
			if quest_mgr:
				best_time = float(quest_mgr.get_quest_progress(quest_id).get("progress", {}).get("best_time", 0.0))
			if best_time > 0 and best_time <= qw_tgt:
				return "已达成 %.1f秒（≤%.0f）" % [best_time, qw_tgt]
			elif best_time > 0:
				return "最快 %.1f秒（需≤%.0f）" % [best_time, qw_tgt]
			return "目标：≤%.0f秒" % qw_tgt
		"perfect_battle":
			return "三星 %d / %d" % [cur, int(target)]
		"survive_waves":
			return "波次 %d / %d" % [cur, int(target)]
		"attack_faction":
			return "已完成" if done else "进行中"
		"defend_faction":
			return "已完成" if done else "进行中"
	return ""

func _on_accept(quest_id: String) -> void:
	ManagerLazyLoader.ensure_loaded("quest")
	var quest_mgr = get_node_or_null("/root/QuestManager")
	if quest_mgr:
		quest_mgr.accept_quest(quest_id)
		_refresh_list()

func _on_abandon(quest_id: String) -> void:
	ManagerLazyLoader.ensure_loaded("quest")
	var quest_mgr = get_node_or_null("/root/QuestManager")
	if quest_mgr:
		quest_mgr.abandon_quest(quest_id)
		_refresh_list()
