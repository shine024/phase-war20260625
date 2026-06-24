extends Node
## 光环管理器
## 集中管理所有光环效果，使用 Timer 驱动而非每帧检查
var DEBUG_AURA_LOG := false

## 光环类型定义（与 aura_data.Category 保持一一对应）
enum AuraType {
	MEDIC_HEAL,      # 0  MEDIC 维修光环
	CARRIER_REPAIR,  # 1  CARRIER 机械维修光环
	SCOUT_CRIT,      # 2  SCOUT/STEALTH 侦查光环
	RADAR_RANGE,     # 3  RADAR 雷达光环
	FORTRESS_DEF,    # 4  FORTRESS 堡垒光环
	COMMAND_GLOBAL   # 5  COMMAND 指挥光环
}

## 光环配置
var _aura_timers: Dictionary = {}  # 兼容旧结构（统计/调试）
var _aura_intervals: Dictionary = {
	AuraType.MEDIC_HEAL: 3.0,
	AuraType.CARRIER_REPAIR: 3.0,
	AuraType.RADAR_RANGE: 1.0,
	AuraType.SCOUT_CRIT: 1.0,
	AuraType.FORTRESS_DEF: 1.0,
	AuraType.COMMAND_GLOBAL: 1.0,
}
var _global_tick_timer: Timer = null
var _unit_map: Dictionary = {}          # unit_id -> Node2D
var _unit_auras: Dictionary = {}        # unit_id -> {aura_type: true}
var _aura_data_script: Script = null

func _get_aura_data() -> RefCounted:
	if _aura_data_script == null:
		_aura_data_script = load("res://data/aura_data.gd") as Script
	return _aura_data_script.new()

var _medic_elapsed: float = 0.0
var _carrier_elapsed: float = 0.0
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
		AuraType.CARRIER_REPAIR:
			_apply_carrier_repair_aura(unit)
		AuraType.COMMAND_GLOBAL:
			_apply_command_global_aura(unit)
		_:
			pass
	if DEBUG_AURA_LOG:
		pass
		# [LOG-v5.1] print("[AuraManager] 注册光环: 单位=%d, 类型=%d" % [unit_id, aura_type])

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
		pass
		# [LOG-v5.1] print("[AuraManager] 注销光环: 单位=%d, 类型=%d" % [unit_id, aura_type])

## 注销单位所有光环
func unregister_all_auras(unit: Node2D) -> void:
	if not unit:
		return

	var unit_id: int = unit.get_instance_id()
	_unit_auras.erase(unit_id)
	_unit_map.erase(unit_id)
	_aura_timers.erase(unit_id)
	if DEBUG_AURA_LOG:
		pass
		# [LOG-v5.1] print("[AuraManager] 注销所有光环: 单位=%d" % unit_id)

## 全局 Tick 回调（单 Timer 批处理）
func _on_global_tick() -> void:
	_medic_elapsed += _global_tick_timer.wait_time
	_carrier_elapsed += _global_tick_timer.wait_time
	_fallback_group_cache_elapsed += _global_tick_timer.wait_time
	# 清理失效引用
	var dead_ids: Array = []
	for unit_id in _unit_map.keys():
		# 用无类型变量接收：freed 实例赋给静态类型(Node2D)会触发
		# "Trying to assign invalid previously freed instance"，需在 is_instance_valid 之前避免类型检查
		var u = _unit_map[unit_id]
		if u == null or not is_instance_valid(u):
			dead_ids.append(unit_id)
	for unit_id in dead_ids:
		_unit_map.erase(unit_id)
		_unit_auras.erase(unit_id)
		_aura_timers.erase(unit_id)
	# MEDIC 按 3 秒节奏批处理
	if _medic_elapsed >= _aura_intervals[AuraType.MEDIC_HEAL]:
		_medic_elapsed = 0.0
		for unit_id in _unit_auras.keys():
			var aura_map: Dictionary = _unit_auras[unit_id]
			if not aura_map.has(AuraType.MEDIC_HEAL):
				continue
			var unit = _unit_map.get(unit_id, null)
			if unit != null and is_instance_valid(unit):
				_apply_medic_aura(unit)
	# CARRIER 按 3 秒节奏批处理
	if _carrier_elapsed >= _aura_intervals[AuraType.CARRIER_REPAIR]:
		_carrier_elapsed = 0.0
		for unit_id in _unit_auras.keys():
			var aura_map: Dictionary = _unit_auras[unit_id]
			if not aura_map.has(AuraType.CARRIER_REPAIR):
				continue
			var unit = _unit_map.get(unit_id, null)
			if unit != null and is_instance_valid(unit):
				_apply_carrier_repair_tick(unit)

## ── 槽位判定辅助 ──

