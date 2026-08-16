extends Node2D
## 蜂群敌人控制器：单 _physics_process 驱动全部轻量槽位；MultiMesh 绘制；死亡 CPUParticles。
##
## v10(H18) 设计差异声明——蜂群与经典敌人（enemy_unit.gd）的口径差异（有意为之，非 bug）：
##   · 索敌/保持/开火半径用裸 attack_range（无 ×2.6 与 1600 保底）——蜂群均为近战贴脸单位
##   · 固定 interval 冷却攻击模型（无三阶段状态机/per-target 武器攻速）——MultiMesh 槽位无武器槽
##   · 无硬直/眩晕、词缀、fast/stealth 响应——MultiMesh 表现层限制（与"蜂群无二周目加成"同源）
##   · H5 已对齐：目标失效复位攻击计时器（原新目标首帧瞬发）
## 如需与经典敌人完全对齐，须先给 slot 引入武器槽与完整 stats 消费链。
const GC = preload("res://resources/game_constants.gd")
const CombatTargeting = preload("res://scripts/combat_targeting.gd")
const CombatFeedback = preload("res://scripts/combat_feedback.gd")
const MuzzleAnchors = preload("res://data/muzzle_anchors.gd")  # 蜂群开火点（补齐 muzzle 接入，与经典 enemy_unit 对齐）
const DT = preload("res://resources/design_tokens.gd")  # v10: motion_reduce 守卫(受击闪)

const BATTLE_MIN_X: float = 40.0
const BATTLE_MAX_X: float = 1240.0
# v9.3: 扩大 Y 硬夹范围（原 280~440 仅覆盖旧双行布局，三行布局下行 center+60
# 在高背景纹理关卡可能 >440；扩大到 200~560 覆盖三行全程 + 高/低车道中心）
const BATTLE_MIN_Y: float = 200.0
const BATTLE_MAX_Y: float = 560.0

var _mmi: MultiMeshInstance2D
var _slots: Array = []
var _muzzle_offset_cache: Dictionary = {}  # archetype_id -> Vector2 枪口偏移（相对 slot 中心）
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
	# v7.x: 部署虚影期间不索敌/不开火（蜂群 move_speed 恒为0靠 _clamp_slot 定位，仍需夹紧保持位置）。
	# 计时归零时调 slot.materialize_swarm_deploy_ghost 实体化，本帧跳过攻击逻辑。
	if s is SwarmEnemySlot and (s as SwarmEnemySlot).is_deploy_ghost:
		_clamp_slot(s)
		var gs: SwarmEnemySlot = s as SwarmEnemySlot
		gs._ghost_materialize_time_left -= delta
		if gs._ghost_materialize_time_left <= 0.0:
			gs.materialize_swarm_deploy_ghost()
		return
	# v10: 受击闪白计时递减(MultiMesh 不能 tween,靠 _sync 时 lerp visual_color)
	if s is SwarmEnemySlot and (s as SwarmEnemySlot)._hit_flash_t > 0.0:
		(s as SwarmEnemySlot)._hit_flash_t = maxf(0.0, (s as SwarmEnemySlot)._hit_flash_t - delta)
	# v10(C1) 修复：计时器清零移入触发分支内（原无条件清零致周期重索敌永不触发）；
	# 无目标快速重试节流至 20Hz（原每物理帧跑完整索敌流程）
	s._target_find_timer += delta
	var should_find := false
	if s.target == null or not is_instance_valid(s.target):
		if s._target_find_timer >= 0.05:
			should_find = true
			s._target_find_timer = 0.0
	elif s._target_find_timer >= _find_interval_for_battle_load():
		should_find = true
		s._target_find_timer = 0.0
	if should_find:
		_find_target_for_slot(s)
	# v10(H1): 势力 on_hit_debuff 过期恢复（蜂群 slot 也可能中 debuff——其 interval 直改被消费）
	FactionSkillEffectHandler.process_debuff_expirations(s, delta)

	_clamp_slot(s)
	s.grid_update_timer -= delta
	if s.grid_update_timer <= 0.0:
		s.update_spatial_grid()
		s.grid_update_timer = 0.08

	# v10(H5): 目标失效时复位攻击计时——原无目标期照常累加，新目标首帧瞬发；
	# 与经典敌人"目标失效即复位 _attack_phase"口径对齐
	if s.target == null or not is_instance_valid(s.target):
		s.attack_timer = 0.0
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
		# v10(L3): 平方比较（避免 sqrt）
		elif s.global_position.distance_squared_to(s.target.global_position) <= float(s.attack_range) * float(s.attack_range):
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
	# v10(H8): fallback 取最近（原取组顺序第一个，与 spatial_grid 路径口径分叉）
	var fb_best: Node2D = null
	var fb_best_d2: float = INF
	for n in _fallback_player_units:
		if not CombatTargeting.is_attackable_combat_unit(n):
			continue
		var n2d: Node2D = n as Node2D
		if n2d == null:
			continue
		var d2: float = s.global_position.distance_squared_to(n2d.global_position)
		if d2 <= attack_range_sq and d2 < fb_best_d2:
			fb_best_d2 = d2
			fb_best = n2d
	if fb_best != null:
		s.target = fb_best
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

