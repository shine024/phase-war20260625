extends Node
## 模块化词条战斗效果处理器
## 负责在战斗中应用模块化词条的特殊效果

class_name AffixCombatHandler

## 暴击伤害倍数
const CRIT_DAMAGE_MULTIPLIER: float = 1.5

static func _has_property(obj: Object, property_name: String) -> bool:
	if obj == null:
		return false
	for p in obj.get_property_list():
		if String(p.get("name", "")) == property_name:
			return true
	return false

## ─────────────────────────────────────────────
##  伤害计算：暴击、穿甲
## ─────────────────────────────────────────────

## 计算最终伤害（考虑暴击和穿甲）
## 返回 { final_damage, is_crit, actual_reduction }
static func calculate_damage(
	base_damage: float,
	attacker_stats: UnitStats,
	_defender_hp: float,
	_defender_max_hp: float,
	defender_damage_reduction: float
) -> Dictionary:
	var is_crit: bool = false
	var crit_roll: float = randf()
	
	# 判断是否暴击
	if crit_roll < attacker_stats.crit_chance:
		is_crit = true
		base_damage *= CRIT_DAMAGE_MULTIPLIER
	
	# 计算防御减免
	# 穿甲率可以忽视防御：(1 - armor_penetration) 比例保持防御
	var effective_reduction: float = defender_damage_reduction * (1.0 - attacker_stats.armor_penetration)
	var final_damage: float = base_damage * (1.0 - effective_reduction)
	
	return {
		"final_damage": max(0.1, final_damage),
		"is_crit": is_crit,
		"actual_reduction": effective_reduction,
		"base_damage": base_damage
	}

## ─────────────────────────────────────────────
##  伤害后处理：吸血、溅射、连锁
## ─────────────────────────────────────────────

## 处理吸血效果
## 返回吸收的生命值
static func apply_lifesteal(
	damage_dealt: float,
	attacker_stats: UnitStats,
	attacker: Node2D
) -> float:
	if attacker_stats.lifesteal <= 0.0 or attacker == null:
		return 0.0
	
	var heal_amount: float = damage_dealt * attacker_stats.lifesteal
	
	# 调用单位的治疗方法（如果存在）
	if attacker.has_method("heal"):
		attacker.heal(heal_amount)
	elif _has_property(attacker, "hp"):
		attacker.hp = min(attacker.hp + heal_amount, attacker_stats.max_hp)
	
	return heal_amount

## 处理溅射伤害
## 在目标周围造成范围伤害
## 返回溅射伤害列表
static func apply_splash_damage(
	primary_target: Node2D,
	damage_dealt: float,
	attacker_stats: UnitStats,
	_attacker_is_player: bool
) -> Array:
	if attacker_stats.splash_damage <= 0.0 or primary_target == null:
		return []
	
	var splash_dmg: float = damage_dealt * attacker_stats.splash_damage
	var splash_radius: float = 80.0  # 溅射范围（像素）
	var targets_hit: Array = []
	
	# 获取 primary_target 的父节点（战斗单位容器）
	var parent: Node = primary_target.get_parent()
	if parent == null:
		return []
	
	# 在范围内查找其他目标
	for node in parent.get_children():
		if node == primary_target or not is_instance_valid(node):
			continue
		if not node is Node2D:
			continue
		if not node.has_method("take_damage"):
			continue
		
		var distance: float = node.global_position.distance_to(primary_target.global_position)
		if distance <= splash_radius:
			node.take_damage(splash_dmg)
			targets_hit.append({
				"target": node,
				"damage": splash_dmg,
				"distance": distance
			})
	
	return targets_hit

## 处理连锁伤害效果
## 从主目标跳向附近的敌人造成伤害
## 返回连锁伤害信息列表
static func apply_chain_lightning(
	primary_target: Node2D,
	damage_dealt: float,
	attacker_stats: UnitStats,
	_attacker_is_player: bool,
	max_chain_targets: int = 5
) -> Array:
	if attacker_stats.chain_chance <= 0.0 or primary_target == null:
		return []
	
	var chain_chance: float = attacker_stats.chain_chance
	var chain_roll: float = randf()
	
	# 判断是否触发连锁
	if chain_roll >= chain_chance:
		return []
	
	var chain_damage: float = damage_dealt * 0.75  # 连锁伤害为原伤害的75%
	var chain_radius: float = 200.0  # 连锁范围
	var targets_hit: Array = []
	var chain_count: int = 0
	
	var parent: Node = primary_target.get_parent()
	if parent == null:
		return []
	
	# 递归连锁
	var current_target: Node2D = primary_target
	var hit_targets: Array = [primary_target]  # 已经被连锁的目标
	
	while chain_count < max_chain_targets:
		# 寻找下一个目标
		var next_target: Node2D = null
		var min_distance: float = chain_radius
		
		for node in parent.get_children():
			if not is_instance_valid(node) or hit_targets.has(node):
				continue
			if not node is Node2D or not node.has_method("take_damage"):
				continue
			
			var distance: float = node.global_position.distance_to(current_target.global_position)
			if distance <= min_distance:
				min_distance = distance
				next_target = node
		
		# 没有找到下一个目标则停止
		if next_target == null:
			break
		
		# 造成连锁伤害
		next_target.take_damage(chain_damage)
		targets_hit.append({
			"target": next_target,
			"damage": chain_damage,
			"chain_hop": chain_count + 1
		})
		
		hit_targets.append(next_target)
		current_target = next_target
		chain_count += 1
	
	return targets_hit

## ─────────────────────────────────────────────
##  持续效果：护盾、回血
## ─────────────────────────────────────────────

