extends Node2D
## 玩家轻武器弹道批处理：直线导引、无穿透/爆炸时用 MultiMesh 绘制，减轻 Bullet 节点数量。
## 仿照 simple_enemy_projectile_batch.gd，玩家版无护盾墙减伤。

const CombatFeedback = preload("res://scripts/combat_feedback.gd")
const WeaponProjectileVfx = preload("res://scripts/weapon_projectile_vfx.gd")
const VfxImpactFactory = preload("res://scripts/battle/vfx_impact_factory.gd")  # v9.2: 枪口火
const WeaponVisuals = preload("res://data/weapon_visual_profiles.gd")  # v17: 武器视觉档案（名字优先解析）
const DirectWeaponFlavor = preload("res://data/direct_weapon_flavor.gd")  # v20.16: 直射亚类（弹头形状分流）

const _HIT_R2: float = 100.0
const _MAX_PROJ: int = 720
const _BATCH_WEAPON_TYPES: Array[int] = [
	0,  # SMG
	4,  # PISTOL
	1,  # RIFLE
	2,  # MG
]
# v20.16: 直射亚类形状层（WeaponProjectileVfx.FLAVOR_LAYER_*）——步枪细长/机枪短钝/坦克炮大号，
# 各自独立 MultiMesh 网格。玩家侧直射 wt 恒为 0（新枚举 DIRECT），wt 分层对玩家全部失效，
# 亚类（武器名解析）是直射弹头形状分化的唯一有效轴。
const _FLAVOR_LAYER_KEYS: Array[int] = [
	WeaponProjectileVfx.FLAVOR_LAYER_RIFLE,
	WeaponProjectileVfx.FLAVOR_LAYER_MG,
	WeaponProjectileVfx.FLAVOR_LAYER_TANK_GUN,
	WeaponProjectileVfx.FLAVOR_LAYER_SMALL_ARMS,  # v20.16d: 手枪/卡宾微型光点层
]
const _PLAYER_TINT := Color(1.0, 0.95, 0.4)  # v9.2: 亮金黄（原淡黄，提亮让弹道更醒目）

var _proj: Array = []
var _layers: Dictionary = {}  # layer_key（wt 或亚类形状键 100+）-> MultiMeshInstance2D
# v20.16: 渲染层键全集（基础 wt + 亚类层）——_ready 填充；sync/clear 遍历用（保持零分配）
var _layer_keys: Array[int] = []
# T1 性能优化：轻武器命中特效限流时间戳（见 _apply_hit）
var _last_impact_msec: int = -10000
# v7.4 性能优化：buckets 提升为成员变量 + clear() 复用，消除每帧 Dictionary + Array 分配
var _buckets: Dictionary = {}  # weapon_type -> Array（成员级复用，clear 保留 buffer 容量）
# v9.2: 弹道字典池——fire 时从池取，命中/出界/清场时归还，消除每发字典分配。
# Dictionary 是引用类型，取出后原地修改（r["pos"]=...）仍反映到 _proj 数组里的同一对象，语义不变。
var _dict_pool: Array[Dictionary] = []
# ── v17k: 曳光线——实战 90%+ 轻武器走本路径（MultiMesh 弹头 12×7px 混战不可追踪），
# v17d 的 TracerLine/拖尾只在 bullet.gd 低速路径，主力路径零弹道视觉（"弹道差"最大缺口）。
# 每条活跃弹道后方一条细 ADD 曳光线（机枪连发=弹幕感，曳光弹视觉）。
var _tracer_lines: Array = []   # 固定 Line2D 集合（懒建，上限 MAX_TRACERS，永不 free）
const MAX_TRACERS: int = 48
const TRACER_COLOR := Color(1.0, 0.95, 0.55, 0.78)  # 我方黄白曳光
static var _tracer_mat: CanvasItemMaterial = null

