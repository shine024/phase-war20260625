extends Control
## v6.4 城市地图 — 365天循环剧情模式的核心场景
##
## 布局：
##   - 背景：幻想城市（深色底+渐变）
##   - 时段蒙板：覆盖在城市上，表现早中晚氛围
##   - 地点按钮：8个，按相对位置摆放，未开放则灰显
##   - 顶部HUD：天数/时段/周目 + 主线提示
##   - 底部：休息按钮、退出按钮

const DesignTokens = preload("res://resources/design_tokens.gd")
const CityLocs = preload("res://data/city_locations.gd")
const StoryNodes = preload("res://data/main_story_nodes.gd")
const StoryFlags = preload("res://data/story/story_flags.gd")
const NPCDialogSystem = preload("res://scripts/city/npc_dialog_system.gd")
const RuneDefinitions = preload("res://data/runes.gd")
const CityBackdrop = preload("res://scenes/city/city_backdrop.gd")

var _day_clock: Node = null
var _location_buttons: Dictionary = {}  # location_id -> Button
var _phase_overlay: ColorRect = null
var _time_label: Label = null
var _hint_label: Label = null
var _stats_label: Label = null  ## v6.6(剧情): 战力/声望显示（补剧情.txt L37/L41）
var _pending_node: Dictionary = {}  ## 待处理的主线节点
var _pending_npc_dialog: Dictionary = {}  ## v6.6(剧情): 待处理的 NPC 支线对话播放指令
var _awaiting_post_battle_dialogue: bool = false  ## v6.6(剧情): 等待战后对话播完的标志

func _ready() -> void:
	_day_clock = get_node_or_null("/root/DayClock")
	_build_ui()
	_refresh_all()
	# 监听天时钟信号
	if _day_clock:
		if _day_clock.has_signal("day_phase_changed"):
			_day_clock.day_phase_changed.connect(_on_time_changed)
		if _day_clock.has_signal("day_started"):
			_day_clock.day_started.connect(_on_day_started)
		if _day_clock.has_signal("year_end_reached"):
			_day_clock.year_end_reached.connect(_on_year_end)
	# 监听对话完成信号
	if SignalBus.has_signal("story_dialogue_finished"):
		SignalBus.story_dialogue_finished.connect(_on_dialogue_finished)
	# 监听战斗结束
	if SignalBus.has_signal("battle_ended"):
		SignalBus.battle_ended.connect(_on_battle_ended)
	# v6.6(剧情): 监听战斗开始 — 隐藏 city_map 让出屏幕给战斗 HUD（背包/相位仪）
	# city_map 在 PopupLayer(layer 100) 会遮挡 HudLayer(layer 40) 的战斗功能栏
	if SignalBus.has_signal("battle_started"):
		SignalBus.battle_started.connect(_on_battle_started)
	# v6.6(剧情): 监听对话面板的分支选择信号（真实者加入/拒绝/拖延）
	var dp_for_choice: Node = get_node_or_null("StoryDialoguePanel")
	if dp_for_choice == null:
		var ms: Node = get_tree().current_scene
		if ms:
			dp_for_choice = ms.get_node_or_null("PopupLayer/StoryOverlay/CenterContainer/StoryDialoguePanel")
	if dp_for_choice and dp_for_choice.has_signal("story_choice_made") and not dp_for_choice.story_choice_made.is_connected(_on_story_choice_made):
		dp_for_choice.story_choice_made.connect(_on_story_choice_made)
	visible = false

func _exit_tree() -> void:
	_disconnect_signals()

func _disconnect_signals() -> void:
	if _day_clock and is_instance_valid(_day_clock):
		if _day_clock.has_signal("day_phase_changed") and _day_clock.day_phase_changed.is_connected(_on_time_changed):
			_day_clock.day_phase_changed.disconnect(_on_time_changed)
		if _day_clock.has_signal("day_started") and _day_clock.day_started.is_connected(_on_day_started):
			_day_clock.day_started.disconnect(_on_day_started)
	if SignalBus != null:
		if SignalBus.has_signal("story_dialogue_finished") and SignalBus.story_dialogue_finished.is_connected(_on_dialogue_finished):
			SignalBus.story_dialogue_finished.disconnect(_on_dialogue_finished)
		if SignalBus.has_signal("battle_started") and SignalBus.battle_started.is_connected(_on_battle_started):
			SignalBus.battle_started.disconnect(_on_battle_started)
		if SignalBus.has_signal("battle_ended") and SignalBus.battle_ended.is_connected(_on_battle_ended):
			SignalBus.battle_ended.disconnect(_on_battle_ended)

