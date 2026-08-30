extends Node2D
## 曲射弹道批处理（玩家/敌方共用）：迫击炮/火箭/导弹使用 MultiMesh 绘制，减轻 Bullet 节点数量。
## 支持 weapon_type 3(ROCKET)/7(FLAK)/9(MISSILE) + 新枚举 INDIRECT(1)/AERIAL(2)
## Fix-1/3/5/6: 统一新枚举路由、AOE上限、禁用炮口火焰、空弹道跳过同步
## v6.2: 支持敌方曲射批处理，通过 is_player_side 区分阵营颜色
## Fix-9: 修复曲射批处理的防御计算（三攻三防系统）

const GC = preload("res://resources/game_constants.gd")
const CombatFeedback = preload("res://scripts/combat_feedback.gd")
const WeaponProjectileVfx = preload("res://scripts/weapon_projectile_vfx.gd")
const WeaponVisuals = preload("res://data/weapon_visual_profiles.gd")  # v17: 武器视觉档案（名字优先解析）
const AttackCalculator = preload("res://scripts/battle/attack_calculator.gd")
const _PairEngineRef = preload("res://scripts/battle/pair_synergy_engine.gd")  # v21 P2: 搭档协同（溅射乘数）
const CardGridUnitVisuals = preload("res://scripts/card_grid_unit_visuals.gd")  # v23.5: 空中目标瞄准点

const _HIT_R2: float = 100.0
const _MAX_PROJ: int = 180
const MAX_AOE_TARGETS_PER_HIT: int = 4  # Fix-3: AOE 溅射目标上限
const _BATCH_WEAPON_TYPES: Array[int] = [
	3,  # ROCKET (旧)
	7,  # FLAK (旧)
	9,  # MISSILE (旧)
	1,  # INDIRECT (新枚举 GC.WeaponType.INDIRECT)
	2,  # AERIAL (新枚举 GC.WeaponType.AERIAL)
]
const _PLAYER_TINT := Color(0.95, 0.92, 0.5)
# v20.25: 敌方曲射弹体粉红→亮橙红，与直射 batch（simple_*_projectile_batch 的
# _ENEMY_TINT）统一——v18-R9b 已否掉粉红（"棉花糖状失真"，阵营代码色非物理色），
# 此前曲射漏改，敌方弹体阵营色呈"直射橙红/曲射粉"两套语言。
const _ENEMY_TINT := Color(1.0, 0.55, 0.25)

## 阵营标识（由 BattleManager 在创建时设置）
var is_player_side: bool = true

## 武器配置
const _WEAPON_CONFIG: Dictionary = {
	3: {"speed": 420.0, "max_dist": 2000.0, "explosion_radius": 40.0},  # ROCKET
	7: {"speed": 520.0, "max_dist": 1500.0, "explosion_radius": 36.0},  # FLAK
	9: {"speed": 380.0, "max_dist": 2300.0, "explosion_radius": 55.0},  # MISSILE
	1: {"speed": 420.0, "max_dist": 2000.0, "explosion_radius": 40.0},  # INDIRECT (新枚举)
	2: {"speed": 520.0, "max_dist": 2000.0, "explosion_radius": 36.0},  # AERIAL (新枚举)
}

var _proj: Array = []
var _layers: Dictionary = {}  # weapon_type -> MultiMeshInstance2D
# v7.4 性能优化：buckets 提升为成员变量 + clear() 复用，消除每帧 Dictionary + Array 分配
var _buckets: Dictionary = {}  # weapon_type -> Array（成员级复用，clear 保留 buffer 容量）
# v9.2: 弹道字典池——fire 时从池取，落地/清场时归还，消除每发字典分配（同 player/enemy batch）
var _dict_pool: Array[Dictionary] = []
# v20.25: 爆炸音节流时间戳——多门火炮同帧落地时压成一声（70ms 窗口，同直射 batch 命中特效限流思路）
var _last_boom_msec: int = -10000

