## ConstructUnit AI / Attack / Targeting logic
## 提取自 construct_unit.gd，class_name 用于跨文件引用
class_name ConstructUnitAI
extends RefCounted

const GC = preload("res://resources/game_constants.gd")
const BulletScene = preload("res://scenes/units/bullet.tscn")
const ModuleEffectHandler = preload("res://scripts/battle/module_effect_handler.gd")
const CombatFeedback = preload("res://scripts/combat_feedback.gd")
const CombatTargeting = preload("res://scripts/combat_targeting.gd")
const TargetSelection = preload("res://scripts/battle/target_selection.gd")
const DamageAttenuation = preload("res://scripts/battle/damage_attenuation.gd")
const AttackCalculator = preload("res://scripts/battle/attack_calculator.gd")

## 主循环攻击处理：由 construct_unit._physics_process 调用
## 返回值暂未使用，保留以备扩展
static func process_attack(u: CharacterBody2D, delta: float) -> void:
	# 多武器处理
	if u._weapon_cfgs.size() > 0:
		_process_multi_weapons(u, delta)
	else:
		if u._hit_stun_left <= 0.0:
			_process_single_weapon_attack(u, delta)

## 获取目标查找间隔
static func get_target_find_interval(u: CharacterBody2D) -> float:
	var n: int = 0
	if BattleManager and BattleManager.has_method("get_enemy_unit_count"):
		n = BattleManager.get_enemy_unit_count()
	if n > 55:
		return 0.55
	if n > 35:
		return 0.42
	return 0.3

## 查找攻击目标
static func find_target(u: CharacterBody2D, _delta: float) -> void:
	if should_retain_current_target(u):
		return
	u.target = null

	# 性能优化：优先使用空间分区系统
	if BattleManager and BattleManager.spatial_grid:
		var spatial_grid = BattleManager.spatial_grid
		if spatial_grid:
			var nearest_target = spatial_grid.query_nearest_target(
				u.global_position,
				u.is_player,
				acquisition_range(u)
			)
			if nearest_target != null:
				u.target = nearest_target
				return

	# 回退到传统方法
	var tree = u.get_tree()
	if tree == null:
		return

	var target_group: String = "enemy_units" if u.is_player else "player_units"
	var gr: Array = BattleManager.get_cached_nodes_in_group(target_group) if BattleManager else tree.get_nodes_in_group(target_group)
	var candidates: Array = []
	var acq: float = acquisition_range(u)
	for n in gr:
		if not CombatTargeting.is_attackable_combat_unit(n):
			continue
		if u.global_position.distance_to((n as Node2D).global_position) <= acq:
			candidates.append(n)

	if not candidates.is_empty() and u.stats != null:
		var selected: Node2D = TargetSelection.select_target(u, candidates, u.stats.weapon_type)
		if selected != null:
			u.target = selected
			return
	elif not candidates.is_empty():
		candidates.sort_custom(func(a, b): return u.global_position.distance_squared_to((a as Node2D).global_position) < u.global_position.distance_squared_to((b as Node2D).global_position))
		u.target = candidates[0] as Node2D
		return

	# 无对方战斗单位时，攻击对方相位场
	if targeting_opponent_phase_field_only(u):
		var phase_field: Node2D = CombatTargeting.find_opponent_phase_field(
			u.global_position, u.is_player, BattleManager, -1.0
		)
		if phase_field != null:
			u.target = phase_field
			return

## 执行攻击（使用 stats 计算伤害）
static func do_attack(u: CharacterBody2D) -> void:
	if u.target == null or u.stats == null:
		do_attack_with_damage(u, u.stats.attack_light if u.stats else 0.0, u.stats.weapon_type if u.stats else 0)
		return

	var target_stats = u.target.get("stats") as UnitStats
	var target_kind: int = target_stats.combat_kind if target_stats else 0
	var distance: float = u.global_position.distance_to(u.target.global_position)

	# 尝试使用槽位系统
	var weapon = AttackCalculator.get_weapon_for_target(u.stats, target_kind)
	if weapon != null and weapon.enabled:
		var damage = AttackCalculator.calculate_damage_with_weapon(
			u.stats, target_stats,
			distance, weapon,
			u.stats.enhance_level, _get_mod_array(u.stats)
		)
		# 射程检查
		if weapon.weapon_type == GC.WeaponType.DIRECT:
			var max_range = AttackCalculator.get_weapon_range(weapon)
			if distance > max_range:
				CombatFeedback.show_miss(u.target.global_position, u.target)
				return
		do_attack_with_damage(u, damage, weapon.weapon_type, weapon.display_name, weapon)
		return

	# 回退到旧系统
	var damage: float = AttackCalculator.get_attack_vs(u.stats, target_kind)
	do_attack_with_damage(u, damage, u.stats.weapon_type, "")

