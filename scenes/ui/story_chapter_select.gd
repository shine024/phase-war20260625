extends Control
## v6.3 剧情模式章节选择面板
##
## 显示所有章节列表，按进度解锁。点击已解锁章节进入剧情。

const DesignTokens = preload("res://resources/design_tokens.gd")
const StoryChaptersData = preload("res://data/story_chapters.gd")

var _sm: Node = null  ## StoryManager 引用
var _chapter_list: VBoxContainer = null
var _progress_label: Label = null

func _ready() -> void:
	_sm = get_node_or_null("/root/StoryManager")
	_build_ui()
	visible = false
	if SignalBus.has_signal("story_show_chapter_select"):
		SignalBus.story_show_chapter_select.connect(_on_show)

func _exit_tree() -> void:
	if SignalBus != null and SignalBus.has_signal("story_show_chapter_select"):
		if SignalBus.story_show_chapter_select.is_connected(_on_show):
			SignalBus.story_show_chapter_select.disconnect(_on_show)

# ═══════════════════════════════════════════════════════════════════
# UI 构建
# ═══════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 背景遮罩
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.04, 0.08, 0.9)
	add_child(bg)
	
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 560)
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
	
	# 标题
	var title := Label.new()
	title.text = "⚔ 剧情模式"
	title.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_TITLE)
	title.add_theme_color_override("font_color", DesignTokens.COLOR_ACCENT_PURPLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# 进度标签
	_progress_label = Label.new()
	_progress_label.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_SMALL)
	_progress_label.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT)
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_progress_label)
	
	# 分隔线
	vbox.add_child(HSeparator.new())
	
	# 章节列表（可滚动）
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	_chapter_list = VBoxContainer.new()
	_chapter_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chapter_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_chapter_list)
	
	# 底部按钮栏
	var btn_box := HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", DesignTokens.BUTTON_SPACING)
	vbox.add_child(btn_box)
	
	# 返回自由模式按钮
	var back_btn := Button.new()
	back_btn.text = "返回自由模式"
	back_btn.custom_minimum_size = Vector2(150, DesignTokens.BUTTON_HEIGHT)
	back_btn.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_MEDIUM)
	back_btn.pressed.connect(_on_back_pressed)
	btn_box.add_child(back_btn)

# ═══════════════════════════════════════════════════════════════════
# 刷新逻辑
# ═══════════════════════════════════════════════════════════════════

func _on_show() -> void:
	_refresh_list()
	visible = true

func _refresh_list() -> void:
	for child in _chapter_list.get_children():
		child.queue_free()
	# 进度
	var completed: int = 0
	var total: int = StoryChaptersData.get_chapter_count()
	if _sm and _sm.has_method("get_completed_count"):
		completed = _sm.get_completed_count()
	_progress_label.text = "进度：%d / %d 章完成" % [completed, total]
	# 章节列表
	for chapter in StoryChaptersData.ALL_CHAPTERS:
		var entry := _make_chapter_entry(chapter)
		_chapter_list.add_child(entry)

func _make_chapter_entry(chapter: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 64)
	btn.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_MEDIUM)
	var ch_id: String = chapter.get("id", "")
	var ch_num: int = int(chapter.get("chapter_num", 0))
	var title: String = chapter.get("title", "")
	var subtitle: String = chapter.get("subtitle", "")
	var is_boss: bool = bool(chapter.get("is_boss_chapter", false))
	# 解锁/完成状态
	var unlocked: bool = false
	var completed: bool = false
	if _sm:
		if _sm.has_method("is_chapter_unlocked"):
			unlocked = _sm.is_chapter_unlocked(ch_id)
		if _sm.has_method("is_chapter_completed"):
			completed = _sm.is_chapter_completed(ch_id)
	# 显示文字
	var prefix: String = ""
	if is_boss:
		prefix = "💀 "  # Boss章节标记
	else:
		prefix = "📖 "
	var status: String = ""
	if completed:
		status = "  ✓"
		btn.add_theme_color_override("font_color", DesignTokens.COLOR_HEALTH)
	elif unlocked:
		status = ""
		btn.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT)
	else:
		status = "  🔒"
		btn.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
	btn.text = "%s第%d章 %s\n%s%s" % [prefix, ch_num, title, subtitle, status]
	btn.disabled = not unlocked
	if unlocked:
		btn.pressed.connect(_on_chapter_pressed.bind(ch_id))
	return btn

# ═══════════════════════════════════════════════════════════════════
# 事件处理
# ═══════════════════════════════════════════════════════════════════

func _on_chapter_pressed(chapter_id: String) -> void:
	visible = false
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("start_story_chapter"):
		gm.start_story_chapter(chapter_id)

func _on_back_pressed() -> void:
	visible = false
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("exit_story_mode"):
		gm.exit_story_mode()
