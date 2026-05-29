extends Node2D
## 子弹/激光/导弹等：按武器类型显示不同攻击动画，飞向目标造成伤害

const GC = preload("res://resources/game_constants.gd")
const CombatFeedback = preload("res://scripts/combat_feedback.gd")
const AffixCombatHandler = preload("res://managers/affix_combat_handler.gd")
const ActiveLawEffects = preload("res://managers/active_law_effects.gd")
const CardAbilityManager = preload("res://managers/card_ability_manager.gd")
const CardGridFx = preload("res://scripts/card_grid_fx.gd")
const WeaponProjectileVfx = preload("res://scripts/weapon_projectile_vfx.gd")
const AttackCalculator = preload("res://scripts/battle/attack_calculator.gd")
# ObjectPoolManager 为 autoload

var speed: float = 600.0
var damage: float = 5.0
var target: Node2D = null
var shooter_is_player: bool = true
var max_distance: float = 1600.0
var weapon_type: int = 0
var shooter: Node2D = null  # 射手引用（用于词条效果）
var shooter_stats: UnitStats = null  # 射手数值（用于词条效果计算）
## 超射程「哑弹」：飞过但不造成伤害（仍可对卡牌模式播放擦弹表现）
var forced_miss: bool = false

# 行为参数：由武器类型决定
var pierce_count: int = 0          # 可额外穿透多少个目标（LASER/SNIPER 用）
var explosion_radius: float = 0.0  # >0 时命中产生范围伤害（ROCKET/MISSILE/FLAK）
var pellet_count: int = 1          # 霰弹多发
var spread_angle_deg: float = 0.0  # 多发散射角

var _start_position: Vector2
var _sprite: Polygon2D
var _beam_line: Line2D
var _tex_sprite: Sprite2D
var _trail_sprite: Sprite2D
var _use_tex_sprite: bool = false
var _direction: Vector2 = Vector2.RIGHT
var _beam_visual_phase: int = 0
const BEAM_VISUAL_LEN: float = 52.0
var _beam_pts: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
var _dbg_spawn_logged: bool = false

#region agent log
func _agent_log(hypothesis_id: String, message: String, data: Dictionary) -> void:
	var f := FileAccess.open("debug-1776fa.log", FileAccess.WRITE_READ)
	if f == null:
		return
	f.seek_end()
	var payload := {
		"sessionId": "1776fa",
		"runId": "law_bullet_debug_v1",
		"hypothesisId": hypothesis_id,
		"location": "bullet.gd",
		"message": message,
		"data": data,
		"timestamp": Time.get_ticks_msec()
	}
	f.store_line(JSON.stringify(payload))
	f.close()
#endregion

func _apply_shield_wall_mitigation(raw_damage: float, target: Node) -> float:
	if target == null or not is_instance_valid(target):
		return raw_damage
	# 护盾墙主要保护我方单位/基地，且只对敌方射弹生效
	if shooter_is_player:
		return raw_damage
	if not (target is CharacterBody2D or target.is_in_group("phase_driver")):
		return raw_damage
	var mitigation: float = ActiveLawEffects.get_shield_wall_mitigation_for_point(target.global_position, "ALLY")
	if mitigation <= 0.0:
		return raw_damage
	return raw_damage * (1.0 - mitigation)

func setup(p_target: Node2D, p_damage: float, p_is_player: bool, p_weapon_type: int = -1, p_shooter: Node2D = null, p_shooter_stats: UnitStats = null, p_forced_miss: bool = false) -> void:
	visible = true
	_dbg_spawn_logged = false
	target = p_target
	damage = p_damage
	shooter_is_player = p_is_player
	shooter = p_shooter
	shooter_stats = p_shooter_stats
	forced_miss = p_forced_miss
	if p_weapon_type >= 0:
		weapon_type = p_weapon_type
	_start_position = global_position
	_direction = Vector2.RIGHT
	_sprite = get_node_or_null("Sprite") as Polygon2D
	_beam_line = get_node_or_null("BeamLine") as Line2D
	_tex_sprite = get_node_or_null("TexSprite") as Sprite2D
	_trail_sprite = get_node_or_null("TrailSprite") as Sprite2D
	_apply_visual()
	_configure_behavior()
	_beam_visual_phase = 0
	#region agent log
	_agent_log("H3_bullet_spawn", "bullet_setup", {
		"is_player": shooter_is_player,
		"weapon_type": weapon_type,
		"visible": visible,
		"target_valid": target != null and is_instance_valid(target),
		"parent_name": get_parent().name if get_parent() != null else ""
	})
	#endregion

