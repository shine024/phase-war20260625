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
const PROJ_DISPLAY_SCALE_MUL: float = 0.5


## ========== v6.0: 按武器名称查贴图 ==========

## v6.1 性能优化：武器名贴图静态缓存，避免每发子弹 ResourceLoader.exists() + load()
static var _proj_name_cache: Dictionary = {}
static var _impact_name_cache: Dictionary = {}
## v6.2 性能优化：命中特效 Sprite2D 对象池，替代每帧 new/queue_free
static var _impact_pool: Array = []  # 可复用 Sprite2D
static var _active_impacts: int = 0
const MAX_ACTIVE_IMPACTS: int = 64  # 从 32 增加到 64，支持曲射单位同时攻击

## 从池中获取（或新建）Sprite2D
static func _acquire_impact_sprite() -> Sprite2D:
	if _impact_pool.size() > 0:
		var fx: Sprite2D = _impact_pool.pop_back()
		if is_instance_valid(fx):
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
	var s := proj_scale(weapon_type) * REF_TEX_PX
	prints("[PROJ_QS]", "wt=", weapon_type, "scale=", proj_scale(weapon_type), "final_size=", s)
	return Vector2(s, s)


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


static func impact_scale(weapon_type: int) -> float:
	return float(IMPACT_TEX_SCALE.get(weapon_type, 0.11))


## ========== 命中特效生成 ==========

static func spawn_impact(parent: Node2D, world_pos: Vector2, weapon_type: int, is_player_shot: bool) -> void:
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
	fx.scale = Vector2.ONE * sc
	fx.global_position = world_pos
	if not is_player_shot:
		fx.modulate = Color(1.0, 0.45, 0.55)
	parent.add_child(fx)
	var tw := fx.create_tween()
	tw.tween_property(fx, "scale", fx.scale * 1.22, 0.07)
	tw.parallel().tween_property(fx, "modulate:a", 0.0, 0.20)
	tw.finished.connect(func(): _release_impact_sprite(fx))
