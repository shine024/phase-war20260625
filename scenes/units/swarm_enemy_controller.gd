extends Node2D
## 蜂群敌人控制器：单 _physics_process 驱动全部轻量槽位；MultiMesh 绘制；死亡 CPUParticles。
const GC = preload("res://resources/game_constants.gd")
const CombatTargeting = preload("res://scripts/combat_targeting.gd")
const CombatFeedback = preload("res://scripts/combat_feedback.gd")

const BATTLE_MIN_X: float = 40.0
const BATTLE_MAX_X: float = 1240.0
const BATTLE_MIN_Y: float = 280.0
const BATTLE_MAX_Y: float = 440.0

var _mmi: MultiMeshInstance2D
var _slots: Array = []
var _death_fx_pool: Array[CPUParticles2D] = []
var _death_fx_active: Array[CPUParticles2D] = []
const MAX_DEATH_FX_POOL: int = 20
var _death_fx_timer: Timer = null
var _death_fx_root: Node = null
var _fallback_cache_timer: float = 0.0
var _fallback_player_units: Array = []
var _fallback_phase_drivers: Array = []
# P1 性能优化: 缓存 is_card_grid_battle 结果（每帧只查一次，避免逐槽逐帧反射链）
# _physics_process 开头刷新，_tick_slot/_clamp_slot 读缓存
var _cached_is_card_grid: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_ensure_multimesh()
	_init_death_fx_pool()
	visible = true

func _init_death_fx_pool() -> void:
	_death_fx_root = get_parent()
	if _death_fx_root == null:
		return
	for i in range(MAX_DEATH_FX_POOL):
		var p := CPUParticles2D.new()
		p.name = "SwarmDeathFX_%d" % i
		p.z_index = 5
		p.emitting = false
		p.one_shot = true
		p.explosiveness = 0.95
		p.amount = 16
		p.lifetime = 0.35
		p.direction = Vector2(0, -1)
		p.spread = 180.0
		p.initial_velocity_min = 30.0
		p.initial_velocity_max = 120.0
		p.scale_amount_min = 1.5
		p.scale_amount_max = 2.5
		p.color = Color(1.0, 0.45, 0.2, 0.85)
		p.visible = false
		_death_fx_root.add_child(p)
		_death_fx_pool.append(p)
	_death_fx_timer = Timer.new()
	_death_fx_timer.wait_time = 0.5
	_death_fx_timer.autostart = true
	_death_fx_root.add_child(_death_fx_timer)
	_death_fx_timer.timeout.connect(_recycle_death_fx)

func _ensure_multimesh() -> void:
	if _mmi == null:
		_mmi = MultiMeshInstance2D.new()
		_mmi.name = "MultiMeshInstance2D"
		add_child(_mmi)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2(12, 9)
	mm.mesh = q
	_mmi.multimesh = mm

func spawn_slot(wave_index: int, archetype_id: String, local_pos: Vector2) -> Node2D:
	var slot: SwarmEnemySlot = SwarmEnemySlot.new()
	add_child(slot)
	if slot.has_method("setup"):
		slot.setup(wave_index, archetype_id, local_pos)
	_slots.append(slot)
	_sync_multimesh_count()
	return slot

func on_slot_died(dead: Node) -> void:
	_spawn_death_fx(dead.global_position)
	_slots.erase(dead)
	_sync_multimesh_count()

func clear_all_slots() -> void:
	for s in _slots:
		if is_instance_valid(s):
			if BattleManager and BattleManager.spatial_grid:
				BattleManager.spatial_grid.remove(s as Node2D)
			s.queue_free()
	_slots.clear()
	_sync_multimesh_count()

func _spawn_death_fx(at: Vector2) -> void:
	if _death_fx_pool.size() > 0:
		var p: CPUParticles2D = _death_fx_pool.pop_back()
		p.global_position = at
		p.visible = true
		p.emitting = true
		_death_fx_active.append(p)

func _recycle_death_fx() -> void:
	for i in range(_death_fx_active.size() - 1, -1, -1):
		var p: CPUParticles2D = _death_fx_active[i]
		if not is_instance_valid(p) or not p.emitting:
			_death_fx_active.remove_at(i)
			if is_instance_valid(p):
				p.emitting = false
				p.visible = false
				_death_fx_pool.append(p)

