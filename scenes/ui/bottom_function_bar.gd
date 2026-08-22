extends PanelContainer
## 底部功能键栏：包含所有面板入口按钮
## 每个按钮点击后发出对应信号，外部统一监听并弹出面板
## 支持"当前激活按钮"高亮状态

const DT = preload("res://resources/design_tokens.gd")
const PanelStyles = preload("res://scripts/ui/panel_styles.gd")

## 播放音效（Autoload AudioManager；get_node_or_null 兜底）
func _play_sfx(name: String) -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.play_sfx(name)

signal btn_backpack_pressed
signal btn_faction_pressed
signal btn_quest_pressed
signal btn_achievement_pressed
signal btn_help_pressed
signal btn_store_pressed
signal btn_progression_pressed
signal btn_leaderboard_pressed
signal btn_info_pressed
signal btn_map_pressed
signal btn_settings_pressed
signal btn_collection_pressed
signal btn_save_pressed
signal btn_afk_pressed
signal btn_start_battle_pressed
signal btn_pause_pressed
signal btn_retreat_pressed
signal btn_back_pressed
## 兼容旧场景连接：当前版本法则入口改由底部仪表栏格子点击处理
signal btn_law_pressed

# 当前高亮的按钮 key
var _active_btn_key: String = ""

## 设为 true 时左侧功能按钮不显示中文，便于只看图标。
## 上线/正常游玩必须为 false——新手无法仅凭图标分辨 11 个功能（背包/成长/商店等）。
const DEBUG_HIDE_BOTTOM_BAR_TEXT := false

## 底部功能键 → `assets/ui/icons/<name>.svg`（优先；若无则 `.png`；无映射则仅文字）
const BTN_ICON_BY_KEY: Dictionary = {
	"backpack": "icon_backpack",
	"progression": "icon_upgrade",
	"faction": "icon_blueprint",
	"quest": "icon_quest",
	"store": "icon_shop",
	"leaderboard": "icon_leaderboard",
	"info": "icon_help",
	"map": "icon_map",
	"collection": "icon_collection",
	"settings": "icon_settings",
	"save": "icon_save",
	"afk": "icon_afk",
}

const BATTLE_BTN_ICON_BY_KEY: Dictionary = {
	"start_battle": "icon_start_battle",
	"pause": "icon_pause",
	"retreat": "icon_retreat",
	"back": "icon_arrow_left",
}

# 按钮配置：[key, 显示文字, 信号名]
# v7.x: 功能按钮全部直接显示（"更多"菜单方案因图标渲染问题暂缓，保持平铺）
# 2026-08-22 D3：补"成就/帮助"入口——两个面板早已做完（PanelChrome 统一框架）却无任何
# 开启路径（成就解锁只弹 toast 无法回看，帮助面板完全不可达），典型"功能做好了玩家看不见"。
# 14×62+间距 ≈ 940px < 1280 视口，不溢出。
const BTN_CONFIGS: Array = [
	["backpack",     "背包",   "btn_backpack_pressed"],
	["progression",  "成长",   "btn_progression_pressed"],
	["faction",      "势力",   "btn_faction_pressed"],
	["quest",        "任务",   "btn_quest_pressed"],
	["store",        "商店",   "btn_store_pressed"],
	["map",          "地图",   "btn_map_pressed"],
	["leaderboard",  "排行",   "btn_leaderboard_pressed"],
	["info",         "情报",   "btn_info_pressed"],
	["collection",   "图鉴",   "btn_collection_pressed"],
	["achievement",  "成就",   "btn_achievement_pressed"],
	["settings",     "设置",   "btn_settings_pressed"],
	["help",         "帮助",   "btn_help_pressed"],
	["save",         "存档",   "btn_save_pressed"],
	["afk",          "挂机",   "btn_afk_pressed"],
]

# 右侧战斗控制按钮（开始/暂停/撤退/返回）
const BATTLE_BTN_CONFIGS: Array = [
	["start_battle", "开始战斗", "btn_start_battle_pressed"],
	["pause",        "暂停",     "btn_pause_pressed"],
	["retreat",      "撤退",     "btn_retreat_pressed"],
	["back",         "返回",     "btn_back_pressed"],
]

# key → Button 节点的映射
var _btn_map: Dictionary = {}

