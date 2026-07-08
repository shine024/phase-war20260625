extends RefCounted
class_name WeaponProjectileVfx
## 武器弹道 / 命中贴图与缩放（玩家 Bullet 与敌方批处理共用）
## v6.0: 按武器名称查找专属贴图

const GC = preload("res://resources/game_constants.gd")
const WeaponVfxMapping: GDScript = preload("res://data/weapon_vfx_mapping.gd")

const TEX_DIR := "res://assets/effects/projectiles/weapons_realistic/"

## 旧 WeaponType 枚举 → 默认贴图（兼容 v3 旧武器 ID）
## v6.1 新枚举映射：INDIRECT(1) -> 曲射弹道, AERIAL(2) -> 空射导弹
## 注意：新枚举 0=DIRECT, 1=INDIRECT, 2=AERIAL 不在此字典中
## 直接映射通过 _proj_texture_by_wt() 处理
const PROJ_TEX_LEGACY: Dictionary = {
	0: preload(TEX_DIR + "weapon_smg_projectile.png"),       # SMG
	1: preload(TEX_DIR + "weapon_rifle_projectile.png"),     # RIFLE (旧)
	2: preload(TEX_DIR + "weapon_mg_projectile.png"),        # MG
	3: preload(TEX_DIR + "weapon_rocket_projectile.png"),    # ROCKET (旧物理)
	4: preload(TEX_DIR + "weapon_pistol_projectile.png"),    # PISTOL
	5: preload(TEX_DIR + "weapon_shotgun_projectile.png"),   # SHOTGUN
	6: preload(TEX_DIR + "weapon_sniper_projectile.png"),    # SNIPER
	7: preload(TEX_DIR + "weapon_flak_projectile.png"),      # FLAK (旧物理)
	8: preload(TEX_DIR + "weapon_laser_projectile.png"),     # LASER
	9: preload(TEX_DIR + "weapon_missile_projectile.png"),   # MISSILE (旧物理)
	10: preload(TEX_DIR + "weapon_omega_cannon_projectile.png"), # OMEGA_CANNON
	11: preload(TEX_DIR + "weapon_rail_cannon_projectile.png"),  # RAIL_CANNON
}
## 新枚举投射贴图（GameConstants.WeaponType）
const PROJ_TEX_NEW: Dictionary = {
	0: preload(TEX_DIR + "weapon_smg_projectile.png"),       # DIRECT -> 通用直射
	1: preload(TEX_DIR + "weapon_artillery_ballistic.png"),  # INDIRECT -> 曲射弹道
	2: preload(TEX_DIR + "weapon_missile_projectile.png"),   # AERIAL -> 空射导弹
}

const IMPACT_TEX_SMALL := preload(TEX_DIR + "weapon_impact_small_arms.png")
const IMPACT_TEX_SHOTGUN := preload(TEX_DIR + "weapon_impact_shotgun.png")
const IMPACT_TEX_SNIPER := preload(TEX_DIR + "weapon_impact_sniper.png")
const IMPACT_TEX_EXPLOSIVE := preload(TEX_DIR + "weapon_impact_explosive.png")
## v6.2: 曲射专属落地爆炸（迫击炮/榴弹炮，与 IMPACT_TEX_EXPLOSIVE 区分）
const IMPACT_TEX_ARTILLERY := preload(TEX_DIR + "weapon_artillery_impact.png")
## v6.2: 能量/电磁类武器命中（Omega 炮 / 电磁炮）
const IMPACT_TEX_OMEGA := preload(TEX_DIR + "weapon_impact_omega.png")

