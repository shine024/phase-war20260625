extends Control
## v7.x 顶部 HUD 顶栏（44px 横贯全屏，无整条背景）
## 结构：Control > Margin > HBox[CenterSection(关卡+绿点+波次+计时), RightSection(撤退+开始+倍速+暂停+返回)]
## 数据源：关卡名(GameManager信号) / 波次(BattleManager轮询) / 计时(本地自增) / 绿点(SignalBus战斗信号)

signal btn_start_battle_pressed
signal btn_pause_pressed
signal btn_retreat_pressed
signal btn_back_pressed

# ── 子节点引用（运行时取，容错）──
var _level_label: Label = null
var _wave_label: Label = null
var _time_label: Label = null
var _retreat_btn: Button = null
var _pause_btn: Button = null
var _speed_btn: Button = null
var _start_btn: Button = null
var _back_btn: Button = null

# ── 计时（本地自增，搬自 battle_info_display.gd）──
var _battle_time: float = 0.0
var _time_refresh_accum: float = 0.0

# ── 波次轮询（搬自 enemy_spawn_hud.gd）──
var _wave_refresh_accum: float = 0.0
const _WAVE_REFRESH_SEC: float = 0.25

# ── 状态绿点 ──
var _in_battle: bool = false

# ── 倍速 ──
var _speed_scale: float = 1.0
const _SPEED_OPTIONS: Array = [1.0, 2.0]

# ── 暂停态图标 ──
const _PAUSE_ICON := "icon_pause"
const _PLAY_ICON := "icon_play"
const _RETREAT_ICON := "icon_retreat"
const _START_ICON := "icon_start_battle"
const _BACK_ICON := "icon_arrow_left"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cache_nodes()
	_connect_signals()
	_apply_chip_styles()
	_apply_button_icons()
	_apply_button_styles()
	# 强制确保 SpeedBtn 有可见文字（防被其他逻辑覆盖）
	if _speed_btn:
		_speed_btn.text = "×1"
	_refresh_level()
	_refresh_wave()
	_refresh_time()


func _cache_nodes() -> void:
	_level_label = get_node_or_null("CenterSection/LevelRow/LevelLabel") as Label
	_wave_label = get_node_or_null("CenterSection/InfoRow/WaveLabel") as Label
	_time_label = get_node_or_null("CenterSection/InfoRow/TimeLabel") as Label
	# v7.x: 5 按钮组从顶栏根节点迁到 RightSection HBoxContainer（右锚，防 1280 以下分辨率按钮掉屏）
	_retreat_btn = get_node_or_null("RightSection/RetreatBtn") as Button
	_pause_btn = get_node_or_null("RightSection/PauseBtn") as Button
	_speed_btn = get_node_or_null("RightSection/SpeedBtn") as Button
	_start_btn = get_node_or_null("RightSection/StartBtn") as Button
	_back_btn = get_node_or_null("RightSection/BackBtn") as Button


func _connect_signals() -> void:
	if _retreat_btn:
		_retreat_btn.pressed.connect(func(): emit_signal("btn_retreat_pressed"))
	if _pause_btn:
		_pause_btn.pressed.connect(func(): emit_signal("btn_pause_pressed"))
	if _start_btn:
		_start_btn.pressed.connect(func(): emit_signal("btn_start_battle_pressed"))
	if _back_btn:
		_back_btn.pressed.connect(func(): emit_signal("btn_back_pressed"))
	if _speed_btn:
		_speed_btn.pressed.connect(_on_speed_pressed)
	# 关卡名：信号推送
	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.has_signal("current_level_changed"):
		gm.current_level_changed.connect(_on_level_changed)
	# 战斗状态：控制绿点 + 计时启停
	var sb := get_node_or_null("/root/SignalBus")
	if sb:
		if sb.has_signal("battle_started"):
			sb.battle_started.connect(_on_battle_started)
		if sb.has_signal("battle_ended"):
			sb.battle_ended.connect(_on_battle_ended)


func _apply_button_icons() -> void:
	_apply_icon_to(_retreat_btn, _RETREAT_ICON, "撤", Color(0.4, 0.1, 0.1, 0.85))
	_apply_icon_to(_pause_btn, _PAUSE_ICON, "停", Color(0.3, 0.25, 0.05, 0.85))
	_apply_icon_to(_start_btn, _START_ICON, "战", Color(0.05, 0.25, 0.15, 0.85))
	_apply_icon_to(_back_btn, _BACK_ICON, "返", Color(0.1, 0.1, 0.15, 0.85))

func _apply_icon_to(btn: Button, icon_key: String, fallback_text: String = "", bg_color: Color = Color(0.06, 0.10, 0.18, 0.85)) -> void:
	if btn == null:
		return
	var t := UiAssetLoader.ui_icon(icon_key)
	if t:
		btn.icon = t
		btn.expand_icon = false
		btn.add_theme_constant_override("icon_max_width", 18)
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	# 文字 fallback（图标失败时也能识别）
	if fallback_text != "":
		btn.text = fallback_text
		btn.add_theme_font_size_override("font_size", 13)
	# 按钮背景色（每个按钮独特配色，确保可见）
	var st := StyleBoxFlat.new()
	st.bg_color = bg_color
	st.border_color = Color(0.3, 0.5, 0.75, 0.5)
	st.set_border_width_all(1)
	st.set_corner_radius_all(5)
	st.set_content_margin_all(4)
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", st)


