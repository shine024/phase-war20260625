extends RefCounted
class_name CardGridBattleLayout
## 格子战术战场列宽 / 卡宽 / 间隙（1280 设计宽，战场 X 40–1240）
## 布局：3 行 × 3 列（每侧 9 格）
## 每列：我方 3 格 | 中间 1 列空 | 敌方 3 格；共 7 列
## 每行 3 格等距水平排列，3 行垂直非等距交错
## 全局共 7 列（3+1+3），每侧 9 格（3行×3列），无边缘禁放。
##
## ── v26.2 每关布局（激活态） ──────────────────────────────────────────
## 下方 DEFAULT_* 常量是"3 行 3 列无禁放"的默认布局（与历史行为逐像素一致）；
## battle_manager.start_battle 调 apply_for_level(level) 从 LevelBattleLayouts
## 读该关布局写入 static 激活态，end_battle 调 reset_to_default() 复位（防跨场泄漏）。
## 所有几何函数读激活态而非常量；未 apply 时（headless 测试/准备界面）即默认布局。
## 几何保真：column_width_px = (X1-X0) / max(7, cols_p+cols_e+1)——3×3 时除数 7
## 与旧实现一致；4 列关自动缩列宽，两侧带 + 中间带总宽恒 ≤ 1200。

const BATTLE_X0: float = 40.0
const BATTLE_X1: float = 1240.0
## UI 四级标准修复 R-C1：阵型带视口自适应——1280 画布返回 40..1240（历史值，
## 16:9 布局逐像素不变红线）；画布更宽（stretch=expand 下 21:9/32:9）时带整体
## 平移居中（带宽恒 1200 不变——单位尺寸/列宽不动，只是不再挤在左侧）；
## 窄于 1280 不收缩（维持 40..1240，防负带）。消费方一律走 band_x0()/band_x1()，
## BATTLE_X0/X1 常量保留为 1280 基准值。
static func band_x0() -> float:
	return _viewport_band().x

static func band_x1() -> float:
	return _viewport_band().y

static func _viewport_band() -> Vector2:
	var vw := 1280.0
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		vw = tree.root.get_visible_rect().size.x
	if vw <= 1280.0:
		return Vector2(BATTLE_X0, BATTLE_X1)
	var x0: float = (vw - (BATTLE_X1 - BATTLE_X0)) * 0.5
	return Vector2(x0, x0 + (BATTLE_X1 - BATTLE_X0))
const SLOTS_PER_SIDE: int = 3    ## 默认每行每侧 3 格（历史兼容常量；运行时读 active_player_cols/enemy_cols）
const NUM_ROWS: int = 3          ## 默认垂直方向 3 行（历史兼容常量；运行时读 active_rows()）
const MIDDLE_EMPTY_COLUMNS: int = 1
const TOTAL_COLUMNS: int = SLOTS_PER_SIDE + MIDDLE_EMPTY_COLUMNS + SLOTS_PER_SIDE  # = 7
## 每侧总槽位数 = 每行格数 × 行数（默认布局；运行时读 player_slots_total/enemy_slots_total）
const TOTAL_SLOTS_PER_SIDE: int = SLOTS_PER_SIDE * NUM_ROWS  # = 9
const CARD_GAP_RATIO: float = 0.25
## 中间空带宽度（两侧阵型之间的间隙）。v9.5: 从原 1 列(≈172) 收紧到 60——仅减小中间；
## 单位列宽/卡牌大小/行内间距均不变（column_width_px 与中间带解耦）。
const MIDDLE_GAP_PX: float = 60.0

## 卡图基础宽度（旧双行布局 = 58.9px）。三行布局槽位水平间距随列宽变大，但卡图视觉
## 大小保持与旧双行相同，通过 CardGridThumbnailScale 用此常量缩放，再乘以军衔/战力乘数。
const BASE_CARD_WIDTH_PX: float = 58.9

## 默认 3 行垂直间距（行偏移 = Y 相对于车道中心的像素偏移）
## v9.5: 均匀 65px——上行-120 / 中行-55 / 下行10（row0/row1 同步上移55，底间距从10放开到65）
## row_offsets[0] = 上行，row_offsets[1] = 中行，row_offsets[2] = 下行
const ROW_Y_OFFSETS: Array[float] = [-120.0, -55.0, 10.0]
## 2 行布局的行偏移：沿用 3 行的上下边线（-120/10），行距放开到 130
const ROW_Y_OFFSETS_2ROWS: Array[float] = [-120.0, 10.0]

# ── v26.2 激活态（battle_manager 在每场 start_battle 设置 / end_battle 复位） ──
static var _active_rows: int = NUM_ROWS
static var _active_player_cols: int = SLOTS_PER_SIDE
static var _active_enemy_cols: int = SLOTS_PER_SIDE
static var _active_player_excluded: Array = []
static var _active_enemy_excluded: Array = []
static var _layout_customized: bool = false

