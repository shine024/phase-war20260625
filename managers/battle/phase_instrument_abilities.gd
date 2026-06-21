class_name PhaseInstrumentAbilities
extends RefCounted
## v6.6: 7星相位仪主动特殊能力的战斗触发逻辑
## 处理 type=periodic（周期触发）和 type=on_battle_start（开局一次性）能力。
## passive（被动常驻）能力由 battle_spawn_system / attack_calculator 直接查询相位仪数据，
## 不经过本类。

const CombatFeedback = preload("res://scripts/combat_feedback.gd")
const VisualEffects = preload("res://scenes/effects/visual_effects_manager.gd")
const PhaseLawCastEffect = preload("res://scenes/effects/phase_law_cast_effect.gd")
const ScreenShakeScript = preload("res://scenes/effects/screen_shake.gd")

## 当前激活的能力（战斗开始时从相位仪读取，战斗中不变）
static var _active_ability: Dictionary = {}
## 周期能力计时器
static var _periodic_timers: Dictionary = {}  # ability_id -> elapsed
## 开局一次性能力是否已触发
static var _start_fired: bool = false
## 战斗是否激活
static var _battle_active: bool = false
## 战场引用（on_battle_start 时设置）
static var _battlefield: Node = null
## 酸雨剩余持续时间
static var _acid_rain_remaining: float = 0.0
## 火炮连发队列：[{fire_at: float, shots_left: int}]
static var _barrage_queue: Array = []

## 战斗开始时调用：读取当前相位仪的 active_ability，触发开局能力
static func on_battle_start(phase_instrument: Node, battlefield: Node) -> void:
	reset_state()
	_battlefield = battlefield
	_battle_active = true
	_start_fired = false
	if phase_instrument == null:
		return
	_active_ability = _get_active_ability(phase_instrument)
	if _active_ability.is_empty():
		return
	# 触发开局一次性能力
	_fire_start_abilities()

## 每帧调用：驱动周期能力（火炮连发/核子轰炸/酸雨持续）
static func update(delta: float) -> void:
	if not _battle_active or _active_ability.is_empty():
		return
	var ability_id: String = String(_active_ability.get("id", ""))
	var atype: String = String(_active_ability.get("type", ""))
	# 酸雨持续掉血
	if _acid_rain_remaining > 0.0:
		_acid_rain_remaining -= delta
		_apply_acid_rain_tick(delta)
	# 周期能力计时
	if atype == "periodic":
		_update_periodic(ability_id, delta)

## 战斗结束时重置状态
static func reset_state() -> void:
	_active_ability.clear()
	_periodic_timers.clear()
	_start_fired = false
	_battle_active = false
	_battlefield = null
	_acid_rain_remaining = 0.0
	_barrage_queue.clear()

## 获取当前相位仪的 active_ability（被动能力查询也用这个）
static func get_active_ability() -> Dictionary:
	return _active_ability

## 获取当前能力的 params（供 passive 能力的消费方查询）
static func get_active_params() -> Dictionary:
	return _active_ability.get("params", {})

# ─────────────────────────────────────────────
#  内部实现
# ─────────────────────────────────────────────

static func _get_active_ability(phase_instrument: Node) -> Dictionary:
	if phase_instrument == null:
		return {}
	if phase_instrument.has_method("get_active_ability"):
		return phase_instrument.get_active_ability()
	# 回退：直接读配置
	var cfg: Dictionary = {}
	if phase_instrument.has_method("get_current_instrument"):
		cfg = phase_instrument.get_current_instrument()
	return cfg.get("active_ability", {})

