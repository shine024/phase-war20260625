extends Control
## 剧情对话面板
##
## 显示角色对话，支持多句队列播放、分支选项、同关多剧情排队。
## v6.8: 删除剧情模式后，本面板仅服务 v6.7 自由模式关卡剧情任务
## （由 GameManager._check_story_mission_pre/post_battle 通过 story_mission_dialogue 信号触发）。

const DesignTokens = preload("res://resources/design_tokens.gd")

var _dialogues: Array = []         ## 待播放的对话队列
var _current_index: int = 0        ## 当前播放到第几句
var _is_pre_battle: bool = true    ## true=战前对话, false=战后对话
var _chapter_id: String = ""

# v6.7(剧情任务): 剧情任务播放状态
# _mission_quest_id 非空时表示当前正在播关卡剧情任务对话
var _mission_quest_id: String = ""
var _mission_is_post: bool = false
# v6.7: 同关多剧情排队播放（如第20关：tutorial_rune + story_first_guardian 依次播放）
var _mission_queue: Array = []  # 待播队列，每项 {title, dialogues, quest_id, is_post}

# v6.6(剧情): 对话选项系统（补剧情.txt 第四幕真实者分支选择）
var _pending_quest_id: String = ""   ## 当前选择节点关联的任务 id（由 city_map 在播放前设置）
var _choices_container: VBoxContainer = null  ## 选项按钮容器
var _choice_made: bool = false      ## 本轮对话是否已做出选择（防重复）

## 玩家在对话中做出分支选择（补剧情.txt 真实者 join/reject/delay）
signal story_choice_made(quest_id: String, branch_key: String)

# UI元素
var _speaker_label: Label = null
var _text_label: RichTextLabel = null
var _next_button: Button = null
var _chapter_title_label: Label = null
var _portrait_rect: ColorRect = null  ## 头像占位（暂用色块，未来可替换为TextureRect）

func _ready() -> void:
	_build_ui()
	visible = false
	# v6.7(剧情任务): 关卡剧情任务对话
	if SignalBus.has_signal("story_mission_dialogue"):
		SignalBus.story_mission_dialogue.connect(_on_story_mission_dialogue)

func _exit_tree() -> void:
	if SignalBus != null:
		if SignalBus.has_signal("story_mission_dialogue") and SignalBus.story_mission_dialogue.is_connected(_on_story_mission_dialogue):
			SignalBus.story_mission_dialogue.disconnect(_on_story_mission_dialogue)

# ═══════════════════════════════════════════════════════════════════
# UI 构建
# ═══════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_custom_minimum_size(Vector2(900, 400))
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 半透明背景遮罩
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.04, 0.08, 0.85)
	add_child(bg)
	
	# 主面板容器（居中）
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(800, 320)
	center.add_child(panel)
	
	var style := StyleBoxFlat.new()
	style.bg_color = DesignTokens.COLOR_PANEL
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = DesignTokens.COLOR_ACCENT_PURPLE
	style.corner_radius_top_left = DesignTokens.CORNER_RADIUS
	style.corner_radius_top_right = DesignTokens.CORNER_RADIUS
	style.corner_radius_bottom_left = DesignTokens.CORNER_RADIUS
	style.corner_radius_bottom_right = DesignTokens.CORNER_RADIUS
	style.content_margin_left = DesignTokens.PADDING_LARGE
	style.content_margin_right = DesignTokens.PADDING_LARGE
	style.content_margin_top = DesignTokens.PADDING_MEDIUM
	style.content_margin_bottom = DesignTokens.PADDING_MEDIUM
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", DesignTokens.PADDING_SMALL)
	panel.add_child(vbox)
	
	# 章节标题
	_chapter_title_label = Label.new()
	_chapter_title_label.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_MEDIUM)
	_chapter_title_label.add_theme_color_override("font_color", DesignTokens.COLOR_ACCENT_CYAN)
	_chapter_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_chapter_title_label)
	
	# 内容区（头像 + 文字）
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", DesignTokens.PADDING_MEDIUM)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content)
	
	# 头像占位
	_portrait_rect = ColorRect.new()
	_portrait_rect.custom_minimum_size = Vector2(80, 80)
	_portrait_rect.color = DesignTokens.COLOR_ACCENT_PURPLE
	content.add_child(_portrait_rect)
	
	# 对话文字区
	var text_vbox := VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.add_theme_constant_override("separation", 6)
	content.add_child(text_vbox)
	
	# 说话者名字
	_speaker_label = Label.new()
	_speaker_label.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_MEDIUM)
	_speaker_label.add_theme_color_override("font_color", DesignTokens.COLOR_ACCENT_CYAN)
	text_vbox.add_child(_speaker_label)
	
	# 对话内容
	_text_label = RichTextLabel.new()
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.bbcode_enabled = true
	_text_label.add_theme_font_size_override("normal_font_size", DesignTokens.FONT_SIZE_MEDIUM)
	_text_label.add_theme_color_override("default_color", DesignTokens.COLOR_TEXT)
	_text_label.fit_content = true
	text_vbox.add_child(_text_label)
	
	# 底部按钮
	var btn_box := HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", DesignTokens.BUTTON_SPACING)
	vbox.add_child(btn_box)
	
	_next_button = Button.new()
	_next_button.text = "继续 ▶"
	_next_button.custom_minimum_size = Vector2(DesignTokens.BUTTON_MIN_WIDTH, DesignTokens.BUTTON_HEIGHT)
	_next_button.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_MEDIUM)
	_next_button.pressed.connect(_on_next_pressed)
	btn_box.add_child(_next_button)

	# v6.6(剧情): 选项按钮容器（默认隐藏，仅在 choices 对话节点显示）
	_choices_container = VBoxContainer.new()
	_choices_container.add_theme_constant_override("separation", DesignTokens.PADDING_SMALL)
	_choices_container.visible = false
	vbox.add_child(_choices_container)

