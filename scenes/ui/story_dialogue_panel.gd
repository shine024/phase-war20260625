extends Control
## 剧情对话面板（v6.8 底部条带·沉浸式重做 / v7.x 美化增强 / v7.x 双立绘规范化）
##
## 显示角色对话，支持多句队列播放、分支选项、同关多剧情排队。
## v6.8: 删除剧情模式后，本面板仅服务 v6.7 自由模式关卡剧情任务
## （由 GameManager._check_story_mission_pre/post_battle 通过 story_mission_dialogue 信号触发）。
## v7.x 美化:
##   - 头像统一圆形遮罩（修复 200px/512px 混合尺寸导致"一张大一张小"）
##   - 左侧角色色光带 + 章节banner + 打字机逐字 + 徽章入场动画
## v7.x 双立绘规范化（Galgame 范式）:
##   - 左右各一个全身立绘位（540×720），我方陈末恒在左、NPC/Boss 恒在右
##   - 当前说话者立绘全亮前移，未说话者暗化后退；中立 speaker 两侧都暗化
##   - 96 圆形徽章位置随说话者方位浮动（player→条带左上, npc/enemy→条带右上）
##   - speaker→阵营/方位/立绘/配色由 SpeakerRegistry 集中管理，对话数据零改动
##
## 布局（双立绘 + 底部对话框，配色用 Phase War 霓虹深色）:
##   - 战场在中场可见（暗化层 alpha 0.65，对话叠加演出）
##   - 左右立绘贴屏幕两侧（不挡中部 920 宽底部对话框）
##   - 对话条带锚定屏幕底部居中，霓虹青紫描边 + 阴影发光 + 左侧角色色光带
##   - 头像徽章从条带左上/右上角探出（按说话者方位浮动，圆形遮罩 + 角色色描边）
##   - 章节标题（半透明banner）浮在条带正上方
##   - 说话者名牌钉在条带上沿，按角色变色
##   - 对话正文逐字浮现（打字机），点击可跳过补全
##   - 四角宝石点缀，右下闪烁"继续 ▼"指示器
##   - 点击屏幕任意处推进对话（选项节点显示时禁用，防误触）

const DesignTokens = preload("res://resources/design_tokens.gd")
## speaker 注册表（阵营/方位/立绘路径/配色集中管理）
const SpeakerRegistry = preload("res://data/speaker_registry.gd")
## 圆形头像遮罩 shader（方形纹理裁圆，配合徽章角色色描边）
const _CircleMaskShader := preload("res://shaders/portrait_circle_mask.gdshader")

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
var _chapter_title_label: Label = null         ## 章节标题（浮在 banner 上）
var _chapter_banner: Panel = null              ## 章节 banner 底条（v7.x 美化）
var _strip: Panel = null                       ## 底部对话条带（纯 Panel，手工放置，避免容器自动尺寸冲突）
var _left_accent_bar: ColorRect = null         ## 左侧角色色光带（v7.x 美化，随说话者变色）
var _body_label: RichTextLabel = null          ## 对话正文
var _nameplate_panel: Panel = null             ## 说话者名牌（钉条带上沿）
var _nameplate_label: Label = null
var _portrait_badge: Panel = null              ## 头像徽章（探出条带左上）
var _portrait_label: Label = null              ## 徽章中心首字（fallback）
var _portrait_rect: TextureRect = null         ## 头像图片（v7.x: TextureRect + 圆形遮罩，统一尺寸）
var _continue_label: Label = null              ## 右下"继续 ▼"指示器
var _blink_tween: Tween = null                 ## 指示器闪烁动画
var _typewriter_tween: Tween = null            ## 打字机逐字动画（v7.x 美化）
var _badge_enter_tween: Tween = null           ## 徽章入场动画（v7.x 美化）
var _is_typing: bool = false                   ## 当前是否正在逐字播放（点击时跳过补全）

# v7.x 双立绘：左右立绘层（贴屏幕左右两侧，全身立绘 540×720）
var _left_stage: Control = null                ## 左立绘容器（我方陈末）
var _left_portrait: TextureRect = null         ## 左立绘图片
var _right_stage: Control = null               ## 右立绘容器（NPC/Boss）
var _right_portrait: TextureRect = null        ## 右立绘图片
var _stage_tween: Tween = null                 ## 立绘切换过渡动画
# 立绘层最后绑定的 speaker（避免同 speaker 重复触发过渡动画）
var _left_stage_speaker: String = ""
var _right_stage_speaker: String = ""