# ═══════════════════════════════════════════════════════════════════
# UI 构建
# ═══════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# v6.6(剧情): 无限城几何形象背景（替换原纯色背景）
	# CityBackdrop 是独立 _draw 节点，mouse_filter=IGNORE 不拦截地点按钮点击
	var backdrop := Control.new()
	backdrop.set_script(CityBackdrop)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	# 时段蒙板（覆盖在背景上，表现早中晚氛围）
	_phase_overlay = ColorRect.new()
	_phase_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_phase_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phase_overlay.color = Color(1, 1, 1, 0)
	add_child(_phase_overlay)

	# 顶部HUD
	_build_top_hud()

	# 地点按钮层（叠加在无限城几何图上）
	_build_location_buttons()

	# v6.6(剧情): 左侧相位仪快捷显示栏
	_build_phase_instrument_bar()

	# 底部功能按钮栏（背包/成长/商店/任务/符文/情报 + 休息/推进/退出）
	_build_bottom_bar()

func _build_top_hud() -> void:
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 50
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", DesignTokens.PADDING_MEDIUM)
	add_child(top)

	_time_label = Label.new()
	_time_label.text = "第1天 · 上午"
	_time_label.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_LARGE)
	_time_label.add_theme_color_override("font_color", DesignTokens.COLOR_ACCENT_CYAN)
	top.add_child(_time_label)

	_hint_label = Label.new()
	_hint_label.text = ""
	_hint_label.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_SMALL)
	_hint_label.add_theme_color_override("font_color", DesignTokens.COLOR_ACCENT_PURPLE)
	top.add_child(_hint_label)

	# v6.6(剧情): 战力/声望显示（补剧情.txt L37/L41 声望战力概念引入）
	_stats_label = Label.new()
	_stats_label.text = "战力 0 · 声望 0"
	_stats_label.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_MEDIUM)
	_stats_label.add_theme_color_override("font_color", DesignTokens.COLOR_HEALTH)
	top.add_child(_stats_label)

func _build_location_buttons() -> void:
	for loc in CityLocs.LOCATIONS:
		var btn := Button.new()
		var pos: Vector2 = loc.get("button_pos", Vector2(0.5, 0.5))
		# 相对位置转绝对偏移
		btn.set_anchors_preset(Control.PRESET_CENTER)
		btn.anchor_left = pos.x
		btn.anchor_top = pos.y
		btn.anchor_right = pos.x
		btn.anchor_bottom = pos.y
		btn.offset_left = -60
		btn.offset_top = -30
		btn.offset_right = 60
		btn.offset_bottom = 30
		btn.custom_minimum_size = Vector2(120, 60)
		btn.text = "%s\n%s" % [loc.get("icon", "◆"), loc.get("name", "???")]
		btn.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_SMALL)
		var loc_color: Color = loc.get("color", DesignTokens.COLOR_TEXT)
		btn.add_theme_color_override("font_color", loc_color)
		btn.tooltip_text = loc.get("description", "")
		var loc_id: String = loc["id"]
		btn.pressed.connect(_on_location_clicked.bind(loc_id))
		add_child(btn)
		_location_buttons[loc_id] = btn

func _build_bottom_bar() -> void:
	# v6.6(剧情): 底部栏重构为两行 — 功能按钮行 + 时间控制行
	var bottom_vbox := VBoxContainer.new()
	bottom_vbox.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_vbox.offset_top = -110
	bottom_vbox.add_theme_constant_override("separation", 6)
	add_child(bottom_vbox)

	# ── 第一行：功能按钮（复用 _open_panel 打开现有面板）──
	var func_row := HBoxContainer.new()
	func_row.alignment = BoxContainer.ALIGNMENT_CENTER
	func_row.add_theme_constant_override("separation", DesignTokens.BUTTON_SPACING)
	bottom_vbox.add_child(func_row)
	# 功能按钮配置：[图标, 文字, panel_key]
	# panel_key 对应 main.gd _overlay_for_panel_key 的键
	var func_buttons: Array = [
		["🎒", "背包", "backpack"],
		["🌱", "成长", "growth"],
		["🛒", "商店", "store"],
		["📜", "任务", "quest"],
		["🔰", "符文", "rune"],
		["◈", "情报", "info"],
		["🔧", "强化", "enhancement"],
	]
	for cfg in func_buttons:
		var icon_text: String = cfg[0]
		var label: String = cfg[1]
		var pkey: String = cfg[2]
		var btn := Button.new()
		btn.text = "%s %s" % [icon_text, label]
		btn.custom_minimum_size = Vector2(90, DesignTokens.BUTTON_HEIGHT)
		btn.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_SMALL)
		btn.pressed.connect(_open_panel.bind(pkey))
		func_row.add_child(btn)

	# ── 第二行：时间控制 ──
	var time_row := HBoxContainer.new()
	time_row.alignment = BoxContainer.ALIGNMENT_CENTER
	time_row.add_theme_constant_override("separation", DesignTokens.BUTTON_SPACING)
	bottom_vbox.add_child(time_row)

	# 休息按钮
	var rest_btn := Button.new()
	rest_btn.text = "☾ 休息（跳到明天）"
	rest_btn.custom_minimum_size = Vector2(180, DesignTokens.BUTTON_HEIGHT)
	rest_btn.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_MEDIUM)
	rest_btn.pressed.connect(_on_rest_pressed)
	time_row.add_child(rest_btn)

	# 推进时段按钮
	var advance_btn := Button.new()
	advance_btn.text = "▶ 推进时间"
	advance_btn.custom_minimum_size = Vector2(140, DesignTokens.BUTTON_HEIGHT)
	advance_btn.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_MEDIUM)
	advance_btn.pressed.connect(_on_advance_pressed)
	time_row.add_child(advance_btn)

	# 退出按钮
	var exit_btn := Button.new()
	exit_btn.text = "返回自由模式"
	exit_btn.custom_minimum_size = Vector2(150, DesignTokens.BUTTON_HEIGHT)
	exit_btn.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_MEDIUM)
	exit_btn.pressed.connect(_on_exit_pressed)
	time_row.add_child(exit_btn)

