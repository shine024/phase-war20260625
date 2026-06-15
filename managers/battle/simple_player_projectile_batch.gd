extends Node2D
## 玩家轻武器弹道批处理：直线导引、无穿透/爆炸时用 MultiMesh 绘制，减轻 Bullet 节点数量。
## 仿照 simple_enemy_projectile_batch.gd，玩家版无护盾墙减伤。

const GC = preload("res://resources/game_constants.gd")
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
	prints("[BATCH_LAYER]", name, "creating layer wt=", wt)
	var mmi := MultiMeshInstance2D.new()
	mmi.texture = WeaponProjectileVfx.proj_texture(wt)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	var q := QuadMesh.new()
	q.size = WeaponProjectileVfx.proj_quad_size(wt)
	mm.mesh = q
	mmi.multimesh = mm
	prints("[BATCH_LAYER]", name, "wt=", wt, "texture=", mmi.texture, "quad_size=", q.size)
	return mmi

func fire(from: Vector2, tgt: Node2D, dmg: float, wt: int, shooter: Node2D, shooter_stats: Variant, forced_miss: bool = false) -> void:
	if _proj.size() >= _MAX_PROJ or tgt == null or not is_instance_valid(tgt):
		prints("BATCH_DEBUG: REJECTED size=", _proj.size(), "wt=", wt)
		return
	if not _layers.has(wt):
		prints("BATCH_DEBUG: REJECTED wt=", wt, "available=", _layers.keys())
		return
	prints("BATCH_DEBUG_FIRE:", name, "from=", from, "wt=", wt, "speed=", _speed_for(wt))
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
	_sync_multimesh_layers()
	if _proj.is_empty():
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
	var counts: Dictionary = {}
	for wt: int in _BATCH_WEAPON_TYPES:
		counts[wt] = 0
	for r: Dictionary in _proj:
		var wt_r: int = int(r["wt"])
		if counts.has(wt_r):
			counts[wt_r] += 1
	var cursors: Dictionary = {}
	for wt: int in _BATCH_WEAPON_TYPES:
		var mmi: MultiMeshInstance2D = _layers[wt]
		var mm: MultiMesh = mmi.multimesh
		var n: int = int(counts[wt])
		mm.instance_count = n
		cursors[wt] = 0
	for r: Dictionary in _proj:
		var wt_r: int = int(r["wt"])
		if not _layers.has(wt_r):
			continue
		var idx: int = int(cursors[wt_r])
		cursors[wt_r] = idx + 1
		var dir: Vector2 = r.get("dir", Vector2.RIGHT) as Vector2
		var mm2: MultiMesh = (_layers[wt_r] as MultiMeshInstance2D).multimesh
		var global_pos: Vector2 = r["pos"]
		var local_pos: Vector2 = to_local(global_pos)
		prints("BATCH_DEBUG:", name, "global_pos=", global_pos, "local_pos=", local_pos, "parent_pos=", position)
		mm2.set_instance_transform_2d(idx, Transform2D(dir.angle(), local_pos))
		if idx == 0:
			prints("BATCH_DEBUG_SLOW:", name, "dir=", dir, "wt=", wt_r, "speed=", _speed_for(wt_r), "z_index=", get_z_index())
		mm2.set_instance_color(idx, _PLAYER_TINT)

func _apply_hit(r: Dictionary) -> void:
	prints("APPLY_HIT:", r["wt"], "from=", r["pos"], "tgt=", r["tgt"].global_position if is_instance_valid(r["tgt"]) else "null")
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
	if tgt.has_method("take_damage"):
		var atk: Variant = shooter
		print("[PlayerProjectile] 造成伤害: ", raw, " 目标: ", tgt.name)
		tgt.take_damage(raw, atk)

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
