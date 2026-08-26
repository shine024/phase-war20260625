extends RefCounted
class_name CardAbilityManager
## 卡牌特殊能力集中处理器。
## 所有函数为 static，由 bullet._on_hit 和 construct_unit 调用。

static var _aura_data: RefCounted = null
static var _construct_unit_scene: PackedScene = null

static func _get_aura_data() -> RefCounted:
	if _aura_data == null:
		_aura_data = load("res://data/aura_data.gd") as RefCounted
	return _aura_data

# ── 工具函数 ─────────────────────────────────

## 临时修改 stats.move_speed，duration 秒后恢复
static func _apply_temp_speed_scale(unit: Node2D, scale: float, duration: float) -> void:
	if unit == null or not ("stats" in unit) or unit.stats == null:
		return
	var old_speed: float = unit.stats.move_speed
	unit.stats.move_speed = old_speed * scale
	var dur: float = maxf(0.1, duration)
	Engine.get_main_loop().create_timer(dur).timeout.connect(Callable(CardAbilityManager, "_on_temp_speed_timeout").bind(unit, old_speed))

## 临时修改 stats.attack_interval（haste），duration 秒后恢复
static func _apply_temp_attack_haste(unit: Node2D, haste_ratio: float, duration: float) -> void:
	if unit == null or not ("stats" in unit) or unit.stats == null:
		return
	var old_interval: float = unit.stats.attack_interval
	unit.stats.attack_interval = maxf(0.1, old_interval * (1.0 - haste_ratio))
	var dur: float = maxf(0.1, duration)
	Engine.get_main_loop().create_timer(dur).timeout.connect(Callable(CardAbilityManager, "_on_temp_haste_timeout").bind(unit, old_interval))


static func has_platform_card(pid: String, card_id: String) -> bool:
	return pid == card_id

## 战斗中优先用 BattleManager.spatial_grid，避免 get_nodes_in_group 全表扫描。
static func _try_get_spatial_grid(origin: Node2D) -> Node:
	var tree: SceneTree = null
	if origin != null and is_instance_valid(origin) and origin.is_inside_tree():
		tree = origin.get_tree()
	elif Engine.get_main_loop() is SceneTree:
		tree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var bm: Node = tree.root.get_node_or_null("BattleManager")
	if bm == null or not is_instance_valid(bm):
		return null
	if bm.get("battle_active") != true:
		return null
	var grid: Variant = bm.get("spatial_grid")
	if grid == null or not is_instance_valid(grid):
		return null
	return grid as Node

static func _get_nearby_units(origin: Node2D, radius: float, target_group: String) -> Array:
	var units: Array = []
	if origin == null or not is_instance_valid(origin):
		return units
	var grid: Node = _try_get_spatial_grid(origin)
	if grid != null and grid.has_method("query_nearby"):
		var nearby: Array = grid.query_nearby(origin.global_position, radius)
		for node in nearby:
			if not is_instance_valid(node) or node == origin:
				continue
			if not (node is Node2D):
				continue
			if not node.is_in_group(target_group):
				continue
			units.append(node)
		return units
	var tree: SceneTree = origin.get_tree()
	if tree == null:
		return units
	var nodes: Array = []
	var bm: Node = tree.root.get_node_or_null("BattleManager")
	if bm != null and is_instance_valid(bm) and bm.has_method("get_cached_nodes_in_group"):
		var active: bool = bool(bm.get("battle_active")) if "battle_active" in bm else false
		if active:
			nodes = bm.get_cached_nodes_in_group(target_group)
	if nodes.is_empty():
		nodes = tree.get_nodes_in_group(target_group)
	for node in nodes:
		if not is_instance_valid(node) or node == origin:
			continue
		if not node is Node2D:
			continue
		if origin.global_position.distance_to(node.global_position) <= radius:
			units.append(node)
	return units

static func _get_nearby_enemies(origin: Node2D, radius: float, is_player_unit: bool) -> Array:
	var group_name: String = "enemy_units" if is_player_unit else "player_units"
	return _get_nearby_units(origin, radius, group_name)

static func _get_nearby_allies(origin: Node2D, radius: float, is_player_unit: bool) -> Array:
	# v6.2: 所有光环均影响全体我方单位，忽略距离限制（radius 参数保留以兼容现有调用）
	# 光环不再受像素距离/槽位距离限制，只要是在场的同阵营单位都受影响
	var group_name: String = "player_units" if is_player_unit else "enemy_units"
	return _get_all_units_in_group(origin, group_name)

## 获取某阵营在场全部单位（不含 origin 自身）
static func _get_all_units_in_group(origin: Node2D, target_group: String) -> Array:
	var units: Array = []
	if origin == null or not is_instance_valid(origin):
		return units
	# origin 可能尚未加入场景树（setup 阶段被 AuraManager 调用）；
	# is_inside_tree 守卫避免 get_tree() 触发 C++ "data.tree is null" 断言。
	if not origin.is_inside_tree():
		return units
	var tree: SceneTree = origin.get_tree()
	if tree == null:
		return units
	var nodes: Array = []
	var bm: Node = tree.root.get_node_or_null("BattleManager")
	if bm != null and is_instance_valid(bm) and bm.has_method("get_cached_nodes_in_group"):
		var active: bool = bool(bm.get("battle_active")) if "battle_active" in bm else false
		if active:
			nodes = bm.get_cached_nodes_in_group(target_group)
	if nodes.is_empty():
		nodes = tree.get_nodes_in_group(target_group)
	for node in nodes:
		if not is_instance_valid(node) or node == origin:
			continue
		if not node is Node2D:
			continue
		units.append(node)
	return units

# ── 部署时属性修改 ─────────────────────────

static func apply_deploy_stat_modifiers(stats: UnitStats) -> void:
	if stats == null:
		return
	# abrams_mk2：伤害减免+20%
	if has_platform_card(stats.platform_card_id, "abrams_mk2"):
		stats.damage_reduction = minf(0.75, stats.damage_reduction + 0.20)

# ── 部署时初始化（单位成型后调用一次）─────────────

static func on_unit_materialized(unit: Node) -> void:
	if unit == null or not ("stats" in unit) or unit.stats == null:
		return
	var stats: UnitStats = unit.stats
	apply_deploy_stat_modifiers(stats)
	# titan_mk2：记录部署时间
	if has_platform_card(stats.platform_card_id, "titan_mk2"):
		unit.set_meta("titan_mk2_deploy_time", Time.get_ticks_msec() / 1000.0)
	# heavy_carrier：生成2个僚机
	if has_platform_card(stats.platform_card_id, "heavy_carrier"):
		_spawn_wingman(unit, stats)
		_spawn_wingman(unit, stats)

