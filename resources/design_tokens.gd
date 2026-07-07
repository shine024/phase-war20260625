extends Resource
class_name DesignTokens
## Neon Battle HUD design tokens (shared with start screen palette)

# Color palette
const COLOR_BG := Color(0.04, 0.07, 0.12, 1)           # Deep space black
const COLOR_PANEL := Color(0.15, 0.17, 0.25, 1.0)       # Opaque panel
const COLOR_TEXT := Color(0.95, 0.95, 0.98, 1)            # Off-white text
const COLOR_ACCENT_CYAN := Color(0, 0.94, 1, 1)           # Neon cyan
const COLOR_ACCENT_PURPLE := Color(0.55, 0.35, 0.96, 1)   # Neon purple
const COLOR_HEALTH := Color(0.2, 0.9, 0.4, 1)            # Green health
const COLOR_ENERGY := Color(0.9, 0.6, 0.1, 1)            # Orange energy
const COLOR_DANGER := Color(0.9, 0.2, 0.2, 1)            # Red danger

# 补充语义色（v6.10 审核：收敛 3 兄妹面板的重复 THEME_ 常量，为后续新代码提供唯一归宿）
# 数值取自 card_enhancement/evolution/reinforcement 三面板事实标准，避免"绿色3套值、暗文本灰7套值"的发散
const COLOR_GOLD := Color(1.0, 0.85, 0.35, 1)            # 金色（升级/稀有/货币强调）
const COLOR_GREEN_BRIGHT := Color(0.3, 0.92, 0.5, 1)     # 亮绿（增强/提升语义，区别于血量绿）
const COLOR_TEXT_DIM := Color(0.6, 0.66, 0.78, 1)        # 暗文本灰（次要信息/标签）
const COLOR_TEXT_BRIGHT := Color(0.88, 0.92, 0.98, 1)    # 亮文本白（面板正文，区别于纯白）
const COLOR_BORDER := Color(0.25, 0.35, 0.42, 0.7)       # 暗边框（槽位/分隔）

# Typography sizes (base)
const FONT_SIZE_SMALL := 12
const FONT_SIZE_MEDIUM := 16
const FONT_SIZE_LARGE := 20
const FONT_SIZE_TITLE := 32
const FONT_SIZE_HUGE := 48

# Spacing and sizing
const CORNER_RADIUS := 6
const BORDER_WIDTH := 2
const PADDING_SMALL := 8
const PADDING_MEDIUM := 16
const PADDING_LARGE := 24

# Glow settings
const GLOW_ENABLED := true
const GLOW_STRENGTH := 0.8
const GLOW_BLUR := 8

# Accessibility presets
# v7.x(A3): 由 const 改为 static var，使高对比度/大字号可由设置面板运行时切换。
# 初值不变（false），未调用 set_accessibility 前行为与历史版本完全一致。
static var HIGH_CONTRAST_ENABLED := false
static var LARGE_TYPE_ENABLED := false
# v7.x(A3): 新增减少动效开关（控制 screen_shake / 脉冲 tween 是否短路）。
static var MOTION_REDUCE_ENABLED := false

# 注：可访问性变更通知通过 SignalBus.accessibility_changed 广播（autoload 实例信号），
# GDScript 不支持 static signal，故不在此声明。set_accessibility 内部 emit 该信号。

# High contrast palette (derived from base, but brighter)
const COLOR_BG_HIGH_CONTRAST := Color(0.0, 0.0, 0.0, 1)
const COLOR_PANEL_HIGH_CONTRAST := Color(0.05, 0.05, 0.10, 1)
const COLOR_TEXT_HIGH_CONTRAST := Color(1, 1, 1, 1)
const COLOR_ACCENT_CYAN_HIGH_CONTRAST := Color(0.0, 1.0, 1.0, 1)
const COLOR_ACCENT_PURPLE_HIGH_CONTRAST := Color(0.7, 0.5, 1.0, 1)

# Bar dimensions
const BAR_HEIGHT := 20
const BAR_WIDTH := 200
const BAR_BORDER := 2

# Button sizing
const BUTTON_MIN_WIDTH := 120
const BUTTON_HEIGHT := 40
const BUTTON_SPACING := 8