static func _fire_start_abilities() -> void:
	if _start_fired:
		return
	_start_fired = true
	var ability_id: String = String(_active_ability.get("id", ""))
	var atype: String = String(_active_ability.get("type", ""))
	var params: Dictionary = _active_ability.get("params", {})
	if atype != "on_battle_start":
		return
	match ability_id:
		"acid_rain":
			_acid_rain_remaining = float(params.get("duration", 30.0))
			# v6.6 正式动画：绿色酸液云覆盖战场
			if _battlefield is Node2D:
				var center: Vector2 = (_battlefield as Node2D).global_position
				# 大范围绿色粒子云
				_create_acid_rain_cloud(center)
			_trigger_screen_shake(5.0, 0.4)
			_show_toast("☁ 致命酸雨降临敌方阵营！")
		"mega_shield":
			_apply_mega_shield(params)
			_show_toast("🛡 巨型能量罩笼罩我方全体！")

static func _update_periodic(ability_id: String, delta: float) -> void:
	var params: Dictionary = _active_ability.get("params", {})
	# 先处理火炮连发的待发射队列
	_process_barrage_queue(delta)
	match ability_id:
		"artillery_barrage":
			_tick_artillery_barrage(params, delta)
		"nuclear_bombardment":
			_tick_nuclear_bombardment(params, delta)

# ── 火炮连发 ──
static func _tick_artillery_barrage(params: Dictionary, delta: float) -> void:
	var interval: float = float(params.get("interval", 10.0))
	var elapsed: float = float(_periodic_timers.get("artillery_barrage", interval))  # 首次跳过等待
	elapsed += delta
	if elapsed >= interval:
		elapsed = 0.0
		var shots: int = int(params.get("shots", 7))
		var shot_interval: float = float(params.get("shot_interval", 1.0))
		# 排队连发：每 shot_interval 发射一发
		for i in range(shots):
			_barrage_queue.append({"fire_at": float(i) * shot_interval, "fired": false})
		_show_toast("💥 火炮连发启动！")
	_periodic_timers["artillery_barrage"] = elapsed

static func _process_barrage_queue(delta: float) -> void:
	if _barrage_queue.is_empty():
		return
	for entry in _barrage_queue:
		if not bool(entry.get("fired", false)):
			var fire_at: float = float(entry.get("fire_at", 0.0))
			fire_at -= delta
			entry["fire_at"] = fire_at
			if fire_at <= 0.0:
				entry["fired"] = true
				_fire_artillery_shot()
	# 清理已发射的
	_barrage_queue = _barrage_queue.filter(func(e): return not bool(e.get("fired", true)))

static func _fire_artillery_shot() -> void:
	if _battlefield == null:
		return
	var enemies: Array = _get_enemy_units()
	if enemies.is_empty():
		return
	# 随机选一个敌方单位造成伤害（按平均攻击力 × 倍率）
	var target: Node = enemies[randi() % enemies.size()]
	var dmg: float = _compute_artillery_damage()
	# v6.6 正式动画：红色炮弹轨迹 + 爆炸
	if target is Node2D:
		var tpos: Vector2 = (target as Node2D).global_position
		# 炮弹轨迹：从战场顶部红色粒子下落
		_create_artillery_trajectory(tpos)
		# 命中爆炸：橙红色大爆炸
		VisualEffects.create_explosion(_battlefield, tpos, 1.8, Color(1.0, 0.3, 0.1, 1.0))
		CombatFeedback.show_damage(tpos, dmg, target, false, "normal")
	if target and target.has_method("take_damage"):
		target.take_damage(dmg, null)

static func _compute_artillery_damage() -> float:
	# 基于我方单位平均攻击力的固定倍率，避免太弱或太强
	var allies: Array = _get_player_units()
	if allies.is_empty():
		return 50.0
	var total_atk: float = 0.0
	var count: int = 0
	for u in allies:
		if u and "stats" in u and u.stats != null:
			total_atk += float(u.stats.attack_damage)
			count += 1
	if count == 0:
		return 50.0
	return (total_atk / float(count)) * 1.5  # 平均攻击力 × 1.5