## v7.x: 按目标 combat_kind 的命中修饰（色调/缩放倍率/震动强度）
## 复用现有贴图，仅叠加 Color modulate + scale 倍率实现"火花/碎屑/空爆"视觉差异
## LIGHT/SUPPORT → 黄白火花（小）；ARMOR/FORT → 橙红金属碎屑（中）；AIR → 空爆（大）
const IMPACT_TINT_BY_KIND: Dictionary = {
	0: Color(1.0, 0.95, 0.6),   # LIGHT 黄白火花
	2: Color(1.0, 0.95, 0.6),   # SUPPORT 归入 LIGHT
	1: Color(1.0, 0.55, 0.25),  # ARMOR 橙红金属碎屑
	4: Color(1.0, 0.55, 0.25),  # FORT 归入 ARMOR
	3: Color(1.0, 1.0, 1.0),    # AIR 保留原色（空爆贴图已足够）
}
const IMPACT_SCALE_MUL_BY_KIND: Dictionary = {
	0: 0.85,  # LIGHT 小火花
	2: 0.85,  # SUPPORT
	1: 1.15,  # ARMOR 中等碎屑
	4: 1.15,  # FORT
	3: 1.35,  # AIR 大空爆
}
## combat_kind → 屏幕震动 (幅度, 时长)。AIR 最强，ARMOR 中等，LIGHT 轻微
const IMPACT_SHAKE_BY_KIND: Dictionary = {
	0: Vector2(1.8, 0.10),  # LIGHT
	2: Vector2(1.8, 0.10),  # SUPPORT
	1: Vector2(3.2, 0.18),  # ARMOR
	4: Vector2(3.2, 0.18),  # FORT
	3: Vector2(5.0, 0.25),  # AIR
}

const PROJ_TEX_SCALE: Dictionary = {
	# New enum: 0=DIRECT, 1=INDIRECT, 2=AERIAL
	0: 0.27,
	1: 0.45,
	2: 0.48,
	# Legacy: SMG=0, RIFLE=1, MG=2, ROCKET=3, PISTOL=4, SHOTGUN=5, SNIPER=6, FLAK=7, LASER=8, MISSILE=9, OMEGA=10, RAIL=11
	3: 0.45,
	5: 0.33,
	6: 0.33,
	7: 0.39,
	8: 0.30,
	9: 0.48,
	10: 0.51,
	11: 0.48,
	4: 0.24,
}

const IMPACT_TEX_SCALE: Dictionary = {
	# New enum
	0: 0.30,   # DIRECT
	1: 0.45,   # INDIRECT
	2: 0.48,   # AERIAL
	# Legacy
	4: 0.30,
	5: 0.36,
	6: 0.33,
	7: 0.42,
	8: 0.33,
	9: 0.48,
	10: 0.54,
	11: 0.51,
}

const REF_TEX_PX: float = 512.0
const PROJ_DISPLAY_SCALE_MUL: float = 0.05


## ========== v6.0: 按武器名称查贴图 ==========

## v6.1 性能优化：武器名贴图静态缓存，避免每发子弹 ResourceLoader.exists() + load()
static var _proj_name_cache: Dictionary = {}
static var _impact_name_cache: Dictionary = {}
## v6.2 性能优化：命中特效 Sprite2D 对象池，替代每帧 new/queue_free
static var _impact_pool: Array = []  # 可复用 Sprite2D
static var _active_impacts: int = 0
const MAX_ACTIVE_IMPACTS: int = 64  # 从 32 增加到 64，支持曲射单位同时攻击

## 从池中获取（或新建）Sprite2D
## 跳过已释放实例：战斗清理 queue_free 特效 Sprite 后，静态池仍可能持有悬空引用
static func _acquire_impact_sprite() -> Sprite2D:
	while _impact_pool.size() > 0:
		var fx: Sprite2D = _impact_pool.pop_back()
		if fx != null and is_instance_valid(fx):
			fx.visible = true
			fx.modulate = Color.WHITE
			return fx
	return Sprite2D.new()

## 归还 Sprite2D 到池
static func _release_impact_sprite(fx: Sprite2D) -> void:
	if fx == null or not is_instance_valid(fx):
		_active_impacts -= 1
		return
	if fx.is_inside_tree() and fx.get_parent():
		fx.get_parent().remove_child(fx)
	fx.visible = false
	fx.modulate = Color.WHITE
	_active_impacts -= 1
	if _impact_pool.size() < MAX_ACTIVE_IMPACTS:
		_impact_pool.append(fx)
	else:
		fx.queue_free()