# Get accent color by type
static func get_accent_color(accent_type: String, high_contrast: bool = HIGH_CONTRAST_ENABLED) -> Color:
	if high_contrast:
		match accent_type:
			"cyan": return COLOR_ACCENT_CYAN_HIGH_CONTRAST
			"purple": return COLOR_ACCENT_PURPLE_HIGH_CONTRAST
			"health": return COLOR_HEALTH
			"energy": return COLOR_ENERGY
			"danger": return COLOR_DANGER
			"gold": return COLOR_GOLD
			"green_bright": return COLOR_GREEN_BRIGHT
			_: return COLOR_ACCENT_CYAN_HIGH_CONTRAST
	else:
		match accent_type:
			"cyan": return COLOR_ACCENT_CYAN
			"purple": return COLOR_ACCENT_PURPLE
			"health": return COLOR_HEALTH
			"energy": return COLOR_ENERGY
			"danger": return COLOR_DANGER
			"gold": return COLOR_GOLD
			"green_bright": return COLOR_GREEN_BRIGHT
			_: return COLOR_ACCENT_CYAN

static func get_bg_color(high_contrast: bool = HIGH_CONTRAST_ENABLED) -> Color:
	return COLOR_BG_HIGH_CONTRAST if high_contrast else COLOR_BG

static func get_panel_color(high_contrast: bool = HIGH_CONTRAST_ENABLED) -> Color:
	return COLOR_PANEL_HIGH_CONTRAST if high_contrast else COLOR_PANEL

static func get_text_color(high_contrast: bool = HIGH_CONTRAST_ENABLED) -> Color:
	return COLOR_TEXT_HIGH_CONTRAST if high_contrast else COLOR_TEXT

static func get_font_size(base_size: int, large_type: bool = LARGE_TYPE_ENABLED) -> int:
	if not large_type:
		return base_size
	# 简单放大 25%，向上取整
	return int(ceil(base_size * 1.25))


# ===== v7.x(A3): 运行时可访问性 API =====
# 说明：上面的 get_*(high_contrast = HIGH_CONTRAST_ENABLED) 默认参数在函数定义时
# 求值，不会随 static var 运行时变化而更新。因此设置面板切换后，消费方应改用下列
# 无参 getter（它们实时读取 static var），或监听 accessibility_changed 信号重绘。

# 一次性设置三项可访问性开关，并广播通知。由 settings_panel 调用。
# 通过 SignalBus.accessibility_changed 广播（GDScript 不支持 static signal）。
static func set_accessibility(high_contrast: bool, large_type: bool, motion_reduce: bool) -> void:
	var changed: bool = (HIGH_CONTRAST_ENABLED != high_contrast) \
		or (LARGE_TYPE_ENABLED != large_type) \
		or (MOTION_REDUCE_ENABLED != motion_reduce)
	HIGH_CONTRAST_ENABLED = high_contrast
	LARGE_TYPE_ENABLED = large_type
	MOTION_REDUCE_ENABLED = motion_reduce
	if changed:
		# 经由 SignalBus 广播，让已打开的面板/条 UI 即时重绘。SignalBus 是 autoload，
		# 用 has_node 守卫避免在极早期（SignalBus 尚未就绪）调用崩溃。
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null and tree.root != null and tree.root.has_node("SignalBus"):
			var sb := tree.root.get_node("SignalBus")
			if sb != null and sb.has_signal("accessibility_changed"):
				sb.emit_signal("accessibility_changed")

# 无参 getter（实时读 static var，供消费方在运行时调用）。
static func is_high_contrast() -> bool:
	return HIGH_CONTRAST_ENABLED

static func is_large_type() -> bool:
	return LARGE_TYPE_ENABLED

static func is_motion_reduce() -> bool:
	return MOTION_REDUCE_ENABLED

# 实时读 static var 的颜色/字号 getter（不带默认参数，直接反映当前开关状态）。
static func current_bg_color() -> Color:
	return get_bg_color(HIGH_CONTRAST_ENABLED)

static func current_panel_color() -> Color:
	return get_panel_color(HIGH_CONTRAST_ENABLED)

static func current_text_color() -> Color:
	return get_text_color(HIGH_CONTRAST_ENABLED)

static func current_accent_color(accent_type: String) -> Color:
	return get_accent_color(accent_type, HIGH_CONTRAST_ENABLED)

static func current_font_size(base_size: int) -> int:
	return get_font_size(base_size, LARGE_TYPE_ENABLED)
