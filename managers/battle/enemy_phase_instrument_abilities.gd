class_name EnemyPhaseInstrumentAbilities
extends RefCounted
## v7.x 敌方相位仪主动特殊能力的战斗触发逻辑
## 镜像我方 PhaseInstrumentAbilities，但角色对调：敌方能力打击玩家、buff 敌兵。
## 处理 type=periodic（周期触发）和 type=on_battle_start（开局一次性）能力。
##
## 能力清单：
##   enemy_artillery_barrage (periodic)      — 每 N 秒炮击玩家单位
##   enemy_nano_swarm (on_battle_start)      — 开局持续秒数内玩家单位每秒掉 %max_hp
##   enemy_shield_bulwark (on_battle_start)  — 开局给所有敌兵加护盾
##   enemy_rage_buff (periodic)              — 周期性激活敌兵狂暴（攻速/攻击临时提升）

const CombatFeedback = preload("res://scripts/combat_feedback.gd")
const VisualEffects = preload("res://scenes/effects/visual_effects_manager.gd")
const PhaseLawCastEffect = preload("res://scenes/effects/phase_law_cast_effect.gd")
const ScreenShakeScript = preload("res://scenes/effects/screen_shake.gd")

## 当前激活的能力（战斗开始时从敌方相位仪读取，战斗中不变）
static var _active_ability: Dictionary = {}
## 周期能力计时器
static var _periodic_timers: Dictionary = {}  # ability_id -> elapsed
## 开局一次性能力是否已触发
static var _start_fired: bool = false
## 战斗是否激活
static var _battle_active: bool = false
## 战场引用（on_battle_start 时设置）
static var _battlefield: Node = null
## 纳米虫群剩余持续时间
static var _nano_swarm_remaining: float = 0.0
## 炮击队列：[{fire_at: float, fired: bool}]
static var _barrage_queue: Array = []
## 敌方狂暴状态
static var _rage_active: bool = false
static var _rage_expire_at: float = 0.0  # 游戏时间戳（秒）
## 狂暴已应用的单位集合（防止重复叠加）
static var _rage_applied_units: Array = []


## 战斗开始时调用：读取敌方相位仪的 active_ability，触发开局能力
## driver: EnemyPhaseFieldDriver 节点（持有 equipment/phase_instrument 数据）
static func on_battle_start(driver: Node, battlefield: Node) -> void:
	reset_state()
	_battlefield = battlefield
	_battle_active = true
	_start_fired = false
	if driver == null:
		return
	_active_ability = _get_active_ability(driver)
	if _active_ability.is_empty():
		return
	# 触发开局一次性能力
	_fire_start_abilities()

## 每帧调用：驱动周期能力（炮击/狂暴/纳米虫群持续）
static func update(delta: float) -> void:
	if not _battle_active or _active_ability.is_empty():
		return
	var ability_id: String = String(_active_ability.get("id", ""))
	var atype: String = String(_active_ability.get("type", ""))
	# 纳米虫群持续掉血
	if _nano_swarm_remaining > 0.0:
		_nano_swarm_remaining -= delta
		_apply_nano_swarm_tick(delta)
	# 检查狂暴过期
	if _rage_active:
		var now: float = Time.get_ticks_msec() / 1000.0
		if now >= _rage_expire_at:
			_expire_rage_buff()
	# 周期能力计时
	if atype == "periodic":
		_update_periodic(ability_id, delta)

## 战斗结束时重置状态
static func reset_state() -> void:
	# 若狂暴仍激活，先恢复（防止 stats 残留）
	if _rage_active:
		_expire_rage_buff()
	_active_ability.clear()
	_periodic_timers.clear()
	_start_fired = false
	_battle_active = false
	_battlefield = null
	_nano_swarm_remaining = 0.0
	_barrage_queue.clear()

## 获取当前敌方相位仪的 active_ability
static func get_active_ability() -> Dictionary:
	return _active_ability

# ─────────────────────────────────────────────
#  内部实现
# ─────────────────────────────────────────────

## 从 driver 读取敌方相位仪的 active_ability
static func _get_active_ability(driver: Node) -> Dictionary:
	if driver == null:
		return {}
	# 优先用 driver 的 getter（setup 时缓存）
	if driver.has_method("get_active_ability"):
		return driver.get_active_ability()
	return {}

