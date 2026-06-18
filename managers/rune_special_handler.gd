extends RefCounted
class_name RuneSpecialHandler
## v6.2 符文之语特殊效果触发器
##
## 从 UnitStats 的 meta "rune_specials" 读取特殊效果列表，
## 在单位的关键事件（攻击命中/击杀/受击/死亡）时按概率触发。

# ── 可调参数常量 ─────────────────────────────────────────────────────
const CHAIN_LIGHTNING_RADIUS: float = 250.0   ## 闪电链传导半径
const CHAIN_LIGHTNING_MAX_TARGETS: int = 3    ## 闪电链最大跳跃目标数
const CHAIN_LIGHTNING_DECAY: float = 0.8      ## 闪电链每跳伤害衰减（80%）
const SPLASH_RADIUS: float = 150.0            ## 溅射伤害半径
const SPLASH_MAX_TARGETS: int = 5             ## 溅射最大目标数
const SHIELD_HP_RATIO: float = 0.3            ## 护盾值 = 最大HP × 此比例
const DEFAULT_MAX_HP: float = 100.0           ## 无法读取stats时的回退HP
const PERCENT_DIVISOR: float = 100.0          ## 百分比转小数的除数

## 获取单位携带的符文特殊效果列表
## 返回 Array[Dictionary]，每项 {special, chance, value}
static func get_specials(unit: Node) -> Array:
	if unit == null or not is_instance_valid(unit):
		return []
	if not unit.has_meta("rune_specials"):
		return []
	var specials = unit.get_meta("rune_specials")
	if specials is Array:
		return specials
	return []

## 按类型筛选特殊效果
static func get_specials_by_type(unit: Node, special_type: String) -> Array:
	var result: Array = []
	for sp in get_specials(unit):
		if sp.get("special", "") == special_type:
			result.append(sp)
	return result

# ═══════════════════════════════════════════════════════════════════
# 事件触发器（由 construct_unit / bullet 在关键事件调用）
# ═══════════════════════════════════════════════════════════════════

## 攻击命中时触发（由 bullet.gd._on_hit 调用，shooter 为攻击者）
static func on_hit(attacker: Node, target: Node, damage_dealt: float) -> void:
	if attacker == null or not is_instance_valid(attacker):
		return
	# on_hit_chain_lightning：攻击命中时概率触发闪电链
	for sp in get_specials_by_type(attacker, "on_hit_chain_lightning"):
		if randf() <= float(sp.get("chance", 0.0)):
			_trigger_chain_lightning(attacker, target, damage_dealt, float(sp.get("value", 10)) / PERCENT_DIVISOR)
	# on_area_damage：攻击命中时概率溅射
	for sp in get_specials_by_type(attacker, "on_area_damage"):
		if randf() <= float(sp.get("chance", 0.0)):
			_trigger_splash_damage(attacker, target, damage_dealt, float(sp.get("value", 15)) / PERCENT_DIVISOR)

## 击杀敌人时触发（由击杀逻辑调用，killer 为击杀者）
static func on_kill(killer: Node, _victim: Node) -> void:
	if killer == null or not is_instance_valid(killer):
		return
	# on_kill_regen_energy：击杀时恢复能量
	var is_player: bool = bool(killer.get("is_player")) if "is_player" in killer else true
	if not is_player:
		return  # 仅玩家方单位触发能量恢复
	for sp in get_specials_by_type(killer, "on_kill_regen_energy"):
		if randf() <= float(sp.get("chance", 0.0)):
			var em: Node = _get_autoload(killer, "EnergyManager")
			if em and em.has_method("add_energy"):
				em.add_energy(float(sp.get("value", 50)))
## 受击时触发（由 take_damage 调用，返回额外减伤比例 0.0-1.0）
static func on_damaged(unit: Node, _attacker: Node, _incoming_damage: float) -> float:
	if unit == null or not is_instance_valid(unit):
		return 0.0
	var extra_reduction: float = 0.0
	# on_damage_reduction：受击时额外减伤（叠加）
	for sp in get_specials_by_type(unit, "on_damage_reduction"):
		# 此效果为常驻减伤，已通过数值加成处理，这里不重复
		pass
	# on_energy_shield：受击时概率生成护盾
	for sp in get_specials_by_type(unit, "on_energy_shield"):
		if randf() <= float(sp.get("chance", 0.0)):
			_generate_shield(unit, float(sp.get("value", 100)) / 100.0)
	return extra_reduction

## 死亡时触发（返回 true 表示复活成功，阻止死亡）
static func on_death(unit: Node) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false
	# on_death_respawn：死亡时概率复活
	for sp in get_specials_by_type(unit, "on_death_respawn"):
		if randf() <= float(sp.get("chance", 0.0)):
			_respawn_unit(unit, float(sp.get("value", 100)) / 100.0)
			return true
	return false

