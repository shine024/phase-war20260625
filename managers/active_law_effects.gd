extends Node
## 主动法则战斗效果管理器
## 处理主动法则施放时的实际数值效果

const PhaseLaws = preload("res://data/phase_laws.gd")

## 引力井伤害转换系数：value 为减速比例（0~1），乘以此系数得到实际伤害值
const GRAVITY_WELL_DAMAGE_MULTIPLIER: float = 30.0

## 护盾墙节点缓存（避免每次命中 get_nodes_in_group 全树遍历）
## 注意：不能用 Array[Node2D]，否则已释放实例在读取时会触发 "previously freed instance" 报错
static var _law_shield_wall_nodes: Array = []
static var _shield_wall_counter: int = 0

#region agent log
static func _agent_log(hypothesis_id: String, message: String, data: Dictionary) -> void:
	var f := FileAccess.open("debug-1776fa.log", FileAccess.WRITE_READ)
	if f == null:
		return
	f.seek_end()
	var payload := {
		"sessionId": "1776fa",
		"runId": "law_bullet_debug_v1",
		"hypothesisId": hypothesis_id,
		"location": "active_law_effects.gd",
		"message": message,
		"data": data,
		"timestamp": Time.get_ticks_msec()
	}
	f.store_line(JSON.stringify(payload))
	f.close()
#endregion

static func _has_property(obj: Object, property_name: StringName) -> bool:
	if obj == null:
		return false
	for p in obj.get_property_list():
		if StringName(p.get("name", "")) == property_name:
			return true
	return false

static func _register_law_shield_wall(node: Node2D) -> void:
	if node == null:
		return
	if node in _law_shield_wall_nodes:
		return
	_law_shield_wall_nodes.append(node)
	node.tree_exited.connect(func():
		_law_shield_wall_nodes.erase(node)
	)

static func _compact_shield_wall_cache() -> void:
	var i: int = _law_shield_wall_nodes.size()
	while i > 0:
		i -= 1
		var cached: Variant = _law_shield_wall_nodes[i]
		if not (cached is Node2D) or not is_instance_valid(cached):
			_law_shield_wall_nodes.remove_at(i)

## 应用主动法则效果到战场
static func apply_active_law_effect(law_id: String, world_pos: Vector2, battlefield: Node) -> void:
	var law: Dictionary = PhaseLaws.get_by_id(law_id)
	if law.is_empty():
		#region agent log
		_agent_log("H2_law_apply", "law_config_missing", {"law_id": law_id})
		#endregion
		return
	
	var effect: String = law.get("runtime_tags", {}).get("effect", "")
	var value: float = float(law.get("runtime_tags", {}).get("value", 0.0))
	var radius: float = float(law.get("runtime_tags", {}).get("radius", 200.0))
	var duration: float = float(law.get("runtime_tags", {}).get("duration", 0.0))
	var target_side: String = String(law.get("runtime_tags", {}).get("target_side", "ENEMY"))
	var target_type: String = String(law.get("runtime_tags", {}).get("target_type", "ALL"))
	#region agent log
	_agent_log("H2_law_apply", "law_apply_entry", {
		"law_id": law_id,
		"effect": effect,
		"value": value,
		"radius": radius,
		"duration": duration,
		"target_side": target_side,
		"target_type": target_type
	})
	#endregion
	
	match effect:
		"aoe_emp":
			_apply_emp_effect(battlefield, world_pos, radius, value, duration, target_side, target_type)
		"line_bombard":
			_apply_line_bombard(battlefield, world_pos, radius, value, target_side, target_type)
		"chain_lightning":
			_apply_chain_lightning(battlefield, world_pos, radius, value, target_side, target_type)
		"burn_mark":
			_apply_burn_mark(battlefield, world_pos, radius, value, duration, target_side, target_type)
		"global_time_slow":
			_apply_time_slow(battlefield, value, duration)
		"spawn_shield_wall":
			_apply_shield_wall(battlefield, world_pos, radius, value, duration)
		"hp_shield_shift":
			_apply_hp_shield_shift(battlefield, world_pos, radius, value, duration, target_side, target_type)
		"anchor_field":
			_apply_anchor_field(battlefield, world_pos, radius, value, duration, target_side, target_type)
		"scorch_wave":
			_apply_scorch_wave(battlefield, world_pos, radius, value, target_side, target_type)
		"ember_screen":
			_apply_ember_screen(battlefield, world_pos, radius, value, duration, target_side, target_type)
		"core_rupture":
			_apply_core_rupture(battlefield, world_pos, radius, value, target_side, target_type)
		"ion_net":
			_apply_ion_net(battlefield, world_pos, radius, value, duration, target_side, target_type)
		"surge_drive":
			_apply_surge_drive(battlefield, world_pos, value, duration, target_side, target_type)
		"static_domain":
			_apply_static_domain(battlefield, world_pos, radius, value, duration, target_side, target_type)
		"phase_cloak":
			_apply_phase_cloak(battlefield, world_pos, radius, value, duration, target_side, target_type)
		"gravity_well":
			_apply_gravity_well(battlefield, world_pos, radius, value, duration, target_side, target_type)
		_:
			push_warning("ActiveLawEffects: 未实现的效果类型: " + effect)

