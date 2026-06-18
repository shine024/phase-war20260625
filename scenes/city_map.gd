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

var _day_clock: Node = null
var _location_buttons: Dictionary = {}  # location_id -> Button
var _phase_overlay: ColorRect = null
var _time_label: Label = null
var _hint_label: Label = null
var _pending_node: Dictionary = {}  ## 待处理的主线节点

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
		if SignalBus.has_signal("battle_ended") and SignalBus.battle_ended.is_connected(_on_battle_ended):
			SignalBus.battle_ended.disconnect(_on_battle_ended)

# ═══════════════════════════════════════════════════════════════════
# UI 构建
# ═══════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 城市背景
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.05, 0.1, 1.0)  # 深蓝黑底色
	add_child(bg)

	# 时段蒙板（覆盖在背景上）
	_phase_overlay = ColorRect.new()
	_phase_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_phase_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phase_overlay.color = Color(1, 1, 1, 0)
	add_child(_phase_overlay)

	# 顶部HUD
	_build_top_hud()

	# 地点按钮层
	_build_location_buttons()

	# 底部按钮栏
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
	var bottom := HBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -50
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", DesignTokens.BUTTON_SPACING)
	add_child(bottom)

	# 休息按钮
	var rest_btn := Button.new()
	rest_btn.text = "☾ 休息（跳到明天）"
	rest_btn.custom_minimum_size = Vector2(180, DesignTokens.BUTTON_HEIGHT)
	rest_btn.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_MEDIUM)
	rest_btn.pressed.connect(_on_rest_pressed)
	bottom.add_child(rest_btn)

	# 推进时段按钮
	var advance_btn := Button.new()
	advance_btn.text = "▶ 推进时间"
	advance_btn.custom_minimum_size = Vector2(140, DesignTokens.BUTTON_HEIGHT)
	advance_btn.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_MEDIUM)
	advance_btn.pressed.connect(_on_advance_pressed)
	bottom.add_child(advance_btn)

	# 退出按钮
	var exit_btn := Button.new()
	exit_btn.text = "返回自由模式"
	exit_btn.custom_minimum_size = Vector2(150, DesignTokens.BUTTON_HEIGHT)
	exit_btn.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_MEDIUM)
	exit_btn.pressed.connect(_on_exit_pressed)
	bottom.add_child(exit_btn)

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
	var sm: Node = get_node_or_null("/root/StoryManager")
	if sm and sm.has_method("is_chapter_completed"):
		if sm.is_chapter_completed(node.get("id", "")):
			return  # 已处理，不再触发
	# 触发主线节点
	_trigger_story_node(node)

# ═══════════════════════════════════════════════════════════════════
# 主线节点触发
# ═══════════════════════════════════════════════════════════════════

func _trigger_story_node(node: Dictionary) -> void:
	_pending_node = node
	var node_type: String = node.get("type", "dialogue")
	# 标记节点为已触发（避免重复）
	var sm: Node = get_node_or_null("/root/StoryManager")
	if sm and sm.has_method("complete_chapter"):
		sm.complete_chapter(node.get("id", ""))
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
			_show_ending(node)
		_:
			_show_dialogues(node.get("dialogues", []))

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
	if _pending_node.is_empty():
		return
	var node_type: String = _pending_node.get("type", "")
	match node_type:
		"battle":
			_start_story_battle(_pending_node)
		"boss":
			_start_story_boss(_pending_node)
		"unlock":
			_apply_unlock(_pending_node)
			_advance_time_after_action()
		"dialogue":
			# 纯对话节点也推进时间
			_advance_time_after_action()
		_:
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
	var actions: Array = loc.get("actions", [])
	if actions.is_empty():
		return
	# 简化版：每个地点执行其第一个action
	# 实际可以做行动选择菜单，这里先直接执行
	var action: String = actions[0]
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

func _open_quest_panel() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm and gm.main_scene:
		# 触发任务面板（通过SignalBus）
		if SignalBus.has_signal("show_toast"):
			SignalBus.show_toast.emit("任务板已打开")

func _open_shop() -> void:
	if SignalBus.has_signal("show_toast"):
		SignalBus.show_toast.emit("商店已打开")

func _open_enhance() -> void:
	if SignalBus.has_signal("show_toast"):
		SignalBus.show_toast.emit("强化工坊已打开")

func _open_rune_panel() -> void:
	if SignalBus.has_signal("show_toast"):
		SignalBus.show_toast.emit("符文研究所已打开")

func _open_intel() -> void:
	if SignalBus.has_signal("show_toast"):
		SignalBus.show_toast.emit("情报已更新")

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
	# 新的一天提示
	if SignalBus.has_signal("show_toast"):
		SignalBus.show_toast.emit("第%d天开始" % day)

func _on_year_end() -> void:
	# 第365天结束，触发最终Boss
	var final_node: Dictionary = StoryNodes.get_final_boss_node()
	if not final_node.is_empty():
		_trigger_story_node(final_node)

func _on_battle_ended(player_won: bool) -> void:
	# 战斗结束后回到城市地图
	visible = true
	# 如果是Boss战且是最终Boss
	if not _pending_node.is_empty() and _pending_node.get("is_final", false):
		var ending_node: Dictionary = StoryNodes.get_ending_node(player_won)
		if not ending_node.is_empty():
			_show_ending(ending_node)
		return
	# 普通战斗：显示战后对话（如有），然后推进时间
	if not _pending_node.is_empty():
		var post_dlg: Array = _pending_node.get("post_battle_dialogues", [])
		if not post_dlg.is_empty():
			_show_dialogues(post_dlg)
			return
	_advance_time_after_action()

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
	_refresh_all()