## 蜂群开火点：slot.global_position 是 QuadMesh 中心（非脚部），offset 相对中心算。
## 同 archetype 共享纹理与尺寸，按 archetype 缓存。无标注回退 ZERO（从中心发射）。
func _get_swarm_muzzle_offset(s: Node2D) -> Vector2:
	var aid: String = ""
	if s is SwarmEnemySlot:
		aid = (s as SwarmEnemySlot).archetype_id
	if aid.is_empty():
		return Vector2.ZERO
	if _muzzle_offset_cache.has(aid):
		return _muzzle_offset_cache[aid]
	var off: Vector2 = Vector2.ZERO
	var anchor: Dictionary = MuzzleAnchors.get_anchor(aid)
	if not anchor.is_empty():
		var tex_w: float = 12.0
		var tex_h: float = 9.0
		if _mmi != null and _mmi.multimesh != null and _mmi.multimesh.mesh is QuadMesh:
			tex_w = (_mmi.multimesh.mesh as QuadMesh).size.x
			tex_h = (_mmi.multimesh.mesh as QuadMesh).size.y
		var fx: float = float(anchor.get("fireX", 0.5))
		var fy: float = float(anchor.get("fireY_pct", 50.0))
		off = Vector2((fx - 0.5) * tex_w, (fy - 50.0) / 100.0 * tex_h)
	_muzzle_offset_cache[aid] = off
	return off

func _fire_from_slot(s: Node2D) -> void:
	if s.target == null or not is_instance_valid(s.target):
		return
	var dist_t: float = s.global_position.distance_to(s.target.global_position)
	# v9.2: range_falloff 改返回 float（p_hit==damage_mult，合并消除字典分配）
	var falloff: float = CombatTargeting.range_falloff(dist_t, float(s.attack_range))
	var dmg_out: float = float(s.attack_damage)
	var miss: bool = false
	if dist_t > float(s.attack_range) and float(s.attack_range) > 0.5:
		if randf() > falloff:
			miss = true
			CombatFeedback.show_miss(s.target.global_position, s.target)
		else:
			dmg_out *= falloff
	var wt: int = s.weapon_type
	if s.weapon_types.size() > 0:
		wt = int(s.weapon_types[s._attack_weapon_index % s.weapon_types.size()])
		s._attack_weapon_index += 1
	var spawn_pos := s.global_position + _get_swarm_muzzle_offset(s)
	if _should_use_projectile_batch(wt):
		if BattleManager and BattleManager.enemy_projectile_batch:
			BattleManager.enemy_projectile_batch.fire(
				spawn_pos, s.target, dmg_out, wt, s, null, miss
			)
			return
	_fallthrough_bullet(s, wt, dmg_out, miss)

func _should_use_projectile_batch(wt: int) -> bool:
	return wt in GC.BATCH_FIRE_WEAPON_TYPES  # SMG, PISTOL, RIFLE, MG

func _fallthrough_bullet(s: Node2D, wt: int, p_damage: float = -1.0, p_miss: bool = false) -> void:
	const BulletScene = preload("res://scenes/units/bullet.tscn")
	var bullet: Node2D = ObjectPoolManager.get_object("bullets") if ObjectPoolManager else null
	if bullet == null:
		bullet = BulletScene.instantiate()
	bullet.global_position = s.global_position + _get_swarm_muzzle_offset(s)
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
			var _gs: SwarmEnemySlot = s as SwarmEnemySlot
			col = _gs.visual_color
			# v10: 受击闪白——按 _hit_flash_t 把颜色 lerp 向白(motion_reduce 时跳过; 0.08 对齐 slot _HIT_FLASH_DUR)
			if _gs._hit_flash_t > 0.0 and not DT.is_motion_reduce():
				col = col.lerp(Color.WHITE, _gs._hit_flash_t / 0.08)
		mm.set_instance_color(i, col)
