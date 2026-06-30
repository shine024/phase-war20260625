extends Control
## 剧情对话面板（v6.8 底部条带·沉浸式重做）
##
## 显示角色对话，支持多句队列播放、分支选项、同关多剧情排队。
## v6.8: 删除剧情模式后，本面板仅服务 v6.7 自由模式关卡剧情任务
## （由 GameManager._check_story_mission_pre/post_battle 通过 story_mission_dialogue 信号触发）。
##
## 布局（底部条带·沉浸式，参考 JRPG 底部对话框范式，配色用 Phase War 霓虹深色）:
##   - 战场在上半屏始终可见（暗化层 alpha 仅 0.5，对话叠加演出）
##   - 对话条带锚定屏幕底部居中，霓虹青紫描边 + 阴影发光
##   - 头像徽章从条带左上角探出（负边距溢出框外）
##   - 说话者名牌钉在条带上沿，按角色变色
##   - 四角宝石点缀，右下闪烁"继续 ▼"指示器
##   - 点击屏幕任意处推进对话（选项节点显示时禁用，防误触）

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
var _choices_active: bool = false   ## 当前是否正在显示选项（显示时禁用点击推进）

## 玩家在对话中做出分支选择（补剧情.txt 真实者 join/reject/delay）
signal story_choice_made(quest_id: String, branch_key: String)

# ── UI 元素引用 ──
var _dim_layer: ColorRect = null               ## 全屏暗化层（点击推进 + 战场压暗）
var _chapter_title_label: Label = null         ## 章节标题（浮在条带上方）
var _strip: Panel = null                       ## 底部对话条带（纯 Panel，手工放置，避免容器自动尺寸冲突）
var _body_label: RichTextLabel = null          ## 对话正文
var _nameplate_panel: Panel = null             ## 说话者名牌（钉条带上沿）
var _nameplate_label: Label = null
var _portrait_badge: Panel = null              ## 头像徽章（探出条带左上）
var _portrait_label: Label = null              ## 徽章中心首字（fallback）
var _portrait_sprite: Sprite2D = null          ## 实际头像图片
var _continue_label: Label = null              ## 右下"继续 ▼"指示器
var _blink_tween: Tween = null                 ## 指示器闪烁动画

# ── 布局常量（屏幕坐标，基于 1280x720）──
# v7.x 布局修复：条带浮在中场，避让底部 HUD（BattleBottomBar 占 y=596~720，高 124px）
# _STRIP_BOTTOM_GAP=150 → 条带底边 y=570（HUD 顶部 596 之上，零重叠）
# _STRIP_H 由 196 压到 168 → 条带顶边 y≈402（远离战场顶部状态栏，且长文不溢出）
const _STRIP_W := 920.0
const _STRIP_H := 168.0
const _STRIP_BOTTOM_GAP := 150.0
const _BADGE_SIZE := 96.0
# 底部 HUD 高度（dim_layer 在此高度以下留出透明通道，不压暗 HUD）
const _HUD_BOTTOM_CLEARANCE := 124.0

## 角色名 → portrait路径映射表
const _PORTRAIT_MAP := {
	"指挥官": "res://ui/portraits/player.png",
	"陈末": "res://ui/portraits/player.png",
	"托马斯": "res://ui/portraits/thomas.png",
	"soldier_thomas": "res://ui/portraits/soldier_thomas.png",
	"索菲亚": "res://ui/portraits/sophia.png",
	"维克多": "res://ui/portraits/victor.png",
	"艾莉亚": "res://ui/portraits/aria.png",
	"诺瓦": "res://ui/portraits/nova.png",
	"洛克": "res://ui/portraits/locke.png",
	"林薇": "res://ui/portraits/linwei.png",
	"扎克": "res://ui/portraits/zack.png",
	"海伦": "res://ui/portraits/helen.png",
	"真实者": "res://ui/portraits/realist.png",
	"铁血男爵": "res://ui/portraits/boss_baron.png",
	"钢铁元帅": "res://ui/portraits/boss_marshall.png",
	"相位之主": "res://ui/portraits/boss_phase_lord.png",
	"守护者": "res://ui/portraits/boss_guardian.png",
	"虚空领主": "res://ui/portraits/boss_void_lord.png",
	"镜像": "res://ui/portraits/boss_mirror.png",
	"镜像守护者": "res://ui/portraits/boss_mirror.png",
}

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
	if _blink_tween != null and _blink_tween.is_valid():
		_blink_tween.kill()