const LevelBattleLayoutsRef = preload("res://data/level_battle_layouts.gd")
const GameCfgLayout = preload("res://resources/game_config.gd")


## 从 LevelBattleLayouts 读该关布局激活（GameConfig.battle_layouts_enabled=false 时跳过）。
## 返回是否激活了非默认布局。
static func apply_for_level(level: int) -> bool:
	reset_to_default()
	if not bool(GameCfgLayout.get_default().battle_layouts_enabled):
		return false
	var spec: Dictionary = LevelBattleLayoutsRef.get_for_level(level)
	if spec.is_empty():
		return false
	_active_rows = clampi(int(spec.get("rows", NUM_ROWS)), 2, 3)
	_active_player_cols = clampi(int(spec.get("player_cols", SLOTS_PER_SIDE)), 2, 4)
	_active_enemy_cols = clampi(int(spec.get("enemy_cols", SLOTS_PER_SIDE)), 2, 4)
	_active_player_excluded = _sanitize_excluded(spec.get("player_excluded", []), _active_player_cols * _active_rows)
	_active_enemy_excluded = _sanitize_excluded(spec.get("enemy_excluded", []), _active_enemy_cols * _active_rows)
	_layout_customized = true
	return true


static func reset_to_default() -> void:
	_active_rows = NUM_ROWS
	_active_player_cols = SLOTS_PER_SIDE
	_active_enemy_cols = SLOTS_PER_SIDE
	_active_player_excluded = []
	_active_enemy_excluded = []
	_layout_customized = false


static func _sanitize_excluded(list: Variant, total: int) -> Array:
	var out: Array = []
	if list is Array:
		for v in list:
			var i: int = int(v)
			if i >= 0 and i < total and not out.has(i):
				out.append(i)
	out.sort()
	return out


## 当前是否激活了非默认布局（UI 题面提示用）
static func is_custom_layout_active() -> bool:
	return _layout_customized

static func active_rows() -> int:
	return _active_rows

static func active_player_cols() -> int:
	return _active_player_cols

static func active_enemy_cols() -> int:
	return _active_enemy_cols

static func player_slots_total() -> int:
	return _active_player_cols * _active_rows

static func enemy_slots_total() -> int:
	return _active_enemy_cols * _active_rows

## 槽位是否为废墟禁放格（side: "player"/"enemy"）
static func is_slot_excluded(slot_index: int, side: String = "player") -> bool:
	if slot_index < 0:
		return false
	var table: Array = _active_enemy_excluded if side == "enemy" else _active_player_excluded
	return table.has(slot_index)


## 单位列宽——默认布局 (X1-X0)/7 = 171.43 与历史一致；宽阵关按总列数收窄。
## （中间空带为独立 MIDDLE_GAP_PX；除数 max(7, cols_p+cols_e+1) 保证 3×3 逐像素不变。）
## R-C1：带宽走 band_x0/band_x1（视口自适应，带宽恒 1200 → 列宽与 1280 画布恒等）。
static func column_width_px() -> float:
	var divisor: float = maxf(7.0, float(_active_player_cols + _active_enemy_cols + 1))
	return (band_x1() - band_x0()) / divisor


static func card_gap_px() -> float:
	return CARD_GAP_RATIO * column_width_px()


## 一侧 N 槽占 N 列：N×卡宽 + (N-1)×间隙 = N×列宽（敌我列数可不同，卡宽按侧取）
static func battle_card_width_px(is_enemy: bool = false) -> float:
	var p: float = column_width_px()
	var n: float = float(_active_enemy_cols if is_enemy else _active_player_cols)
	return (n - CARD_GAP_RATIO * (n - 1.0)) / n * p


static func side_band_width_px(is_enemy: bool = false) -> float:
	return float(_active_enemy_cols if is_enemy else _active_player_cols) * column_width_px()


static func slot_pitch_px(is_enemy: bool = false) -> float:
	return battle_card_width_px(is_enemy) + card_gap_px()


## 带内第 slot_index 个槽（0=靠外缘一侧带首）的局部 X；band_start_x 为该侧带左缘
static func slot_center_x_in_band(band_start_x: float, slot_index: int, is_enemy: bool = false) -> float:
	var card_w: float = battle_card_width_px(is_enemy)
	var pitch: float = slot_pitch_px(is_enemy)
	return band_start_x + card_w * 0.5 + float(slot_index) * pitch


