extends Node
## 光环管理器
## 集中管理所有光环效果，使用 Timer 驱动而非每帧检查
var DEBUG_AURA_LOG := false

## 光环类型定义
enum AuraType {
	MEDIC_HEAL,      # MEDIC 维修光环
	RADAR_RANGE,    # RADAR 雷达光环
	SCOUT_CRIT,     # SCOUT/STEALTH 侦查光环
	FORTRESS_DEF    # FORTRESS 堡垒光环
}

## 光环配置
var _aura_timers: Dictionary = {}  # 兼容旧结构（统计/调试）
var _aura_intervals: Dictionary = {
	AuraType.MEDIC_HEAL: 3.0,
	AuraType.RADAR_RANGE: 1.0,
	AuraType.SCOUT_CRIT: 1.0,
	AuraType.FORTRESS_DEF: 1.0
}
var _global_tick_timer: Timer = null
var _unit_map: Dictionary = {}          # unit_id -> Node2D
var _unit_auras: Dictionary = {}        # unit_id -> {aura_type: true}
var _medic_elapsed: float = 0.0
var _fallback_group_cache: Dictionary = {"player_units": [], "enemy_units": []}
var _fallback_group_cache_ttl_sec: float = 0.35
var _fallback_group_cache_elapsed: float = 0.0

func _ready() -> void:
	_sync_debug_log_flag()
	_global_tick_timer = Timer.new()
	_global_tick_timer.wait_time = 0.5
	_global_tick_timer.autostart = true
	_global_tick_timer.timeout.connect(_on_global_tick)
	add_child(_global_tick_timer)

func _sync_debug_log_flag() -> void:
	var debug_mgr: Node = get_node_or_null("/root/DebugLogManager")
	if debug_mgr != null and debug_mgr.has_method("is_channel_enabled"):
		DEBUG_AURA_LOG = bool(debug_mgr.is_channel_enabled("aura_manager", DEBUG_AURA_LOG))

## 注册单位光环
func register_aura(unit: Node2D, aura_type: AuraType) -> void:
	if not unit or not is_instance_valid(unit):
		return

	var unit_id: int = unit.get_instance_id()
	if not _unit_auras.has(unit_id):
		_unit_auras[unit_id] = {}
		_aura_timers[unit_id] = {}
	_unit_map[unit_id] = unit

	# 如果该类型光环已注册，跳过
	if _unit_auras[unit_id].has(aura_type):
		return
	_unit_auras[unit_id][aura_type] = true
	_aura_timers[unit_id][aura_type] = true
	# 一次性类型立即应用，不放入周期逻辑
	match aura_type:
		AuraType.RADAR_RANGE:
			_apply_radar_aura(unit)
		AuraType.SCOUT_CRIT:
			_apply_scout_aura(unit)
		AuraType.FORTRESS_DEF:
			_apply_fortress_aura(unit)
		_:
			pass
	if DEBUG_AURA_LOG:
		print("[AuraManager] 注册光环: 单位=%d, 类型=%d" % [unit_id, aura_type])

## 注销单位光环
func unregister_aura(unit: Node2D, aura_type: AuraType) -> void:
	if not unit:
		return

	var unit_id: int = unit.get_instance_id()
	if not _unit_auras.has(unit_id):
		return
	if not _unit_auras[unit_id].has(aura_type):
		return
	_unit_auras[unit_id].erase(aura_type)
	if _aura_timers.has(unit_id):
		_aura_timers[unit_id].erase(aura_type)
	if _unit_auras[unit_id].is_empty():
		_unit_auras.erase(unit_id)
		_unit_map.erase(unit_id)
		_aura_timers.erase(unit_id)
	if DEBUG_AURA_LOG:
		print("[AuraManager] 注销光环: 单位=%d, 类型=%d" % [unit_id, aura_type])

## 注销单位所有光环
func unregister_all_auras(unit: Node2D) -> void:
	if not unit:
		return

	var unit_id: int = unit.get_instance_id()
	_unit_auras.erase(unit_id)
	_unit_map.erase(unit_id)
	_aura_timers.erase(unit_id)
	if DEBUG_AURA_LOG:
		print("[AuraManager] 注销所有光环: 单位=%d" % unit_id)