## 通过槽位索引找受影响的友军（替代像素距离判定）
func get_slot_targets(unit: Node2D, is_global: bool, is_player: bool) -> Array:
	# v6.2: 所有光环均影响全体同阵营单位，不再受槽位/距离限制
	var targets: Array = []
	if unit == null or not is_instance_valid(unit):
		return targets
	var tree: SceneTree = unit.get_tree()
	if tree == null:
		return targets
	var group_name: String = "player_units" if is_player else "enemy_units"
	# v6.2 性能优化：优先使用 BattleManager 缓存的节点列表，避免每次 get_nodes_in_group 分配新数组
	var group_nodes: Array = []
	var bm: Node = tree.root.get_node_or_null("BattleManager")
	if bm != null and is_instance_valid(bm) and bm.has_method("get_cached_nodes_in_group"):
		var active: bool = bool(bm.get("battle_active")) if "battle_active" in bm else false
		if active:
			group_nodes = bm.get_cached_nodes_in_group(group_name)
	if group_nodes.is_empty():
		group_nodes = tree.get_nodes_in_group(group_name)
	for node in group_nodes:
		if not is_instance_valid(node) or node == unit:
			continue
		if not node is Node2D:
			continue
		targets.append(node)
	return targets

## 获取单位强化等级（v6.11: 从废弃的 get_blueprint_star 迁移到真实 enhance_level）
## 缓存到 meta 避免重复查询
static func get_unit_star(unit: Node2D) -> int:
	if unit == null:
		return 1
	if unit.has_meta("enhance_level"):
		return int(unit.get_meta("enhance_level"))
	# 首次访问时从 CardEnhancementManager 查询真实强化等级并缓存
	if "stats" in unit and unit.stats != null and not unit.stats.platform_card_id.is_empty():
		var cem: Node = null
		var loop = Engine.get_main_loop()
		if loop is SceneTree:
			cem = (loop as SceneTree).root.get_node_or_null("CardEnhancementManager")
		if cem and cem.has_method("get_card_enhancement_level"):
			var lvl: int = int(cem.get_card_enhancement_level(unit.stats.platform_card_id))
			unit.set_meta("enhance_level", lvl)
			return lvl
	unit.set_meta("enhance_level", 1)
	return 1

## 应用光环效果（内部方法）
func _apply_medic_aura(unit: Node2D) -> void:
	if not "stats" in unit or unit.stats == null:
		return
	var is_player: bool = unit.is_player if "is_player" in unit else true
	var allies: Array = get_slot_targets(unit, false, is_player)
	for ally in allies:
		if not is_instance_valid(ally):
			continue
		if not "stats" in ally or ally.stats == null:
			continue
		var star: int = get_unit_star(unit)
		var params: Dictionary = _get_aura_data().get_aura_params(_get_aura_data().Category.MEDIC_HEAL, star)
		var heal_amount: float = ally.stats.max_hp * float(params.get("heal_pct", 0.08))
		if ally.has_method("heal"):
			ally.heal(heal_amount)

func _apply_carrier_repair_tick(unit: Node2D) -> void:
	if not "stats" in unit or unit.stats == null:
		return
	var is_player: bool = unit.is_player if "is_player" in unit else true
	var allies: Array = get_slot_targets(unit, false, is_player)
	for ally in allies:
		if not is_instance_valid(ally):
			continue
		if not "stats" in ally or ally.stats == null:
			continue
		if not _get_aura_data().is_mechanical_platform(ally.stats.platform_type):
			continue
		var star: int = get_unit_star(unit)
		var params: Dictionary = _get_aura_data().get_aura_params(_get_aura_data().Category.CARRIER_REPAIR, star)
		var heal_amount: float = ally.stats.max_hp * float(params.get("heal_pct", 0.12))
		if ally.has_method("heal"):
			ally.heal(heal_amount)

func _apply_carrier_repair_aura(unit: Node2D) -> void:
	# CARRIER_REPAIR 由 _on_global_tick 周期驱动，此处仅做一次性标记
	if unit.has_meta("carrier_repair_aura_applied"):
		return
	unit.set_meta("carrier_repair_aura_applied", true)

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

func _apply_command_global_aura(unit: Node2D) -> void:
	if unit.has_meta("command_aura_applied"):
		return
	CardAbilityManager.apply_command_global_aura(unit)

## 辅助方法：获取附近友军（保留旧签名，内部改为槽位判定）
func _get_nearby_allies(origin: Node2D, radius: float, is_player_unit: bool) -> Array:
	return get_slot_targets(origin, false, is_player_unit)

func _get_nearby_units(origin: Node2D, radius: float, target_group: String) -> Array:
	var units: Array = []
	var tree: SceneTree = origin.get_tree() if origin != null else null
	if tree == null:
		return units
	var is_player: bool = target_group == "player_units"
	return get_slot_targets(origin, false, is_player)

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
	_medic_elapsed = 0.0
	_carrier_elapsed = 0.0
	if DEBUG_AURA_LOG:
		pass
		# [LOG-v5.1] print("[AuraManager] 清理所有光环")

## 获取统计信息
func get_stats() -> Dictionary:
	var active_auras = 0
	for unit_id in _unit_auras:
		active_auras += _unit_auras[unit_id].size()

	return {
		"tracked_units": _unit_auras.size(),
		"active_auras": active_auras
	}
