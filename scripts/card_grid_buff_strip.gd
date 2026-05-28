extends Node2D
class_name CardGridBuffStrip
## 卡底加成图标条：受光环影响的单位在卡图下方显示彩色矢量图标。

const CardGridBattleLayout = preload("res://scripts/card_grid_battle_layout.gd")

enum BuffKind {
	RADAR,
	SCOUT,
	FORTRESS,
	COMMAND,
	CARRIER,
}

const ICON_WIDTH_FRAC: float = 0.22
const ICON_GAP_FRAC: float = 0.06

const _BUFF_ORDER: Array[BuffKind] = [
	BuffKind.RADAR,
	BuffKind.SCOUT,
	BuffKind.FORTRESS,
	BuffKind.COMMAND,
	BuffKind.CARRIER,
]

const _BUFF_COLORS: Dictionary = {
	BuffKind.RADAR: Color(0.35, 0.88, 1.0, 0.95),
	BuffKind.SCOUT: Color(0.45, 1.0, 0.55, 0.95),
	BuffKind.FORTRESS: Color(1.0, 0.68, 0.28, 0.95),
	BuffKind.COMMAND: Color(0.92, 0.72, 1.0, 0.95),
	BuffKind.CARRIER: Color(0.3, 0.85, 1.0, 0.95),
}

var _card_art_width: float = 0.0
var _active_kinds: Array[BuffKind] = []
var _icon_layout: Array[Dictionary] = []
var _total_height: float = 0.0


static func collect_buff_kinds(unit: Node) -> Array[BuffKind]:
	var kinds: Array[BuffKind] = []
	if unit == null or not is_instance_valid(unit):
		return kinds
	if unit.has_meta("radar_buffed") and bool(unit.get_meta("radar_buffed")):
		kinds.append(BuffKind.RADAR)
	if unit.has_meta("scout_crit_buffed") and bool(unit.get_meta("scout_crit_buffed")):
		kinds.append(BuffKind.SCOUT)
	if unit.has_meta("fortress_def_buffed") and bool(unit.get_meta("fortress_def_buffed")):
		kinds.append(BuffKind.FORTRESS)
	if unit.has_meta("command_buffed") and bool(unit.get_meta("command_buffed")):
		kinds.append(BuffKind.COMMAND)
	if unit.has_meta("carrier_repair_buffed") and bool(unit.get_meta("carrier_repair_buffed")):
		kinds.append(BuffKind.CARRIER)
	return kinds


static func buff_signature(unit: Node) -> String:
	var parts: PackedStringArray = []
	for kind: BuffKind in collect_buff_kinds(unit):
		parts.append(str(int(kind)))
	return "|".join(parts)


func get_total_height() -> float:
	return _total_height


func rebuild(active_kinds: Array[BuffKind], card_art_width: float = -1.0) -> void:
	_card_art_width = card_art_width if card_art_width > 1.0 else CardGridBattleLayout.battle_card_width_px()
	_active_kinds = active_kinds.duplicate()
	_icon_layout.clear()
	_total_height = 0.0
	if _active_kinds.is_empty():
		visible = false
		queue_redraw()
		return
	visible = true
	var icon_size: float = _card_art_width * ICON_WIDTH_FRAC
	var icon_gap: float = _card_art_width * ICON_GAP_FRAC
	var row_w: float = float(_active_kinds.size()) * icon_size + float(maxi(_active_kinds.size() - 1, 0)) * icon_gap
	var x0: float = -row_w * 0.5
	for i: int in range(_active_kinds.size()):
		var kind: BuffKind = _active_kinds[i]
		_icon_layout.append({
			"kind": kind,
			"rect": Rect2(x0 + float(i) * (icon_size + icon_gap), 0.0, icon_size, icon_size),
			"color": _BUFF_COLORS.get(kind, Color.WHITE),
		})
	_total_height = icon_size
	queue_redraw()


