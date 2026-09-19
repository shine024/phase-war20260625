extends Control
## v7.x 顶部 HUD 顶栏（44px 横贯全屏，无整条背景）
## 结构：Control > Capsule(胶囊底板,BU-3) > CenterSection(关卡+波次+计时+波次进度条), RightSection(撤退+开始+倍速+暂停+返回)
## 数据源：关卡名(GameManager信号) / 波次(BattleManager轮询) / 计时(本地自增) / 绿点(SignalBus战斗信号)

const DT = preload("res://resources/design_tokens.gd")
# v26.2: 战场环境效果（chip 数据源）+ 每关布局题面
const BattleEnvEffects = preload("res://data/battle_env_effects.gd")
# v32.0 B1-1: 战斗时间状态（倍速档位/极速推演旗标唯一真身）
const BTS = preload("res://scripts/battle/battle_time_state.gd")
const LevelBattleLayouts = preload("res://data/level_battle_layouts.gd")

signal btn_start_battle_pressed
signal btn_pause_pressed
signal btn_retreat_pressed
signal btn_back_pressed

# ── 子节点引用（运行时取，容错）──
var _level_label: Label = null
var _wave_label: Label = null
var _time_label: Label = null
var _wave_progress: ProgressBar = null
var _wave_fill_style: StyleBoxFlat = null
var _bm_cache: Node = null  ## v9.x（3c）：BattleManager 引用缓存
var _retreat_btn: Button = null
var _pause_btn: Button = null
var _speed_btn: Button = null
var _start_btn: Button = null
var _back_btn: Button = null
# ── v27: 基地完整度 chip（FTUE S3——phase_driver_hp_changed 此前零显示消费方，"基地被打了看不见"） ──
var _base_chip: HBoxContainer = null
var _base_label: Label = null
var _base_progress: ProgressBar = null
var _base_fill_style: StyleBoxFlat = null
var _base_pulse_tween: Tween = null
# ── v26.2: 环境效果 chip（战内常显本场生效条目，与 world_map 战前摘要同一数据源） ──
var _env_chip: HBoxContainer = null
var _env_label: Label = null

# ── 计时（本地自增，搬自 battle_info_display.gd）──
var _battle_time: float = 0.0
var _time_refresh_accum: float = 0.0

# ── 状态绿点 ──
var _in_battle: bool = false

# ── 倍速 ──
var _speed_scale: float = 1.0
# R1-6（设计审查 F-13）加 ×3 档；v32.0 B1-1 加 ×4 档 + 档位跨会话记忆
#（真身在 BTS.SPEED_OPTIONS，持久化 user://battle_speed.cfg，读档就近吸附）
const _SPEED_OPTIONS: Array = [1.0, 2.0, 3.0, 4.0]
# v38：跳过（极速推演）按钮按用户拍板移除——不提供跳过战斗入口。
# BattleTimeState 的极速推演机制保留（BattleSpectacle 仍是其收口方，AFK 链路不受影响）。

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
	_apply_button_icons()
	_apply_button_styles()
	_ensure_wave_progress_style()
	_build_base_chip()
	_build_env_chip()
	# v32.0 B1-1: 倍速档位跨会话记忆（读 battle_speed.cfg 就近吸附；实际应用在 battle_started）
	_speed_scale = BTS.load_pref()
	if _speed_btn:
		_sync_speed_btn_label()
	_refresh_level()
	_refresh_wave()
	_refresh_time()


func _cache_nodes() -> void:
	_level_label = get_node_or_null("Capsule/CenterSection/LevelRow/LevelLabel") as Label
	_wave_label = get_node_or_null("Capsule/CenterSection/InfoRow/WaveLabel") as Label
	_time_label = get_node_or_null("Capsule/CenterSection/InfoRow/TimeLabel") as Label
	_wave_progress = get_node_or_null("Capsule/CenterSection/WaveProgressBar") as ProgressBar
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
		# v9.x: 波次推进信号驱动刷新（替代每 0.25s 轮询 BattleManager）
		if sb.has_signal("wave_spawned"):
			sb.wave_spawned.connect(_on_wave_changed)
		# v27: 基地完整度（相位场驱动器 HP）
		if sb.has_signal("phase_driver_hp_changed"):
			sb.phase_driver_hp_changed.connect(_on_phase_driver_hp_changed)


