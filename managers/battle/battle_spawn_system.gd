extends RefCounted
## 战斗刷新子系统：玩家部署、敌方波次刷新、预览单位管理、单位清理
##
## 设计文档: docs/architecture/project-architecture.md (Section 4)
## 从 BattleManager 中提取，负责所有单位创建与生命周期管理。

const GC = preload("res://resources/game_constants.gd")
const EnemyArchetypes = preload("res://data/enemy_archetypes.gd")
const UnitStatsTable = preload("res://resources/unit_stats_table.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const FactionCardGenerator = preload("res://managers/faction/faction_card_generator.gd")
const FactionCardBonuses = preload("res://data/faction_card_bonuses.gd")
const SwarmEnemyControllerScript = preload("res://scenes/units/swarm_enemy_controller.gd")
const _CardGridSlotsPerSide: int = BattleSlotGrid.SLOT_COUNT
const _DamageNumberDisplayScript = preload("res://scenes/effects/damage_number_display.gd")
const ConstructUnitScene = preload("res://scenes/units/construct_unit.tscn")
const DEPLOY_FAIL_LOG_THROTTLE_MS := 350

# ---- 外部依赖引用（由 BattleManager 注入） ----
var _energy_manager: Node = null
var _phase_instrument: Node = null
var _signal_bus: Node = null
var _battlefield: Node = null
var _player_units_node: Node = null
var _enemy_units_node: Node = null

# ---- 玩家部署追踪 ----
var player_unit_count: int = 0
var _max_player_units_deployed: int = 0
var _player_units_lost: int = 0
var _player_deploy_manual: bool = true

# ---- 敌方波次状态 ----
var enemy_unit_count: int = 0
var enemy_wave_index: int = 0
var enemy_wave_timer: float = 0.0
var _enemy_wave_interval: float = 12.0
var _enemy_wave_total: int = 0
var _last_deploy_fail_key: String = ""
var _last_deploy_fail_ts_ms: int = -999999
var _stats_cache: Dictionary = {}

## 卡牌格子战术
var _card_grid_active: bool = false
var _card_grid_enemy_quota: int = _CardGridSlotsPerSide

func setup(deps: Dictionary) -> void:
	_energy_manager = deps.get("energy_manager", null)
	_phase_instrument = deps.get("phase_instrument", null)
	_signal_bus = deps.get("signal_bus", null)

func configure_card_grid_battle(enemy_quota: int) -> void:
	_card_grid_active = true
	_card_grid_enemy_quota = clampi(enemy_quota, 1, _CardGridSlotsPerSide)


func _enemy_field_unit_cap() -> int:
	return _CardGridSlotsPerSide


func finalize_card_grid_and_spawn_enemies(current_level: int) -> void:
	if not _card_grid_active:
		return
	_materialize_player_deploy_ghosts()
	_apply_player_card_grid_post_placement()
	if _battlefield != null and _battlefield.has_method("snap_card_grid_units_to_slots"):
		_battlefield.snap_card_grid_units_to_slots()
	# 非相位师格子战：敌军按波次间隔整波刷入敌侧格子；相位师关不刷格子线敌军


func _materialize_player_deploy_ghosts() -> void:
	if _player_units_node == null:
		return
	for u in _player_units_node.get_children():
		if u != null and is_instance_valid(u) and u.has_method("force_materialize_if_deploy_ghost"):
			u.force_materialize_if_deploy_ghost()


func _apply_player_card_grid_post_placement() -> void:
	if _player_units_node == null:
		return
	for u in _player_units_node.get_children():
		if u != null and is_instance_valid(u) and u.has_method("apply_card_grid_combat_started"):
			u.apply_card_grid_combat_started()


func _card_grid_count_free_enemy_slots() -> int:
	var n: int = 0
	for si in range(_CardGridSlotsPerSide):
		if not _is_enemy_grid_slot_occupied(si):
			n += 1
	return n


func _enemy_node_claims_card_grid_slot(n: Node, slot_idx: int) -> bool:
	if n == null or not is_instance_valid(n):
		return false
	return int(n.get_meta("card_grid_enemy_slot", -1)) == slot_idx


## 在 EnemyUnits 子树内查找（含 SwarmEnemyController 下的蜂群槽），避免多波次重复占同一格叠在一起
func _is_enemy_grid_slot_occupied(slot_idx: int) -> bool:
	if _enemy_units_node == null:
		return false
	return _find_enemy_subtree_with_slot(_enemy_units_node, slot_idx) != null


func _find_enemy_subtree_with_slot(n: Node, slot_idx: int) -> Node:
	if n == null or not is_instance_valid(n):
		return null
	if _enemy_node_claims_card_grid_slot(n, slot_idx):
		return n
	for c in n.get_children():
		var hit: Node = _find_enemy_subtree_with_slot(c, slot_idx)
		if hit != null:
			return hit
	return null


## 敌方区域：槽索引 0 在靠中线一侧、递增向屏幕右缘 → 从左向右逐个占空位
func _card_grid_next_free_enemy_slot_index() -> int:
	for si in range(_CardGridSlotsPerSide):
		if not _is_enemy_grid_slot_occupied(si):
			return si
	return -1


## 与场上实际敌单位对齐，避免阵亡后缓存计数偏高导致后续波次刷不出、胜利条件不满足
func sync_enemy_unit_count_from_field() -> void:
	if BattleManager != null and BattleManager.battle_active and BattleManager.has_method("recount_enemy_units_on_field"):
		enemy_unit_count = BattleManager.recount_enemy_units_on_field()


func all_enemy_waves_spawned() -> bool:
	if _enemy_wave_total <= 0:
		return true
	return enemy_wave_index >= _enemy_wave_total


## 格子战术：时间到后本波 `to_spawn` 个单位同时落在空敌槽。敌槽全满时不推进波次、不消耗间隔。
func spawn_card_grid_enemy_wave(current_level: int) -> bool:
	if not _card_grid_active or _enemy_units_node == null:
		return false
	sync_enemy_unit_count_from_field()
	if enemy_unit_count >= _enemy_field_unit_cap():
		return false
	var free_n: int = _card_grid_count_free_enemy_slots()
	if free_n <= 0:
		return false
	var grid: Node = _battlefield.get_node_or_null("BattleSlotGrid") if _battlefield else null
	if grid != null and grid.has_method("rebuild_slot_centers_now"):
		grid.rebuild_slot_centers_now()

	var next_wave: int = enemy_wave_index + 1
	var gm: Node = _get_autoload_node("GameManager")
	var to_spawn: int = 1 + (next_wave % 2)
	if gm and gm.has_method("get_enemy_spawn_count_for_wave_card_grid"):
		to_spawn = gm.get_enemy_spawn_count_for_wave_card_grid(gm.current_level, next_wave)
	elif gm and gm.has_method("get_enemy_spawn_count_for_wave"):
		to_spawn = gm.get_enemy_spawn_count_for_wave(gm.current_level, next_wave)
	to_spawn = mini(to_spawn, _card_grid_enemy_quota)
	to_spawn = mini(to_spawn, free_n)
	if to_spawn <= 0:
		return false

	enemy_wave_index = next_wave
	if _signal_bus:
		_signal_bus.wave_spawned.emit(enemy_wave_index)

	var era: int = _current_battle_era(current_level)
	var era_archetypes: Array = EnemyArchetypes.get_ids_for_era(era)
	var basic_ids: Array = []
	var elite_ids: Array = []
	var boss_ids: Array = []
	for aid in era_archetypes:
		var cfg: Dictionary = EnemyArchetypes.get_config(aid)
		if cfg.is_empty():
			continue
		var tags: Array = cfg.get("tags", [])
		if tags.has("boss"):
			boss_ids.append(aid)
		elif tags.has("elite"):
			elite_ids.append(aid)
		else:
			basic_ids.append(aid)

	var is_last_wave: bool = (_enemy_wave_total > 0 and enemy_wave_index >= _enemy_wave_total)
	var is_elite_wave: bool = (enemy_wave_index > 1 and enemy_wave_index % 3 == 0)

	for _i in range(to_spawn):
		if enemy_unit_count >= _enemy_field_unit_cap():
			break
		var slot_i: int = _card_grid_next_free_enemy_slot_index()
		if slot_i < 0:
			break
		var archetype_id: String = ""
		if is_last_wave and _enemy_wave_total > 3 and not boss_ids.is_empty():
			archetype_id = String(boss_ids[randi() % boss_ids.size()])
		elif is_elite_wave and not elite_ids.is_empty():
			archetype_id = String(elite_ids[randi() % elite_ids.size()])
		elif not basic_ids.is_empty():
			archetype_id = String(basic_ids[randi() % basic_ids.size()])
		elif not era_archetypes.is_empty():
			archetype_id = String(era_archetypes[randi() % era_archetypes.size()])

		var spawn_g: Vector2 = _enemy_slot_global_position(slot_i)

		if not archetype_id.is_empty() and EnemyArchetypes.should_spawn_as_swarm(archetype_id):
			var ctl: Node = _ensure_swarm_controller()
			if ctl and ctl.has_method("spawn_slot"):
				var local_p: Vector2 = spawn_g - _enemy_units_node.global_position
				var slot: Node = ctl.spawn_slot(enemy_wave_index, archetype_id, local_p)
				if slot != null:
					enemy_unit_count += 1
					if slot is Object:
						(slot as Object).set_meta("card_grid_enemy_slot", slot_i)
					if _signal_bus:
						_signal_bus.unit_spawned.emit(slot, false)
			continue

		var unit: Node2D = _create_enemy_unit_with_id(archetype_id) as Node2D
		if unit == null:
			continue
		if not spawn_enemy_unit_on_card_grid(unit, slot_i):
			if is_instance_valid(unit):
				unit.queue_free()
			continue

	return true


func _enemy_slot_global_position(slot_i: int) -> Vector2:
	if _battlefield != null and _battlefield.has_method("ensure_battle_slot_grid_ready"):
		_battlefield.ensure_battle_slot_grid_ready()
	var grid: Node = _battlefield.get_node_or_null("BattleSlotGrid") if _battlefield else null
	if _battlefield != null and _battlefield.has_method("get_card_grid_enemy_slot_global"):
		return _battlefield.get_card_grid_enemy_slot_global(slot_i)
	if grid is Node2D and grid.has_method("get_enemy_slot_center"):
		return (grid as Node2D).to_global(grid.get_enemy_slot_center(slot_i))
	return Vector2(1100, 360)


## 敌方单位放入下一个空敌槽（索引 0 靠中线、递增至右缘）；相位师产兵 / 波次刷敌共用
func spawn_enemy_unit_on_card_grid(unit: Node2D, preferred_slot: int = -1) -> bool:
	if not _card_grid_active or _enemy_units_node == null or unit == null:
		return false
	if not is_instance_valid(unit):
		return false
	if enemy_unit_count >= _enemy_field_unit_cap():
		return false
	var slot_i: int = preferred_slot
	if slot_i < 0 or _is_enemy_grid_slot_occupied(slot_i):
		slot_i = _card_grid_next_free_enemy_slot_index()
	if slot_i < 0:
		return false
	var spawn_g: Vector2 = _enemy_slot_global_position(slot_i)
	var parent: Node = unit.get_parent()
	if parent != _enemy_units_node:
		if parent != null:
			parent.remove_child(unit)
		_enemy_units_node.add_child(unit)
	unit.global_position = spawn_g
	unit.set_meta("card_grid_enemy_slot", slot_i)
	if unit.has_method("apply_card_grid_enemy_presentation"):
		unit.apply_card_grid_enemy_presentation()
	if BattleManager and BattleManager.spatial_grid and unit is Node2D:
		BattleManager.spatial_grid.update(unit as Node2D)
	enemy_unit_count += 1
	if _signal_bus:
		_signal_bus.unit_spawned.emit(unit, false)
	return true


## 单位已在 EnemyUnits 子树内时吸附到敌槽（不重复计数）
func place_existing_enemy_on_card_grid(unit: Node) -> bool:
	if not _card_grid_active or unit == null or not (unit is Node2D):
		return false
	if not _unit_is_under_enemy_units(unit):
		return false
	var u := unit as Node2D
	var esi: int = int(u.get_meta("card_grid_enemy_slot", -1))
	if esi < 0:
		esi = _card_grid_next_free_enemy_slot_index()
		if esi < 0:
			return false
		u.set_meta("card_grid_enemy_slot", esi)
	u.global_position = _enemy_slot_global_position(esi)
	if u.has_method("apply_card_grid_enemy_presentation"):
		u.apply_card_grid_enemy_presentation()
	return true


func _unit_is_under_enemy_units(unit: Node) -> bool:
	if unit == null or _enemy_units_node == null:
		return false
	if unit.get_parent() == _enemy_units_node:
		return true
	return _enemy_units_node.is_ancestor_of(unit)


func reset(battle_scene: Node, enemy_wave_interval: float, enemy_wave_total: int) -> void:
	_battlefield = battle_scene
	_player_units_node = _battlefield.get_node_or_null("PlayerUnits")
	_enemy_units_node = _battlefield.get_node_or_null("EnemyUnits")
	if _battlefield.has_method("get_player_units_node"):
		_player_units_node = _battlefield.get_player_units_node()
	if _battlefield.has_method("get_enemy_units_node"):
		_enemy_units_node = _battlefield.get_enemy_units_node()
	if _player_units_node == null:
		_player_units_node = _battlefield
	if _enemy_units_node == null:
		_enemy_units_node = _battlefield
		push_warning("[BattleSpawnSystem] EnemyUnits 缺失，回退到战场根节点。")

	player_unit_count = 0
	enemy_unit_count = 0
	_max_player_units_deployed = 0
	_player_units_lost = 0
	# 与关卡波次间隔一致：从 0 计，首波也需等满 `_enemy_wave_interval` 再整波同时刷出
	enemy_wave_timer = 0.0
	enemy_wave_index = 0
	_enemy_wave_interval = enemy_wave_interval
	_enemy_wave_total = enemy_wave_total
	_stats_cache.clear()
	_card_grid_active = false
	_card_grid_enemy_quota = _CardGridSlotsPerSide

# =========================================================================
#  波次计时（由 BattleManager._process 调用）
# =========================================================================

func update_wave_timer(delta: float) -> void:
	enemy_wave_timer += delta

func should_spawn_wave() -> bool:
	return enemy_wave_timer >= _enemy_wave_interval

func can_spawn_more_waves() -> bool:
	return (_enemy_wave_total <= 0 or enemy_wave_index < _enemy_wave_total)

func consume_wave_timer() -> void:
	enemy_wave_timer = 0.0

# =========================================================================
#  玩家单位部署
# =========================================================================

func request_player_deploy(platform_card_id: String, world_pos: Vector2, battle_era: int) -> bool:
	var bm: Node = _get_autoload_node("BattleManager")
	if bm != null and "battle_active" in bm and not bool(bm.battle_active):
		_emit_deploy_failed("internal", "战斗已结束，无法部署。")
		return false
	if _player_units_node == null or _phase_instrument == null:
		push_warning("[BattleSpawnSystem] 部署失败: 节点未初始化 (player_units=%s, phase_instrument=%s)" % [_player_units_node != null, _phase_instrument != null])
		_emit_deploy_failed("internal", "当前无法部署。")
		return false
	# 使用相位仪的绿色槽位数量作为单位上限
	var max_units: int = GC.PLAYER_MAX_UNITS
	if _phase_instrument.has_method("get_max_deployable_units"):
		max_units = _phase_instrument.get_max_deployable_units()
	if _card_grid_active:
		max_units = mini(max_units, _CardGridSlotsPerSide)
	if player_unit_count >= max_units:
		_emit_deploy_failed("max_units", "我方单位数量已达上限（%d/%d）。" % [player_unit_count, max_units])
		return false
	if _reach_alive_limit_for_card(platform_card_id):
		_emit_deploy_failed("unit_on_field", "该单位同配置已全部在场上，请待其离场后再部署。")
		return false
	var loadout: Dictionary = {}
	if _phase_instrument.has_method("get_loadout_by_platform_card_id"):
		loadout = _phase_instrument.get_loadout_by_platform_card_id(platform_card_id)
	if loadout.is_empty():
		_emit_deploy_failed("invalid_loadout", "未找到有效战斗卡配置，请检查绿槽。")
		return false
	var platform_card: CardResource = loadout.get("platform", null)
	var weapon_cards: Array = []
	if platform_card == null:
		_emit_deploy_failed("invalid_loadout", "未找到有效战斗卡配置，请检查绿槽。")
		return false
	var weapon_types: Array = resolve_deploy_weapon_types(platform_card)
	var deploy_slot_idx: int = -1
	if _battlefield == null or not is_instance_valid(_battlefield):
		_emit_deploy_failed("internal", "战场未就绪。")
		return false
	var grid: Node = null
	if _battlefield.has_method("ensure_battle_slot_grid_ready"):
		grid = _battlefield.ensure_battle_slot_grid_ready()
	else:
		grid = _battlefield.get_node_or_null("BattleSlotGrid")
	if grid == null or not is_instance_valid(grid) or not grid.has_method("find_nearest_player_slot"):
		_emit_deploy_failed("internal", "格子战场未就绪。")
		return false
	var query_pos: Vector2 = world_pos
	if grid is Node2D and _battlefield is Node2D:
		query_pos = (grid as Node2D).to_local((_battlefield as Node2D).to_global(world_pos))
	var si: int = grid.find_nearest_player_slot(query_pos)
	if si < 0:
		_emit_deploy_failed("out_of_bounds", "请点击我方格子区域部署。")
		return false
	if grid.has_method("is_player_slot_occupied") and grid.is_player_slot_occupied(si, _player_units_node):
		_emit_deploy_failed("slot_busy", "该格子已有单位。")
		return false
	deploy_slot_idx = si
	if _battlefield.has_method("get_card_grid_player_slot_global"):
		world_pos = _battlefield.get_card_grid_player_slot_global(si)
	elif grid is Node2D:
		world_pos = (grid as Node2D).to_global(grid.get_player_slot_center(si))
	else:
		world_pos = grid.get_player_slot_center(si)
	var output_rate: float = 1.0
	if _phase_instrument.has_method("get_energy_output_rate"):
		output_rate = maxf(0.1, float(_phase_instrument.get_energy_output_rate()))
	# 无武器版：部署费用仅由平台卡决定
	var deploy_energy_cost: float = maxf(1.0, float(platform_card.energy_cost))
	var deploy_time: float = deploy_energy_cost / output_rate
	if _energy_manager and _energy_manager.has_method("spend"):
		if not _energy_manager.spend(deploy_energy_cost):
			_emit_deploy_failed("insufficient_energy", "能量不足，无法完成部署。")
			return false
	var stats = _build_stats_cached(platform_card, weapon_cards, weapon_types, battle_era)
	#endregion
	# 填充卡牌 ID（用于战斗中判断卡牌特殊能力）
	stats.platform_card_id = platform_card.card_id
	stats.weapon_card_ids.clear()
	for wc in weapon_cards:
		if wc != null and not wc.card_id.is_empty():
			stats.weapon_card_ids.append(wc.card_id)
	var unit = _create_player_unit(stats)
	if unit == null:
		_emit_deploy_failed("internal", "部署失败，请重试。")
		return false
	unit.set_meta("source_card_id", platform_card.card_id)
	if deploy_slot_idx >= 0:
		unit.set_meta("card_grid_slot", deploy_slot_idx)
	_player_units_node.add_child(unit)
	unit.global_position = world_pos
	if deploy_slot_idx >= 0 and _battlefield != null and _battlefield.has_method("snap_card_grid_unit") and unit is Node2D:
		_battlefield.snap_card_grid_unit(unit as Node2D)
	if unit.has_method("start_as_deploy_ghost"):
		unit.start_as_deploy_ghost()
	if BattleManager and BattleManager.spatial_grid and unit is Node2D:
		var sg: Node = BattleManager.spatial_grid
		if sg.has_method("insert"):
			sg.insert(unit as Node2D)
	player_unit_count += 1
	if player_unit_count > _max_player_units_deployed:
		_max_player_units_deployed = player_unit_count
	if _signal_bus:
		_signal_bus.unit_spawned.emit(unit, true)
	return true

func clear_preview_units() -> void:
	if _player_units_node == null or not is_instance_valid(_player_units_node):
		return

	var children = _player_units_node.get_children().duplicate()
	for u in children:
		if is_instance_valid(u) and u.has_method("get"):
			var is_preview = u.get("is_preview_mode")
			if is_preview == true:
				if u.has_method("set_physics_process"):
					u.set_physics_process(false)
				u.queue_free()

# =========================================================================
#  单位清理
# =========================================================================

func _free_damage_numbers_under(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	for c in node.get_children():
		if c != null and is_instance_valid(c) and c.is_in_group("battle_damage_numbers"):
			_DamageNumberDisplayScript.try_return_to_pool(c)


func clear_all_units() -> void:
	if OS.is_debug_build():
		print("[BattleSpawnSystem] clear_all_units: clearing units")
	player_unit_count = 0
	enemy_unit_count = 0

	# 先清飘字：暂停/结算帧内 _process 可能未跑完，避免残留在单位层下
	if _player_units_node and is_instance_valid(_player_units_node):
		_free_damage_numbers_under(_player_units_node)
	if _enemy_units_node and is_instance_valid(_enemy_units_node):
		_free_damage_numbers_under(_enemy_units_node)
	if _battlefield and is_instance_valid(_battlefield):
		_free_damage_numbers_under(_battlefield)

	if _player_units_node and is_instance_valid(_player_units_node):
		var children = _player_units_node.get_children().duplicate()
		if OS.is_debug_build():
			print("[BattleSpawnSystem] Clearing ", children.size(), " player units")
		for u in children:
			if is_instance_valid(u):
				if u.has_method("set") and "is_preview_mode" in u:
					u.set("is_preview_mode", false)
				u.queue_free()
	if _enemy_units_node and is_instance_valid(_enemy_units_node):
		var children = _enemy_units_node.get_children().duplicate()
		if OS.is_debug_build():
			print("[BattleSpawnSystem] Clearing ", children.size(), " enemy units")
		for u in children:
			if is_instance_valid(u):
				u.queue_free()
	_clear_battlefield_transient_nodes()
	if OS.is_debug_build():
		print("[BattleSpawnSystem] clear_all_units done")

func _clear_battlefield_transient_nodes() -> void:
	if _battlefield == null or not is_instance_valid(_battlefield):
		return
	if _battlefield.has_method("prune_transient_children"):
		_battlefield.prune_transient_children()
		return
	for child in _battlefield.get_children():
		if child == null or not is_instance_valid(child):
			continue
		child.queue_free()

# =========================================================================
#  玩家单位计数（由 BattleManager._on_unit_died 调用）
# =========================================================================

func on_player_unit_died() -> void:
	player_unit_count = max(0, player_unit_count - 1)
	_player_units_lost += 1

func on_enemy_unit_died() -> void:
	enemy_unit_count = max(0, enemy_unit_count - 1)

# =========================================================================
#  只读 HUD 接口
# =========================================================================

func get_player_spawn_time_remaining() -> float:
	if _player_deploy_manual:
		return -1.0
	return -1.0  # 手动部署模式

func get_player_spawn_interval() -> float:
	if _player_deploy_manual:
		return 0.0
	return 0.0

func get_player_unit_count_active() -> int:
	return player_unit_count

func get_enemy_wave_time_remaining() -> float:
	return maxf(0.0, _enemy_wave_interval - enemy_wave_timer)

func get_enemy_wave_interval() -> float:
	return _enemy_wave_interval

func get_enemy_wave_index() -> int:
	return enemy_wave_index

func get_enemy_unit_count_active() -> int:
	return enemy_unit_count

func get_enemy_wave_total() -> int:
	return _enemy_wave_total

func get_player_units_node() -> Node:
	return _player_units_node

func get_enemy_units_node() -> Node:
	return _enemy_units_node

func get_max_player_units_deployed() -> int:
	return _max_player_units_deployed

func get_player_units_lost() -> int:
	return _player_units_lost

# =========================================================================
#  内部工具
# =========================================================================

func _current_battle_era(level: int) -> int:
	return GC.get_era_for_level(level)

func _has_alive_player_unit_from_card(card_id: String) -> bool:
	if card_id.is_empty() or _player_units_node == null:
		return false
	for n in _player_units_node.get_children():
		if n != null and is_instance_valid(n) and String(n.get_meta("source_card_id", "")) == card_id:
			return true
	return false

func _count_alive_player_units_from_card(card_id: String) -> int:
	if card_id.is_empty() or _player_units_node == null:
		return 0
	var count: int = 0
	for n in _player_units_node.get_children():
		if n != null and is_instance_valid(n) and String(n.get_meta("source_card_id", "")) == card_id:
			count += 1
	return count

func _count_equipped_loadouts_from_card(card_id: String) -> int:
	if card_id.is_empty() or _phase_instrument == null or not _phase_instrument.has_method("get_loadouts"):
		return 0
	var count: int = 0
	var loadouts: Array = _phase_instrument.get_loadouts()
	for ld in loadouts:
		if not (ld is Dictionary):
			continue
		var plat: CardResource = ld.get("platform", null)
		if plat != null and plat.card_id == card_id:
			count += 1
	return count

func _reach_alive_limit_for_card(card_id: String) -> bool:
	if card_id.is_empty():
		return false
	var equipped_count: int = _count_equipped_loadouts_from_card(card_id)
	if equipped_count <= 0:
		# 回退旧行为：未知装配信息时，仍保持“同卡最多一台”保护
		return _has_alive_player_unit_from_card(card_id)
	var alive_count: int = _count_alive_player_units_from_card(card_id)
	return alive_count >= equipped_count

func _create_player_unit(stats: UnitStats) -> Node:
	var u = ConstructUnitScene.instantiate()
	# 我方战斗单位视觉同形：按 platform_card_id 反查 EnemyArchetypes.drops，
	# 命中则强制走 archetype 路径；找不到时回落到 ConstructUnit 内部的兜底逻辑。
	var archetype_id: String = ""
	if stats != null and not stats.platform_card_id.is_empty():
		archetype_id = EnemyArchetypes.get_visual_archetype_id_for_card(stats.platform_card_id)
	if not archetype_id.is_empty() and u.has_method("setup_with_enemy_visual"):
		u.setup_with_enemy_visual(true, stats, archetype_id)
	else:
		u.setup(true, stats)
	return u

func _create_enemy_unit_with_id(arch_id: String) -> Node:
	var scene = preload("res://scenes/units/enemy_unit.tscn")
	var u = scene.instantiate()
	u.setup(false, enemy_wave_index, arch_id)
	return u

func _ensure_swarm_controller() -> Node:
	if _enemy_units_node == null or not is_instance_valid(_enemy_units_node):
		return null
	var existing: Node = _enemy_units_node.get_node_or_null("SwarmEnemyController")
	if existing:
		return existing
	var ctl: Node = SwarmEnemyControllerScript.new()
	ctl.name = "SwarmEnemyController"
	_enemy_units_node.add_child(ctl)
	return ctl

func _emit_deploy_failed(reason_code: String, message: String) -> void:
	var now_ms: int = Time.get_ticks_msec()
	var key: String = "%s|%s" % [reason_code, message]
	if key != _last_deploy_fail_key or (now_ms - _last_deploy_fail_ts_ms) >= DEPLOY_FAIL_LOG_THROTTLE_MS:
		print("[BattleSpawnSystem] 部署失败: reason=%s, msg=%s" % [reason_code, message])
		_last_deploy_fail_key = key
		_last_deploy_fail_ts_ms = now_ms
	if _signal_bus:
		_signal_bus.player_deploy_failed.emit(reason_code, message)


## 与 backpack_combat_preview 一致：一体卡多武器用 multi_weapon_types，否则单默认武器。
static func resolve_deploy_weapon_types(card: CardResource) -> Array:
	if card == null:
		return [1]  # RIFLE
	var default_wt: int = int(card.default_weapon_type) if card.default_weapon_type >= 0 else 1  # RIFLE
	if card.card_type == GC.CardType.COMBAT_UNIT:
		var wts: Array = []
		for t in card.multi_weapon_types:
			wts.append(int(t))
		if wts.is_empty() and card.default_weapon_type >= 0:
			wts.append(int(card.default_weapon_type))
		if wts.is_empty():
			wts.append(1)  # RIFLE
		return wts
	return [default_wt]


func _build_stats_cached(platform_card: CardResource, weapon_cards: Array, weapon_types: Array, battle_era: int) -> UnitStats:
	var weapon_ids: Array[String] = []
	for wc in weapon_cards:
		if wc != null and not wc.card_id.is_empty():
			weapon_ids.append(wc.card_id)
	weapon_ids.sort()
	var wt_parts: Array[String] = []
	for wt_raw in weapon_types:
		wt_parts.append(str(int(wt_raw)))
	wt_parts.sort()
	var weapon_types_key: String = ",".join(wt_parts)
	var pf_bonus_key: String = ""
	if _phase_instrument and _phase_instrument.has_method("get_phase_field_total_bonus"):
		var pf_bonus: Dictionary = _phase_instrument.get_phase_field_total_bonus()
		var keys: Array = pf_bonus.keys()
		keys.sort()
		var kv_parts: Array[String] = []
		for k in keys:
			kv_parts.append("%s=%.6f" % [String(k), float(pf_bonus[k])])
		pf_bonus_key = ",".join(kv_parts)

	# === 势力变体查询（需在缓存 key 之前，因 key 包含势力信息） ===
	var effective_card: CardResource = platform_card
	var faction_bonus_dict: Dictionary = {}
	var active_faction_cache_key: String = ""
	if not platform_card.is_faction_variant:
		var fsm: Node = _get_autoload_node("FactionSystemManager")
		if fsm and fsm.has_method("get_active_faction"):
			var active_faction: String = fsm.get_active_faction()
			if not active_faction.is_empty():
				var faction_level: int = fsm.get_faction_level(active_faction)
				if faction_level > 0:
					active_faction_cache_key = "%s:%d" % [active_faction, faction_level]
					var variant: CardResource = FactionCardGenerator.generate_faction_variant(
						platform_card.card_id, active_faction, faction_level
					)
					if variant != null:
						effective_card = variant
						faction_bonus_dict = FactionCardBonuses.get_bonus(active_faction, faction_level)
	else:
		active_faction_cache_key = "%s:%d" % [platform_card.faction_id, platform_card.faction_level]
		faction_bonus_dict = FactionCardBonuses.get_bonus(platform_card.faction_id, platform_card.faction_level)

	# 缓存 key 包含势力变体信息，避免不同势力下命中错误缓存
	var key: String = "%s|%s|%s|%d|%s|%s" % [
		platform_card.card_id, ",".join(weapon_ids), weapon_types_key, battle_era, pf_bonus_key,
		active_faction_cache_key
	]
	if _stats_cache.has(key):
		var cached_stats: UnitStats = _stats_cache[key]
		return cached_stats.duplicate() as UnitStats

	var stats = UnitStatsTable.build_stats_from_card(effective_card, battle_era)

	# 势力特殊属性注入到 UnitStats（闪避/暴击/命中/回复/减伤/法则效果）
	if not faction_bonus_dict.is_empty():
		FactionCardGenerator.apply_faction_special_to_stats(stats, faction_bonus_dict)
	# === 势力技能树加成注入 ===
	var fsm_skill: Node = _get_autoload_node("FactionSystemManager")
	if fsm_skill and fsm_skill.has_method("get_active_faction_skill_effects"):
		var skill_effects: Dictionary = fsm_skill.get_active_faction_skill_effects()
		if not skill_effects.is_empty():
			_apply_skill_tree_effects(stats, skill_effects)
	var bm_growth: Node = _get_autoload_node("BlueprintManager")
	if bm_growth and bm_growth.has_method("apply_growth_to_stats"):
		bm_growth.apply_growth_to_stats(stats, platform_card, weapon_cards)
	var am: Node = _get_autoload_node("AffixManager")
	if am and am.has_method("apply_affixes_to_stats"):
		am.apply_affixes_to_stats(stats, platform_card, weapon_cards)
	if _phase_instrument and _phase_instrument.has_method("apply_phase_field_bonus_to_unit_stats"):
		_phase_instrument.apply_phase_field_bonus_to_unit_stats(stats)
	_stats_cache[key] = stats.duplicate()
	return stats

func _get_autoload_node(name: String) -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var tree: SceneTree = loop as SceneTree
		if tree.root != null:
			return tree.root.get_node_or_null(name)
	return null

## 应用势力技能树效果到UnitStats
func _apply_skill_tree_effects(stats: Node, effects: Dictionary) -> void:
	# 属性加成（百分比）
	var sb: Dictionary = effects.get("stat_bonus", {})
	if sb.has("hp") and float(sb["hp"]) != 0.0:
		stats.max_hp *= (1.0 + float(sb["hp"]))
	if sb.has("atk_light") and float(sb["atk_light"]) != 0.0:
		stats.attack_light *= (1.0 + float(sb["atk_light"]))
	if sb.has("atk_armor") and float(sb["atk_armor"]) != 0.0:
		stats.attack_armor *= (1.0 + float(sb["atk_armor"]))
	if sb.has("atk_air") and float(sb["atk_air"]) != 0.0:
		stats.attack_air *= (1.0 + float(sb["atk_air"]))
	if sb.has("def_light") and float(sb["def_light"]) != 0.0:
		stats.defense_light *= (1.0 + float(sb["def_light"]))
	if sb.has("def_armor") and float(sb["def_armor"]) != 0.0:
		stats.defense_armor *= (1.0 + float(sb["def_armor"]))
	if sb.has("def_air") and float(sb["def_air"]) != 0.0:
		stats.defense_air *= (1.0 + float(sb["def_air"]))
	if sb.has("attack_speed") and float(sb["attack_speed"]) != 0.0:
		var spd_mult: float = 1.0 + float(sb["attack_speed"])
		stats.attack_light_speed *= spd_mult
		stats.attack_armor_speed *= spd_mult
		stats.attack_air_speed *= spd_mult
	if sb.has("dodge") and float(sb["dodge"]) != 0.0:
		stats.dodge_chance = minf(stats.dodge_chance + float(sb["dodge"]), 0.80)
	if sb.has("crit_chance") and float(sb["crit_chance"]) != 0.0:
		stats.crit_chance = minf(stats.crit_chance + float(sb["crit_chance"]), 1.0)
	if sb.has("crit_damage") and float(sb["crit_damage"]) != 0.0:
		stats.crit_damage_bonus += float(sb["crit_damage"])
	if sb.has("accuracy") and float(sb["accuracy"]) != 0.0:
		stats.faction_accuracy_bonus = minf(stats.faction_accuracy_bonus + float(sb["accuracy"]), 0.50)
	if sb.has("effect") and float(sb["effect"]) != 0.0:
		stats.faction_effect_bonus *= (1.0 + float(sb["effect"]))
	if sb.has("hp_regen") and float(sb["hp_regen"]) != 0.0:
		stats.hp_regen += float(sb["hp_regen"])
	if sb.has("damage_reduction") and float(sb["damage_reduction"]) != 0.0:
		stats.damage_reduction = minf(stats.damage_reduction + float(sb["damage_reduction"]), 0.50)
	if sb.has("move_speed") and float(sb["move_speed"]) != 0.0:
		stats.move_speed *= (1.0 + float(sb["move_speed"]))
	if sb.has("range") and int(sb["range"]) != 0:
		stats.attack_range += int(sb["range"])
	# 部署加成（在部署阶段使用）
	# 特殊效果标记（由战斗系统读取处理）
	var specials: Array = effects.get("special", [])
	if not specials.is_empty():
		stats.skill_tree_specials = specials
