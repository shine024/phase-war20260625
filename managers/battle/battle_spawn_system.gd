extends RefCounted
## 战斗刷新子系统：玩家部署、敌方波次刷新、预览单位管理、单位清理
##
## 设计文档: docs/architecture/project-architecture.md (Section 4)
## 从 BattleManager 中提取，负责所有单位创建与生命周期管理。

const GC = preload("res://resources/game_constants.gd")
const EnemyArchetypes = preload("res://data/enemy_archetypes.gd")
const UnitStatsTable = preload("res://resources/unit_stats_table.gd")
const DefaultCards = preload("res://data/default_cards.gd")
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
## 每侧可用槽位数：SLOTS_PER_SIDE(7) 减去 1 个靠屏幕外缘的禁放位（我方 slot 0 / 敌方 slot N-1）= 6
var _usable_enemy_slots: int = max(1, _CardGridSlotsPerSide - 1)

func setup(deps: Dictionary) -> void:
	_energy_manager = deps.get("energy_manager", null)
	_phase_instrument = deps.get("phase_instrument", null)
	_signal_bus = deps.get("signal_bus", null)

func configure_card_grid_battle(enemy_quota: int) -> void:
	_card_grid_active = true
	_card_grid_enemy_quota = clampi(enemy_quota, 1, _CardGridSlotsPerSide)
	# 敌方仅 slot N-1（全局位置 15，最右靠屏幕边）禁放，实际可用 = SLOTS_PER_SIDE - 1
	_usable_enemy_slots = max(1, _CardGridSlotsPerSide - 1)


func _enemy_field_unit_cap() -> int:
	# 敌方仅 slot N-1 禁放，实际可用 = SLOTS_PER_SIDE - 1
	return max(0, _CardGridSlotsPerSide - 1)


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
	# 敌方仅 slot N-1（位置 15）禁放，可用 slot 0~N-2
	for si in range(0, _CardGridSlotsPerSide - 1):
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


## 敌方区域：从远端 slot(最大索引，靠屏幕右缘、离玩家最远)开始填，依次向近端
## 敌方仅 slot N-1（位置 15，最右靠屏幕边）禁放，可用 slot 0~N-2；远端即 N-2
## 这样少量敌人也部署在远端，玩家曲射(先远后近)能优先打到后排
func _card_grid_next_free_enemy_slot_index() -> int:
	for si in range(_CardGridSlotsPerSide - 2, -1, -1):
		if not _is_enemy_grid_slot_occupied(si):
			return si
	return -1


## 按单位射程选敌方槽位：长程(>=阈值)放远端(slot N-2 起倒序)，短程放近端(slot 0 起顺序)
## 敌方仅 slot N-1（位置 15）禁放，可用 slot 0~N-2
## 短程直射单位放近端才够得到玩家；长程/曲射放远端供玩家曲射打击
func _pick_enemy_slot_by_range(attack_range: float) -> int:
	const LONG_RANGE_THRESHOLD: float = 300.0
	if attack_range >= LONG_RANGE_THRESHOLD:
		for si in range(_CardGridSlotsPerSide - 2, -1, -1):
			if not _is_enemy_grid_slot_occupied(si):
				return si
	else:
		for si in range(0, _CardGridSlotsPerSide - 1):
			if not _is_enemy_grid_slot_occupied(si):
				return si
	return -1


