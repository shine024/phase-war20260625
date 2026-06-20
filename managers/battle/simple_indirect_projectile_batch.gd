extends Node2D
## 曲射弹道批处理（玩家/敌方共用）：迫击炮/火箭/导弹使用 MultiMesh 绘制，减轻 Bullet 节点数量。
## 支持 weapon_type 3(ROCKET)/7(FLAK)/9(MISSILE) + 新枚举 INDIRECT(1)/AERIAL(2)
## Fix-1/3/5/6: 统一新枚举路由、AOE上限、禁用炮口火焰、空弹道跳过同步
## v6.2: 支持敌方曲射批处理，通过 is_player_side 区分阵营颜色
## Fix-9: 修复曲射批处理的防御计算（三攻三防系统）

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
const _ENEMY_TINT := Color(1.0, 0.38, 0.52)

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
func _get_indirect_arc_multiplier(wt: int) -> float:
	match wt:
		1:   # INDIRECT 迫击炮/野战炮 — 高弧线
			return 1.6
		7:   # FLAK 高射炮 — 较高弧线
			return 1.3
		9:   # MISSILE 导弹 — 中等弧线（默认基准）
			return 1.0
		2:   # AERIAL 空射 — 低弧线（俯冲）
			return 0.5
		3:   # ROCKET 火箭筒 — 最低弧线（直瞄反坦克）
			return 0.3
		_:
			return 1.0

func fire(from: Vector2, tgt: Node2D, dmg: float, wt: int, shooter: Node2D, shooter_stats: Variant, forced_miss: bool = false, weapon_name: String = "") -> void:
	if _proj.size() >= _MAX_PROJ or tgt == null or not is_instance_valid(tgt):
		return
	if not _layers.has(wt):
		push_error("[IndirectBatch] weapon_type %d not supported" % wt)
		return
	# 首发弹道时启用 physics_process
	if _proj.is_empty():
		set_physics_process(true)

	var start := from
	var end := tgt.global_position
	var dist := start.distance_to(end)
	var duration := 0.6 + dist / 2000.0 * 0.8
	# v6.5: 不同曲射武器的弧线高低不同（按 weapon_type 差异化）
	var apex := (100.0 + dist * 0.25) * _get_indirect_arc_multiplier(wt)

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
		"is_player": is_player_side,
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
	var tint := _PLAYER_TINT if is_player_side else _ENEMY_TINT
	var cursors: Dictionary = {}
	for wt: int in _BATCH_WEAPON_TYPES:
		var n: int = int(counts[wt])
		var mmi: MultiMeshInstance2D = _layers[wt]
		var mm: MultiMesh = mmi.multimesh
		# 优化：跳过空层
		if n == 0:
			if mm.instance_count > 0:
				mm.instance_count = 0
			continue
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
		mm2.set_instance_color(idx, tint)

func _apply_hit(r: Dictionary) -> void:
	var raw_tgt: Variant = r.get("tgt")
	if raw_tgt == null or not is_instance_valid(raw_tgt):
		return
	var tgt: Node2D = raw_tgt

	var wt: int = int(r["wt"])
	var hit_pos: Vector2 = r["pos"]

	# 生成命中特效
	var proj_is_player: bool = bool(r.get("is_player", true))
	if not bool(r.get("forced_miss", false)):
		_spawn_impact_explosion(hit_pos, proj_is_player, wt)
		# v6.4: 曲射爆炸触发中等屏幕震动
		var tree := get_tree()
		var bm: Node = tree.root.get_node_or_null("BattleManager") if tree else null
		if bm != null and is_instance_valid(bm) and bm.has_method("request_screen_shake"):
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

				# 3. 强化加成
				if shooter_stats.enhance_level > 0:
					var enhance_mult: float
					if shooter_stats.enhance_level >= 10:
						enhance_mult = 1.60
					elif shooter_stats.enhance_level >= 9:
						enhance_mult = 1.50
					else:
						enhance_mult = 1.0 + float(shooter_stats.enhance_level) * 0.05
					final_primary_dmg *= enhance_mult

					# v6.4: 改造伤害加成已由 ModificationRegistry.apply_with_level 在 UnitStats 构建阶段
					# 直接叠加到 attack_light/armor/air，此处无需再乘倍率。

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
				var splash_raw: float = raw_dmg * 0.5
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
						var def_val_splash: float = AttackCalculator.get_defense_vs(target_stats_splash, shooter_stats.combat_kind)
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
			# v6.6: 应用改造/符文命中副作用（吸血/溅射/连锁）
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

## 爆炸特效
## v6.2: 按 weapon_type 选不同贴图（迫击炮/导弹/高射炮/Omega/电磁炮各有专属外观）
func _spawn_impact_explosion(pos: Vector2, is_player_proj: bool = true, weapon_type: int = 1) -> void:
	var tex: Texture2D = WeaponProjectileVfx.explosion_impact_texture(weapon_type)
	if tex == null:
		return
	if WeaponProjectileVfx._active_impacts >= WeaponProjectileVfx.MAX_ACTIVE_IMPACTS:
		return
	WeaponProjectileVfx._active_impacts += 1
	var fx: Sprite2D = WeaponProjectileVfx._acquire_impact_sprite()
	fx.texture = tex
	fx.centered = true
	# v6.2: 曲射/空射爆炸特效放大(初始 0.75→1.0，放大倍率 1.5→2.25)
	fx.scale = Vector2(1.0, 1.0)
	fx.global_position = pos
	fx.z_as_relative = false
	fx.z_index = 4
	if not is_player_proj:
		fx.modulate = Color(1.0, 0.45, 0.55)
	fx.show()
	add_child(fx)
	var tw := fx.create_tween()
	tw.tween_property(fx, "scale", fx.scale * 2.25, 0.15)
	tw.parallel().tween_property(fx, "modulate:a", 0.0, 0.3)
	tw.finished.connect(func(): WeaponProjectileVfx._release_impact_sprite(fx))
