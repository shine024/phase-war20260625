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
const HIGH_CONTRAST_ENABLED := false
const LARGE_TYPE_ENABLED := false

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
			_: return COLOR_ACCENT_CYAN_HIGH_CONTRAST
	else:
		match accent_type:
			"cyan": return COLOR_ACCENT_CYAN
			"purple": return COLOR_ACCENT_PURPLE
			"health": return COLOR_HEALTH
			"energy": return COLOR_ENERGY
			"danger": return COLOR_DANGER
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