## 处理击杀护盾效果
## 当单位击杀敌人时获得护盾
## 返回获得的护盾值
static func apply_shield_on_kill(
	killer: Node2D,
	killer_stats: UnitStats
) -> float:
	if killer_stats.shield_on_kill <= 0.0 or killer == null:
		return 0.0
	
	# shield_on_kill 表示基于最大 HP 的百分比
	var shield_value: float = killer_stats.max_hp * killer_stats.shield_on_kill
	
	# 将护盾值叠加到单位（如果支持护盾系统）
	if killer.has_method("add_shield"):
		killer.add_shield(shield_value)
	
	return shield_value

## ─────────────────────────────────────────────
##  持续处理（每帧调用）
## ─────────────────────────────────────────────

## 处理每秒回血效果
static func apply_hp_regen(unit: Node2D, unit_stats: UnitStats, delta: float) -> float:
	if unit_stats.hp_regen <= 0.0 or unit == null:
		return 0.0
	
	# hp_regen 表示每秒回复的 HP 百分比
	var heal_amount: float = unit_stats.max_hp * unit_stats.hp_regen * delta
	
	if _has_property(unit, "hp"):
		var old_hp: float = unit.hp
		unit.hp = min(unit.hp + heal_amount, unit_stats.max_hp)
		return unit.hp - old_hp  # 实际治疗量
	
	return 0.0

## ─────────────────────────────────────────────
##  词条变异效果处理
## ─────────────────────────────────────────────

## 处理"武器伤害+15%变异"：双倍伤害概率
static func check_weapon_dmg_mutation_double_damage(attacker_stats: UnitStats) -> bool:
	if not attacker_stats.has_meta("weapon_dmg_mutated") or not attacker_stats.get_meta("weapon_dmg_mutated"):
		return false
	# 15% 概率触发双倍伤害
	return randf() < 0.15

## 处理"速射改装变异"：连续攻击加成
## track_attack_count 需要在单位端维护
static func check_weapon_atkspd_mutation_bonus(attacker: Node2D) -> float:
	# 连续攻击3次后，下次攻击伤害+50%
	if not attacker.has_meta("attack_count"):
		attacker.set_meta("attack_count", 0)
	
	var count: int = int(attacker.get_meta("attack_count"))
	count += 1
	attacker.set_meta("attack_count", count)
	
	if count >= 3:
		attacker.set_meta("attack_count", 0)
		return 1.5  # 伤害倍数
	
	return 1.0

## 处理"精准打击变异"：暴击恢复生命
static func check_crit_mutation_heal(
	is_crit: bool,
	attacker: Node2D,
	attacker_stats: UnitStats
) -> float:
	if not is_crit or attacker == null:
		return 0.0
	
	# 暴击时恢复 5% 最大生命值
	var heal_amount: float = attacker_stats.max_hp * 0.05
	
	if attacker.has_method("heal"):
		attacker.heal(heal_amount)
	elif _has_property(attacker, "hp"):
		attacker.hp = min(attacker.hp + heal_amount, attacker_stats.max_hp)
	
	return heal_amount

## 处理"吸血变异"：生命低于 30% 时吸血效果翻倍
static func get_lifesteal_multiplier(attacker: Node2D, attacker_stats: UnitStats) -> float:
	if attacker == null or attacker_stats.max_hp <= 0.0:
		return 1.0
	
	var hp_ratio: float = attacker.hp / attacker_stats.max_hp if _has_property(attacker, "hp") else 1.0
	if hp_ratio < 0.3:
		return 2.0  # 吸血翻倍
	
	return 1.0

## 处理"纳米自愈变异"：生命低于 50% 时回复速度翻倍
static func get_hp_regen_multiplier(unit: Node2D, unit_stats: UnitStats) -> float:
	if unit == null or unit_stats.max_hp <= 0.0:
		return 1.0
	
	var hp_ratio: float = unit.hp / unit_stats.max_hp if _has_property(unit, "hp") else 1.0
	if hp_ratio < 0.5:
		return 2.0  # 回复翻倍
	
	return 1.0

## 处理"平台HP变异"：血量超过 80% 时伤害减少 10%
static func check_platform_hp_mutation_extra_defense(unit: Node2D, unit_stats: UnitStats) -> bool:
	if unit == null or unit_stats.max_hp <= 0.0:
		return false
	
	var hp_ratio: float = unit.hp / unit_stats.max_hp if _has_property(unit, "hp") else 0.0
	return hp_ratio >= 0.8

## ─────────────────────────────────────────────
##  工具函数
## ─────────────────────────────────────────────

## 获取目标的敌对方单位列表
static func get_nearby_enemies(
	origin: Node2D,
	radius: float,
	is_attacker_player: bool
) -> Array:
	if origin == null or not is_instance_valid(origin):
		return []

	var pos: Vector2 = origin.global_position

	# 战斗中优先用 BattleManager 空间网格，避免 get_nodes_in_group 全表扫描
	if BattleManager and BattleManager.spatial_grid and is_instance_valid(BattleManager.spatial_grid):
		var grid: Node = BattleManager.spatial_grid
		if grid.has_method("query_enemies"):
			var nearby: Array = grid.query_enemies(pos, radius, is_attacker_player)
			var out: Array = []
			for node in nearby:
				if is_instance_valid(node) and node != origin and node is Node2D:
					out.append(node)
			return out

	# 无网格时（非战斗场景/测试）回退到组扫描
	if origin.get_tree() == null:
		return []
	var group_name: String = "enemy_units" if is_attacker_player else "player_units"
	var enemies: Array = []
	for node in origin.get_tree().get_nodes_in_group(group_name):
		if not is_instance_valid(node) or node == origin:
			continue
		if not node is Node2D:
			continue
		if node.global_position.distance_squared_to(pos) <= radius * radius:
			enemies.append(node)
	return enemies