func _configure_behavior() -> void:
	# 基础：大多数子弹直线追踪目标
	speed = 600.0
	max_distance = 1600.0
	pierce_count = 0
	explosion_radius = 0.0
	pellet_count = 1
	spread_angle_deg = 0.0

	match weapon_type:
		0, 4:
			speed = 720.0
			max_distance = 1200.0
		1:
			speed = 800.0
			max_distance = 1600.0
		2:
			speed = 680.0
			max_distance = 1400.0
		5:
			speed = 650.0
			max_distance = 900.0
			pellet_count = 6
			spread_angle_deg = 18.0
		6:
			speed = 1100.0
			max_distance = 2200.0
			pierce_count = 1
		8:
			speed = 1400.0
			max_distance = 2200.0
			pierce_count = 3
		3:
			speed = 420.0
			max_distance = 2000.0
			explosion_radius = 40.0
		9:
			speed = 380.0
			max_distance = 2300.0
			explosion_radius = 55.0
		7:
			speed = 520.0
			max_distance = 1500.0
			explosion_radius = 36.0
		11:  # RAIL_CANNON
			speed = 560.0
			max_distance = 2500.0
			explosion_radius = 58.0
			pierce_count = 1
		10:  # OMEGA_CANNON
			speed = 520.0
			max_distance = 2600.0
			explosion_radius = 70.0
			pierce_count = 2

	# 霰弹：在本弹上直接设置随机初始方向偏移
	if pellet_count > 1:
		var base_dir := Vector2.RIGHT
		if target and is_instance_valid(target):
			base_dir = (target.global_position - global_position).normalized()
		var half_spread := spread_angle_deg * 0.5
		var rand_angle := randf_range(-half_spread, half_spread)
		_direction = base_dir.rotated(deg_to_rad(rand_angle))
	else:
		if target and is_instance_valid(target):
			_direction = (target.global_position - global_position).normalized()

func _apply_visual() -> void:
	var is_player: bool = shooter_is_player
	_use_tex_sprite = WeaponProjectileVfx.has_proj_texture(weapon_type)
	if _use_tex_sprite:
		_apply_tex_sprite_visual(is_player)
		return
	_hide_tex_sprite_visual()
	var bullet_color: Color
	var beam_color: Color
	var use_beam: bool = false
	var size_scale: float = 1.0
	match weapon_type:
		0, 4:
			bullet_color = Color(0.95, 0.9, 0.3) if is_player else Color(1, 0.4, 0.2)
			size_scale = 0.8
		1, 2:
			bullet_color = Color(0.85, 0.85, 0.9) if is_player else Color(0.9, 0.5, 0.3)
			size_scale = 1.0
		5:
			bullet_color = Color(0.9, 0.85, 0.5) if is_player else Color(1, 0.5, 0.2)
			size_scale = 1.2
		6:
			use_beam = true
			beam_color = Color(0.4, 0.9, 1) if is_player else Color(1, 0.5, 0.4)
		8:
			use_beam = true
			beam_color = Color(0.2, 0.85, 1) if is_player else Color(1, 0.3, 0.6)
		3, 9:
			bullet_color = Color(0.9, 0.5, 0.1) if is_player else Color(1, 0.35, 0.15)
			size_scale = 1.8
		7:
			bullet_color = Color(0.8, 0.75, 0.6) if is_player else Color(0.95, 0.6, 0.3)
			size_scale = 0.6
		11:  # RAIL_CANNON
			bullet_color = Color(0.5, 0.55, 1) if is_player else Color(1, 0.25, 0.45)
			size_scale = 1.85
		_:
			bullet_color = Color(0.9, 0.9, 0.95) if is_player else Color(0.9, 0.35, 0.25)
	if _sprite:
		_sprite.visible = not use_beam
		if not use_beam:
			_sprite.color = bullet_color
			var pts: PackedVector2Array = PackedVector2Array([Vector2(-2,-2)*size_scale, Vector2(4,0)*size_scale, Vector2(-2,2)*size_scale])
			_sprite.polygon = pts
	if _beam_line:
		_beam_line.visible = use_beam
		if use_beam:
			_beam_line.default_color = beam_color
			_beam_line.width = 3.0 if weapon_type == 6 else 4.5