# ── 布局常量（屏幕坐标，基于 1280x720）──
# v7.x 布局修复：条带浮在中场，避让底部 HUD（BattleBottomBar 占 y=596~720，高 124px）
# _STRIP_BOTTOM_GAP=150 → 条带底边 y=570（HUD 顶部 596 之上，零重叠）
# _STRIP_H 由 196 压到 168 → 条带顶边 y≈402（远离战场顶部状态栏，且长文不溢出）
const _STRIP_W := 920.0
const _STRIP_H := 168.0
const _STRIP_BOTTOM_GAP := 150.0
const _BADGE_SIZE := 96.0
const _ACCENT_BAR_W := 5.0           ## 左侧角色色光带宽度（v7.x 美化）
# 底部 HUD 高度（dim_layer 在此高度以下留出透明通道，不压暗 HUD）
const _HUD_BOTTOM_CLEARANCE := 124.0
# 打字机逐字速度（秒/字，v7.x 美化）
const _TYPEWRITER_SEC_PER_CHAR := 0.025
# v7.x 双立绘规范：全身立绘规格（产出标准，旧图任意尺寸自动适配）
const _STAGE_W := 540.0              ## 立绘宽（占屏幕 540/1280 ≈ 42%）
const _STAGE_H := 720.0              ## 立绘高（满屏高）
# 立绘状态：说话者全亮前移 / 非说话者暗化后退
const _STAGE_ACTIVE_MODULATE := 1.0
const _STAGE_DIM_MODULATE := 0.35
const _STAGE_ACTIVE_SCALE := 1.0
const _STAGE_DIM_SCALE := 0.95
const _STAGE_TRANSITION_SEC := 0.2

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
	if _typewriter_tween != null and _typewriter_tween.is_valid():
		_typewriter_tween.kill()
	if _badge_enter_tween != null and _badge_enter_tween.is_valid():
		_badge_enter_tween.kill()
	if _stage_tween != null and _stage_tween.is_valid():
		_stage_tween.kill()

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

	# v7.x 双立绘：左右立绘层贴屏幕左右两侧（在条带/banner/徽章之前添加，确保位于底部图层）
	_build_left_stage()
	_build_right_stage()

	# ── 以下装饰节点统一锚定"底部中心点"，用像素偏移定位到条带区域 ──
	# 章节 banner（半透明深色底条 + 角色色细描边，浮在条带正上方居中，v7.x 美化）
	_chapter_banner = Panel.new()
	_anchor_bottom_center(_chapter_banner)
	_place_rect(_chapter_banner, -330.0, 330.0, -(_STRIP_H + _STRIP_BOTTOM_GAP + 60.0), -(_STRIP_H + _STRIP_BOTTOM_GAP + 24.0))
	_chapter_banner.add_theme_stylebox_override("panel", _make_chapter_banner_style())
	_chapter_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_chapter_banner)

	# 章节标题（浮在 banner 正中）
	_chapter_title_label = Label.new()
	_chapter_title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chapter_title_label.offset_left = 12.0
	_chapter_title_label.offset_right = -12.0
	_chapter_title_label.offset_top = 0.0
	_chapter_title_label.offset_bottom = 0.0
	_chapter_title_label.add_theme_font_size_override("font_size", DesignTokens.FONT_SIZE_LARGE)
	_chapter_title_label.add_theme_color_override("font_color", DesignTokens.COLOR_ACCENT_CYAN)
	_chapter_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chapter_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_chapter_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chapter_banner.add_child(_chapter_title_label)

	# 底部对话条带（纯 Panel，霓虹描边 + 阴影发光；内部标签手工放置，规避 fit_content 与容器尺寸冲突）
	_strip = Panel.new()
	_anchor_bottom_center(_strip)
	_place_rect(_strip, -_STRIP_W / 2.0, _STRIP_W / 2.0, -(_STRIP_H + _STRIP_BOTTOM_GAP), -_STRIP_BOTTOM_GAP)
	_strip.add_theme_stylebox_override("panel", _make_strip_style())
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_strip)

	# 左侧角色色光带（条带最左缘竖条，随说话者变色，v7.x 美化）
	_left_accent_bar = ColorRect.new()
	_left_accent_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_left_accent_bar.offset_left = 0.0
	_left_accent_bar.offset_right = _ACCENT_BAR_W
	_left_accent_bar.offset_top = 0.0
	_left_accent_bar.offset_bottom = 0.0
	_left_accent_bar.color = DesignTokens.COLOR_ACCENT_CYAN
	_left_accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.add_child(_left_accent_bar)

	# 对话正文（直接放在条带上，左侧留出徽章宽度 + 光带宽度，关闭 fit_content 用显式锚定，避免容器尺寸打架）
	# v7.x: 正文字号 20→16（中文长句更舒展，配合 _STRIP_H 收窄后不溢出）
	# v7.x: offset_left 增加 _ACCENT_BAR_W 给左侧角色色光带让位
	_body_label = RichTextLabel.new()
	_body_label.bbcode_enabled = true
	_body_label.fit_content = false
	_body_label.add_theme_font_size_override("normal_font_size", DesignTokens.FONT_SIZE_MEDIUM)
	_body_label.add_theme_color_override("default_color", DesignTokens.COLOR_TEXT)
	_body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 相对条带：左留徽章宽度+光带，右留 24 内边距，上留 24，下留 40（给指示器让位）
	_body_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_body_label.offset_left = _BADGE_SIZE + _ACCENT_BAR_W - 4
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

	# 头像图片（v7.x: TextureRect + 圆形遮罩 shader，统一渲染为 96×96 圆形）
	# 取代原 Sprite2D（硬编码 512 导致 200px/512px 混合尺寸显示一大一小）。
	# IGNORE_SIZE 忽略源纹理尺寸，KEEP_ASPECT_COVERED 让任意比例图片 cover 填满不变形，
	# 圆形遮罩 shader 把方形裁成正圆，与徽章角色色描边完美贴合。
	_portrait_rect = TextureRect.new()
	_portrait_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_portrait_rect.offset_left = 0.0
	_portrait_rect.offset_right = 0.0
	_portrait_rect.offset_top = 0.0
	_portrait_rect.offset_bottom = 0.0
	_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait_rect.custom_minimum_size = Vector2(_BADGE_SIZE, _BADGE_SIZE)
	var mask_mat := ShaderMaterial.new()
	mask_mat.shader = _CircleMaskShader
	_portrait_rect.material = mask_mat
	_portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_rect.visible = false
	_portrait_badge.add_child(_portrait_rect)

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

