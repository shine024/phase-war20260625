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
	# 单枚图标尺寸（与血条高度匹配，放血条右侧）
	var icon_size: float = _card_art_width * ICON_WIDTH_FRAC
	_icons.clear()
	_total_height = 0.0
	if _rank_level <= 0:
		visible = false
		queue_redraw()
		return
	visible = true
	# 只画当前实际军衔 1 个图标（rank_level 对应 RANK_ORDER[rank_level-1]）
	var rank_id: String = RankRules.RANK_ORDER[_rank_level - 1]
	var tex: Texture2D = RankIcons.get_icon(rank_id)
	# 图标以本节点原点为中心绘制（position 由 sync_rank_strip 设到血条右侧）
	_icons.append({
		"rect": Rect2(-icon_size * 0.5, -icon_size * 0.5, icon_size, icon_size),
		"tex": tex,
		"color": Color(1.0, 0.95, 0.82, 1.0),
	})
	_total_height = icon_size
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
