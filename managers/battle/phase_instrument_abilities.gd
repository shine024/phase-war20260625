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
## v6.6: 超级火炮连击复用正式火炮曲射弹道
const BulletScene = preload("res://scenes/units/bullet.tscn")
## 曲射炮击起点偏移：目标正上方 + 左右随机，保证从屏幕外抛物线飞入
const ARTILLERY_SHOT_OFFSET_Y: float = -800.0
const ARTILLERY_SHOT_OFFSET_X: float = 300.0

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
## 纳米虫群剩余持续时间
static var _nano_swarm_remaining: float = 0.0
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

## 每帧调用：驱动周期能力（火炮连发/核子轰炸/纳米虫群持续）
static func update(delta: float) -> void:
	if not _battle_active or _active_ability.is_empty():
		return
	var ability_id: String = String(_active_ability.get("id", ""))
	var atype: String = String(_active_ability.get("type", ""))
	# 纳米虫群持续掉血
	if _nano_swarm_remaining > 0.0:
		_nano_swarm_remaining -= delta
		_apply_nano_swarm_tick(delta)
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
	_nano_swarm_remaining = 0.0
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
		"nano_swarm":
			_nano_swarm_remaining = float(params.get("duration", 30.0))
			# v7.x 正式动画：紫色纳米虫群覆盖战场
			if _battlefield is Node2D:
				var center: Vector2 = (_battlefield as Node2D).global_position
				_create_nano_swarm_cloud(center)
			_trigger_screen_shake(5.0, 0.4)
			_show_toast("🔮 纳米虫群降临敌方阵营！")
			# v8.1: emit start 信号供 BattleSpectacle 创建全屏紫色降雨层
			_emit_ability_triggered("nano_swarm", "start", {"duration": _nano_swarm_remaining})
		"mega_shield":
			_apply_mega_shield(params)
			_show_toast("🛡 巨型能量罩笼罩我方全体！")
			# v8.1: emit start 信号供 BattleSpectacle 播放全屏能量罩降临闪光
			_emit_ability_triggered("mega_shield", "start", {"shield_amount": float(params.get("shield_amount", 3000.0))})

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
	# 随机选一个敌方单位（"不确定的敌方单位"）
	var target: Node = enemies[randi() % enemies.size()]
	if target == null or not is_instance_valid(target) or not (target is Node2D):
		return
	var dmg: float = _compute_artillery_damage()
	# v6.6 超级火炮连击：复用正式火炮曲射弹道（INDIRECT），从屏幕外抛物线飞入
	var bullet: Node2D = ObjectPoolManager.get_object("bullets") if ObjectPoolManager != null else null
	if bullet == null:
		bullet = BulletScene.instantiate()
	# 起点：目标正上方 + 左右随机偏移，保证从屏幕外飞入且有横向弧度
	var tpos: Vector2 = (target as Node2D).global_position
	bullet.global_position = tpos + Vector2(randf_range(-ARTILLERY_SHOT_OFFSET_X, ARTILLERY_SHOT_OFFSET_X), ARTILLERY_SHOT_OFFSET_Y)
	# weapon_type=1 (INDIRECT) → 曲射弹道；我方攻击；抑制炮口火焰（屏幕外无炮口）
	bullet.setup(target, dmg, true, 1, null, null, false, "")
	bullet.suppress_muzzle = true
	# 挂到场景树（对象池取出时不在树中）
	var current_parent: Node = bullet.get_parent()
	if current_parent != _battlefield:
		if current_parent != null:
			current_parent.remove_child(bullet)
		_battlefield.add_child(bullet)

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
	# v8.1: emit warning 信号供 BattleSpectacle 播放全屏红屏预警
	var first_pos: Vector2 = Vector2.ZERO
	if not enemies.is_empty() and enemies[0] is Node2D:
		first_pos = (enemies[0] as Node2D).global_position
	_emit_ability_triggered("nuclear_bombardment", "warning", {"damage": base_dmg, "position": first_pos, "count": enemies.size()})
	var mark_delay: float = 0.35
	var fired_impact: bool = false
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
			# v8.1: 上升烟柱粒子（核爆蘑菇云效果）
			_spawn_smoke_column(cur_pos, Color(0.5, 0.85, 0.4, 0.6))
			if is_instance_valid(captured_enemy):
				CombatFeedback.show_damage(cur_pos, base_dmg, captured_enemy, true, "critical")
				if captured_enemy.has_method("take_damage"):
					captured_enemy.take_damage(base_dmg, null)
			# v8.1: 首次爆炸时 emit impact 信号（供 BattleSpectacle 白闪定帧）
			if not fired_impact:
				fired_impact = true
				_emit_ability_triggered("nuclear_bombardment", "impact", {"position": cur_pos, "damage": base_dmg})
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

