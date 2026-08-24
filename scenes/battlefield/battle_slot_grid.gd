extends Node2D
class_name BattleSlotGrid
## 格子战术：3 行 × 3 列，每侧 9 部署槽，中间 1 列为空置带。
## 全局共 7 列（3+1+3），每侧 9 格（row0/1/2 × col0/1/2），无边缘禁放。
## v9.5: 斜阵——每行 X 错位，我方呈 ///（上行靠中线）、敌方呈 \\\ 镜像。

const _Layout = preload("res://scripts/card_grid_battle_layout.gd")

const SLOT_COUNT: int = _Layout.TOTAL_SLOTS_PER_SIDE  # = 9
const MIDDLE_EMPTY_COLUMNS: int = _Layout.MIDDLE_EMPTY_COLUMNS
const TOTAL_GRID_COLUMNS: int = _Layout.TOTAL_COLUMNS
const BATTLE_X0: float = _Layout.BATTLE_X0
const BATTLE_X1: float = _Layout.BATTLE_X1

## 无边缘禁放槽位（3×3 全可用）
const PLAYER_EXCLUDED_SLOTS: Array[int] = []
const ENEMY_EXCLUDED_SLOTS: Array[int] = []

var player_slot_centers: Array[Vector2] = []
var enemy_slot_centers: Array[Vector2] = []
var _lane_y_center: float = 360.0
## 点击判定：覆盖 3 行全范围
var _accept_y_min: float = 200.0
var _accept_y_max: float = 520.0
var _slot_step_x: float = 42.0
## BU-5（战斗界面美化）：部署区可视化高亮层（见文件尾 SlotHighlight 内部类）
var _highlight: Node = null

func _ready() -> void:
	_rebuild_centers()
	_ensure_highlight_layer()

func _ensure_highlight_layer() -> void:
	if _highlight != null and is_instance_valid(_highlight):
		return
	_highlight = SlotHighlight.new()
	_highlight.name = "SlotHighlightLayer"
	add_child(_highlight)


## 刷敌前可再调一次，避免早于本节点 `_ready` 时槽位数组仍为空
func rebuild_slot_centers_now() -> void:
	_rebuild_centers()

## 与背景车道 / 出生点 Y 对齐（道路「红线」一带）
func sync_lane(center_y: float, deploy_y_min: float, deploy_y_max: float) -> void:
	_lane_y_center = clampf(center_y, deploy_y_min, deploy_y_max)
	# 点击接受带：按 ROW_Y_OFFSETS 实际最小/最大行偏移覆盖全部行 + 56px 点击容差
	# （行偏移加大后须动态计算，否则上行会落到接受带外导致不可点击）
	var min_off: float = _Layout.ROW_Y_OFFSETS.min()
	var max_off: float = _Layout.ROW_Y_OFFSETS.max()
	_accept_y_min = _lane_y_center + min_off - 56.0
	_accept_y_max = _lane_y_center + max_off + 56.0
	_rebuild_centers()

func _rebuild_centers() -> void:
	player_slot_centers.clear()
	enemy_slot_centers.clear()
	_slot_step_x = _Layout.slot_pitch_px()
	var p0: float = _Layout.player_band_start_x()
	for i in range(SLOT_COUNT):
		# v9.5: 斜阵——我方 /// 每行 X 错位（上行靠中线）
		var prow: int = i / _Layout.SLOTS_PER_SIDE
		var sx: float = _Layout.slot_center_x_in_band(p0, i % _Layout.SLOTS_PER_SIDE) + _Layout.slot_row_x_stagger(prow, false)
		var sy: float = _lane_y_center + _Layout.slot_y_offset_for_index(i)
		player_slot_centers.append(Vector2(sx, sy))
	var e0: float = _Layout.enemy_band_start_x()
	for j in range(SLOT_COUNT):
		# v9.5: 斜阵——敌方 \\\ 镜像（上行靠中线）
		var erow: int = j / _Layout.SLOTS_PER_SIDE
		var ex: float = _Layout.slot_center_x_in_band(e0, j % _Layout.SLOTS_PER_SIDE) + _Layout.slot_row_x_stagger(erow, true)
		var ey: float = _lane_y_center + _Layout.slot_y_offset_for_index(j)
		enemy_slot_centers.append(Vector2(ex, ey))

func get_player_slot_center(idx: int) -> Vector2:
	if idx < 0 or idx >= player_slot_centers.size():
		return Vector2.ZERO
	return player_slot_centers[idx]

func get_enemy_slot_center(idx: int) -> Vector2:
	if idx < 0 or idx >= enemy_slot_centers.size():
		return Vector2.ZERO
	return enemy_slot_centers[idx]

func find_nearest_player_slot(battle_pos: Vector2) -> int:
	# battle_pos：BattleSlotGrid 局部坐标（由 battlefield / spawn 系统换算）
	# 3×3 网格：同列 3 个槽 X 相同、分属 3 行，必须用 2D 距离(X²+Y²)选最近槽；
	# 否则同列只会命中索引最小的那行（严格 < 不替换）→ 永远只能部署一行。
	if player_slot_centers.is_empty():
		rebuild_slot_centers_now()
	var local_pos: Vector2 = battle_pos
	var best_i: int = -1
	var best_d2: float = 1e12
	for i in range(player_slot_centers.size()):
		var c: Vector2 = player_slot_centers[i]
		var ddx: float = local_pos.x - c.x
		var ddy: float = local_pos.y - c.y
		var d2: float = ddx * ddx + ddy * ddy
		if d2 < best_d2:
			best_d2 = d2
			best_i = i
	if best_i < 0:
		return -1
	var best: Vector2 = player_slot_centers[best_i]
	var y_ok: bool = local_pos.y >= _accept_y_min and local_pos.y <= _accept_y_max
	var x_ok: bool = absf(local_pos.x - best.x) <= _slot_step_x * 0.68
	if x_ok and y_ok:
		return best_i
	return -1

