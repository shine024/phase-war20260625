extends PanelContainer
## MOD模块槽位预制体

const SLOT_COLORS = {
	"A": Color(0.0, 0.902, 0.463),
	"B": Color(0.29, 0.561, 0.851),
	"C": Color(1.0, 0.753, 0.0),
}

const SLOT_BG_A = Color(0.0, 0.902, 0.463, 0.04)
const SLOT_BG_B = Color(0.29, 0.561, 0.851, 0.04)
const SLOT_BG_C = Color(1.0, 0.753, 0.0, 0.04)

var _slot_index: int = 1
var _mod_data: Dictionary = {}

@onready var _label: Label = $Margin/VBox/Label
@onready var _icon: Label = $Margin/VBox/Icon
@onready var _name: Label = $Margin/VBox/Name
@onready var _level: Label = $Margin/VBox/Level

func set_slot_index(idx: int) -> void:
	_slot_index = idx
	if _label:
		_label.text = "S%d" % idx

func set_mod(mod_data: Dictionary) -> void:
	_mod_data = mod_data
	if not _name or not _level or not _icon:
		return
	if mod_data.is_empty():
		_icon.text = "+"
		_icon.modulate = Color(0.333, 0.4, 0.467, 0.3)
		_name.text = "空"
		_name.modulate = Color(0.333, 0.4, 0.467)
		_level.text = ""
		_set_empty_style()
	else:
		_icon.text = mod_data.get("icon", "\u2699")
		_icon.modulate = Color.WHITE
		_name.text = mod_data.get("name", "")
		var lv: int = mod_data.get("level", 1)
		_level.text = "Lv.%d" % lv
		_level.modulate = Color(0.533, 0.608, 0.678)
		_set_filled_style(mod_data.get("tier", ""))

func _set_empty_style() -> void:
	add_theme_stylebox_override("panel", _get_stylebox(Color(1, 1, 1, 0.03), Color(0.2, 0.23, 0.278, 0.3), true))

func _set_filled_style(tier: String) -> void:
	var tier_key: String = tier if tier in SLOT_COLORS else "A"
	var col: Color = SLOT_COLORS[tier_key]
	var bg: Color = SLOT_BG_A if tier_key == "A" else (SLOT_BG_B if tier_key == "B" else SLOT_BG_C)
	add_theme_stylebox_override("panel", _get_stylebox(bg, col, false))

static func _get_stylebox(bg_color: Color, border_color: Color, dashed: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(3)
	sb.bg_color = bg_color
	sb.border_color = border_color
	if dashed:
		sb.draw_center = false  # approximate dashed
	else:
		sb.set_border_width_all(1)
	sb.content_left = 4
	sb.content_top = 2
	sb.content_right = 4
	sb.content_bottom = 2
	return sb