## AOE EMP - 电磁脉冲
static func _apply_emp_effect(battlefield: Node, center: Vector2, radius: float, damage: float, duration: float, target_side: String, target_type: String) -> void:
	if battlefield == null:
		return
	for unit in _get_target_units(battlefield, target_side, target_type):
		var unit_2d: Node2D = unit as Node2D
		if unit_2d == null:
			continue
		var dist: float = unit_2d.global_position.distance_to(center)
		if dist <= radius:
			# 对范围内所有敌人造成伤害
			if unit.has_method("take_damage"):
				unit.take_damage(damage)
			_apply_temporary_attack_slow(unit, 0.2, duration)

static func _get_target_units(battlefield: Node, target_side: String, target_type: String) -> Array:
	var units: Array = []
	if battlefield == null:
		return units
	var side_upper: String = target_side.to_upper()
	if side_upper == "ENEMY" or side_upper == "BOTH":
		var enemy_units = battlefield.get_node_or_null("EnemyUnits")
		if enemy_units != null:
			for unit in enemy_units.get_children():
				if is_instance_valid(unit) and _is_target_type_match(unit, target_type):
					units.append(unit)
		var enemy_driver: Node = battlefield.get_node_or_null("EnemyPhaseFieldDriver")
		if is_instance_valid(enemy_driver) and _is_target_type_match(enemy_driver, target_type):
			units.append(enemy_driver)
	if side_upper == "ALLY" or side_upper == "BOTH":
		var player_units = battlefield.get_node_or_null("PlayerUnits")
		if player_units != null:
			for unit2 in player_units.get_children():
				if is_instance_valid(unit2) and _is_target_type_match(unit2, target_type):
					units.append(unit2)
		var player_driver: Node = battlefield.get_node_or_null("PhaseFieldDriver")
		if is_instance_valid(player_driver) and _is_target_type_match(player_driver, target_type):
			units.append(player_driver)
	return units

static func _is_target_type_match(unit: Node, target_type: String) -> bool:
	var tt: String = target_type.to_upper()
	if tt == "ALL" or tt.is_empty():
		return true
	if tt == "VEHICLE":
		return unit is CharacterBody2D
	if tt == "INFANTRY":
		# TODO: 步兵/载具区分 — 当前所有战场单位均为 CharacterBody2D，暂按同等处理
		return unit is CharacterBody2D
	return true

## 线型轰炸
static func _apply_line_bombard(battlefield: Node, center: Vector2, length: float, damage: float, target_side: String, target_type: String) -> void:
	if battlefield == null:
		return
	# 从中心向右侧延伸的矩形区域
	var rect := Rect2(center.x, center.y - 50, length, 100)
	for unit in _get_target_units(battlefield, target_side, target_type):
		if rect.has_point(unit.global_position):
			if unit.has_method("take_damage"):
				unit.take_damage(damage)

## 链式放电
static func _apply_chain_lightning(battlefield: Node, center: Vector2, radius: float, damage: float, target_side: String, target_type: String) -> void:
	if battlefield == null:
		return
	# 找到范围内的敌人并链式传导
	var targets: Array = []
	for unit in _get_target_units(battlefield, target_side, target_type):
		var unit_2d: Node2D = unit as Node2D
		if unit_2d == null:
			continue
		var dist: float = unit_2d.global_position.distance_to(center)
		if dist <= radius:
			targets.append(unit)
	# 对每个目标造成伤害（简化版：全部伤害）
	for target in targets:
		if is_instance_valid(target) and target.has_method("take_damage"):
			target.take_damage(damage / max(1, targets.size()))