func _acquire_proj_dict() -> Dictionary:
	if not _dict_pool.is_empty():
		return _dict_pool.pop_back()
	return {}

func _release_proj_dict(d: Dictionary) -> void:
	d.clear()
	_dict_pool.append(d)

func _ready() -> void:
	# 初始化时不启用 physics_process，等有弹道时再启用
	set_physics_process(false)
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	z_as_relative = false
	z_index = 3
	for wt: int in _BATCH_WEAPON_TYPES:
		_layers[wt] = _make_layer(wt)
		_layers[wt].show()
		add_child(_layers[wt])
		_buckets[wt] = []

func _make_layer(wt: int) -> MultiMeshInstance2D:
	var mmi := MultiMeshInstance2D.new()
	var tex: Texture2D = WeaponProjectileVfx.proj_texture(wt)
	# 新枚举 INDIRECT(1)/AERIAL(2) 无旧贴图，回退到 ROCKET(3)
	if tex == null and wt in [1, 2]:
		tex = WeaponProjectileVfx.proj_texture(3)
	if tex == null:
		push_error("[IndirectBatch] No texture for weapon_type ", wt)
	mmi.texture = tex
	mmi.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	var q := QuadMesh.new()
	q.size = WeaponProjectileVfx.proj_quad_size(wt)
	mm.mesh = q
	mmi.multimesh = mm
	mmi.z_as_relative = false
	mmi.show()
	# v6.4: 发光叠加（导弹/火箭尾焰发光更自然）
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mmi.material = mat
	return mmi

## v6.5: 不同曲射武器的弧线高度倍率（与 bullet.gd 保持一致）
## v20.25 修复：本表此前停留在 v19 调优前的旧值（wt1=1.6/wt9=1.0），而 bullet.gd
## 已在 v19-R25/R33 按可读性下调（1.6→1.0→0.5）——曲射实战 100% 走本 batch，
## 导致弧线修复从未在主路径生效（无名炮弹弧顶 ~376px 飞出画面上缘，AI 批
## "弹道完全缺失只看到枪口火"）。现逐项对齐 bullet.gd 的 v19 验证值。
## v20.17 亚类系数（WeaponProjectileVfx.indirect_apex_mul）同步按新基准重标。
func _get_indirect_arc_multiplier(wt: int) -> float:
	match wt:
		1:   # INDIRECT 迫击炮/野战炮 — 中弧线（v19-R33: 1.6→0.5，弧顶≈画面中部）
			return 0.5
		7:   # FLAK 高射炮 — 较高弧线
			return 1.3
		9:   # MISSILE 导弹 — 低弧线（v19-R33: 1.0→0.5，同 AERIAL）
			return 0.5
		2:   # AERIAL 空射 — 低弧线（俯冲）
			return 0.5
		3:   # ROCKET 火箭筒 — 最低弧线（直瞄反坦克）
			return 0.3
		_:
			return 1.0