## 触发开局一次性能力
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
		"enemy_nano_swarm":
			_nano_swarm_remaining = float(params.get("duration", 20.0))
			if _battlefield is Node2D:
				var center: Vector2 = (_battlefield as Node2D).global_position
				_create_acid_cloud(center)
			_trigger_screen_shake(5.0, 0.4)
			_show_toast("☠ 敌方相位仪释放纳米虫群！我方单位持续失血！")
			_emit_ability_triggered("enemy_nano_swarm", "start", {"duration": _nano_swarm_remaining, "is_enemy": true})
		"enemy_shield_bulwark":
			_apply_shield_bulwark(params)
			_show_toast("🛡 敌方相位仪展开能量壁垒！全体敌兵获得护盾！")
			_emit_ability_triggered("enemy_shield_bulwark", "start", {"shield_amount": float(params.get("shield_amount", 5000.0)), "is_enemy": true})

## 周期能力驱动
static func _update_periodic(ability_id: String, delta: float) -> void:
	var params: Dictionary = _active_ability.get("params", {})
	# 先处理炮击待发射队列
	_process_barrage_queue(delta)
	match ability_id:
		"enemy_artillery_barrage":
			_tick_artillery_barrage(params, delta)
		"enemy_rage_buff":
			_tick_rage_buff(params, delta)

# ── 敌方炮击（periodic）──

static func _tick_artillery_barrage(params: Dictionary, delta: float) -> void:
	var interval: float = float(params.get("interval", 12.0))
	var elapsed: float = float(_periodic_timers.get("artillery_barrage", interval))  # 首次跳过等待
	elapsed += delta
	if elapsed >= interval:
		elapsed = 0.0
		var shots: int = int(params.get("shots", 4))
		var shot_interval: float = float(params.get("shot_interval", 0.8))
		for i in range(shots):
			_barrage_queue.append({"fire_at": float(i) * shot_interval, "fired": false})
		_show_toast("💥 敌方相位仪炮击！我方阵地遭轰击！")
	_emit_periodic_timer("artillery_barrage", elapsed)

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

## 对一个随机玩家单位施加炮击伤害（红色标记→延迟→爆炸+伤害）
static func _fire_artillery_shot() -> void:
	if _battlefield == null:
		return
	var targets: Array = _get_player_units()
	if targets.is_empty():
		return
	var target: Node = targets[randi() % targets.size()]
	if target == null or not is_instance_valid(target) or not (target is Node2D):
		return
	var dmg: float = _compute_artillery_damage()
	var tpos: Vector2 = (target as Node2D).global_position
	# 第一阶段：红色标记（警告玩家）
	PhaseLawCastEffect.create_phase_law_effect(_battlefield, tpos, Color(1.0, 0.2, 0.2, 1.0))
	# 第二阶段：延迟爆炸 + 伤害（tween）
	var captured_target = target
	var captured_pos = tpos
	var captured_dmg = dmg
	var tw := _battlefield.create_tween()
	tw.tween_interval(0.45)
	tw.tween_callback(func():
		if _battlefield == null or not is_instance_valid(_battlefield):
			return
		var cur_pos: Vector2 = captured_pos
		if is_instance_valid(captured_target) and captured_target is Node2D:
			cur_pos = (captured_target as Node2D).global_position
		VisualEffects.create_explosion(_battlefield, cur_pos, 2.5, Color(1.0, 0.4, 0.2, 1.0))
		if is_instance_valid(captured_target):
			CombatFeedback.show_damage(cur_pos, captured_dmg, captured_target, false, "critical")
			if captured_target.has_method("take_damage"):
				captured_target.take_damage(captured_dmg, null)
	)

## 基于场上敌兵的平均攻击力计算炮击伤害（保证有实质威胁但不过分）
static func _compute_artillery_damage() -> float:
	var enemies: Array = _get_enemy_units()
	if enemies.is_empty():
		return 80.0
	var total_atk: float = 0.0
	var count: int = 0
	for u in enemies:
		if u and "stats" in u and u.stats != null:
			total_atk += float(u.stats.attack_damage)
			count += 1
	if count == 0:
		return 80.0
	return (total_atk / float(count)) * 1.2  # 平均攻击力 × 1.2

# ── 纳米虫群（on_battle_start，持续百分比掉血）──