## 灼烧印记
static func _apply_burn_mark(battlefield: Node, center: Vector2, radius: float, damage_per_sec: float, duration: float, target_side: String, target_type: String) -> void:
	if battlefield == null:
		return
	# 灼烧 - 立即造成持续伤害的一部分作为初始伤害
	for unit in _get_target_units(battlefield, target_side, target_type):
		var unit_2d: Node2D = unit as Node2D
		if unit_2d == null:
			continue
		var dist: float = unit_2d.global_position.distance_to(center)
		if dist <= radius:
			if unit.has_method("take_damage"):
				# 灼烧伤害
				unit.take_damage(damage_per_sec * duration * 0.5)

## 全局时间减速（战场单位级，不影响 UI）
static func _apply_time_slow(battlefield: Node, slow_factor: float, duration: float) -> void:
	if battlefield == null:
		return
	# 对战场所有单位施加减速（不使用 Engine.time_scale，避免影响 UI 响应）
	var all_units: Array = []
	var enemy_container = battlefield.get_node_or_null("EnemyUnits")
	if enemy_container != null:
		for u in enemy_container.get_children():
			if is_instance_valid(u):
				all_units.append(u)
	var player_container = battlefield.get_node_or_null("PlayerUnits")
	if player_container != null:
		for u in player_container.get_children():
			if is_instance_valid(u):
				all_units.append(u)
	var speed_scale: float = max(0.1, 1.0 - slow_factor)
	for unit in all_units:
		_apply_temporary_speed_scale(unit, speed_scale, duration)
		_apply_temporary_attack_slow(unit, slow_factor * 0.5, duration)

## 生成护盾墙
static func _apply_shield_wall(battlefield: Node, center: Vector2, radius: float, mitigation: float, duration: float) -> void:
	if battlefield == null:
		return
	# 创建一个护盾墙实体（可视化的持续存在物）
	var shield := Node2D.new()
	var wall_id: int = _shield_wall_counter
	_shield_wall_counter += 1
	shield.set_name("ShieldWall_%d" % wall_id)
	shield.add_to_group("law_shield_wall")
	shield.position = center
	battlefield.add_child(shield)
	# 设置护盾属性
	shield.set("mitigation", mitigation)
	shield.set("radius", radius)
	shield.set("side", "ALLY")
	shield.set("expiration_time", Time.get_ticks_msec() / 1000.0 + duration)
	_register_law_shield_wall(shield)
	# 定时移除
	var captured_shield = shield
	Engine.get_main_loop().create_timer(max(0.1, duration)).timeout.connect(func() -> void:
		if is_instance_valid(captured_shield):
			captured_shield.queue_free()
	)

## HP护盾转移
static func _apply_hp_shield_shift(battlefield: Node, center: Vector2, radius: float, shield_ratio: float, duration: float, target_side: String, target_type: String) -> void:
	if battlefield == null:
		return
	# 为范围内友军提供临时护盾
	for unit in _get_target_units(battlefield, target_side, target_type):
		var unit_2d: Node2D = unit as Node2D
		if unit_2d == null:
			continue
		var dist: float = unit_2d.global_position.distance_to(center)
		if dist <= radius:
			if unit.has_method("add_shield"):
				var hp := 100.0
				if unit.has_method("get"):
					var stats = unit.get("stats")
					if stats != null:
						hp = stats.max_hp
				var shield_amount: float = hp * shield_ratio
				unit.add_shield(shield_amount)
				# duration > 0 时在到期后移除同量护盾，避免”持续”参数无意义。
				# 注意：多条法则叠加时，若护盾被部分消耗后到期移除固定值，可能出现数值偏差
				if duration > 0.0 and _has_property(unit, &"shield"):
					var captured_unit = unit
					var captured_shield_amount: float = shield_amount
					Engine.get_main_loop().create_timer(max(0.1, duration)).timeout.connect(func() -> void:
						if is_instance_valid(captured_unit):
							var cur_shield: float = float(captured_unit.get("shield"))
							captured_unit.set("shield", maxf(0.0, cur_shield - captured_shield_amount))
					)