# ── 子弹命中前（修改伤害）───────────────────────

## 返回 { damage_bonus: float, damage_mult_bonus: float }
# P1 性能优化：静态空结果，避免每次命中都分配新 Dictionary
const _EMPTY_HIT_RESULT: Dictionary = {"damage_bonus": 0.0, "damage_mult_bonus": 0.0}

static func on_bullet_hit(
	shooter: Node2D, target: Node2D, shooter_stats: UnitStats,
	_hit_pos: Vector2, _base_damage: float, _final_damage: float, _is_player: bool
) -> Dictionary:
	if shooter_stats == null:
		return _EMPTY_HIT_RESULT
	# P1 性能优化：当前无命中前伤害修改能力，复用静态空字典避免每次命中分配
	return _EMPTY_HIT_RESULT

# ── 子弹命中后（施加效果）───────────────────────

static func on_bullet_hit_post(
	shooter: Node2D, target: Node2D, shooter_stats: UnitStats,
	hit_pos: Vector2, final_damage: float, is_player: bool
) -> void:
	if shooter_stats == null:
		return

# ── 平台：受伤修改 ─────────────────────────────

## bulwark：正面受击减伤 40%（静止 55%）。返回伤害乘数。
static func get_bulwark_damage_multiplier(unit: Node2D, attacker: Variant) -> float:
	if unit == null or attacker == null or not (attacker is Node2D):
		return 1.0
	var is_player: bool = unit.is_player if "is_player" in unit else true
	var facing_dir: float = 1.0 if is_player else -1.0
	var to_attacker: Vector2 = (attacker.global_position - unit.global_position).normalized()
	var dot: float = to_attacker.x * facing_dir
	if dot <= 0.0:
		return 1.0  # 背面/侧面：不减免
	var is_stationary: bool = false
	if "stats" in unit and unit.stats != null:
		is_stationary = unit.stats.is_stationary
	return 0.45 if is_stationary else 0.6

## titan_mk2：固定减伤 3（最低 1）
static func apply_titan_mk2_damage_reduction(amount: float) -> float:
	return maxf(1.0, amount - 3.0)

## titan_mk2：存活 12 秒后输出 +25%。返回伤害乘数。
static func get_titan_mk2_damage_multiplier(unit: Node2D) -> float:
	if unit == null or not unit.has_meta("titan_mk2_deploy_time"):
		return 1.0
	var deploy_time: float = float(unit.get_meta("titan_mk2_deploy_time"))
	if (Time.get_ticks_msec() / 1000.0 - deploy_time) >= 12.0:
		return 1.25
	return 1.0

# ── 平台：攻击修改 ─────────────────────────────

## storm_rider：危险区域（靠近敌人）时 +20% 伤害。返回伤害乘数。
static func get_storm_rider_damage_multiplier(unit: Node2D) -> float:
	if unit == null:
		return 1.0
	var is_player: bool = unit.is_player if "is_player" in unit else true
	if _get_nearby_enemies(unit, 150.0, is_player).size() > 0:
		return 1.2
	return 1.0

# ── 平台：每帧效果 ─────────────────────────────

## regen_frame：脱战回复 8 HP/s
static func apply_regen_frame_regen(unit: Node2D, delta: float) -> float:
	if unit == null or not ("target" in unit) or not ("hp" in unit) or not ("stats" in unit):
		return 0.0
	if unit.target != null and is_instance_valid(unit.target):
		return 0.0
	if unit.hp >= unit.stats.max_hp:
		return 0.0
	var heal: float = 8.0 * delta
	unit.hp = min(unit.hp + heal, unit.stats.max_hp)
	return heal

## abrams_mk2：脱战回复 5% 最大 HP/s
static func apply_abrams_mk2_regen(unit: Node2D, delta: float) -> float:
	if unit == null or not ("target" in unit) or not ("hp" in unit) or not ("stats" in unit):
		return 0.0
	if unit.target != null and is_instance_valid(unit.target):
		return 0.0
	if unit.hp >= unit.stats.max_hp:
		return 0.0
	var heal: float = unit.stats.max_hp * 0.05 * delta
	unit.hp = min(unit.hp + heal, unit.stats.max_hp)
	return heal

## storm_rider：危险区域时 +30% 移速（0.5 秒冷却避免 Timer 堆积）
static func apply_storm_rider_speed(unit: Node2D, delta: float) -> void:
	if unit == null:
		return
	var cd: float = unit._storm_rider_cd - delta
	unit._storm_rider_cd = cd
	if cd > 0.0:
		return
	unit._storm_rider_cd = 0.5
	var is_player: bool = unit.is_player if "is_player" in unit else true
	if _get_nearby_enemies(unit, 150.0, is_player).size() > 0:
		_apply_temp_speed_scale(unit, 1.3, 0.6)

## drop_repair_fortress：每 4 秒治疗 150 范围内友军 5% 最大 HP
static func apply_repair_fortress_heal(unit: Node2D, delta: float) -> void:
	if unit == null or not ("stats" in unit) or unit.stats == null:
		return
	var cd: float = unit._repair_fortress_cd - delta
	unit._repair_fortress_cd = cd
	if cd > 0.0:
		return
	unit._repair_fortress_cd = 4.0
	var is_player: bool = unit.is_player if "is_player" in unit else true
	var allies: Array = _get_nearby_allies(unit, 150.0, is_player)
	# 也治疗自身
	allies.append(unit)
	for ally in allies:
		if not is_instance_valid(ally):
			continue
		var ally_max_hp: float = 100.0
		if "stats" in ally and ally.stats != null:
			ally_max_hp = ally.stats.max_hp
		elif "max_hp" in ally:
			ally_max_hp = float(ally.max_hp)
		# v6.2 性能优化：跳过已满血的单位
		var ally_current_hp: float = float(ally.hp) if "hp" in ally else ally_max_hp
		if ally_current_hp >= ally_max_hp - 0.01:
			continue
		var heal_amount: float = ally_max_hp * 0.05
		if ally.has_method("heal"):
			ally.heal(heal_amount)
		elif "hp" in ally:
			ally.hp = min(ally.hp + heal_amount, ally_max_hp)

# ── 僚机系统（heavy_carrier）──────────────────