func _draw() -> void:
	for entry: Dictionary in _icon_layout:
		var r: Rect2 = entry["rect"] as Rect2
		var kind: BuffKind = entry["kind"] as BuffKind
		var col: Color = entry["color"] as Color
		var cx: float = r.position.x + r.size.x * 0.5
		var cy: float = r.position.y + r.size.y * 0.5
		var s: float = minf(r.size.x, r.size.y) * 0.42
		match kind:
			BuffKind.RADAR:
				_draw_radar_icon(cx, cy, s, col)
			BuffKind.SCOUT:
				_draw_scout_icon(cx, cy, s, col)
			BuffKind.FORTRESS:
				_draw_fortress_icon(cx, cy, s, col)
			BuffKind.COMMAND:
				_draw_command_icon(cx, cy, s, col)
			BuffKind.CARRIER:
				_draw_carrier_icon(cx, cy, s, col)


func _draw_radar_icon(cx: float, cy: float, s: float, col: Color) -> void:
	draw_arc(Vector2(cx, cy), s * 0.95, -PI * 0.75, -PI * 0.25, 12, col, 1.6, true)
	draw_line(Vector2(cx - s, cy), Vector2(cx + s, cy), col, 1.4, true)
	draw_line(Vector2(cx, cy - s), Vector2(cx, cy + s), col, 1.4, true)
	draw_circle(Vector2(cx, cy), s * 0.14, col)


func _draw_scout_icon(cx: float, cy: float, s: float, col: Color) -> void:
	draw_arc(Vector2(cx, cy), s * 0.72, 0.0, TAU, 24, col, 1.4, true)
	draw_line(Vector2(cx - s, cy), Vector2(cx - s * 0.22, cy), col, 1.4, true)
	draw_line(Vector2(cx + s * 0.22, cy), Vector2(cx + s, cy), col, 1.4, true)
	draw_line(Vector2(cx, cy - s), Vector2(cx, cy - s * 0.22), col, 1.4, true)
	draw_line(Vector2(cx, cy + s * 0.22), Vector2(cx, cy + s), col, 1.4, true)
	draw_circle(Vector2(cx, cy), s * 0.12, col)


func _draw_fortress_icon(cx: float, cy: float, s: float, col: Color) -> void:
	var pts := PackedVector2Array([
		Vector2(cx, cy - s * 0.95),
		Vector2(cx + s * 0.82, cy - s * 0.2),
		Vector2(cx + s * 0.62, cy + s * 0.9),
		Vector2(cx - s * 0.62, cy + s * 0.9),
		Vector2(cx - s * 0.82, cy - s * 0.2),
	])
	draw_colored_polygon(pts, col)
	var inset := PackedVector2Array([
		Vector2(cx, cy - s * 0.45),
		Vector2(cx + s * 0.28, cy + s * 0.05),
		Vector2(cx, cy + s * 0.42),
		Vector2(cx - s * 0.28, cy + s * 0.05),
	])
	draw_colored_polygon(inset, Color(col.r, col.g, col.b, col.a * 0.35))


func _draw_command_icon(cx: float, cy: float, s: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i: int in range(5):
		var outer_a: float = -PI * 0.5 + TAU * float(i) / 5.0
		var inner_a: float = outer_a + TAU / 10.0
		pts.append(Vector2(cx + cos(outer_a) * s, cy + sin(outer_a) * s))
		pts.append(Vector2(cx + cos(inner_a) * s * 0.42, cy + sin(inner_a) * s * 0.42))
	draw_colored_polygon(pts, col)


func _draw_carrier_icon(cx: float, cy: float, s: float, col: Color) -> void:
	draw_line(Vector2(cx - s * 0.85, cy), Vector2(cx + s * 0.85, cy), col, 1.6, true)
	draw_line(Vector2(cx, cy - s * 0.85), Vector2(cx, cy + s * 0.85), col, 1.6, true)
	draw_arc(Vector2(cx, cy), s * 0.78, 0.0, TAU, 20, col, 1.2, true)
	var dot_r: float = s * 0.15
	draw_circle(Vector2(cx, cy - s * 0.85), dot_r, col)
	draw_circle(Vector2(cx, cy + s * 0.85), dot_r, col)
	draw_circle(Vector2(cx - s * 0.85, cy), dot_r, col)
	draw_circle(Vector2(cx + s * 0.85, cy), dot_r, col)
