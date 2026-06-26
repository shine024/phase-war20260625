class_name ModuleEffectHandler
extends RefCounted
## v6.0 统一条词效果处理器（替代旧 AffixCombatHandler）
## 在战斗中按触发点调用。
##
## 触发点：
##   - on_bullet_hit()    — 弹道命中时：暴击、穿甲、闪避、吸血、溅射、闪电链
##   - on_kill()           — 击杀时：护盾
##   - on_tick()           — 持续：HP回复
##   - on_damage_taken()   — 受击时：闪避、减伤

const GC = preload("res://resources/game_constants.gd")

# ─────────────────────────────────────────────
#  弹道命中处理
# ─────────────────────────────────────────────

## 弹道命中时综合处理
## 返回最终伤害值（0 表示被闪避）
static func on_bullet_hit(attacker: Node, target: Node, base_damage: float) -> float:
	var stats = _get_attacker_stats(attacker)
	var target_stats = _get_target_stats(target)
	if stats == null:
		return base_damage

	var final_damage := base_damage

	# 1. 穿甲
	if stats.armor_penetration > 0.0:
		final_damage = _apply_penetration(final_damage, stats)

	# 2. 暴击
	final_damage = _apply_crit(final_damage, stats)

	# 3. 目标减伤
	if target_stats != null:
		final_damage = _apply_target_reduction(final_damage, target_stats)
		# 4. 目标闪避
		if _check_dodge(target, target_stats):
			return 0.0

	# 5. 吸血
	_apply_lifesteal(attacker, final_damage, stats)

	# v6.6: 主目标伤害惩罚（子母弹等范围武器的单目标平衡项，值为负小数）
	# 默认 0 时 (1+0)=1 无影响；放在最终伤害确定后、溅射/连锁之前
	if stats.single_target_penalty != 0.0:
		final_damage = maxf(0.0, final_damage * (1.0 + stats.single_target_penalty))

	# 6. 溅射
	_apply_splash(attacker, target, final_damage, stats)

	# 7. 闪电链
	_apply_chain(attacker, target, final_damage, stats)

	return final_damage

# ─────────────────────────────────────────────
#  命中副作用（仅吸血/连锁/溅射，不含暴击/穿甲/减伤/闪避）
# ─────────────────────────────────────────────

## v6.6: 仅处理命中副作用（吸血/连锁/溅射），不重新计算伤害数值。
## 用于伤害已由 attack_calculator / 已有路径计算的批处理路径，
## 避免暴击/穿甲双重计算。deal_damage 为最终结算伤害。
static func apply_on_hit_side_effects(attacker: Node, target: Node, deal_damage: float) -> void:
	var stats = _get_attacker_stats(attacker)
	if stats == null or deal_damage <= 0.0:
		return
	_apply_lifesteal(attacker, deal_damage, stats)
	_apply_splash(attacker, target, deal_damage, stats)
	_apply_chain(attacker, target, deal_damage, stats)

# ─────────────────────────────────────────────
#  击杀处理
# ─────────────────────────────────────────────

## 击杀时处理护盾
static func on_kill(attacker: Node) -> void:
	var stats = _get_attacker_stats(attacker)
	if stats == null:
		return
	if stats.shield_on_kill > 0.0:
		var max_hp = _get_unit_max_hp(attacker)
		if max_hp > 0.0:
			var shield_amount = max_hp * stats.shield_on_kill
			_apply_shield(attacker, shield_amount)

# ─────────────────────────────────────────────
#  持续效果
# ─────────────────────────────────────────────

## 每帧持续效果（HP回复）
static func on_tick(unit: Node, delta: float) -> void:
	var stats = _get_unit_stats(unit)
	if stats == null:
		return
	if stats.hp_regen > 0.0:
		var max_hp = _get_unit_max_hp(unit)
		if max_hp > 0.0:
			var regen_amount = max_hp * stats.hp_regen * delta
			_heal_unit(unit, regen_amount)

## 获取 HP 回复倍率（兼容旧接口）
static func get_hp_regen_multiplier(unit: Node, stats: Resource) -> float:
	if stats == null:
		return 0.0
	if stats is UnitStats and stats.hp_regen > 0.0:
		return stats.hp_regen
	return 0.0

## 应用 HP 回复（兼容旧接口）
static func apply_hp_regen(unit: Node, stats: Resource, delta: float) -> void:
	on_tick(unit, delta)

# ─────────────────────────────────────────────
#  平台 HP 变异额外防御（兼容旧接口）
# ─────────────────────────────────────────────

static func check_platform_hp_mutation_extra_defense(unit: Node, stats: Resource) -> float:
	if stats == null or not (stats is UnitStats):
		return 0.0
	if stats.has_platform_hp_mutation:
		var hp_ratio = _get_unit_hp_ratio(unit)
		if hp_ratio > 0.7:
			return stats.defense * 0.3
	return 0.0

# ─────────────────────────────────────────────
#  内部实现
# ─────────────────────────────────────────────

static func _apply_penetration(damage: float, stats: UnitStats) -> float:
	# 穿甲降低目标有效防御
	return damage * (1.0 + stats.armor_penetration * 0.5)

static func _apply_crit(damage: float, stats: UnitStats) -> float:
	if stats.crit_chance <= 0.0:
		return damage
	if randf() > stats.crit_chance:
		return damage
	var crit_mult := 1.5 + stats.crit_damage_bonus
	return damage * crit_mult

