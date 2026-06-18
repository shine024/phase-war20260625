extends Node2D
class_name BattleSlotGrid
## 格子战术：左右各 7 部署槽，中间 1 列为空置带（位置 8 正中空位，不布阵）。
## 全局共 15 列：位置 1(我方 slot 0，最左靠屏幕边)与位置 15(敌方 slot N-1，最右靠屏幕边)禁放。
## 实际可用：我方 slot 1~6（6 个），敌方 slot 0~5（6 个）。

const _Layout = preload("res://scripts/card_grid_battle_layout.gd")

const SLOT_COUNT: int = _Layout.SLOTS_PER_SIDE
const MIDDLE_EMPTY_COLUMNS: int = _Layout.MIDDLE_EMPTY_COLUMNS
const TOTAL_GRID_COLUMNS: int = _Layout.TOTAL_COLUMNS
const BATTLE_X0: float = _Layout.BATTLE_X0
const BATTLE_X1: float = _Layout.BATTLE_X1

## 边缘禁放槽位索引（按侧分）：
## 我方 slot 0 = 全局位置 1（最左靠屏幕边），禁放。
## 敌方 slot N-1 = 全局位置 15（最右靠屏幕边），禁放。
const PLAYER_EXCLUDED_SLOTS: Array[int] = [0]
const ENEMY_EXCLUDED_SLOTS: Array[int] = [SLOT_COUNT - 1]

var player_slot_centers: Array[Vector2] = []
var enemy_slot_centers: Array[Vector2] = []
var _lane_y_center: float = 360.0
## 点击判定：与战场 `battlefield` 部署带同步后的宽松 Y 带
var _accept_y_min: float = 200.0
var _accept_y_max: float = 520.0
var _slot_step_x: float = 42.0

func _ready() -> void:
	_rebuild_centers()


## 刷敌前可再调一次，避免早于本节点 `_ready` 时槽位数组仍为空
func rebuild_slot_centers_now() -> void:
	_rebuild_centers()

## 与背景车道 / 出生点 Y 对齐（道路「红线」一带）
func sync_lane(center_y: float, deploy_y_min: float, deploy_y_max: float) -> void:
	_lane_y_center = clampf(center_y, deploy_y_min, deploy_y_max)
	_accept_y_min = deploy_y_min - 56.0
	_accept_y_max = deploy_y_max + 56.0
	_rebuild_centers()

func _rebuild_centers() -> void:
	player_slot_centers.clear()
	enemy_slot_centers.clear()
	_slot_step_x = _Layout.slot_pitch_px()
	var p0: float = _Layout.player_band_start_x()
	for i in range(SLOT_COUNT):
		player_slot_centers.append(Vector2(_Layout.slot_center_x_in_band(p0, i), _lane_y_center))
	var e0: float = _Layout.enemy_band_start_x()
	for j in range(SLOT_COUNT):
		enemy_slot_centers.append(Vector2(_Layout.slot_center_x_in_band(e0, j), _lane_y_center))

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
	if player_slot_centers.is_empty():
		rebuild_slot_centers_now()
	var local_pos: Vector2 = battle_pos
	var best_i: int = -1
	var best_dx: float = 1e12
	for i in range(player_slot_centers.size()):
		# 玩家侧禁放：slot 0（= 全局位置 1，最左靠屏幕边）
		if PLAYER_EXCLUDED_SLOTS.has(i):
			continue
		var dx: float = absf(local_pos.x - player_slot_centers[i].x)
		if dx < best_dx:
			best_dx = dx
			best_i = i
	if best_i < 0:
		return -1
	var y_ok: bool = local_pos.y >= _accept_y_min and local_pos.y <= _accept_y_max
	var x_ok: bool = best_dx <= _slot_step_x * 0.68
	if x_ok and y_ok:
		return best_i
	return -1

func is_player_slot_occupied(idx: int, player_root: Node2D) -> bool:
	if player_root == null:
		return false
	for u in player_root.get_children():
		if not is_instance_valid(u):
			continue
		if int(u.get_meta("card_grid_slot", -1)) == idx:
			return true
	return false

## 判断某侧的某槽位是否为靠屏幕外缘的禁放位
## side: "player" → slot 0（全局位置 1，最左）；"enemy" → slot N-1（全局位置 15，最右）
static func is_edge_excluded_slot(slot_idx: int, side: String = "player") -> bool:
	if slot_idx < 0 or slot_idx >= SLOT_COUNT:
		return true
	if side == "enemy":
		return slot_idx == SLOT_COUNT - 1
	return slot_idx == 0
