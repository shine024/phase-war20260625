extends RefCounted
class_name WeaponProjectileVfx
## 武器弹道 / 命中贴图与缩放（玩家 Bullet 与敌方批处理共用）
## v6.0: 按武器名称查找专属贴图

const GC = preload("res://resources/game_constants.gd")
const WeaponVfxMapping: GDScript = preload("res://data/weapon_vfx_mapping.gd")
# v8.1: 命中特效委托给分层化工厂（冲击波环+主火花+碎片烟尘）
const VfxFactory = preload("res://scripts/battle/vfx_impact_factory.gd")

const TEX_DIR := "res://assets/effects/projectiles/weapons_realistic/"
## v8.4: 通用命中贴图兜底——仓库现有但此前零引用的通用爆炸贴图。
## 当武器 display_name 不在 WEAPON_ID_MAP（如"炮射导弹"/"萨姆-7防空导弹"/未来单位）时，
## fallback 到此贴图，保证所有重型爆炸武器的命中贴图层都能生效（而非回退纯粒子）。
const FALLBACK_IMPACT_TEX := preload(TEX_DIR + "weapon_artillery_impact.png")

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

# ── 命中特效粒子颜色配置 ──
# v8.4: IMPACT_COLOR_BY_WT 已废弃（与 VfxImpactFactory.COLOR_BY_WT 重复定义）。
# 命中粒子主色统一由 VfxImpactFactory._impact_color() 提供（含 combat_kind 二次调色）。
# IMPACT_TINT_BY_KIND / IMPACT_SHAKE_BY_KIND 仍保留（工厂未实现震动表，这里仍是真身）。