## 获取单位攻击射程（像素），用于按射程分配槽位
func _get_unit_attack_range(unit: Node2D) -> float:
	if unit == null:
		return 200.0
	if "attack_range" in unit:
		return float(unit.attack_range)
	if "stats" in unit and unit.stats != null:
		return float(unit.stats.attack_range)
	return 200.0


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
	# 敌方仅 slot N-1（位置 15）禁放，实际可用槽位 = SLOTS_PER_SIDE - 1
	var usable_enemy_slots: int = max(1, _CardGridSlotsPerSide - 1)
	_card_grid_enemy_quota = mini(_card_grid_enemy_quota, usable_enemy_slots)
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
		var archetype_id: String = ""
		if is_last_wave and _enemy_wave_total > 3 and not boss_ids.is_empty():
			archetype_id = String(boss_ids[randi() % boss_ids.size()])
		elif is_elite_wave and not elite_ids.is_empty():
			archetype_id = String(elite_ids[randi() % elite_ids.size()])
		elif not basic_ids.is_empty():
			archetype_id = String(basic_ids[randi() % basic_ids.size()])
		elif not era_archetypes.is_empty():
			archetype_id = String(era_archetypes[randi() % era_archetypes.size()])

		# 蜂群单位视为短程，部署到近端
		if not archetype_id.is_empty() and EnemyArchetypes.should_spawn_as_swarm(archetype_id):
			var swarm_slot: int = _pick_enemy_slot_by_range(150.0)
			if swarm_slot < 0:
				break
			var spawn_g: Vector2 = _enemy_slot_global_position(swarm_slot)
			var ctl: Node = _ensure_swarm_controller()
			if ctl and ctl.has_method("spawn_slot"):
				var local_p: Vector2 = spawn_g - _enemy_units_node.global_position
				var slot: Node = ctl.spawn_slot(enemy_wave_index, archetype_id, local_p)
				if slot != null:
					enemy_unit_count += 1
					if slot is Object:
						(slot as Object).set_meta("card_grid_enemy_slot", swarm_slot)
					if _signal_bus:
						_signal_bus.unit_spawned.emit(slot, false)
			continue

		# 普通单位：先创建，再按实际射程选 slot（长程远端、短程近端）
		var unit: Node2D = _create_enemy_unit_with_id(archetype_id) as Node2D
		if unit == null:
			continue
		if not spawn_enemy_unit_on_card_grid(unit, -1):
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
		# 按单位射程分层：长程远端、短程近端
		slot_i = _pick_enemy_slot_by_range(_get_unit_attack_range(unit))
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
		# 玩家侧仅 slot 0（位置 1，最左靠屏幕边）禁放，实际可用 = SLOTS_PER_SIDE - 1
		var usable_slots: int = max(1, _CardGridSlotsPerSide - 1)
		max_units = mini(max_units, usable_slots)
	# v6.5: 用实时 recount（与 HUD 显示口径一致）替代缓存 player_unit_count，
	# 避免单位死亡淡出/幽灵态导致缓存与实际脱节，出现"显示4个却不让部署"的错位。
	var live_count: int = player_unit_count
	if BattleManager != null and BattleManager.has_method("recount_player_units_on_field"):
		live_count = BattleManager.recount_player_units_on_field()
		player_unit_count = live_count  # 同步缓存，保持后续逻辑一致
	if live_count >= max_units:
		_emit_deploy_failed("max_units", "我方单位数量已达上限（%d/%d）。" % [live_count, max_units])
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
	# v6.6: 免能量能力（free_energy）— 应用部署成本倍率（0=全免）
	var deploy_cost_mult: float = _get_free_energy_multiplier()
	deploy_energy_cost = deploy_energy_cost * deploy_cost_mult
	deploy_time = deploy_time * deploy_cost_mult
	if _energy_manager and _energy_manager.has_method("spend"):
		# cost 为 0 时跳过消耗（免能量）
		if deploy_energy_cost > 0.0 and not _energy_manager.spend(deploy_energy_cost):
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
	# v6.6: 幻影克隆 — 若本次部署是同卡的第2个单位（克隆体），应用克隆加成
	if _is_phantom_clone_for_card(platform_card.card_id):
		_apply_phantom_clone_buff(unit)
		unit.set_meta("is_phantom_clone", true)
	# v6.6: 钢铁壁垒 — 装甲/堡垒类单位部署时最大HP翻倍（耐久加倍）
	_apply_fortress_bulwark_buff(unit)
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
		pass
		# [LOG-v5.1] print("[BattleSpawnSystem] clear_all_units: clearing units")
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
			pass
			# [LOG-v5.1] print("[BattleSpawnSystem] Clearing ", children.size(), " player units")
		for u in children:
			if is_instance_valid(u):
				if u.has_method("set") and "is_preview_mode" in u:
					u.set("is_preview_mode", false)
				u.queue_free()
	if _enemy_units_node and is_instance_valid(_enemy_units_node):
		var children = _enemy_units_node.get_children().duplicate()
		if OS.is_debug_build():
			pass
			# [LOG-v5.1] print("[BattleSpawnSystem] Clearing ", children.size(), " enemy units")
		for u in children:
			if is_instance_valid(u):
				u.queue_free()
	_clear_battlefield_transient_nodes()
	if OS.is_debug_build():
		pass
		# [LOG-v5.1] print("[BattleSpawnSystem] clear_all_units done")