func _apply_button_icons() -> void:
	_apply_icon_to(_retreat_btn, _RETREAT_ICON, "撤", Color(0.4, 0.1, 0.1, 0.85))
	_apply_icon_to(_pause_btn, _PAUSE_ICON, "停", Color(0.3, 0.25, 0.05, 0.85))
	_apply_icon_to(_start_btn, _START_ICON, "战", Color(0.05, 0.25, 0.15, 0.85))
	_apply_icon_to(_back_btn, _BACK_ICON, "返", Color(0.1, 0.1, 0.15, 0.85))
	# v6.14：返回语义=回移动基地（原按出击来源分流，非基地出击时回标题，用户反馈
	# 战斗界面找不到回基地入口）——按钮是纯图标，悬停说明必须给出去向
	if _back_btn:
		_back_btn.tooltip_text = "返回移动基地"

func _apply_icon_to(btn: Button, icon_key: String, fallback_text: String = "", _bg_color: Color = Color(0.06, 0.10, 0.18, 0.85)) -> void:
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
	# v26.x: 此处原有一份手写 radius-5 样式，但 _ready 中 _apply_button_styles() 在
	# _apply_button_icons() 之后执行、四态样式（radius 6 + hover 青）整体覆盖之——
	# 原样式块是写完即被覆盖的死代码，已删除。按钮真实样式见 _apply_normal_btn_style。


# ========== Chip 背景样式 ==========
# v26.x: _make_chip_style / _CHIP_BG / _CHIP_BORDER 已删除——零调用方死代码
#（_apply_chip_styles 是 pass，_build_base_chip 自建样式）。


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
	# C6: 补 disabled / focus 态（原文标准：可交互处必须有完整多状态）
	var disabled := normal.duplicate()
	disabled.bg_color = Color(_BTN_BG.r, _BTN_BG.g, _BTN_BG.b, 0.5)
	btn.add_theme_stylebox_override("disabled", disabled)
	var focus := normal.duplicate()
	focus.border_color = _BTN_BORDER_HOVER
	focus.border_width_left = 2
	focus.border_width_top = 2
	focus.border_width_right = 2
	focus.border_width_bottom = 2
	btn.add_theme_stylebox_override("focus", focus)
	# 字色
	btn.add_theme_color_override("font_color", Color(0.62, 0.68, 0.75, 1))
	btn.add_theme_color_override("font_hover_color", Color(0.91, 0.94, 0.96, 1))
	btn.add_theme_color_override("font_pressed_color", DT.COLOR_CYAN_TECH_SOFT)
	btn.add_theme_color_override("font_disabled_color", Color(0.45, 0.5, 0.56, 1))


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
	# v9.x: 波次刷新改由 wave_spawned 信号驱动（_on_wave_changed），不再每 0.25s 轮询


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
	# v9.x（3c）：BattleManager 引用缓存（原每次刷新绝对路径查找）
	if not is_instance_valid(_bm_cache):
		_bm_cache = get_node_or_null("/root/BattleManager")
	var bm := _bm_cache
	if bm == null or not _in_battle:
		_wave_label.text = ""
		if _wave_progress != null:
			_wave_progress.visible = false
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
	# BU-3：波次进度条——当前波/总波；>80% 转金色（收尾提示），非战斗/无波次隐藏
	if _wave_progress != null:
		if _in_battle and wave_total > 0:
			_wave_progress.visible = true
			_wave_progress.max_value = maxf(float(wave_total), 1.0)
			_wave_progress.value = clampf(float(wave_idx), 0.0, float(wave_total))
			if _wave_fill_style != null:
				var ratio: float = float(wave_idx) / maxf(float(wave_total), 1.0)
				_wave_fill_style.bg_color = DT.COLOR_GOLD if ratio >= 0.8 else DT.COLOR_ACCENT_CYAN
		else:
			_wave_progress.visible = false


