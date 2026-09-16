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
signal btn_modification_pressed
signal btn_evolution_pressed
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

## BU-1（战斗界面美化，2026-08-24）：抽屉模式——15 个功能按钮平时收起，
## 由相位仪栏右端「菜单」按钮展开；面板打开后自动收起，ESC 优先关抽屉。
var _drawer_open: bool = false
var _drawer_tween: Tween = null
var _badge_counts: Dictionary = {}

## 设为 true 时左侧功能按钮不显示中文，便于只看图标。
## 上线/正常游玩必须为 false——新手无法仅凭图标分辨 11 个功能（背包/成长/商店等）。
const DEBUG_HIDE_BOTTOM_BAR_TEXT := false

## 底部功能键 → `assets/ui/icons/<name>.svg`（优先；若无则 `.png`；无映射则仅文字）
const BTN_ICON_BY_KEY: Dictionary = {
	"backpack": "icon_backpack",
	"progression": "icon_upgrade",
	"modification": "icon_modification",
	"evolution": "icon_blueprint",
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
# v25.3 系统收敛（14→6）：战斗场景只保留战斗即时需要的功能。其余纯养成查册面板
#（势力/任务/商店/排行/情报/图鉴/成就/帮助）只留基地入口（bunker EMBEDDED_PANELS 全有
# 同款）。main.gd 的面板 handler/overlay 机制保留不动（整备舱转发 modification/evolution
# 仍依赖），仅移除按钮与热键两个入口。
# v32.3 E1：8 键重排——成长（原「整备」）提为首位+amber 加权；改造/制造从成长面板
# 详情底部的二级跳转提为一级按钮（实机验收：入口太深）
const BTN_CONFIGS: Array = [
	["progression",  "成长",   "btn_progression_pressed"],
	["backpack",     "卡仓",   "btn_backpack_pressed"],
	["modification", "改造",   "btn_modification_pressed"],
	["evolution",    "制造",   "btn_evolution_pressed"],
	["map",          "地图",   "btn_map_pressed"],
	["settings",     "设置",   "btn_settings_pressed"],
	["save",         "存档",   "btn_save_pressed"],
	["afk",          "挂机",   "btn_afk_pressed"],
]

# 批次三 B8：左排面板按钮 tooltip 文案（含快捷键宣传；键位以 main.gd _input 为准）
const SHORTCUT_TOOLTIPS: Dictionary = {
	"progression":  "成长：卡牌等级 / 技能树 / 战力总览（快捷键 7）",
	"backpack":     "卡仓：查看拥有的卡牌与实例（快捷键 1 / B）",
	"modification": "改造：给战斗卡安装/升级改造模块（消耗图纸+纳米）",
	"evolution":    "制造：用情报与资源生产新卡牌",
	"map":          "世界地图：选择关卡推进（快捷键 M）",
	"settings":     "设置（快捷键 9）",
	"save":         "手动存档",
	"afk":          "自动哨戒：自动部署刷资源",
}

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
	# v34 渐进解锁：改造(L3)/制造(L5)/挂机(L5) 按节奏表灰显；跨级解锁信号实时刷新
	_refresh_feature_gates()
	if not SignalBus.feature_unlocked.is_connected(_on_feature_unlocked):
		SignalBus.feature_unlocked.connect(_on_feature_unlocked)
	# v7.x: 战斗控制按钮已迁移到 TopBattleControls，隐藏底部 RightSection + Divider
	# 仍保留 _build_right_buttons 创建按钮到 _btn_map（set_pause_text 回退路径依赖）
	if right_section:
		right_section.visible = false
	var divider := get_node_or_null("Margin/HBox/Divider")
	if divider:
		divider.visible = false
	# BU-1：抽屉化——默认收起 + 悬浮卡片样式（与相位仪栏同一 PanelStyles 语言）
	_apply_float_frame_style()
	visible = false

## BU-1：抽屉开合。展开 = 淡入 + 自底生长（0.2s SINE OUT），收起反向 0.15s。
## scale 以底边为支点（容器只管布局不改 scale，安全）；尊重 DT.is_motion_reduce() 直接切换。
func is_drawer_open() -> bool:
	return _drawer_open

func toggle_drawer() -> void:
	set_drawer_open(not _drawer_open)

func set_drawer_open(open: bool, animated: bool = true) -> void:
	if open == _drawer_open:
		return
	_drawer_open = open
	# 开合广播（battle_log 淡出让位用——抽屉展开时底部栏向上生长会顶进日志面板区域）
	SignalBus.bottom_drawer_toggled.emit(open)
	if _drawer_tween != null and _drawer_tween.is_valid():
		_drawer_tween.kill()
		_drawer_tween = null
	if open:
		visible = true
		if not animated or DT.is_motion_reduce():
			modulate.a = 1.0
			scale = Vector2.ONE
			return
		pivot_offset = _bottom_pivot()
		modulate.a = 0.0
		scale = Vector2(1.0, 0.85)
		_drawer_tween = create_tween().set_parallel(true)
		_drawer_tween.tween_property(self, "modulate:a", 1.0, DT.MOTION_FADE_IN)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_drawer_tween.tween_property(self, "scale", Vector2.ONE, DT.MOTION_FADE_IN)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		if not animated or DT.is_motion_reduce():
			visible = false
			modulate.a = 1.0
			scale = Vector2.ONE
			return
		pivot_offset = _bottom_pivot()
		_drawer_tween = create_tween().set_parallel(true)
		_drawer_tween.tween_property(self, "modulate:a", 0.0, DT.MOTION_FADE_OUT)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_drawer_tween.tween_property(self, "scale", Vector2(1.0, 0.85), DT.MOTION_FADE_OUT)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_drawer_tween.chain().tween_callback(func() -> void:
			if not _drawer_open and is_instance_valid(self):
				visible = false
				modulate.a = 1.0
				scale = Vector2.ONE)

## 底边支点：隐藏期间容器不给布局（size 可能为 0），回退 custom_minimum_size。
func _bottom_pivot() -> Vector2:
	var w: float = size.x if size.x > 1.0 else custom_minimum_size.x
	var h: float = size.y if size.y > 1.0 else custom_minimum_size.y
	return Vector2(w * 0.5, h)

## BU-1：抽屉面板悬浮卡片化（12 圆角 + accent 发光，与相位仪栏同语言）。
func _apply_float_frame_style() -> void:
	var sb: StyleBoxFlat = PanelStyles.make_panel_frame(DT.COLOR_ACCENT_CYAN)
	sb.bg_color.a = 0.90
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	add_theme_stylebox_override("panel", sb)

## BU-1：把红点总数透传给相位仪栏「菜单」按钮（同 BattleBottomBar 下的兄弟节点）。
func _notify_menu_badge() -> void:
	var total: int = 0
	for v in _badge_counts.values():
		total += maxi(int(v), 0)
	var ib: Node = get_node_or_null("../BottomInstrumentBar")
	if ib != null and ib.has_method("set_menu_badge"):
		ib.set_menu_badge(total)

## 创建左侧功能按钮（12 个全部直接显示）
func _build_left_buttons() -> void:
	for cfg in BTN_CONFIGS:
		var key: String = cfg[0]
		var label_text: String = cfg[1]
		var signal_name: String = cfg[2]
		var btn := _make_func_button(label_text)
		# 批次三 B8：左排面板按钮 tooltip（原完全缺失）——用途一句话 + 快捷键宣传
		# （学《朝露》：按两次就记住；键位与 main.gd _input 战前 match 一一对应）
		var tip: String = String(SHORTCUT_TOOLTIPS.get(key, ""))
		btn.tooltip_text = tip if not tip.is_empty() else label_text
		if DEBUG_HIDE_BOTTOM_BAR_TEXT:
			btn.text = ""
		_apply_bar_icon(btn, BTN_ICON_BY_KEY.get(key, ""))
		btn.add_theme_constant_override("icon_max_width", 30)
		# v32.3 E1：成长按钮视觉加权（amber 主张——养成主链路不与工具键同权）
		if key == "progression":
			var gold := PanelStyles.make_button_styles(DT.COLOR_AMBER)
			btn.add_theme_stylebox_override("normal", gold["normal"])
			btn.add_theme_color_override("font_color", Color(0.99, 0.86, 0.60))
		if key == "save":
			btn.pressed.connect(func():
				_set_active_btn("")
				emit_signal(signal_name)
				# BU-1：从抽屉点开的入口——面板已动作，抽屉自动收起
				if _drawer_open:
					set_drawer_open(false)
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
	# BU-1：红点计数聚合——透传给相位仪栏「菜单」按钮的总角标
	_badge_counts[key] = count
	_notify_menu_badge()
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
		bd.add_theme_font_size_override("font_size", DT.FONT_SIZE_XSMALL)
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
	# ui-review·易用性：hover/pressed 反馈（原单态悬停无响应）
	var hover_sb: StyleBoxFlat = style.duplicate()
	hover_sb.bg_color = style.bg_color.lightened(0.14)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("pressed", style.duplicate())

## 功能按钮点击：高亮状态 + 发出信号
func _on_func_btn_pressed(key: String, signal_name: String) -> void:
	# v34 渐进解锁：锁定键点击 → toast 提示解锁关，不发开面板信号
	if _btn_map.has(key) and _btn_map[key].has_meta("gate_locked") \
			and bool(_btn_map[key].get_meta("gate_locked")):
		_play_sfx("error")
		SignalBus.show_toast.emit("🔒 %s" % _gate_hint(key))
		return
	_play_sfx("button")
	# 切换高亮：再次点击已高亮的按钮则取消高亮（面板关闭由外部处理）
	if _active_btn_key == key:
		_set_active_btn("")
	else:
		_set_active_btn(key)
	emit_signal(signal_name)
	# BU-1：从抽屉点开的入口——信号发出后自动收起（面板已弹出）
	if _drawer_open:
		set_drawer_open(false)

# ── v34 渐进解锁：底栏门控（key 与 data/feature_unlock_schedule.gd 对齐）──
const GATED_KEYS: Array = ["modification", "evolution", "afk"]

func _gate_hint(key: String) -> String:
	var lpm := get_node_or_null("/root/LevelProgressManager")
	if lpm != null and lpm.has_method("feature_gate_hint"):
		return String(lpm.feature_gate_hint(key))
	return ""

func _refresh_feature_gates() -> void:
	var lpm := get_node_or_null("/root/LevelProgressManager")
	for key in GATED_KEYS:
		if not _btn_map.has(key):
			continue
		var btn: Button = _btn_map[key]
		var unlocked := true
		if lpm != null and lpm.has_method("is_feature_unlocked"):
			unlocked = bool(lpm.is_feature_unlocked(key))
		if unlocked:
			btn.modulate = Color.WHITE
			btn.set_meta("gate_locked", false)
			var tip: String = String(SHORTCUT_TOOLTIPS.get(key, ""))
			btn.tooltip_text = tip if not tip.is_empty() else String(btn.text)
		else:
			btn.modulate = Color(0.55, 0.55, 0.55, 0.8)
			btn.set_meta("gate_locked", true)
			btn.tooltip_text = "🔒 %s" % _gate_hint(key)

func _on_feature_unlocked(_key: String) -> void:
	_refresh_feature_gates()

## 设置高亮按钮（传入 "" 清除所有高亮）
func _set_active_btn(key: String) -> void:
	_active_btn_key = key
	# C6: 手写高亮/默认样式 → PanelStyles 工厂（active 复用 pressed 态视觉）
	# v32.3 E1：成长按钮用 amber 档（高亮/恢复都保持与其它键的视觉区分）
	var styles := PanelStyles.make_button_styles(DT.COLOR_ACCENT_CYAN)
	var gold := PanelStyles.make_button_styles(DT.COLOR_AMBER)
	for k in _btn_map:
		var btn: Button = _btn_map[k]
		var st: Dictionary = gold if k == "progression" else styles
		var base_color: Color = Color(0.99, 0.86, 0.60) if k == "progression" else Color(0.75, 0.85, 1.0, 0.9)
		if k == key:
			btn.add_theme_stylebox_override("normal", st["pressed"])
			btn.add_theme_color_override("font_color", base_color)
		elif k not in ["start_battle", "back", "pause", "retreat", "save"]:
			# 恢复默认样式
			btn.add_theme_stylebox_override("normal", st["normal"])
			btn.add_theme_color_override("font_color", base_color)

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
	btn.modulate = Color(0.55, 0.58, 0.62, 1.0) if text == "战斗中" else DT.COLOR_HOVER_WHITE

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