func _clear_battlefield_transient_nodes() -> void:
	if _battlefield == null or not is_instance_valid(_battlefield):
		return
	# v6.6: 延迟到下一帧清理战场瞬态节点，避免结算帧阻塞
	var bf: Node = _battlefield
	call_deferred("_do_prune_transient", bf)

func _do_prune_transient(bf: Node) -> void:
	if bf == null or not is_instance_valid(bf):
		return
	if bf.has_method("prune_transient_children"):
		bf.prune_transient_children()
		return
	for child in bf.get_children():
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
	# v6.6: 幻影克隆（phantom_clone）— 同卡可放2个单位
	var alive_limit: int = equipped_count * _get_phantom_deploy_multiplier()
	var alive_count: int = _count_alive_player_units_from_card(card_id)
	return alive_count >= alive_limit

## v6.6: 获取免能量部署的成本倍率（0=全免，1=正常，0.5=半价）
func _get_free_energy_multiplier() -> float:
	if _phase_instrument == null or not _phase_instrument.has_method("get_active_ability"):
		return 1.0
	var ability: Dictionary = _phase_instrument.get_active_ability()
	if ability.is_empty() or String(ability.get("id", "")) != "free_energy":
		return 1.0
	var params: Dictionary = ability.get("params", {})
	return float(params.get("deploy_cost_multiplier", 1.0))

## v6.6: 获取幻影克隆的部署倍率（1=正常1个，2=可放2个）
func _get_phantom_deploy_multiplier() -> int:
	if _phase_instrument == null or not _phase_instrument.has_method("get_active_ability"):
		return 1
	var ability: Dictionary = _phase_instrument.get_active_ability()
	if ability.is_empty() or String(ability.get("id", "")) != "phantom_clone":
		return 1
	var params: Dictionary = ability.get("params", {})
	return int(params.get("deploy_count", 1))

## v6.6: 判断新部署的单位是否为克隆体（第2个），若是则应用克隆加成
func _is_phantom_clone_for_card(card_id: String) -> bool:
	if _get_phantom_deploy_multiplier() < 2:
		return false
	# 当同卡已有1个存活单位时，这次部署的是第2个=克隆体
	return _count_alive_player_units_from_card(card_id) >= 1