## 获取攻击穿透比例（0.0-1.0，用于伤害计算时无视防御）
static func get_penetration_ratio(attacker: Node) -> float:
	var total: float = 0.0
	for sp in get_specials_by_type(attacker, "on_attack_penetration"):
		# 穿透效果取最大值（不叠加百分比）
		total = maxf(total, float(sp.get("value", 0)) / PERCENT_DIVISOR)
	return total

# ═══════════════════════════════════════════════════════════════════
# 内部实现
# ═══════════════════════════════════════════════════════════════════

## 闪电链：对目标附近敌人造成百分比攻击力的闪电伤害
static func _trigger_chain_lightning(source: Node, primary_target: Node, base_damage: float, damage_ratio: float) -> void:
	var chain_damage: float = base_damage * damage_ratio
	var chain_targets := _find_nearby_enemies(source, primary_target, CHAIN_LIGHTNING_RADIUS, CHAIN_LIGHTNING_MAX_TARGETS)
	# 对主目标也造成闪电伤害
	if is_instance_valid(primary_target) and primary_target.has_method("take_damage"):
		primary_target.take_damage(chain_damage, source)
	# 链式传导（每跳衰减）
	var current_damage: float = chain_damage * CHAIN_LIGHTNING_DECAY
	for target in chain_targets:
		if is_instance_valid(target) and target.has_method("take_damage"):
			target.take_damage(current_damage, source)
			current_damage *= CHAIN_LIGHTNING_DECAY

## 溅射伤害：对目标周围敌人造成百分比伤害
static func _trigger_splash_damage(source: Node, primary_target: Node, base_damage: float, damage_ratio: float) -> void:
	var splash_damage: float = base_damage * damage_ratio
	var splash_targets := _find_nearby_enemies(source, primary_target, SPLASH_RADIUS, SPLASH_MAX_TARGETS)
	for target in splash_targets:
		if is_instance_valid(target) and target.has_method("take_damage"):
			target.take_damage(splash_damage, source)

## 生成护盾
static func _generate_shield(unit: Node, shield_ratio: float) -> void:
	if not unit.has_method("heal") and not unit.has_method("take_damage"):
		return
	# 护盾以临时HP形式体现（恢复一定比例的max_hp）
	var stats = unit.get("stats") if "stats" in unit else null
	if stats == null:
		return
	var max_hp: float = float(stats.max_hp) if "max_hp" in stats else DEFAULT_MAX_HP
	var shield_amount: float = max_hp * shield_ratio * SHIELD_HP_RATIO  # 护盾值=最大HP×比例×系数
	if unit.has_method("heal"):
		unit.heal(shield_amount)

## 复活单位
static func _respawn_unit(unit: Node, hp_ratio: float) -> void:
	var stats = unit.get("stats") if "stats" in unit else null
	if stats == null:
		return
	var max_hp: float = float(stats.max_hp) if "max_hp" in stats else DEFAULT_MAX_HP
	var revive_hp: float = max_hp * hp_ratio
	# 恢复HP
	if "hp" in unit:
		unit.hp = revive_hp
	# 清除死亡标记
	if "_is_dying" in unit:
		unit._is_dying = false
	# 通知单位复活（如果支持）
	if unit.has_method("on_revived"):
		unit.on_revived()

## 查找附近的敌方单位（排除主目标）
static func _find_nearby_enemies(source: Node, primary_target: Node, radius: float, max_count: int) -> Array:
	var result: Array = []
	var is_player: bool = bool(source.get("is_player")) if "is_player" in source else true
	var enemy_group: String = "enemy_units" if is_player else "player_units"
	var tree: SceneTree = source.get_tree() if source is Node else null
	if tree == null:
		return result
	var center: Vector2 = primary_target.global_position if is_instance_valid(primary_target) else source.global_position
	var candidates: Array = []
	# 优先使用 SpatialGrid
	var bm: Node = tree.root.get_node_or_null("BattleManager")
	if bm and is_instance_valid(bm) and "spatial_grid" in bm:
		var grid = bm.spatial_grid
		if grid and grid.has_method("query_nearby"):
			candidates = grid.query_nearby(center, radius)
	if candidates.is_empty():
		candidates = tree.get_nodes_in_group(enemy_group)
	for node in candidates:
		if result.size() >= max_count:
			break
		if not is_instance_valid(node) or node == source or node == primary_target:
			continue
		if not (node is Node2D):
			continue
		if not node.is_in_group(enemy_group):
			continue
		if node.global_position.distance_to(center) <= radius:
			result.append(node)
	return result

## 获取 autoload 节点
static func _get_autoload(from_node: Node, autoload_name: String) -> Node:
	var tree: SceneTree = from_node.get_tree() if from_node is Node else null
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(autoload_name)
