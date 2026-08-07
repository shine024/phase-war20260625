class_name PhaseInstrumentAbilities
extends RefCounted
## v6.6 / v8.5: 统一 owner-aware 相位仪主动特殊能力引擎
## 合并原 PhaseInstrumentAbilities（玩家版）+ EnemyPhaseInstrumentAbilities（敌方版）为单引擎。
## 双 owner 并存：玩家与敌方能力可在同一场战斗各自激活，状态按 owner 分键。
##
## 方向纯靠 owner（忽略 ability dict 的 target 字段——仅描述性，不参与逻辑）：
##   PLAYER 持有：targets = EnemyUnits，allies = PlayerUnits
##   ENEMY  持有：targets = PlayerUnits，allies = EnemyUnits
##
## 能力 id 裸化（统一去除 enemy_ 前缀），共 5 个：
##   nano_swarm（持续百分比掉血）/ artillery_barrage（火炮连发）/ mega_shield（能量罩，原 enemy_shield_bulwark 并入）
##   nuclear_bombardment（核子轰炸）/ rage_buff（狂暴，原敌方专属，已搬入）
##
## 处理 type=periodic（周期触发）和 type=on_battle_start（开局一次性）能力。
## passive（被动常驻）能力由 battle_spawn_system / attack_calculator 直接查询相位仪数据，
## 不经过本类。

const CombatFeedback = preload("res://scripts/combat_feedback.gd")
const VfxImpactFactory = preload("res://scripts/battle/vfx_impact_factory.gd")
const PhaseLawCastEffect = preload("res://scenes/effects/phase_law_cast_effect.gd")
const ScreenShakeScript = preload("res://scenes/effects/screen_shake.gd")
## v6.6: 超级火炮连击复用正式火炮曲射弹道
const BulletScene = preload("res://scenes/units/bullet.tscn")
## 曲射炮击起点偏移：目标正上方 + 左右随机，保证从屏幕外抛物线飞入
const ARTILLERY_SHOT_OFFSET_Y: float = -800.0
const ARTILLERY_SHOT_OFFSET_X: float = 300.0

enum Owner { PLAYER, ENEMY }

# ─── 双 owner 状态（按 owner 分键，不可退回单一 _owner）──
## 各 owner 当前激活的能力（战斗开始时从相位仪读取，战斗中不变）
static var _player_active: Dictionary = {}
static var _enemy_active: Dictionary = {}
## 周期能力计时器  key: "<owner_key>:<ability_id>" -> elapsed
static var _periodic_timers: Dictionary = {}
## 纳米虫群剩余持续时间  "<owner_key>" -> float
static var _nano_remaining: Dictionary = {}
## v7.x 性能优化：纳米虫群 tick 累加器  "<owner_key>" -> accumulated_delta
## nano_swarm 每 take_damage 触发 6 个 unit_damaged 订阅者，每帧×目标数开销大。
## 改为每 0.25s 累积一次结算（数值等价，take_damage 调用频率降 4×）。
static var _nano_tick_acc: Dictionary = {}
const NANO_TICK_INTERVAL: float = 0.25
## 火炮连发队列  "<owner_key>" -> Array[{fire_at: float, fired: bool}]
static var _barrage_queue: Dictionary = {}
## 狂暴状态  "<owner_key>" -> {active, expire_at, applied, atk_mult, spd_mult}
static var _rage_state: Dictionary = {}
## 战斗是否激活（共享）
static var _battle_active: bool = false
## 战场引用（共享，on_battle_start 时设置）
static var _battlefield: Node = null
## 开局一次性能力是否已触发  "<owner_key>" -> bool
static var _start_fired: Dictionary = {}

# ─────────────────────────────────────────────
#  公共入口
# ─────────────────────────────────────────────

## 战斗开始时调用：读取指定 owner 相位仪的 active_ability，触发开局能力。
## source: 玩家=PhaseInstrumentManager，敌方=EnemyPhaseFieldDriver（均有 get_active_ability()）。
## owner 默认 PLAYER，保持对旧调用方（battle_manager 等）的向后兼容；Task 7 将显式传入。
static func on_battle_start(source: Node, battlefield: Node, owner: Owner = Owner.PLAYER) -> void:
	var ab: Dictionary = _read_ability(source)
	if owner == Owner.PLAYER:
		_player_active = ab
	else:
		_enemy_active = ab
	_battlefield = battlefield
	_battle_active = true
	_start_fired[_owner_key(owner)] = false
	if ab.is_empty():
		return
	_fire_start_abilities(owner)

## 每帧调用：驱动所有 owner 的周期能力（火炮连发/核子轰炸/纳米虫群持续/狂暴）
static func update(delta: float) -> void:
	if not _battle_active:
		return
	# 双 owner 并存：逐 owner 推进，空 ability 跳过
	_update_owner(Owner.PLAYER, _player_active, delta)
	_update_owner(Owner.ENEMY, _enemy_active, delta)