func _update_tracers() -> void:
	var need: int = mini(_proj.size(), MAX_TRACERS)
	# 懒建到 need 数
	if _tracer_mat == null:
		_tracer_mat = CanvasItemMaterial.new()
		_tracer_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	while _tracer_lines.size() < need:
		var t := Line2D.new()
		t.width = 2.5  # v17k-R2: 1.5→2.5（AI 批"弹道不可读"，缩图后 1.5px 线消失）
		t.default_color = TRACER_COLOR
		t.material = _tracer_mat
		t.joint_mode = Line2D.LINE_JOINT_ROUND
		t.end_cap_mode = Line2D.LINE_CAP_ROUND
		add_child(t)
		_tracer_lines.append(t)
	# 更新前 need 条坐标；多余的隐藏
	for i in range(_tracer_lines.size()):
		var t2: Line2D = _tracer_lines[i]
		if i >= need:
			t2.visible = false
			continue
		t2.visible = true
		var r: Dictionary = _proj[i]
		var dir: Vector2 = r.get("dir", Vector2.RIGHT) as Vector2
		var sk_r: int = int(r.get("sk", r["wt"]))  # v20.16b: 亚类曳光参数（宽/长/色）
		t2.position = to_local(r["pos"])
		t2.width = WeaponProjectileVfx.tracer_width_for(sk_r)
		t2.default_color = WeaponProjectileVfx.tracer_color_for(sk_r, TRACER_COLOR)
		# 两点：弹头（0,0）→ 后方曳光尾（按亚类分长：机枪加长/坦克炮短粗）
		t2.clear_points()
		t2.add_point(Vector2.ZERO)
		t2.add_point(-dir * WeaponProjectileVfx.tracer_len_for(sk_r))

## v9.2: 从池获取弹道字典（池空则新建）。fire 调用。
func _acquire_proj_dict() -> Dictionary:
	if not _dict_pool.is_empty():
		return _dict_pool.pop_back()
	return {}

## v9.2: 归还弹道字典到池（命中/出界/清场调用）。clear 字段防复用残留。
func _release_proj_dict(d: Dictionary) -> void:
	d.clear()
	_dict_pool.append(d)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 3
	for wt: int in _BATCH_WEAPON_TYPES:
		_layers[wt] = _make_layer(wt)
		add_child(_layers[wt])
		_buckets[wt] = []
		_layer_keys.append(wt)
	# v20.16: 直射亚类形状层——武器名分流后各用独立网格（步枪细长/机枪短钝/坦克炮大号）
	for fk: int in _FLAVOR_LAYER_KEYS:
		_layers[fk] = _make_layer(fk)
		add_child(_layers[fk])
		_buckets[fk] = []
		_layer_keys.append(fk)

func _make_layer(wt: int) -> MultiMeshInstance2D:
	var mmi := MultiMeshInstance2D.new()
	# v9.4: 程序化弹头多边形替代长条横向贴图（与 simple_enemy_projectile_batch 同步改造）。
	# 原用 QuadMesh + weapon_*_projectile.png（横向长条），弹道斜向时视觉违和。
	# 改用 7 点弹头 ArrayMesh（弹体矩形+弹头锥形，指向 +X，原点居中），
	# Transform2D(dir.angle()) 旋转后任意角度自然对齐。纯色 + ADD 发光，无需贴图。
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.mesh = WeaponProjectileVfx.build_bullet_arraymesh(wt)
	mmi.multimesh = mm
	# v6.4: 发光叠加，让弹头产生霓虹发光
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mmi.material = mat
	return mmi

func fire(from: Vector2, tgt: Node2D, dmg: float, wt: int, shooter: Node2D, shooter_stats: Variant, forced_miss: bool = false, weapon_name: String = "", p_vfx_variant: String = "") -> void:
	if _proj.size() >= _MAX_PROJ or tgt == null or not is_instance_valid(tgt):
		return
	if not _layers.has(wt):
		return
	# v9.2: 从字典池取复用字典（替代每次 new 字典字面量），fire 高频路径消除分配
	var d: Dictionary = _acquire_proj_dict()
	d["pos"] = from
	d["tgt"] = tgt
	d["dmg"] = dmg
	d["wt"] = wt
	d["shooter"] = shooter
	d["shooter_stats"] = shooter_stats
	d["forced_miss"] = forced_miss
	d["traveled"] = 0.0
	# v20.16: 直射亚类（武器名优先）——渲染层键分流形状；v20.16b: 弹速同步分化
	# （步枪 1.3× 干脆 / 机枪 0.95× 弹幕 / 坦克炮 0.75× 重弹，系数单射源在 WPV）。
	var flavor: int = DirectWeaponFlavor.classify(weapon_name, wt)
	d["speed"] = WeaponProjectileVfx.flavor_speed(flavor, _speed_for(wt))
	d["max_dist"] = _max_dist_for(wt)
	d["dir"] = Vector2.RIGHT
	# 命中/出界结算仍按原 wt；渲染层键（sk）分流形状/染色/曳光。
	var sk: int = WeaponProjectileVfx.flavor_layer_key(flavor)
	d["sk"] = sk if sk >= 0 else wt
	# v16: 透传武器名（命中配方亚类：机枪/坦克炮/步枪）与改造专属视觉标识
	d["weapon_name"] = weapon_name
	d["vfx_variant"] = p_vfx_variant
	_proj.append(d)
	# v16: 删除原 25% 抽样枪口火——唯一调用方 construct_unit_ai 在 do_attack_with_damage
	# 顶部已播单位级炮口火（_play_muzzle_feedback，锚点对齐+类别键正确），batch 再播会双重叠加。