# ═══════════════════════════════════════════════════════════════════
# v7.x 双立绘层构建与切换
# ═══════════════════════════════════════════════════════════════════

## 构建左立绘层（占屏幕左侧 540×720 竖条，纹理居中保持比例）
## 关键：限制 stage 自身区域为屏幕左 540px，立绘 TextureRect 在该区域内居中，
## 避免左右两侧立绘都跑到屏幕中央互相覆盖。
func _build_left_stage() -> void:
	_left_stage = Control.new()
	_left_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 锚定屏幕左侧竖条：x=[0, 540], y=[0, 720]（屏幕 1280×720）
	# offset 定位：anchor 全 0（左上角原点），offset 直接是像素坐标
	_left_stage.anchor_left = 0.0
	_left_stage.anchor_top = 0.0
	_left_stage.anchor_right = 0.0
	_left_stage.anchor_bottom = 0.0
	_left_stage.offset_left = 0.0
	_left_stage.offset_top = 0.0
	_left_stage.offset_right = _STAGE_W  # 540
	_left_stage.offset_bottom = _STAGE_H  # 720
	add_child(_left_stage)
	_left_portrait = _make_stage_portrait()
	_left_stage.add_child(_left_portrait)

## 构建右立绘层（占屏幕右侧 540×720 竖条，纹理居中保持比例）
func _build_right_stage() -> void:
	_right_stage = Control.new()
	_right_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 锚定屏幕右侧竖条：x=[740, 1280], y=[0, 720]（中间 540~740 留 200px 给对话框）
	_right_stage.anchor_left = 0.0
	_right_stage.anchor_top = 0.0
	_right_stage.anchor_right = 0.0
	_right_stage.anchor_bottom = 0.0
	_right_stage.offset_left = 1280.0 - _STAGE_W  # 740
	_right_stage.offset_top = 0.0
	_right_stage.offset_right = 1280.0  # 屏幕右边
	_right_stage.offset_bottom = _STAGE_H  # 720
	add_child(_right_stage)
	_right_portrait = _make_stage_portrait()
	_right_stage.add_child(_right_portrait)

