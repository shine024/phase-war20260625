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
# v7.x 面板统一：字号收敛到 7 档（XS/S/BODY/M/L/TITLE/HUGE），
# 迁移映射规则：7-11→XS、12/13→S、14/15→BODY、16/17→M、18/20/22→L、24/32→TITLE。
const FONT_SIZE_XSMALL := 10
const FONT_SIZE_SMALL := 12
const FONT_SIZE_BODY := 14
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

# 标准面板尺寸（v7.x 界面一致性修复：统一弹窗三档，视口 1280×720）
# 养成面板（强化/改造/进化/成长）统一 LARGE；图鉴/军衔用 MEDIUM；情报/小弹窗用 SMALL
const PANEL_SIZE_LARGE := Vector2(1180, 640)
const PANEL_SIZE_MEDIUM := Vector2(960, 600)
const PANEL_SIZE_SMALL := Vector2(840, 580)

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


# ===== v7.x UI 重设计：四养成面板统一签名色 + 字体 =====
# 设计语言：每个养成系统有独立签名色，强化琥珀金/改造青蓝/进化紫金/成长整合
# 颜色数值与 docs/design_mockups/养成系统四面板设计.html 对齐。

# —— 四系统签名色 ——
const COLOR_AMBER := Color(0.961, 0.620, 0.043, 1)          # #f59e0b 强化 · 提升
const COLOR_AMBER_SOFT := Color(0.984, 0.749, 0.141, 1)     # #fbbf24
const COLOR_AMBER_DEEP := Color(0.706, 0.325, 0.035, 1)     # #b45309
const COLOR_CYAN_TECH := Color(0.024, 0.714, 0.831, 1)      # #06b6d4 改造 · 科技
const COLOR_CYAN_TECH_SOFT := Color(0.133, 0.827, 0.933, 1) # #22d3ee
const COLOR_VIOLET := Color(0.653, 0.546, 0.980, 1)         # #a78bfa 进化 · 蜕变
const COLOR_VIOLET_SOFT := Color(0.769, 0.710, 0.992, 1)   # #c4b5fd
const COLOR_VIOLET_DEEP := Color(0.486, 0.227, 0.929, 1)   # #7c3aed
const COLOR_GREEN_UP := Color(0.204, 0.827, 0.600, 1)      # #34d399 数值提升（通用）
const COLOR_RED_DOWN := Color(0.937, 0.267, 0.267, 1)      # #ef4444 数值下降/失败

# —— 面板中性色（比 COLOR_BG/PANEL 更深的景深）——
const COLOR_VOID := Color(0.024, 0.035, 0.071, 1)           # #060912 深空黑
const COLOR_PANEL_DEEP := Color(0.051, 0.075, 0.125, 1)     # #0d1320
const COLOR_CARD := Color(0.075, 0.102, 0.165, 1)           # #131a2a
const COLOR_CARD_HI := Color(0.102, 0.141, 0.220, 1)        # #1a2438
const COLOR_SLOT_LOCKED := Color(0.039, 0.059, 0.110, 1)   # #0a0f1c

# —— 兼容别名（v7.x UI 重设计过渡期，供新面板代码引用）——
# 命名与 HTML 设计稿 CSS 变量对齐，避免新旧常量名混乱
const COLOR_BG_CARD := Color(0.075, 0.102, 0.165, 1)        # 同 COLOR_CARD
const COLOR_BG_SLOT := Color(0.039, 0.059, 0.110, 1)        # 同 COLOR_SLOT_LOCKED
const COLOR_BORDER_DIM := Color(0.25, 0.35, 0.42, 0.14)     # 极暗边框
const COLOR_TEXT_FAINT := Color(0.27, 0.31, 0.39, 1)        # 极暗文本（标签/角标）
const COLOR_TEXT_MID := Color(0.67, 0.72, 0.82, 1)          # 中等文本（次要信息）
# 注：COLOR_AMBER_DEEP 已在上方签名色段定义（#b45309）