static func _apply_target_reduction(damage: float, target_stats: UnitStats) -> float:
	if target_stats.damage_reduction <= 0.0:
		return damage
	return damage * (1.0 - minf(target_stats.damage_reduction, 0.60))

static func _check_dodge(target: Node, target_stats: UnitStats) -> bool:
	if target_stats.dodge_chance <= 0.0:
		return false
	return randf() < target_stats.dodge_chance

static func _apply_lifesteal(attacker: Node, damage: float, stats: UnitStats) -> void:
	if stats.lifesteal <= 0.0 or damage <= 0.0:
		return
	var heal = damage * stats.lifesteal
	_heal_unit(attacker, heal)

static func _apply_splash(attacker: Node, target: Node, damage: float, stats: UnitStats) -> void:
	if stats.splash_damage <= 0.0:
		return
	# 溅射逻辑：对目标周围其他敌人造成溅射伤害
	var splash_dmg = damage * minf(stats.splash_damage, 0.60)
	# v6.6: 半径支持改造加成（子母弹/近炸引信），默认 0 时与原 80px 行为一致
	var radius: float = 80.0 * (1.0 + maxf(0.0, stats.splash_radius_bonus))
	var targets = _find_nearby_enemies(target, radius)
	for t in targets:
		if t != target and is_instance_valid(t):
			_deal_damage_to_unit(t, splash_dmg, attacker)

static func _apply_chain(attacker: Node, target: Node, damage: float, stats: UnitStats) -> void:
	if stats.chain_chance <= 0.0:
		return
	if randf() > stats.chain_chance:
		return
	var chain_dmg = damage * 0.5  # 闪电链伤害 = 50%
	var targets = _find_nearby_enemies(target, 120.0)
	for t in targets:
		if t != target and is_instance_valid(t):
			_deal_damage_to_unit(t, chain_dmg, attacker)
			break  # 闪电链只跳一次

static func _apply_shield(unit: Node, amount: float) -> void:
	if is_instance_valid(unit) and unit.has_method("add_shield"):
		unit.add_shield(amount)

static func _heal_unit(unit: Node, amount: float) -> void:
	if is_instance_valid(unit):
		if unit.has_method("heal"):
			unit.heal(amount)
		elif "hp" in unit:
			unit.hp = minf(unit.hp + amount, _get_unit_max_hp(unit))

static func _deal_damage_to_unit(unit: Node, damage: float, source: Node = null) -> void:
	if not is_instance_valid(unit):
		return
	if unit.has_method("take_damage"):
		unit.take_damage(damage, source)
	elif "hp" in unit:
		unit.hp = maxi(0.0, unit.hp - damage)

static func _find_nearby_enemies(center: Node, radius: float) -> Array:
	if center == null or not is_instance_valid(center):
		return []
	# P3 性能优化: 优先用 spatial_grid.query_enemies（bounding-box 只遍历覆盖格子），
	# 替代原 get_nodes_in_group 全组遍历 + 逐个 distance_to。
	# center 的 is_player 决定找哪方（玩家找敌人 is_player=false）
	var is_player_center: bool = false
	if "is_player" in center:
		is_player_center = bool(center.is_player)
	if BattleManager != null and BattleManager.spatial_grid != null and is_instance_valid(BattleManager.spatial_grid):
		var enemies = BattleManager.spatial_grid.query_enemies(center.global_position, radius, is_player_center)
		# query_enemies 可能包含 center 自身（同阵营），过滤掉
		if center in enemies:
			enemies.erase(center)
		return enemies
	# 防御性回退: spatial_grid 不可用时用原全组遍历
	var targets: Array = []
	var tree = center.get_tree()
	if tree == null:
		return []
	# 找同组目标（玩家打敌人/敌人打玩家）
	if center.is_in_group("player_units"):
		targets = tree.get_nodes_in_group("enemy_units")
	elif center.is_in_group("enemy_units"):
		targets = tree.get_nodes_in_group("player_units")
	var result: Array = []
	for t in targets:
		if is_instance_valid(t) and t != center:
			var dist = center.global_position.distance_to(t.global_position)
			if dist <= radius:
				result.append(t)
	return result

# ─────────────────────────────────────────────
#  Stats 获取工具
# ─────────────────────────────────────────────

static func _get_unit_stats(unit: Node) -> UnitStats:
	if not is_instance_valid(unit):
		return null
	if unit.get("stats") is UnitStats:
		return unit.stats as UnitStats
	return null

static func _get_attacker_stats(attacker: Node) -> UnitStats:
	return _get_unit_stats(attacker)

static func _get_target_stats(target: Node) -> UnitStats:
	return _get_unit_stats(target)

static func _get_unit_max_hp(unit: Node) -> float:
	if not is_instance_valid(unit):
		return 0.0
	if unit.get("stats") is UnitStats:
		return (unit.stats as UnitStats).max_hp
	if "max_hp" in unit:
		return float(unit.max_hp)
	return 0.0

static func _get_unit_hp_ratio(unit: Node) -> float:
	var max_hp = _get_unit_max_hp(unit)
	if max_hp <= 0.0:
		return 0.0
	var current_hp: float = 0.0
	if "hp" in unit:
		current_hp = float(unit.hp)
	return current_hp / max_hp