## v6.6: 应用幻影克隆加成到克隆体单位（攻击+%，血量+%）
func _apply_phantom_clone_buff(unit: Node) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if _phase_instrument == null or not _phase_instrument.has_method("get_active_ability"):
		return
	var ability: Dictionary = _phase_instrument.get_active_ability()
	if ability.is_empty() or String(ability.get("id", "")) != "phantom_clone":
		return
	var params: Dictionary = ability.get("params", {})
	var atk_bonus: float = float(params.get("clone_atk_bonus", 0.0))
	var hp_bonus: float = float(params.get("clone_hp_bonus", 0.0))
	var unit_stats = unit.get("stats")
	if unit_stats == null:
		return
	# 血量加成
	if hp_bonus > 0.0:
		var old_max: float = float(unit_stats.max_hp)
		var new_max: float = maxf(1.0, old_max * (1.0 + hp_bonus))
		unit_stats.max_hp = new_max
		if "max_hp" in unit:
			unit.hp = new_max  # 克隆体满血出场
		if unit.has_method("_update_hp_bar"):
			unit._update_hp_bar()
	# 攻击加成（三维攻击 + 武器伤害）
	if atk_bonus > 0.0:
		var mult: float = 1.0 + atk_bonus
		unit_stats.attack_damage = maxf(0.1, float(unit_stats.attack_damage) * mult)
		unit_stats.attack_light = maxf(0.1, float(unit_stats.attack_light) * mult)
		unit_stats.attack_armor = maxf(0.1, float(unit_stats.attack_armor) * mult)
		unit_stats.attack_air = maxf(0.1, float(unit_stats.attack_air) * mult)
		for i in range(unit_stats.weapons.size()):
			var w: Variant = unit_stats.weapons[i]
			if w is Dictionary:
				var wd: Dictionary = w
				wd["damage"] = maxf(0.1, float(wd.get("damage", 0.0)) * mult)
				unit_stats.weapons[i] = wd
	# v6.6: 克隆体视觉区分——青蓝色半透明（受击闪白/死亡淡出均会正确保留此基础色调）
	# 单位此刻尚未入树，modulate 立即设置；入场脉冲延迟到入树后执行
	if unit is Node2D:
		(unit as Node2D).modulate = Color(0.55, 0.85, 1.0, 0.72)
		(unit as Node2D).call_deferred("_play_phantom_clone_spawn_pulse")

## v6.6: 钢铁壁垒（fortress_bulwark）— 装甲/堡垒类单位部署时最大HP按倍率增加（耐久加倍）
## 7星：装甲+堡垒 HP×2.0；5星：HP×1.5；3星：仅装甲 HP×1.3
func _apply_fortress_bulwark_buff(unit: Node) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if _phase_instrument == null or not _phase_instrument.has_method("get_active_ability"):
		return
	var ability: Dictionary = _phase_instrument.get_active_ability()
	if ability.is_empty() or String(ability.get("id", "")) != "fortress_bulwark":
		return
	var unit_stats = unit.get("stats")
	if unit_stats == null:
		return
	# 判定单位是否属于目标 combat_kind（ARMOR=1 / FORT=4）
	var unit_kind: int = int(unit_stats.combat_kind)
	var params: Dictionary = ability.get("params", {})
	var target_kinds: Array = params.get("target_combat_kinds", [1, 4])
	if not (unit_kind in target_kinds):
		return
	# 应用 HP 倍率（max_hp + 当前 hp 同步提升，保持满血出场）
	var hp_mult: float = float(params.get("hp_multiplier", 2.0))
	unit_stats.max_hp = maxf(1.0, float(unit_stats.max_hp) * hp_mult)
	if "max_hp" in unit:
		unit.hp = float(unit_stats.max_hp)  # 耐久加倍后满血
	if unit.has_method("_update_hp_bar"):
		unit._update_hp_bar()
	unit.set_meta("fortress_bulwark_applied", true)

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
	# v6.7: 相位师 boss 对战时，给敌方单位应用排名差异化加成（与玩家方对称）
	_apply_enemy_phase_master_bonus_if_active(u)
	return u