## 锚定力场：范围敌军减速（value 作为减速比例）
static func _apply_anchor_field(battlefield: Node, center: Vector2, radius: float, value: float, duration: float, target_side: String, target_type: String) -> void:
	if battlefield == null:
		return
	for unit in _get_target_units(battlefield, target_side, target_type):
		var unit_2d: Node2D = unit as Node2D
		if unit_2d == null:
			continue
		if unit_2d.global_position.distance_to(center) <= radius:
			_apply_temporary_speed_scale(unit, max(0.2, 1.0 - value), duration)

## 范围即时伤害（通用）
static func _apply_damage_in_radius(battlefield: Node, center: Vector2, radius: float, damage: float, target_side: String, target_type: String) -> void:
	if battlefield == null:
		return
	for unit in _get_target_units(battlefield, target_side, target_type):
		var unit_2d: Node2D = unit as Node2D
		if unit_2d == null:
			continue
		if unit_2d.global_position.distance_to(center) <= radius and unit.has_method("take_damage"):
			unit.take_damage(damage)

## 灼浪推进：范围即时伤害
static func _apply_scorch_wave(battlefield: Node, center: Vector2, radius: float, damage: float, target_side: String, target_type: String) -> void:
	_apply_damage_in_radius(battlefield, center, radius, damage, target_side, target_type)

## 灰烬幕障：范围友军获得临时护盾（持续时间结束后移除）
static func _apply_ember_screen(battlefield: Node, center: Vector2, radius: float, shield_ratio: float, duration: float, target_side: String, target_type: String) -> void:
	if battlefield == null:
		return
	for unit in _get_target_units(battlefield, target_side, target_type):
		var unit_2d: Node2D = unit as Node2D
		if unit_2d == null:
			continue
		if unit_2d.global_position.distance_to(center) > radius:
			continue
		var shield_amount: float = 0.0
		if unit.has_method("add_shield"):
			var hp := 100.0
			var stats = unit.get("stats") if unit.has_method("get") else null
			if stats != null:
				hp = float(stats.max_hp)
			shield_amount = hp * shield_ratio
			unit.add_shield(shield_amount)
			# 持续时间结束后移除护盾（与 hp_shield_shift 同模式）
			# 注意：多条法则叠加时，若护盾被部分消耗后到期移除固定值，可能出现数值偏差
		if duration > 0.0 and shield_amount > 0.0:
			var captured_target_unit: Node = unit as Node
			var captured_shield_amount: float = float(shield_amount)
			Engine.get_main_loop().create_timer(max(0.1, duration)).timeout.connect(func() -> void:
				if is_instance_valid(captured_target_unit):
					var cur_shield: float = float(captured_target_unit.get("shield"))
					captured_target_unit.set("shield", maxf(0.0, cur_shield - captured_shield_amount))
			)

## 核心破裂：范围高伤害（对载具）
static func _apply_core_rupture(battlefield: Node, center: Vector2, radius: float, damage: float, target_side: String, target_type: String) -> void:
	_apply_damage_in_radius(battlefield, center, radius, damage, target_side, target_type)

## 离子网：范围减速并减攻速
static func _apply_ion_net(battlefield: Node, center: Vector2, radius: float, value: float, duration: float, target_side: String, target_type: String) -> void:
	if battlefield == null:
		return
	for unit in _get_target_units(battlefield, target_side, target_type):
		var unit_2d: Node2D = unit as Node2D
		if unit_2d == null:
			continue
		if unit_2d.global_position.distance_to(center) > radius:
			continue
		_apply_temporary_speed_scale(unit, max(0.2, 1.0 - value), duration)
		_apply_temporary_attack_slow(unit, value, duration)

## 激涌驱动：全体友军加速并提攻速（value 作为加成比例）
static func _apply_surge_drive(battlefield: Node, _center: Vector2, value: float, duration: float, target_side: String, target_type: String) -> void:
	if battlefield == null:
		return
	for unit in _get_target_units(battlefield, target_side, target_type):
		_apply_temporary_speed_scale(unit, 1.0 + value, duration)
		_apply_temporary_attack_haste(unit, value, duration)