func _physics_process(delta: float) -> void:
	var tree := get_tree()
	if tree == null or tree.paused:
		return
	# P1: 每帧只查一次 is_card_grid_battle，所有槽复用（原逐槽逐帧反射）
	_cached_is_card_grid = (
		GameManager != null
		and GameManager.has_method("is_card_grid_battle")
		and GameManager.is_card_grid_battle()
	)
	_fallback_cache_timer += delta
	if _fallback_cache_timer >= 0.35:
		_refresh_fallback_targets_cache()
		_fallback_cache_timer = 0.0
	var to_remove: Array = []
	for s in _slots:
		if not is_instance_valid(s):
			to_remove.append(s)
			continue
		_tick_slot(s, delta)
	for r in to_remove:
		_slots.erase(r)
	_sync_multimesh_transforms()

func _tick_slot(s: Node2D, delta: float) -> void:
	s._target_find_timer += delta
	var should_find := false
	if s.target == null or not is_instance_valid(s.target):
		should_find = true
	elif s._target_find_timer >= _find_interval_for_battle_load():
		should_find = true
		s._target_find_timer = 0.0
	if should_find:
		_find_target_for_slot(s)

	# P1: 读 controller 每帧刷新的缓存，避免逐槽反射
	var card_grid_no_march: bool = _cached_is_card_grid
	if not card_grid_no_march:
		if s.target != null and is_instance_valid(s.target):
			var d: float = s.global_position.distance_to(s.target.global_position)
			if d > s.attack_range:
				s.global_position.x -= s.move_speed * delta
		else:
			s.global_position.x -= s.move_speed * delta

	_clamp_slot(s)
	s.grid_update_timer -= delta
	if s.grid_update_timer <= 0.0:
		s.update_spatial_grid()
		s.grid_update_timer = 0.08

	s.attack_timer += delta
	if s.target != null and is_instance_valid(s.target) and s.attack_timer >= s.attack_interval:
		var max_rng: float = float(s.attack_range)
		if CombatTargeting.is_phase_field_node(s.target) and not CombatTargeting.has_alive_player_units(BattleManager):
			max_rng = maxf(max_rng, CombatTargeting.card_grid_enemy_acquisition_range(float(s.attack_range), true) * 1.5)
		var d_fire: float = s.global_position.distance_to(s.target.global_position)
		if d_fire <= max_rng:
			s.attack_timer = 0.0
			_fire_from_slot(s)

func _find_interval_for_battle_load() -> float:
	var n: int = 0
	if BattleManager and BattleManager.has_method("get_enemy_unit_count"):
		n = int(BattleManager.get_enemy_unit_count())
	if n > 55:
		return 0.55
	if n > 35:
		return 0.42
	return 0.3

func _find_target_for_slot(s: Node2D) -> void:
	if s.target != null and is_instance_valid(s.target):
		if CombatTargeting.should_drop_phase_field_target(s.target, false, BattleManager):
			s.target = null
		elif CombatTargeting.is_phase_field_node(s.target):
			if not CombatTargeting.has_alive_player_units(BattleManager):
				return
			s.target = null
		elif s.global_position.distance_to(s.target.global_position) <= s.attack_range:
			return
		else:
			s.target = null
	else:
		s.target = null
	if s.target != null:
		return
	if BattleManager and BattleManager.spatial_grid:
		var grid = BattleManager.spatial_grid
		if grid:
			var nearest: Node2D = grid.query_nearest_target(s.global_position, false, s.attack_range)
			if nearest != null:
				s.target = nearest
				return
	var attack_range: float = float(s.attack_range)
	var attack_range_sq: float = attack_range * attack_range
	for n in _fallback_player_units:
		if not CombatTargeting.is_attackable_combat_unit(n):
			continue
		if s.global_position.distance_squared_to(n.global_position) <= attack_range_sq:
			s.target = n as Node2D
			return
	if not CombatTargeting.has_alive_player_units(BattleManager):
		var phase_field: Node2D = CombatTargeting.find_opponent_phase_field(
			s.global_position, false, BattleManager, -1.0
		)
		if phase_field != null:
			s.target = phase_field
			return

func _refresh_fallback_targets_cache() -> void:
	var tree := get_tree()
	if tree == null:
		return
	_fallback_player_units = tree.get_nodes_in_group("player_units")
	_fallback_phase_drivers = tree.get_nodes_in_group("phase_driver")

