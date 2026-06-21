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
	# origin 可能尚未加入场景树（setup 阶段被 AuraManager 调用）
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
static func apply_radar_range_aura(unit: Node2D, delta: float) -> void:
	if unit == null or not ("stats" in unit) or unit.stats == null:
		return
	# 用 meta 标记避免重复施加
	if unit.has_meta("radar_aura_applied"):
		return
	unit.set_meta("radar_aura_applied", true)
	var is_player: bool = unit.is_player if "is_player" in unit else true
	var star: int = _get_unit_star(unit)
	var params: Dictionary = _get_aura_data().get_aura_params(_get_aura_data().Category.RADAR_RANGE, star)
	var range_bonus: float = float(params.get("range_bonus", 15.0))
	var allies: Array = _get_nearby_allies(unit, 180.0, is_player)
	for ally in allies:
		if not is_instance_valid(ally) or ally == unit:
			continue
		if not ("stats" in ally) or ally.stats == null:
			continue
		if not ally.has_meta("radar_buffed"):
			ally.set_meta("radar_buffed", true)
			ally.set_meta("radar_orig_range", ally.stats.attack_range)
			ally.stats.attack_range += range_bonus
			# 同时更新多武器射程
			for w in ally.stats.weapons:
				if w.has("range"):
					w["range"] = float(w["range"]) + range_bonus

## RADAR 光环清理：单位死亡时恢复友军射程
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
			var orig_range: float = float(ally.get_meta("radar_orig_range"))
			if "stats" in ally and ally.stats != null:
				ally.stats.attack_range = orig_range
				for w in ally.stats.weapons:
					if w.has("range"):
						w["range"] = float(w["range"]) - (ally.stats.attack_range - orig_range)
			ally.remove_meta("radar_buffed")
			ally.remove_meta("radar_orig_range")

## SCOUT/STEALTH 侦查光环：暴击+命中（按槽位判定范围）
static func apply_scout_crit_aura(unit: Node2D, delta: float) -> void:
	if unit == null or not ("stats" in unit) or unit.stats == null:
		return
	if unit.has_meta("scout_aura_applied"):
		return
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
static func apply_fortress_defense_aura(unit: Node2D, delta: float) -> void:
	if unit == null or not ("stats" in unit) or unit.stats == null:
		return
	if unit.has_meta("fortress_aura_applied"):
		return
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
		if not _get_aura_data().is_mechanical_platform(ally.stats.platform_type):
			continue
		var heal_amount: float = ally.stats.max_hp * heal_pct
		if not ally.has_meta("carrier_repair_buffed"):
			ally.set_meta("carrier_repair_buffed", true)
		if ally.has_method("heal"):
			ally.heal(heal_amount)
		elif "hp" in ally:
			ally.hp = min(ally.hp + heal_amount, ally.stats.max_hp)

## COMMAND_GLOBAL 指挥光环：全场友军攻/速/暴加成
static func apply_command_global_aura(unit: Node2D) -> void:
	if unit == null or not ("stats" in unit) or unit.stats == null:
		return
	if unit.has_meta("command_aura_applied"):
		return
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
	if "stats" in unit and unit.stats != null and not unit.stats.platform_card_id.is_empty():
		var loop = Engine.get_main_loop()
		if loop is SceneTree:
			var bm: Node = (loop as SceneTree).root.get_node_or_null("BlueprintManager")
			if bm != null and bm.has_method("get_blueprint_star"):
				var star: int = int(bm.get_blueprint_star(unit.stats.platform_card_id))
				unit.set_meta("enhance_level", star)
				return star
	unit.set_meta("enhance_level", 1)
	return 1