# 签名色 → 发光色辅助（带 alpha，用于阴影/外发光）
const COLOR_AMBER_GLOW := Color(0.961, 0.620, 0.043, 0.35)
const COLOR_CYAN_TECH_GLOW := Color(0.024, 0.714, 0.831, 0.35)
const COLOR_VIOLET_GLOW := Color(0.653, 0.546, 0.980, 0.40)

# —— 稀有度色（与 backpack_card_item / GC.get_rarity_color 对齐）——
const COLOR_RARITY_COMMON := Color(0.420, 0.463, 0.569, 1)    # #6b7691
const COLOR_RARITY_UNCOMMON := Color(0.133, 0.773, 0.369, 1)  # #22c55e
const COLOR_RARITY_RARE := Color(0.220, 0.741, 0.973, 1)      # #38bdf8
const COLOR_RARITY_EPIC := Color(0.753, 0.518, 0.988, 1)      # #c084fc
const COLOR_RARITY_LEGENDARY := Color(0.961, 0.620, 0.043, 1) # #f59e0b（与 COLOR_AMBER 同）
const COLOR_RARITY_MYTHIC := Color(0.937, 0.267, 0.267, 1)    # #ef4444（与 COLOR_RED_DOWN 同）

# —— 兵种色（CombatKind 0-4：LIGHT/ARMOR/SUPPORT/AIR/FORT）——
# v1.5：单一权威源。原 modification_panel/evolution_panel/growth_panel 各有一份 _get_kind_color，
# 且键名按"步兵/炮兵/防空..."match，但 CardResource.get_combat_kind_name 只返回"轻装/装甲/支援/空中/堡垒"，
# 导致除装甲外全部 fallback 灰。此处用 int 索引（与枚举值 1:1），数值照搬 backpack_card_item._V9_KIND_COLORS。
const COLOR_KIND_LIGHT := Color(0.898, 0.282, 0.302, 1)   # 0 轻装/步兵 红 #e5484d
const COLOR_KIND_ARMOR := Color(0.302, 0.498, 0.898, 1)   # 1 装甲 蓝 #4d7fe5
const COLOR_KIND_SUPPORT := Color(0.898, 0.596, 0.125, 1) # 2 支援/炮兵 橙 #e59820
const COLOR_KIND_AIR := Color(0.302, 0.802, 0.898, 1)     # 3 空军 青 #4dcce5
const COLOR_KIND_FORT := Color(0.624, 0.624, 0.624, 1)    # 4 堡垒 灰 #9f9f9f

const KIND_COLORS := {
	0: COLOR_KIND_LIGHT,
	1: COLOR_KIND_ARMOR,
	2: COLOR_KIND_SUPPORT,
	3: COLOR_KIND_AIR,
	4: COLOR_KIND_FORT,
}
# 兵种单字字形（与 CardResource.get_combat_kind_short 一致：轻/甲/援/空/堡）
const KIND_GLYPHS := {
	0: "轻", 1: "甲", 2: "援", 3: "空", 4: "堡",
}

## 按 combat_kind 整数取兵种色，越界返回中性灰（v1.5 统一入口）
static func get_kind_color(combat_kind: int) -> Color:
	return KIND_COLORS.get(combat_kind, Color(0.624, 0.624, 0.624, 1))

## 按 combat_kind 整数取兵种单字字形，越界返回 "?"
static func get_kind_glyph(combat_kind: int) -> String:
	return KIND_GLYPHS.get(combat_kind, "?")

# —— 字体资源路径（v7.x UI 重设计新增 Rajdhani）——
const FONT_PATH_TITLE := "res://assets/fonts/Rajdhani-SemiBold.ttf"  # 标题/数字
const FONT_PATH_TITLE_BOLD := "res://assets/fonts/Rajdhani-Bold.ttf"
const FONT_PATH_BODY := "res://assets/fonts/Rajdhani-Regular.ttf"     # 正文
# 注：data_font.ttf（Barlow）保留用于纯数字场景；中文走 Godot fallback（Noto Sans CJK）

# 字体缓存（避免每面板重复 load）
static var _title_font: FontFile = null
static var _title_font_bold: FontFile = null
static var _body_font: FontFile = null