## v6.6(剧情): 左侧相位仪快捷显示栏（点击打开相位仪选择面板）
## 复用 main.gd 的 _open_phase_instrument_selector 流程
func _build_phase_instrument_bar() -> void:
	var bar := VBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	bar.offset_top = 70
	bar.offset_bottom = 120
	bar.offset_right = 200
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(bar)

	var pi_btn := Button.new()
	pi_btn.name = "PhaseInstrumentButton"
	pi_btn.text = "🌀 相位仪"
	pi_btn.tooltip_text = "点击打开相位仪选择"
	pi_btn.custom_minimum_size = Vector2(160, DesignTokens.BUTTON_HEIGHT)
	pi_btn.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_MEDIUM)
	pi_btn.add_theme_color_override("font_color", DesignTokens.COLOR_ACCENT_CYAN)
	pi_btn.pressed.connect(_on_phase_instrument_clicked)
	bar.add_child(pi_btn)

## v6.6(剧情): 打开相位仪选择面板（复用 main.gd 的流程）
func _on_phase_instrument_clicked() -> void:
	var main_scene: Node = get_tree().current_scene
	if main_scene and main_scene.has_method("_open_phase_instrument_selector"):
		main_scene._open_phase_instrument_selector()
	elif main_scene and main_scene.has_method("_on_phase_level_label_clicked"):
		main_scene._on_phase_level_label_clicked()
	else:
		if SignalBus.has_signal("show_toast"):
			SignalBus.show_toast.emit("相位仪选择暂不可用")

# ═══════════════════════════════════════════════════════════════════
# 刷新逻辑
# ═══════════════════════════════════════════════════════════════════

func _refresh_all() -> void:
	_refresh_time_display()
	_refresh_phase_overlay()
	_refresh_location_availability()
	_check_main_story_node()

func _refresh_time_display() -> void:
	if _day_clock == null:
		_time_label.text = "时间未初始化"
		return
	_time_label.text = _day_clock.get_full_time_display()
	# 主线提示
	var next_node: Dictionary = StoryNodes.get_next_node_after(_day_clock.current_day)
	if not next_node.is_empty():
		var next_day: int = int(next_node.get("trigger_day", 0))
		_hint_label.text = "下一个主线：第%d天 · %s" % [next_day, next_node.get("title", "")]
	else:
		_hint_label.text = ""
	# v6.6(剧情): 刷新战力/声望显示（补剧情.txt L37/L41）
	_refresh_stats_display()

## v6.6(剧情): 刷新战力/声望 HUD（从 GameManager + FactionSystemManager 聚合）
func _refresh_stats_display() -> void:
	if _stats_label == null:
		return
	var power: int = 0
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		if gm.has_method("get_power_rating"):
			power = gm.get_power_rating()
		elif gm.has_method("calculate_power_rating"):
			power = gm.calculate_power_rating()
	var total_rep: int = _get_total_reputation()
	_stats_label.text = "战力 %d · 声望 %d" % [power, total_rep]

## v6.6(剧情): 聚合 7 阵营总声望
func _get_total_reputation() -> int:
	var fsm: Node = get_node_or_null("/root/FactionSystemManager")
	if fsm == null or not fsm.has_method("get_faction_reputation"):
		return 0
	var total: int = 0
	for fid in ["iron_wall_corp", "nova_arms", "aether_dynamics",
				"quantum_logistics", "helix_recon", "void_research", "frontier_union"]:
		total += int(fsm.get_faction_reputation(fid))
	return total

