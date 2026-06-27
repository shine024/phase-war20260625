extends Node
## 空间哈希网格系统
## 用于优化大量单位的目标查找和碰撞检测
## 将战场划分为网格，只检查附近网格中的单位

## 网格配置
var _cell_size: float = 100.0  # 网格单元大小（像素）
var _grid: Dictionary = {}  # 网格数据：{Vector2i: [units]}
var _unit_to_cell: Dictionary = {}  # 单元到网格的映射 {unit: Vector2i}

## 战场边界
var _battle_min_x: float = 0.0
var _battle_max_x: float = 1280.0
var _battle_min_y: float = 0.0
var _battle_max_y: float = 720.0

## 统计信息
var _query_count: int = 0
var _last_query_count: int = 0

## 初始化网格
func setup(cell_size: float = 100.0, min_x: float = 0.0, max_x: float = 1280.0, min_y: float = 0.0, max_y: float = 720.0) -> void:
	_cell_size = cell_size
	_battle_min_x = min_x
	_battle_max_x = max_x
	_battle_min_y = min_y
	_battle_max_y = max_y
	clear()

## 清空网格
func clear() -> void:
	_grid.clear()
	_unit_to_cell.clear()
	_query_count = 0

## 插入单位到网格
func insert(unit: Node2D) -> void:
	if not unit or not is_instance_valid(unit):
		return

	# 如果单位已经在网格中，先移除
	if _unit_to_cell.has(unit):
		remove(unit)

	# 计算单位所在的网格
	var cell_key: Vector2i = _get_cell_coords(unit.global_position)
	_unit_to_cell[unit] = cell_key

	# 添加到网格
	if not _grid.has(cell_key):
		_grid[cell_key] = []
	_grid[cell_key].append(unit)

## 从网格中移除单位
func remove(unit: Node2D) -> void:
	if not unit or not is_instance_valid(unit):
		return

	if not _unit_to_cell.has(unit):
		return

	var cell_key: Vector2i = _unit_to_cell[unit]
	_unit_to_cell.erase(unit)

	if _grid.has(cell_key):
		_grid[cell_key].erase(unit)
		if _grid[cell_key].is_empty():
			_grid.erase(cell_key)

## 更新单位位置（移动后调用）
func update(unit: Node2D) -> void:
	if not unit or not is_instance_valid(unit):
		return

	# 检查是否需要更新网格
	var old_cell_key: Variant = _unit_to_cell.get(unit)
	var new_cell_key: Vector2i = _get_cell_coords(unit.global_position)

	if old_cell_key != new_cell_key:
		# 重新插入到新网格
		remove(unit)
		insert(unit)

## 查询附近单位
func query_nearby(position: Vector2, radius: float) -> Array:
	_query_count += 1
	var nearby_units: Array = []

	# 计算查询范围覆盖的网格（整数格，无 string split）
	var min_c: Vector2i = _get_cell_coords(position - Vector2(radius, radius))
	var max_c: Vector2i = _get_cell_coords(position + Vector2(radius, radius))

	var r2: float = radius * radius
	for x in range(min_c.x, max_c.x + 1):
		for y in range(min_c.y, max_c.y + 1):
			var cell_key := Vector2i(x, y)
			if not _grid.has(cell_key):
				continue
			for unit in _grid[cell_key]:
				if unit and is_instance_valid(unit):
					if unit.global_position.distance_squared_to(position) <= r2:
						nearby_units.append(unit)

	return nearby_units

## 查询指定范围内的敌方单位（使用bounding-box优化）
func query_enemies(position: Vector2, radius: float, is_player: bool) -> Array:
	_query_count += 1
	var enemies: Array = []
	var r2: float = radius * radius

	# 只遍历 radius 范围内的网格格子
	var min_c: Vector2i = _get_cell_coords(position - Vector2(radius, radius))
	var max_c: Vector2i = _get_cell_coords(position + Vector2(radius, radius))

	for x in range(min_c.x, max_c.x + 1):
		for y in range(min_c.y, max_c.y + 1):
			var cell_key := Vector2i(x, y)
			if not _grid.has(cell_key):
				continue
			for unit in _grid[cell_key]:
				if unit == null or not is_instance_valid(unit):
					continue
				if not (unit is Node2D):
					continue
				if unit.global_position.distance_squared_to(position) > r2:
					continue
				if "is_player" in unit:
					if unit.is_player != is_player:
						enemies.append(unit)

	return enemies