# 获取 Rajdhani SemiBold（标题/数据展示），加载失败回退 ThemeDB.fallback_font
static func get_title_font() -> Font:
	if _title_font == null:
		_title_font = load(FONT_PATH_TITLE) as FontFile
		if _title_font == null:
			return ThemeDB.fallback_font
	return _title_font

# 获取 Rajdhani Bold（强调标题）
static func get_title_font_bold() -> Font:
	if _title_font_bold == null:
		_title_font_bold = load(FONT_PATH_TITLE_BOLD) as FontFile
		if _title_font_bold == null:
			return get_title_font()
	return _title_font_bold

# 获取 Rajdhani Regular（正文）
static func get_body_font() -> Font:
	if _body_font == null:
		_body_font = load(FONT_PATH_BODY) as FontFile
		if _body_font == null:
			return ThemeDB.fallback_font
	return _body_font

# 系统签名色快捷取（system: "amber"|"cyan"|"violet"|"gold"|"green_up"|"red_down"）
static func get_system_color(system: String) -> Color:
	match system:
		"amber", "enhance": return COLOR_AMBER
		"amber_soft": return COLOR_AMBER_SOFT
		"cyan", "modify": return COLOR_CYAN_TECH
		"cyan_soft": return COLOR_CYAN_TECH_SOFT
		"violet", "evolve": return COLOR_VIOLET
		"violet_soft": return COLOR_VIOLET_SOFT
		"gold", "growth": return COLOR_GOLD
		"green_up": return COLOR_GREEN_UP
		"red_down": return COLOR_RED_DOWN
		_: return COLOR_ACCENT_CYAN

# 系统签名色 → 对应发光色
static func get_system_glow(system: String) -> Color:
	match system:
		"amber", "enhance": return COLOR_AMBER_GLOW
		"cyan", "modify": return COLOR_CYAN_TECH_GLOW
		"violet", "evolve": return COLOR_VIOLET_GLOW
		"gold", "growth": return Color(1.0, 0.85, 0.35, 0.40)
		_: return Color(0, 0.94, 1, 0.35)


# ===== 面板签名色（v7.x 面板统一：每个功能面板一个 accent，标题栏/边框/强调态共用） =====
# 视觉方向对齐 docs/界面一致性/design_06_visual_direction.html（军事科幻 + 霓虹光晕 + 冷色调）。
# 养成四面板沿用签名色：强化=amber；本表覆盖未接入 DT 的功能面板。
const PANEL_ACCENTS := {
	"store": COLOR_GOLD,             # 公司商店 · 金（货币/交易语义，沿用原金色主题）
	"quest": COLOR_ACCENT_CYAN,      # 任务 · 霓虹青
	"faction": COLOR_ACCENT_PURPLE,  # 势力 · 霓虹紫
	"occupation": COLOR_ACCENT_CYAN, # 势力领地图 · 青（地图/战术语义）
	"intelligence": COLOR_VIOLET,    # 情报中心 · 紫（隐秘语义）
	"drops": COLOR_ENERGY,           # 掉落背包 · 橙（战利品语义）
	"achievement": COLOR_GOLD,       # 成就 · 金（荣誉语义）
	"daily": COLOR_GREEN_BRIGHT,     # 每日任务 · 亮绿（日常/刷新语义）
	"settings": Color(0.55, 0.65, 0.75, 1),  # 设置 · 中性冷灰蓝（工具面板不抢戏）
	"collection": COLOR_CYAN_TECH,   # 图鉴 · 科技青
	"reinforcement": COLOR_GREEN_BRIGHT,  # 强化面板 · 亮绿（提升语义，区别于 card_enhancement 的琥珀）
	"leaderboard": COLOR_GOLD,       # 排行榜 · 金（竞技荣誉语义）
}

## 面板 accent 单一入口：未知 panel_id 回退霓虹青
static func get_panel_accent(panel_id: String) -> Color:
	return PANEL_ACCENTS.get(panel_id, COLOR_ACCENT_CYAN)