# ═══════════════════════════════════════════════════════════════════
# 对话播放逻辑
# ═══════════════════════════════════════════════════════════════════

# v6.7(剧情任务): 关卡剧情任务对话入口
# 由 GameManager 在进关/过关时 emit story_mission_dialogue 信号触发
# 同关多剧情（如第20关 tutorial + story）依次入队，播完一个自动播下一个
func _on_story_mission_dialogue(quest_id: String, phase: String) -> void:
	if quest_id.is_empty():
		return
	var QuestDefs = preload("res://data/quest_definitions.gd")
	var def: Dictionary = QuestDefs.get_by_id(quest_id)
	if def.is_empty():
		return
	var is_post: bool = (phase == "post")
	var dialogues: Array = def.get("post_battle_dialogues", []) if is_post else def.get("pre_battle_dialogues", [])
	if dialogues.is_empty():
		return  # 该任务无对应阶段的对话，静默跳过
	var title: String = "【剧情】" + def.get("title", quest_id)
	if not is_post:
		title = "【战前】" + title
	else:
		title = "【战后】" + title
	# 若当前正在播放，加入队列等待
	if visible and not _mission_quest_id.is_empty():
		_mission_queue.append({"title": title, "dialogues": dialogues, "quest_id": quest_id, "is_post": is_post})
		return
	play_dialogues(title, dialogues, quest_id, is_post)

## v6.7(剧情任务): 通用对话播放接口（解耦自 v6.3 章节流程）
## 外部传入对话数据播放，完成后根据来源走不同回调
func play_dialogues(title: String, dialogues: Array, quest_id: String, is_post: bool) -> void:
	_chapter_id = ""  # 清空章节标记，标记为自由模式剧情任务
	_mission_quest_id = quest_id
	_mission_is_post = is_post
	_is_pre_battle = not is_post
	_dialogues = dialogues.duplicate(true)
	_current_index = 0
	_chapter_title_label.text = title
	_choice_made = false
	_pending_quest_id = quest_id  # 复用 v6.6 分支选择机制
	# v6.7: 自由模式下 StoryOverlay 默认隐藏，需确保父级 overlay 可见
	_ensure_ancestor_visible()
	_show_current_dialogue()
	visible = true

## v6.7(剧情任务): 向上遍历祖先，把所有 Control 祖先设为 visible（确保自由模式下 StoryOverlay 不挡住面板）
func _ensure_ancestor_visible() -> void:
	var p: Node = get_parent()
	while p != null:
		if p is Control:
			(p as Control).visible = true
		p = p.get_parent()

## v6.7(剧情任务): 关卡剧情任务播完后隐藏 StoryOverlay
func _hide_mission_overlay() -> void:
	var p: Node = get_parent()
	while p != null:
		if p is Control and p.name == "StoryOverlay":
			(p as Control).visible = false
			return
		p = p.get_parent()

func _show_current_dialogue() -> void:
	if _current_index >= _dialogues.size():
		_on_all_dialogues_done()
		return
	var dlg: Dictionary = _dialogues[_current_index]
	var speaker: String = dlg.get("speaker", "???")
	var text: String = dlg.get("text", "")
	_speaker_label.text = speaker
	_text_label.text = text
	# 头像颜色按角色变化
	_portrait_rect.color = _get_speaker_color(speaker)
	# v6.6(剧情): 检测选项节点（choices 字段存在时显示选项按钮，隐藏继续按钮）
	var choices: Array = dlg.get("choices", [])
	if not choices.is_empty() and not _choice_made:
		_next_button.visible = false
		_show_choices(choices)
	else:
		_next_button.visible = true
		_clear_choices()
		# 按钮文字：最后一句显示不同
		if _current_index == _dialogues.size() - 1:
			_next_button.text = "开始战斗 ⚔" if _is_pre_battle else "继续 ▶"
		else:
			_next_button.text = "继续 ▶"