## 全局 Tick 回调（单 Timer 批处理）
func _on_global_tick() -> void:
	_medic_elapsed += _global_tick_timer.wait_time
	_fallback_group_cache_elapsed += _global_tick_timer.wait_time
	# 清理失效引用
	var dead_ids: Array = []
	for unit_id in _unit_map.keys():
		var u: Node2D = _unit_map[unit_id]
		if not is_instance_valid(u):
			dead_ids.append(unit_id)
	for unit_id in dead_ids:
		_unit_map.erase(unit_id)
		_unit_auras.erase(unit_id)
		_aura_timers.erase(unit_id)
	# MEDIC 按原 3 秒节奏批处理
	if _medic_elapsed >= _aura_intervals[AuraType.MEDIC_HEAL]:
		_medic_elapsed = 0.0
		for unit_id in _unit_auras.keys():
			var aura_map: Dictionary = _unit_auras[unit_id]
			if not aura_map.has(AuraType.MEDIC_HEAL):
				continue
			var unit: Node2D = _unit_map.get(unit_id, null)
			if unit != null and is_instance_valid(unit):
				_apply_medic_aura(unit)

## 应用光环效果（内部方法）
func _apply_medic_aura(unit: Node2D) -> void:
	if not "stats" in unit or unit.stats == null:
		return
	var is_player: bool = unit.is_player if "is_player" in unit else true
	var allies = _get_nearby_allies(unit, 180.0, is_player)
	for ally in allies:
		if not is_instance_valid(ally) or ally == unit:
			continue
		if not "stats" in ally or ally.stats == null:
			continue
		# 治疗 8% 最大 HP
		var heal_amount = ally.stats.max_hp * 0.08
		if ally.has_method("heal"):
			ally.heal(heal_amount)

func _apply_radar_aura(unit: Node2D) -> void:
	# RADAR 光环在单位生成时应用一次即可，无需持续更新
	if unit.has_meta("radar_aura_applied"):
		return
	CardAbilityManager.apply_radar_range_aura(unit, 0.0)

func _apply_scout_aura(unit: Node2D) -> void:
	# SCOUT 光环在单位生成时应用一次即可，无需持续更新
	if unit.has_meta("scout_aura_applied"):
		return
	CardAbilityManager.apply_scout_crit_aura(unit, 0.0)

func _apply_fortress_aura(unit: Node2D) -> void:
	# FORTRESS 光环在单位生成时应用一次即可，无需持续更新
	if unit.has_meta("fortress_aura_applied"):
		return
	CardAbilityManager.apply_fortress_defense_aura(unit, 0.0)

## 辅助方法：获取附近友军
func _get_nearby_allies(origin: Node2D, radius: float, is_player_unit: bool) -> Array:
	var group_name: String = "player_units" if is_player_unit else "enemy_units"
	return _get_nearby_units(origin, radius, group_name)

func _get_nearby_units(origin: Node2D, radius: float, target_group: String) -> Array:
	var units: Array = []

	# 性能优化：优先使用空间分区
	var battle_mgr = get_node_or_null("/root/BattleManager")
	if battle_mgr and battle_mgr.spatial_grid:
		# 使用空间网格查询（O(1)）
		var nearby = battle_mgr.spatial_grid.query_nearby(origin.global_position, radius)
		for unit in nearby:
			if unit.is_in_group(target_group):
				units.append(unit)
		return units

	# 回退到传统方法（遍历所有单位）
	var tree = origin.get_tree()
	if tree == null:
		return units

	if _fallback_group_cache_elapsed >= _fallback_group_cache_ttl_sec:
		_fallback_group_cache["player_units"] = tree.get_nodes_in_group("player_units")
		_fallback_group_cache["enemy_units"] = tree.get_nodes_in_group("enemy_units")
		_fallback_group_cache_elapsed = 0.0
	var group_nodes: Array = _fallback_group_cache.get(target_group, [])
	if group_nodes.is_empty():
		group_nodes = tree.get_nodes_in_group(target_group)
		_fallback_group_cache[target_group] = group_nodes
	for node in group_nodes:
		if not is_instance_valid(node) or node == origin:
			continue
		if not node is Node2D:
			continue
		if origin.global_position.distance_to(node.global_position) <= radius:
			units.append(node)

	return units

## 清理所有光环
func clear_all() -> void:
	if _global_tick_timer != null and is_instance_valid(_global_tick_timer):
		_global_tick_timer.stop()
	_aura_timers.clear()
	_unit_map.clear()
	_unit_auras.clear()
	_fallback_group_cache["player_units"] = []
	_fallback_group_cache["enemy_units"] = []
	_fallback_group_cache_elapsed = 0.0
	if DEBUG_AURA_LOG:
		print("[AuraManager] 清理所有光环")

## 获取统计信息
func get_stats() -> Dictionary:
	var active_auras = 0
	for unit_id in _unit_auras:
		active_auras += _unit_auras[unit_id].size()

	return {
		"tracked_units": _unit_auras.size(),
		"active_auras": active_auras
	}
