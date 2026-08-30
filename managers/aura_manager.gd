extends Node
## 光环管理器
## 集中管理所有光环效果，使用 Timer 驱动而非每帧检查
## v21 P0: 战术光环范围化——医疗/侦查/雷达/堡垒按带内槽距过滤（详见 data/aura_data.gd）；
## 指挥/载具维修恒全场；一次性光环施加延迟到帧末（等部署槽位 meta 就绪）。
var DEBUG_AURA_LOG := false

const AuraDataScript = preload("res://data/aura_data.gd")
const AuraRangeIndicator = preload("res://scenes/effects/aura_range_indicator.gd")

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
	# 一次性类型应用，不放入周期逻辑
	# v21 P0: 改为帧末应用——部署槽位 meta 由 spawn 系统在 setup 之后写入
	# （时序详见 ModAuraHandler.broadcast_and_receive_deferred），立即应用时源槽位未知
	# 会全场兜底绕过范围化。周期类型（MEDIC/CARRIER）由 _on_global_tick 驱动，
	# 天然在槽位就绪后结算，无需延迟。
	_apply_one_shot_aura_deferred(unit, aura_type)
	if DEBUG_AURA_LOG:
		pass
		# [LOG-v5.1] print("[AuraManager] 注册光环: 单位=%d, 类型=%d" % [unit_id, aura_type])

## v21 P0: 一次性光环帧末应用（守卫：单位有效/入树/未注销/未排队删除）
func _apply_one_shot_aura_deferred(unit: Node2D, aura_type: AuraType) -> void:
	_spawn_range_indicator_if_tactical(unit, aura_type)
	var ml: Variant = Engine.get_main_loop()
	if ml == null or not (ml is SceneTree):
		_apply_one_shot_aura(unit, aura_type)
		return
	var cb := func() -> void:
		if not is_instance_valid(unit) or not unit.is_inside_tree() or unit.is_queued_for_deletion():
			return
		# 战斗清理（clear_all）或死亡注销后不补施加
		var aura_map: Dictionary = _unit_auras.get(unit.get_instance_id(), {})
		if not aura_map.has(aura_type):
			return
		_apply_one_shot_aura(unit, aura_type)
	(ml as SceneTree).process_frame.connect(cb, CONNECT_ONE_SHOT)

## v21 P0: 一次性光环分派（自 register_aura 抽出）
func _apply_one_shot_aura(unit: Node2D, aura_type: AuraType) -> void:
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

## v21 P0: 战术光环部署瞬间范围指示（全场类别/开关关闭时不生成；内部再延迟到入树）
func _spawn_range_indicator_if_tactical(unit: Node2D, aura_type: AuraType) -> void:
	if not AuraDataScript.is_aura_ranging_enabled():
		return
	var range_cells: int = AuraDataScript.aura_range_for(aura_type, get_unit_star(unit))
	if range_cells < 0:
		return
	AuraRangeIndicator.spawn_for_unit(unit, range_cells)

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
## v21 P0: range_cells >= 0 时按带内切比雪夫槽距过滤（战术光环）；
## 缺省 -1 = 全场（战略光环/撤销路径）。槽位未知/开关关闭时 is_in_aura_range 内部回退全场。
func get_slot_targets(unit: Node2D, is_global: bool, is_player: bool, range_cells: int = -1) -> Array:
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
	# v21 P0: 范围过滤
	if range_cells >= 0 and AuraDataScript.is_aura_ranging_enabled():
		var src_slot: int = AuraDataScript.unit_slot_index(unit)
		var filtered: Array = []
		for node in targets:
			if AuraDataScript.is_in_aura_range(src_slot, AuraDataScript.unit_slot_index(node), range_cells):
				filtered.append(node)
		return filtered
	return targets