func fire(from: Vector2, tgt: Node2D, dmg: float, wt: int, shooter: Node2D, shooter_stats: Variant, forced_miss: bool = false, weapon_name: String = "", p_vfx_variant: String = "") -> void:
	if _proj.size() >= _MAX_PROJ or tgt == null or not is_instance_valid(tgt):
		return
	if not _layers.has(wt):
		push_error("[IndirectBatch] weapon_type %d not supported" % wt)
		return
	# 首发弹道时启用 physics_process
	if _proj.is_empty():
		set_physics_process(true)

	var start := from
	# v23.5: 弧线终点对齐空中目标悬空机身（空中爆炸/空爆观感，而非落地穿帮）
	var end := CardGridUnitVisuals.aim_pos_for(tgt)
	var dist := start.distance_to(end)
	var duration := 0.6 + dist / 2000.0 * 0.8
	# v6.5: 不同曲射武器的弧线高低不同（按 weapon_type 差异化）
	var apex := (100.0 + dist * 0.25) * _get_indirect_arc_multiplier(wt)
	# v20.17: 武器名亚类覆盖（弧线/节奏/弹体/染色，单射源 WPV）——迫击炮慢飘高弧小弹、
	# 榴弹炮族中弧重弹、火箭低平快弹橙红、导弹俯冲微加速。无名恒 1.0 零行为变化。
	var flavor: int = WeaponProjectileVfx.classify_indirect(weapon_name)
	apex *= WeaponProjectileVfx.indirect_apex_mul(flavor)
	duration *= WeaponProjectileVfx.indirect_duration_mul(flavor)
	var body_scale: float = WeaponProjectileVfx.indirect_body_scale(flavor)

	# v9.2: 从字典池取复用字典（替代每次 new 字典字面量）
	var d: Dictionary = _acquire_proj_dict()
	d["start"] = start
	d["end"] = end
	d["pos"] = from
	d["tgt"] = tgt
	d["dmg"] = dmg
	d["wt"] = wt
	d["shooter"] = shooter
	d["shooter_stats"] = shooter_stats
	d["forced_miss"] = forced_miss
	d["weapon_name"] = weapon_name
	d["vfx_variant"] = p_vfx_variant  # v8.4: 武器类改造专属视觉标识
	d["progress"] = 0.0
	d["duration"] = duration
	d["apex"] = apex
	d["flavor_scale"] = body_scale  # v20.17: per-instance 弹体尺寸（亚类）
	d["flavor"] = flavor            # v20.17: 亚类染色键（sync 时查表）
	d["dir"] = Vector2.RIGHT
	d["prev_pos"] = from
	d["muzzle_spawned"] = true  # Fix-5: 禁用炮口火焰，标记为已生成
	d["impact_spawned"] = false
	d["is_player"] = is_player_side
	_proj.append(d)
	_play_fire_sfx(wt)

## v20.25: 曲射开火音——此前武器开火音效全链路只挂在 bullet.gd 兜底路径（_play_attack_sfx），
## 曲射实战 100% 走本 batch → 火炮/火箭/导弹开火全程无声（sound_generator 生成的
## rocket_launch/flak_fire/missile_hum 主路径零消费）。音量/降调规则与 bullet 同源。
func _play_fire_sfx(wt: int) -> void:
	if not (AudioManager and AudioManager.has_method("play_sfx")):
		return
	var pitch := randf_range(0.9, 1.1)
	var vol: float = 1.0
	if not is_player_side:
		pitch *= 0.92  # 敌方轻微降调（与 bullet.gd 同规则）
		vol = 0.8
	match wt:
		7:
			AudioManager.play_sfx("flak_fire", vol * 0.9, pitch * 0.9)
		9, 2:
			AudioManager.play_sfx("missile_hum", vol * 0.8, pitch)
		_:
			# 1(INDIRECT)/3(ROCKET) 火炮/火箭发射——重发射低鸣
			AudioManager.play_sfx("rocket_launch", vol * 1.0, pitch * 0.8)

## v20.25: 落地爆炸音——take_damage→unit_damaged 只驱动通用 "hit" 短音（AudioManager
## 节流层），曲射爆炸缺低频轰鸣层。70ms 窗口节流防多炮同帧齐轰爆音。
func _play_explosion_sfx() -> void:
	if not (AudioManager and AudioManager.has_method("play_sfx")):
		return
	var now := Time.get_ticks_msec()
	if now - _last_boom_msec < 70:
		return
	_last_boom_msec = now
	AudioManager.play_sfx("explosion", 1.0, randf_range(0.9, 1.1))

func clear_all() -> void:
	# v9.2: 归还所有活跃弹道字典到池
	for d: Dictionary in _proj:
		_release_proj_dict(d)
	_proj.clear()
	for wt: int in _BATCH_WEAPON_TYPES:
		var mmi: MultiMeshInstance2D = _layers.get(wt)
		if mmi and mmi.multimesh:
			mmi.multimesh.instance_count = 0