func clear_all() -> void:
	# v9.2: 归还所有活跃弹道字典到池（战斗结束/拆卸时批量回收，下场战斗复用）
	for d: Dictionary in _proj:
		_release_proj_dict(d)
	_proj.clear()
	for k: int in _layer_keys:
		var mmi: MultiMeshInstance2D = _layers.get(k)
		if mmi and mmi.multimesh:
			mmi.multimesh.instance_count = 0

func _physics_process(delta: float) -> void:
	var tree := get_tree()
	if tree == null or tree.paused:
		return
	# v6.6: 移除开头冗余的 _sync_multimesh_layers() ——
	# 上帧末尾已同步过，且本帧 fire() 之前 _proj 不会增长，
	# 删除此处可每帧每批省 2 遍 720 发遍历
	if _proj.is_empty():
		_sync_multimesh_layers()
		return

	var write: int = 0
	var n: int = _proj.size()
	for read_idx in range(n):
		if read_idx >= _proj.size():
			break
		var r: Dictionary = _proj[read_idx]
		var raw_tgt: Variant = r["tgt"]
		var tgt: Node2D = raw_tgt if raw_tgt != null and is_instance_valid(raw_tgt) else null
		if tgt == null:
			_release_proj_dict(r)  # v9.2: 归还池（目标失效，弹道废弃）
			continue
		var pos: Vector2 = r["pos"]
		var spd: float = r["speed"]
		var dir: Vector2 = (tgt.global_position - pos).normalized()
		pos += dir * spd * delta
		r["pos"] = pos
		r["dir"] = dir
		r["traveled"] = float(r["traveled"]) + spd * delta
		if pos.distance_squared_to(tgt.global_position) <= _HIT_R2:
			_apply_hit(r)
			_release_proj_dict(r)  # v9.2: 归还池（命中结算完）
			continue
		if float(r["traveled"]) > float(r["max_dist"]):
			_release_proj_dict(r)  # v9.2: 归还池（超射程丢失）
			continue
		if write != read_idx:
			_proj[write] = r
		write += 1
	# Fix: _apply_hit 回调链可能帧中途清空 _proj（同 simple_enemy_projectile_batch.gd），
	# 此时 resize(write) 会以 null 填充数组导致下一帧 for r: Dictionary 崩溃。
	if _proj.is_empty():
		write = 0
	_proj.resize(write)
	_sync_multimesh_layers()
	_update_tracers()  # v17k: 曳光随弹道每帧更新

func _sync_multimesh_layers() -> void:
	if _proj.is_empty():
		for k: int in _layer_keys:
			_layers[k].multimesh.instance_count = 0
		return
	# v7.3 性能优化：单遍遍历 _proj 同时完成分桶（收集到每层临时数组）。
	# v7.4 性能优化：buckets 改为成员变量 + clear() 复用，消除每帧 Dictionary + Array 分配。
	# v20.16: 分桶键 wt→sk（渲染层键）——直射亚类各入各形状层。
	for k: int in _layer_keys:
		(_buckets[k] as Array).clear()
	for r: Dictionary in _proj:
		var sk_r: int = int(r.get("sk", r["wt"]))
		if _buckets.has(sk_r):
			(_buckets[sk_r] as Array).append(r)
	# 设每层 instance_count
	for k: int in _layer_keys:
		var mmi: MultiMeshInstance2D = _layers[k]
		var mm: MultiMesh = mmi.multimesh
		mm.instance_count = (_buckets[k] as Array).size()
	# 遍历分桶数组写 transform（只遍历实际弹道）
	for k: int in _layer_keys:
		var arr: Array = _buckets[k]
		if arr.is_empty():
			continue
		var mm2: MultiMesh = (_layers[k] as MultiMeshInstance2D).multimesh
		var tint: Color = WeaponProjectileVfx.layer_tint(k, _PLAYER_TINT)  # v20.16b: 亚类层按武器配色
		var idx: int = 0
		for r: Dictionary in arr:
			var dir: Vector2 = r.get("dir", Vector2.RIGHT) as Vector2
			var local_pos: Vector2 = to_local(r["pos"])
			mm2.set_instance_transform_2d(idx, Transform2D(dir.angle(), local_pos))
			mm2.set_instance_color(idx, tint)
			idx += 1