func _refresh_phase_overlay() -> void:
	if _day_clock == null:
		return
	_phase_overlay.color = _day_clock.get_current_phase_overlay()

func _refresh_location_availability() -> void:
	if _day_clock == null:
		return
	for loc_id in _location_buttons:
		var btn: Button = _location_buttons[loc_id]
		var available: bool = CityLocs.is_location_available(loc_id, _day_clock.current_day, _day_clock.current_phase)
		btn.disabled = not available
		btn.modulate.a = 1.0 if available else 0.4

func _check_main_story_node() -> void:
	if _day_clock == null:
		return
	var node: Dictionary = StoryNodes.get_node_at(_day_clock.current_day, _day_clock.current_phase)
	if node.is_empty():
		return
	# 有主线节点 — 检查是否已处理过
	# v6.6(剧情)修复：原代码误用 is_chapter_complete 判定节点，会污染章节进度
	# 改用 StoryManager.is_node_triggered 专门追踪剧情节点
	var sm: Node = get_node_or_null("/root/StoryManager")
	if sm and sm.has_method("is_node_triggered"):
		if sm.is_node_triggered(node.get("id", "")):
			return  # 已处理，不再触发
	# 触发主线节点
	_trigger_story_node(node)

# ═══════════════════════════════════════════════════════════════════
# 主线节点触发
# ═══════════════════════════════════════════════════════════════════

func _trigger_story_node(node: Dictionary) -> void:
	_pending_node = node
	var node_type: String = node.get("type", "dialogue")
	# v6.6(剧情)修复：mark_node_triggered 不在此处提前调用（会导致战前对话阶段存档退出时
	# 节点被标记"已触发"但战斗实际没打，进度静默丢失）。改在各完成路径末尾标记。
	match node_type:
		"dialogue":
			_show_dialogues(node.get("dialogues", []))
		"battle":
			_show_dialogues(node.get("dialogues", []))
			# 对话结束后由 _on_dialogue_finished 触发战斗
		"boss":
			_show_dialogues(node.get("dialogues", []))
			# 对话结束后触发Boss战
		"unlock":
			_show_dialogues(node.get("dialogues", []))
			# 对话结束后应用解锁
		"ending":
			# 结局节点：播放即完成，立即标记
			_mark_node_done(node)
			_show_ending(node)
		_:
			_show_dialogues(node.get("dialogues", []))

## v6.6(剧情): 标记节点完成（全流程结束后调用，防过早标记导致进度丢失）
func _mark_node_done(node: Dictionary) -> void:
	var sm: Node = get_node_or_null("/root/StoryManager")
	if sm and sm.has_method("mark_node_triggered"):
		sm.mark_node_triggered(node.get("id", ""))

func _show_dialogues(dialogues: Array) -> void:
	if dialogues.is_empty():
		_on_dialogue_finished()
		return
	# 复用 story_dialogue_panel
	var dialogue_panel: Node = get_node_or_null("StoryDialoguePanel")
	if dialogue_panel == null:
		# 尝试从 story overlay 获取
		var main_scene: Node = get_tree().current_scene
		if main_scene:
			dialogue_panel = main_scene.get_node_or_null("PopupLayer/StoryOverlay/CenterContainer/StoryDialoguePanel")
	if dialogue_panel and dialogue_panel.has_method("_show_dialogues"):
		# 准备对话数据
		dialogue_panel._chapter_id = _pending_node.get("id", "")
		dialogue_panel._is_pre_battle = _pending_node.get("type", "") in ["battle", "boss"]
		dialogue_panel._dialogues = dialogues
		dialogue_panel._current_index = 0
		dialogue_panel.visible = true
		dialogue_panel._show_current_dialogue()
	else:
		# 无对话面板，直接结束
		_on_dialogue_finished()

func _on_dialogue_finished() -> void:
	# v6.6(剧情): 优先处理 NPC 支线对话播完的副作用
	if not _pending_npc_dialog.is_empty():
		NPCDialogSystem.apply_post_effects(_pending_npc_dialog)
		var npc_id: String = _pending_npc_dialog.get("npc_id", "")
		if not npc_id.is_empty() and SignalBus.has_signal("npc_event"):
			var eid: String = _pending_npc_dialog.get("entry", {}).get("id", "")
			SignalBus.npc_event.emit(npc_id, eid)
		_pending_npc_dialog = {}
		_advance_time_after_action()
		return
	# 主线节点处理
	if _pending_node.is_empty():
		return
	# v6.6(剧情)修复#1：战后对话播完 → 标记节点完成并推进时间
	if _awaiting_post_battle_dialogue:
		_awaiting_post_battle_dialogue = false
		_mark_node_done(_pending_node)
		_pending_node = {}
		_advance_time_after_action()
		return
	var node_type: String = _pending_node.get("type", "")
	match node_type:
		"battle":
			_start_story_battle(_pending_node)
			# battle/boss 节点不在对话结束时标记，等 _on_battle_ended 处理完战后对话再标记
		"boss":
			_start_story_boss(_pending_node)
		"unlock":
			_apply_unlock(_pending_node)
			_mark_node_done(_pending_node)
			_advance_time_after_action()
		"dialogue":
			# 纯对话节点：播完即完成，标记并推进时间
			_mark_node_done(_pending_node)
			_advance_time_after_action()
		_:
			_mark_node_done(_pending_node)
			_advance_time_after_action()
	_pending_node = {}