## 创建一个立绘 TextureRect（贴屏幕一侧、纵向占满 720、横向 540 居中保持比例）
func _make_stage_portrait() -> TextureRect:
	var tex := TextureRect.new()
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)  # 占满父级（父级是 FULL_RECT 的 _left/_right_stage）
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE  # 忽略源图尺寸（适配任意大小）
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED  # 保持比例居中
	tex.custom_minimum_size = Vector2(_STAGE_W, _STAGE_H)
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.visible = false  # 默认隐藏，speaker 切换时显示
	tex.modulate = Color(1, 1, 1, _STAGE_DIM_MODULATE)  # 默认暗化
	return tex

## 切换说话者时更新左右立绘状态（亮/暗/scale + 立绘图片加载）
## 由 _show_current_dialogue 调用
func _update_portrait_stages(speaker: String) -> void:
	var side: String = SpeakerRegistry.get_side(speaker)
	var portrait_path: String = SpeakerRegistry.get_portrait_path(speaker)

	# ── 加载立绘图片到对应侧（仅当 speaker 有立绘且与当前该侧 speaker 不同时切换）──
	# 左侧立绘仅装 player 阵营 speaker
	if side == "left":
		if _left_stage_speaker != speaker:
			_load_stage_texture(_left_portrait, portrait_path)
			_left_stage_speaker = speaker
	# 右侧立绘装 npc/enemy speaker
	elif side == "right":
		if _right_stage_speaker != speaker:
			_load_stage_texture(_right_portrait, portrait_path)
			_right_stage_speaker = speaker

	# ── 计算两侧目标状态 ──
	# active=说话者侧全亮+前移, dim=另一侧暗化+后退, neutral=两侧都暗化
	var left_active: bool = (side == "left")
	var right_active: bool = (side == "right")
	# 立绘不可见的侧直接置 dim（避免空立绘位突兀亮起）
	if not _left_portrait.visible:
		left_active = false
	if not _right_portrait.visible:
		right_active = false

	_tween_stage(_left_portrait, left_active)
	_tween_stage(_right_portrait, right_active)

## 加载立绘路径到 TextureRect（路径空或不存在则隐藏该侧立绘）
func _load_stage_texture(tex: TextureRect, portrait_path: String) -> void:
	if portrait_path.is_empty() or not ResourceLoader.exists(portrait_path):
		tex.visible = false
		tex.texture = null
		return
	var loaded = load(portrait_path) as Texture2D
	if loaded == null:
		tex.visible = false
		tex.texture = null
		return
	tex.texture = loaded
	tex.visible = true

## 用 tween 过渡立绘的 modulate.a 和 scale（active 全亮前移 / dim 暗化后退）
func _tween_stage(tex: TextureRect, active: bool) -> void:
	if not tex.visible:
		return
	if _stage_tween != null and _stage_tween.is_valid():
		_stage_tween.kill()
	_stage_tween = create_tween()
	_stage_tween.set_parallel(true)
	# scale 围绕底部中心（立绘脚位）缩放，避免上下漂移
	# pivot 用 stage 容器尺寸（540×720）而非 tex.size（布局前可能为 0）
	var target_scale := _STAGE_ACTIVE_SCALE if active else _STAGE_DIM_SCALE
	var target_alpha := _STAGE_ACTIVE_MODULATE if active else _STAGE_DIM_MODULATE
	tex.pivot_offset = Vector2(_STAGE_W / 2.0, _STAGE_H)
	tex.scale = Vector2(target_scale, target_scale)
	_stage_tween.tween_property(tex, "modulate:a", target_alpha, _STAGE_TRANSITION_SEC).set_ease(Tween.EASE_OUT)
	_stage_tween.tween_property(tex, "scale", Vector2(target_scale, target_scale), _STAGE_TRANSITION_SEC).set_ease(Tween.EASE_OUT)

## 隐藏所有立绘层（对话结束时调用，避免下一轮对话残留上一轮立绘）
func _clear_stages() -> void:
	_left_portrait.visible = false
	_left_portrait.texture = null
	_left_stage_speaker = ""
	_right_portrait.visible = false
	_right_portrait.texture = null
	_right_stage_speaker = ""

## 对话条带 StyleBox（深色面板 + 青紫双描边 + 阴影发光 + 大圆角）
## v7.x: shadow_size 14→16 增强霓虹氛围
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
	s.shadow_size = 16
	s.content_margin_left = DesignTokens.PADDING_MEDIUM
	s.content_margin_right = DesignTokens.PADDING_MEDIUM
	s.content_margin_top = DesignTokens.PADDING_SMALL
	s.content_margin_bottom = DesignTokens.PADDING_SMALL
	return s