func _apply_hit(r: Dictionary) -> void:
	var tgt: Node2D = r["tgt"]
	if tgt == null or not is_instance_valid(tgt):
		return
	var hit_pos: Vector2 = Vector2(r["pos"])
	var wt: int = int(r["wt"])
	# v17: 命中特效 wt 经 WeaponVisualProfiles 统一解析（武器名优先+我方域兜底）。
	# batch 只收轻动能武器（BATCH_FIRE_WEAPON_TYPES=[0,4,1,2]），名字有信号时按
	# 信号走（如坦克炮重环），无信号保持轻动能档——替代 v16 的裸 normalize。
	var _wname: String = String(r.get("weapon_name", ""))
	var impact_wt: int = WeaponVisuals.resolve_visual_wt(_wname, wt, true)
	# v7.x: 从目标提取 combat_kind 实现按目标类型差异化命中色调/缩放
	var _tgt_kind: int = -1
	if tgt != null and "stats" in tgt:
		var _ts: UnitStats = tgt.get("stats") as UnitStats
		if _ts != null:
			_tgt_kind = int(_ts.combat_kind)
	if bool(r.get("forced_miss", false)):
		CombatFeedback.show_miss(tgt.global_position, tgt)
	else:
		# v9.4: power_tier 威力分级（直射轻武器 radius=0，tier 由 damage 决定）。
		var _tier: int = WeaponProjectileVfx.compute_power_tier(impact_wt, 0.0, float(r.get("dmg", 0.0)))
		var _opts: Dictionary = {"power_tier": _tier}
		# v16: 改造专属视觉（集束/温压/近炸等 vfx_variant）
		var _variant: String = String(r.get("vfx_variant", ""))
		if not _variant.is_empty():
			_opts["vfx_variant"] = _variant
		# T1 性能优化：轻武器命中特效时间窗限流——每次命中无条件生成 7-10 个特效节点
		# （2 Sprite + ring + decal + 3-4 CPUParticles2D，30-90 粒），密集齐射时按命中频率爆炸。
		# HEAVY+ 档不限流（低频且视觉重要）；轻武器 40ms 窗口内只出一次（≤25 次/秒）。
		# 交火稀疏时（<25 命中/秒）每次命中仍有特效，视觉零损失。
		var _spawn_fx: bool = true
		if _tier < 2:
			var _now: int = Time.get_ticks_msec()
			if _now - _last_impact_msec < 40:
				_spawn_fx = false
			else:
				_last_impact_msec = _now
		if _spawn_fx:
			WeaponProjectileVfx.spawn_impact_with_kind(self, hit_pos, impact_wt, true, _tgt_kind, _opts, _wname)
		# v9.4: 仅 HEAVY+ 档震屏（轻武器密集命中不震屏避免干扰；重型直射/核武才震）
		if _tier >= 2:
			var tree := get_tree()
			var bm: Node = tree.root.get_node_or_null("BattleManager") if tree else null
			if bm != null and is_instance_valid(bm) and bm.has_method("request_screen_shake"):
				if _tier == 3:
					bm.request_screen_shake(20.0, 0.8)
				else:
					bm.request_screen_shake(10.0, 0.45)
	var raw: float = float(r["dmg"])
	var shooter_raw: Variant = r["shooter"]
	var shooter: Node2D = shooter_raw if shooter_raw != null and is_instance_valid(shooter_raw) and shooter_raw is Node2D else null
	# v6.6: 应用改造/符文命中副作用（吸血/溅射/连锁）。
	# 之前这些效果在批处理路径完全缺失（module_effect_handler.on_bullet_hit 零调用），
	# 导致射速>2.0 的直射武器（绝大多数轻武器）的吸血/连锁/溅射全部失效。
	# 用 apply_on_hit_side_effects（仅副作用，不含暴击/穿甲，避免与已有伤害计算冲突）。
	if tgt.has_method("take_damage"):
		tgt.take_damage(raw, shooter)
		ModuleEffectHandler.apply_on_hit_side_effects(shooter, tgt, raw)

func _speed_for(wt: int) -> float:
	match wt:
		0, 4:
			return 720.0
		1:
			return 800.0
		2:
			return 680.0
		_:
			return 650.0

func _max_dist_for(wt: int) -> float:
	match wt:
		0, 4:
			return 1200.0
		1:
			return 1600.0
		2:
			return 1400.0
		_:
			return 1300.0
