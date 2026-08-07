extends Node2D
## 敌方轻武器弹道批处理：直线导引、无穿透/爆炸时用 MultiMesh 绘制，减轻 Bullet 节点数量。
const GC = preload("res://resources/game_constants.gd")
const ActiveLawEffects = preload("res://managers/active_law_effects.gd")
const CombatFeedback = preload("res://scripts/combat_feedback.gd")
const WeaponProjectileVfx = preload("res://scripts/weapon_projectile_vfx.gd")
const VfxImpactFactory = preload("res://scripts/battle/vfx_impact_factory.gd")  # v9.2: 枪口火

const _HIT_R2: float = 100.0
const _MAX_PROJ: int = 720
const _BATCH_WEAPON_TYPES: Array[int] = [
	0,
	4,
	1,
	2,
]
const _ENEMY_TINT := Color(1.0, 0.55, 0.25)  # v9.2: 亮橙红（原暗粉 1.0/0.38/0.52），在战场上更醒目

var _proj: Array = []
var _layers: Dictionary = {}  # weapon_type -> MultiMeshInstance2D
# v7.4 性能优化：buckets 提升为成员变量 + clear() 复用，消除每帧 Dictionary + Array 分配
var _buckets: Dictionary = {}  # weapon_type -> Array（成员级复用，clear 保留 buffer 容量）
# v9.2: 弹道字典池——fire 时从池取，命中/出界/清场时归还，消除每发字典分配（同 player batch）
var _dict_pool: Array[Dictionary] = []

func _acquire_proj_dict() -> Dictionary:
	if not _dict_pool.is_empty():
		return _dict_pool.pop_back()
	return {}

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

func _make_layer(wt: int) -> MultiMeshInstance2D:
	var mmi := MultiMeshInstance2D.new()
	mmi.texture = WeaponProjectileVfx.proj_texture(wt)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	var q := QuadMesh.new()
	q.size = WeaponProjectileVfx.proj_quad_size(wt)
	mm.mesh = q
	mmi.multimesh = mm
	# v6.4: 发光叠加
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mmi.material = mat
	return mmi

func fire(from: Vector2, tgt: Node2D, dmg: float, wt: int, shooter: Node2D, _shooter_stats: Variant, forced_miss: bool = false) -> void:
	if _proj.size() >= _MAX_PROJ or tgt == null or not is_instance_valid(tgt):
		return
	if not _layers.has(wt):
		return
	# v9.2: 从字典池取复用字典（替代每次 new 字典字面量）
	var d: Dictionary = _acquire_proj_dict()
	d["pos"] = from
	d["tgt"] = tgt
	d["dmg"] = dmg
	d["wt"] = wt
	d["shooter"] = shooter
	d["forced_miss"] = forced_miss
	d["traveled"] = 0.0
	d["speed"] = _speed_for(wt)
	d["max_dist"] = _max_dist_for(wt)
	d["dir"] = Vector2.RIGHT
	_proj.append(d)
	# v9.2: 枪口火——batch 路径无 Bullet 节点，原本无开火反馈，敌方小兵射击"看不到攻击"。
	# 在发射点播一个枪口火（敌方朝左），让玩家看到"敌人在开火"。
	# 节流：60% 抽样——密集齐射时 spark 池(MAX_SPARKS=200)会被枪口火打满挤压命中/暴击火花，
	# 抽样后既保留"敌方齐射"的视觉反馈，又把火花槽占用砍掉近一半。
	if not forced_miss and randf() < 0.6:
		VfxImpactFactory.spawn_muzzle_flash(self, from, false, wt)

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
	# v6.6: 移除开头冗余的 _sync_multimesh_layers() —— 同 player batch
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
			_release_proj_dict(r)  # v9.2: 归还池（目标失效）
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
	# Fix: _apply_hit 的回调链（take_damage → apply_on_hit_side_effects）可能在帧中途
	# 触发 clear_all() 清空 _proj。此时 write 仍 > 0，直接 resize(write) 会把数组从 0
	# 扩容到 write 并以 null 填充，下一帧 for r: Dictionary in _proj 遇到 nil 即崩溃。
	# 与 simple_indirect_projectile_batch.gd 一致：清空时把 write 归零，避免 null 污染。
	if _proj.is_empty():
		write = 0
	_proj.resize(write)
	_sync_multimesh_layers()