## 战斗结束时重置全部状态（两个 owner 一并清理）
static func reset_state() -> void:
	# 若狂暴仍激活，先恢复 stats（防止残留）
	_expire_rage_if_active(Owner.PLAYER)
	_expire_rage_if_active(Owner.ENEMY)
	_player_active.clear()
	_enemy_active.clear()
	_periodic_timers.clear()
	_nano_remaining.clear()
	_nano_tick_acc.clear()
	_barrage_queue.clear()
	_rage_state.clear()
	_start_fired.clear()
	_battle_active = false
	_battlefield = null

## 获取指定 owner 的 active_ability（被动能力查询也用这个）。
## owner 默认 PLAYER，保持对旧调用方（bullet / attack_calculator）的向后兼容；Task 8 将显式传入。
static func get_active_ability(owner: Owner = Owner.PLAYER) -> Dictionary:
	return _owner_active(owner)

## 获取指定 owner 能力的 params（供 passive 能力的消费方查询）
static func get_active_params(owner: Owner = Owner.PLAYER) -> Dictionary:
	return _owner_active(owner).get("params", {})

# ─────────────────────────────────────────────
#  内部：方向抽象 + owner 工具
# ─────────────────────────────────────────────

static func _owner_key(owner: Owner) -> String:
	return "player" if owner == Owner.PLAYER else "enemy"

static func _owner_active(owner: Owner) -> Dictionary:
	return _player_active if owner == Owner.PLAYER else _enemy_active

## 打击目标：PLAYER 打敌方单位，ENEMY 打玩家单位
static func _get_targets(owner: Owner) -> Array:
	return _get_units("EnemyUnits") if owner == Owner.PLAYER else _get_units("PlayerUnits")

## buff 对象（盟军）：PLAYER buff 玩家单位，ENEMY buff 敌方单位
static func _get_allies(owner: Owner) -> Array:
	return _get_units("PlayerUnits") if owner == Owner.PLAYER else _get_units("EnemyUnits")

## 从 source 读取 ability dict，并裸化 ability_id（删 enemy_ 前缀；shield_bulwark 并入 mega_shield）
static func _read_ability(source: Node) -> Dictionary:
	if source == null:
		return {}
	if not source.has_method("get_active_ability"):
		return {}
	# 复制避免污染 source 内部缓存（仅改顶层 id）
	var ab: Dictionary = source.get_active_ability().duplicate()
	if ab.is_empty():
		return {}
	var aid: String = String(ab.get("id", ""))
	if aid.begins_with("enemy_"):
		aid = aid.substr(6)  # len("enemy_") == 6
	# enemy_shield_bulwark → mega_shield（都加护盾，params 均含 shield_amount）
	if aid == "shield_bulwark":
		aid = "mega_shield"
	ab["id"] = aid
	return ab

## 读取战场下 PlayerUnits / EnemyUnits 容器的有效子节点
static func _get_units(group_node_name: String) -> Array:
	var result: Array = []
	if _battlefield == null:
		return result
	var container: Node = _battlefield.get_node_or_null(group_node_name)
	if container != null:
		for u in container.get_children():
			if is_instance_valid(u):
				result.append(u)
	return result

## owner 文案选择
static func _owner_msg(owner: Owner, player_msg: String, enemy_msg: String) -> String:
	return player_msg if owner == Owner.PLAYER else enemy_msg

# ─────────────────────────────────────────────
#  内部：每帧驱动
# ─────────────────────────────────────────────

static func _update_owner(owner: Owner, ab: Dictionary, delta: float) -> void:
	if ab.is_empty():
		return
	var key: String = _owner_key(owner)
	var atype: String = String(ab.get("type", ""))
	var aid: String = String(ab.get("id", ""))
	# 纳米虫群持续掉血
	var nano_left: float = float(_nano_remaining.get(key, 0.0))
	if nano_left > 0.0:
		_nano_remaining[key] = nano_left - delta
		_apply_nano_swarm_tick(owner, ab, delta)
	# 检查狂暴过期
	_check_rage_expire(owner)
	# 周期能力计时
	if atype == "periodic":
		_tick_periodic(owner, aid, ab, delta)