## BU-3：波次进度条样式（底 PANEL_DEEP + 填充青/GOLD 可变）。复用同一 StyleBox 实例改色。
func _ensure_wave_progress_style() -> void:
	if _wave_progress == null or _wave_fill_style != null:
		return
	var bg := StyleBoxFlat.new()
	bg.bg_color = DT.COLOR_PANEL_DEEP
	bg.set_corner_radius_all(3)
	_wave_fill_style = StyleBoxFlat.new()
	_wave_fill_style.bg_color = DT.COLOR_ACCENT_CYAN
	_wave_fill_style.set_corner_radius_all(3)
	_wave_progress.add_theme_stylebox_override("background", bg)
	_wave_progress.add_theme_stylebox_override("fill", _wave_fill_style)


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
	# v9.x: 战斗开始时刷新一次波次初始显示（后续由 wave_spawned 信号驱动）
	_refresh_wave()
	# v27: 战斗中显示基地完整度
	if _base_chip != null:
		_base_chip.visible = true
	# v26.2: 刷新环境效果 chip（按当前关卡环境）
	_refresh_env_chip()

func _on_battle_ended(_won) -> void:
	_in_battle = false
	if _wave_progress != null:
		_wave_progress.visible = false
	# v27: 战斗结束隐藏基地 chip + 停危急闪烁
	if _base_chip != null:
		_base_chip.visible = false
	_stop_base_pulse()

## v9.x: 波次推进时刷新 dots 显示（替代每 0.25s 轮询）
func _on_wave_changed(_wave_index: int) -> void:
	_refresh_wave()


# ========== 基地完整度 chip（v27 / FTUE S3）==========
## 编程式挂进 InfoRow（与 ultimate_cast_bar 同风格：不动 tscn）。
## 三段色：>60% 绿 / 30-60% 琥珀 / ≤30% 红 + "基地"字样呼吸闪烁（配 audio 侧告警音）。
func _build_base_chip() -> void:
	var info_row: Node = get_node_or_null("Capsule/CenterSection/InfoRow")
	if info_row == null:
		return
	_base_chip = HBoxContainer.new()
	_base_chip.add_theme_constant_override("separation", 4)
	_base_chip.visible = false
	_base_label = Label.new()
	_base_label.text = "基地"
	_base_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	_base_label.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
	_base_chip.add_child(_base_label)
	_base_progress = ProgressBar.new()
	_base_progress.custom_minimum_size = Vector2(90, 10)
	_base_progress.show_percentage = false
	_base_progress.mouse_filter = Control.MOUSE_FILTER_PASS
	_base_progress.tooltip_text = "相位场驱动器（基地）完整度——归零即战败。\n危急（红色闪烁）时同时有告警音提示。"
	_base_chip.add_child(_base_progress)
	info_row.add_child(_base_chip)
	var bg := StyleBoxFlat.new()
	bg.bg_color = DT.COLOR_PANEL_DEEP
	bg.set_corner_radius_all(3)
	_base_fill_style = StyleBoxFlat.new()
	_base_fill_style.bg_color = DT.COLOR_HEALTH
	_base_fill_style.set_corner_radius_all(3)
	_base_progress.add_theme_stylebox_override("background", bg)
	_base_progress.add_theme_stylebox_override("fill", _base_fill_style)

func _on_phase_driver_hp_changed(current: float, maximum: float) -> void:
	if _base_progress == null or maximum <= 0.0:
		return
	var ratio: float = clampf(current / maximum, 0.0, 1.0)
	_base_progress.max_value = maximum
	_base_progress.value = maxf(current, 0.0)
	if ratio > 0.6:
		_base_fill_style.bg_color = DT.COLOR_HEALTH
		_base_label.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
		_stop_base_pulse()
	elif ratio > 0.3:
		_base_fill_style.bg_color = DT.COLOR_AMBER
		_base_label.add_theme_color_override("font_color", DT.COLOR_AMBER)
		_stop_base_pulse()
	else:
		_base_fill_style.bg_color = DT.COLOR_DANGER
		_base_label.add_theme_color_override("font_color", DT.COLOR_DANGER)
		_start_base_pulse()