static func _apply_nano_swarm_tick(delta: float) -> void:
	if _battlefield == null:
		return
	var params: Dictionary = _active_ability.get("params", {})
	var hp_pct: float = float(params.get("hp_pct_per_sec", 0.015))
	var targets: Array = _get_player_units()
	# 节流：每 ~0.4s 在部分单位上显示一次命中特效
	var show_vfx_this_frame: bool = fmod(Time.get_ticks_msec(), 400.0) < 60.0
	for i in range(targets.size()):
		var u = targets[i]
		if u == null or not is_instance_valid(u):
			continue
		var max_hp: float = 0.0
		if "stats" in u and u.stats != null:
			max_hp = float(u.stats.max_hp)
		elif "max_hp" in u:
			max_hp = float(u.max_hp)
		if max_hp <= 0.0:
			continue
		var dmg: float = max_hp * hp_pct * delta
		if dmg > 0.0 and u.has_method("take_damage"):
			u.take_damage(dmg, null)
			if show_vfx_this_frame and i % 3 == 0 and u is Node2D:
				_create_acid_hit((u as Node2D).global_position)

## 敌方能量壁垒（on_battle_start，给敌兵加护盾）
static func _apply_shield_bulwark(params: Dictionary) -> void:
	if _battlefield == null:
		return
	var shield_amount: float = float(params.get("shield_amount", 5000.0))
	var enemies: Array = _get_enemy_units()
	for e in enemies:
		if e == null or not is_instance_valid(e):
			continue
		if e.has_method("add_shield"):
			e.add_shield(shield_amount)
		if e is Node2D:
			_create_shield_dome((e as Node2D).global_position)
	_trigger_screen_shake(5.0, 0.4)

# ── 敌方狂暴（periodic，临时提升敌兵攻击/攻速）──

static func _tick_rage_buff(params: Dictionary, delta: float) -> void:
	# 若狂暴已激活，等待其过期（_expire_rage 在 update 中调用）
	if _rage_active:
		return
	var interval: float = float(params.get("interval", 15.0))
	var elapsed: float = float(_periodic_timers.get("rage_buff", interval))
	elapsed += delta
	if elapsed >= interval:
		elapsed = 0.0
		_activate_rage_buff(params)
	_emit_periodic_timer("rage_buff", elapsed)

## 激活狂暴：给所有敌兵临时提升攻击力/攻速
static func _activate_rage_buff(params: Dictionary) -> void:
	var duration: float = float(params.get("duration", 5.0))
	var atk_mult: float = float(params.get("atk_mult", 1.4))
	var spd_mult: float = float(params.get("spd_mult", 1.25))
	_rage_active = true
	_rage_expire_at = Time.get_ticks_msec() / 1000.0 + duration
	_rage_applied_units.clear()
	var enemies: Array = _get_enemy_units()
	for e in enemies:
		if e == null or not is_instance_valid(e):
			continue
		if "stats" in e and e.stats != null:
			_apply_rage_to_unit(e, atk_mult, spd_mult)
			_rage_applied_units.append(e)
	_trigger_screen_shake(8.0, 0.5)
	_show_toast("🔥 敌方相位仪激活狂暴！敌兵攻击力飙升！")
	_emit_ability_triggered("enemy_rage_buff", "start", {"duration": duration, "is_enemy": true})

## 对单个单位施加狂暴 stats 乘数（用 meta 防重复）
static func _apply_rage_to_unit(unit: Node, atk_mult: float, spd_mult: float) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if unit.has_meta("_enemy_rage_applied"):
		return  # 已施加，跳过（防重复叠加）
	var stats = unit.get("stats")
	if stats == null:
		return
	stats.attack_damage *= atk_mult
	# 三维攻速提升
	if "attack_light_speed" in stats:
		stats.attack_light_speed *= spd_mult
	if "attack_armor_speed" in stats:
		stats.attack_armor_speed *= spd_mult
	if "attack_air_speed" in stats:
		stats.attack_air_speed *= spd_mult
	unit.set_meta("_enemy_rage_applied", true)
	# 红色光环标记
	if unit is Node2D:
		_create_rage_aura((unit as Node2D).global_position)