## 触发开局一次性能力
static func _fire_start_abilities(owner: Owner) -> void:
	var key: String = _owner_key(owner)
	if bool(_start_fired.get(key, false)):
		return
	_start_fired[key] = true
	var ab: Dictionary = _owner_active(owner)
	var ability_id: String = String(ab.get("id", ""))
	var atype: String = String(ab.get("type", ""))
	var params: Dictionary = ab.get("params", {})
	if atype != "on_battle_start":
		return
	match ability_id:
		"nano_swarm":
			_nano_remaining[key] = float(params.get("duration", 30.0))
			# v7.x 正式动画：owner 配色纳米虫群覆盖战场
			if _battlefield is Node2D:
				var center: Vector2 = (_battlefield as Node2D).global_position
				_create_nano_swarm_cloud(center, owner)
			_trigger_screen_shake(5.0, 0.4)
			_show_toast(_owner_msg(owner,
				"🔮 纳米虫群降临敌方阵营！",
				"☠ 敌方相位仪释放纳米虫群！我方单位持续失血！"))
			# v8.1: emit start 信号供 BattleSpectacle 创建全屏降雨层
			_emit_ability_triggered("nano_swarm", "start",
				{"duration": float(_nano_remaining[key]), "is_enemy": owner == Owner.ENEMY})
		"mega_shield":
			_apply_mega_shield(owner, params)
			_show_toast(_owner_msg(owner,
				"🛡 巨型能量罩笼罩我方全体！",
				"🛡 敌方相位仪展开能量壁垒！全体敌兵获得护盾！"))
			# v8.1: emit start 信号供 BattleSpectacle 播放全屏能量罩降临闪光
			_emit_ability_triggered("mega_shield", "start",
				{"shield_amount": float(params.get("shield_amount", 3000.0)), "is_enemy": owner == Owner.ENEMY})

## 周期能力分派
static func _tick_periodic(owner: Owner, aid: String, ab: Dictionary, delta: float) -> void:
	# 先处理火炮连发的待发射队列
	_process_barrage_queue(owner, delta)
	match aid:
		"artillery_barrage":
			_tick_artillery_barrage(owner, ab.get("params", {}), delta)
		"nuclear_bombardment":
			_tick_nuclear_bombardment(owner, ab.get("params", {}), delta)
		"rage_buff":
			_tick_rage_buff(owner, ab.get("params", {}), delta)

# ── 火炮连发（periodic）──
static func _tick_artillery_barrage(owner: Owner, params: Dictionary, delta: float) -> void:
	var pkey: String = _owner_key(owner) + ":artillery_barrage"
	var interval: float = float(params.get("interval", 10.0))
	var elapsed: float = float(_periodic_timers.get(pkey, interval))  # 首次跳过等待
	elapsed += delta
	if elapsed >= interval:
		elapsed = 0.0
		var shots: int = int(params.get("shots", 7))
		var shot_interval: float = float(params.get("shot_interval", 1.0))
		# 排队连发：每 shot_interval 发射一发
		var bq_key: String = _owner_key(owner)
		if not _barrage_queue.has(bq_key):
			_barrage_queue[bq_key] = []
		var queue: Array = _barrage_queue[bq_key]
		for i in range(shots):
			queue.append({"fire_at": float(i) * shot_interval, "fired": false})
		_show_toast(_owner_msg(owner,
			"💥 火炮连发启动！",
			"💥 敌方相位仪炮击！我方阵地遭轰击！"))
	_periodic_timers[pkey] = elapsed

static func _process_barrage_queue(owner: Owner, delta: float) -> void:
	var key: String = _owner_key(owner)
	var queue: Array = _barrage_queue.get(key, [])
	if queue.is_empty():
		return
	for entry in queue:
		if not bool(entry.get("fired", false)):
			var fire_at: float = float(entry.get("fire_at", 0.0))
			fire_at -= delta
			entry["fire_at"] = fire_at
			if fire_at <= 0.0:
				entry["fired"] = true
				_fire_artillery_shot(owner)
	# 清理已发射的
	_barrage_queue[key] = queue.filter(func(e): return not bool(e.get("fired", true)))

## 单发炮击：PLAYER=曲射弹道（玩家 v6.6 升级），ENEMY=红色标记+延迟爆炸（敌方风格，VFX owner 配色）
static func _fire_artillery_shot(owner: Owner) -> void:
	if _battlefield == null:
		return
	var targets: Array = _get_targets(owner)
	if targets.is_empty():
		return
	# 随机选一个目标单位（"不确定的敌方/玩家单位"）
	var target: Node = targets[randi() % targets.size()]
	if target == null or not is_instance_valid(target) or not (target is Node2D):
		return
	var dmg: float = _compute_artillery_damage(owner)
	if owner == Owner.PLAYER:
		_fire_artillery_shot_player(target, dmg)
	else:
		_fire_artillery_shot_enemy(target, dmg)

## 玩家曲射炮击：复用正式火炮曲射弹道（INDIRECT），从屏幕外抛物线飞入
static func _fire_artillery_shot_player(target: Node, dmg: float) -> void:
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

## 敌方炮击：红色标记（警告）→ 延迟 → 爆炸 + 伤害（VFX 敌方配色：红标记/橙冲击波）
static func _fire_artillery_shot_enemy(target: Node, dmg: float) -> void:
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
		# v8.4: 迁移自 visual_effects_manager.create_explosion → VfxImpactFactory（三层组合特效）
		# 大冲击波（橙色炮击）+ 完整爆炸配方（碎片/烟尘）
		VfxImpactFactory.spawn_shockwave(_battlefield, cur_pos, 100.0, Color(1.0, 0.4, 0.2, 0.85))
		VfxImpactFactory.spawn_layered_impact(_battlefield, cur_pos, 3, false, -1)
		if is_instance_valid(captured_target):
			CombatFeedback.show_damage(cur_pos, captured_dmg, captured_target, false, "critical")
			if captured_target.has_method("take_damage"):
				captured_target.take_damage(captured_dmg, null)
	)

