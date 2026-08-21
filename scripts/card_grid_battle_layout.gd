extends RefCounted
class_name CardGridBattleLayout
## 格子战术战场列宽 / 卡宽 / 间隙（1280 设计宽，战场 X 40–1240）
## 布局：3 行 × 3 列（每侧 9 格）
## 每列：我方 3 格 | 中间 1 列空 | 敌方 3 格；共 7 列
## 每行 3 格等距水平排列，3 行垂直非等距交错
## 全局共 7 列（3+1+3），每侧 9 格（3行×3列），无边缘禁放。

const BATTLE_X0: float = 40.0
const BATTLE_X1: float = 1240.0
const SLOTS_PER_SIDE: int = 3    ## 每行每侧 3 格
const NUM_ROWS: int = 3          ## 垂直方向 3 行
const MIDDLE_EMPTY_COLUMNS: int = 1
const TOTAL_COLUMNS: int = SLOTS_PER_SIDE + MIDDLE_EMPTY_COLUMNS + SLOTS_PER_SIDE  # = 7
## 每侧总槽位数 = 每行格数 × 行数
const TOTAL_SLOTS_PER_SIDE: int = SLOTS_PER_SIDE * NUM_ROWS  # = 9
const CARD_GAP_RATIO: float = 0.25
## 中间空带宽度（两侧阵型之间的间隙）。v9.5: 从原 1 列(≈172) 收紧到 60——仅减小中间；
## 单位列宽/卡牌大小/行内间距均不变（column_width_px 与中间带解耦）。
const MIDDLE_GAP_PX: float = 60.0

## 卡图基础宽度（旧双行布局 = 58.9px）。三行布局槽位水平间距随列宽变大，但卡图视觉
## 大小保持与旧双行相同，通过 CardGridThumbnailScale 用此常量缩放，再乘以军衔/战力乘数。
const BASE_CARD_WIDTH_PX: float = 58.9

## 3 行垂直间距（行偏移 = Y 相对于车道中心的像素偏移）
## v9.5: 均匀 65px——上行-120 / 中行-55 / 下行10（row0/row1 同步上移55，底间距从10放开到65）
## row_offsets[0] = 上行，row_offsets[1] = 中行，row_offsets[2] = 下行
const ROW_Y_OFFSETS: Array[float] = [-120.0, -55.0, 10.0]


static func column_width_px() -> float:
	# 单位列宽——保持 (X1-X0)/7 = 171.43 不变，使卡牌大小与行内间距不受中间空带影响。
	# （中间空带改为独立 MIDDLE_GAP_PX；此处除数 7 为基准，不再代表实际列数。）
	return (BATTLE_X1 - BATTLE_X0) / 7.0


static func card_gap_px() -> float:
	return CARD_GAP_RATIO * column_width_px()


static func battle_card_width_px() -> float:
	## 一侧 N 槽占 N 列：N×卡宽 + (N-1)×间隙 = N×列宽
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


## 根据全局槽位编号（0..TOTAL_SLOTS_PER_SIDE-1）提取行号（0=上行，1=中行，2=下行）
## 布局：槽位编号按行主序排列
##   我方：row0=[0,1,2] row1=[3,4,5] row2=[6,7,8]
##   敌方：row0=[0,1,2] row1=[3,4,5] row2=[6,7,8]
static func get_row_for_slot(slot_index: int) -> int:
	return slot_index / SLOTS_PER_SIDE


## 根据行号返回 Y 偏移（上行为负、中行为 0、下行正；非等距）
static func row_y_offset(row: int) -> float:
	if row < 0 or row >= NUM_ROWS:
		return 0.0
	return ROW_Y_OFFSETS[row]


## 根据槽位编号返回 Y 偏移（用于计算槽位中心 Y）
static func slot_y_offset_for_index(slot_index: int) -> float:
	var row: int = get_row_for_slot(slot_index)
	return row_y_offset(row)


