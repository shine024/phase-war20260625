extends Node2D
## 玩家曲射弹道批处理：迫击炮/火箭/导弹使用 MultiMesh 绘制，减轻 Bullet 节点数量。
## 支持 weapon_type 3(ROCKET)/7(FLAK)/9(MISSILE) + 新枚举 INDIRECT(1)/AERIAL(2)
## Fix-1/3/5/6: 统一新枚举路由、AOE上限、禁用炮口火焰、空弹道跳过同步

const GC = preload("res://resources/game_constants.gd")
const CombatFeedback = preload("res://scripts/combat_feedback.gd")
const WeaponProjectileVfx = preload("res://scripts/weapon_projectile_vfx.gd")
const AttackCalculator = preload("res://scripts/battle/attack_calculator.gd")

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

func _ready() -> void:
	set_physics_process(true)
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	z_as_relative = false
	z_index = 3
	for wt: int in _BATCH_WEAPON_TYPES:
		_layers[wt] = _make_layer(wt)
		_layers[wt].show()
		add_child(_layers[wt])
	print("[IndirectBatch] initialized with ", _BATCH_WEAPON_TYPES.size(), " layers")

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
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	mmi.material = mat
	print("[IndirectBatch] layer for wt=", wt, " texture=", tex, " quad_size=", q.size)
	return mmi

func fire(from: Vector2, tgt: Node2D, dmg: float, wt: int, shooter: Node2D, shooter_stats: Variant, forced_miss: bool = false, weapon_name: String = "") -> void:
	if _proj.size() >= _MAX_PROJ or tgt == null or not is_instance_valid(tgt):
		return
	if not _layers.has(wt):
		push_error("[IndirectBatch] weapon_type %d not supported" % wt)
		return
	if _proj.is_empty():
		print("[IndirectBatch] first fire wt=", wt, " from=", from, " to=", tgt.global_position)

	var start := from
	var end := tgt.global_position
	var dist := start.distance_to(end)
	var duration := 0.6 + dist / 2000.0 * 0.8
	var apex := 100.0 + dist * 0.25

	_proj.append({
		"start": start,
		"end": end,
		"pos": from,
		"tgt": tgt,
		"dmg": dmg,
		"wt": wt,
		"shooter": shooter,
		"shooter_stats": shooter_stats,
		"forced_miss": forced_miss,
		"weapon_name": weapon_name,
		"progress": 0.0,
		"duration": duration,
		"apex": apex,
		"dir": Vector2.RIGHT,
		"prev_pos": from,
		"muzzle_spawned": true,  # Fix-5: 禁用炮口火焰，标记为已生成
		"impact_spawned": false,
		"is_player": true,
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
	if _proj.is_empty():
		# Fix-6: 空弹道时清除 MultiMesh 实例并跳过同步
		for wt_key: int in _BATCH_WEAPON_TYPES:
			var mmi: MultiMeshInstance2D = _layers.get(wt_key)
			if mmi and mmi.multimesh and mmi.multimesh.instance_count > 0:
				mmi.multimesh.instance_count = 0
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
		mm2.set_instance_transform_2d(idx, Transform2D(dir.angle(), local_pos))
		mm2.set_instance_color(idx, _PLAYER_TINT)

func _apply_hit(r: Dictionary) -> void:
	var tgt: Node2D = r["tgt"]
	if tgt == null or not is_instance_valid(tgt):
		return

	var wt: int = int(r["wt"])
	var hit_pos: Vector2 = r["pos"]

	# 生成命中特效
	if not bool(r.get("forced_miss", false)):
		_spawn_impact_explosion(hit_pos)

	# 造成伤害
	if bool(r.get("forced_miss", false)):
		CombatFeedback.show_miss(tgt.global_position, tgt)
	else:
		var raw_dmg: float = float(r["dmg"])
		var explosion_r: float = _WEAPON_CONFIG.get(wt, {}).get("explosion_radius", 40.0)

		# Fix-3: AOE 伤害，限制溅射目标数量
		var targets: Array = _get_aoe_targets(hit_pos, explosion_r, tgt)
		var splash_count := 0
		for target in targets:
			if target == tgt:
				continue
			if splash_count >= MAX_AOE_TARGETS_PER_HIT:
				break
			if target.has_method("take_damage"):
				var splash_dmg := raw_dmg * 0.5
				var shooter_raw: Variant = r["shooter"]
				var shooter: Node2D = shooter_raw if shooter_raw != null and is_instance_valid(shooter_raw) and shooter_raw is Node2D else null
				target.take_damage(splash_dmg, shooter)
				splash_count += 1

		# 主目标伤害
		if tgt.has_method("take_damage"):
			var shooter_raw: Variant = r["shooter"]
			var shooter: Node2D = shooter_raw if shooter_raw != null and is_instance_valid(shooter_raw) and shooter_raw is Node2D else null
			tgt.take_damage(raw_dmg, shooter)

	# Fix-8: 性能监控
	if _proj.size() > 20 and Engine.get_frames_drawn() % 300 == 0:
		push_warning("[IndirectBatch] 高弹道数: %d" % _proj.size())

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

## 爆炸特效
func _spawn_impact_explosion(pos: Vector2) -> void:
	const ARTILLERY_IMPACT_TEX = preload("res://assets/effects/projectiles/weapons_realistic/weapon_artillery_impact.png")
	if ARTILLERY_IMPACT_TEX == null:
		return
	if WeaponProjectileVfx._active_impacts >= WeaponProjectileVfx.MAX_ACTIVE_IMPACTS:
		return
	WeaponProjectileVfx._active_impacts += 1
	var fx: Sprite2D = WeaponProjectileVfx._acquire_impact_sprite()
	fx.texture = ARTILLERY_IMPACT_TEX
	fx.centered = true
	fx.scale = Vector2(0.25, 0.25)
	fx.global_position = pos
	fx.z_as_relative = false
	fx.z_index = 4
	fx.show()
	add_child(fx)
	var tw := fx.create_tween()
	tw.tween_property(fx, "scale", fx.scale * 1.5, 0.15)
	tw.parallel().tween_property(fx, "modulate:a", 0.0, 0.3)
	tw.finished.connect(func(): WeaponProjectileVfx._release_impact_sprite(fx))