# ── 核子轰炸 ──
static func _tick_nuclear_bombardment(params: Dictionary, delta: float) -> void:
	var interval: float = float(params.get("interval", 30.0))
	var elapsed: float = float(_periodic_timers.get("nuclear_bombardment", interval))
	elapsed += delta
	if elapsed >= interval:
		elapsed = 0.0
		_fire_nuclear_bombardment(params)
	_periodic_timers["nuclear_bombardment"] = elapsed

static func _fire_nuclear_bombardment(params: Dictionary) -> void:
	if _battlefield == null:
		return
	var dmg_mult: float = float(params.get("dmg_mult", 1.0))
	var base_dmg: float = _compute_nuclear_damage() * dmg_mult
	var enemies: Array = _get_enemy_units()
	# v6.6 正式动画：分两阶段——先紫色闪电标记（警告），延迟后绿色核爆 + 伤害结算
	var mark_delay: float = 0.35
	for e in enemies:
		if e == null or not is_instance_valid(e):
			continue
		var epos: Vector2 = (e as Node2D).global_position if e is Node2D else Vector2.ZERO
		# 第一阶段：紫色闪电标记（立即出现，提示玩家轰炸即将命中）
		PhaseLawCastEffect.create_phase_law_effect(_battlefield, epos, Color(0.5, 0.0, 1.0, 1.0))
		# 第二阶段：延迟核爆 + 伤害结算（用 tween，避免阻塞；结算时复查有效性）
		var captured_enemy = e
		var captured_pos = epos
		var tw := _battlefield.create_tween()
		tw.tween_interval(mark_delay)
		tw.tween_callback(func():
			if _battlefield == null or not is_instance_valid(_battlefield):
				return
			# 延迟后敌人可能已死亡/移除，跟踪其当前位置
			var cur_pos: Vector2 = captured_pos
			if is_instance_valid(captured_enemy) and captured_enemy is Node2D:
				cur_pos = (captured_enemy as Node2D).global_position
			VisualEffects.create_explosion(_battlefield, cur_pos, 3.0, Color(0.2, 1.0, 0.2, 1.0))
			if is_instance_valid(captured_enemy):
				CombatFeedback.show_damage(cur_pos, base_dmg, captured_enemy, true, "critical")
				if captured_enemy.has_method("take_damage"):
					captured_enemy.take_damage(base_dmg, null)
		)
	# 全屏震动（与标记同步出现，强化预警冲击）
	_trigger_screen_shake(10.0, 0.6)
	_show_toast("☢ 核子轰炸！敌方全体受到 %.0f 伤害" % base_dmg)

static func _compute_nuclear_damage() -> float:
	# 固定基础伤害 + 我方总攻击力比例，确保有实质威胁
	var allies: Array = _get_player_units()
	var total_atk: float = 0.0
	for u in allies:
		if u and "stats" in u and u.stats != null:
			total_atk += float(u.stats.attack_damage)
	return 300.0 + total_atk * 0.5  # 基础300 + 总攻击力50%

# ── 酸雨（持续百分比掉血）──
static func _apply_acid_rain_tick(delta: float) -> void:
	if _battlefield == null:
		return
	var params: Dictionary = _active_ability.get("params", {})
	var hp_pct: float = float(params.get("hp_pct_per_sec", 0.02))
	var enemies: Array = _get_enemy_units()
	# v6.6 占位动画：酸雨命中特效（节流：每 ~0.4s 在部分单位上显示一次，避免每帧刷屏）
	var show_vfx_this_frame: bool = fmod(Time.get_ticks_msec(), 400.0) < 60.0
	for i in range(enemies.size()):
		var e = enemies[i]
		if e == null or not is_instance_valid(e):
			continue
		var max_hp: float = 0.0
		if "stats" in e and e.stats != null:
			max_hp = float(e.stats.max_hp)
		elif "max_hp" in e:
			max_hp = float(e.max_hp)
		if max_hp <= 0.0:
			continue
		var dmg: float = max_hp * hp_pct * delta
		if dmg > 0.0 and e.has_method("take_damage"):
			e.take_damage(dmg, null)
			# v6.6: 伤害数字由 take_damage → unit_damaged 信号统一驱动（用实际扣血），
			# 此处不再直接 show_damage（否则双数字 + 不含 _incoming_damage_mul）。
			# 仅保留酸液滴落视觉特效。
			if show_vfx_this_frame and i % 3 == 0 and e is Node2D:
				var epos: Vector2 = (e as Node2D).global_position
				_create_acid_drip(epos)

