extends Node2D
class_name CardGridRankStrip
## 卡顶军衔条：自上而下绘制——元帅在最上行，士档（含下士）在最下行靠卡图。
## 每行总宽 = 卡图宽；单格图标更大、格间更紧。

const RankRules = preload("res://data/rank_rules.gd")
const RankIcons = preload("res://scripts/rank_icons.gd")
const CardGridBattleLayout = preload("res://scripts/card_grid_battle_layout.gd")

## 单枚图标占卡宽（3 枚 + 2 缝 = 1.0 卡宽）
const ICON_WIDTH_FRAC: float = 0.32
const ICON_GAP_FRAC: float = (1.0 - ICON_WIDTH_FRAC * 3.0) / 2.0
## 行距（相对图标高，略收紧）
const ROW_GAP_FRAC: float = 0.12

const _TIER_LIT: Array[Color] = [
	Color(1.0, 1.0, 1.0, 1.0),
	Color(1.0, 1.0, 1.0, 1.0),
	Color(1.0, 0.95, 0.82, 1.0),
	Color(1.0, 0.88, 0.72, 1.0),
	Color(1.0, 0.92, 0.55, 1.0),
]
const _TIER_DIM: Color = Color(0.55, 0.56, 0.6, 0.42)

var _rank_level: int = 0
var _card_art_width: float = 0.0
var _total_height: float = 0.0
var _icons: Array[Dictionary] = []


func get_total_height() -> float:
	return _total_height


func rebuild(rank_level: int, card_art_width: float = -1.0) -> void:
	_rank_level = clampi(rank_level, 0, RankRules.RANK_LEVEL_MAX)
	_card_art_width = card_art_width if card_art_width > 1.0 else CardGridBattleLayout.battle_card_width_px()
	var icon_size: float = _card_art_width * ICON_WIDTH_FRAC
	var icon_gap: float = _card_art_width * ICON_GAP_FRAC
	var row_gap: float = icon_size * ROW_GAP_FRAC
	_icons.clear()
	_total_height = 0.0
	var tier_count: int = RankRules.visible_tier_count(_rank_level)
	if tier_count <= 0:
		visible = false
		queue_redraw()
		return
	visible = true
	var row_w: float = _card_art_width
	var x0: float = -row_w * 0.5
	var y: float = 0.0
	# 高军衔在上（y 小）：先画元帅行 tier4，最后画士档 tier0（靠卡图一侧）
	for ti: int in range(tier_count - 1, -1, -1):
		var tier: int = ti
		var slots: int = 1 if tier == 4 else RankRules.RANK_ICONS_PER_ROW
		for slot: int in range(slots):
			if not RankRules.is_rank_icon_shown(_rank_level, tier, slot):
				continue
			var slot_x: float = x0 + float(slot) * (icon_size + icon_gap)
			if tier == 4:
				slot_x = -icon_size * 0.5
			var lit: bool = RankRules.is_rank_icon_lit(_rank_level, tier, slot)
			var global_slot: int = 13 if tier == 4 else tier * RankRules.RANK_ICONS_PER_ROW + slot + 1
			var rank_id: String = RankRules.RANK_ORDER[global_slot - 1]
			var tex: Texture2D = RankIcons.get_icon(rank_id)
			_icons.append({
				"rect": Rect2(slot_x, y, icon_size, icon_size),
				"tex": tex,
				"color": _TIER_LIT[mini(tier, _TIER_LIT.size() - 1)] if lit else _TIER_DIM,
			})
		y += icon_size + row_gap
	_total_height = y - row_gap if y > 0.0 else 0.0
	queue_redraw()


func _draw() -> void:
	for entry: Dictionary in _icons:
		var r: Rect2 = entry["rect"] as Rect2
		var col: Color = entry["color"] as Color
		var tex: Texture2D = entry.get("tex") as Texture2D
		if tex != null:
			draw_texture_rect(tex, r, false, col)
		else:
			draw_rect(r, col)