static func has_proj_texture_by_name(weapon_name: String) -> bool:
	return proj_texture_by_name(weapon_name) != null


static func proj_texture_by_name(weapon_name: String) -> Texture2D:
	if _proj_name_cache.has(weapon_name):
		return _proj_name_cache[weapon_name]
	var sid: String = WeaponVfxMapping.get_weapon_safe_id(weapon_name)
	if sid.is_empty():
		_proj_name_cache[weapon_name] = null
		return null
	var path: String = TEX_DIR + sid + "_proj.png"
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path) as Texture2D
		_proj_name_cache[weapon_name] = tex
		return tex
	_proj_name_cache[weapon_name] = null
	return null


static func impact_texture_by_name(weapon_name: String) -> Texture2D:
	if _impact_name_cache.has(weapon_name):
		return _impact_name_cache[weapon_name]
	var sid: String = WeaponVfxMapping.get_weapon_safe_id(weapon_name)
	if sid.is_empty():
		_impact_name_cache[weapon_name] = null
		return null
	var path: String = TEX_DIR + sid + "_impact.png"
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path) as Texture2D
		_impact_name_cache[weapon_name] = tex
		return tex
	_impact_name_cache[weapon_name] = null
	return null


static func proj_scale_by_name(weapon_name: String) -> float:
	var cat: String = WeaponVfxMapping.get_category(weapon_name)
	match cat:
		"energy", "railgun": return 0.48 * PROJ_DISPLAY_SCALE_MUL
		"missile": return 0.48 * PROJ_DISPLAY_SCALE_MUL
		"cannon": return 0.45 * PROJ_DISPLAY_SCALE_MUL
		"mortar": return 0.45 * PROJ_DISPLAY_SCALE_MUL
		"machinegun": return 0.30 * PROJ_DISPLAY_SCALE_MUL
		"rifle": return 0.30 * PROJ_DISPLAY_SCALE_MUL
		_: return 0.30 * PROJ_DISPLAY_SCALE_MUL


static func impact_scale_by_name(weapon_name: String) -> float:
	var cat: String = WeaponVfxMapping.get_category(weapon_name)
	match cat:
		"energy", "railgun": return 0.51
		"missile": return 0.48
		"cannon", "mortar": return 0.45
		"machinegun": return 0.30
		"rifle": return 0.30
		_: return 0.33


## ========== 旧接口（兼容） ==========

static func has_proj_texture(weapon_type: int) -> bool:
	# New enum: 0=DIRECT, 1=INDIRECT, 2=AERIAL
	if weapon_type in [0, 1, 2]:
		return true
	# Legacy: check PROJ_LEGACY
	return PROJ_TEX_LEGACY.has(weapon_type) and PROJ_TEX_LEGACY[weapon_type] != null


static func proj_texture(weapon_type: int) -> Texture2D:
	# New enum first
	if weapon_type == 1:  # INDIRECT
		return PROJ_TEX_NEW[1]
	if weapon_type == 2:  # AERIAL
		return PROJ_TEX_NEW[2]
	if weapon_type == 0:  # DIRECT -> default to SMG
		return PROJ_TEX_NEW[0]
	# Legacy fallback
	return PROJ_TEX_LEGACY.get(weapon_type) as Texture2D


static func proj_scale(weapon_type: int) -> float:
	return float(PROJ_TEX_SCALE.get(weapon_type, 0.10)) * PROJ_DISPLAY_SCALE_MUL