func _physics_process(delta: float) -> void:
	var tree := get_tree()
	if tree == null or tree.paused:
		return
	if _proj.is_empty():
		# Fix-6: 空弹道时清除 MultiMesh 实例并跳过同步，禁用 physics_process
		for wt_key: int in _BATCH_WEAPON_TYPES:
			var mmi: MultiMeshInstance2D = _layers.get(wt_key)
			if mmi and mmi.multimesh and mmi.multimesh.instance_count > 0:
				mmi.multimesh.instance_count = 0
		set_physics_process(false)
		return

	var write: int = 0
	var n: int = _proj.size()
	for read_idx in range(n):
		if read_idx >= _proj.size():
			break
		var r: Dictionary = _proj[read_idx]

		r["prev_pos"] = r["pos"]
		r["progress"] = float(r["progress"]) + delta / float(r["duration"])
		if r["progress"] >= 1.0:
			_apply_hit(r)
			_release_proj_dict(r)  # v9.2: 归还池（曲射落地爆炸结算完）
			continue

		var t := float(r["progress"])
		var start := r["start"] as Vector2
		var end := r["end"] as Vector2
		var mid := (start + end) * 0.5
		var apex_point := mid + Vector2.UP * float(r["apex"])
		var new_pos := (1.0 - t) * (1.0 - t) * start + 2.0 * (1.0 - t) * t * apex_point + t * t * end
		r["pos"] = new_pos

		var prev := r["prev_pos"] as Vector2
		if new_pos != prev:
			r["dir"] = (new_pos - prev).normalized()

		# v8.1: 落点预警圈——progress > 0.55 时在落点 spawn 红色扩散圈（v8.1a：提前到0.55给玩家充分反应）
		if t > 0.55 and not bool(r.get("warned", false)):
			r["warned"] = true
			var wt_warn: int = int(r["wt"])
			var warn_radius: float = float(_WEAPON_CONFIG.get(wt_warn, {}).get("explosion_radius", 40.0))
			VfxImpactFactory.spawn_shockwave(self, end, warn_radius, Color(1.0, 0.3, 0.2, 0.55))

		# Fix-5: 炮口火焰已禁用（muzzle_spawned 初始化为 true）

		var raw_tgt: Variant = r["tgt"]
		if raw_tgt == null or not is_instance_valid(raw_tgt):
			pass

		if write != read_idx:
			_proj[write] = r
		write += 1

	if _proj.is_empty():
		write = 0
	else:
		_proj.resize(write)
	_sync_multimesh_layers()

func _sync_multimesh_layers() -> void:
	# v7.3 性能优化：单遍分桶（原两遍遍历 _proj：count + write）
	# v7.4 性能优化：buckets 改为成员变量 + clear() 复用，消除每帧 Dictionary + Array 分配。
	for wt: int in _BATCH_WEAPON_TYPES:
		(_buckets[wt] as Array).clear()
	for r: Dictionary in _proj:
		var wt_r: int = int(r["wt"])
		if _buckets.has(wt_r):
			(_buckets[wt_r] as Array).append(r)
	var tint := _PLAYER_TINT if is_player_side else _ENEMY_TINT
	for wt: int in _BATCH_WEAPON_TYPES:
		var mmi: MultiMeshInstance2D = _layers[wt]
		var mm: MultiMesh = mmi.multimesh
		var arr: Array = _buckets[wt]
		# 优化：跳过空层
		if arr.is_empty():
			if mm.instance_count > 0:
				mm.instance_count = 0
			continue
		mm.instance_count = arr.size()
		var idx: int = 0
		for r: Dictionary in arr:
			var dir: Vector2 = r.get("dir", Vector2.RIGHT) as Vector2
			var local_pos: Vector2 = to_local(r["pos"])
			# v20.17: per-instance 弹体尺寸（亚类 scale 乘进 Transform2D）
			var sc: float = float(r.get("flavor_scale", 1.0))
			var xf: Transform2D = Transform2D(dir.angle(), Vector2(sc, sc), 0.0, local_pos) if sc != 1.0 \
				else Transform2D(dir.angle(), local_pos)
			mm.set_instance_transform_2d(idx, xf)
			# v20.17: 亚类染色覆盖（火箭橙红/导弹微橙白；NONE 保持阵营 tint）
			var tint_r: Color = WeaponProjectileVfx.indirect_tint(int(r.get("flavor", -1)), tint)
			mm.set_instance_color(idx, tint_r)
			idx += 1