static func _spawn_wingman(carrier: Node2D, parent_stats: UnitStats) -> void:
	if carrier == null or parent_stats == null:
		return
	if _construct_unit_scene == null:
		_construct_unit_scene = load("res://scenes/units/construct_unit.tscn") as PackedScene
	var scene: PackedScene = _construct_unit_scene
	if scene == null:
		return
	var wingman_stats = UnitStats.new()
	wingman_stats.max_hp = parent_stats.max_hp * 0.25
	wingman_stats.move_speed = parent_stats.move_speed * 1.2
	wingman_stats.attack_damage = parent_stats.attack_damage * 0.3
	wingman_stats.attack_range = parent_stats.attack_range * 0.8
	wingman_stats.attack_interval = parent_stats.attack_interval
	wingman_stats.is_stationary = false
	wingman_stats.platform_type = parent_stats.platform_type  # @deprecated 存档兼容
	wingman_stats.weapon_type = parent_stats.weapon_type  # 新 WeaponTypeNew 枚举
	# v3: 也应该复制 combat_kind
	wingman_stats.combat_kind = parent_stats.combat_kind
	var wingman = scene.instantiate()
	wingman.setup(carrier.is_player if "is_player" in carrier else true, wingman_stats)
	wingman.set_meta("is_wingman", true)
	wingman.set_meta("wingman_parent", carrier)
	wingman.scale = Vector2(0.6, 0.6)
	carrier.add_child(wingman)
	wingman.global_position = carrier.global_position + Vector2(0, 15)

static func schedule_wingman_respawn(wingman: Node2D) -> void:
	if wingman == null or not wingman.has_meta("wingman_parent"):
		return
	var parent: Variant = wingman.get_meta("wingman_parent")
	if parent == null or not is_instance_valid(parent):
		return
	var carrier: Node2D = parent as Node2D
	var parent_stats: UnitStats = carrier.stats if "stats" in carrier else null
	Engine.get_main_loop().create_timer(12.0).timeout.connect(Callable(CardAbilityManager, "_on_wingman_respawn_timeout").bind(carrier, parent_stats))

static func _on_temp_speed_timeout(captured: Node2D, captured_old: float) -> void:
	if is_instance_valid(captured) and "stats" in captured and captured.stats != null:
		captured.stats.move_speed = captured_old

static func _on_temp_haste_timeout(captured: Node2D, captured_old: float) -> void:
	if is_instance_valid(captured) and "stats" in captured and captured.stats != null:
		captured.stats.attack_interval = captured_old

static func _on_wingman_respawn_timeout(captured_carrier: Node2D, captured_stats: UnitStats) -> void:
	if is_instance_valid(captured_carrier) and captured_stats != null:
		_spawn_wingman(captured_carrier, captured_stats)

# ── 平台光环系统（基于 platform_type，每帧调用）────────────────────

## MEDIC 维修光环：每 3 秒治疗 180 范围内所有友军 8% 最大 HP（CD 由调用方用成员变量驱动时可改用 tick 版本）
static func apply_medic_heal_aura(unit: Node2D, delta: float) -> void:
	if unit == null or not ("stats" in unit) or unit.stats == null:
		return
	var cd: float = unit._medic_aura_cd - delta
	unit._medic_aura_cd = cd
	if cd > 0.0:
		return
	unit._medic_aura_cd = 3.0
	apply_medic_heal_aura_tick(unit)


## MEDIC 单次治疗脉冲（无 CD 逻辑；由 construct_unit._medic_aura_cd 等节流）
static func apply_medic_heal_aura_tick(unit: Node2D) -> void:
	if unit == null or not ("stats" in unit) or unit.stats == null:
		return
	var is_player: bool = unit.is_player if "is_player" in unit else true
	var star: int = _get_unit_star(unit)
	var params: Dictionary = _get_aura_data().get_aura_params(_get_aura_data().Category.MEDIC_HEAL, star)
	var heal_pct: float = float(params.get("heal_pct", 0.08))
	var allies: Array = _get_nearby_allies(unit, 180.0, is_player)
	allies.append(unit)  # 也治疗自身
	for ally in allies:
		if not is_instance_valid(ally):
			continue
		var ally_max_hp: float = 100.0
		if "stats" in ally and ally.stats != null:
			ally_max_hp = ally.stats.max_hp
		elif "max_hp" in ally:
			ally_max_hp = float(ally.max_hp)
		# v6.2 性能优化：跳过已满血的单位，避免无效治疗调用
		var ally_current_hp: float = float(ally.hp) if "hp" in ally else ally_max_hp
		if ally_current_hp >= ally_max_hp - 0.01:
			continue
		var heal_amount: float = ally_max_hp * heal_pct
		if ally.has_method("heal"):
			ally.heal(heal_amount)
		elif "hp" in ally:
			ally.hp = min(ally.hp + heal_amount, ally_max_hp)

## RADAR 雷达光环：射程加成（按槽位判定范围）
static func apply_radar_range_aura(unit: Node2D, delta: float, replay := false) -> void:
	if unit == null or not ("stats" in unit) or unit.stats == null:
		return
	# 用 meta 标记避免重复施加（replay=true 供后入场补偿：源已标记，只补未受 buff 的友军）
	if unit.has_meta("radar_aura_applied"):
		if not replay:
			return
	else:
		unit.set_meta("radar_aura_applied", true)
	var is_player: bool = unit.is_player if "is_player" in unit else true
	var star: int = _get_unit_star(unit)
	var params: Dictionary = _get_aura_data().get_aura_params(_get_aura_data().Category.RADAR_RANGE, star)
	var crit_bonus: float = float(params.get("crit_bonus", 0.05))
	var allies: Array = _get_nearby_allies(unit, 180.0, is_player)
	for ally in allies:
		if not is_instance_valid(ally) or ally == unit:
			continue
		if not ("stats" in ally) or ally.stats == null:
			continue
		if not ally.has_meta("radar_buffed"):
			ally.set_meta("radar_buffed", true)
			ally.set_meta("radar_orig_crit", ally.stats.crit_chance)
			ally.stats.crit_chance = clampf(ally.stats.crit_chance + crit_bonus, 0.0, 1.0)

## RADAR 光环清理：单位死亡时恢复友军暴击率
static func remove_radar_range_aura(unit: Node2D) -> void:
	if unit == null:
		return
	if not unit.has_meta("radar_aura_applied"):
		return
	var is_player: bool = unit.is_player if "is_player" in unit else true
	var allies: Array = _get_nearby_allies(unit, 300.0, is_player)
	for ally in allies:
		if not is_instance_valid(ally) or ally == unit:
			continue
		if ally.has_meta("radar_buffed"):
			var orig_crit: float = float(ally.get_meta("radar_orig_crit"))
			if "stats" in ally and ally.stats != null:
				ally.stats.crit_chance = orig_crit
			ally.remove_meta("radar_buffed")
			ally.remove_meta("radar_orig_crit")