# ========== Chip 背景样式（三段独立半透明背景，替代原整条顶栏背景） ==========
# 设计稿 .panel 玻璃拟态：rgba(13,18,27,.85) + 边框 rgba(148,163,184,.18) + 圆角 10
const _CHIP_BG := Color(0.051, 0.071, 0.106, 0.85)      # rgba(13,18,27,.85)
const _CHIP_BORDER := Color(0.58, 0.64, 0.72, 0.22)


## v7.x: 无整条背景，仅给 RightSection（5按钮组）加小背景便于识别
func _apply_chip_styles() -> void:
	# RightSection 现在是 HBoxContainer（非 PanelContainer），跳过——按钮自带 StyleBox 背景
	pass


func _make_chip_style() -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = _CHIP_BG
	st.border_color = _CHIP_BORDER
	st.border_width_left = 1
	st.border_width_top = 1
	st.border_width_right = 1
	st.border_width_bottom = 1
	st.corner_radius_top_left = 8
	st.corner_radius_top_right = 8
	st.corner_radius_bottom_right = 8
	st.corner_radius_bottom_left = 8
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	return st


# ========== 按钮样式（对齐设计稿 .hud-btn：半透明深色背景 + 边框） ==========
# 设计稿 .hud-btn: background rgba(16,22,31,.8) + border rgba(148,163,184,.18)
# hover: 边框转青 rgba(34,211,238,.35) + 字色亮
# .retreat（撤退）: 红色边框 + 浅红字
const _BTN_BG := Color(0.063, 0.086, 0.122, 0.8)        # rgba(16,22,31,.8)
const _BTN_BORDER := Color(0.58, 0.64, 0.72, 0.18)      # rgba(148,163,184,.18)
const _BTN_BORDER_HOVER := Color(0.13, 0.83, 0.93, 0.45) # 青色 hover
const _BTN_BORDER_RETREAT := Color(0.97, 0.44, 0.44, 0.35) # 红色边框（撤退）


func _apply_button_styles() -> void:
	# 普通按钮（开始/倍速/暂停/返回）
	for btn in [_start_btn, _speed_btn, _pause_btn, _back_btn]:
		if btn != null:
			_apply_normal_btn_style(btn)
	# 撤退按钮：红色变体
	if _retreat_btn != null:
		_apply_retreat_btn_style(_retreat_btn)


func _apply_normal_btn_style(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = _BTN_BG
	normal.border_color = _BTN_BORDER
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_right = 6
	normal.corner_radius_bottom_left = 6
	normal.content_margin_left = 6
	normal.content_margin_right = 6
	normal.content_margin_top = 2
	normal.content_margin_bottom = 2
	btn.add_theme_stylebox_override("normal", normal)
	# hover：边框转青，背景微亮
	var hover := normal.duplicate()
	hover.border_color = _BTN_BORDER_HOVER
	hover.bg_color = Color(0.063, 0.086, 0.122, 0.95)
	btn.add_theme_stylebox_override("hover", hover)
	# pressed：背景更暗，边框青
	var pressed := normal.duplicate()
	pressed.border_color = _BTN_BORDER_HOVER
	pressed.bg_color = Color(0.04, 0.06, 0.09, 0.95)
	btn.add_theme_stylebox_override("pressed", pressed)
	# 字色
	btn.add_theme_color_override("font_color", Color(0.62, 0.68, 0.75, 1))
	btn.add_theme_color_override("font_hover_color", Color(0.91, 0.94, 0.96, 1))
	btn.add_theme_color_override("font_pressed_color", Color(0.13, 0.83, 0.93, 1))


func _apply_retreat_btn_style(btn: Button) -> void:
	_apply_normal_btn_style(btn)
	# 覆盖边框为红色，字色浅红（贴合设计稿 .hud-btn.retreat）
	var normal := btn.get_theme_stylebox("normal") as StyleBoxFlat
	if normal != null:
		normal.border_color = _BTN_BORDER_RETREAT
	var hover := btn.get_theme_stylebox("hover") as StyleBoxFlat
	if hover != null:
		hover.border_color = Color(0.97, 0.44, 0.44, 0.5)
		hover.bg_color = Color(0.12, 0.05, 0.05, 0.9)
	btn.add_theme_color_override("font_color", Color(0.97, 0.65, 0.65, 1))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.78, 0.78, 1))