## 章节 banner StyleBox（半透明深色底 + 青色细描边 + 小圆角，v7.x 美化）
func _make_chapter_banner_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.09, 0.15, 0.92)
	s.border_width_left = 1
	s.border_width_right = 1
	s.border_width_top = 1
	s.border_width_bottom = 1
	s.border_color = DesignTokens.COLOR_ACCENT_CYAN
	s.corner_radius_top_left = 8
	s.corner_radius_top_right = 8
	s.corner_radius_bottom_left = 8
	s.corner_radius_bottom_right = 8
	s.shadow_color = DesignTokens.COLOR_ACCENT_CYAN
	s.shadow_size = 8
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
	_update_portrait_stages(speaker)  # v7.x 双立绘：左右立绘按 speaker 阵营亮/暗切换
	_update_nameplate(speaker)
	_update_portrait_badge(speaker)
	_update_accent_bar(speaker)  # v7.x 美化：左侧光带随说话者变色
	_body_label.text = text
	# v7.x 美化：打字机逐字显示
	_start_typewriter(text)
	# v6.6(剧情): 检测选项节点（choices 字段存在时显示选项按钮，隐藏继续指示器）
	var choices: Array = dlg.get("choices", [])
	if not choices.is_empty() and not _choice_made:
		_choices_active = true
		_continue_label.visible = false
		_show_choices(choices)
	else:
		_choices_active = false
		# 打字机播完前不显示继续指示器（_start_typewriter 内 _on_typewriter_done 会显示）
		if not _is_typing:
			_continue_label.visible = true
		_clear_choices()
		_set_continue_text()

## v7.x 美化：打字机逐字显示对话正文（可点击跳过补全）
func _start_typewriter(text: String) -> void:
	_stop_typewriter()
	var char_count := text.length()
	if char_count <= 0:
		_is_typing = false
		return
	_is_typing = true
	_continue_label.visible = false  # 播放期间隐藏继续指示器
	_body_label.visible_characters = 0
	_body_label.visible_ratio = 0.0
	var duration := char_count * _TYPEWRITER_SEC_PER_CHAR
	_typewriter_tween = create_tween()
	_typewriter_tween.tween_property(_body_label, "visible_ratio", 1.0, duration).set_ease(Tween.EASE_IN_OUT)
	_typewriter_tween.tween_callback(_on_typewriter_done)

## 打字机播完：显示继续指示器
func _on_typewriter_done() -> void:
	_is_typing = false
	_body_label.visible_ratio = 1.0
	# 仅在非选项分支时显示继续指示器（选项分支由 _show_choices 管理可见性）
	if not _choices_active:
		_continue_label.visible = true

## 停止打字机（清理 tween，不重置文字）
func _stop_typewriter() -> void:
	if _typewriter_tween != null and _typewriter_tween.is_valid():
		_typewriter_tween.kill()
		_typewriter_tween = null

## v7.x 美化：打字机跳过补全（点击时若正在逐字显示，直接显示全文，不推进对话）
## 返回 true 表示本次点击用于跳过（已补全），调用方不再推进
func _skip_typewriter_if_typing() -> bool:
	if _is_typing:
		_stop_typewriter()
		_body_label.visible_ratio = 1.0
		_is_typing = false
		if not _choices_active:
			_continue_label.visible = true
		return true
	return false

## v7.x 美化：左侧角色色光带随说话者变色（与名牌/徽章描边同色，角色色贯穿三处）
func _update_accent_bar(speaker: String) -> void:
	_left_accent_bar.color = _get_speaker_color(speaker)

## 更新名牌（v7.x: 深色底 + 角色色描边 + 角色色文字，角色标识鲜明且不撞主调）
func _update_nameplate(speaker: String) -> void:
	var accent: Color = _get_speaker_color(speaker)
	_nameplate_label.text = speaker
	_nameplate_label.add_theme_color_override("font_color", accent)
	_nameplate_panel.add_theme_stylebox_override("panel", _make_nameplate_style(accent))