# ── 巨型能量罩 ──
static func _apply_mega_shield(params: Dictionary) -> void:
	if _battlefield == null:
		return
	var shield_amount: float = float(params.get("shield_amount", 20000.0))
	var allies: Array = _get_player_units()
	# v6.6 正式动画：蓝色能量罩降临每个友军 + 战场中央光环
	for u in allies:
		if u == null or not is_instance_valid(u):
			continue
		if u.has_method("add_shield"):
			u.add_shield(shield_amount)
		if u is Node2D:
			_create_shield_dome((u as Node2D).global_position)
	_trigger_screen_shake(6.0, 0.4)

# ── 辅助 ──
static func _get_enemy_units() -> Array:
	return _get_units("EnemyUnits", "EnemyPhaseFieldDriver")

static func _get_player_units() -> Array:
	return _get_units("PlayerUnits", "PhaseFieldDriver")

static func _get_units(group_node_name: String, driver_name: String) -> Array:
	var result: Array = []
	if _battlefield == null:
		return result
	var container: Node = _battlefield.get_node_or_null(group_node_name)
	if container != null:
		for u in container.get_children():
			if is_instance_valid(u):
				result.append(u)
	return result

static func _show_toast(msg: String) -> void:
	var sb := Engine.get_main_loop() as SceneTree
	if sb == null or sb.root == null:
		return
	if sb.root.has_node("/root/SignalBus"):
		var SignalBusRef = sb.root.get_node("/root/SignalBus")
		if SignalBusRef and SignalBusRef.has_signal("show_toast"):
			SignalBusRef.show_toast.emit(msg)

## v6.6 正式：触发屏幕震动（使用 ScreenShake 脚本）
static func _trigger_screen_shake(intensity: float, duration: float) -> void:
	if _battlefield == null:
		return
	var cam: Camera2D = null
	# 优先从 viewport 找当前相机
	var vp := _battlefield.get_viewport()
	if vp != null:
		cam = vp.get_camera_2d()
	if cam != null:
		ScreenShakeScript.shake_camera(cam, intensity, duration)

# ─────────────────────────────────────────────
#  正式动画函数（v6.6）
# ─────────────────────────────────────────────

## 火炮连发：红色炮弹轨迹
static func _create_artillery_trajectory(target_pos: Vector2) -> void:
	"""从战场顶部生成红色粒子下落轨迹"""
	if _battlefield == null or not (_battlefield is Node2D):
		return
	var trail := Node2D.new()
	trail.position = Vector2(target_pos.x, target_pos.y - 300.0)  # 从上方300像素处开始
	_battlefield.add_child(trail)
	
	# 炮弹粒子：红色高速下落
	var p := CPUParticles2D.new()
	p.emitting = true
	p.lifetime = 0.6
	p.amount = 15
	p.one_shot = true
	p.explosiveness = 0.3
	p.direction = Vector2.DOWN
	p.spread = 30.0
	p.initial_velocity_min = 200.0
	p.initial_velocity_max = 350.0
	p.gravity = Vector2(0, 300)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.0
	p.color = Color(1.0, 0.2, 0.1, 1.0)
	trail.add_child(p)
	
	# 拖尾光点
	var tw := trail.create_tween()
	tw.tween_property(p, "scale", Vector2(0.5, 0.5), 0.6)
	tw.tween_interval(0.1)
	tw.tween_callback(func(): trail.queue_free())