func _apply_tex_sprite_visual(is_player: bool) -> void:
	if _sprite:
		_sprite.visible = false
	if _beam_line:
		_beam_line.visible = false
	var tint := Color.WHITE if is_player else Color(1.0, 0.38, 0.52)
	var sc := WeaponProjectileVfx.proj_scale(weapon_type)
	if _tex_sprite:
		_tex_sprite.visible = true
		_tex_sprite.texture = WeaponProjectileVfx.proj_texture(weapon_type)
		_tex_sprite.scale = Vector2(sc, sc)
		_tex_sprite.modulate = tint
	if _trail_sprite:
		_trail_sprite.visible = false


func _hide_tex_sprite_visual() -> void:
	if _tex_sprite:
		_tex_sprite.visible = false
	if _trail_sprite:
		_trail_sprite.visible = false


func _spawn_tex_impact_at(world_pos: Vector2) -> void:
	var parent := get_parent()
	if parent == null:
		return
	WeaponProjectileVfx.spawn_impact(parent, world_pos, weapon_type, shooter_is_player)


func _finish_tex_bullet() -> void:
	ObjectPoolManager.return_object("bullets", self)


func _process(delta: float) -> void:
	if not _dbg_spawn_logged:
		_dbg_spawn_logged = true
		#region agent log
		_agent_log("H3_bullet_spawn", "bullet_process_first_tick", {
			"visible": visible,
			"global_position": global_position,
			"target_valid": target != null and is_instance_valid(target)
		})
		#endregion
	# 目标死亡时：非导引弹直接消失，导引类仍按最后方向飞行
	if target == null or not is_instance_valid(target):
		if weapon_type in [9, 3]:
			# 继续沿当前方向飞一段距离
			global_position += _direction * speed * delta
		else:
			_finish_tex_bullet()
			return
	else:
		# 激光/狙击等保持精准指向目标，其他武器略带跟踪
		if weapon_type in [8, 6, 9]:
			_direction = (target.global_position - global_position).normalized()
		else:
			var desired := (target.global_position - global_position).normalized()
			_direction = _direction.lerp(desired, 0.15).normalized()
		global_position += _direction * speed * delta
	if _use_tex_sprite:
		rotation = _direction.angle()
	# 光束类：每 3 帧更新线段（命中判定仍每帧）
	if _beam_line and _beam_line.visible:
		if _beam_visual_phase % 3 == 0:
			var tail_world: Vector2 = global_position - _direction.normalized() * BEAM_VISUAL_LEN
			_beam_pts.set(0, to_local(tail_world))
			_beam_pts.set(1, Vector2.ZERO)
			_beam_line.points = _beam_pts
		_beam_visual_phase += 1
	var max_d2: float = max_distance * max_distance
	if global_position.distance_squared_to(_start_position) > max_d2:
		_finish_tex_bullet()
		return
	if target and is_instance_valid(target) and global_position.distance_squared_to(target.global_position) < 100.0:
		_on_hit(target)

## 爆炸/溅射候选：优先空间网格，避免遍历父节点下全部子节点。
func _get_aoe_damage_targets(center: Vector2, radius: float, primary: Node2D) -> Array:
	var targets: Array = []
	var r2: float = radius * radius
	var tree := get_tree()
	var bm: Node = tree.root.get_node_or_null("BattleManager") if tree else null
	if bm != null and is_instance_valid(bm) and bm.get("battle_active") == true:
		var grid: Variant = bm.get("spatial_grid")
		if grid != null and is_instance_valid(grid) and grid.has_method("query_nearby"):
			for node in grid.query_nearby(center, radius):
				if node == primary or not is_instance_valid(node):
					continue
				if not (node is Node2D):
					continue
				if not node.has_method("take_damage"):
					continue
				if node.global_position.distance_squared_to(center) > r2:
					continue
				targets.append(node)
			return targets
	if primary.get_parent():
		var parent := primary.get_parent()
		for child in parent.get_children():
			if child == primary:
				continue
			if child is Node2D and child.has_method("take_damage"):
				if child.global_position.distance_squared_to(center) <= r2:
					targets.append(child)
	return targets