## 炮击伤害：基于 buff 对象（allies）平均攻击力 × owner 倍率
static func _compute_artillery_damage(owner: Owner) -> float:
	var allies: Array = _get_allies(owner)
	if allies.is_empty():
		return 50.0 if owner == Owner.PLAYER else 80.0
	var total_atk: float = 0.0
	var count: int = 0
	for u in allies:
		if u and "stats" in u and u.stats != null:
			total_atk += float(u.stats.attack_damage)
			count += 1
	if count == 0:
		return 50.0 if owner == Owner.PLAYER else 80.0
	var mult: float = 1.5 if owner == Owner.PLAYER else 1.2  # 玩家×1.5 / 敌方×1.2
	return (total_atk / float(count)) * mult

# ── 核子轰炸（periodic）──
static func _tick_nuclear_bombardment(owner: Owner, params: Dictionary, delta: float) -> void:
	var pkey: String = _owner_key(owner) + ":nuclear_bombardment"
	var interval: float = float(params.get("interval", 30.0))
	var elapsed: float = float(_periodic_timers.get(pkey, interval))
	elapsed += delta
	if elapsed >= interval:
		elapsed = 0.0
		_fire_nuclear_bombardment(owner, params)
	_periodic_timers[pkey] = elapsed

static func _fire_nuclear_bombardment(owner: Owner, params: Dictionary) -> void:
	if _battlefield == null:
		return
	var dmg_mult: float = float(params.get("dmg_mult", 1.0))
	var base_dmg: float = _compute_nuclear_damage(owner) * dmg_mult
	var targets: Array = _get_targets(owner)
	# v6.6 正式动画：分两阶段——先标记（警告），延迟后核爆 + 伤害结算
	# v8.1: emit warning 信号供 BattleSpectacle 播放全屏红屏预警
	var first_pos: Vector2 = Vector2.ZERO
	if not targets.is_empty() and targets[0] is Node2D:
		first_pos = (targets[0] as Node2D).global_position
	_emit_ability_triggered("nuclear_bombardment", "warning",
		{"damage": base_dmg, "position": first_pos, "count": targets.size(), "is_enemy": owner == Owner.ENEMY})
	# owner 选色：玩家=紫青能量调（与战术核武橙白写实核爆互补色，差异最大）；敌方=红橙
	# 去蘑菇云（核武专属符号），改能量光柱从天而降——核子轰炸=科幻能量武器，非核武器
	var mark_color: Color = Color(0.6, 0.3, 1.0, 1.0) if owner == Owner.PLAYER else Color(1.0, 0.2, 0.2, 1.0)
	var shock_color: Color = Color(0.3, 0.7, 1.0, 0.85) if owner == Owner.PLAYER else Color(1.0, 0.4, 0.2, 0.85)
	var beam_color: Color = Color(0.5, 0.6, 1.0, 0.7) if owner == Owner.PLAYER else Color(1.0, 0.5, 0.3, 0.7)
	var layer_count: int = 9 if owner == Owner.PLAYER else 3
	var layer_critical: bool = true if owner == Owner.PLAYER else false
	var mark_delay: float = 0.35
	var fired_impact: bool = false
	# 预加载核爆贴图包（循环外加载一次，循环内复用；缺失的贴图自动跳过对应层）
	var nuke_textures: Dictionary = _load_nuke_texture_pack()
	# 核爆配色（与战术核武统一橙白写实，但保留 owner 分流供将来扩展）
	var nuke_colors: Dictionary = {
		"shock": shock_color,
		"aftershock": Color(0.9, 0.5, 0.2, 0.5) if owner == Owner.PLAYER else Color(1.0, 0.4, 0.2, 0.5),
		"smoke": Color(0.35, 0.32, 0.30, 0.6),
	}
	for e in targets:
		if e == null or not is_instance_valid(e):
			continue
		var epos: Vector2 = (e as Node2D).global_position if e is Node2D else Vector2.ZERO
		# 第一阶段：标记（立即出现，提示轰炸即将命中）
		PhaseLawCastEffect.create_phase_law_effect(_battlefield, epos, mark_color)
		# 第二阶段：延迟核爆 + 伤害结算（用 tween，避免阻塞；结算时复查有效性）
		var captured_enemy = e
		var captured_pos = epos
		var tw := _battlefield.create_tween()
		tw.tween_interval(mark_delay)
		tw.tween_callback(func():
			if _battlefield == null or not is_instance_valid(_battlefield):
				return
			# 延迟后目标可能已死亡/移除，跟踪其当前位置
			var cur_pos: Vector2 = captured_pos
			if is_instance_valid(captured_enemy) and captured_enemy is Node2D:
				cur_pos = (captured_enemy as Node2D).global_position
			# 完整核爆效果（火球+冲击波+蘑菇云帧动画+焦痕），复用战术核武同一套 VFX
			# 核子轰炸=全域多点核爆，每个敌方位置都打；全局闪白/震屏由 BattleSpectacle 首次触发
			# size_scale=0.6：多点核爆每个缩小（半径200→120/余波320→192），避免视觉覆盖到靠近的我方单位
			VfxImpactFactory.spawn_nuclear_explosion(_battlefield, cur_pos, nuke_textures, nuke_colors, 0.6)
			if is_instance_valid(captured_enemy):
				CombatFeedback.show_damage(cur_pos, base_dmg, captured_enemy, true, "critical")
				if captured_enemy.has_method("take_damage"):
					captured_enemy.take_damage(base_dmg, null)
			# v8.1: 首次爆炸时 emit impact 信号（供 BattleSpectacle 白闪定帧）
			if not fired_impact:
				fired_impact = true
				_emit_ability_triggered("nuclear_bombardment", "impact",
					{"position": cur_pos, "damage": base_dmg, "is_enemy": owner == Owner.ENEMY})
		)
	# 全屏震动（与标记同步出现，强化预警冲击）
	_trigger_screen_shake(10.0, 0.6)
	_show_toast(_owner_msg(owner,
		"☢ 核子轰炸！敌方全体受到 %.0f 伤害" % base_dmg,
		"☢ 敌方核子轰炸！我方全体受到 %.0f 伤害" % base_dmg))