func _apply_hit(r: Dictionary) -> void:
	var raw_tgt: Variant = r.get("tgt")
	if raw_tgt == null or not is_instance_valid(raw_tgt):
		return
	var tgt: Node2D = raw_tgt

	var wt: int = int(r["wt"])
	var hit_pos: Vector2 = r["pos"]

	# 生成命中特效
	var proj_is_player: bool = bool(r.get("is_player", true))
	# v7.x: 从目标提取 combat_kind 实现按目标类型差异化命中色调/缩放
	var _tgt_kind: int = -1
	if tgt != null and "stats" in tgt:
		var _ts: UnitStats = tgt.get("stats") as UnitStats
		if _ts != null:
			_tgt_kind = int(_ts.combat_kind)
	if not bool(r.get("forced_miss", false)):
		# v8.4: 透传 weapon_name（命中贴图层）+ vfx_variant opts（改造专属视觉）
		var _wname: String = String(r.get("weapon_name", ""))
		var _variant: String = String(r.get("vfx_variant", ""))
		var _opts: Dictionary = {} if _variant.is_empty() else {"vfx_variant": _variant}
		# v9.4: power_tier 威力分级——曲射武器有 explosion_radius（_WEAPON_CONFIG），
		# 叠加 damage 判定：普通火箭(radius40/MEDIUM) vs 导弹(radius55/HEAVY) vs 终极粒子炮(高伤/可能NUCLEAR)。
		var _ind_radius: float = float(_WEAPON_CONFIG.get(wt, {}).get("explosion_radius", 0.0))
		_opts["power_tier"] = WeaponProjectileVfx.compute_power_tier(wt, _ind_radius, float(r.get("dmg", 0.0)))
		_spawn_impact_explosion(hit_pos, proj_is_player, wt, _tgt_kind, _wname, _opts)
		_play_explosion_sfx()
		# v6.4: 曲射爆炸触发中等屏幕震动
		# v7.x: 优先用 combat_kind 的震动参数（对空重震/对装甲中震/对轻装轻震）
		var tree := get_tree()
		var bm: Node = tree.root.get_node_or_null("BattleManager") if tree else null
		if bm != null and is_instance_valid(bm) and bm.has_method("request_screen_shake"):
			# v9.4: 按 power_tier 分级震屏（HEAVY/NUCLEAR 显著强于 MEDIUM）
			var _tier: int = int(_opts.get("power_tier", 1))
			var _base_shake: Vector2 = WeaponProjectileVfx.impact_shake_for_kind(_tgt_kind) if _tgt_kind >= 0 else Vector2(5.0, 0.25)
			var _shake_mag: float = _base_shake.x
			var _shake_dur: float = _base_shake.y
			if _tier == 3:  # NUCLEAR
				_shake_mag = 20.0; _shake_dur = 0.8
			elif _tier == 2:  # HEAVY
				_shake_mag = maxf(_shake_mag, 10.0); _shake_dur = maxf(_shake_dur, 0.45)
			if _shake_mag > 0.0:
				bm.request_screen_shake(_shake_mag, _shake_dur)
			else:
				bm.request_screen_shake(5.0, 0.25)

	# 造成伤害
	if bool(r.get("forced_miss", false)):
		CombatFeedback.show_miss(tgt.global_position, tgt)
	else:
		var raw_dmg: float = float(r["dmg"])
		var shooter_raw: Variant = r["shooter"]
		var shooter: Node2D = shooter_raw if shooter_raw != null and is_instance_valid(shooter_raw) and shooter_raw is Node2D else null
		var shooter_stats: Variant = r["shooter_stats"]
		var explosion_r: float = _WEAPON_CONFIG.get(wt, {}).get("explosion_radius", 40.0)

		# Fix-9: 修复曲射批处理的防御计算（v6.2 核心修复）
		# 应用防御减免、改造加成、强化加成
		var final_primary_dmg: float = raw_dmg

		if tgt.has_method("take_damage"):
			var target_stats: UnitStats = tgt.get("stats") as UnitStats if tgt != null and "stats" in tgt else null
			if target_stats != null and shooter_stats != null and shooter_stats is UnitStats:
				# 检测格子战模式：防御由 CardGridDamage 处理，跳过防御减免避免双重计算
				var is_card_grid := false
				var tree := get_tree()
				if tree != null:
					var gm: Node = tree.root.get_node_or_null("GameManager")
					if gm != null and gm.has_method("is_card_grid_battle"):
						is_card_grid = gm.is_card_grid_battle()

				# 1. 根据攻击者单位类型获取对应的防御值（v6.2: 攻防维度对齐）
				# 2. 应用防御减免（仅在非格子战模式）
				if not is_card_grid:
					var def_val: float = AttackCalculator.get_defense_vs(target_stats, shooter_stats.combat_kind)
					final_primary_dmg = raw_dmg * (100.0 / (100.0 + def_val))

				# v10(C6) 修复：删除强化加成块——调用方（construct_unit_ai / enemy_unit）传入的 dmg
				# 已含 AttackCalculator.calculate_damage_with_weapon 的强化曲线（v7.x 0.08/级），
				# 此处再乘 0.05/级旧曲线构成双乘。强化现全链路仅应用一次。
				# （v6.4 注：改造伤害加成由 ModificationRegistry 在 UnitStats 构建阶段直叠 attack_*。）

				# 5. 词缀战斗效果（如果shooter节点有效）
				if shooter and is_instance_valid(shooter):
					# 5.1 武器伤害变异（15%概率双倍伤害）
					if shooter_stats.has_weapon_dmg_mutation and randf() < 0.15:
						final_primary_dmg *= 2.0

				# 6. 卡牌特殊能力：命中前修改伤害
				if shooter and is_instance_valid(shooter):
					var ability_result: Dictionary = {"damage_bonus": 0.0, "damage_mult_bonus": 0.0}
					if shooter.has_method("get_script"):
						var script = shooter.get_script()
						if script and script.has_method("on_bullet_hit_post"):
							ability_result = shooter.get_script().on_bullet_hit_post(
								shooter, tgt, shooter_stats, hit_pos,
								final_primary_dmg, r.get("is_player", true)
							)
							final_primary_dmg += ability_result["damage_bonus"]
							final_primary_dmg *= (1.0 + ability_result["damage_mult_bonus"])

		# Fix-3: AOE 伤害，限制溅射目标数量
		var targets: Array = _get_aoe_targets(hit_pos, explosion_r, tgt)
		var splash_count := 0
		for target in targets:
			if target == tgt:
				continue
			if splash_count >= MAX_AOE_TARGETS_PER_HIT:
				break
			if target.has_method("take_damage"):
				# 溅射目标也需要防御计算（格子战模式下跳过，由CardGridDamage处理）
				# v21 P1: 统一装药（gen_unified_splash）B4 最小对齐——溅射比例改读
				# shooter stats.splash_damage（>0 时），无则回退 0.5（原行为不变）。
				# MAX_AOE_TARGETS_PER_HIT 与 bullet 兜底路径均不动（计划 §7 风险 5 允许）。
				var splash_ratio: float = 0.5
				if shooter_stats != null and shooter_stats is UnitStats and float(shooter_stats.splash_damage) > 0.0:
					splash_ratio = clampf(float(shooter_stats.splash_damage), 0.0, 0.80)
				# v21 P2: 侦察×火炮搭档——主目标带侦察标记且射手是火炮角色时溅射 ×1.5
				splash_ratio *= _PairEngineRef.get_artillery_mark_splash_mult(shooter, tgt)
				var splash_raw: float = raw_dmg * splash_ratio
				var splash_final: float = splash_raw

				var target_stats_splash: UnitStats = target.get("stats") as UnitStats if target != null and "stats" in target else null
				if target_stats_splash != null and shooter_stats != null and shooter_stats is UnitStats:
					# 检测格子战模式
					var is_card_grid := false
					var tree := get_tree()
					if tree != null:
						var gm: Node = tree.root.get_node_or_null("GameManager")
						if gm != null and gm.has_method("is_card_grid_battle"):
							is_card_grid = gm.is_card_grid_battle()

					# 仅在非格子战模式下应用防御减免
					if not is_card_grid:
						# v21 P1: 传 shooter_stats——弹道重赋（gen_converted_munitions）对轻轴转对甲轴
						var def_val_splash: float = AttackCalculator.get_defense_vs(target_stats_splash, shooter_stats.combat_kind, shooter_stats)
						if splash_raw > def_val_splash:
							splash_final = splash_raw * (100.0 / (100.0 + def_val_splash))
						else:
							splash_final = 0.0

				if splash_final <= 0.0:
					continue

				target.take_damage(splash_final, shooter)
				splash_count += 1

		# 主目标伤害（应用完整计算）
		if tgt.has_method("take_damage") and final_primary_dmg > 0.0:
			tgt.take_damage(final_primary_dmg, shooter)
			# v6.6: 应用改造/符文命中副作用（溅射/连锁；击杀修复走 unit_killed）
			ModuleEffectHandler.apply_on_hit_side_effects(shooter, tgt, final_primary_dmg)