@onready var left_section: HBoxContainer = $Margin/HBox/LeftSection
@onready var right_section: HBoxContainer = $Margin/HBox/RightSection

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_left_buttons()
	_build_right_buttons()
	# v7.x: 战斗控制按钮已迁移到 TopBattleControls，隐藏底部 RightSection + Divider
	# 仍保留 _build_right_buttons 创建按钮到 _btn_map（set_pause_text 回退路径依赖）
	if right_section:
		right_section.visible = false
	var divider := get_node_or_null("Margin/HBox/Divider")
	if divider:
		divider.visible = false

## 创建左侧功能按钮（12 个全部直接显示）
func _build_left_buttons() -> void:
	for cfg in BTN_CONFIGS:
		var key: String = cfg[0]
		var label_text: String = cfg[1]
		var signal_name: String = cfg[2]
		var btn := _make_func_button(label_text)
		if DEBUG_HIDE_BOTTOM_BAR_TEXT:
			btn.text = ""
		_apply_bar_icon(btn, BTN_ICON_BY_KEY.get(key, ""))
		btn.add_theme_constant_override("icon_max_width", 30)
		if key == "save":
			btn.pressed.connect(func():
				_set_active_btn("")
				emit_signal(signal_name)
			)
		else:
			btn.pressed.connect(func():
				_on_func_btn_pressed(key, signal_name)
			)
		left_section.add_child(btn)
		_btn_map[key] = btn

## 创建右侧战斗控制按钮
func _build_right_buttons() -> void:
	for cfg in BATTLE_BTN_CONFIGS:
		var key: String = cfg[0]
		var label_text: String = cfg[1]
		var signal_name: String = cfg[2]
		var btn := _make_func_button(label_text)
		btn.text = ""
		btn.custom_minimum_size = Vector2(52, 44)
		btn.tooltip_text = label_text
		_apply_bar_icon(btn, BATTLE_BTN_ICON_BY_KEY.get(key, ""))
		btn.add_theme_constant_override("icon_max_width", 30)
		# 战斗控制按钮用不同配色（C4: 高饱和大面积用色收敛 DT token）
		if key == "start_battle":
			_style_battle_button(btn, DT.COLOR_GREEN_BRIGHT, Color(0.0, 0.15, 0.12, 0.9))
		elif key == "pause":
			_style_battle_button(btn, DT.COLOR_GOLD, Color(0.2, 0.15, 0.05, 0.85))
		elif key == "retreat":
			_style_battle_button(btn, DT.COLOR_RED_DOWN, Color(0.25, 0.06, 0.06, 0.88))
		elif key == "back":
			_style_battle_button(btn, Color(0.75, 0.75, 0.8, 0.85), Color(0.08, 0.08, 0.1, 0.85))
		btn.pressed.connect(func():
			emit_signal(signal_name)
		)
		right_section.add_child(btn)
		_btn_map[key] = btn

## 通用功能按钮工厂
func _apply_bar_icon(btn: Button, icon_basename: Variant) -> void:
	if btn == null or not (icon_basename is String):
		return
	var ib: String = String(icon_basename)
	if ib.is_empty():
		return
	var t: Texture2D = UiAssetLoader.ui_icon(ib)
	if t == null:
		return
	btn.icon = t
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP


func _make_func_button(label_text: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	# v9.3: 12按钮宽度从72缩到62，12×62+66间距=810px，留足边距防溢出
	btn.custom_minimum_size = Vector2(62, 56)
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0, 0.9))
	# C6: 手写三态按钮（缺 disabled/focus，两个青变体）→ PanelStyles 四态工厂
	var styles := PanelStyles.make_button_styles(DT.COLOR_ACCENT_CYAN)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		btn.add_theme_stylebox_override(state, styles[state])
	return btn