func _start_story_battle(node: Dictionary) -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm == null:
		return
	var level: int = int(node.get("level_override", 1))
	gm.set_current_level(level)
	gm.go_to_battle()

func _start_story_boss(node: Dictionary) -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm == null:
		return
	var custom: Dictionary = node.get("custom_battle", {})
	gm.current_level = int(node.get("level_override", 100))
	gm._is_phase_master_battle = true
	gm._current_phase_master = gm._build_story_master_config(custom)
	# v6.6(剧情): 最终战标记（补剧情.txt 第十幕 第100关记忆场景视觉）
	if bool(node.get("is_final", false)) and gm.has_method("set_final_battle"):
		gm.set_final_battle(true)
	gm.go_to_battle()

func _apply_unlock(node: Dictionary) -> void:
	var content: Dictionary = node.get("unlock_content", {})
	# 解锁内容主要是数据标记，城市地点的开放由 available_from_day 控制
	# 这里可以触发额外信号
	if content.has("location"):
		if SignalBus.has_signal("show_toast"):
			SignalBus.show_toast.emit("新地点已开放：%s" % content.get("note", ""))

func _show_ending(node: Dictionary) -> void:
	var is_good: bool = node.get("ending_type", "good") == "good"
	var ending_panel: Node = get_node_or_null("/root/EndingPanel")
	if ending_panel == null:
		# 尝试从场景获取
		var main_scene: Node = get_tree().current_scene
		if main_scene:
			ending_panel = main_scene.get_node_or_null("PopupLayer/StoryOverlay/CenterContainer/EndingPanel")
	if ending_panel and ending_panel.has_method("show_ending"):
		ending_panel.show_ending(is_good)
	else:
		# 无结局面板，直接显示对话然后轮回
		_show_dialogues(node.get("dialogues", []))

# ═══════════════════════════════════════════════════════════════════
# 地点行动
# ═══════════════════════════════════════════════════════════════════

func _on_location_clicked(location_id: String) -> void:
	var loc: Dictionary = CityLocs.get_location(location_id)
	if loc.is_empty():
		return
	# v6.6(剧情): 优先检查该地点是否有 NPC 支线对话应触发（按 force_location 匹配）
	# 例如：市场(market)触发林薇、训练场(training_ground)触发扎克、指挥部(command_center)触发海伦/洛克
	if _day_clock != null:
		var npc_instr: Dictionary = NPCDialogSystem.check_location_npc_event(location_id, _day_clock.current_day)
		if not npc_instr.is_empty():
			_play_npc_dialogue(npc_instr)
			return
	var actions: Array = loc.get("actions", [])
	if actions.is_empty():
		return
	# v6.6(剧情): action 选择 — 多 action 地点（如 void_rift）随机选一个，体现"不稳定裂隙"的不确定性
	# 单 action 地点仍直接执行第一个
	var action: String = actions[0]
	if actions.size() > 1:
		action = actions[randi() % actions.size()]
	_execute_location_action(location_id, action)

func _execute_location_action(location_id: String, action: String) -> void:
	match action:
		"main_story":
			# 指挥部：检查主线
			_check_main_story_node()
		"quest_board":
			# 任务板：打开任务面板
			_open_quest_panel()
			_advance_time_after_action()
		"battle":
			# 训练场/边境：随机战斗
			_start_training_battle()
		"shop":
			# 市场：打开商店
			_open_shop()
			_advance_time_after_action()
		"enhance":
			# 强化
			_open_enhance()
			_advance_time_after_action()
		"rune_shop":
			_open_rune_panel()
			_advance_time_after_action()
		"boss_battle":
			_start_training_boss()
		"rune_drop":
			# v6.6(剧情): 虚空裂隙符文挑战（补剧情.txt 高风险高回报）
			_try_rune_drop()
			_advance_time_after_action()
		"rest":
			_do_rest()
		"intel":
			_open_intel()
			_advance_time_after_action()
		_:
			_advance_time_after_action()