## SCOUT/STEALTH 侦查光环：暴击+命中（按槽位判定范围）
static func apply_scout_crit_aura(unit: Node2D, delta: float, replay := false) -> void:
	if unit == null or not ("stats" in unit) or unit.stats == null:
		return
	if unit.has_meta("scout_aura_applied"):
		if not replay:
			return
	else:
		unit.set_meta("scout_aura_applied", true)
	var is_player: bool = unit.is_player if "is_player" in unit else true
	var star: int = _get_unit_star(unit)
	var params: Dictionary = _get_aura_data().get_aura_params(_get_aura_data().Category.SCOUT_CRIT, star)
	var crit_bonus: float = float(params.get("crit_bonus", 0.08))
	var allies: Array = _get_nearby_allies(unit, 150.0, is_player)
	for ally in allies:
		if not is_instance_valid(ally) or ally == unit:
			continue
		if not ("stats" in ally) or ally.stats == null:
			continue
		if not ally.has_meta("scout_crit_buffed"):
			ally.set_meta("scout_crit_buffed", true)
			ally.set_meta("scout_orig_crit", ally.stats.crit_chance)
			ally.stats.crit_chance = min(1.0, ally.stats.crit_chance + crit_bonus)

## SCOUT 光环清理
static func remove_scout_crit_aura(unit: Node2D) -> void:
	if unit == null:
		return
	if not unit.has_meta("scout_aura_applied"):
		return
	var is_player: bool = unit.is_player if "is_player" in unit else true
	var allies: Array = _get_nearby_allies(unit, 300.0, is_player)
	for ally in allies:
		if not is_instance_valid(ally) or ally == unit:
			continue
		if ally.has_meta("scout_crit_buffed"):
			var orig_crit: float = float(ally.get_meta("scout_orig_crit"))
			if "stats" in ally and ally.stats != null:
				ally.stats.crit_chance = orig_crit
			ally.remove_meta("scout_crit_buffed")
			ally.remove_meta("scout_orig_crit")

## FORTRESS 堡垒光环：减伤+防御（按槽位判定范围）
static func apply_fortress_defense_aura(unit: Node2D, delta: float, replay := false) -> void:
	if unit == null or not ("stats" in unit) or unit.stats == null:
		return
	if unit.has_meta("fortress_aura_applied"):
		if not replay:
			return
	else:
		unit.set_meta("fortress_aura_applied", true)
	var is_player: bool = unit.is_player if "is_player" in unit else true
	var star: int = _get_unit_star(unit)
	var params: Dictionary = _get_aura_data().get_aura_params(_get_aura_data().Category.FORTRESS_DEF, star)
	var dr_bonus: float = float(params.get("damage_reduction_bonus", 0.06))
	var def_bonus: float = float(params.get("defense_bonus", 2.0))
	var allies: Array = _get_nearby_allies(unit, 200.0, is_player)
	for ally in allies:
		if not is_instance_valid(ally) or ally == unit:
			continue
		if not ("stats" in ally) or ally.stats == null:
			continue
		if not ally.has_meta("fortress_def_buffed"):
			ally.set_meta("fortress_def_buffed", true)
			ally.set_meta("fortress_orig_dr", ally.stats.damage_reduction)
			ally.set_meta("fortress_orig_def", ally.stats.defense)
			ally.stats.damage_reduction = min(0.75, ally.stats.damage_reduction + dr_bonus)
			ally.stats.defense += def_bonus

## FORTRESS 光环清理
static func remove_fortress_defense_aura(unit: Node2D) -> void:
	if unit == null:
		return
	if not unit.has_meta("fortress_aura_applied"):
		return
	var is_player: bool = unit.is_player if "is_player" in unit else true
	var allies: Array = _get_nearby_allies(unit, 300.0, is_player)
	for ally in allies:
		if not is_instance_valid(ally) or ally == unit:
			continue
		if ally.has_meta("fortress_def_buffed"):
			var orig_dr: float = float(ally.get_meta("fortress_orig_dr"))
			var orig_def: float = float(ally.get_meta("fortress_orig_def", ally.stats.defense if "stats" in ally and ally.stats != null else 0.0))
			if "stats" in ally and ally.stats != null:
				ally.stats.damage_reduction = orig_dr
				ally.stats.defense = orig_def
			ally.remove_meta("fortress_def_buffed")
			ally.remove_meta("fortress_orig_dr")
			if ally.has_meta("fortress_orig_def"):
				ally.remove_meta("fortress_orig_def")


## CARRIER_REPAIR 维修光环：仅治疗机械类平台（由 AuraManager Timer 周期驱动）
static func apply_carrier_repair_aura_tick(unit: Node2D) -> void:
	if unit == null or not ("stats" in unit) or unit.stats == null:
		return
	var is_player: bool = unit.is_player if "is_player" in unit else true
	var star: int = _get_unit_star(unit)
	var params: Dictionary = _get_aura_data().get_aura_params(_get_aura_data().Category.CARRIER_REPAIR, star)
	var heal_pct: float = float(params.get("heal_pct", 0.12))
	var allies: Array = _get_nearby_allies(unit, 180.0, is_player)
	for ally in allies:
		if not is_instance_valid(ally):
			continue
		if not ("stats" in ally) or ally.stats == null:
			continue
		if not _get_aura_data().is_mechanical_ally(ally):
			continue
		var heal_amount: float = ally.stats.max_hp * heal_pct
		if not ally.has_meta("carrier_repair_buffed"):
			ally.set_meta("carrier_repair_buffed", true)
		if ally.has_method("heal"):
			ally.heal(heal_amount)
		elif "hp" in ally:
			ally.hp = min(ally.hp + heal_amount, ally.stats.max_hp)

## COMMAND_GLOBAL 指挥光环：全场友军攻/速/暴加成
static func apply_command_global_aura(unit: Node2D, replay := false) -> void:
	if unit == null or not ("stats" in unit) or unit.stats == null:
		return
	if unit.has_meta("command_aura_applied"):
		if not replay:
			return
	else:
		unit.set_meta("command_aura_applied", true)
	var is_player: bool = unit.is_player if "is_player" in unit else true
	var star: int = _get_unit_star(unit)
	var params: Dictionary = _get_aura_data().get_aura_params(_get_aura_data().Category.COMMAND_GLOBAL, star)
	var atk_mul: float = float(params.get("attack_mul", 0.05))
	var spd_mul: float = float(params.get("speed_mul", 0.05))
	var crit_mul: float = float(params.get("crit_mul", 0.02))
	var allies: Array = _get_nearby_allies(unit, 99999.0, is_player)
	for ally in allies:
		if not is_instance_valid(ally) or ally == unit:
			continue
		if not ("stats" in ally) or ally.stats == null:
			continue
		if not ally.has_meta("command_buffed"):
			ally.set_meta("command_buffed", true)
			ally.set_meta("command_orig_atk", ally.stats.attack_damage)
			ally.set_meta("command_orig_spd", ally.stats.move_speed)
			ally.set_meta("command_orig_crit", ally.stats.crit_chance)
			ally.stats.attack_damage *= (1.0 + atk_mul)
			ally.stats.move_speed *= (1.0 + spd_mul)
			ally.stats.crit_chance = min(1.0, ally.stats.crit_chance + crit_mul)