## 设置某按钮的红点角标（key=按钮key，count>0 显示数字，count<=0 隐藏）
## 延迟创建 Badge 子节点，避免预设子节点干扰 Button 的 icon/text 布局
func set_btn_badge(key: String, count: int) -> void:
	if not _btn_map.has(key):
		return
	var btn: Button = _btn_map[key]
	var bg := btn.get_node_or_null("BadgeBg") as ColorRect
	var bd := btn.get_node_or_null("Badge") as Label
	# count<=0 且无现有 badge：直接返回，不创建任何节点
	if count <= 0 and bg == null:
		return
	# 首次需要显示时才创建 badge 节点
	if bg == null:
		bg = ColorRect.new()
		bg.name = "BadgeBg"
		bg.color = Color(0.95, 0.25, 0.25, 0.95)
		bg.anchors_preset = Control.PRESET_TOP_RIGHT
		bg.anchor_left = 1.0
		bg.anchor_right = 1.0
		bg.offset_left = -18
		bg.offset_right = -2
		bg.offset_top = -2
		bg.offset_bottom = 14
		bg.size = Vector2(16, 16)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(bg)
		bd = Label.new()
		bd.name = "Badge"
		bd.add_theme_font_size_override("font_size", 10)
		bd.add_theme_color_override("font_color", Color.WHITE)
		bd.add_theme_color_override("font_outline_color", Color(0.8, 0.1, 0.1, 1.0))
		bd.add_theme_constant_override("outline_size", 2)
		bd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bd.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		bd.anchors_preset = Control.PRESET_TOP_RIGHT
		bd.anchor_left = 1.0
		bd.anchor_right = 1.0
		bd.offset_left = -18
		bd.offset_right = -2
		bd.offset_top = -2
		bd.offset_bottom = 14
		bd.size = Vector2(16, 16)
		bd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(bd)
	if count > 0:
		bd.text = str(count)
		bg.visible = true
		bd.visible = true
	else:
		bd.text = ""
		bg.visible = false
		bd.visible = false

## 战斗控制按钮特殊样式
func _style_battle_button(btn: Button, font_color: Color, bg_color: Color) -> void:
	btn.add_theme_color_override("font_color", font_color)
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = font_color.darkened(0.2)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	btn.add_theme_stylebox_override("normal", style)

## 功能按钮点击：高亮状态 + 发出信号
func _on_func_btn_pressed(key: String, signal_name: String) -> void:
	_play_sfx("button")
	# 切换高亮：再次点击已高亮的按钮则取消高亮（面板关闭由外部处理）
	if _active_btn_key == key:
		_set_active_btn("")
	else:
		_set_active_btn(key)
	emit_signal(signal_name)

## 设置高亮按钮（传入 "" 清除所有高亮）
func _set_active_btn(key: String) -> void:
	_active_btn_key = key
	# C6: 手写高亮/默认样式 → PanelStyles 工厂（active 复用 pressed 态视觉）
	var styles := PanelStyles.make_button_styles(DT.COLOR_ACCENT_CYAN)
	for k in _btn_map:
		var btn: Button = _btn_map[k]
		if k == key:
			btn.add_theme_stylebox_override("normal", styles["pressed"])
			btn.add_theme_color_override("font_color", DT.COLOR_ACCENT_CYAN)
		elif k not in ["start_battle", "back", "pause", "retreat", "save"]:
			# 恢复默认样式
			btn.add_theme_stylebox_override("normal", styles["normal"])
			btn.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0, 0.9))

## 外部通知：某个面板已关闭，清除对应高亮
func notify_panel_closed(key: String) -> void:
	if _active_btn_key == key:
		_set_active_btn("")

## v7.x: 战斗控制按钮已整合进 TopHudBar。
## 本方法保留为转发门面，让 main_battle_setup.gd 等旧调用点零改动。
func _get_top_controls() -> Node:
	# bottom_function_bar 在 HudLayer/BattleBottomBar/BottomFunctionBar
	# 向上 2 层到 HudLayer，再下到 TopHudBar
	return get_node_or_null("../../TopHudBar")

## 外部更新开始战斗状态（转发到 TopBattleControls）
func set_start_battle_text(text: String) -> void:
	var tc := _get_top_controls()
	if tc != null and tc.has_method("set_start_battle_text"):
		tc.set_start_battle_text(text)
		return
	# 回退：旧场景未挂 TopBattleControls 时仍操作本地按钮
	if not _btn_map.has("start_battle"):
		return
	var btn: Button = _btn_map["start_battle"] as Button
	btn.tooltip_text = text
	btn.modulate = Color(0.55, 0.58, 0.62, 1.0) if text == "战斗中" else Color(1, 1, 1, 1)

## 外部更新暂停状态（转发到 TopBattleControls）
func set_pause_text(text: String) -> void:
	var tc := _get_top_controls()
	if tc != null and tc.has_method("set_pause_text"):
		tc.set_pause_text(text)
		return
	# 回退
	if not _btn_map.has("pause"):
		return
	var btn: Button = _btn_map["pause"] as Button
	btn.tooltip_text = text
	var icon_key := "icon_pause"
	if text == "继续":
		icon_key = "icon_play"
	_apply_bar_icon(btn, icon_key)
