extends RefCounted
class_name WeaponProjectileVfx
## 武器弹道 / 命中贴图与缩放（玩家 Bullet 与敌方批处理共用）

const GC = preload("res://resources/game_constants.gd")

const TEX_DIR := "res://assets/effects/projectiles/weapons_realistic/"

const PROJ_TEX: Dictionary = {
	GC.WeaponType.SMG: preload(TEX_DIR + "weapon_smg_projectile.png"),
	GC.WeaponType.RIFLE: preload(TEX_DIR + "weapon_rifle_projectile.png"),
	GC.WeaponType.MG: preload(TEX_DIR + "weapon_mg_projectile.png"),
	GC.WeaponType.ROCKET: preload(TEX_DIR + "weapon_rocket_projectile.png"),
	GC.WeaponType.PISTOL: preload(TEX_DIR + "weapon_pistol_projectile.png"),
	GC.WeaponType.SHOTGUN: preload(TEX_DIR + "weapon_shotgun_projectile.png"),
	GC.WeaponType.SNIPER: preload(TEX_DIR + "weapon_sniper_projectile.png"),
	GC.WeaponType.FLAK: preload(TEX_DIR + "weapon_flak_projectile.png"),
	GC.WeaponType.LASER: preload(TEX_DIR + "weapon_laser_projectile.png"),
	GC.WeaponType.MISSILE: preload(TEX_DIR + "weapon_missile_projectile.png"),
	GC.WeaponType.OMEGA_CANNON: preload(TEX_DIR + "weapon_omega_cannon_projectile.png"),
	GC.WeaponType.RAIL_CANNON: preload(TEX_DIR + "weapon_rail_cannon_projectile.png"),
}

const IMPACT_TEX_SMALL := preload(TEX_DIR + "weapon_impact_small_arms.png")
const IMPACT_TEX_SHOTGUN := preload(TEX_DIR + "weapon_impact_shotgun.png")
const IMPACT_TEX_SNIPER := preload(TEX_DIR + "weapon_impact_sniper.png")
const IMPACT_TEX_EXPLOSIVE := preload(TEX_DIR + "weapon_impact_explosive.png")

const PROJ_TEX_SCALE: Dictionary = {
	GC.WeaponType.SMG: 0.09,
	GC.WeaponType.PISTOL: 0.08,
	GC.WeaponType.RIFLE: 0.10,
	GC.WeaponType.MG: 0.10,
	GC.WeaponType.SHOTGUN: 0.11,
	GC.WeaponType.SNIPER: 0.11,
	GC.WeaponType.LASER: 0.10,
	GC.WeaponType.ROCKET: 0.15,
	GC.WeaponType.MISSILE: 0.16,
	GC.WeaponType.FLAK: 0.13,
	GC.WeaponType.RAIL_CANNON: 0.16,
	GC.WeaponType.OMEGA_CANNON: 0.17,
}

const IMPACT_TEX_SCALE: Dictionary = {
	GC.WeaponType.SMG: 0.10,
	GC.WeaponType.PISTOL: 0.10,
	GC.WeaponType.RIFLE: 0.10,
	GC.WeaponType.MG: 0.10,
	GC.WeaponType.SHOTGUN: 0.12,
	GC.WeaponType.SNIPER: 0.11,
	GC.WeaponType.LASER: 0.11,
	GC.WeaponType.ROCKET: 0.15,
	GC.WeaponType.MISSILE: 0.16,
	GC.WeaponType.FLAK: 0.14,
	GC.WeaponType.RAIL_CANNON: 0.17,
	GC.WeaponType.OMEGA_CANNON: 0.18,
}

const REF_TEX_PX: float = 512.0
## 弹道贴图显示倍率（命中 IMPACT_TEX_SCALE 不受此影响）
const PROJ_DISPLAY_SCALE_MUL: float = 0.5


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
		GC.WeaponType.SHOTGUN:
			return IMPACT_TEX_SHOTGUN
		GC.WeaponType.SNIPER, GC.WeaponType.LASER:
			return IMPACT_TEX_SNIPER
		GC.WeaponType.ROCKET, GC.WeaponType.MISSILE, GC.WeaponType.FLAK, GC.WeaponType.RAIL_CANNON, GC.WeaponType.OMEGA_CANNON:
			return IMPACT_TEX_EXPLOSIVE
		_:
			return IMPACT_TEX_SMALL


static func impact_scale(weapon_type: int) -> float:
	return float(IMPACT_TEX_SCALE.get(weapon_type, 0.11))


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