## COMMAND 光环清理：死亡时恢复友军属性
static func remove_command_global_aura(unit: Node2D) -> void:
	if unit == null:
		return
	if not unit.has_meta("command_aura_applied"):
		return
	var is_player: bool = unit.is_player if "is_player" in unit else true
	var allies: Array = _get_nearby_allies(unit, 99999.0, is_player)
	for ally in allies:
		if not is_instance_valid(ally) or ally == unit:
			continue
		if ally.has_meta("command_buffed"):
			var orig_atk: float = float(ally.get_meta("command_orig_atk"))
			var orig_spd: float = float(ally.get_meta("command_orig_spd"))
			var orig_crit: float = float(ally.get_meta("command_orig_crit"))
			if "stats" in ally and ally.stats != null:
				ally.stats.attack_damage = orig_atk
				ally.stats.move_speed = orig_spd
				ally.stats.crit_chance = orig_crit
			ally.remove_meta("command_buffed")
			ally.remove_meta("command_orig_atk")
			ally.remove_meta("command_orig_spd")
			ally.remove_meta("command_orig_crit")
	unit.remove_meta("command_aura_applied")

## 获取单位星级（优先读 meta 缓存，其次查 BlueprintManager）
static func _get_unit_star(unit: Node2D) -> int:
	if unit == null:
		return 1
	if unit.has_meta("enhance_level"):
		return int(unit.get_meta("enhance_level"))
	# v20.12 等级统一：优先读 stats.card_level（战斗卡等级 1-30），÷3 换算 1-10 星
	if "stats" in unit and unit.stats != null and "card_level" in unit.stats and int(unit.stats.card_level) > 0:
		var star_lv: int = clampi(int(round(float(int(unit.stats.card_level)) / 3.0)), 1, 10)
		unit.set_meta("enhance_level", star_lv)
		return star_lv
	# 过渡回退：旧 CardEnhancementManager 查询链（强化①退役后恒 0/1）
	if "stats" in unit and unit.stats != null and not unit.stats.platform_card_id.is_empty():
		var loop = Engine.get_main_loop()
		if loop is SceneTree:
			var cem: Node = (loop as SceneTree).root.get_node_or_null("CardEnhancementManager")
			if cem and cem.has_method("get_card_enhancement_level"):
				var lvl: int = int(cem.get_card_enhancement_level(unit.stats.platform_card_id))
				unit.set_meta("enhance_level", lvl)
				return lvl
	unit.set_meta("enhance_level", 1)
	return 1


# ════════════════════════════════════════════════════════════════════════
#  v20.14 兵种特殊机制
# ════════════════════════════════════════════════════════════════════════

## ── 隐身飞机（stealth_aircraft）：周期性隐身 ──────────────────────

## 每 8 秒自动进入隐身状态（闪避+40%，移速+20%），持续 4 秒或被攻击命中后提前解除。
## 由 construct_unit._physics_process 每帧调用。
static func update_stealth_periodic(unit: Node2D, delta: float) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if not _has_tag(unit, "stealth_aircraft"):
		return
	# 初始化 meta
	if not unit.has_meta("_stealth_cd"):
		unit.set_meta("_stealth_cd", 8.0)
		unit.set_meta("_stealth_active", false)
		unit.set_meta("_stealth_duration", 0.0)
		unit.set_meta("_stealth_base_modulate", unit.modulate)

	var stealth_active: bool = bool(unit.get_meta("_stealth_active"))
	var stealth_dur: float = float(unit.get_meta("_stealth_duration"))
	var stealth_cd: float = float(unit.get_meta("_stealth_cd"))

	if stealth_active:
		stealth_dur -= delta
		unit.set_meta("_stealth_duration", stealth_dur)
		if stealth_dur <= 0.0:
			_exit_stealth(unit)
		return

	# 冷却中
	stealth_cd -= delta
	unit.set_meta("_stealth_cd", stealth_cd)
	if stealth_cd <= 0.0:
		_enter_stealth(unit)

## 进入隐身状态
static func _enter_stealth(unit: Node2D) -> void:
	unit.set_meta("_stealth_active", true)
	unit.set_meta("_stealth_duration", 4.0)
	unit.set_meta("_stealth_cd", 0.0)
	# 视觉：半透明
	unit.set_meta("_stealth_base_modulate", unit.modulate)
	unit.modulate = Color(unit.modulate.r, unit.modulate.g, unit.modulate.b, 0.4)
	# 闪避 +40%
	if "stats" in unit and unit.stats != null:
		if not unit.has_meta("_stealth_orig_dodge"):
			unit.set_meta("_stealth_orig_dodge", unit.stats.dodge_chance)
		unit.stats.dodge_chance = min(1.0, unit.stats.dodge_chance + 0.40)
	# 移速 +20%
	if "stats" in unit and unit.stats != null:
		if not unit.has_meta("_stealth_orig_speed"):
			unit.set_meta("_stealth_orig_speed", unit.stats.move_speed)
		unit.stats.move_speed *= 1.20

## 退出隐身状态
static func _exit_stealth(unit: Node2D) -> void:
	unit.set_meta("_stealth_active", false)
	unit.set_meta("_stealth_duration", 0.0)
	unit.set_meta("_stealth_cd", 8.0)
	# 恢复视觉
	if unit.has_meta("_stealth_base_modulate"):
		unit.modulate = unit.get_meta("_stealth_base_modulate")
	# 恢复闪避
	if unit.has_meta("_stealth_orig_dodge") and "stats" in unit and unit.stats != null:
		unit.stats.dodge_chance = float(unit.get_meta("_stealth_orig_dodge"))
		unit.remove_meta("_stealth_orig_dodge")
	# 恢复移速
	if unit.has_meta("_stealth_orig_speed") and "stats" in unit and unit.stats != null:
		unit.stats.move_speed = float(unit.get_meta("_stealth_orig_speed"))
		unit.remove_meta("_stealth_orig_speed")