## 狂暴过期：恢复所有受影响单位的原始 stats
static func _expire_rage_buff() -> void:
	if not _rage_active:
		return
	var params: Dictionary = _active_ability.get("params", {})
	var atk_mult: float = float(params.get("atk_mult", 1.4))
	var spd_mult: float = float(params.get("spd_mult", 1.25))
	for unit in _rage_applied_units:
		if unit == null or not is_instance_valid(unit):
			continue
		if unit.has_meta("_enemy_rage_applied"):
			var stats = unit.get("stats")
			if stats != null:
				stats.attack_damage /= atk_mult
				if "attack_light_speed" in stats:
					stats.attack_light_speed /= spd_mult
				if "attack_armor_speed" in stats:
					stats.attack_armor_speed /= spd_mult
				if "attack_air_speed" in stats:
					stats.attack_air_speed /= spd_mult
			unit.remove_meta("_enemy_rage_applied")
	_rage_applied_units.clear()
	_rage_active = false

# ── 辅助 ──

## 获取玩家单位（敌方能力的打击目标）
static func _get_player_units() -> Array:
	return _get_units("PlayerUnits", "PhaseFieldDriver")

## 获取敌方单位（敌方能力的 buff 对象）
static func _get_enemy_units() -> Array:
	return _get_units("EnemyUnits", "EnemyPhaseFieldDriver")

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

## 周期计时器写入（统一入口，方便扩展）
static func _emit_periodic_timer(key: String, elapsed: float) -> void:
	_periodic_timers[key] = elapsed

static func _show_toast(msg: String) -> void:
	var sb := Engine.get_main_loop() as SceneTree
	if sb == null or sb.root == null:
		return
	if sb.root.has_node("/root/SignalBus"):
		var SignalBusRef = sb.root.get_node("/root/SignalBus")
		if SignalBusRef and SignalBusRef.has_signal("show_toast"):
			SignalBusRef.show_toast.emit(msg)

## emit 相位仪能力触发信号（复用我方信号，params 加 is_enemy:true 标记来源）
## battle_spectacle 按 ability_id 分派演出
static func _emit_ability_triggered(ability_id: String, stage: String, params: Dictionary = {}) -> void:
	var sb := Engine.get_main_loop() as SceneTree
	if sb == null or sb.root == null:
		return
	if sb.root.has_node("/root/SignalBus"):
		var SignalBusRef = sb.root.get_node("/root/SignalBus")
		if SignalBusRef and SignalBusRef.has_signal("phase_instrument_ability_triggered"):
			SignalBusRef.phase_instrument_ability_triggered.emit(ability_id, stage, params)

## 触发屏幕震动
static func _trigger_screen_shake(intensity: float, duration: float) -> void:
	if _battlefield == null:
		return
	var cam: Camera2D = null
	var vp := _battlefield.get_viewport()
	if vp != null:
		cam = vp.get_camera_2d()
	if cam != null:
		ScreenShakeScript.shake_camera(cam, intensity, duration)

# ─────────────────────────────────────────────
#  视觉特效（简化版，配色偏向"敌方/威胁"——红/暗紫/暗红）
# ─────────────────────────────────────────────

## 纳米虫群云：大范围暗紫色粒子覆盖（打玩家时的酸雨）
static func _create_acid_cloud(center: Vector2) -> void:
	if _battlefield == null or not (_battlefield is Node2D):
		return
	var cloud := Node2D.new()
	cloud.position = center
	_battlefield.add_child(cloud)

	var p1 := CPUParticles2D.new()
	p1.emitting = true
	p1.lifetime = 3.0
	p1.amount = 60
	p1.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p1.emission_sphere_radius = 180.0
	p1.direction = Vector2(0, 1)  # 向下（酸雨下落）
	p1.spread = 35.0
	p1.initial_velocity_min = 40.0
	p1.initial_velocity_max = 100.0
	p1.gravity = Vector2(0, 80)
	p1.scale_amount_min = 0.5
	p1.scale_amount_max = 1.5

	# 暗紫渐变（毒酸感）
	var gradient := Gradient.new()
	gradient.add_point(0.0, Color(0.6, 0.1, 0.3, 1.0))
	gradient.add_point(0.4, Color(0.4, 0.05, 0.2, 0.8))
	gradient.add_point(0.8, Color(0.2, 0.0, 0.1, 0.3))
	gradient.add_point(1.0, Color.TRANSPARENT)
	p1.color_ramp = gradient
	cloud.add_child(p1)

	var ring := Polygon2D.new()
	var segments := 48
	var pts := PackedVector2Array()
	for i in range(segments):
		var ang := (TAU * i) / segments
		pts.append(Vector2(cos(ang), sin(ang)) * 140.0)
	ring.polygon = pts
	ring.color = Color(0.5, 0.1, 0.2, 0.4)
	ring.scale = Vector2(0.1, 0.1)
	cloud.add_child(ring)

	var tw := cloud.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(2.0, 2.0), 2.0).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "color:a", 0.0, 2.0).set_ease(Tween.EASE_IN)
	tw.tween_interval(1.5)
	tw.tween_callback(func(): cloud.queue_free())