## 酸雨云：大范围绿色粒子覆盖
static func _create_acid_rain_cloud(center: Vector2) -> void:
	"""在战场中央生成大范围绿色酸液云"""
	if _battlefield == null or not (_battlefield is Node2D):
		return
	var cloud := Node2D.new()
	cloud.position = center
	_battlefield.add_child(cloud)
	
	# 大范围绿色粒子云
	var p := CPUParticles2D.new()
	p.emitting = true
	p.lifetime = 2.0
	p.amount = 60
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 150.0
	p.direction = Vector2.DOWN
	p.spread = 10.0
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 80.0
	p.gravity = Vector2(0, 150)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	
	# 绿色渐变
	var gradient := Gradient.new()
	gradient.add_point(0.0, Color(0.2, 1.0, 0.3, 1.0))
	gradient.add_point(0.5, Color(0.4, 0.9, 0.2, 0.8))
	gradient.add_point(1.0, Color.TRANSPARENT)
	p.color_ramp = gradient
	
	cloud.add_child(p)
	
	# 地面腐蚀圈
	var ring := Polygon2D.new()
	var segments := 48
	var pts := PackedVector2Array()
	for i in range(segments):
		var ang := (TAU * i) / segments
		pts.append(Vector2(cos(ang), sin(ang)) * 120.0)
	ring.polygon = pts
	ring.color = Color(0.2, 0.9, 0.2, 0.4)
	ring.scale = Vector2(0.1, 0.1)
	cloud.add_child(ring)
	
	var tw := cloud.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(1.5, 1.5), 1.5).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "color:a", 0.0, 1.5).set_ease(Tween.EASE_IN)
	tw.tween_interval(0.5)
	tw.tween_callback(func(): cloud.queue_free())

## 酸液滴落：绿色腐蚀粒子
static func _create_acid_drip(pos: Vector2) -> void:
	"""单个酸液滴落效果"""
	if _battlefield == null or not (_battlefield is Node2D):
		return
	var drip := Node2D.new()
	drip.position = pos
	_battlefield.add_child(drip)
	
	# 绿色酸液粒子
	var p := CPUParticles2D.new()
	p.emitting = true
	p.lifetime = 0.5
	p.amount = 8
	p.one_shot = true
	p.explosiveness = 0.8
	p.direction = Vector2.DOWN
	p.spread = 60.0
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 120.0
	p.gravity = Vector2(0, 200)
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.5
	p.color = Color(0.3, 1.0, 0.2, 1.0)
	drip.add_child(p)
	
	var tw := drip.create_tween()
	tw.tween_interval(0.5)
	tw.tween_callback(func(): drip.queue_free())

## 能量罩：蓝色护盾光环
static func _create_shield_dome(pos: Vector2) -> void:
	"""蓝色能量罩降临效果"""
	if _battlefield == null or not (_battlefield is Node2D):
		return
	var dome := Node2D.new()
	dome.position = pos
	_battlefield.add_child(dome)
	
	# 外圈护盾环
	var outer := Polygon2D.new()
	var segs := 32
	var pts := PackedVector2Array()
	for i in range(segs):
		var ang := (TAU * i) / segs
		pts.append(Vector2(cos(ang), sin(ang)) * 35.0)
	outer.polygon = pts
	outer.color = Color(0.2, 0.6, 1.0, 0.6)
	dome.add_child(outer)
	
	# 内圈光晕
	var inner := ColorRect.new()
	inner.size = Vector2(70, 70)
	inner.position = Vector2(-35, -35)
	inner.color = Color(0.3, 0.7, 1.0, 0.15)
	dome.add_child(inner)
	
	var tw := dome.create_tween()
	tw.set_parallel(true)
	tw.tween_property(outer, "scale", Vector2(1.5, 1.5), 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_property(outer, "color:a", 0.0, 1.2).set_ease(Tween.EASE_IN)
	tw.tween_property(inner, "modulate:a", 0.0, 1.0)
	tw.tween_interval(0.3)
	tw.tween_callback(func(): dome.queue_free())