## 隐身飞机被命中时强制退出隐身
static func on_stealth_hit(unit: Node2D) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if not _has_tag(unit, "stealth_aircraft"):
		return
	if unit.has_meta("_stealth_active") and bool(unit.get_meta("_stealth_active")):
		_exit_stealth(unit)

## ── 隐身飞机（stealth_aircraft）：首击爆发 ──────────────────────

## 隐身状态下攻击 → 必定暴击 + 伤害 ×1.5。返回伤害乘数。
static func get_stealth_first_strike_multiplier(unit: Node2D) -> float:
	if unit == null or not is_instance_valid(unit):
		return 1.0
	if not _has_tag(unit, "stealth_aircraft"):
		return 1.0
	if unit.has_meta("_stealth_active") and bool(unit.get_meta("_stealth_active")):
		return 1.50
	return 1.0

## 隐身首击是否必定暴击
static func is_stealth_first_strike_crit(unit: Node2D) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false
	if not _has_tag(unit, "stealth_aircraft"):
		return false
	return unit.has_meta("_stealth_active") and bool(unit.get_meta("_stealth_active"))

## ── 攻击无人机（attack_drone）：自动标记集火 ──────────────────────

## 每 12 秒自动标记半径 400 内最高威胁的 2 个敌方，+25% 易伤 8 秒。
## 由 construct_unit._physics_process 每帧调用。
static func update_drone_auto_mark(unit: Node2D, delta: float) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if not _has_tag(unit, "attack_drone"):
		return
	if not unit.has_meta("_drone_mark_cd"):
		unit.set_meta("_drone_mark_cd", 12.0)

	var cd: float = float(unit.get_meta("_drone_mark_cd"))
	cd -= delta
	unit.set_meta("_drone_mark_cd", cd)
	if cd > 0.0:
		return
	unit.set_meta("_drone_mark_cd", 12.0)

	# 扫描敌方单位
	var is_player: bool = unit.is_player if "is_player" in unit else true
	var enemies: Array = _get_all_units_in_group(unit, "enemy_units" if is_player else "player_units")
	if enemies.is_empty():
		return

	# 按威胁排序（HP 最高优先）
	enemies.sort_custom(func(a, b):
		var hp_a: float = float(a.hp) if "hp" in a else 0.0
		var hp_b: float = float(b.hp) if "hp" in b else 0.0
		return hp_a > hp_b
	)

	# 标记前 2 个（在半径 400 内）
	var marked_count := 0
	var target_positions: Array = []
	var now_ms: int = Time.get_ticks_msec()
	for enemy in enemies:
		if marked_count >= 2:
			break
		if not is_instance_valid(enemy):
			continue
		if unit.global_position.distance_to(enemy.global_position) > 400.0:
			continue
		# 挂标记（兼容现有 _drone_marked_until 格式，bullet.gd:1258 已消费）
		enemy.set_meta("_drone_marked_until", now_ms + 8000)  # 8 秒后过期
		enemy.set_meta("_drone_mark_vuln", 0.25)  # +25% 易伤
		target_positions.append(enemy.global_position)
		marked_count += 1

	# 演出信号
	if target_positions.size() > 0:
		var sb: Node = _get_signal_bus()
		if sb != null and sb.has_signal("mechanism_drone_marked"):
			sb.mechanism_drone_marked.emit(unit.global_position, target_positions)

## 无人机标记过期清理（每帧由 construct_unit 调用，清过期 _drone_marked_until）
static func update_drone_mark_expiry(_delta: float) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var now_ms: int = Time.get_ticks_msec()
	var enemies: Array = tree.get_nodes_in_group("enemy_units")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.has_meta("_drone_marked_until"):
			var until: int = int(enemy.get_meta("_drone_marked_until", 0))
			if now_ms >= until:
				enemy.remove_meta("_drone_marked_until")
				enemy.remove_meta("_drone_mark_vuln")

## 无人机标记易伤：被标记目标受到额外伤害乘数（兼容 _drone_marked_until 格式）
static func get_drone_mark_vuln_multiplier(target: Node2D) -> float:
	if target == null or not is_instance_valid(target):
		return 1.0
	if target.has_meta("_drone_marked_until"):
		var until: int = int(target.get_meta("_drone_marked_until", 0))
		if Time.get_ticks_msec() < until:
			var vuln: float = float(target.get_meta("_drone_mark_vuln", 0.25))
			return 1.0 + vuln
	return 1.0

## ── 攻击无人机（attack_drone）：全图攻击距离衰减 ──────────────────

## 返回距离衰减系数：近距离 100% → 中距离 75% → 远距离 50%
const DRONE_RANGE_FULL_DMG: float = 300.0   # 300px 内满伤害
const DRONE_RANGE_MID_DMG: float = 600.0    # 300-600px 75%
const DRONE_RANGE_FAR_DMG: float = 1200.0   # 600-1200px 50%，之外 40%

static func get_drone_range_damage_multiplier(unit: Node2D, target: Node2D) -> float:
	if unit == null or target == null or not is_instance_valid(unit) or not is_instance_valid(target):
		return 1.0
	if not _has_tag(unit, "attack_drone"):
		return 1.0
	var dist: float = unit.global_position.distance_to(target.global_position)
	if dist <= DRONE_RANGE_FULL_DMG:
		return 1.0
	elif dist <= DRONE_RANGE_MID_DMG:
		return 0.75
	elif dist <= DRONE_RANGE_FAR_DMG:
		return 0.50
	else:
		return 0.40

## ── 维修车（repair_vehicle）：装甲单位死亡保护 ──────────────────────

## 维修车在场时，装甲类（combat_kind=1）单位死亡有 50% 概率不消耗部署次数。
const REPAIR_ARMOR_SAVE_CHANCE: float = 0.50

## 判断是否有维修车在场
static func has_repair_vehicle_on_field(is_player: bool) -> bool:
	var group_name: String = "player_units" if is_player else "enemy_units"
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	var nodes: Array = tree.get_nodes_in_group(group_name)
	for node in nodes:
		if not is_instance_valid(node):
			continue
		if _has_tag(node, "repair_vehicle"):
			# 确保不是正在死亡
			if "_is_dying" in node and node._is_dying:
				continue
			return true
	return false

## 装甲单位死亡时调用：返回 true 表示不消耗部署次数
static func on_armor_unit_dying(unit: Node2D) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false
	# 检查是否为装甲类
	var ck: int = 0
	if "stats" in unit and unit.stats != null and "combat_kind" in unit.stats:
		ck = int(unit.stats.combat_kind)
	if ck != 1:  # 不是装甲类
		return false
	# 检查维修车是否在场
	var is_player: bool = unit.is_player if "is_player" in unit else true
	if not has_repair_vehicle_on_field(is_player):
		return false
	# 50% 概率
	if randf() < REPAIR_ARMOR_SAVE_CHANCE:
		return true
	return false