# ═══════════════════════════════════════════════════════════════════
# UI 构建（v6.8 底部条带·沉浸式）
# ═══════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_custom_minimum_size(Vector2(900, 400))
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 暗化层（v7.x: 底部留出 _HUD_BOTTOM_CLEARANCE 通道，避让 BattleBottomBar；
	# alpha 0.5→0.65 提升长文对比度；承担"点击推进"，覆盖中场上半屏 + 条带区域）
	_dim_layer = ColorRect.new()
	_dim_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim_layer.offset_bottom = -_HUD_BOTTOM_CLEARANCE  # 底边停在 y=596，HUD 区域不被压暗
	_dim_layer.color = Color(0.02, 0.04, 0.08, 0.65)
	_dim_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim_layer.gui_input.connect(_on_advance_input)
	add_child(_dim_layer)

	# ── 以下装饰节点统一锚定"底部中心点"，用像素偏移定位到条带区域 ──
	# 章节标题（浮在条带正上方，居中）
	_chapter_title_label = Label.new()
	_anchor_bottom_center(_chapter_title_label)
	_place_rect(_chapter_title_label, -300, 300, -(_STRIP_H + _STRIP_BOTTOM_GAP + 58), -(_STRIP_H + _STRIP_BOTTOM_GAP + 24))
	_chapter_title_label.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_LARGE)
	_chapter_title_label.add_theme_color_override("font_color", DesignTokens.COLOR_ACCENT_CYAN)
	_chapter_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chapter_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_chapter_title_label)

	# 底部对话条带（纯 Panel，霓虹描边 + 阴影发光；内部标签手工放置，规避 fit_content 与容器尺寸冲突）
	_strip = Panel.new()
	_anchor_bottom_center(_strip)
	_place_rect(_strip, -_STRIP_W / 2.0, _STRIP_W / 2.0, -(_STRIP_H + _STRIP_BOTTOM_GAP), -_STRIP_BOTTOM_GAP)
	_strip.add_theme_stylebox_override("panel", _make_strip_style())
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_strip)

	# 对话正文（直接放在条带上，左侧留出徽章宽度，关闭 fit_content 用显式锚定，避免容器尺寸打架）
	# v7.x: 正文字号 20→16（中文长句更舒展，配合 _STRIP_H 收窄后不溢出）
	_body_label = RichTextLabel.new()
	_body_label.bbcode_enabled = true
	_body_label.fit_content = false
	_body_label.add_theme_font_size_override("normal_font_size", DesignTokens.FONT_SIZE_MEDIUM)
	_body_label.add_theme_color_override("default_color", DesignTokens.COLOR_TEXT)
	_body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 相对条带：左留徽章宽度，右留 24 内边距，上留 24，下留 40（给指示器让位）
	_body_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_body_label.offset_left = _BADGE_SIZE - 4
	_body_label.offset_right = -DesignTokens.PADDING_LARGE
	_body_label.offset_top = DesignTokens.PADDING_LARGE + 6
	_body_label.offset_bottom = -40
	_strip.add_child(_body_label)

	# 头像徽章（探出条带左上角，负偏移溢出框外）
	_portrait_badge = Panel.new()
	_anchor_bottom_center(_portrait_badge)
	# 从条带左上角向左上探出约 60px
	_place_rect(_portrait_badge, -_STRIP_W / 2.0 + 12.0, -_STRIP_W / 2.0 + 12.0 + _BADGE_SIZE, -(_STRIP_H + _STRIP_BOTTOM_GAP) - 40.0, -(_STRIP_H + _STRIP_BOTTOM_GAP) - 40.0 + _BADGE_SIZE)
	_portrait_badge.add_theme_stylebox_override("panel", _make_badge_style(DesignTokens.COLOR_ACCENT_CYAN))
	_portrait_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_portrait_badge)

	_portrait_label = Label.new()
	_portrait_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_portrait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_portrait_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_portrait_label.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_TITLE)
	_portrait_label.add_theme_color_override("font_color", DesignTokens.COLOR_ACCENT_CYAN)
	_portrait_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_badge.add_child(_portrait_label)

	# 头像图片（覆盖在徽章上，有图片时隐藏首字）
	_portrait_sprite = Sprite2D.new()
	_portrait_sprite.scale = Vector2(_BADGE_SIZE / 512.0, _BADGE_SIZE / 512.0)
	_portrait_sprite.offset = Vector2(-256.0, -256.0)
	# Sprite2D 继承自 Node2D，无 mouse_filter 属性（Control 专属）；
	# 父徽章 _portrait_badge 已设为 MOUSE_FILTER_IGNORE，Sprite2D 本身不接收点击事件，无需单独设置。
	_portrait_sprite.visible = false
	_portrait_badge.add_child(_portrait_sprite)

	# 说话者名牌（钉条带上沿，徽章右侧，按角色变色；纯 Panel + 直接放标签，避免 PanelContainer 与固定 placement 混用）
	_nameplate_panel = Panel.new()
	_anchor_bottom_center(_nameplate_panel)
	var np_x := -_STRIP_W / 2.0 + 12.0 + _BADGE_SIZE - 8.0
	_place_rect(_nameplate_panel, np_x, np_x + 190.0, -(_STRIP_H + _STRIP_BOTTOM_GAP) - 20.0, -(_STRIP_H + _STRIP_BOTTOM_GAP) - 20.0 + 32.0)
	_nameplate_panel.add_theme_stylebox_override("panel", _make_nameplate_style(DesignTokens.COLOR_ACCENT_CYAN))
	_nameplate_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_nameplate_panel)

	_nameplate_label = Label.new()
	_nameplate_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_nameplate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nameplate_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_nameplate_label.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_MEDIUM)
	_nameplate_label.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT)
	_nameplate_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nameplate_panel.add_child(_nameplate_label)

	# 四角宝石点缀
	for corner in ["tl", "tr", "bl", "br"]:
		add_child(_make_gem(corner))

	# 右下"继续 ▼"指示器（闪烁）
	_continue_label = Label.new()
	_anchor_bottom_center(_continue_label)
	_place_rect(_continue_label, _STRIP_W / 2.0 - 200.0, _STRIP_W / 2.0 - 24.0, -_STRIP_BOTTOM_GAP - 44.0, -_STRIP_BOTTOM_GAP - 22.0)
	_continue_label.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_SMALL + 2)
	_continue_label.add_theme_color_override("font_color", DesignTokens.COLOR_ACCENT_CYAN)
	_continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_continue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_continue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_continue_label.text = "继续 ▼"
	add_child(_continue_label)
	_start_blink()

	# v6.6(剧情): 选项按钮容器（浮在条带上方居中，默认隐藏）
	# 锚定到"条带顶部"往上约 140px 的一块区域，选项自底向上堆叠
	_choices_container = VBoxContainer.new()
	_anchor_bottom_center(_choices_container)
	# 底边贴条带顶部（-(_STRIP_H + _STRIP_BOTTOM_GAP)），顶边再往上留 140 容纳多个选项
	_place_rect(_choices_container, -320.0, 320.0, -(_STRIP_H + _STRIP_BOTTOM_GAP) - 150.0, -(_STRIP_H + _STRIP_BOTTOM_GAP) - 12.0)
	_choices_container.alignment = BoxContainer.ALIGNMENT_END
	_choices_container.add_theme_constant_override("separation", DesignTokens.PADDING_SMALL)
	_choices_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choices_container.visible = false
	add_child(_choices_container)