# ── 纳米虫群（持续百分比掉血）──
static func _apply_nano_swarm_tick(delta: float) -> void:
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
			# v7.x: 伤害数字由 take_damage → unit_damaged 信号统一驱动，
			# 仅保留纳米虫群命中视觉特效。
			if show_vfx_this_frame and i % 3 == 0 and e is Node2D:
				var epos: Vector2 = (e as Node2D).global_position
				_create_nano_swarm_hit(epos)

## ── 巨型能量罩 ──
static func _apply_mega_shield(params: Dictionary) -> void:
	if _battlefield == null:
		return
	var shield_amount: float = float(params.get("shield_amount", 3000.0))
	# 每单位上限3000护盾
	shield_amount = minf(shield_amount, 3000.0)
	var allies: Array = _get_player_units()
	# v7.x 正式动画：蓝色能量罩降临每个友军 + 战场中央光环
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

## v8.1: emit 相位仪能力触发信号（供 BattleSpectacle 编排全屏演出）
static func _emit_ability_triggered(ability_id: String, stage: String, params: Dictionary = {}) -> void:
	var sb := Engine.get_main_loop() as SceneTree
	if sb == null or sb.root == null:
		return
	if sb.root.has_node("/root/SignalBus"):
		var SignalBusRef = sb.root.get_node("/root/SignalBus")
		if SignalBusRef and SignalBusRef.has_signal("phase_instrument_ability_triggered"):
			SignalBusRef.phase_instrument_ability_triggered.emit(ability_id, stage, params)

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