static func proj_quad_size(weapon_type: int) -> Vector2:
	# v7.x 修复：QuadMesh 尺寸必须与 Sprite2D 显示尺寸一致
	# Sprite2D 显示尺寸 = texture_pixel_size * proj_scale
	# proj_scale = PROJ_TEX_SCALE[type] * PROJ_DISPLAY_SCALE_MUL
	# 因此 quad size = 贴图实际像素 * proj_scale
	# 由于无法在编译期获取贴图像素尺寸，改用以下等价公式：
	# quad_h = proj_scale * REF_TEX_PX * (tex_height / REF_TEX_PX)
	#        = proj_scale * tex_height
	# 我们已知各武器对应的贴图高度，直接硬编码计算：
	var s := proj_scale(weapon_type)
	match weapon_type:
		0, 4:     # DIRECT/SMG/PISTOL — tex 673x121 / 567x131
			return Vector2(s * 673, s * 121)
		1:        # INDIRECT/artillery — tex 1122x184
			return Vector2(s * 1122, s * 184)
		2, 9:     # AERIAL/MISSILE — tex 1127x251
			return Vector2(s * 1127, s * 251)
		3, 7:     # ROCKET/FLAK — tex 1202x203
			return Vector2(s * 1202, s * 203)
		5:        # SHOTGUN — tex 737x472
			return Vector2(s * 737, s * 472)
		6:        # SNIPER — tex 629x80
			return Vector2(s * 629, s * 80)
		8:        # LASER — tex 365x77
			return Vector2(s * 365, s * 77)
		10:       # OMEGA — tex 1071x191
			return Vector2(s * 1071, s * 191)
		11:       # RAIL — tex 974x208
			return Vector2(s * 974, s * 208)
		_:
			return Vector2(s * 512, s * 128)


static func impact_texture(weapon_type: int) -> Texture2D:
	# New enum: 0=DIRECT, 1=INDIRECT, 2=AERIAL
	if weapon_type == 1 or weapon_type == 2:  # INDIRECT / AERIAL -> explosive
		return IMPACT_TEX_EXPLOSIVE
	# Legacy
	match weapon_type:
		5:
			return IMPACT_TEX_SHOTGUN
		6, 8:
			return IMPACT_TEX_SNIPER
		3, 9, 7, 11, 10:
			return IMPACT_TEX_EXPLOSIVE
		_:
			return IMPACT_TEX_SMALL


## v6.2: 爆炸类武器的命中贴图（按武器类型差异化）
## 用于 bullet._spawn_impact_explosion 与 indirect_batch._spawn_impact_explosion
## 让迫击炮(抛物线落地)/空射导弹/火箭/高射炮/Omega/电磁炮各有不同外观
static func explosion_impact_texture(weapon_type: int) -> Texture2D:
	match weapon_type:
		1:  # INDIRECT (新枚举) -> 迫击炮/榴弹炮：曲射落地专属爆炸
			return IMPACT_TEX_ARTILLERY
		10, 11:  # OMEGA_CANNON / RAIL_CANNON -> 能量/电磁类命中
			return IMPACT_TEX_OMEGA
		2, 3, 7, 9:  # AERIAL / ROCKET / FLAK / MISSILE -> 通用爆炸
			return IMPACT_TEX_EXPLOSIVE
		_:
			return IMPACT_TEX_EXPLOSIVE


static func impact_scale(weapon_type: int) -> float:
	return float(IMPACT_TEX_SCALE.get(weapon_type, 0.11))


## ========== 命中特效生成 ==========

static func spawn_impact(parent: Node2D, world_pos: Vector2, weapon_type: int, is_player_shot: bool) -> void:
	spawn_impact_with_kind(parent, world_pos, weapon_type, is_player_shot, -1)

