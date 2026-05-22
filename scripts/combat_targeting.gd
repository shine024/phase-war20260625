extends RefCounted
class_name CombatTargeting
## 索敌与超射程衰减：无战斗单位时攻击对方相位场；超射程降低命中与伤害。

## 超出 attack_range 后，在 attack_range * SPAN 距离内线性衰减，最低保留 30% 命中与伤害
const RANGE_FALLOFF_SPAN_MULT: float = 3.0
const MIN_FALLOFF_MULT: float = 0.30
const CARD_GRID_ENEMY_ACQUISITION_MIN: float = 1600.0

static func range_falloff(dist: float, attack_range: float) -> Dictionary:
	if attack_range <= 0.5:
		return {"p_hit": 1.0, "damage_mult": 1.0}
	if dist <= attack_range:
		return {"p_hit": 1.0, "damage_mult": 1.0}
	var over: float = dist - attack_range
	var t: float = over / maxf(attack_range * RANGE_FALLOFF_SPAN_MULT, 1.0)
	var mult: float = clampf(1.0 - t * (1.0 - MIN_FALLOFF_MULT), MIN_FALLOFF_MULT, 1.0)
	return {"p_hit": mult, "damage_mult": mult}


static func card_grid_enemy_acquisition_range(attack_range: float, combat_started: bool) -> float:
	var r: float = attack_range
	if combat_started:
		r *= 2.6
	return maxf(r, CARD_GRID_ENEMY_ACQUISITION_MIN)


static func count_alive_in_group(group_name: String, battle_manager: Node) -> int:
	var nodes: Array
	if battle_manager != null and battle_manager.has_method("get_cached_nodes_in_group"):
		nodes = battle_manager.get_cached_nodes_in_group(group_name)
	else:
		var tree := Engine.get_main_loop() as SceneTree
		if tree == null:
			return 0
		nodes = tree.get_nodes_in_group(group_name)
	var n: int = 0
	for node in nodes:
		if node == null or not is_instance_valid(node):
			continue
		if node is CharacterBody2D or node.has_method("take_damage"):
			if "hp" in node and float(node.hp) <= 0.0:
				continue
			n += 1
	return n


static func has_alive_player_units(battle_manager: Node) -> bool:
	return count_alive_in_group("player_units", battle_manager) > 0


static func has_alive_enemy_units(battle_manager: Node) -> bool:
	return count_alive_in_group("enemy_units", battle_manager) > 0


static func is_phase_field_node(node) -> bool:
	if node == null or not is_instance_valid(node) or not (node is Node):
		return false
	var n: Node = node as Node
	return n.is_in_group("phase_driver") or n.is_in_group("enemy_phase_driver")


## 对方战斗单位已上场时，应放弃相位场目标并重新索敌
static func should_drop_phase_field_target(target, attacker_is_player: bool, battle_manager: Node) -> bool:
	if not is_phase_field_node(target):
		return false
	if attacker_is_player:
		return has_alive_enemy_units(battle_manager)
	return has_alive_player_units(battle_manager)


static func is_attackable_combat_unit(node) -> bool:
	if node == null or not is_instance_valid(node) or not (node is Node):
		return false
	var n: Node = node as Node
	if is_phase_field_node(n):
		return false
	if "is_preview_mode" in n and bool(n.is_preview_mode):
		return false
	if "hp" in n and float(n.hp) <= 0.0:
		return false
	return n is CharacterBody2D or n.has_method("take_damage")


static func opponent_phase_field_group(attacker_is_player: bool) -> String:
	return "enemy_phase_driver" if attacker_is_player else "phase_driver"


## 场上无对方战斗单位时，选取最近相位场（max_range <= 0 表示不限距离）
static func find_opponent_phase_field(
	origin: Vector2,
	attacker_is_player: bool,
	battle_manager: Node,
	max_range: float = 2400.0
) -> Node2D:
	var grp: String = opponent_phase_field_group(attacker_is_player)
	var nodes: Array
	if battle_manager != null and battle_manager.has_method("get_cached_nodes_in_group"):
		nodes = battle_manager.get_cached_nodes_in_group(grp)
	else:
		var tree := Engine.get_main_loop() as SceneTree
		if tree == null:
			return null
		nodes = tree.get_nodes_in_group(grp)
	var best: Node2D = null
	var best_d2: float = 1e18
	var cap_sq: float = max_range * max_range if max_range > 0.0 else 1e18
	for node in nodes:
		if node == null or not is_instance_valid(node) or not (node is Node2D):
			continue
		var d2: float = origin.distance_squared_to((node as Node2D).global_position)
		if d2 < best_d2 and d2 <= cap_sq:
			best_d2 = d2
			best = node as Node2D
	return best