## 获取单位强化星级（v20.12 等级统一：从 stats.card_level 战斗卡等级换算 1-10 星，
## 30 级制÷3 映射保住星级乘数表量纲；旧 enhance_level 链仅作过渡回退）
## 缓存到 meta 避免重复查询
static func get_unit_star(unit: Node2D) -> int:
	if unit == null:
		return 1
	if unit.has_meta("enhance_level"):
		return int(unit.get_meta("enhance_level"))
	# v20.12: 优先读 stats.card_level（我方部署时打栈），÷3 换算到 0-10 星制
	if "stats" in unit and unit.stats != null and "card_level" in unit.stats and int(unit.stats.card_level) > 0:
		var star_lv: int = clampi(int(round(float(int(unit.stats.card_level)) / 3.0)), 1, 10)
		unit.set_meta("enhance_level", star_lv)
		return star_lv
	# 过渡回退：旧 CardEnhancementManager 查询链（强化①退役后恒 0/1）
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
	var star: int = get_unit_star(unit)
	var ad: RefCounted = AuraDataScript
	var params: Dictionary = ad.get_aura_params(ad.Category.MEDIC_HEAL, star)
	var range_cells: int = ad.aura_range_for(ad.Category.MEDIC_HEAL, star)
	var allies: Array = get_slot_targets(unit, false, is_player, range_cells)
	for ally in allies:
		if not is_instance_valid(ally):
			continue
		if not "stats" in ally or ally.stats == null:
			continue
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
		if not _get_aura_data().is_mechanical_ally(ally):
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

## v7.x: 查询某单位当前激活的光环类型列表（供 UI 显示用）
## 返回 Array[int]，每项为 AuraType 枚举值；单位无光环返回空数组。用于情报面板查询某单位当前激活的光环类型列表（供 UI 显示）。
func get_unit_aura_types(unit: Node2D) -> Array[int]:
	var empty: Array[int] = []
	if unit == null or not is_instance_valid(unit):
		return empty
	var unit_id: int = unit.get_instance_id()
	if not _unit_auras.has(unit_id):
		return empty
	var aura_map: Dictionary = _unit_auras[unit_id]
	var result: Array[int] = []
	for aura_type in aura_map.keys():
		result.append(int(aura_type))
	return result

## v20.15: 后入场单位补偿接收场上既有光环源的一次性增益（雷达暴击/侦察命中/堡垒减伤/指挥全局）。
## 仿 ModAuraHandler.receive_mod_auras_from_field（H9 修复）——光环源注册时只覆盖当时在场友军，
## 后部署的单位原先永久吃不到 buff。replay=true 绕过源单位 meta 防重入，
## 由各 apply_* 内部的 per-ally meta 保证只给未受 buff 的单位补（即新入场者与漏补者）。
func receive_auras_from_field(unit: Node2D) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if not ("is_player" in unit):
		return
	var is_player: bool = bool(unit.is_player)
	for unit_id in _unit_map.keys():
		var src = _unit_map.get(unit_id, null)
		if src == null or not is_instance_valid(src):
			continue
		if not (src is Node2D) or src == unit:
			continue
		if not ("is_player" in src) or bool(src.is_player) != is_player:
			continue
		var aura_map: Dictionary = _unit_auras.get(unit_id, {})
		if aura_map.has(AuraType.RADAR_RANGE):
			CardAbilityManager.apply_radar_range_aura(src, 0.0, true)
		if aura_map.has(AuraType.SCOUT_CRIT):
			CardAbilityManager.apply_scout_crit_aura(src, 0.0, true)
		if aura_map.has(AuraType.FORTRESS_DEF):
			CardAbilityManager.apply_fortress_defense_aura(src, 0.0, true)
		if aura_map.has(AuraType.COMMAND_GLOBAL):
			CardAbilityManager.apply_command_global_aura(src, true)

## v21 P0: setup 期后入场补偿改帧末——本单位槽位 meta 由 spawn 系统在 setup 之后写入
## （时序详见 ModAuraHandler.broadcast_and_receive_deferred），立即接收会全场兜底绕过范围化。
## 各 apply_* 内部自带范围判定，补偿时机不影响范围正确性，只影响槽位读取。
func receive_auras_from_field_deferred(unit: Node2D) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if not ("is_player" in unit):
		return
	var ml: Variant = Engine.get_main_loop()
	if ml == null or not (ml is SceneTree):
		receive_auras_from_field(unit)
		return
	var cb := func() -> void:
		if not is_instance_valid(unit) or not unit.is_inside_tree() or unit.is_queued_for_deletion():
			return
		receive_auras_from_field(unit)
	(ml as SceneTree).process_frame.connect(cb, CONNECT_ONE_SHOT)

## 清理所有光环
## v9.x: 修复回归——3fdb0a6 提交在新增 get_unit_aura_types 时误删了本函数头，
## 导致 L302-314 成为 get_unit_aura_types return 之后的死代码。补回后由
## battle_manager.end_battle 调用，清空 autoload 单例跨战斗残留的 _unit_auras 缓存。
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