func _start_training_battle() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm == null:
		return
	# 根据当前进度选关卡
	var level: int = clampi(_day_clock.current_day / 4, 1, 100)
	gm.set_current_level(level)
	gm.go_to_battle()

func _start_training_boss() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm == null:
		return
	# 虚空裂隙：随机Boss战（15%概率）
	if randf() < 0.15:
		gm.current_level = clampi(_day_clock.current_day / 4, 20, 100)
		gm._is_phase_master_battle = true
		# 使用默认Boss选择逻辑
		var master: Dictionary = gm.check_phase_master_encounter()
		if not master.is_empty():
			gm._current_phase_master = gm._enrich_master_config(master)
	else:
		_start_training_battle()

## v6.6(剧情): 虚空裂隙符文挑战（补剧情.txt 高风险高回报）
## 30% 概率获得一个玩家未拥有的随机符文，70% 概率只得到少量纳米材料补偿
## 消耗一个时段（由调用方 _advance_time_after_action 推进）
func _try_rune_drop() -> void:
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	if pim == null or not pim.has_method("add_owned_rune"):
		if SignalBus.has_signal("show_toast"):
			SignalBus.show_toast.emit("相位仪系统未就绪")
		return
	var roll: float = randf()
	if roll < 0.30:
		# 30% 概率：尝试给一个未拥有的符文
		var all_ids: Array = RuneDefinitions.get_all_ids()
		var owned: Array = []
		if pim.has_method("get_owned_runes"):
			owned = pim.get_owned_runes()
		var candidates: Array = []
		for rid in all_ids:
			if not owned.has(rid):
				candidates.append(rid)
		if candidates.is_empty():
			# 全部拥有，给纳米材料补偿
			_grant_compensation_nano(200, "所有符文已收集")
			return
		var chosen_id: String = String(candidates[randi() % candidates.size()])
		var rune_name: String = RuneDefinitions.get_rune_name(chosen_id)
		var is_new: bool = pim.add_owned_rune(chosen_id)
		if SignalBus.has_signal("show_toast"):
			if is_new:
				SignalBus.show_toast.emit("✦ 虚空裂隙馈赠：获得符文【%s】！" % rune_name)
			else:
				_grant_compensation_nano(100, "重复符文，转为纳米材料")
	else:
		# 70% 概率：少量纳米材料补偿
		_grant_compensation_nano(50, "虚空裂隙这次没有回应")

## v6.6(剧情): 符文挑战的纳米材料补偿
func _grant_compensation_nano(amount: int, reason: String) -> void:
	var brm: Node = get_node_or_null("/root/BasicResourceManager")
	if brm and brm.has_method("add_resource"):
		brm.add_resource("nano_materials", amount)
	if SignalBus.has_signal("show_toast"):
		SignalBus.show_toast.emit("%s（+%d 纳米材料）" % [reason, amount])

func _open_quest_panel() -> void:
	_open_panel("quest")

func _open_shop() -> void:
	_open_panel("store")

func _open_enhance() -> void:
	_open_panel("enhancement")

func _open_rune_panel() -> void:
	_open_panel("rune")

func _open_intel() -> void:
	_open_panel("info")

## v6.6(剧情): 通过 main_scene 打开功能面板（真实接线，替代原 toast 占位）
## panel_key 对应 main.gd _overlay_for_panel_key 的键：quest/store/enhancement/rune/info/backpack/faction 等
## city_map 保持可见，被功能面板 overlay 遮挡；面板关闭后自然露出 city_map
func _open_panel(panel_key: String) -> void:
	var main_scene: Node = get_tree().current_scene
	if main_scene == null:
		if SignalBus.has_signal("show_toast"):
			SignalBus.show_toast.emit("面板暂不可用")
		return
	# 复用 main.gd 的 _toggle_overlay 流程（含 lazy load + closed 信号连接）
	if main_scene.has_method("_toggle_overlay"):
		var overlay: Control = main_scene._overlay_for_panel_key(panel_key) if main_scene.has_method("_overlay_for_panel_key") else null
		if overlay == null:
			if SignalBus.has_signal("show_toast"):
				SignalBus.show_toast.emit("未知面板: %s" % panel_key)
			return
		# 若面板已打开则不再重复触发（避免 toggle 把已开的关掉）
		if overlay.visible:
			return
		main_scene._toggle_overlay(overlay, panel_key)
	else:
		# main_scene 无 _toggle_overlay（降级），发 toast 提示
		if SignalBus.has_signal("show_toast"):
			SignalBus.show_toast.emit("面板暂不可用")

func _do_rest() -> void:
	if _day_clock:
		_day_clock.rest_until_dawn()