## 查询最近的目标（使用bounding-box优化，避免遍历所有格子）
func query_nearest_target(position: Vector2, is_player: bool, max_range: float = 1000.0) -> Node2D:
	_query_count += 1
	var nearest: Node2D = null
	var nearest_dist_sq: float = max_range * max_range

	# 只遍历 max_range 范围内的网格格子
	var min_c: Vector2i = _get_cell_coords(position - Vector2(max_range, max_range))
	var max_c: Vector2i = _get_cell_coords(position + Vector2(max_range, max_range))

	for x in range(min_c.x, max_c.x + 1):
		for y in range(min_c.y, max_c.y + 1):
			var cell_key := Vector2i(x, y)
			if not _grid.has(cell_key):
				continue
			for unit in _grid[cell_key]:
				if unit == null or not is_instance_valid(unit):
					continue
				if not (unit is Node2D):
					continue
				if "is_player" in unit:
					if unit.is_player == is_player:
						continue
				else:
					continue
				var d2: float = unit.global_position.distance_squared_to(position)
				if d2 < nearest_dist_sq:
					nearest_dist_sq = d2
					nearest = unit

	return nearest

## ========== 三攻三防系统：双向索敌 ==========

## 查询目标（支持从近到远或从远到近）
## @param targeting_mode: 0=NEAREST_FIRST（从近到远）, 1=FARTHEST_FIRST（从远到近）
## v7.3 性能优化：改线性扫描（O(覆盖格数×格内单位数)），不分配 Dictionary、不排序。
## 原实现为每个候选构造 {"unit":...,"distance_sq":...} 再 sort_custom（O(m log m) + 大量临时字典），
## 但实际只取 [0]（最近或最远一个）。NEAREST_FIRST 记录最小 d2，FARTHEST_FIRST 记录最大 d2。
func query_nearest_target_with_mode(
	position: Vector2,
	is_player: bool,
	max_range: float = 1000.0,
	targeting_mode: int = 0
) -> Node2D:
	_query_count += 1

	const GC = preload("res://resources/game_constants.gd")
	var want_farthest: bool = (targeting_mode == GC.TargetingMode.FARTHEST_FIRST)
	var best: Node2D = null
	var best_d2: float = max_range * max_range  # NEAREST_FIRST 的上界
	if want_farthest:
		best_d2 = -1.0  # FARTHEST_FIRST 的下界

	var min_c: Vector2i = _get_cell_coords(position - Vector2(max_range, max_range))
	var max_c: Vector2i = _get_cell_coords(position + Vector2(max_range, max_range))

	for x in range(min_c.x, max_c.x + 1):
		for y in range(min_c.y, max_c.y + 1):
			var cell_key := Vector2i(x, y)
			if not _grid.has(cell_key):
				continue
			for unit in _grid[cell_key]:
				if unit == null or not is_instance_valid(unit):
					continue
				if not (unit is Node2D):
					continue
				if "is_player" in unit and unit.is_player == is_player:
					continue
				var d2: float = unit.global_position.distance_squared_to(position)
				if d2 > max_range * max_range:
					continue
				if want_farthest:
					if d2 > best_d2:
						best_d2 = d2
						best = unit
				else:
					if d2 < best_d2:
						best_d2 = d2
						best = unit

	return best

## 获取网格统计信息
func get_stats() -> Dictionary:
	return {
		"cell_size": _cell_size,
		"total_cells": _grid.size(),
		"total_units": _unit_to_cell.size(),
		"query_count": _query_count,
		"queries_since_last": _query_count - _last_query_count
	}

## 重置查询计数
func reset_query_count() -> void:
	_last_query_count = _query_count

## 计算网格坐标（整数格）
func _get_cell_coords(position: Vector2) -> Vector2i:
	var x := int(floor(position.x / _cell_size))
	var y := int(floor(position.y / _cell_size))
	return Vector2i(x, y)

## 调试：绘制网格（用于可视化）
func draw_debug(canvas: CanvasItem) -> void:
	if not canvas:
		return

	# 计算网格范围
	var min_cell_x = int(floor(_battle_min_x / _cell_size))
	var max_cell_x = int(floor(_battle_max_x / _cell_size))
	var min_cell_y = int(floor(_battle_min_y / _cell_size))
	var max_cell_y = int(floor(_battle_max_y / _cell_size))

	# 绘制网格线
	for x in range(min_cell_x, max_cell_x + 1):
		var world_x = x * _cell_size
		canvas.draw_line(Vector2(world_x, _battle_min_y), Vector2(world_x, _battle_max_y), Color(0.3, 0.3, 0.3, 0.3))

	for y in range(min_cell_y, max_cell_y + 1):
		var world_y = y * _cell_size
		canvas.draw_line(Vector2(_battle_min_x, world_y), Vector2(_battle_max_x, world_y), Color(0.3, 0.3, 0.3, 0.3))

	# 绘制单元格内容
	for cell_key in _grid.keys():
		var cell_x: int = cell_key.x
		var cell_y: int = cell_key.y
		var cell_pos = Vector2(cell_x * _cell_size, cell_y * _cell_size)

		# 绘制单元格矩形
		var rect = Rect2(cell_pos, Vector2(_cell_size, _cell_size))
		canvas.draw_rect(rect, Color(0.2, 0.5, 0.8, 0.1))

		# 显示单位数量
		var count = _grid[cell_key].size()
		if count > 0:
			canvas.draw_string(ThemeDB.fallback_font, cell_pos + Vector2(5, 15), str(count), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.YELLOW)