## 预加载核爆贴图包（供 spawn_nuclear_explosion 使用）。
## 火球/冲击波/焦痕/蘑菇云单帧/蘑菇云9帧序列，缺失的自动跳过（部分核爆仍可见）。
static func _load_nuke_texture_pack() -> Dictionary:
	var pack: Dictionary = {}
	var dir := "res://assets/effects/nuclear/"
	# 单帧贴图
	for key in ["fireball", "shockwave", "burn", "mushroom"]:
		var path: String = dir + "nuke_" + str(key) + ".png"
		if ResourceLoader.exists(path):
			pack[key] = load(path)
	# 蘑菇云9帧序列（精灵表切割产物）
	var frames: Array = []
	for i in 9:
		var fpath := dir + "nuke_mushroom_f" + str(i) + ".png"
		if ResourceLoader.exists(fpath):
			var tex = load(fpath)
			if tex != null:
				frames.append(tex)
			else:
				frames.clear()
				break
		else:
			frames.clear()
			break
	if not frames.is_empty():
		pack["mushroom_frames"] = frames
	return pack


static func _compute_nuclear_damage(owner: Owner) -> float:
	# 固定基础伤害 + allies 总攻击力比例，确保有实质威胁
	var allies: Array = _get_allies(owner)
	var total_atk: float = 0.0
	for u in allies:
		if u and "stats" in u and u.stats != null:
			total_atk += float(u.stats.attack_damage)
	return 300.0 + total_atk * 0.5  # 基础300 + 总攻击力50%

# ── 纳米虫群（on_battle_start，持续百分比掉血）──
# v7.x 性能优化：节流到 NANO_TICK_INTERVAL(0.25s) 累积一次结算。
# 原实现每帧 take_damage×目标数，每 take_damage 触发 6 个 unit_damaged 订阅者，
# 30 秒持续期间是稳定掉帧源。改后 take_damage 频率降 4×，伤害数值完全等价（hp_pct × tick_delta）。
static func _apply_nano_swarm_tick(owner: Owner, ab: Dictionary, delta: float) -> void:
	if _battlefield == null:
		return
	var key: String = _owner_key(owner)
	# 累加 delta，未满一个 tick 则跳过本帧（伤害在 tick 结算时按整 tick 计算，数值等价）
	var acc: float = float(_nano_tick_acc.get(key, 0.0)) + delta
	if acc < NANO_TICK_INTERVAL:
		_nano_tick_acc[key] = acc
		return
	# 消费一个 tick（不保留余数，误差 < NANO_TICK_INTERVAL 可接受；nano_swarm 是百分比掉血非精确伤害）
	_nano_tick_acc[key] = 0.0
	var tick_delta: float = NANO_TICK_INTERVAL

	var params: Dictionary = ab.get("params", {})
	var hp_pct: float = float(params.get("hp_pct_per_sec", 0.02))
	# v9.1: nano_swarm 注入战场纳米浓度（套路3 纳米浓度场）——按存活敌方单位数累积。
	# 每个敌方单位每 tick 贡献 0.5 浓度（tick=0.25s，即每单位每秒 +2.0 浓度）。
	# 浓度供纳米病毒改造读取增伤 + 纳米感染扩散触发。
	var _combo_fs: RefCounted = null
	var _ml := Engine.get_main_loop()
	var _bm_for_combo: Node = null
	if _ml != null and _ml is SceneTree and (_ml as SceneTree).root != null:
		_bm_for_combo = (_ml as SceneTree).root.get_node_or_null("BattleManager")
	if _bm_for_combo != null and _bm_for_combo.has_method("get_combo_field_state"):
		_combo_fs = _bm_for_combo.get_combo_field_state()
	var targets: Array = _get_targets(owner)
	if _combo_fs != null and targets.size() > 0:
		var _CFS = preload("res://scripts/battle/combo_field_state.gd")
		_combo_fs.add_field(_CFS.FIELD_NANO, float(targets.size()) * 0.5, 0.8, 30.0)
	for e in targets:
		if e == null or not is_instance_valid(e):
			continue
		var max_hp: float = 0.0
		if "stats" in e and e.stats != null:
			max_hp = float(e.stats.max_hp)
		elif "max_hp" in e:
			max_hp = float(e.max_hp)
		if max_hp <= 0.0:
			continue
		var dmg: float = max_hp * hp_pct * tick_delta
		if dmg > 0.0 and e.has_method("take_damage"):
			e.take_damage(dmg, null)
			# v7.x: 伤害数字由 take_damage → unit_damaged 信号统一驱动，
			# 每 tick 显示一次命中视觉特效（频率已从每帧降到每 0.25s）。
			if e is Node2D:
				_create_nano_swarm_hit((e as Node2D).global_position, owner)

