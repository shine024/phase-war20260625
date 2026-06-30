extends Node2D
## 玩家轻武器弹道批处理：直线导引、无穿透/爆炸时用 MultiMesh 绘制，减轻 Bullet 节点数量。
## 仿照 simple_enemy_projectile_batch.gd，玩家版无护盾墙减伤。

const CombatFeedback = preload("res://scripts/combat_feedback.gd")
const WeaponProjectileVfx = preload("res://scripts/weapon_projectile_vfx.gd")

const _HIT_R2: float = 100.0
const _MAX_PROJ: int = 720
const _BATCH_WEAPON_TYPES: Array[int] = [
	0,  # SMG
	4,  # PISTOL
	1,  # RIFLE
	2,  # MG
]
const _PLAYER_TINT := Color(0.95, 0.92, 0.5)

var _proj: Array = []
var _layers: Dictionary = {}  # weapon_type -> MultiMeshInstance2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 3
	for wt: int in _BATCH_WEAPON_TYPES:
		_layers[wt] = _make_layer(wt)
		add_child(_layers[wt])

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
	# v6.4: 发光叠加，让子弹贴图产生霓虹发光
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mmi.material = mat
	return mmi

func fire(from: Vector2, tgt: Node2D, dmg: float, wt: int, shooter: Node2D, shooter_stats: Variant, forced_miss: bool = false) -> void:
	if _proj.size() >= _MAX_PROJ or tgt == null or not is_instance_valid(tgt):
		return
	if not _layers.has(wt):
		return
	_proj.append({
		"pos": from,
		"tgt": tgt,
		"dmg": dmg,
		"wt": wt,
		"shooter": shooter,
		"shooter_stats": shooter_stats,
		"forced_miss": forced_miss,
		"traveled": 0.0,
		"speed": _speed_for(wt),
		"max_dist": _max_dist_for(wt),
		"dir": Vector2.RIGHT,
	})

func clear_all() -> void:
	_proj.clear()
	for wt: int in _BATCH_WEAPON_TYPES:
		var mmi: MultiMeshInstance2D = _layers.get(wt)
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
			continue
		if float(r["traveled"]) > float(r["max_dist"]):
			continue
		if write != read_idx:
			_proj[write] = r
		write += 1
	_proj.resize(write)
	_sync_multimesh_layers()

func _sync_multimesh_layers() -> void:
	if _proj.is_empty():
		for wt: int in _BATCH_WEAPON_TYPES:
			_layers[wt].multimesh.instance_count = 0
		return
	# v7.3 性能优化：单遍遍历 _proj 同时完成分桶（按 wt 收集到每层临时数组）。
	# 原实现两遍遍历 _proj：第一遍 count，第二遍再遍历全量写 transform（含 int(r["wt"]) + _layers.has 重复判断）。
	# 改为单遍分桶后，第二遍只遍历每层实际弹道，减少遍历总量与重复判断。
	var buckets: Dictionary = {}
	for wt: int in _BATCH_WEAPON_TYPES:
		buckets[wt] = []
	for r: Dictionary in _proj:
		var wt_r: int = int(r["wt"])
		if buckets.has(wt_r):
			(buckets[wt_r] as Array).append(r)
	# 设每层 instance_count
	for wt: int in _BATCH_WEAPON_TYPES:
		var mmi: MultiMeshInstance2D = _layers[wt]
		var mm: MultiMesh = mmi.multimesh
		mm.instance_count = (buckets[wt] as Array).size()
	# 遍历分桶数组写 transform（只遍历实际弹道）
	for wt: int in _BATCH_WEAPON_TYPES:
		var arr: Array = buckets[wt]
		if arr.is_empty():
			continue
		var mm2: MultiMesh = (_layers[wt] as MultiMeshInstance2D).multimesh
		var idx: int = 0
		for r: Dictionary in arr:
			var dir: Vector2 = r.get("dir", Vector2.RIGHT) as Vector2
			var local_pos: Vector2 = to_local(r["pos"])
			mm2.set_instance_transform_2d(idx, Transform2D(dir.angle(), local_pos))
			mm2.set_instance_color(idx, _PLAYER_TINT)
			idx += 1

func _apply_hit(r: Dictionary) -> void:
	var tgt: Node2D = r["tgt"]
	if tgt == null or not is_instance_valid(tgt):
		return
	var hit_pos: Vector2 = Vector2(r["pos"])
	var wt: int = int(r["wt"])
	if bool(r.get("forced_miss", false)):
		CombatFeedback.show_miss(tgt.global_position, tgt)
	else:
		WeaponProjectileVfx.spawn_impact(self, hit_pos, wt, true)
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