## v6.7: 仅在相位师 boss 对战时给敌方单位应用排名加成
## 普通波次小怪不受影响（保持原数值）
func _apply_enemy_phase_master_bonus_if_active(unit: Node) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	var bm = Engine.get_main_loop() as SceneTree
	if bm == null or bm.root == null:
		return
	var battle_mgr: Node = bm.root.get_node_or_null("BattleManager")
	if battle_mgr == null or not ("_is_phase_master_battle" in battle_mgr):
		return
	if not bool(battle_mgr.get("_is_phase_master_battle")):
		return
	# 仅对有 stats 的单位应用（enemy_unit 的 stats 在 setup 中构建）
	var stats: Variant = unit.get("stats") if "stats" in unit else null
	if stats == null or not (stats is UnitStats):
		return
	if _phase_instrument != null and _phase_instrument.has_method("apply_enemy_phase_master_bonus_to_unit_stats"):
		var enemy_stars: int = 3
		if "_cached_enemy_rank_stars" in _phase_instrument:
			enemy_stars = int(_phase_instrument._cached_enemy_rank_stars)
		_phase_instrument.apply_enemy_phase_master_bonus_to_unit_stats(stats, enemy_stars)
	# 同步单位节点的派生字段（hp/max_hp 等），让 UI 血条与 stats 一致
	if unit.has_method("_update_hp_bar"):
		unit._update_hp_bar()

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
		# [LOG-v5.1] print("[BattleSpawnSystem] 部署失败: reason=%s, msg=%s" % [reason_code, message])
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
		# v6.7: 排名星级也纳入缓存 key（星级变化时加成系数变化，必须失效旧缓存）
		if "_cached_player_rank_stars" in _phase_instrument:
			pf_bonus_key += "|ps%d" % int(_phase_instrument._cached_player_rank_stars)

	# v6.8: 势力变体加成已停用（effective_card 直接使用原始 platform_card，势力不影响战斗数值）
	var effective_card: CardResource = platform_card
	var active_faction_cache_key: String = ""

	# v7.0: 实例化养成——若 platform_card 已是实例（instance_id 非空），养成数据直接在对象上，
	# 无需再查 CardEnhancementManager。仅对非实例卡（兼容旧路径）做查表注入。
	var instance_id_key: String = platform_card.instance_id if platform_card != null else ""
	if instance_id_key.is_empty():
		# 旧路径兼容：非实例卡，按 card_id 查 CardEnhancementManager 注入养成
		var cem: Node = _get_autoload_node("CardEnhancementManager")
		if cem and cem.has_method("get_module_slots"):
			var enhance_slots: Array = cem.get_module_slots(platform_card.card_id)
			if not enhance_slots.is_empty():
				var enhance_lvl: int = 0
				if cem.has_method("get_card_enhancement_level"):
					enhance_lvl = cem.get_card_enhancement_level(platform_card.card_id)
				if effective_card.enhance_level != enhance_lvl or effective_card.module_slots.is_empty():
					var card_clone: CardResource = effective_card.clone()
					card_clone.enhance_level = enhance_lvl
					card_clone.module_slots = enhance_slots
					effective_card = card_clone

	# 缓存 key：v7.0 实例卡用 instance_id（避免两张同名实例共享缓存），非实例卡用 card_id
	var card_key: String = instance_id_key if not instance_id_key.is_empty() else platform_card.card_id
	var key: String = "%s|%s|%s|%d|%s|%s" % [
		card_key, ",".join(weapon_ids), weapon_types_key, battle_era, pf_bonus_key,
		active_faction_cache_key
	]
	if _stats_cache.has(key):
		var cached_stats: UnitStats = _stats_cache[key]
		return cached_stats.duplicate() as UnitStats

	var stats = UnitStatsTable.build_stats_from_card(effective_card, battle_era)

	# v6.8: 势力特殊属性 / 势力技能树加成已停用（势力不影响战斗数值）
	var bm_growth: Node = _get_autoload_node("BlueprintManager")
	if bm_growth and bm_growth.has_method("apply_growth_to_stats"):
		bm_growth.apply_growth_to_stats(stats, platform_card, weapon_cards)
	# v6.0: 词条效果已由 UnitStatsTable.build_stats_from_card 内部处理
	# 不再需要额外调用 AffixManager.apply_affixes_to_stats
	if _phase_instrument and _phase_instrument.has_method("apply_phase_field_bonus_to_unit_stats"):
		_phase_instrument.apply_phase_field_bonus_to_unit_stats(stats)
	# v6.2: 符文之语全局加成注入（所有玩家单位共享）
	if _phase_instrument and _phase_instrument.has_method("get_rune_bonus"):
		_apply_rune_bonus_to_stats(stats, _phase_instrument.get_rune_bonus())
	# v6.8: 敌源MOD（D槽）战斗加成已停用（EOM 面板/掉落/存档保留）
	_stats_cache[key] = stats.duplicate()
	return stats