# ── 巨型能量罩（on_battle_start，给 allies 加护盾）──
static func _apply_mega_shield(owner: Owner, params: Dictionary) -> void:
	if _battlefield == null:
		return
	var shield_amount: float = float(params.get("shield_amount", 3000.0))
	# v7.x 平衡修订：护盾上限由生成器 ability_mega_shield 按星级决定（4★3000/6★5000/7★8000），
	# 此处不再二次压制（原硬上限 3000 会让高星级护盾空转）。
	var allies: Array = _get_allies(owner)
	# v7.x 正式动画：能量罩降临每个盟军 + 战场中央光环（owner 配色）
	for u in allies:
		if u == null or not is_instance_valid(u):
			continue
		if u.has_method("add_shield"):
			u.add_shield(shield_amount)
		if u is Node2D:
			_create_shield_dome((u as Node2D).global_position, owner)
	_trigger_screen_shake(6.0, 0.4)

# ── 狂暴（periodic，临时提升 allies 攻击/攻速；自敌方版搬入）──

static func _tick_rage_buff(owner: Owner, params: Dictionary, delta: float) -> void:
	var key: String = _owner_key(owner)
	# 若狂暴已激活，等待其过期（_check_rage_expire 在 _update_owner 中调用）
	if bool(_rage_state.get(key, {}).get("active", false)):
		return
	var pkey: String = key + ":rage_buff"
	var interval: float = float(params.get("interval", 15.0))
	var elapsed: float = float(_periodic_timers.get(pkey, interval))
	elapsed += delta
	if elapsed >= interval:
		elapsed = 0.0
		_activate_rage_buff(owner, params)
	_periodic_timers[pkey] = elapsed

## 激活狂暴：给所有 allies 临时提升攻击力/攻速
static func _activate_rage_buff(owner: Owner, params: Dictionary) -> void:
	var key: String = _owner_key(owner)
	var duration: float = float(params.get("duration", 5.0))
	var atk_mult: float = float(params.get("atk_mult", 1.4))
	var spd_mult: float = float(params.get("spd_mult", 1.25))
	var applied: Array = []
	var allies: Array = _get_allies(owner)
	for u in allies:
		if u == null or not is_instance_valid(u):
			continue
		if "stats" in u and u.stats != null:
			_apply_rage_to_unit(u, atk_mult, spd_mult, owner)
			applied.append(u)
	_rage_state[key] = {
		"active": true,
		"expire_at": Time.get_ticks_msec() / 1000.0 + duration,
		"applied": applied,
		"atk_mult": atk_mult,
		"spd_mult": spd_mult,
	}
	_trigger_screen_shake(8.0, 0.5)
	_show_toast(_owner_msg(owner,
		"🔥 相位仪激活狂暴！我方攻击力飙升！",
		"🔥 敌方相位仪激活狂暴！敌兵攻击力飙升！"))
	_emit_ability_triggered("rage_buff", "start",
		{"duration": duration, "is_enemy": owner == Owner.ENEMY})

## 对单个单位施加狂暴 stats 乘数（用 owner 化 meta 防重复）
static func _apply_rage_to_unit(unit: Node, atk_mult: float, spd_mult: float, owner: Owner) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	var meta_key: String = "_phase_rage_" + _owner_key(owner)
	if unit.has_meta(meta_key):
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
	unit.set_meta(meta_key, true)
	# owner 配色光环标记
	if unit is Node2D:
		_create_rage_aura((unit as Node2D).global_position, owner)