## 纳米虫群云：大范围紫色粒子覆盖（替代酸雨云）
static func _create_nano_swarm_cloud(center: Vector2) -> void:
	"""在战场中央生成大范围紫色纳米虫群"""
	if _battlefield == null or not (_battlefield is Node2D):
		return
	var cloud := Node2D.new()
	cloud.position = center
	_battlefield.add_child(cloud)
	
	# 大范围紫色纳米粒子（密集飞散效果）
	var p1 := CPUParticles2D.new()
	p1.emitting = true
	p1.lifetime = 3.0
	p1.amount = 80
	p1.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p1.emission_sphere_radius = 180.0
	p1.direction = Vector2(0, -1)  # 向上扩散
	p1.spread = 45.0
	p1.initial_velocity_min = 40.0
	p1.initial_velocity_max = 120.0
	p1.gravity = Vector2(0, 50)   # 轻微下沉
	p1.scale_amount_min = 0.6
	p1.scale_amount_max = 1.8
	
	# 紫色渐变（亮紫→暗紫→透明）
	var gradient := Gradient.new()
	gradient.add_point(0.0, Color(0.7, 0.2, 1.0, 1.0))
	gradient.add_point(0.4, Color(0.5, 0.1, 0.8, 0.8))
	gradient.add_point(0.8, Color(0.3, 0.05, 0.6, 0.3))
	gradient.add_point(1.0, Color.TRANSPARENT)
	p1.color_ramp = gradient
	
	cloud.add_child(p1)
	
	# 第二层：慢速漂浮的纳米微粒（营造"虫群"感）
	var p2 := CPUParticles2D.new()
	p2.emitting = true
	p2.lifetime = 4.0
	p2.amount = 40
	p2.one_shot = false
	# 注：CPUParticles2D 没有 autofree 属性（autofree 仅存在于 RefCounted 资源）。
	# p2 作为 cloud 的子节点，会在 cloud.queue_free() 时自动随之释放。
	p2.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p2.emission_sphere_radius = 100.0
	p2.direction = Vector2(0, 0)  # 悬浮不动
	p2.spread = 90.0
	p2.initial_velocity_min = 5.0
	p2.initial_velocity_max = 25.0
	p2.gravity = Vector2(0, 10)
	p2.scale_amount_min = 0.3
	p2.scale_amount_max = 0.8
	# 注：原代码尝试条件 preload 一个不存在的 nano_process_material.gd，
	# 但 preload 是编译期指令，ResourceLoader.exists 守卫无法阻止其求值，
	# 会导致 "Preload file does not exist" 报错。CPUParticles2D 无自定义
	# process_material 时使用默认行为，配合 color_ramp 已足够，直接移除。

	var grad2 := Gradient.new()
	grad2.add_point(0.0, Color(0.9, 0.5, 1.0, 1.0))
	grad2.add_point(0.5, Color(0.6, 0.3, 0.9, 0.6))
	grad2.add_point(1.0, Color.TRANSPARENT)
	p2.color_ramp = grad2
	
	cloud.add_child(p2)
	
	# 地面腐蚀圈改为纳米虫群聚集环
	var ring := Polygon2D.new()
	var segments := 48
	var pts := PackedVector2Array()
	for i in range(segments):
		var ang := (TAU * i) / segments
		pts.append(Vector2(cos(ang), sin(ang)) * 140.0)
	ring.polygon = pts
	ring.color = Color(0.5, 0.15, 0.9, 0.5)
	ring.scale = Vector2(0.1, 0.1)
	cloud.add_child(ring)
	
	var tw := cloud.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(2.0, 2.0), 2.0).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "color:a", 0.0, 2.0).set_ease(Tween.EASE_IN)
	tw.tween_interval(1.5)
	tw.tween_callback(func(): cloud.queue_free())

## 纳米虫群命中：紫色粒子爆炸（替代酸液滴落）
static func _create_nano_swarm_hit(pos: Vector2) -> void:
	"""单个纳米虫群命中效果——紫色粒子向四周飞散"""
	if _battlefield == null or not (_battlefield is Node2D):
		return
	var hit := Node2D.new()
	hit.position = pos
	_battlefield.add_child(hit)
	
	# 紫色纳米粒子爆炸
	var p := CPUParticles2D.new()
	p.emitting = true
	p.lifetime = 0.6
	p.amount = 12
	p.one_shot = true
	p.explosiveness = 0.9
	p.direction = Vector2(0, 0)
	p.spread = 80.0
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 80.0
	p.gravity = Vector2(0, 50)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	
	var gradient := Gradient.new()
	gradient.add_point(0.0, Color(0.9, 0.4, 1.0, 1.0))
	gradient.add_point(0.5, Color(0.6, 0.2, 0.9, 0.7))
	gradient.add_point(1.0, Color.TRANSPARENT)
	p.color_ramp = gradient
	
	hit.add_child(p)
	
	var tw := hit.create_tween()
	tw.tween_interval(0.6)
	tw.tween_callback(func(): hit.queue_free())