## v6.2: 应用符文之语加成到单位属性
## bonus 结构：{"stats": {attack: 0.5, hp: 0.3, ...}, "specials": [...]}
func _apply_rune_bonus_to_stats(stats: UnitStats, bonus: Dictionary) -> void:
	var stat_map: Dictionary = bonus.get("stats", {})
	# v6.2 修复：即使无数值加成，也要写入特殊效果（否则纯特殊效果符文之语会失效）
	# 先写入特殊效果，再处理数值加成
	var specials: Array = bonus.get("specials", [])
	if not specials.is_empty():
		stats.set_meta("rune_specials", specials)
	if stat_map.is_empty():
		return
	# 攻击力加成（影响所有武器伤害）
	if stat_map.has("attack") and float(stat_map["attack"]) != 0.0:
		var mult: float = 1.0 + float(stat_map["attack"])
		stats.attack_damage *= mult
		stats.attack_light *= mult
		stats.attack_armor *= mult
		stats.attack_air *= mult
		# 武器伤害同步缩放
		var weapons = stats.weapons if "weapons" in stats else null
		if weapons is Array:
			for w in weapons:
				if w is Dictionary and w.has("damage"):
					w["damage"] = float(w["damage"]) * mult
	# 防御力加成（影响所有防御维度）
	if stat_map.has("defense") and float(stat_map["defense"]) != 0.0:
		var def_mult: float = 1.0 + float(stat_map["defense"])
		stats.defense *= def_mult
		stats.defense_light *= def_mult
		stats.defense_armor *= def_mult
		stats.defense_air *= def_mult
	# 生命值加成
	if stat_map.has("hp") and float(stat_map["hp"]) != 0.0:
		stats.max_hp *= (1.0 + float(stat_map["hp"]))
	# 攻击速度加成（attack_speed → 降低 attack_interval）
	if stat_map.has("attack_speed") and float(stat_map["attack_speed"]) != 0.0:
		var speed_mult: float = 1.0 + float(stat_map["attack_speed"])
		stats.attack_light_speed /= speed_mult
		stats.attack_armor_speed /= speed_mult
		stats.attack_air_speed /= speed_mult
		stats.attack_interval /= speed_mult
	# 部署速度加成（影响部署间隔）
	if stat_map.has("deploy_speed") and float(stat_map["deploy_speed"]) != 0.0:
		# v6.2: 部署速度加成（UnitStats.deploy_speed 是部署速度倍率，直接叠加）
		stats.deploy_speed *= (1.0 + float(stat_map["deploy_speed"]))
	# 射程加成
	if stat_map.has("range") and float(stat_map["range"]) != 0.0:
		stats.attack_range *= (1.0 + float(stat_map["range"]))
	# 闪避率加成
	if stat_map.has("dodge") and float(stat_map["dodge"]) != 0.0:
		stats.dodge_chance = clampf(stats.dodge_chance + float(stat_map["dodge"]), 0.0, 0.75)
	# 暴击率加成
	if stat_map.has("crit") and float(stat_map["crit"]) != 0.0:
		stats.crit_chance = clampf(stats.crit_chance + float(stat_map["crit"]), 0.0, 0.95)
	# 命中率加成（映射到 faction_accuracy_bonus）
	if stat_map.has("accuracy") and float(stat_map["accuracy"]) != 0.0:
		stats.faction_accuracy_bonus = clampf(stats.faction_accuracy_bonus + float(stat_map["accuracy"]), 0.0, 1.0)
	# 生命恢复加成
	if stat_map.has("hp_regen") and float(stat_map["hp_regen"]) != 0.0:
		stats.hp_regen = stats.hp_regen + float(stat_map["hp_regen"])
	# 伤害减免加成
	if stat_map.has("damage_reduction") and float(stat_map["damage_reduction"]) != 0.0:
		stats.damage_reduction = clampf(stats.damage_reduction + float(stat_map["damage_reduction"]), 0.0, 0.8)
	# 注：特殊效果已在函数开头写入 meta，此处无需重复

func _get_autoload_node(name: String) -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var tree: SceneTree = loop as SceneTree
		if tree.root != null:
			return tree.root.get_node_or_null(name)
	return null