## 狂暴过期：恢复所有受影响单位的原始 stats
static func _expire_rage_buff(owner: Owner) -> void:
	var key: String = _owner_key(owner)
	var rs: Dictionary = _rage_state.get(key, {})
	if not bool(rs.get("active", false)):
		_rage_state.erase(key)
		return
	var atk_mult: float = float(rs.get("atk_mult", 1.4))
	var spd_mult: float = float(rs.get("spd_mult", 1.25))
	var meta_key: String = "_phase_rage_" + key
	for unit in rs.get("applied", []):
		if unit == null or not is_instance_valid(unit):
			continue
		if unit.has_meta(meta_key):
			var stats = unit.get("stats")
			if stats != null:
				stats.attack_damage /= atk_mult
				if "attack_light_speed" in stats:
					stats.attack_light_speed /= spd_mult
				if "attack_armor_speed" in stats:
					stats.attack_armor_speed /= spd_mult
				if "attack_air_speed" in stats:
					stats.attack_air_speed /= spd_mult
			unit.remove_meta(meta_key)
	rs["active"] = false
	rs["applied"] = []
	_rage_state[key] = rs

## 每帧检查狂暴是否过期
static func _check_rage_expire(owner: Owner) -> void:
	var key: String = _owner_key(owner)
	var rs: Dictionary = _rage_state.get(key, {})
	if not bool(rs.get("active", false)):
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now >= float(rs.get("expire_at", 0.0)):
		_expire_rage_buff(owner)

## reset_state 用：若狂暴激活则先恢复
static func _expire_rage_if_active(owner: Owner) -> void:
	var key: String = _owner_key(owner)
	if bool(_rage_state.get(key, {}).get("active", false)):
		_expire_rage_buff(owner)

# ─────────────────────────────────────────────
#  辅助：信号 / 震动 / toast
# ─────────────────────────────────────────────

static func _show_toast(msg: String) -> void:
	# v9.2: SignalBus 是 autoload 全局单例，直接用全局名访问（与 quest_manager/toast_manager 范式一致）。
	# 旧写法 sb.root.get_node("/root/SignalBus") 是 API 误用——绝对路径必须从 SceneTree 调用，
	# 从 root 节点调用会报 "get_node() with absolute paths from outside the active scene tree"。
	if Engine.get_main_loop() != null:
		SignalBus.show_toast.emit(msg)

## v8.1: emit 相位仪能力触发信号（供 BattleSpectacle 编排全屏演出）
static func _emit_ability_triggered(ability_id: String, stage: String, params: Dictionary = {}) -> void:
	# v9.2: 同 _show_toast，改用 autoload 全局名 SignalBus。
	if Engine.get_main_loop() != null:
		SignalBus.phase_instrument_ability_triggered.emit(ability_id, stage, params)

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
#  正式动画函数（v6.6）—— VFX 按 owner 配色
#  PLAYER：蓝/紫/绿（玩家原配色）  ENEMY：红/暗紫/橙（自敌方版搬入）
# ─────────────────────────────────────────────

## 纳米虫群云：大范围粒子覆盖（PLAYER=紫色向上扩散；ENEMY=暗紫红向下酸雨）
static func _create_nano_swarm_cloud(center: Vector2, owner: Owner) -> void:
	if _battlefield == null or not (_battlefield is Node2D):
		return
	var cloud := Node2D.new()
	cloud.position = center
	_battlefield.add_child(cloud)

	# 主粒子层
	var p1 := CPUParticles2D.new()
	p1.emitting = true
	p1.lifetime = 3.0
	p1.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p1.emission_sphere_radius = 180.0
	if owner == Owner.PLAYER:
		# 玩家：紫色纳米虫群向上扩散
		p1.amount = 80
		p1.direction = Vector2(0, -1)
		p1.spread = 45.0
		p1.initial_velocity_min = 40.0
		p1.initial_velocity_max = 120.0
		p1.gravity = Vector2(0, 50)
		p1.scale_amount_min = 0.6
		p1.scale_amount_max = 1.8
		var gradient := Gradient.new()
		gradient.add_point(0.0, Color(0.7, 0.2, 1.0, 1.0))
		gradient.add_point(0.4, Color(0.5, 0.1, 0.8, 0.8))
		gradient.add_point(0.8, Color(0.3, 0.05, 0.6, 0.3))
		gradient.add_point(1.0, Color.TRANSPARENT)
		p1.color_ramp = gradient
	else:
		# 敌方：暗紫红酸雨下落
		p1.amount = 60
		p1.direction = Vector2(0, 1)
		p1.spread = 35.0
		p1.initial_velocity_min = 40.0
		p1.initial_velocity_max = 100.0
		p1.gravity = Vector2(0, 80)
		p1.scale_amount_min = 0.5
		p1.scale_amount_max = 1.5
		var gradient := Gradient.new()
		gradient.add_point(0.0, Color(0.6, 0.1, 0.3, 1.0))
		gradient.add_point(0.4, Color(0.4, 0.05, 0.2, 0.8))
		gradient.add_point(0.8, Color(0.2, 0.0, 0.1, 0.3))
		gradient.add_point(1.0, Color.TRANSPARENT)
		p1.color_ramp = gradient
	cloud.add_child(p1)

	# 玩家第二层：慢速漂浮纳米微粒（营造"虫群"感；敌方版无此层）
	if owner == Owner.PLAYER:
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

	# 地面环（owner 配色：玩家紫聚环 / 敌方暗红环）
	var ring := Polygon2D.new()
	var segments := 48
	var pts := PackedVector2Array()
	for i in range(segments):
		var ang := (TAU * i) / segments
		pts.append(Vector2(cos(ang), sin(ang)) * 140.0)
	ring.polygon = pts
	ring.color = Color(0.5, 0.15, 0.9, 0.5) if owner == Owner.PLAYER else Color(0.5, 0.1, 0.2, 0.4)
	ring.scale = Vector2(0.1, 0.1)
	cloud.add_child(ring)

	var tw := cloud.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(2.0, 2.0), 2.0).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "color:a", 0.0, 2.0).set_ease(Tween.EASE_IN)
	tw.tween_interval(1.5)
	tw.tween_callback(func(): cloud.queue_free())