func _deploy_y_bounds_for_clamp() -> Vector2:
	# P1: 读 controller 缓存（原反射 GameManager.is_card_grid_battle）
	if _cached_is_card_grid:
		if BattleManager and BattleManager.battlefield and BattleManager.battlefield.has_method("get_deploy_y_bounds"):
			return BattleManager.battlefield.get_deploy_y_bounds()
	return Vector2(BATTLE_MIN_Y, BATTLE_MAX_Y)


func _clamp_slot(s: Node2D) -> void:
	# P1: 读 controller 缓存（原逐槽逐帧反射 GameManager.is_card_grid_battle）
	if _cached_is_card_grid:
		var esi: int = int(s.get_meta("card_grid_enemy_slot", -1))
		if esi >= 0 and BattleManager and BattleManager.battlefield:
			var bf: Node = BattleManager.battlefield
			if bf.has_method("get_card_grid_enemy_slot_global"):
				s.global_position = bf.get_card_grid_enemy_slot_global(esi)
				return
	var gx := s.global_position
	var cx := clampf(gx.x, BATTLE_MIN_X, BATTLE_MAX_X)
	var yb: Vector2 = _deploy_y_bounds_for_clamp()
	var cy := clampf(gx.y, yb.x, yb.y)
	if cx != gx.x or cy != gx.y:
		s.global_position = Vector2(cx, cy)

func _fire_from_slot(s: Node2D) -> void:
	if s.target == null or not is_instance_valid(s.target):
		return
	var dist_t: float = s.global_position.distance_to(s.target.global_position)
	var falloff: Dictionary = CombatTargeting.range_falloff(dist_t, float(s.attack_range))
	var dmg_out: float = float(s.attack_damage)
	var miss: bool = false
	if dist_t > float(s.attack_range) and float(s.attack_range) > 0.5:
		if randf() > float(falloff.get("p_hit", 1.0)):
			miss = true
			CombatFeedback.show_miss(s.target.global_position, s.target)
		else:
			dmg_out *= float(falloff.get("damage_mult", 1.0))
	var wt: int = s.weapon_type
	if s.weapon_types.size() > 0:
		wt = int(s.weapon_types[s._attack_weapon_index % s.weapon_types.size()])
		s._attack_weapon_index += 1
	if _should_use_projectile_batch(wt):
		if BattleManager and BattleManager.enemy_projectile_batch:
			BattleManager.enemy_projectile_batch.fire(
				s.global_position, s.target, dmg_out, wt, s, null, miss
			)
			return
	_fallthrough_bullet(s, wt, dmg_out, miss)

func _should_use_projectile_batch(wt: int) -> bool:
	return wt in [0, 4, 1, 2]  # SMG, PISTOL, RIFLE, MG

func _fallthrough_bullet(s: Node2D, wt: int, p_damage: float = -1.0, p_miss: bool = false) -> void:
	const BulletScene = preload("res://scenes/units/bullet.tscn")
	var bullet: Node2D = ObjectPoolManager.get_object("bullets") if ObjectPoolManager else null
	if bullet == null:
		bullet = BulletScene.instantiate()
	bullet.global_position = s.global_position
	var dmg: float = float(s.attack_damage) if p_damage < 0.0 else p_damage
	bullet.setup(s.target, dmg, false, wt, s, null, p_miss, "")
	var root_2d: Node = get_parent().get_parent() if get_parent() else self
	var current_parent: Node = bullet.get_parent()
	if current_parent != root_2d:
		if current_parent != null:
			current_parent.remove_child(bullet)
		root_2d.add_child(bullet)

func _sync_multimesh_count() -> void:
	if _mmi == null or _mmi.multimesh == null:
		return
	_mmi.multimesh.instance_count = _slots.size()

func _sync_multimesh_transforms() -> void:
	if _mmi == null or _mmi.multimesh == null:
		return
	var mm: MultiMesh = _mmi.multimesh
	var n: int = mini(_slots.size(), mm.instance_count)
	for i in range(n):
		var s: Node2D = _slots[i] as Node2D
		if not is_instance_valid(s):
			continue
		var local_xf := Transform2D(0.0, s.position)
		mm.set_instance_transform_2d(i, local_xf)
		var col: Color = Color.WHITE
		if s is SwarmEnemySlot:
			col = (s as SwarmEnemySlot).visual_color
		mm.set_instance_color(i, col)