## v7.x: 按目标 combat_kind 的命中修饰（色调/震动强度）
## v8.0: 缩放倍率已废弃（粒子系统无 scale 概念），仅保留色调和震动
const IMPACT_TINT_BY_KIND: Dictionary = {
	0: Color(1.0, 0.95, 0.6),   # LIGHT 黄白火花
	2: Color(1.0, 0.95, 0.6),   # SUPPORT 归入 LIGHT
	1: Color(1.0, 0.55, 0.25),  # ARMOR 橙红金属碎屑
	4: Color(1.0, 0.55, 0.25),  # FORT 归入 ARMOR
	3: Color(1.0, 1.0, 1.0),    # AIR 保留原色（空爆贴图已足够）
}
## combat_kind → 屏幕震动 (幅度, 时长)。AIR 最强，ARMOR 中等，LIGHT 轻微
## v8.3 视觉增强：全面上调（LIGHT 1.8→3.0 / ARMOR 3.2→5.0 / AIR 5.0→7.0），让爆炸有分量感
const IMPACT_SHAKE_BY_KIND: Dictionary = {
	0: Vector2(3.0, 0.15),  # LIGHT
	2: Vector2(3.0, 0.15),  # SUPPORT
	1: Vector2(5.0, 0.25),  # ARMOR
	4: Vector2(5.0, 0.25),  # FORT
	3: Vector2(7.0, 0.35),  # AIR
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
# v8.3 视觉增强：0.05 → 0.10（×2），让贴图弹体在战场上清晰可见
const PROJ_DISPLAY_SCALE_MUL: float = 0.10


## ========== v6.0: 按武器名称查贴图 ==========

## v6.1 性能优化：武器名贴图静态缓存，避免每发子弹 ResourceLoader.exists() + load()
static var _proj_name_cache: Dictionary = {}
static var _impact_name_cache: Dictionary = {}
## v8.0 性能优化：命中特效从 Sprite2D+贴图 改为 CPUParticles2D（零贴图绑定、零 Sprite2D new/free）
## v8.1：命中特效委托 VfxImpactFactory 三层组合（冲击波环+主火花+碎片烟尘）
static var _impact_particles: Array = []  # 可复用 CPUParticles2D 池
static var _active_impacts: int = 0
const MAX_ACTIVE_IMPACTS: int = 200  # v8.1：128→200（视觉优先，三层特效共用池）

# ── 预建粒子色带缓存（CPUParticles2D 直接吃 Gradient，无需 Material） ──
# 注：v8.0 命中特效从 Sprite2D 改为 CPUParticles2D，原实现误用 ParticleProcessMaterial
# （那是 GPUParticles2D 的材质）赋给 process_material 属性（CPUParticles2D 不存在该属性），
# 导致 "Nonexistent property 'process_material'" 运行时崩溃。CPUParticles2D 的所有粒子
# 参数都是节点自身的直接属性，color_ramp 期望的是 Gradient 而非 GradientTexture1D。
static var _cached_impact_ramps: Dictionary = {}  # key(weapon_type+color) -> Gradient

static func _get_impact_ramp(weapon_type: int, base_color: Color) -> Gradient:
	var key := "%d_%02x%02x%02x" % [weapon_type, int(base_color.r*255), int(base_color.g*255), int(base_color.b*255)]
	if _cached_impact_ramps.has(key):
		return _cached_impact_ramps[key]
	var gradient := Gradient.new()
	gradient.add_point(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.add_point(0.3, base_color)
	gradient.add_point(1.0, Color(base_color.r, base_color.g, base_color.b, 0.0))
	_cached_impact_ramps[key] = gradient
	return gradient

## 从池中获取（或新建）CPUParticles2D
## 注：取用时必须从池中移除，否则同一粒子会被多次取用（释放时又 append 回池，
## 造成重复引用），且失效/已 free 的引用会残留在池中。原实现遍历返回但未 remove，
## 是 spawn_impact_with_kind 中 p 为 Nil 的根因。
static func _acquire_impact_particle() -> CPUParticles2D:
	# 从池尾向前取，命中即移除并返回；失效引用就地丢弃
	var i := _impact_particles.size() - 1
	while i >= 0:
		var candidate = _impact_particles[i]
		_impact_particles.remove_at(i)
		if candidate != null and is_instance_valid(candidate) and not candidate.is_queued_for_deletion():
			candidate.visible = true
			candidate.emitting = true
			candidate.restart()  # one_shot 模式下必须 restart 才能重新发射
			return candidate
		i -= 1
	# 池空或全是失效引用，新建
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.28
	p.amount = 18
	# CPUParticles2D 的发射参数都是节点直接属性（非材质）。取用时再按武器类型覆盖。
	p.gravity = Vector2(0, 0)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 2.0
	p.direction = Vector2(0, 0)
	p.spread = 360.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 120.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = Color(1.0, 0.95, 0.6, 1.0)  # 粒子主色（color_ramp 会在此基础上渐变）
	p.color_ramp = _get_impact_ramp(0, Color(0.95, 0.92, 0.5))
	# 加性混合让火花更亮（命中特效是发光火花）
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	p.emitting = true
	return p

## 归还粒子到池
static func _release_impact_particle(p: CPUParticles2D) -> void:
	if p == null or not is_instance_valid(p):
		_active_impacts -= 1
		return
	if p.is_inside_tree() and p.get_parent():
		p.get_parent().remove_child(p)
	p.emitting = false
	p.visible = false
	p.position = Vector2.ZERO
	_active_impacts -= 1
	if _impact_particles.size() < MAX_ACTIVE_IMPACTS:
		_impact_particles.append(p)
	else:
		p.queue_free()


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
	if not sid.is_empty():
		var path: String = TEX_DIR + sid + "_impact.png"
		if ResourceLoader.exists(path):
			var tex: Texture2D = load(path) as Texture2D
			_impact_name_cache[weapon_name] = tex
			return tex
	# v8.4: 无专属命中贴图（display_name 不在映射 / 映射了但贴图缺失）→ fallback 通用爆炸贴图
	# 保证所有重型爆炸武器的命中贴图层都能生效（炮射导弹/萨姆-7/毒刺/未来单位等）
	_impact_name_cache[weapon_name] = FALLBACK_IMPACT_TEX
	return FALLBACK_IMPACT_TEX


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


static func impact_scale(weapon_type: int) -> float:
	# v8.0: 命中特效已改为粒子系统，此函数仅保留兼容旧调用（如 CardGridFx）
	return float(IMPACT_TEX_SCALE.get(weapon_type, 0.11))


## ========== 命中特效生成（v8.0：CPUParticles2D，零贴图绑定）==========

static func spawn_impact(parent: Node2D, world_pos: Vector2, weapon_type: int, is_player_shot: bool) -> void:
	spawn_impact_with_kind(parent, world_pos, weapon_type, is_player_shot, -1)

## v7.x/v8.0: 带 combat_kind 的命中特效（粒子化）
## v8.1: 委托 VfxImpactFactory 三层组合特效（签名不变，所有调用方零改动）
## combat_kind = -1 时走原逻辑；>=0 时叠加 IMPACT_TINT_BY_KIND 色调
## opts（v8.1 新增，可选）：{"is_crit":bool, "is_pierce":bool, "direction":Vector2}
##        v8.4 新增可选："vfx_variant":String（武器类改造专属视觉标识）
## weapon_name（v8.4 新增，可选）：武器显示名，用于查命中贴图（仅重型爆炸武器 3/7/9 触发贴图层）
static func spawn_impact_with_kind(parent: Node2D, world_pos: Vector2, weapon_type: int, is_player_shot: bool, target_combat_kind: int = -1, opts: Dictionary = {}, weapon_name: String = "") -> void:
	if parent == null:
		return
	# v8.4: 重型爆炸武器（ROCKET=3/FLAK=7/MISSILE=9）——有专属命中贴图时叠加贴图层
	# 仅这三类触发贴图查找（符合"仅重型爆炸武器"决策），轻武器直接走粒子省查表
	if weapon_name != "" and weapon_type in [3, 7, 9]:
		var impact_tex: Texture2D = impact_texture_by_name(weapon_name)
		if impact_tex != null:
			var peak_scale: float = impact_scale_by_name(weapon_name) * 2.0  # 贴图爆炸放大显示
			VfxFactory.spawn_impact_sprite(parent, world_pos, impact_tex, peak_scale, 0.45)
	# v8.1: 委托 VfxImpactFactory 三层组合特效（粒子层，与贴图层叠加）
	# 注：SMG(0)/PISTOL(4) 的跳过守卫仍在 bullet._spawn_tex_impact_at 维护；
	# batch 路径（轻武器密集命中）不跳过——工厂配方表对轻武器用小快特效，命中反馈必要。
	VfxFactory.spawn_layered_impact(parent, world_pos, weapon_type, is_player_shot, target_combat_kind, opts)
	# v8.4: 武器类改造专属视觉——在基础特效之上叠加变体独有特征
	var _variant: String = String(opts.get("vfx_variant", ""))
	if not _variant.is_empty():
		VfxFactory.spawn_variant_overlay(parent, world_pos, weapon_type, _variant, is_player_shot)

## v7.x: 按 combat_kind 返回屏幕震动参数 (幅度, 时长)，无匹配返回 Vector2.ZERO
static func impact_shake_for_kind(target_combat_kind: int) -> Vector2:
	if target_combat_kind >= 0 and IMPACT_SHAKE_BY_KIND.has(target_combat_kind):
		return IMPACT_SHAKE_BY_KIND[target_combat_kind]
	return Vector2.ZERO
