extends RefCounted
class_name CardGridBattleLayout
## 格子战术战场列宽 / 卡宽 / 间隙（1280 设计宽，战场 X 40–1240）
## 布局：我方 7 槽 | 中间 1 列空带 | 敌方 7 槽；相邻卡间距 = 0.25×列宽

const BATTLE_X0: float = 40.0
const BATTLE_X1: float = 1240.0
const SLOTS_PER_SIDE: int = 7
const MIDDLE_EMPTY_COLUMNS: int = 1
const TOTAL_COLUMNS: int = SLOTS_PER_SIDE + MIDDLE_EMPTY_COLUMNS + SLOTS_PER_SIDE
const CARD_GAP_RATIO: float = 0.25


static func column_width_px() -> float:
	return (BATTLE_X1 - BATTLE_X0) / float(TOTAL_COLUMNS)


static func card_gap_px() -> float:
	return CARD_GAP_RATIO * column_width_px()


static func battle_card_width_px() -> float:
	## 一侧 N 槽占 N 列：N×卡宽 + (N-1)×间隙 = N×列宽，间隙 = CARD_GAP_RATIO×列宽
	var p: float = column_width_px()
	var n: float = float(SLOTS_PER_SIDE)
	return (n - CARD_GAP_RATIO * (n - 1.0)) / n * p


static func side_band_width_px() -> float:
	return float(SLOTS_PER_SIDE) * column_width_px()


static func slot_pitch_px() -> float:
	return battle_card_width_px() + card_gap_px()


## 带内第 slot_index 个槽（0=靠中线）的局部 X；band_start_x 为我方左缘或敌方带左缘
static func slot_center_x_in_band(band_start_x: float, slot_index: int) -> float:
	var card_w: float = battle_card_width_px()
	var pitch: float = slot_pitch_px()
	return band_start_x + card_w * 0.5 + float(slot_index) * pitch


static func player_band_start_x() -> float:
	return BATTLE_X0


static func enemy_band_start_x() -> float:
	return BATTLE_X1 - side_band_width_px()