## 把节点锚定到"底部中心点"（anchor_left=anchor_right=0.5, anchor_top=anchor_bottom=1.0）
func _anchor_bottom_center(c: Control) -> void:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_top = 1.0
	c.anchor_bottom = 1.0

## 在底部中心点坐标系下，用像素偏移设定节点矩形（offset 即相对锚点的像素坐标）
func _place_rect(c: Control, left: float, right: float, top: float, bottom: float) -> void:
	c.offset_left = left
	c.offset_right = right
	c.offset_top = top
	c.offset_bottom = bottom

## 对话条带 StyleBox（深色面板 + 青紫双描边 + 阴影发光 + 大圆角）
func _make_strip_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.10, 0.16, 0.96)
	s.border_width_left = 3
	s.border_width_right = 3
	s.border_width_top = 3
	s.border_width_bottom = 3
	# 双色描边：用紫色主描边
	s.border_color = DesignTokens.COLOR_ACCENT_PURPLE
	s.corner_radius_top_left = 14
	s.corner_radius_top_right = 14
	s.corner_radius_bottom_left = 14
	s.corner_radius_bottom_right = 14
	# 霓虹发光阴影
	s.shadow_color = DesignTokens.COLOR_ACCENT_PURPLE
	s.shadow_size = 14
	s.content_margin_left = DesignTokens.PADDING_MEDIUM
	s.content_margin_right = DesignTokens.PADDING_MEDIUM
	s.content_margin_top = DesignTokens.PADDING_SMALL
	s.content_margin_bottom = DesignTokens.PADDING_SMALL
	return s