## 静电域：范围伤害并减攻速
static func _apply_static_domain(battlefield: Node, center: Vector2, radius: float, damage: float, duration: float, target_side: String, target_type: String) -> void:
	if battlefield == null:
		return
	for unit in _get_target_units(battlefield, target_side, target_type):
		var unit_2d: Node2D = unit as Node2D
		if unit_2d == null:
			continue
		if unit_2d.global_position.distance_to(center) > radius:
			continue
		if unit.has_method("take_damage"):
			unit.take_damage(damage)
		_apply_temporary_attack_slow(unit, 0.25, duration)

## 相位披幕：范围友军护盾（复用灰烬幕障逻辑，数据层区分数值）
static func _apply_phase_cloak(battlefield: Node, center: Vector2, radius: float, shield_ratio: float, duration: float, target_side: String, target_type: String) -> void:
	_apply_ember_screen(battlefield, center, radius, shield_ratio, duration, target_side, target_type)

## 引力井：范围减速 + 持续伤害
static func _apply_gravity_well(battlefield: Node, center: Vector2, radius: float, value: float, duration: float, target_side: String, target_type: String) -> void:
	if battlefield == null:
		return
	for unit in _get_target_units(battlefield, target_side, target_type):
		var unit_2d: Node2D = unit as Node2D
		if unit_2d == null:
			continue
		if unit_2d.global_position.distance_to(center) > radius:
			continue
		_apply_temporary_speed_scale(unit, max(0.15, 1.0 - value), duration)
		if unit.has_method("take_damage"):
			unit.take_damage(value * GRAVITY_WELL_DAMAGE_MULTIPLIER)

static func _apply_temporary_speed_scale(unit: Node, speed_scale: float, duration: float) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if not unit.has_method("get") or not unit.has_method("set"):
		return
	var has_move_speed := _has_property(unit, &"move_speed")
	var old_move_speed: float = 0.0
	var old_velocity: Vector2 = Vector2.ZERO
	if has_move_speed:
		old_move_speed = float(unit.get("move_speed"))
		unit.set("move_speed", old_move_speed * speed_scale)
	else:
		var ov: Variant = unit.get("velocity")
		if typeof(ov) != TYPE_VECTOR2:
			return
		old_velocity = ov
		unit.set("velocity", old_velocity * speed_scale)
	var dur: float = maxf(0.1, duration)
	Engine.get_main_loop().create_timer(dur).timeout.connect(func() -> void:
		if is_instance_valid(unit):
			if has_move_speed:
				unit.set("move_speed", old_move_speed)
			else:
				unit.set("velocity", old_velocity)
	)

static func get_shield_wall_mitigation_for_point(point: Vector2, target_side: String = "ALLY") -> float:
	_compact_shield_wall_cache()
	var best: float = 0.0
	for cached in _law_shield_wall_nodes:
		if not (cached is Node2D) or not is_instance_valid(cached):
			continue
		var node: Node2D = cached as Node2D
		var side: String = String(node.get("side"))
		if side != "BOTH" and side != target_side:
			continue
		var radius: float = float(node.get("radius"))
		var mitigation: float = float(node.get("mitigation"))
		if node.global_position.distance_to(point) <= radius:
			best = maxf(best, mitigation)
	return clampf(best, 0.0, 0.85)

static func _apply_temporary_attack_slow(unit: Node, slow_ratio: float, duration: float) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if not unit.has_method("get") or not unit.has_method("set"):
		return
	var has_interval := false
	var base_interval: float = 1.0
	if _has_property(unit, &"attack_interval"):
		base_interval = float(unit.get("attack_interval"))
		has_interval = true
	if has_interval:
		unit.set("attack_interval", base_interval * (1.0 + max(0.0, slow_ratio)))
		var dur: float = maxf(0.1, duration)
		Engine.get_main_loop().create_timer(dur).timeout.connect(func() -> void:
			if is_instance_valid(unit):
				unit.set("attack_interval", base_interval)
		)

static func _apply_temporary_attack_haste(unit: Node, haste_ratio: float, duration: float) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if not unit.has_method("get") or not unit.has_method("set"):
		return
	if not _has_property(unit, &"attack_interval"):
		return
	var base_interval: float = float(unit.get("attack_interval"))
	unit.set("attack_interval", max(0.1, base_interval * (1.0 - max(0.0, haste_ratio))))
	var dur: float = maxf(0.1, duration)
	Engine.get_main_loop().create_timer(dur).timeout.connect(func() -> void:
		if is_instance_valid(unit):
			unit.set("attack_interval", base_interval)
	)
