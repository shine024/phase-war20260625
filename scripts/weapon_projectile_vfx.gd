extends RefCounted
class_name WeaponProjectileVfx
## 武器弹道 / 命中贴图与缩放（玩家 Bullet 与敌方批处理共用）
## v6.0: 按武器名称查找专属贴图

const GC = preload("res://resources/game_constants.gd")
const WeaponVfxMapping: GDScript = preload("res://data/weapon_vfx_mapping.gd")

const TEX_DIR := "res://assets/effects/projectiles/weapons_realistic/"

## 旧 WeaponType 枚举 → 默认贴图（兼容）
const PROJ_TEX: Dictionary = {
	0: preload(TEX_DIR + "weapon_smg_projectile.png"),
	1: preload(TEX_DIR + "weapon_rifle_projectile.png"),
	2: preload(TEX_DIR + "weapon_mg_projectile.png"),
	3: preload(TEX_DIR + "weapon_rocket_projectile.png"),
	4: preload(TEX_DIR + "weapon_pistol_projectile.png"),
	5: preload(TEX_DIR + "weapon_shotgun_projectile.png"),
	6: preload(TEX_DIR + "weapon_sniper_projectile.png"),
	7: preload(TEX_DIR + "weapon_flak_projectile.png"),
	8: preload(TEX_DIR + "weapon_laser_projectile.png"),
	9: preload(TEX_DIR + "weapon_missile_projectile.png"),
	10: preload(TEX_DIR + "weapon_omega_cannon_projectile.png"),
	11: preload(TEX_DIR + "weapon_rail_cannon_projectile.png"),
}

const IMPACT_TEX_SMALL := preload(TEX_DIR + "weapon_impact_small_arms.png")
const IMPACT_TEX_SHOTGUN := preload(TEX_DIR + "weapon_impact_shotgun.png")
const IMPACT_TEX_SNIPER := preload(TEX_DIR + "weapon_impact_sniper.png")
const IMPACT_TEX_EXPLOSIVE := preload(TEX_DIR + "weapon_impact_explosive.png")

const PROJ_TEX_SCALE: Dictionary = {
	0: 0.09,
	4: 0.08,
	1: 0.10,
	2: 0.10,
	5: 0.11,
	6: 0.11,
	8: 0.10,
	3: 0.15,
	9: 0.16,
	7: 0.13,
	11: 0.16,
	10: 0.17,
}

const IMPACT_TEX_SCALE: Dictionary = {
	0: 0.10,
	4: 0.10,
	1: 0.10,
	2: 0.10,
	5: 0.12,
	6: 0.11,
	8: 0.11,
	3: 0.15,
	9: 0.16,
	7: 0.14,
	11: 0.17,
	10: 0.18,
}

const REF_TEX_PX: float = 512.0
const PROJ_DISPLAY_SCALE_MUL: float = 0.5


## ========== v6.0: 按武器名称查贴图 ==========

static func has_proj_texture_by_name(weapon_name: String) -> bool:
	var sid: String = WeaponVfxMapping.get_weapon_safe_id(weapon_name)
	if sid.is_empty():
		return false
	var path: String = TEX_DIR + sid + "_proj.png"
	return ResourceLoader.exists(path)


static func proj_texture_by_name(weapon_name: String) -> Texture2D:
	var sid: String = WeaponVfxMapping.get_weapon_safe_id(weapon_name)
	if sid.is_empty():
		return null
	var path: String = TEX_DIR + sid + "_proj.png"
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


static func impact_texture_by_name(weapon_name: String) -> Texture2D:
	var sid: String = WeaponVfxMapping.get_weapon_safe_id(weapon_name)
	if sid.is_empty():
		return null
	var path: String = TEX_DIR + sid + "_impact.png"
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


static func proj_scale_by_name(weapon_name: String) -> float:
	var cat: String = WeaponVfxMapping.get_category(weapon_name)
	match cat:
		"energy", "railgun": return 0.16 * PROJ_DISPLAY_SCALE_MUL
		"missile": return 0.16 * PROJ_DISPLAY_SCALE_MUL
		"cannon": return 0.15 * PROJ_DISPLAY_SCALE_MUL
		"mortar": return 0.15 * PROJ_DISPLAY_SCALE_MUL
		"machinegun": return 0.10 * PROJ_DISPLAY_SCALE_MUL
		"rifle": return 0.10 * PROJ_DISPLAY_SCALE_MUL
		_: return 0.10 * PROJ_DISPLAY_SCALE_MUL


static func impact_scale_by_name(weapon_name: String) -> float:
	var cat: String = WeaponVfxMapping.get_category(weapon_name)
	match cat:
		"energy", "railgun": return 0.17
		"missile": return 0.16
		"cannon", "mortar": return 0.15
		"machinegun": return 0.10
		"rifle": return 0.10
		_: return 0.11


## ========== 旧接口（兼容） ==========

static func has_proj_texture(weapon_type: int) -> bool:
	return PROJ_TEX.has(weapon_type) and PROJ_TEX[weapon_type] != null


static func proj_texture(weapon_type: int) -> Texture2D:
	return PROJ_TEX.get(weapon_type) as Texture2D


static func proj_scale(weapon_type: int) -> float:
	return float(PROJ_TEX_SCALE.get(weapon_type, 0.10)) * PROJ_DISPLAY_SCALE_MUL


static func proj_quad_size(weapon_type: int) -> Vector2:
	var s := proj_scale(weapon_type) * REF_TEX_PX
	return Vector2(s, s)


static func impact_texture(weapon_type: int) -> Texture2D:
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
	var tex: Texture2D = impact_texture(weapon_type)
	if tex == null:
		return
	var fx := Sprite2D.new()
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
	tw.finished.connect(fx.queue_free)