# ═══════════════════════════════════════════════════════════════════
# 时间推进
# ═══════════════════════════════════════════════════════════════════

func _advance_time_after_action() -> void:
	if _day_clock == null:
		return
	_day_clock.advance_phase()
	_refresh_all()

func _on_time_changed(_day: int, _phase: int) -> void:
	_refresh_all()

func _on_day_started(day: int) -> void:
	_refresh_all()
	# v6.6(剧情): 每天刷新战力缓存（HUD 用缓存高频显示，避免每帧重算）
	var gm_init: Node = get_node_or_null("/root/GameManager")
	if gm_init and gm_init.has_method("refresh_power_rating"):
		gm_init.refresh_power_rating()
	# 新的一天提示
	if SignalBus.has_signal("show_toast"):
		SignalBus.show_toast.emit("第%d天开始" % day)
	# v6.6(剧情): 按天数自动解锁应登场的 story NPC（洛克/林薇/扎克/海伦/真实者）
	var cm: Node = get_node_or_null("/root/CharacterManager")
	if cm and cm.has_method("unlock_story_npcs_for_day"):
		cm.unlock_story_npcs_for_day(day)
	# v6.6(剧情): 关键天数信号触发（海伦引导/全城紧急事件）
	_trigger_key_day_signals(day)
	# v6.6(剧情): 检查今日是否有 NPC 支线对话应触发（force_location 为空的）
	_check_daily_npc_dialogue(day)

## v6.6(剧情): 关键天数信号触发（补剧情.txt 中的全城事件）
func _trigger_key_day_signals(day: int) -> void:
	# 第18天：海伦引导"东区7号有适合你的卡"
	if day == 18 and SignalBus.has_signal("helen_guidance"):
		SignalBus.helen_guidance.emit("东区7号传送门刷新了适合你的卡")
	# 第340天：海伦宣告倒计时25天（全城紧急事件 + 奖励×3 真实生效）
	if day == 340 and SignalBus.has_signal("city_emergency"):
		SignalBus.city_emergency.emit("距离能量罩归零还有25天，奖励×3，传送门全天开放")
		# 接入 DropManager.set_multiplier 让倒计时奖励×3 真实生效（补剧情.txt L123）
		var dm: Node = get_node_or_null("/root/DropManager")
		if dm and dm.has_method("set_multiplier"):
			dm.set_multiplier(3.0)

## v6.6(剧情): 检查每日 NPC 支线对话（无 force_location 约束的）
func _check_daily_npc_dialogue(day: int) -> void:
	# 如果有主线节点待处理，优先主线，NPC 对话延后
	if not _pending_node.is_empty():
		return
	var instruction: Dictionary = NPCDialogSystem.check_daily_npc_events(day)
	if instruction.is_empty():
		return
	_play_npc_dialogue(instruction)

## v6.6(剧情): 播放 NPC 支线对话（复用 StoryDialoguePanel）
func _play_npc_dialogue(instruction: Dictionary) -> void:
	var lines: Array = instruction.get("lines", [])
	if lines.is_empty():
		# 无对话内容，直接应用副作用
		NPCDialogSystem.apply_post_effects(instruction)
		return
	var dialogue_panel: Node = get_node_or_null("StoryDialoguePanel")
	if dialogue_panel == null:
		var main_scene: Node = get_tree().current_scene
		if main_scene:
			dialogue_panel = main_scene.get_node_or_null("PopupLayer/StoryOverlay/CenterContainer/StoryDialoguePanel")
	if dialogue_panel and dialogue_panel.has_method("_show_current_dialogue"):
		_pending_npc_dialog = instruction
		dialogue_panel._chapter_id = "npc_" + instruction.get("npc_id", "")
		dialogue_panel._is_pre_battle = false
		dialogue_panel._dialogues = lines
		dialogue_panel._current_index = 0
		# v6.6(剧情): 传递分支选择关联的任务 id（真实者加入/拒绝/拖延）
		dialogue_panel._pending_quest_id = String(instruction.get("entry", {}).get("quest_id_for_choice", ""))
		dialogue_panel.visible = true
		dialogue_panel._show_current_dialogue()
	else:
		# 无对话面板可用，降级为直接应用副作用
		NPCDialogSystem.apply_post_effects(instruction)

## v6.6(剧情): 玩家在对话面板做出分支选择（真实者 join/reject/delay）
## 转发给 QuestManager.set_quest_branch 记录选择并揭示分支后续任务
func _on_story_choice_made(quest_id: String, branch_key: String) -> void:
	var qm: Node = get_node_or_null("/root/QuestManager")
	if qm and qm.has_method("set_quest_branch"):
		qm.set_quest_branch(quest_id, branch_key)
	if SignalBus.has_signal("show_toast"):
		SignalBus.show_toast.emit("已记录你的选择")