## 更新头像徽章（角色色描边 + 圆形遮罩图片/首字 + 入场弹入动画）
## v7.x 双立绘：徽章位置随说话者方位浮动（player→条带左上, npc/enemy→条带右上, neutral→左上默认）
func _update_portrait_badge(speaker: String) -> void:
	var accent: Color = _get_speaker_color(speaker)
	_portrait_badge.add_theme_stylebox_override("panel", _make_badge_style(accent))
	# v7.x 双立绘：徽章随说话者方位浮动（与全身立绘侧一致，强化左右方位感）
	_position_badge_by_side(SpeakerRegistry.get_side(speaker))

	# v7.x: 立绘路径改查 SpeakerRegistry（替代原内联 _PORTRAIT_MAP）
	var portrait_path: String = SpeakerRegistry.get_portrait_path(speaker)
	if portrait_path and ResourceLoader.exists(portrait_path):
		var tex = load(portrait_path) as Texture2D
		if tex != null:
			# v7.x: TextureRect 自动处理任意源图尺寸（200px/512px 都 cover 填充为统一圆形）
			_portrait_rect.texture = tex
			_portrait_rect.visible = true
			_portrait_label.visible = false
			_play_badge_enter()
			return

	# Fallback: 显示首字徽章
	_portrait_rect.visible = false
	_portrait_label.visible = true
	_portrait_label.text = _get_initial_char(speaker)
	_portrait_label.add_theme_color_override("font_color", accent)
	_play_badge_enter()

## v7.x 双立绘：按说话者方位重定位 96 圆形徽章
## side="left"  → 条带左上角探出（默认，我方陈末）
## side="right" → 条带右上角探出（NPC/Boss）
## side="center"→ 左上默认（中立叙述，无方位归属）
func _position_badge_by_side(side: String) -> void:
	_anchor_bottom_center(_portrait_badge)
	var strip_top: float = -(_STRIP_H + _STRIP_BOTTOM_GAP)
	var probe: float = 40.0  # 探出条带顶部的偏移
	if side == "right":
		# 右上角：右缘对齐条带右边 - 12px 内缩
		_place_rect(_portrait_badge, \
			_STRIP_W / 2.0 - 12.0 - _BADGE_SIZE, \
			_STRIP_W / 2.0 - 12.0, \
			strip_top - probe, \
			strip_top - probe + _BADGE_SIZE)
	else:
		# 左上角（left/center 默认）：左缘对齐条带左边 + 12px 内缩
		_place_rect(_portrait_badge, \
			-_STRIP_W / 2.0 + 12.0, \
			-_STRIP_W / 2.0 + 12.0 + _BADGE_SIZE, \
			strip_top - probe, \
			strip_top - probe + _BADGE_SIZE)

## v7.x 美化：徽章入场动画（切换说话者时 scale 0.85→1.0 + 透明度 0.3→1.0，150ms 弹入）
func _play_badge_enter() -> void:
	if _badge_enter_tween != null and _badge_enter_tween.is_valid():
		_badge_enter_tween.kill()
	# pivot 设到徽章中心，让 scale 绕中心缩放
	_portrait_badge.pivot_offset = Vector2(_BADGE_SIZE / 2.0, _BADGE_SIZE / 2.0)
	_portrait_badge.scale = Vector2(0.85, 0.85)
	_portrait_badge.modulate.a = 0.3
	_badge_enter_tween = create_tween()
	_badge_enter_tween.set_parallel(true)
	_badge_enter_tween.tween_property(_portrait_badge, "scale", Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_badge_enter_tween.tween_property(_portrait_badge, "modulate:a", 1.0, 0.15).set_ease(Tween.EASE_OUT)
	# 动画结束后还原 scale，避免累积漂移
	_badge_enter_tween.chain().tween_callback(func(): _portrait_badge.scale = Vector2.ONE)

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
## v7.x: 若正在打字机逐字显示，第一次点击只跳过补全，不推进对话（符合 JRPG 习惯）
func _on_advance_input(event: InputEvent) -> void:
	if not visible or _choices_active:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _skip_typewriter_if_typing():
			return  # 本次点击用于跳过打字机，不推进
		_advance()
	elif event is InputEventScreenTouch and event.pressed:
		if _skip_typewriter_if_typing():
			return
		_advance()

func _advance() -> void:
	_current_index += 1
	if _current_index >= _dialogues.size():
		_on_all_dialogues_done()
	else:
		_show_current_dialogue()

func _on_all_dialogues_done() -> void:
	visible = false
	_stop_typewriter()  # v7.x: 清理打字机 tween
	_is_typing = false
	_dialogues.clear()
	_clear_stages()  # v7.x 双立绘：清理左右立绘，避免下一轮对话残留
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
	# v7.x 双立绘规范化：配色改由 SpeakerRegistry 集中管理（替代原内联 match）
	# 注册表覆盖所有已注册 speaker + 别名，未注册 speaker 默认红色（与历史 fallback 一致）
	return SpeakerRegistry.get_color(speaker)