# ════════════════════════════════════════════════════════════════════════
#  v20.15 高价值单位固定机制（真隐身反隐 / 光环管线 / 个体机制）
# ════════════════════════════════════════════════════════════════════════

## ── 真隐身 + 反隐闭环 ────────────────────────────────────────────
## 隐身状态来源：
##   ① stealth_aircraft 周期隐身（_stealth_active meta，敌我通用）
##   ② 开局渗透隐身（hidden_grace_until meta，毫秒口径；我方 stalker / 敌方 stealth tag）
## 隐身期间不可被单体索敌选中；范围/AOE 伤害豁免（范围武器克隐身，v20.15 拍板）。

static func is_unit_hidden(unit: Node2D) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false
	if unit.has_meta("_stealth_active") and bool(unit.get_meta("_stealth_active")):
		return true
	if unit.has_meta("hidden_grace_until"):
		return Time.get_ticks_msec() < int(unit.get_meta("hidden_grace_until", 0))
	return false

## 目标对攻击者是否可选（隐身且攻击方阵营无侦测源 → 不可选中）
static func is_unit_targetable(target: Node2D, attacker: Node2D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if not is_unit_hidden(target):
		return true
	var attacker_is_player: bool = true
	if attacker != null and is_instance_valid(attacker) and "is_player" in attacker:
		attacker_is_player = bool(attacker.is_player)
	return side_has_detection(attacker_is_player)

## 侦测源卡 tags（雷达/侦测家族由 UCT 名字关键词自动注入 + 侦察系显式 tag）
const DETECTION_TAGS: Array[String] = ["radar", "雷达", "侦测", "recon"]

## 侦测源存在性缓存（0.5s TTL——索敌热路径防每帧全组扫描）
static var _detection_cache: Dictionary = {"player": false, "enemy": false, "until_ms": 0}

static func side_has_detection(is_player: bool) -> bool:
	var now_ms: int = Time.get_ticks_msec()
	if now_ms >= int(_detection_cache.get("until_ms", 0)):
		_detection_cache["player"] = _scan_side_detection(true)
		_detection_cache["enemy"] = _scan_side_detection(false)
		_detection_cache["until_ms"] = now_ms + 500
	return bool(_detection_cache.get("player" if is_player else "enemy", false))

## 阵营侦测源扫描：
## 玩家口径 = 卡 tags 命中 DETECTION_TAGS，或 stats 带 is_recon_unit meta；
## 敌方口径 = legacy platform_type == 4（雷达平台，各时代波次表已天然配好反制手段）。
static func _scan_side_detection(is_player: bool) -> bool:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	var nodes: Array = tree.get_nodes_in_group("player_units" if is_player else "enemy_units")
	for node in nodes:
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		if "_is_dying" in node and node._is_dying:
			continue
		if is_player:
			if _has_any_tag(node, DETECTION_TAGS):
				return true
			if "stats" in node and node.stats != null \
					and node.stats.has_meta("is_recon_unit") \
					and bool(node.stats.get_meta("is_recon_unit", false)):
				return true
		else:
			if "stats" in node and node.stats != null and int(node.stats.platform_type) == 4:
				return true
	return false

static func _has_any_tag(unit: Node2D, tag_list: Array) -> bool:
	for t in tag_list:
		if _has_tag(unit, String(t)):
			return true
	return false

## 光环星级乘数（与 AuraData.star_multiplier 同式：★1=1.0，每星+5%）
static func _star_scale(star: int) -> float:
	return 1.0 + float(maxi(1, star) - 1) * 0.05

## ── 补给卡车（supply tag）：弹药补给光环 ──────────────────────────
## 每 3 秒给全体友军续 4 秒攻速 buff（+12%×星），走 _card_skill_stat_bonus 通道
## （construct_unit._update_card_skill_bonus 每 0.5s 差异应用/到期还原）。
## 注意 until 写裸毫秒——消费端用裸毫秒比较；periodic 引擎写秒级与其口径不一致
## （存量问题，见 v20.15 记档），此处按消费端口径写。
const SUPPLY_INTERVAL: float = 3.0
const SUPPLY_BUFF_DURATION_MS: int = 4000
const SUPPLY_ATTACK_SPEED_BONUS: float = 0.12

static func update_supply_aura_periodic(unit: Node2D, delta: float) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if not _has_tag(unit, "supply"):
		return
	if not unit.has_meta("_supply_cd"):
		unit.set_meta("_supply_cd", SUPPLY_INTERVAL)
	var cd: float = float(unit.get_meta("_supply_cd")) - delta
	if cd > 0.0:
		unit.set_meta("_supply_cd", cd)
		return
	unit.set_meta("_supply_cd", SUPPLY_INTERVAL)
	var is_player: bool = unit.is_player if "is_player" in unit else true
	var bonus: float = SUPPLY_ATTACK_SPEED_BONUS * _star_scale(_get_unit_star(unit))
	var now_ms: int = Time.get_ticks_msec()
	for ally in _get_nearby_allies(unit, 0.0, is_player):
		if not is_instance_valid(ally) or ally == unit:
			continue
		if not ("stats" in ally) or ally.stats == null:
			continue
		# 合并写入（不覆盖并行的技能 stat_bonus 键）
		var sb: Dictionary = ally.get_meta("_card_skill_stat_bonus") if ally.has_meta("_card_skill_stat_bonus") else {}
		sb["attack_speed"] = bonus
		ally.set_meta("_card_skill_stat_bonus", sb)
		ally.set_meta("_card_skill_stat_bonus_until", now_ms + SUPPLY_BUFF_DURATION_MS)

## ── 相位中继站（relay tag）：能量回充 ────────────────────────────
## 玩家侧每 3 秒 +3×星能量；敌方 relay 单位 no-op（敌方无能量系统）。
const RELAY_INTERVAL: float = 3.0
const RELAY_ENERGY_PER_TICK: float = 3.0

static func update_relay_periodic(unit: Node2D, delta: float) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if not _has_tag(unit, "relay"):
		return
	var is_player: bool = unit.is_player if "is_player" in unit else true
	if not is_player:
		return
	if not unit.has_meta("_relay_cd"):
		unit.set_meta("_relay_cd", RELAY_INTERVAL)
	var cd: float = float(unit.get_meta("_relay_cd")) - delta
	if cd > 0.0:
		unit.set_meta("_relay_cd", cd)
		return
	unit.set_meta("_relay_cd", RELAY_INTERVAL)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var em: Node = tree.root.get_node_or_null("EnergyManager")
	if em == null or not em.has_method("add_energy"):
		return
	em.add_energy(RELAY_ENERGY_PER_TICK * _star_scale(_get_unit_star(unit)))

## ── 侦察系（recon tag）：周期暴击标记 ────────────────────────────
## 每 10 秒给最高威胁（HP 最高）敌人挂 crit_mark 8 秒；
## 消费端 target_selection._prioritize_crit_marked（远程集火优先）已就绪，秒级口径同源。
const SCOUT_MARK_INTERVAL: float = 10.0
const SCOUT_MARK_DURATION_SEC: float = 8.0

static func update_scout_mark_periodic(unit: Node2D, delta: float) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if not _has_tag(unit, "recon"):
		return
	if not unit.has_meta("_scout_mark_cd"):
		unit.set_meta("_scout_mark_cd", SCOUT_MARK_INTERVAL)
	var cd: float = float(unit.get_meta("_scout_mark_cd")) - delta
	if cd > 0.0:
		unit.set_meta("_scout_mark_cd", cd)
		return
	unit.set_meta("_scout_mark_cd", SCOUT_MARK_INTERVAL)
	var is_player: bool = unit.is_player if "is_player" in unit else true
	var enemies: Array = _get_all_units_in_group(unit, "enemy_units" if is_player else "player_units")
	if enemies.is_empty():
		return
	var best: Node2D = null
	var best_hp: float = -1.0
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var ehp: float = float(enemy.hp) if "hp" in enemy else 0.0
		if ehp > best_hp:
			best_hp = ehp
			best = enemy
	if best != null:
		best.set_meta("_crit_marked_until", Time.get_ticks_msec() / 1000.0 + SCOUT_MARK_DURATION_SEC)

## ── 风暴核心（storm_core tag）：周期全场风暴 ──────────────────────
## 每 6 秒对全体敌人造成 atk_a×30% 直伤（走 take_damage，命中隐身单位——AOE 豁免口径；
## 数值 v20.15 待平衡）。
const STORM_INTERVAL: float = 6.0
const STORM_DAMAGE_RATIO: float = 0.30

static func update_storm_periodic(unit: Node2D, delta: float) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if not _has_tag(unit, "storm_core"):
		return
	if not unit.has_meta("_storm_cd"):
		unit.set_meta("_storm_cd", STORM_INTERVAL)
	var cd: float = float(unit.get_meta("_storm_cd")) - delta
	if cd > 0.0:
		unit.set_meta("_storm_cd", cd)
		return
	unit.set_meta("_storm_cd", STORM_INTERVAL)
	if not ("stats" in unit) or unit.stats == null:
		return
	var dmg: float = float(unit.stats.attack_armor) * STORM_DAMAGE_RATIO
	if dmg <= 0.0:
		return
	var is_player: bool = unit.is_player if "is_player" in unit else true
	for enemy in _get_all_units_in_group(unit, "enemy_units" if is_player else "player_units"):
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("take_damage"):
			enemy.take_damage(dmg, unit)

## ── 纳米修复机（repair_vehicle tag）：修复脉冲 ────────────────────
## 每 3 秒治疗血量比例最低友军 5%×星 maxHP（与 v20.14 部署返还保护并存，
## 让"纳米修复射线"名副其实）。
const NANO_REPAIR_INTERVAL: float = 3.0
const NANO_REPAIR_PCT: float = 0.05

static func update_nano_repair_pulse(unit: Node2D, delta: float) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if not _has_tag(unit, "repair_vehicle"):
		return
	if not unit.has_meta("_nano_repair_cd"):
		unit.set_meta("_nano_repair_cd", NANO_REPAIR_INTERVAL)
	var cd: float = float(unit.get_meta("_nano_repair_cd")) - delta
	if cd > 0.0:
		unit.set_meta("_nano_repair_cd", cd)
		return
	unit.set_meta("_nano_repair_cd", NANO_REPAIR_INTERVAL)
	var is_player: bool = unit.is_player if "is_player" in unit else true
	var heal_pct: float = NANO_REPAIR_PCT * _star_scale(_get_unit_star(unit))
	var best: Node2D = null
	var best_ratio: float = 1.1
	for ally in _get_all_units_in_group(unit, "player_units" if is_player else "enemy_units"):
		if not is_instance_valid(ally):
			continue
		if not ("stats" in ally) or ally.stats == null or not ("hp" in ally):
			continue
		var mhp: float = float(ally.stats.max_hp)
		if mhp <= 0.0:
			continue
		var hp: float = float(ally.hp)
		if hp <= 0.0:
			continue
		var ratio: float = hp / mhp
		if ratio < best_ratio:
			best_ratio = ratio
			best = ally
	if best != null and best.has_method("heal"):
		best.heal(float(best.stats.max_hp) * heal_pct)


## ── 工具函数 ──────────────────────────────────────────────────────

## 检查单位是否持有指定 tag（通过 stats.platform_card_id 查卡的 tags）
static func _has_tag(unit: Node2D, tag: String) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false
	# 优先从 meta 缓存读取
	if unit.has_meta("_ability_tags"):
		var cached: Array = unit.get_meta("_ability_tags")
		return tag in cached
	# 从 CardResource 读取并缓存
	var card_id: String = ""
	if "stats" in unit and unit.stats != null:
		card_id = unit.stats.platform_card_id
	if card_id.is_empty():
		return false
	var card: CardResource = _get_card_resource(card_id)
	if card == null:
		return false
	var tags: Array = card.get("tags") if "tags" in card else []
	unit.set_meta("_ability_tags", tags)
	return tag in tags

static func _get_card_resource(card_id: String) -> CardResource:
	if card_id.is_empty():
		return null
	# 尝试从 DefaultCards 获取
	var DefaultCards = load("res://data/default_cards.gd") as GDScript
	if DefaultCards != null:
		var inst = DefaultCards.new()
		if inst.has_method("get_card_by_id"):
			return inst.get_card_by_id(card_id) as CardResource
	# 尝试从 UnifiedCardTable 获取
	var UCT = load("res://data/unified_card_table.gd") as GDScript
	if UCT != null:
		var inst = UCT.new()
		if inst.has_method("get_entry"):
			var entry: Dictionary = inst.get_entry(card_id)
			if not entry.is_empty():
				if inst.has_method("_entry_to_card"):
					return inst._entry_to_card(entry)
	return null

## 安全获取 SignalBus（静态上下文无 autoload 直接访问）
static func _get_signal_bus() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/SignalBus")