func _on_year_end() -> void:
	# 第365天结束，触发最终Boss
	var final_node: Dictionary = StoryNodes.get_final_boss_node()
	if not final_node.is_empty():
		_trigger_story_node(final_node)

## v6.6(剧情): 战斗开始 — 隐藏 city_map 及其父级 StoryOverlay，让出屏幕给战斗 HUD（背包/相位仪/法则）
## city_map 挂在 PopupLayer/StoryOverlay/CenterContainer，StoryOverlay 是全屏 Control(MOUSE_FILTER_STOP)，
## 不隐藏会拦截 HudLayer(layer 40) 战斗功能栏的所有点击，导致战斗中无法打开背包和相位仪
func _on_battle_started() -> void:
	visible = false
	# 隐藏整个 StoryOverlay（含 CenterContainer），彻底让出屏幕
	var story_overlay: Node = get_node_or_null("../..")
	if story_overlay and story_overlay is Control:
		(story_overlay as Control).visible = false

func _on_battle_ended(player_won: bool) -> void:
	# v6.6(剧情)修复#3：区分 city_map 发起的战斗（_pending_node 非空）和外部发起的战斗（空）
	# 外部战斗（如从背包点开始战斗）不归 city_map 管，不恢复 StoryOverlay/不推进时间
	if _pending_node.is_empty() and _pending_npc_dialog.is_empty():
		# 非剧情战斗：city_map 保持隐藏（main.gd 会处理战后流程）
		# 仅在 city_map 本来可见时才恢复（避免干扰自由模式）
		return
	# 战斗结束后回到城市地图
	visible = true
	# v6.6(剧情): 恢复 StoryOverlay 可见（战斗开始时隐藏了整个 overlay）
	var story_overlay: Node = get_node_or_null("../..")
	if story_overlay and story_overlay is Control:
		(story_overlay as Control).visible = true
	# 如果是Boss战且是最终Boss
	if not _pending_node.is_empty() and _pending_node.get("is_final", false):
		# v6.6(剧情): 最终战胜利 → 解锁成就 + 标记通关（补剧情.txt L141）
		if player_won:
			var sm_win: Node = get_node_or_null("/root/StoryManager")
			if sm_win and sm_win.has_method("set_story_flag"):
				sm_win.set_story_flag(StoryFlags.PASSED_100, true)
			var am: Node = get_node_or_null("/root/AchievementManager")
			if am == null:
				ManagerLazyLoader.ensure_loaded("achievement")
				am = get_node_or_null("/root/AchievementManager")
			if am and am.has_method("unlock_achievement"):
				am.unlock_achievement("phase_master")
		_mark_node_done(_pending_node)
		_pending_node = {}
		var ending_node: Dictionary = StoryNodes.get_ending_node(player_won)
		if not ending_node.is_empty():
			_show_ending(ending_node)
		return
	# 普通战斗：显示战后对话（如有），然后推进时间
	if not _pending_node.is_empty():
		var post_dlg: Array = _pending_node.get("post_battle_dialogues", [])
		if not post_dlg.is_empty():
			# 战后对话播完后由 _on_dialogue_finished 收尾（但那时 _pending_node 还在）
			# 需要特殊处理：战后对话播完后标记节点完成+推进时间
			_show_post_battle_dialogues(post_dlg)
			return
		# 无战后对话：立即标记完成并推进时间
		_mark_node_done(_pending_node)
		_pending_node = {}
	_advance_time_after_action()

## v6.6(剧情)修复#1：播放战后对话，播完后标记节点完成
## 复用 _pending_node 机制：战后对话播完会触发 story_dialogue_finished → _on_dialogue_finished
## 但 _on_dialogue_finished 对非空 _pending_node 会尝试重新触发 battle/boss，需用 _awaiting_post_battle_dialogue 区分
func _show_post_battle_dialogues(post_dlg: Array) -> void:
	_awaiting_post_battle_dialogue = true
	_show_dialogues(post_dlg)

# ═══════════════════════════════════════════════════════════════════
# 按钮事件
# ═══════════════════════════════════════════════════════════════════

func _on_rest_pressed() -> void:
	_do_rest()

func _on_advance_pressed() -> void:
	_advance_time_after_action()

func _on_exit_pressed() -> void:
	visible = false
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("exit_story_mode"):
		gm.exit_story_mode()

func show_city_map() -> void:
	visible = true
	# v6.6(剧情): 重新进入城市时刷新战力缓存（战斗后关卡/卡牌可能变化）
	var gm_show: Node = get_node_or_null("/root/GameManager")
	if gm_show and gm_show.has_method("refresh_power_rating"):
		gm_show.refresh_power_rating()
	_refresh_all()