## 酸雨命中：暗红色粒子爆炸
static func _create_acid_hit(pos: Vector2) -> void:
	if _battlefield == null or not (_battlefield is Node2D):
		return
	var hit := Node2D.new()
	hit.position = pos
	_battlefield.add_child(hit)

	var p := CPUParticles2D.new()
	p.emitting = true
	p.lifetime = 0.6
	p.amount = 10
	p.one_shot = true
	p.explosiveness = 0.9
	p.direction = Vector2(0, 0)
	p.spread = 80.0
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 70.0
	p.gravity = Vector2(0, 50)
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.0

	var gradient := Gradient.new()
	gradient.add_point(0.0, Color(0.8, 0.2, 0.3, 1.0))
	gradient.add_point(0.5, Color(0.5, 0.1, 0.2, 0.7))
	gradient.add_point(1.0, Color.TRANSPARENT)
	p.color_ramp = gradient
	hit.add_child(p)

	var tw := hit.create_tween()
	tw.tween_interval(0.6)
	tw.tween_callback(func(): hit.queue_free())

## 能量罩：暗红色六边形网格（敌方护盾，区别于我方蓝色）
static func _create_shield_dome(pos: Vector2) -> void:
	if _battlefield == null or not (_battlefield is Node2D):
		return
	var dome := Node2D.new()
	dome.position = pos
	_battlefield.add_child(dome)
	var hex_positions: Array[Vector2] = [
		Vector2(0, 0),
		Vector2(28, 0), Vector2(-28, 0),
		Vector2(14, 24), Vector2(-14, 24),
		Vector2(14, -24), Vector2(-14, -24),
	]
	var hexes: Array[Polygon2D] = []
	var hex_size: float = 17.0
	for i in range(hex_positions.size()):
		var hex := Polygon2D.new()
		hex.polygon = _make_hexagon_points(hex_size)
		hex.position = hex_positions[i]
		hex.color = Color(0.8, 0.2, 0.2, 0.0)
		hex.modulate.a = 0.0
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		hex.material = mat
		dome.add_child(hex)
		hexes.append(hex)
	var glow := ColorRect.new()
	glow.size = Vector2(60, 60)
	glow.position = Vector2(-30, -30)
	glow.color = Color(0.7, 0.2, 0.2, 0.3)
	glow.modulate.a = 0.0
	dome.add_child(glow)
	var tw := dome.create_tween()
	tw.set_parallel(true)
	tw.tween_property(glow, "modulate:a", 1.0, 0.2)
	for i in range(hexes.size()):
		var hex := hexes[i]
		var delay := 0.05 + hex_positions[i].length() * 0.012
		tw.tween_property(hex, "modulate:a", 1.0, 0.15).set_delay(delay)
	tw.chain().tween_interval(1.5)
	tw.set_parallel(true)
	for hex in hexes:
		tw.tween_property(hex, "modulate:a", 0.0, 0.5)
	tw.tween_property(glow, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(func(): dome.queue_free())

## 生成六边形顶点（平顶六边形）
static func _make_hexagon_points(size: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(6):
		var ang := (TAU * i) / 6.0
		pts.append(Vector2(cos(ang), sin(ang)) * size)
	return pts

## 狂暴光环：单位脚下红色脉动环
static func _create_rage_aura(pos: Vector2) -> void:
	if _battlefield == null or not (_battlefield is Node2D):
		return
	var aura := Node2D.new()
	aura.position = pos
	_battlefield.add_child(aura)
	var ring := Polygon2D.new()
	var segments := 32
	var pts := PackedVector2Array()
	for i in range(segments):
		var ang := (TAU * i) / segments
		pts.append(Vector2(cos(ang), sin(ang)) * 25.0)
	ring.polygon = pts
	ring.color = Color(1.0, 0.2, 0.1, 0.6)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	ring.material = mat
	aura.add_child(ring)
	var tw := aura.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(1.5, 1.5), 0.3)
	tw.tween_property(ring, "color:a", 0.0, 0.5)
	tw.chain().tween_callback(func(): aura.queue_free())