func _on_hit(primary: Node2D) -> void:
	if forced_miss:
		var miss_pos: Vector2 = primary.global_position if primary else global_position
		CombatFeedback.show_miss(miss_pos, primary)
		if _use_tex_sprite:
			_spawn_tex_impact_at(miss_pos)
		elif GameManager and GameManager.has_method("is_card_grid_battle") and GameManager.is_card_grid_battle():
			var root := get_parent() as Node2D
			if root != null:
				CardGridFx.spawn_impact(root, miss_pos, weapon_type)
		_finish_tex_bullet()
		return
	if not _use_tex_sprite and GameManager and GameManager.has_method("is_card_grid_battle") and GameManager.is_card_grid_battle():
		var root2 := get_parent() as Node2D
		if root2 != null:
			CardGridFx.spawn_impact(root2, primary.global_position if primary else global_position, weapon_type)
	# 如果没有射手数值信息，使用基础伤害逻辑
	if shooter_stats == null:
		_on_hit_basic(primary)
		return
	
	# 格子战：百分比护甲减伤与闪避在 take_damage（CardGridDamage）结算；穿甲仍作用于 shooter_stats
	var defender_reduction: float = 0.0
	if GameManager == null or not GameManager.is_card_grid_battle():
		defender_reduction = primary.damage_reduction if primary != null and "damage_reduction" in primary else 0.0
	# v5.0: 击穿检查 + 三维防御减免 100/(100+def)
	var primary_stats: UnitStats = primary.get("stats") as UnitStats if primary != null else null
	if primary_stats != null and shooter_stats != null:
		var def_val: float = AttackCalculator.get_defense_vs(primary_stats, shooter_stats.combat_kind)
		# 击穿检查: attack <= defense → 伤害=0
		if damage <= def_val:
			# 伤害被完全吸收，仍然需要执行miss等后续逻辑
			_on_hit_basic(primary)
			return
		# 防御减免: damage × 100/(100+def)
		damage = damage * (100.0 / (100.0 + def_val))
	# v5.0: 强化加成（enhance_level 乘法）
	if shooter_stats != null and shooter_stats.enhance_level > 0:
		var enhance_mult := 1.0 + float(shooter_stats.enhance_level) * 0.05
		if shooter_stats.enhance_level >= 9:
			enhance_mult = 1.50
		elif shooter_stats.enhance_level >= 10:
			enhance_mult = 1.60
		damage *= enhance_mult
	var damage_calc: Dictionary = AffixCombatHandler.calculate_damage(
		damage,
		shooter_stats,
		primary.hp if primary != null and "hp" in primary else 0.0,
		primary.max_hp if primary != null and "max_hp" in primary else 1.0,
		defender_reduction
	)
	
	var final_damage: float = damage_calc["final_damage"]
	var is_crit: bool = damage_calc["is_crit"]
	
	# 武器伤害变异：15% 概率双倍伤害
	if shooter_stats.has_weapon_dmg_mutation and randf() < 0.15:
		final_damage *= 2.0

	# 卡牌特殊能力：命中前修改伤害（射手节点已释放时禁止传入 on_bullet_hit 的 Node2D 形参）
	var ability_result: Dictionary = {"damage_bonus": 0.0, "damage_mult_bonus": 0.0}
	if is_instance_valid(shooter):
		ability_result = CardAbilityManager.on_bullet_hit(
			shooter, primary, shooter_stats, global_position,
			damage, final_damage, shooter_is_player
		)
	final_damage += ability_result["damage_bonus"]
	final_damage *= (1.0 + ability_result["damage_mult_bonus"])
	
	# 范围伤害
	if explosion_radius > 0.0:
		for child in _get_aoe_damage_targets(global_position, explosion_radius, primary):
			var splash_red: float = 0.0
			if GameManager == null or not GameManager.is_card_grid_battle():
				splash_red = child.damage_reduction if child != null and "damage_reduction" in child else 0.0
			var splash_base: float = damage * shooter_stats.splash_damage
			# v5.0: 溅射目标也做击穿检查+防御减免
			var child_stats: UnitStats = child.get("stats") as UnitStats if child != null else null
			if child_stats != null and shooter_stats != null:
				var child_def: float = AttackCalculator.get_defense_vs(child_stats, shooter_stats.combat_kind)
				if splash_base > child_def:
					splash_base = splash_base * (100.0 / (100.0 + child_def))
				else:
					splash_base = 0.0
			if splash_base <= 0.0:
				continue
			var splash_calc: Dictionary = AffixCombatHandler.calculate_damage(
				splash_base,
				shooter_stats,
				child.hp if child != null and "hp" in child else 0.0,
				child.max_hp if child != null and "max_hp" in child else 1.0,
				splash_red
			)
			var splash_damage: float = _apply_shield_wall_mitigation(float(splash_calc["final_damage"]), child)
			var atk_splash: Variant = shooter if is_instance_valid(shooter) else null
			child.take_damage(splash_damage, atk_splash)
	
	# 直击伤害
	if primary.has_method("take_damage"):
		var final_after_wall: float = _apply_shield_wall_mitigation(final_damage, primary)
		var atk_primary: Variant = shooter if is_instance_valid(shooter) else null
		primary.take_damage(final_after_wall, atk_primary)


	# 伤害后处理：吸血（含变异加成）；射手可能已阵亡，避免把已释放引用传入强类型 Node2D 形参
	if is_instance_valid(shooter):
		var lifesteal_multiplier: float = 1.0
		if shooter_stats.has_lifesteal_mutation:
			lifesteal_multiplier = AffixCombatHandler.get_lifesteal_multiplier(shooter, shooter_stats)
		var _lifesteal_heal: float = AffixCombatHandler.apply_lifesteal(
			final_damage * lifesteal_multiplier,
			shooter_stats,
			shooter
		)

		# 暴击变异：暴击时恢复 5% 最大生命值
		if is_crit and shooter_stats.has_crit_mutation:
			AffixCombatHandler.check_crit_mutation_heal(is_crit, shooter, shooter_stats)
	
	# 伤害后处理：溅射（如果启用了词条）
	if shooter_stats.splash_damage > 0.0:
		var splash_targets: Array = AffixCombatHandler.apply_splash_damage(
			primary,
			final_damage,
			shooter_stats,
			shooter_is_player
		)
	
	# 伤害后处理：连锁（如果启用了词条）
	if shooter_stats.chain_chance > 0.0:
		var chain_targets: Array = AffixCombatHandler.apply_chain_lightning(
			primary,
			final_damage,
			shooter_stats,
			shooter_is_player,
			5
		)

	# 卡牌特殊能力：命中后施加效果（同上，避免已释放 shooter）
	if is_instance_valid(shooter):
		CardAbilityManager.on_bullet_hit_post(
			shooter, primary, shooter_stats, global_position,
			final_damage, shooter_is_player
		)

	# 穿透：减少一次计数，>0 时继续飞行
	if _use_tex_sprite:
		_spawn_tex_impact_at(primary.global_position if primary else global_position)
	if pierce_count > 0:
		pierce_count -= 1
		return
	
	_finish_tex_bullet()

