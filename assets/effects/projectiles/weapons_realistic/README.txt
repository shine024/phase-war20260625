# 写实武器弹道 / 命中贴图（已抠绿，透明底）
# 导入 Godot 后由 bullet.gd 或 VFX 系统按 WeaponType 引用。

# --- 弹道（朝右飞行）---
# weapon_smg_projectile.png       -> WeaponType.SMG
# weapon_rifle_projectile.png     -> WeaponType.RIFLE
# weapon_mg_projectile.png        -> WeaponType.MG
# weapon_pistol_projectile.png    -> WeaponType.PISTOL
# weapon_shotgun_projectile.png   -> WeaponType.SHOTGUN
# weapon_sniper_projectile.png    -> WeaponType.SNIPER
# weapon_rocket_projectile.png    -> WeaponType.ROCKET
# weapon_flak_projectile.png      -> WeaponType.FLAK
# weapon_laser_projectile.png     -> WeaponType.LASER（写实：燃烧曳光弹）
# weapon_missile_projectile.png   -> WeaponType.MISSILE
# weapon_omega_cannon_projectile.png -> WeaponType.OMEGA_CANNON（写实：155mm 炮弹）
# weapon_rail_cannon_projectile.png  -> WeaponType.RAIL_CANNON

# --- 命中（建议复用）---
# weapon_impact_small_arms.png    -> SMG, PISTOL, RIFLE, MG
# weapon_impact_shotgun.png       -> SHOTGUN
# weapon_impact_sniper.png        -> SNIPER, LASER
# weapon_impact_explosive.png     -> ROCKET, MISSILE, FLAK, RAIL_CANNON, OMEGA_CANNON

# 建议战场缩放：轻武器 0.08~0.12，炮弹/导弹 0.14~0.18
