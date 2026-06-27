extends PanelContainer
## 底部功能键栏：包含所有面板入口按钮
## 每个按钮点击后发出对应信号，外部统一监听并弹出面板
## 支持"当前激活按钮"高亮状态

## 播放音效（Autoload AudioManager；get_node_or_null 兜底）
func _play_sfx(name: String) -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.play_sfx(name)

signal btn_backpack_pressed
signal btn_faction_pressed
signal btn_quest_pressed
signal btn_store_pressed
signal btn_progression_pressed
signal btn_leaderboard_pressed
signal btn_info_pressed
signal btn_map_pressed
signal btn_settings_pressed
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

## 设为 true 时左侧功能按钮不显示中文，便于只看图标；确认无误后改回 false。
const DEBUG_HIDE_BOTTOM_BAR_TEXT := true

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
const BTN_CONFIGS: Array = [
	["backpack",     "背包",   "btn_backpack_pressed"],
	["progression",  "成长",   "btn_progression_pressed"],
	["faction",      "势力",   "btn_faction_pressed"],
	["quest",        "任务",   "btn_quest_pressed"],
	["store",        "商店",   "btn_store_pressed"],
	["leaderboard",  "排行",   "btn_leaderboard_pressed"],
	["info",         "情报",   "btn_info_pressed"],
	["map",          "地图",   "btn_map_pressed"],
	["settings",     "设置",   "btn_settings_pressed"],
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

## 创建左侧功能按钮
func _build_left_buttons() -> void:
	var keys_built: Array[String] = []
	for cfg in BTN_CONFIGS:
		var key: String = cfg[0]
		var label_text: String = cfg[1]
		var signal_name: String = cfg[2]
		var btn := _make_func_button(label_text)
		if DEBUG_HIDE_BOTTOM_BAR_TEXT:
			btn.text = ""
		_apply_bar_icon(btn, BTN_ICON_BY_KEY.get(key, ""))
		btn.add_theme_constant_override("icon_max_width", 30)
		# 存档为即时动作，不切换面板高亮
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
		keys_built.append(key)

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
		# 战斗控制按钮用不同配色
		if key == "start_battle":
			_style_battle_button(btn, Color(0.0, 0.94, 0.7, 1.0), Color(0.0, 0.15, 0.12, 0.9))
		elif key == "pause":
			_style_battle_button(btn, Color(1.0, 0.85, 0.3, 1.0), Color(0.2, 0.15, 0.05, 0.85))
		elif key == "retreat":
			_style_battle_button(btn, Color(1.0, 0.4, 0.4, 1.0), Color(0.25, 0.06, 0.06, 0.88))
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


func _make_func_button(label_text: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(72, 44)
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0, 0.9))
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.06, 0.10, 0.18, 0.85)
	normal_style.border_color = Color(0.2, 0.45, 0.75, 0.4)
	normal_style.set_border_width_all(1)
	normal_style.set_corner_radius_all(5)
	btn.add_theme_stylebox_override("normal", normal_style)
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.08, 0.16, 0.28, 0.95)
	hover_style.border_color = Color(0.0, 0.85, 1.0, 0.65)
	hover_style.set_border_width_all(1)
	hover_style.set_corner_radius_all(5)
	btn.add_theme_stylebox_override("hover", hover_style)
	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.0, 0.18, 0.32, 0.95)
	pressed_style.border_color = Color(0.0, 0.94, 1.0, 0.85)
	pressed_style.set_border_width_all(2)
	pressed_style.set_corner_radius_all(5)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	return btn

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
	for k in _btn_map:
		var btn: Button = _btn_map[k]
		if k == key:
			# 激活样式：亮青色边框
			var active_style := StyleBoxFlat.new()
			active_style.bg_color = Color(0.0, 0.18, 0.32, 0.95)
			active_style.border_color = Color(0.0, 0.94, 1.0, 0.85)
			active_style.set_border_width_all(2)
			active_style.set_corner_radius_all(5)
			btn.add_theme_stylebox_override("normal", active_style)
			btn.add_theme_color_override("font_color", Color(0.0, 0.94, 1.0, 1.0))
		elif k not in ["start_battle", "back", "pause", "retreat", "save"]:
			# 恢复默认样式
			var normal_style := StyleBoxFlat.new()
			normal_style.bg_color = Color(0.06, 0.10, 0.18, 0.85)
			normal_style.border_color = Color(0.2, 0.45, 0.75, 0.4)
			normal_style.set_border_width_all(1)
			normal_style.set_corner_radius_all(5)
			btn.add_theme_stylebox_override("normal", normal_style)
			btn.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0, 0.9))

## 外部通知：某个面板已关闭，清除对应高亮
func notify_panel_closed(key: String) -> void:
	if _active_btn_key == key:
		_set_active_btn("")

## 外部更新开始战斗状态（仅图标：用悬停提示显示「开始战斗 / 战斗中」）
func set_start_battle_text(text: String) -> void:
	if not _btn_map.has("start_battle"):
		return
	var btn: Button = _btn_map["start_battle"] as Button
	btn.tooltip_text = text
	if text == "战斗中":
		btn.modulate = Color(0.55, 0.58, 0.62, 1.0)
	else:
		btn.modulate = Color(1, 1, 1, 1)

## 外部更新暂停状态（「暂停」显示暂停图标，「继续」显示播放图标；悬停见文案）
func set_pause_text(text: String) -> void:
	if not _btn_map.has("pause"):
		return
	var btn: Button = _btn_map["pause"] as Button
	btn.tooltip_text = text
	var icon_key := "icon_pause"
	if text == "继续":
		icon_key = "icon_play"
	_apply_bar_icon(btn, icon_key)