## v9.5: 斜阵每行 X 错位量——我方 ///（上行靠中线）、敌方 \\\ 镜像。
## 我方在左带（+X = 朝中线）：row0 = +S（上行朝中线）、row1 = 0、row2 = -S（下行朝外缘）。
## 敌方在右带镜像（dir 取反）。S = 列宽 × ROW_X_STAGGER_RATIO ≈ 34px（可调）。
const ROW_X_STAGGER_RATIO: float = 0.20
static func slot_row_x_stagger(row: int, is_enemy: bool) -> float:
	var s: float = column_width_px() * ROW_X_STAGGER_RATIO
	var dir: float = -1.0 if is_enemy else 1.0
	match row:
		0: return s * dir
		2: return -s * dir
		_: return 0.0


## v9.2: 判定单位是否位于上行（分行索敌/溅射同行收敛用）。
## 单行返回 false（默认按下行兜底）。
static func is_unit_in_upper_row(unit: Node) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false
	var slot: int = -1
	if unit.has_meta("card_grid_slot"):
		slot = int(unit.get_meta("card_grid_slot", -1))
	if slot < 0 and unit.has_meta("card_grid_enemy_slot"):
		slot = int(unit.get_meta("card_grid_enemy_slot", -1))
	if slot < 0:
		return false
	return get_row_for_slot(slot) == 0


## v9.2: 判定两个单位是否位于同一行（分行索敌核心判定）。
## 有行号（row 0/1/2）则比较行号；无 slot meta 视为同行（不参与行过滤）。
static func units_in_same_row(a: Node, b: Node) -> bool:
	if a == null or b == null or not is_instance_valid(a) or not is_instance_valid(b):
		return true
	## 双方都有 slot meta 时才按行过滤
	if a.has_meta("card_grid_slot") or a.has_meta("card_grid_enemy_slot"):
		if b.has_meta("card_grid_slot") or b.has_meta("card_grid_enemy_slot"):
			var row_a: int = -1
			var slot_a: int = -1
			if a.has_meta("card_grid_slot"):
				slot_a = int(a.get_meta("card_grid_slot", -1))
			elif a.has_meta("card_grid_enemy_slot"):
				slot_a = int(a.get_meta("card_grid_enemy_slot", -1))
			if slot_a >= 0:
				row_a = get_row_for_slot(slot_a)
			var row_b: int = -1
			var slot_b: int = -1
			if b.has_meta("card_grid_slot"):
				slot_b = int(b.get_meta("card_grid_slot", -1))
			elif b.has_meta("card_grid_enemy_slot"):
				slot_b = int(b.get_meta("card_grid_enemy_slot", -1))
			if slot_b >= 0:
				row_b = get_row_for_slot(slot_b)
			if row_a >= 0 and row_b >= 0:
				return row_a == row_b
	return true  # 防御性兜底


const GC = preload("res://resources/game_constants.gd")
const GameCfg = preload("res://resources/game_config.gd")

## v9.x: 直射武器跨行射击伤害乘区。
## 规则：曲射/空射（is_indirect_weapon_type，含 legacy 曲射值 ROCKET/FLAK/MISSILE）全场全额恒 1.0；
##       直射同行全额 1.0，跨行 ×cross_row_direct_damage_mult（GameConfig 可调，默认 0.70）。
## 无 slot meta 的节点（相位场等）由 units_in_same_row 兜底视为同行，不惩罚。
## 由开火侧调用（construct_unit_ai / enemy_unit / swarm_enemy_controller），乘在弹道分发前的
## damage 上——批处理弹道直传伤害不重算，不在此处乘则永不生效。
static func cross_row_direct_multiplier(shooter: Node2D, target: Node2D, weapon_type: int) -> float:
	if GC.is_indirect_weapon_type(weapon_type):
		return 1.0
	if units_in_same_row(shooter, target):
		return 1.0
	return GameCfg.get_default().cross_row_direct_damage_mult


## 两侧阵型 + 中间空带的总宽度
static func total_grid_width_px() -> float:
	return side_band_width_px() * 2.0 + MIDDLE_GAP_PX

## 我方带左缘：整体居中（左右等量边距），两侧阵型同步内收、中间收紧
static func player_band_start_x() -> float:
	return BATTLE_X0 + ((BATTLE_X1 - BATTLE_X0) - total_grid_width_px()) * 0.5

## 敌方带左缘：我方带右缘 + 中间空带
static func enemy_band_start_x() -> float:
	return player_band_start_x() + side_band_width_px() + MIDDLE_GAP_PX