## 头像徽章 StyleBox（圆形，角色色描边 + 深色填充）
func _make_badge_style(accent: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.10, 0.12, 0.18, 0.98)
	s.border_width_left = 4
	s.border_width_right = 4
	s.border_width_top = 4
	s.border_width_bottom = 4
	s.border_color = accent
	# 全圆角（半径 = 一半边长）
	s.corner_radius_top_left = int(_BADGE_SIZE / 2.0)
	s.corner_radius_top_right = int(_BADGE_SIZE / 2.0)
	s.corner_radius_bottom_left = int(_BADGE_SIZE / 2.0)
	s.corner_radius_bottom_right = int(_BADGE_SIZE / 2.0)
	s.shadow_color = accent
	s.shadow_size = 10
	return s

## 名牌 StyleBox（v7.x: 收敛为深色底 + 角色色描边，避免大面积角色铺色与紫青主调撞色）
func _make_nameplate_style(accent: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.08, 0.14, 0.92)  # 与条带背景同源深色
	s.border_width_left = 2
	s.border_width_right = 2
	s.border_width_top = 2
	s.border_width_bottom = 2
	s.border_color = accent  # 角色色仅用于描边区分说话者
	s.corner_radius_top_left = 4
	s.corner_radius_top_right = 4
	s.corner_radius_bottom_left = 4
	s.corner_radius_bottom_right = 4
	return s
	return s

## 四角宝石（小菱形，旋转 45°，霓虹点缀）
func _make_gem(corner: String) -> ColorRect:
	var g := ColorRect.new()
	_anchor_bottom_center(g)
	var size := 10.0
	var half_w := _STRIP_W / 2.0
	var top := -(_STRIP_H + _STRIP_BOTTOM_GAP)
	var bottom := -_STRIP_BOTTOM_GAP
	match corner:
		"tl": _place_rect(g, -half_w - size / 2.0, -half_w + size / 2.0, top - size / 2.0, top + size / 2.0)
		"tr": _place_rect(g, half_w - size / 2.0, half_w + size / 2.0, top - size / 2.0, top + size / 2.0)
		"bl": _place_rect(g, -half_w - size / 2.0, -half_w + size / 2.0, bottom - size / 2.0, bottom + size / 2.0)
		"br": _place_rect(g, half_w - size / 2.0, half_w + size / 2.0, bottom - size / 2.0, bottom + size / 2.0)
	g.color = DesignTokens.COLOR_ACCENT_CYAN
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 旋转成菱形（以中心为轴）
	g.pivot_offset = Vector2(size / 2.0, size / 2.0)
	g.rotation = PI / 4.0
	return g

## 右下指示器闪烁动画（循环）
func _start_blink() -> void:
	_blink_tween = create_tween()
	_blink_tween.set_loops()
	_blink_tween.tween_property(_continue_label, "modulate:a", 0.25, 0.6)
	_blink_tween.tween_property(_continue_label, "modulate:a", 1.0, 0.6)

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
	_update_nameplate(speaker)
	_update_portrait_badge(speaker)
	_body_label.text = text
	# v6.6(剧情): 检测选项节点（choices 字段存在时显示选项按钮，隐藏继续指示器）
	var choices: Array = dlg.get("choices", [])
	if not choices.is_empty() and not _choice_made:
		_choices_active = true
		_continue_label.visible = false
		_show_choices(choices)
	else:
		_choices_active = false
		_continue_label.visible = true
		_clear_choices()
		_set_continue_text()

## 更新名牌（v7.x: 深色底 + 角色色描边 + 角色色文字，角色标识鲜明且不撞主调）
func _update_nameplate(speaker: String) -> void:
	var accent: Color = _get_speaker_color(speaker)
	_nameplate_label.text = speaker
	_nameplate_label.add_theme_color_override("font_color", accent)
	_nameplate_panel.add_theme_stylebox_override("panel", _make_nameplate_style(accent))

## 更新头像徽章（角色色描边 + 首字/实际图片）
func _update_portrait_badge(speaker: String) -> void:
	var accent: Color = _get_speaker_color(speaker)
	_portrait_badge.add_theme_stylebox_override("panel", _make_badge_style(accent))
	
	# 查找portrait路径
	var portrait_path: String = _PORTRAIT_MAP.get(speaker, "")
	if portrait_path and ResourceLoader.exists(portrait_path):
		var tex = load(portrait_path) as Texture2D
		if tex != null:
			_portrait_sprite.texture = tex
			_portrait_sprite.visible = true
			_portrait_label.visible = false
			return
	
	# Fallback: 显示首字徽章
	_portrait_sprite.visible = false
	_portrait_label.visible = true
	_portrait_label.text = _get_initial_char(speaker)
	_portrait_label.add_theme_color_override("font_color", accent)