## 爆炸候选：优先空间网格
func _get_aoe_targets(center: Vector2, radius: float, primary: Node2D) -> Array:
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
	# 回退到遍历
	if primary.get_parent():
		var parent := primary.get_parent()
		for child in parent.get_children():
			if child == primary:
				continue
			if child is Node2D and child.has_method("take_damage"):
				if child.global_position.distance_squared_to(center) <= r2:
					targets.append(child)
	return targets

## 爆炸特效（v8.0：粒子化；v8.4：贴图层 + 改造变体）
## 曲射/空射爆炸 = 重型命中特效（更多粒子量 + 命中贴图）
func _spawn_impact_explosion(pos: Vector2, is_player_proj: bool = true, weapon_type: int = 1, target_combat_kind: int = -1, weapon_name: String = "", opts: Dictionary = {}) -> void:
	# v20.26: 删除 _active_impacts 死守卫——WPV 计数器 v8.1 迁厂后只减不增，守卫恒不触发；
	# 特效上限由 VfxImpactFactory 活跃封顶（sprite 160/spark 320/debris 140/ring 80）承担。
	# 复用 spawn_impact_with_kind 的粒子系统 + 贴图层（v8.4 透传 weapon_name）
	# v17: wt 经 WeaponVisualProfiles 统一解析（武器名优先——"227mm火箭炮"按名取火箭
	# 弹视觉而非槽位默认炮弹；域兜底保持原值）。
	var _vwt: int = WeaponVisuals.resolve_visual_wt(weapon_name, weapon_type, is_player_proj)
	WeaponProjectileVfx.spawn_impact_with_kind(self, pos, _vwt, is_player_proj, target_combat_kind, opts, weapon_name)