## 能量罩：六边形能量网格（v8.1 重设计——替代原简单圆环）
## 绘制 7 个六边形阵列（中心1+环绕6），按 delay 依次点亮形成波纹展开效果
static func _create_shield_dome(pos: Vector2) -> void:
	if _battlefield == null or not (_battlefield is Node2D):
		return
	var dome := Node2D.new()
	dome.position = pos
	_battlefield.add_child(dome)
	# 六边形阵列坐标：中心 + 6 环绕（v8.1a：半径22→28，加大能量罩范围）
	var hex_positions: Array[Vector2] = [
		Vector2(0, 0),
		Vector2(28, 0), Vector2(-28, 0),
		Vector2(14, 24), Vector2(-14, 24),
		Vector2(14, -24), Vector2(-14, -24),
	]
	var hexes: Array[Polygon2D] = []
	var hex_size: float = 17.0  # v8.1a：14→17，六边形更大
	for i in range(hex_positions.size()):
		var hex := Polygon2D.new()
		hex.polygon = _make_hexagon_points(hex_size)
		hex.position = hex_positions[i]
		hex.color = Color(0.3, 0.75, 1.0, 0.0)  # 初始透明
		hex.modulate.a = 0.0
		# ADD 混合让网格更亮
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		hex.material = mat
		dome.add_child(hex)
		hexes.append(hex)
	# 中心光晕
	var glow := ColorRect.new()
	glow.size = Vector2(60, 60)
	glow.position = Vector2(-30, -30)
	glow.color = Color(0.3, 0.7, 1.0, 0.3)
	glow.modulate.a = 0.0
	dome.add_child(glow)
	# 六边形逐个点亮（波纹展开）
	var tw := dome.create_tween()
	tw.set_parallel(true)
	tw.tween_property(glow, "modulate:a", 1.0, 0.2)
	for i in range(hexes.size()):
		var hex := hexes[i]
		# 从中心向外按 delay 点亮
		var delay := 0.05 + hex_positions[i].length() * 0.012
		tw.tween_property(hex, "modulate:a", 1.0, 0.15).set_delay(delay)
	# 保持 1.5s 后淡出（降临动画 2.5s 总时长）
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

## v8.1: 上升烟柱粒子（核爆蘑菇云效果）（v8.1a：加倍粒子量+加大尺寸，真蘑菇云）
static func _spawn_smoke_column(pos: Vector2, tint: Color = Color(0.5, 0.5, 0.5, 0.5)) -> void:
	if _battlefield == null or not is_instance_valid(_battlefield):
		return
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = 36  # v8.1a：16→36，蘑菇云密度
	p.lifetime = 2.4  # v8.1a：1.8→2.4，烟柱持续更久
	p.one_shot = false
	p.emitting = true
	p.explosiveness = 0.25
	p.direction = Vector2(0, -1)  # 向上
	p.spread = 30.0  # v8.1a：25→30，蘑菇头扩散
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 110.0  # v8.1a：提速，烟柱窜得更高
	p.gravity = Vector2(0, -20.0)  # 持续上飘
	p.scale_amount_min = 5.0  # v8.1a：4→5
	p.scale_amount_max = 11.0  # v8.1a：8→11，蘑菇云更大
	p.color = tint
	# 烟柱渐变：底部浓→顶部淡
	var grad := Gradient.new()
	grad.add_point(0, Color(tint.r, tint.g, tint.b, 0.85))
	grad.add_point(0.5, Color(tint.r, tint.g, tint.b, 0.45))
	grad.add_point(1.0, Color(tint.r, tint.g, tint.b, 0.0))
	p.color_ramp = grad
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	_battlefield.add_child(p)
	# 2.5s 后停止发射并回收（v8.1a：2→2.5s）
	var tree := _battlefield.get_tree()
	if tree != null:
		var timer := tree.create_timer(2.5)
		timer.timeout.connect(func():
			p.emitting = false
			# +0.1s 余量让残余粒子彻底淡出（虽已停发射，仍防帧率波动截断尾段）
			var t2 := tree.create_timer(p.lifetime + 0.1)
			t2.timeout.connect(func(): p.queue_free())
		)