## 执行攻击（指定伤害值）
static func do_attack_with_damage(u: CharacterBody2D, damage: float, weapon_type_override: int = -1, weapon_name: String = "", weapon_resource: Variant = null) -> void:
	if u.is_deploy_ghost:
		return
	if u._hit_stun_left > 0.0:
		return
	if u.target == null or not is_instance_valid(u.target):
		return
	var dist_t := u.global_position.distance_to(u.target.global_position)
	var miss := false
	var wt: int = weapon_type_override if weapon_type_override >= 0 else (u.stats.weapon_type if u.stats else 0)

	# 射程检查：优先使用 WeaponResource 字段
	var range_val: float = 0.0
	if weapon_resource and weapon_resource is WeaponResource:
		range_val = AttackCalculator.get_weapon_range(weapon_resource)
	elif u.stats:
		range_val = u.stats.attack_range

	if range_val > 0 and dist_t > range_val:
		if wt == GC.WeaponType.DIRECT or wt == -1:
			if wt == 0 and u.stats and u.stats.attack_range > 0.5 and dist_t > u.stats.attack_range:
				var sub_type: String = DamageAttenuation.infer_weapon_sub_type(
					u.stats.combat_kind, int(u.stats.attack_range / 100.0),
					u.stats.attack_light, u.stats.attack_armor, u.stats.attack_air
				)
				var max_range_grids: float = u.stats.attack_range / 100.0
				var dist_grids: float = dist_t / 100.0
				var att_mult: float = DamageAttenuation.calculate_attenuation(dist_grids, max_range_grids, sub_type)
				if att_mult <= 0.0:
					miss = true
					CombatFeedback.show_miss(u.target.global_position, u.target)
				else:
					damage *= att_mult
			elif wt != 0:
				var falloff: Dictionary = CombatTargeting.range_falloff(dist_t, u.stats.attack_range if u.stats else 120.0)
				if randf() > float(falloff.get("p_hit", 1.0)):
					miss = true
					CombatFeedback.show_miss(u.target.global_position, u.target)
				else:
					damage *= float(falloff.get("damage_mult", 1.0))
	# 卡牌特殊能力：平台攻击修改
	if u._has_titan_mk2:
		damage *= CardAbilityManager.get_titan_mk2_damage_multiplier(u)
	if u._has_storm_rider:
		damage *= CardAbilityManager.get_storm_rider_damage_multiplier(u)
	if u._presentation_card_grid:
		_play_card_attack_nudge(u)
	var bullet: Node2D = ObjectPoolManager.get_object("bullets")
	if bullet == null:
		bullet = BulletScene.instantiate()
	bullet.global_position = u.global_position
	# v6.0: 传递 weapon_name 给子弹用于 VFX 贴图查找
	var w_name: String = ""
	if weapon_resource and weapon_resource is WeaponResource:
		w_name = weapon_resource.display_name if weapon_resource.display_name else ""
	bullet.setup(u.target, damage, true, wt, u, u.stats, miss, w_name)
	var root_2d = u.get_parent().get_parent() if u.get_parent() else u
	var current_parent: Node = bullet.get_parent()
	if current_parent != root_2d:
		if current_parent != null:
			current_parent.remove_child(bullet)
		root_2d.add_child(bullet)

## 应用持续效果（回血等），由 _physics_process 调用
static func apply_continuous_effects(u: CharacterBody2D, delta: float) -> void:
	if u.stats == null:
		return
	# 应用回血效果（纳米自愈词条）
	if u.stats.hp_regen > 0.0:
		ModuleEffectHandler.on_tick(u, delta)