## 槽位编号 → 行号（0=上行，1=中行，2=下行；行主序，按该侧列数整除）
##   默认：我方 row0=[0,1,2] row1=[3,4,5] row2=[6,7,8]；敌方同构
static func get_row_for_slot(slot_index: int, is_enemy: bool = false) -> int:
	return slot_index / (_active_enemy_cols if is_enemy else _active_player_cols)


## 行偏移表（按激活行数；2 行沿用 3 行上下边线）
static func row_y_offsets() -> Array:
	return ROW_Y_OFFSETS_2ROWS if _active_rows == 2 else ROW_Y_OFFSETS


## 根据行号返回 Y 偏移（上行为负、下行为正；非等距）
static func row_y_offset(row: int) -> float:
	var offsets: Array = row_y_offsets()
	if row < 0 or row >= offsets.size():
		return 0.0
	return float(offsets[row])


## 根据槽位编号返回 Y 偏移（用于计算槽位中心 Y）
static func slot_y_offset_for_index(slot_index: int, is_enemy: bool = false) -> float:
	return row_y_offset(get_row_for_slot(slot_index, is_enemy))


## v9.5: 斜阵每行 X 错位量——我方 ///（上行靠中线）、敌方 \\\ 镜像。
## 我方在左带（+X = 朝中线）：row0 = +S（上行朝中线）、row1 = 0、row2 = -S（下行朝外缘）。
## 敌方在右带镜像（dir 取反）。S = 列宽 × ROW_X_STAGGER_RATIO ≈ 34px（可调）。
const ROW_X_STAGGER_RATIO: float = 0.20
static func slot_row_x_stagger(row: int, is_enemy: bool) -> float:
	var s: float = column_width_px() * ROW_X_STAGGER_RATIO
	var dir: float = -1.0 if is_enemy else 1.0
	if row == 0:
		return s * dir
	elif row == 2:
		return -s * dir
	return 0.0


## v9.2: 判定单位是否位于上行（分行索敌/溅射同行收敛用）。
## 单行返回 false（默认按下行兜底）。
static func is_unit_in_upper_row(unit: Node) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false
	var slot: int = -1
	var is_enemy: bool = false
	if unit.has_meta("card_grid_slot"):
		slot = int(unit.get_meta("card_grid_slot", -1))
	elif unit.has_meta("card_grid_enemy_slot"):
		slot = int(unit.get_meta("card_grid_enemy_slot", -1))
		is_enemy = true
	if slot < 0:
		return false
	return get_row_for_slot(slot, is_enemy) == 0


## v9.2: 判定两个单位是否位于同一行（分行索敌核心判定）。
## 有行号（按各自侧列数）则比较行号；无 slot meta 视为同行（不参与行过滤）。
## 敌我列数不同的关卡：行号语义仍对齐（row0/1/2 上下边线一致），跨行判定不受影响。
static func units_in_same_row(a: Node, b: Node) -> bool:
	if a == null or b == null or not is_instance_valid(a) or not is_instance_valid(b):
		return true
	## 双方都有 slot meta 时才按行过滤
	var slot_a: int = -1
	var enemy_a: bool = false
	if a.has_meta("card_grid_slot"):
		slot_a = int(a.get_meta("card_grid_slot", -1))
	elif a.has_meta("card_grid_enemy_slot"):
		slot_a = int(a.get_meta("card_grid_enemy_slot", -1))
		enemy_a = true
	var slot_b: int = -1
	var enemy_b: bool = false
	if b.has_meta("card_grid_slot"):
		slot_b = int(b.get_meta("card_grid_slot", -1))
	elif b.has_meta("card_grid_enemy_slot"):
		slot_b = int(b.get_meta("card_grid_enemy_slot", -1))
		enemy_b = true
	if slot_a >= 0 and slot_b >= 0:
		var row_a: int = get_row_for_slot(slot_a, enemy_a)
		var row_b: int = get_row_for_slot(slot_b, enemy_b)
		if row_a >= 0 and row_b >= 0:
			return row_a == row_b
	return true  # 防御性兜底


const GC = preload("res://resources/game_constants.gd")
const GameConfig = preload("res://resources/game_config.gd")

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
	return GameConfig.get_default().cross_row_direct_damage_mult


## 两侧阵型 + 中间空带的总宽度
static func total_grid_width_px() -> float:
	return side_band_width_px(false) + side_band_width_px(true) + MIDDLE_GAP_PX

## 我方带左缘：整体居中（左右等量边距），两侧阵型同步内收、中间收紧
## R-C1：基准带走 band_x0/band_x1（超宽画布整体平移居中）
static func player_band_start_x() -> float:
	return band_x0() + ((band_x1() - band_x0()) - total_grid_width_px()) * 0.5

## 敌方带左缘：我方带右缘 + 中间空带
static func enemy_band_start_x() -> float:
	return player_band_start_x() + side_band_width_px(false) + MIDDLE_GAP_PX