## v7.x: 带 combat_kind 的命中特效（按目标类型差异化色调/缩放）
## combat_kind = -1 时走原逻辑（向后兼容所有现有调用点）
## combat_kind >= 0 时叠加 IMPACT_TINT_BY_KIND 色调 + IMPACT_SCALE_MUL_BY_KIND 缩放倍率
static func spawn_impact_with_kind(parent: Node2D, world_pos: Vector2, weapon_type: int, is_player_shot: bool, target_combat_kind: int = -1) -> void:
	if parent == null:
		return
	if _active_impacts >= MAX_ACTIVE_IMPACTS:
		return
	var tex: Texture2D = impact_texture(weapon_type)
	if tex == null:
		return
	_active_impacts += 1
	var fx: Sprite2D = _acquire_impact_sprite()
	fx.texture = tex
	fx.centered = true
	var sc := impact_scale(weapon_type)
	# v7.x: 按 combat_kind 叠加缩放倍率（火花小/碎屑中/空博大）
	if target_combat_kind >= 0 and IMPACT_SCALE_MUL_BY_KIND.has(target_combat_kind):
		sc *= float(IMPACT_SCALE_MUL_BY_KIND[target_combat_kind])
	fx.scale = Vector2.ONE * sc
	fx.global_position = world_pos
	# v7.x: 按 combat_kind 叠加色调；敌方子弹保持原红色调（优先级低于 combat_kind）
	if target_combat_kind >= 0 and IMPACT_TINT_BY_KIND.has(target_combat_kind):
		fx.modulate = IMPACT_TINT_BY_KIND[target_combat_kind]
	elif not is_player_shot:
		fx.modulate = Color(1.0, 0.45, 0.55)
	parent.add_child(fx)
	var tw := fx.create_tween()
	tw.tween_property(fx, "scale", fx.scale * 1.22, 0.07)
	tw.parallel().tween_property(fx, "modulate:a", 0.0, 0.20)
	tw.finished.connect(func(): _release_impact_sprite(fx))
	# v7.x: 冲击波环 + 火花叠加（仅爆炸/曲射类，轻武器跳过避免性能浪费）
	if weapon_type in [1, 2, 3, 7, 9, 10, 11]:
		_spawn_impact_shockwave(parent, world_pos, fx.scale.x, is_player_shot, target_combat_kind)
	elif not weapon_type in [0, 4]:  # 非轻武器也加少量火花
		_spawn_impact_sparks(parent, world_pos, fx.scale.x * 0.6, is_player_shot, target_combat_kind)


## v7.x: 冲击波环 — 一个扩散并淡出的圆环（用 Line2D 画）
## 仅重型武器触发，让爆炸有"冲击波"层次感
static func _spawn_impact_shockwave(parent: Node2D, world_pos: Vector2, base_scale: float, is_player_shot: bool, target_combat_kind: int) -> void:
	if parent == null:
		return
	var ring := Line2D.new()
	ring.width = 2.0
	ring.sharp_limit = 2.0
	# 圆环颜色：按 combat_kind 取主冲击色调
	var ring_color := Color(1.0, 0.9, 0.5)
	if target_combat_kind >= 0 and IMPACT_TINT_BY_KIND.has(target_combat_kind):
		ring_color = IMPACT_TINT_BY_KIND[target_combat_kind]
	elif not is_player_shot:
		ring_color = Color(1.0, 0.45, 0.55)
	ring.default_color = ring_color
	ring.z_as_relative = false
	ring.z_index = 5
	ring.material = _get_shockwave_mat()
	# 生成 16 点圆环（半径初始 8，放大到 base_scale * 40）
	var start_r: float = 8.0
	var pts := PackedVector2Array()
	for i in 16:
		var a: float = TAU * float(i) / 16.0
		pts.append(Vector2(cos(a), sin(a)) * start_r)
	pts.append(pts[0])  # 闭合
	ring.points = pts
	parent.add_child(ring)
	ring.global_position = world_pos
	var end_r: float = maxf(40.0, base_scale * 40.0)
	var tw := ring.create_tween()
	# 扩散 + 淡出
	tw.set_parallel(true)
	tw.tween_method(func(r: float):
		var p: PackedVector2Array = PackedVector2Array()
		for i in 17:
			var a: float = TAU * float(i % 16) / 16.0
			p.append(Vector2(cos(a), sin(a)) * r)
		ring.points = p, start_r, end_r, 0.22)
	tw.tween_property(ring, "modulate:a", 0.0, 0.22)
	tw.chain().tween_callback(ring.queue_free)
	# 同步撒一把火花
	_spawn_impact_sparks(parent, world_pos, base_scale * 0.7, is_player_shot, target_combat_kind)


