extends Control
## v6.3 剧情对话面板
##
## 显示角色对话，支持多句队列播放。
## 战前对话播完 → 开始战斗；战后对话播完 → 解锁下一章。

const DesignTokens = preload("res://resources/design_tokens.gd")
const StoryChaptersData = preload("res://data/story_chapters.gd")

var _dialogues: Array = []         ## 待播放的对话队列
var _current_index: int = 0        ## 当前播放到第几句
var _is_pre_battle: bool = true    ## true=战前对话, false=战后对话
var _chapter_id: String = ""

# UI元素
var _speaker_label: Label = null
var _text_label: RichTextLabel = null
var _next_button: Button = null
var _chapter_title_label: Label = null
var _portrait_rect: ColorRect = null  ## 头像占位（暂用色块，未来可替换为TextureRect）

func _ready() -> void:
	_build_ui()
	visible = false
	# 监听信号
	if SignalBus.has_signal("story_show_pre_battle_dialogue"):
		SignalBus.story_show_pre_battle_dialogue.connect(_on_show_pre_battle)
	if SignalBus.has_signal("story_show_post_battle_dialogue"):
		SignalBus.story_show_post_battle_dialogue.connect(_on_show_post_battle)

func _exit_tree() -> void:
	if SignalBus != null:
		if SignalBus.has_signal("story_show_pre_battle_dialogue") and SignalBus.story_show_pre_battle_dialogue.is_connected(_on_show_pre_battle):
			SignalBus.story_show_pre_battle_dialogue.disconnect(_on_show_pre_battle)
		if SignalBus.has_signal("story_show_post_battle_dialogue") and SignalBus.story_show_post_battle_dialogue.is_connected(_on_show_post_battle):
			SignalBus.story_show_post_battle_dialogue.disconnect(_on_show_post_battle)

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

# ═══════════════════════════════════════════════════════════════════
# 对话播放逻辑
# ═══════════════════════════════════════════════════════════════════

func _on_show_pre_battle(chapter_id: String) -> void:
	_show_dialogues(chapter_id, true)

func _on_show_post_battle(chapter_id: String) -> void:
	_show_dialogues(chapter_id, false)

func _show_dialogues(chapter_id: String, is_pre_battle: bool) -> void:
	var chapter: Dictionary = StoryChaptersData.get_chapter(chapter_id)
	if chapter.is_empty():
		# 章节不存在，直接跳过
		_on_all_dialogues_done()
		return
	_chapter_id = chapter_id
	_is_pre_battle = is_pre_battle
	var key: String = "pre_battle_dialogues" if is_pre_battle else "post_battle_dialogues"
	_dialogues = chapter.get(key, [])
	_current_index = 0
	# 设置标题
	var title_text: String = "第%d章 · %s" % [chapter.get("chapter_num", 0), chapter.get("title", "")]
	if is_pre_battle:
		title_text = "【战前】" + title_text
	else:
		title_text = "【战后】" + title_text
	_chapter_title_label.text = title_text
	if _dialogues.is_empty():
		_on_all_dialogues_done()
		return
	visible = true
	_show_current_dialogue()

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
	# 按钮文字：最后一句显示不同
	if _current_index == _dialogues.size() - 1:
		_next_button.text = "开始战斗 ⚔" if _is_pre_battle else "继续 ▶"
	else:
		_next_button.text = "继续 ▶"

func _on_next_pressed() -> void:
	_current_index += 1
	if _current_index >= _dialogues.size():
		_on_all_dialogues_done()
	else:
		_show_current_dialogue()

func _on_all_dialogues_done() -> void:
	visible = false
	_dialogues.clear()
	# 通知对话完成
	if SignalBus.has_signal("story_dialogue_finished"):
		SignalBus.story_dialogue_finished.emit()
	# 根据战前/战后执行不同后续
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm == null:
		return
	if _is_pre_battle:
		# 战前对话完成 → 进入战斗
		if gm.has_method("story_proceed_to_battle"):
			gm.story_proceed_to_battle()
	else:
		# 战后对话完成 → 推进到下一章
		if gm.has_method("story_advance_to_next"):
			gm.story_advance_to_next()

# ═══════════════════════════════════════════════════════════════════
# 辅助
# ═══════════════════════════════════════════════════════════════════

func _get_speaker_color(speaker: String) -> Color:
	# 按角色返回不同的头像色块
	match speaker:
		"指挥官":
			return DesignTokens.COLOR_ACCENT_CYAN
		"参谋长":
			return DesignTokens.COLOR_HEALTH
		"情报官":
			return DesignTokens.COLOR_ACCENT_PURPLE
		"旁白":
			return Color(0.5, 0.5, 0.55)
		_:
			# Boss角色用红色系
			return DesignTokens.COLOR_DANGER