## v5.0 攻速分离: 单武器三阶段攻击状态机
static func _process_single_weapon_attack(u: CharacterBody2D, delta: float) -> void:
	if u.target == null or not is_instance_valid(u.target):
		u._attack_phase = u.AttackPhase.IDLE
		u._attack_phase_timer = 0.0
		return
	var target_stats = u.target.get("stats") as UnitStats
	var target_kind: int = target_stats.combat_kind if target_stats else 0

	# v6.0: 从武器槽位获取武器并计算 timing
	var weapon = AttackCalculator.get_weapon_for_target(u.stats, target_kind)
	var timing: Dictionary
	var fire_range: float
	var wt: int
	if weapon and weapon.enabled:
		timing = AttackCalculator.get_weapon_attack_timing(weapon)
		fire_range = AttackCalculator.get_weapon_range(weapon)
		wt = weapon.weapon_type
		u.set("attack_interval", timing["cycle"])
	else:
		timing = AttackCalculator.get_attack_timing(u.stats, target_kind)
		fire_range = u.stats.attack_range if u.stats else 120.0
		wt = u.stats.weapon_type if u.stats else 0

	var dist: float = u.global_position.distance_to(u.target.global_position)
	if dist > fire_range and wt == GC.WeaponType.DIRECT:
		u._attack_phase = u.AttackPhase.IDLE
		u._attack_phase_timer = 0.0
		return
	match u._attack_phase:
		u.AttackPhase.IDLE:
			if dist <= fire_range:
				u._attack_phase = u.AttackPhase.WINDUP
				u._attack_phase_timer = 0.0
		u.AttackPhase.WINDUP:
			u._attack_phase_timer += delta
			if u._attack_phase_timer >= timing["windup"]:
				u._attack_phase = u.AttackPhase.ACTIVE
				u._attack_phase_timer = 0.0
		u.AttackPhase.ACTIVE:
			u._attack_phase_timer += delta
			if u._attack_phase_timer < delta * 1.1:
				do_attack(u)
			if u._attack_phase_timer >= timing["active"]:
				u._attack_phase = u.AttackPhase.COOLDOWN
				u._attack_phase_timer = 0.0
		u.AttackPhase.COOLDOWN:
			u._attack_phase_timer += delta
			if u._attack_phase_timer >= timing["cooldown"]:
				u._attack_phase = u.AttackPhase.IDLE
				u._attack_phase_timer = 0.0

## 多武器三阶段攻击状态机
static func _process_multi_weapons(u: CharacterBody2D, delta: float) -> void:
	if u.is_deploy_ghost or u.is_preview_mode:
		return
	if u.stats != null and u.stats.platform_type == 12:
		return
	if u._hit_stun_left > 0.0:
		return
	if u.target == null or not is_instance_valid(u.target):
		for w in u._weapon_cfgs:
			w["phase"] = u.AttackPhase.IDLE
			w["phase_timer"] = 0.0
		return
	var target_stats = u.target.get("stats") as UnitStats
	var target_kind: int = target_stats.combat_kind if target_stats else 0
	var eff_rng: float = effective_fire_range(u)
	var dist: float = u.global_position.distance_to(u.target.global_position)
	for i in range(u._weapon_cfgs.size()):
		var w = u._weapon_cfgs[i]
		var phase: int = int(w.get("phase", u.AttackPhase.IDLE))
		var phase_timer: float = float(w.get("phase_timer", 0.0))
		var w_wt: int = int(w.get("weapon_type", -1))
		var w_damage: float = float(w.get("damage", 0.0))

		# v6.0: 从武器槽位获取对应 timing
		var timing: Dictionary
		var w_range: float
		var w_weapon: WeaponResource
		if i < u.stats.weapon_slots.size():
			w_weapon = u.stats.weapon_slots[i] as WeaponResource
			if w_weapon and w_weapon.enabled:
				timing = AttackCalculator.get_weapon_attack_timing(w_weapon)
				w_range = AttackCalculator.get_weapon_range(w_weapon)
			else:
				timing = AttackCalculator.get_attack_timing(u.stats, target_kind)
				w_range = u.stats.attack_range
		else:
			timing = AttackCalculator.get_attack_timing(u.stats, target_kind)
			w_range = u.stats.attack_range

		if dist > w_range and w_wt == GC.WeaponType.DIRECT:
			phase = u.AttackPhase.IDLE
			phase_timer = 0.0
		match phase:
			u.AttackPhase.IDLE:
				if dist <= eff_rng:
					phase = u.AttackPhase.WINDUP
					phase_timer = 0.0
			u.AttackPhase.WINDUP:
				phase_timer += delta
				if phase_timer >= timing["windup"]:
					phase = u.AttackPhase.ACTIVE
					phase_timer = 0.0
			u.AttackPhase.ACTIVE:
				phase_timer += delta
				if phase_timer < delta * 1.1:
					var dmg: float = w_damage if w_damage > 0 else float(w.get("damage", u.stats.attack_damage))
					var w_name: String = ""
					if w_weapon and w_weapon is WeaponResource:
						w_name = w_weapon.display_name
					do_attack_with_damage(u, dmg, w_wt, w_name, w_weapon)
				if phase_timer >= timing["active"]:
					phase = u.AttackPhase.COOLDOWN
					phase_timer = 0.0
			u.AttackPhase.COOLDOWN:
				phase_timer += delta
				if phase_timer >= timing["cooldown"]:
					phase = u.AttackPhase.IDLE
					phase_timer = 0.0
		w["phase"] = phase
		w["phase_timer"] = phase_timer