## 角色名首字（徽章中心显示，如"林薇"→"林"）
func _get_initial_char(speaker: String) -> String:
	if speaker.is_empty():
		return "?"
	return speaker.substr(0, 1)

## 设置右下指示器文字（最后一句显示不同）
func _set_continue_text() -> void:
	if _current_index == _dialogues.size() - 1:
		_continue_label.text = "开始战斗 ⚔" if _is_pre_battle else "继续 ▶"
	else:
		_continue_label.text = "继续 ▼"

## v6.6(剧情): 渲染选项按钮（补剧情.txt 真实者分支选择）
func _show_choices(choices: Array) -> void:
	_clear_choices()
	for choice in choices:
		if not (choice is Dictionary):
			continue
		var btn := Button.new()
		btn.text = String(choice.get("text", "???"))
		btn.custom_minimum_size = Vector2(620, DesignTokens.BUTTON_HEIGHT)
		btn.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_MEDIUM)
		# 选项按钮样式：角色色边框
		var bs := StyleBoxFlat.new()
		bs.bg_color = Color(0.12, 0.14, 0.22, 0.96)
		bs.border_width_left = 2
		bs.border_width_right = 2
		bs.border_width_top = 2
		bs.border_width_bottom = 2
		bs.border_color = DesignTokens.COLOR_ACCENT_PURPLE
		bs.corner_radius_top_left = 6
		bs.corner_radius_top_right = 6
		bs.corner_radius_bottom_left = 6
		bs.corner_radius_bottom_right = 6
		bs.content_margin_left = DesignTokens.PADDING_MEDIUM
		bs.content_margin_right = DesignTokens.PADDING_MEDIUM
		btn.add_theme_stylebox_override("normal", bs)
		btn.add_theme_stylebox_override("hover", _make_choice_hover_style())
		btn.add_theme_stylebox_override("pressed", _make_choice_hover_style())
		var bk: String = String(choice.get("branch_key", ""))
		var response: Array = choice.get("response", [])
		btn.pressed.connect(_on_choice_selected.bind(bk, response))
		_choices_container.add_child(btn)
	_choices_container.visible = true

func _make_choice_hover_style() -> StyleBoxFlat:
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.20, 0.16, 0.34, 0.98)
	bs.border_width_left = 2
	bs.border_width_right = 2
	bs.border_width_top = 2
	bs.border_width_bottom = 2
	bs.border_color = DesignTokens.COLOR_ACCENT_CYAN
	bs.corner_radius_top_left = 6
	bs.corner_radius_top_right = 6
	bs.corner_radius_bottom_left = 6
	bs.corner_radius_bottom_right = 6
	bs.content_margin_left = DesignTokens.PADDING_MEDIUM
	bs.content_margin_right = DesignTokens.PADDING_MEDIUM
	return bs

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
	_choices_active = false
	_clear_choices()
	_continue_label.visible = true
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

## v6.8(沉浸式): 点击屏幕任意处推进对话（选项节点显示时禁用，防误触）
func _on_advance_input(event: InputEvent) -> void:
	if not visible or _choices_active:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()
	elif event is InputEventScreenTouch and event.pressed:
		_advance()

func _advance() -> void:
	_current_index += 1
	if _current_index >= _dialogues.size():
		_on_all_dialogues_done()
	else:
		_show_current_dialogue()

func _on_all_dialogues_done() -> void:
	visible = false
	_dialogues.clear()
	_clear_choices()
	_choices_active = false
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
		# v7.3 修复配色缺漏: 补守护者/虚空领主/镜像配色（原落到默认红，语义偏差）
		"守护者":
			# 中立/引导：青蓝色（神秘但非反派）
			return Color(0.3, 0.7, 0.9)
		"虚空领主":
			# 虚空系Boss：深紫红（危险但区别于普通红Boss）
			return Color(0.7, 0.2, 0.6)
		"镜像", "镜像守护者":
			# 玩家镜像：冷银色（复制/虚幻）
			return Color(0.75, 0.78, 0.85)
		_:
			# 默认：Boss/未知角色用红色系
			return DesignTokens.COLOR_DANGER