## 纳米虫群命中：粒子爆炸（PLAYER=紫色 / ENEMY=暗红色）
static func _create_nano_swarm_hit(pos: Vector2, owner: Owner) -> void:
	if _battlefield == null or not (_battlefield is Node2D):
		return
	var hit := Node2D.new()
	hit.position = pos
	_battlefield.add_child(hit)

	var p := CPUParticles2D.new()
	p.emitting = true
	p.lifetime = 0.6
	p.amount = 12 if owner == Owner.PLAYER else 10
	p.one_shot = true
	p.explosiveness = 0.9
	p.direction = Vector2(0, 0)
	p.spread = 80.0
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 80.0 if owner == Owner.PLAYER else 70.0
	p.gravity = Vector2(0, 50)
	p.scale_amount_min = 0.5 if owner == Owner.PLAYER else 0.4
	p.scale_amount_max = 1.2 if owner == Owner.PLAYER else 1.0

	var gradient := Gradient.new()
	if owner == Owner.PLAYER:
		# 紫色纳米粒子爆炸
		gradient.add_point(0.0, Color(0.9, 0.4, 1.0, 1.0))
		gradient.add_point(0.5, Color(0.6, 0.2, 0.9, 0.7))
	else:
		# 暗红色酸液飞溅
		gradient.add_point(0.0, Color(0.8, 0.2, 0.3, 1.0))
		gradient.add_point(0.5, Color(0.5, 0.1, 0.2, 0.7))
	gradient.add_point(1.0, Color.TRANSPARENT)
	p.color_ramp = gradient
	hit.add_child(p)

	var tw := hit.create_tween()
	tw.tween_interval(0.6)
	tw.tween_callback(func(): hit.queue_free())

## 能量罩：六边形能量网格（v8.1 重设计——7 个六边形阵列波纹展开）
## PLAYER=蓝色 / ENEMY=暗红色
static func _create_shield_dome(pos: Vector2, owner: Owner) -> void:
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
	# owner 配色：玩家蓝 / 敌方暗红
	var hex_color := Color(0.3, 0.75, 1.0, 0.0) if owner == Owner.PLAYER else Color(0.8, 0.2, 0.2, 0.0)
	var glow_color := Color(0.3, 0.7, 1.0, 0.3) if owner == Owner.PLAYER else Color(0.7, 0.2, 0.2, 0.3)
	for i in range(hex_positions.size()):
		var hex := Polygon2D.new()
		hex.polygon = _make_hexagon_points(hex_size)
		hex.position = hex_positions[i]
		hex.color = hex_color
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
	glow.color = glow_color
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

## v8.1: 上升烟柱粒子（核爆蘑菇云效果）。
## v8.5+: 实现已迁移到 VfxImpactFactory.spawn_smoke_column（公共化），本方法转发调用，
##        让战术核武机制与相位仪核子轰炸共用同一蘑菇云实现（避免重复维护）。
## tint 由调用方按 owner 传入（玩家绿 / 敌方暗红橙）
static func _spawn_smoke_column(pos: Vector2, tint: Color = Color(0.5, 0.5, 0.5, 0.5)) -> void:
	if _battlefield == null or not is_instance_valid(_battlefield):
		return
	VfxImpactFactory.spawn_smoke_column(_battlefield, pos, tint)

## 狂暴光环：单位脚下脉动环（自敌方版搬入；PLAYER=金橙 / ENEMY=红色）
static func _create_rage_aura(pos: Vector2, owner: Owner) -> void:
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
	# owner 配色：玩家金橙 / 敌方红
	ring.color = Color(1.0, 0.75, 0.2, 0.6) if owner == Owner.PLAYER else Color(1.0, 0.2, 0.1, 0.6)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	ring.material = mat
	aura.add_child(ring)
	var tw := aura.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(1.5, 1.5), 0.3)
	tw.tween_property(ring, "color:a", 0.0, 0.5)
	tw.chain().tween_callback(func(): aura.queue_free())