## ===== 辅助函数 =====

static func acquisition_range(u: CharacterBody2D) -> float:
	if u.stats == null:
		return 120.0
	var combat_started: bool = (
		GameManager
		and GameManager.is_card_grid_battle()
		and BattleManager != null
		and BattleManager.has_method("is_card_grid_combat_started")
		and BattleManager.is_card_grid_combat_started()
	)
	if not u.is_player and GameManager and GameManager.is_card_grid_battle():
		return CombatTargeting.card_grid_enemy_acquisition_range(u.stats.attack_range, combat_started)
	var r: float = u.stats.attack_range
	if combat_started:
		r *= 2.6
	return r

static func effective_fire_range(u: CharacterBody2D) -> float:
	if u.stats == null:
		return 120.0
	var rng: float = u.stats.attack_range
	if (
		GameManager
		and GameManager.is_card_grid_battle()
		and BattleManager != null
		and BattleManager.has_method("is_card_grid_combat_started")
		and BattleManager.is_card_grid_combat_started()
	):
		rng *= 2.6
	if u.target != null and is_instance_valid(u.target) and CombatTargeting.is_phase_field_node(u.target):
		if targeting_opponent_phase_field_only(u):
			return maxf(rng, acquisition_range(u) * 1.5)
	return rng

static func targeting_opponent_phase_field_only(u: CharacterBody2D) -> bool:
	if u.is_player:
		return not CombatTargeting.has_alive_enemy_units(BattleManager)
	return not CombatTargeting.has_alive_player_units(BattleManager)

static func should_retain_current_target(u: CharacterBody2D) -> bool:
	if u.target == null or not is_instance_valid(u.target):
		return false
	if CombatTargeting.should_drop_phase_field_target(u.target, u.is_player, BattleManager):
		return false
	if CombatTargeting.is_phase_field_node(u.target):
		return targeting_opponent_phase_field_only(u)
	var d: float = u.global_position.distance_to(u.target.global_position)
	return d <= acquisition_range(u)

## 格子战术卡面攻击前推动画
static func _play_card_attack_nudge(u: CharacterBody2D) -> void:
	if not u._presentation_card_grid:
		return
	if is_nan(u._card_grid_rest_x):
		u._card_grid_rest_x = u.position.x
	if u._card_nudge_tween != null and u._card_nudge_tween.is_valid():
		u._card_nudge_tween.kill()
		u.position.x = u._card_grid_rest_x
	u._card_nudge_tween = u.create_tween()
	var dir: float = 1.0 if u.is_player else -1.0
	var rest_x: float = u._card_grid_rest_x
	u._card_nudge_tween.tween_property(u, "position:x", rest_x + dir * 22.0, 0.07)
	u._card_nudge_tween.tween_property(u, "position:x", rest_x, 0.09)

## 辅助：从 UnitStats 提取 mods 数组供 AttackCalculator 使用
static func _get_mod_array(stats: Variant) -> Array:
	if stats == null:
		return []
	var result: Array = []
	if stats.has_method("get_mod_list"):
		var raw = stats.get_mod_list()
		result.assign(raw)
	return result