func _sync_multimesh_layers() -> void:
	if _proj.is_empty():
		for wt: int in _BATCH_WEAPON_TYPES:
			_layers[wt].multimesh.instance_count = 0
		return
	# v7.3 性能优化：单遍分桶（原两遍遍历 _proj：count + write）
	# v7.4 性能优化：buckets 改为成员变量 + clear() 复用，消除每帧 Dictionary + Array 分配。
	for wt: int in _BATCH_WEAPON_TYPES:
		(_buckets[wt] as Array).clear()
	for r: Dictionary in _proj:
		var wt_r: int = int(r["wt"])
		if _buckets.has(wt_r):
			(_buckets[wt_r] as Array).append(r)
	for wt: int in _BATCH_WEAPON_TYPES:
		var mmi: MultiMeshInstance2D = _layers[wt]
		var mm: MultiMesh = mmi.multimesh
		mm.instance_count = (_buckets[wt] as Array).size()
	for wt: int in _BATCH_WEAPON_TYPES:
		var arr: Array = _buckets[wt]
		if arr.is_empty():
			continue
		var mm2: MultiMesh = (_layers[wt] as MultiMeshInstance2D).multimesh
		var idx: int = 0
		for r: Dictionary in arr:
			var dir: Vector2 = r.get("dir", Vector2.RIGHT) as Vector2
			var local_pos: Vector2 = to_local(r["pos"])
			mm2.set_instance_transform_2d(idx, Transform2D(dir.angle(), local_pos))
			mm2.set_instance_color(idx, _ENEMY_TINT)
			idx += 1

func _apply_hit(r: Dictionary) -> void:
	var tgt: Node2D = r["tgt"]
	if tgt == null or not is_instance_valid(tgt):
		return
	var hit_pos: Vector2 = Vector2(r["pos"])
	var wt: int = int(r["wt"])
	# v7.x: 从目标提取 combat_kind 实现按目标类型差异化命中色调/缩放
	var _tgt_kind: int = -1
	if tgt != null and "stats" in tgt:
		var _ts: UnitStats = tgt.get("stats") as UnitStats
		if _ts != null:
			_tgt_kind = int(_ts.combat_kind)
	if bool(r.get("forced_miss", false)):
		CombatFeedback.show_miss(tgt.global_position, tgt)
	else:
		WeaponProjectileVfx.spawn_impact_with_kind(self, hit_pos, wt, false, _tgt_kind)
	var raw: float = float(r["dmg"])
	var shooter_raw: Variant = r["shooter"]
	var shooter: Node2D = shooter_raw if shooter_raw != null and is_instance_valid(shooter_raw) and shooter_raw is Node2D else null
	var mitigated: float = _apply_shield_wall_mitigation(raw, tgt)
	# v6.6: 应用改造/符文命中副作用（吸血/溅射/连锁）——敌方弹道同样生效
	if tgt.has_method("take_damage"):
		tgt.take_damage(mitigated, shooter)
		ModuleEffectHandler.apply_on_hit_side_effects(shooter, tgt, mitigated)

func _apply_shield_wall_mitigation(raw_damage: float, target: Node) -> float:
	if target == null or not is_instance_valid(target):
		return raw_damage
	if not (target is CharacterBody2D or target.is_in_group("phase_driver")):
		return raw_damage
	var mitigation: float = ActiveLawEffects.get_shield_wall_mitigation_for_point(target.global_position, "ALLY")
	if mitigation <= 0.0:
		return raw_damage
	return raw_damage * (1.0 - mitigation)

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