func is_player_slot_occupied(idx: int, player_root: Node2D) -> bool:
	if player_root == null:
		return false
	for u in player_root.get_children():
		if not is_instance_valid(u):
			continue
		# 死亡淡出期间（_is_dying=true，queue_free 尚未执行）不计入占用
		if "_is_dying" in u and bool(u.get("_is_dying")):
			continue
		if int(u.get_meta("card_grid_slot", -1)) == idx:
			return true
	return false

## 3×3 布局无禁放位，此函数恒返回 false（保留接口兼容）。
static func is_edge_excluded_slot(_slot_idx: int, _side: String = "player") -> bool:
	return false


## BU-5（战斗界面美化，2026-08-24）：部署区可视化高亮层。
## pending 部署时亮起我方 3×3 格：空格绿框 10% 绿底 / 占用格红框 8% 红底 / 悬停格金框 15% 底，
## 0.15s 淡入淡出（modulate.a）。悬停检测复用 find_nearest_player_slot（与真实部署判定同一条链，
## 亮哪格=点哪格）。红绿语义与背包拖拽批次二标准一致，零学习成本。尊重 DT.is_motion_reduce()。
## z=-2：在地面着色(-9)/光环(-5)之上、单位(0)之下。
class SlotHighlight extends Node2D:
	const DT = preload("res://resources/design_tokens.gd")
	const Layout = preload("res://scripts/card_grid_battle_layout.gd")

	const FADE_SEC: float = 0.15
	const OCC_REFRESH_SEC: float = 0.25
	const RECT_H: float = 58.0

	var _grid: Node = null
	var _alpha: float = 0.0
	var _hover_slot: int = -1
	var _occupied_cache: Array = []
	var _occ_refresh_acc: float = 1.0
	var _player_units: Node = null
	var _free_sb: StyleBoxFlat = null
	var _occ_sb: StyleBoxFlat = null
	var _hov_sb: StyleBoxFlat = null

	func _ready() -> void:
		z_index = -2
		_grid = get_parent()
		_free_sb = _make_sb(Color(0.32, 0.85, 0.45, 0.8), Color(0.1, 0.5, 0.3, 0.10))
		_occ_sb = _make_sb(Color(0.9, 0.3, 0.3, 0.6), Color(0.5, 0.1, 0.1, 0.08))
		_hov_sb = _make_sb(
			Color(DT.COLOR_GOLD.r, DT.COLOR_GOLD.g, DT.COLOR_GOLD.b, 0.95),
			Color(DT.COLOR_GOLD.r, DT.COLOR_GOLD.g, DT.COLOR_GOLD.b, 0.15))

	func _process(delta: float) -> void:
		# 本文件会被纯数据链 preload（master_platform_power 等）——禁用 autoload 全局名
		# （--script 测试模式无 autoload，编译期 Identifier not found），改运行时按路径解析
		var bis: Node = get_node_or_null("/root/BattleInputState")
		var pending: bool = bis != null \
			and not String(bis.get("pending_deploy_platform_card_id")).is_empty()
		var target: float = 1.0 if pending else 0.0
		if DT.is_motion_reduce():
			_alpha = target
		else:
			_alpha = move_toward(_alpha, target, delta / FADE_SEC)
		visible = _alpha > 0.01
		modulate.a = _alpha
		if not visible:
			return
		_refresh_occupancy(delta)
		if pending:
			_update_hover()
		else:
			_hover_slot = -1
		queue_redraw()

	## 占用态 0.25s 节流刷新（部署/死亡瞬间有延迟可接受，省每帧遍历）
	func _refresh_occupancy(delta: float) -> void:
		_occ_refresh_acc += delta
		if _occ_refresh_acc < OCC_REFRESH_SEC:
			return
		_occ_refresh_acc = 0.0
		if _player_units == null or not is_instance_valid(_player_units):
			var bf: Node = _grid.get_parent() if _grid != null else null
			_player_units = bf.get_node_or_null("PlayerUnits") if bf != null else null
			if _player_units == null:
				return
		_occupied_cache.clear()
		for i in range(_grid.SLOT_COUNT):
			_occupied_cache.append(_grid.is_player_slot_occupied(i, _player_units))

	func _update_hover() -> void:
		if _grid == null:
			return
		_hover_slot = _grid.find_nearest_player_slot(to_local(get_global_mouse_position()))

	func _draw() -> void:
		if _grid == null or _occupied_cache.size() == 0:
			return
		var centers: Array = _grid.player_slot_centers
		var n: int = mini(centers.size(), _occupied_cache.size())
		var w: float = Layout.battle_card_width_px() * 1.05
		for i in range(n):
			var c: Vector2 = centers[i]
			var rect := Rect2(c.x - w * 0.5, c.y - RECT_H * 0.5, w, RECT_H)
			if i == _hover_slot and not _occupied_cache[i]:
				draw_style_box(_hov_sb, rect)
			elif _occupied_cache[i]:
				draw_style_box(_occ_sb, rect)
			else:
				draw_style_box(_free_sb, rect)

	func _make_sb(border: Color, fill: Color) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = fill
		sb.border_color = border
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(6)
		return sb