func _start_base_pulse() -> void:
	if DT.is_motion_reduce():
		return
	if _base_pulse_tween != null and _base_pulse_tween.is_valid():
		return
	_base_pulse_tween = create_tween().set_loops()
	_base_pulse_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_base_pulse_tween.tween_property(_base_label, "modulate:a", 0.35, 0.45)
	_base_pulse_tween.tween_property(_base_label, "modulate:a", 1.0, 0.45)

func _stop_base_pulse() -> void:
	if _base_pulse_tween != null and _base_pulse_tween.is_valid():
		_base_pulse_tween.kill()
	_base_pulse_tween = null
	if _base_label != null:
		_base_label.modulate.a = 1.0


# ========== 环境效果 chip（v26.2）==========
## 本场生效的环境条目常显（无效果关隐藏），tooltip 全文 + 布局题面；数据源与 world_map 战前摘要一致。
func _build_env_chip() -> void:
	var info_row: Node = get_node_or_null("Capsule/CenterSection/InfoRow")
	if info_row == null:
		return
	_env_chip = HBoxContainer.new()
	_env_chip.add_theme_constant_override("separation", 4)
	_env_chip.visible = false
	_env_label = Label.new()
	_env_label.text = "环境"
	_env_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	_env_label.add_theme_color_override("font_color", DT.COLOR_AMBER)
	_env_chip.add_child(_env_label)
	info_row.add_child(_env_chip)

func _refresh_env_chip() -> void:
	if _env_chip == null:
		return
	var level: int = 1
	var gm := get_node_or_null("/root/GameManager")
	if gm and "current_level" in gm:
		level = int(gm.current_level)
	var descs: Array = BattleEnvEffects.describe_level_env(level)
	var note: String = LevelBattleLayouts.get_note(level)
	if descs.is_empty() and note.is_empty():
		_env_chip.visible = false
		return
	_env_chip.visible = true
	var tip_lines: Array = descs.duplicate()
	if not tip_lines.is_empty():
		tip_lines.insert(0, "本场环境效果（敌我同样生效）：")
	if not note.is_empty():
		tip_lines.append("本场布阵：" + note)
	_env_label.tooltip_text = "\n".join(tip_lines)


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
	_start_btn.modulate = Color(0.55, 0.58, 0.62, 1.0) if text == "战斗中" else DT.COLOR_HOVER_WHITE


# ========== 倍速 ==========
func _on_speed_pressed() -> void:
	var idx := _SPEED_OPTIONS.find(_speed_scale)
	idx = (idx + 1) % _SPEED_OPTIONS.size()
	_speed_scale = _SPEED_OPTIONS[idx]
	_sync_speed_btn_label()
	# v32.0 B1-1: 偏好持久化+立即应用（推演/慢动作进行中由 BattleSpectacle 守卫延迟生效）
	var bs := get_node_or_null("/root/BattleSpectacle")
	if bs and bs.has_method("set_user_time_scale"):
		bs.set_user_time_scale(_speed_scale)
	else:
		Engine.time_scale = _speed_scale
	# v32.0 埋点：倍速档位使用（speed_x2/x3/x4）
	var pm := get_node_or_null("/root/PerformanceMetricsManager")
	if pm != null and pm.has_method("count_event"):
		pm.count_event("speed_x%d" % int(_speed_scale))


## v32.0 B1-1: 倍速按钮文案/激活态统一同步（_ready 读档与点击切档共用）
func _sync_speed_btn_label() -> void:
	if _speed_btn == null:
		return
	_speed_btn.text = "×%d" % int(_speed_scale)
	_speed_btn.tooltip_text = "战斗倍速 ×%d" % int(_speed_scale)
	# 倍速 > 1 时显示激活态（设计稿 .ctl-on：青色边框 + 微亮背景）
	_update_speed_btn_active_state()


# ========== v32.0 B1-1: 跳过（极速推演）==========
## v38：跳过按钮已按用户拍板移除（不提供跳过战斗入口）。
## 原 _build_skip_btn/_on_skip_pressed 连带删除；极速推演状态机（BattleTimeState +
## BattleSpectacle.set_fast_forward）保留——引擎侧守卫与自动退出仍需要它。

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
		_speed_btn.add_theme_color_override("font_color", DT.COLOR_CYAN_TECH_SOFT)
	else:
		# 恢复普通样式
		_apply_normal_btn_style(_speed_btn)