# ========== 计时（搬自 battle_info_display）==========
func _process(delta: float) -> void:
	if _in_battle:
		_battle_time += delta
	# 计时显示：每 1s 刷新
	_time_refresh_accum += delta
	if _time_refresh_accum >= 1.0:
		_time_refresh_accum = 0.0
		_refresh_time()
	# 波次：每 0.25s 轮询
	_wave_refresh_accum += delta
	if _wave_refresh_accum >= _WAVE_REFRESH_SEC:
		_wave_refresh_accum = 0.0
		_refresh_wave()


func _refresh_time() -> void:
	if _time_label == null:
		return
	var minutes := int(_battle_time / 60)
	var seconds := int(fmod(_battle_time, 60.0))
	_time_label.text = "⏱ %02d:%02d" % [minutes, seconds]


# ========== 波次圆点（搬自 enemy_spawn_hud）==========
func _refresh_wave() -> void:
	if _wave_label == null:
		return
	var bm := get_node_or_null("/root/BattleManager")
	if bm == null or not _in_battle:
		_wave_label.text = ""
		return
	var wave_idx := 0
	var wave_total := 0
	if bm.has_method("get_enemy_wave_index"):
		wave_idx = int(bm.get_enemy_wave_index())
	if bm.has_method("get_enemy_wave_total"):
		wave_total = int(bm.get_enemy_wave_total())
	if wave_total > 0:
		var dots := ""
		for i in range(wave_total):
			if i < wave_idx - 1:
				dots += "●"
			elif i == wave_idx - 1:
				dots += "◉"
			else:
				dots += "○"
		_wave_label.text = "%s 波次 %d/%d" % [dots, wave_idx, wave_total]
	else:
		_wave_label.text = "波次 %d" % wave_idx


# ========== 关卡名 ==========
func _refresh_level() -> void:
	if _level_label == null:
		return
	var level := 1
	var gm := get_node_or_null("/root/GameManager")
	if gm and "current_level" in gm:
		level = int(gm.current_level)
	_level_label.text = "第 %d 关" % level

func _on_level_changed(_level) -> void:
	_refresh_level()

## 外部调用：设置关卡名
func set_level(level: int) -> void:
	if _level_label:
		_level_label.text = "第 %d 关" % level


# ========== 战斗状态（计时启停）==========
func _on_battle_started() -> void:
	_in_battle = true
	_battle_time = 0.0

func _on_battle_ended(_won) -> void:
	_in_battle = false


# ========== 暂停态切换 ==========
## 外部更新暂停状态（"暂停"→暂停图标；"继续"→播放图标）
func set_pause_text(text: String) -> void:
	if _pause_btn == null:
		return
	_pause_btn.tooltip_text = text
	var icon_key := _PAUSE_ICON
	if text == "继续":
		icon_key = _PLAY_ICON
	var t := UiAssetLoader.ui_icon(icon_key)
	if t:
		_pause_btn.icon = t

## 外部更新开始战斗状态（战斗中时按钮灰化）
func set_start_battle_text(text: String) -> void:
	if _start_btn == null:
		return
	_start_btn.tooltip_text = text
	_start_btn.modulate = Color(0.55, 0.58, 0.62, 1.0) if text == "战斗中" else Color(1, 1, 1, 1)


# ========== 倍速 ==========
func _on_speed_pressed() -> void:
	var idx := _SPEED_OPTIONS.find(_speed_scale)
	idx = (idx + 1) % _SPEED_OPTIONS.size()
	_speed_scale = _SPEED_OPTIONS[idx]
	if _speed_btn:
		_speed_btn.text = "×%d" % int(_speed_scale)
		_speed_btn.tooltip_text = "战斗倍速 ×%d" % int(_speed_scale)
		# 倍速 > 1 时显示激活态（设计稿 .ctl-on：青色边框 + 微亮背景）
		_update_speed_btn_active_state()
	var bs := get_node_or_null("/root/BattleSpectacle")
	if bs and bs.has_method("set_user_time_scale"):
		bs.set_user_time_scale(_speed_scale)
	else:
		Engine.time_scale = _speed_scale


## 倍速按钮激活态：×1 用普通样式，×2 用青色激活样式（设计稿 .ctl-on）
func _update_speed_btn_active_state() -> void:
	if _speed_btn == null:
		return
	if _speed_scale > 1.0:
		# 激活态：青色边框 + 青色字 + 微亮背景
		var active := StyleBoxFlat.new()
		active.bg_color = Color(0.05, 0.12, 0.16, 0.9)
		active.border_color = _BTN_BORDER_HOVER
		active.border_width_left = 1
		active.border_width_top = 1
		active.border_width_right = 1
		active.border_width_bottom = 1
		active.corner_radius_top_left = 6
		active.corner_radius_top_right = 6
		active.corner_radius_bottom_right = 6
		active.corner_radius_bottom_left = 6
		active.content_margin_left = 6
		active.content_margin_right = 6
		active.content_margin_top = 2
		active.content_margin_bottom = 2
		_speed_btn.add_theme_stylebox_override("normal", active)
		_speed_btn.add_theme_color_override("font_color", Color(0.13, 0.83, 0.93, 1))
	else:
		# 恢复普通样式
		_apply_normal_btn_style(_speed_btn)