## v7.x: 火花飞溅 — 几个小三角形向外飞出后淡出
## 用 Polygon2D 对象池替代每发 new（复用 _impact_pool 模式）
static var _spark_pool: Array = []
const MAX_SPARKS: int = 96  # 全局火花上限

static func _spawn_impact_sparks(parent: Node2D, world_pos: Vector2, intensity: float, is_player_shot: bool, target_combat_kind: int) -> void:
	if parent == null or _spark_pool.size() == 0 and _active_sparks >= MAX_SPARKS:
		return
	var spark_color := Color(1.0, 0.95, 0.5)
	if target_combat_kind >= 0 and IMPACT_TINT_BY_KIND.has(target_combat_kind):
		spark_color = IMPACT_TINT_BY_KIND[target_combat_kind]
	elif not is_player_shot:
		spark_color = Color(1.0, 0.45, 0.55)
	# 火花数 = clamp(intensity * 4, 3, 6)
	var count: int = int(clamp(intensity * 4.0, 3.0, 6.0))
	for i in count:
		if _active_sparks >= MAX_SPARKS:
			break
		var spark: Polygon2D = _acquire_spark()
		if spark == null:
			break
		_active_sparks += 1
		# 小三角形（朝右，旋转随机角度后向外飞）
		spark.polygon = PackedVector2Array([Vector2(-1, -1), Vector2(2, 0), Vector2(-1, 1)])
		spark.color = spark_color
		spark.material = _get_shockwave_mat()
		parent.add_child(spark)
		spark.global_position = world_pos
		var angle: float = randf() * TAU
		var dist: float = randf_range(12.0, 28.0) * maxf(0.6, intensity)
		var target_pos: Vector2 = world_pos + Vector2(cos(angle), sin(angle)) * dist
		var rot_end: float = angle + randf_range(-1.5, 1.5)
		spark.rotation = angle
		var tw := spark.create_tween()
		tw.set_parallel(true)
		tw.tween_property(spark, "global_position", target_pos, 0.25).set_ease(Tween.EASE_OUT)
		tw.tween_property(spark, "rotation", rot_end, 0.25)
		tw.tween_property(spark, "modulate:a", 0.0, 0.25)
		tw.chain().tween_callback(_release_spark.bind(spark))

static var _active_sparks: int = 0

static func _acquire_spark() -> Polygon2D:
		while not _spark_pool.is_empty():
			var p: Polygon2D = _spark_pool.pop_back()
			if p != null and is_instance_valid(p) and not p.is_queued_for_deletion():
				p.visible = true
				p.modulate = Color.WHITE
				return p
		return Polygon2D.new()

static func _release_spark(spark: Polygon2D) -> void:
	if spark == null or not is_instance_valid(spark):
		_active_sparks -= 1
		return
	if spark.is_inside_tree() and spark.get_parent():
		spark.get_parent().remove_child(spark)
	spark.visible = false
	spark.modulate = Color.WHITE
	_active_sparks -= 1
	if _spark_pool.size() < MAX_SPARKS:
		_spark_pool.append(spark)
	else:
		spark.queue_free()

static var _shockwave_mat: CanvasItemMaterial
static func _get_shockwave_mat() -> CanvasItemMaterial:
	if _shockwave_mat == null:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_shockwave_mat = m
	return _shockwave_mat

## v7.x: 按 combat_kind 返回屏幕震动参数 (幅度, 时长)，无匹配返回 Vector2.ZERO
static func impact_shake_for_kind(target_combat_kind: int) -> Vector2:
	if target_combat_kind >= 0 and IMPACT_SHAKE_BY_KIND.has(target_combat_kind):
		return IMPACT_SHAKE_BY_KIND[target_combat_kind]
	return Vector2.ZERO