## 基础伤害处理（不带词条效果）
func _on_hit_basic(primary: Node2D) -> void:
	if forced_miss:
		_finish_tex_bullet()
		return
	# 范围伤害
	if explosion_radius > 0.0:
		for child in _get_aoe_damage_targets(global_position, explosion_radius, primary):
			var basic_splash: float = _apply_shield_wall_mitigation(damage, child)
			var atk_b: Variant = shooter if is_instance_valid(shooter) else null
			child.take_damage(basic_splash, atk_b)
	# 直击伤害
	if primary.has_method("take_damage"):
		var basic_primary: float = _apply_shield_wall_mitigation(damage, primary)
		var atk_bp: Variant = shooter if is_instance_valid(shooter) else null
		primary.take_damage(basic_primary, atk_bp)
	if _use_tex_sprite:
		_spawn_tex_impact_at(primary.global_position if primary else global_position)
	if pierce_count > 0:
		pierce_count -= 1
		return
	_finish_tex_bullet()

## 对象池：重置子弹状态
func reset_pool_object() -> void:
	# 重置所有状态到初始值
	speed = 600.0
	damage = 5.0
	target = null
	shooter_is_player = true
	max_distance = 1600.0
	weapon_type = 0
	shooter = null
	shooter_stats = null
	forced_miss = false

	pierce_count = 0
	explosion_radius = 0.0
	pellet_count = 1
	spread_angle_deg = 0.0

	_start_position = Vector2.ZERO
	_direction = Vector2.RIGHT
	_beam_visual_phase = 0
	_use_tex_sprite = false

	global_position = Vector2.ZERO
	rotation = 0.0
	scale = Vector2.ONE

	_hide_tex_sprite_visual()
	if _sprite:
		_sprite.visible = true
	if _beam_line:
		_beam_line.visible = false

	visible = false
