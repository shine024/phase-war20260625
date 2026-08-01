extends RefCounted
class_name CardGridBattleLayout
## 格子战术战场列宽 / 卡宽 / 间隙（1280 设计宽，战场 X 40–1240）
## 布局：我方 7 槽 | 中间 2 列空带 | 敌方 7 槽；相邻卡间距 = 0.25×列宽
## 全局共 16 列：位置 1(最左/我方 slot 0)与位置 16(最右/敌方 slot N-1)靠屏幕边禁放。
## 故每侧 7 槽中实际可用 6 槽：我方 slot 1~6、敌方 slot 0~5。
## 双行交错：等距 slot + 奇偶分行即天然蜂巢（上行格在下行两格缝隙正中）。
## 效果（可用 6 槽）：我方 上1/下2/上3/下4/上5/下6，敌方 下0/上1/下2/上3/下4/上5（镜像）。

const BATTLE_X0: float = 40.0
const BATTLE_X1: float = 1240.0
const SLOTS_PER_SIDE: int = 7
const MIDDLE_EMPTY_COLUMNS: int = 2
const TOTAL_COLUMNS: int = SLOTS_PER_SIDE + MIDDLE_EMPTY_COLUMNS + SLOTS_PER_SIDE
const CARD_GAP_RATIO: float = 0.25

## 双行交错排布：奇数索引槽位在上行（Y - OFFSET），偶数索引在下行（Y + OFFSET）。
## 上下行间距 = 2 × OFFSET。敌我同索引同 Y，对位单位视觉对称、子弹水平飞行最自然。
## 注：等距 slot + 奇偶分行已是天然蜂巢（上行格在下行两格缝隙正中），无需额外 X 错缝。
const CARD_GRID_ROW_Y_OFFSET: float = 30.0

## 双行整体竖直偏移：上行与下行一起相对车道中心向屏幕下方平移的像素数。
## 只平移双行视觉位置，不动车道中心 / spawn 点 / 部署带。
const CARD_GRID_ROW_VERTICAL_SHIFT: float = 10.0


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


## 双行交错：奇数索引（slot 1/3/5）在上行，偶数索引（slot 0/2/4/6）在下行。
## for_enemy=true 时反转奇偶（敌方镜像），让敌我对位单位落在同一行，中缝距离两行一致。
## 返回相对车道中心的 Y 偏移（上行为负、下行为正）。加到 _lane_y_center 上即得槽位 Y。
static func slot_y_offset_for_index(slot_index: int, for_enemy: bool = false) -> float:
	var upper: bool = (slot_index % 2 == 1)
	if for_enemy:
		upper = not upper
	if upper:
		return -CARD_GRID_ROW_Y_OFFSET + CARD_GRID_ROW_VERTICAL_SHIFT
	return CARD_GRID_ROW_Y_OFFSET + CARD_GRID_ROW_VERTICAL_SHIFT


static func player_band_start_x() -> float:
	return BATTLE_X0


static func enemy_band_start_x() -> float:
	return BATTLE_X1 - side_band_width_px()