## v6.6(剧情): 渲染选项按钮（补剧情.txt 真实者分支选择）
func _show_choices(choices: Array) -> void:
	_clear_choices()
	for choice in choices:
		if not (choice is Dictionary):
			continue
		var btn := Button.new()
		btn.text = String(choice.get("text", "???"))
		btn.custom_minimum_size = Vector2(600, DesignTokens.BUTTON_HEIGHT)
		btn.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_MEDIUM)
		var bk: String = String(choice.get("branch_key", ""))
		var response: Array = choice.get("response", [])
		btn.pressed.connect(_on_choice_selected.bind(bk, response))
		_choices_container.add_child(btn)
	_choices_container.visible = true

## v6.6(剧情): 清空选项按钮
func _clear_choices() -> void:
	for child in _choices_container.get_children():
		child.queue_free()
	_choices_container.visible = false

## v6.6(剧情): 玩家选择了一个分支选项
func _on_choice_selected(branch_key: String, response: Array) -> void:
	if _choice_made:
		return
	_choice_made = true
	_clear_choices()
	_next_button.visible = true
	# 发出选择信号（city_map 监听后调 QuestManager.set_quest_branch）
	if not _pending_quest_id.is_empty() and not branch_key.is_empty():
		story_choice_made.emit(_pending_quest_id, branch_key)
	# 若选项有后续 response 对话，插入队列继续播放
	if not response.is_empty():
		# 移除当前选择节点及之后的内容，插入 response
		_dialogues = _dialogues.slice(0, _current_index) + response
		_current_index = 0
		_show_current_dialogue()
	else:
		# 无后续对话，直接结束
		_on_all_dialogues_done()

func _on_next_pressed() -> void:
	_current_index += 1
	if _current_index >= _dialogues.size():
		_on_all_dialogues_done()
	else:
		_show_current_dialogue()

func _on_all_dialogues_done() -> void:
	visible = false
	_dialogues.clear()
	_clear_choices()
	# v6.6(剧情): 重置选择状态（防跨对话残留）
	_choice_made = false
	_pending_quest_id = ""
	# v6.7(剧情任务): 剧情任务播放完成 —— 只发 finished 信号
	# 战前对话完成后战斗已由 GameManager.go_to_battle 启动（信号 emit 后立即开战，对话是叠加演出）
	# 战后对话完成后任务进度已由 QuestManager 更新，无需额外推进
	_mission_quest_id = ""
	_mission_is_post = false
	# 队列里还有待播剧情（同关多剧情），播下一个，不隐藏 overlay
	if not _mission_queue.is_empty():
		var next: Dictionary = _mission_queue.pop_front()
		play_dialogues(next["title"], next["dialogues"], next["quest_id"], next["is_post"])
		return
	# 队列空了，隐藏由 _ensure_ancestor_visible 显示的 StoryOverlay
	_hide_mission_overlay()

# ═══════════════════════════════════════════════════════════════════
# 辅助
# ═══════════════════════════════════════════════════════════════════

func _get_speaker_color(speaker: String) -> Color:
	# 按角色返回不同的头像色块
	match speaker:
		"指挥官", "陈末":
			# 主角：青色（陈末是主角真名，与"指挥官"同身份）
			return DesignTokens.COLOR_ACCENT_CYAN
		"参谋长":
			return DesignTokens.COLOR_HEALTH
		"情报官":
			return DesignTokens.COLOR_ACCENT_PURPLE
		"旁白":
			return Color(0.5, 0.5, 0.55)
		# v6.6(剧情): docs/补剧情.txt 新角色配色
		"洛克":
			# 引导者：青绿色（沉稳）
			return Color(0.2, 0.8, 0.65)
		"林薇":
			# 四叶草店主：粉色（温柔）
			return Color(0.95, 0.55, 0.7)
		"扎克":
			# 训练场教官：橙色（刚毅）
			return Color(0.95, 0.65, 0.2)
		"海伦":
			# 城市播报者：金色（权威/中性）
			return Color(0.9, 0.8, 0.3)
		"真实者":
			# 反派：深紫色（神秘/危险）
			return Color(0.55, 0.25, 0.75)
		"铁血男爵", "钢铁元帅", "相位之主":
			# Boss角色：红色系
			return DesignTokens.COLOR_DANGER
		_:
			# 默认：Boss/未知角色用红色系
			return DesignTokens.COLOR_DANGER
