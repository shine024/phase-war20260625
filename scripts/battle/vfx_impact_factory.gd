extends RefCounted
class_name VfxImpactFactory
## 命中特效分层化工厂（v8.1）
## 把原 spawn_impact_with_kind 的单一径向火花升级为三层组合特效：
##   第1层 冲击波环（Polygon2D 扩散淡出）
##   第2层 主火花（CPUParticles2D，按武器配方表差异化）
##   第3层 碎片/烟尘（重型武器专属，第二组粒子）
## 另提供特殊伤害专用特效：暴击光环 / 穿透光线 / 溅射冲击波 / 闪电链电弧
##
## 所有特效走对象池（参考 weapon_projectile_vfx 的 one_shot + SceneTreeTimer 回收模式）。
## 可访问性：DT.is_motion_reduce() 时只保留第2层主火花（减层）。

const DT = preload("res://resources/design_tokens.gd")
const GC = preload("res://resources/game_constants.gd")  # v13: 时代化能量配色(era→关卡)
const DirectWeaponFlavor = preload("res://data/direct_weapon_flavor.gd")
## v9.2: 粒子贴图——CPUParticles2D 赋 texture 告别方形小方块。
## 按武器类型分流：动能武器（金属火花/灰烟）vs 能量武器（蓝色电弧/蓝烟）。
## 池复用继续（性能优先），texture 在 spawn 时按 weapon_type 重新赋值。
## 生成工作流：docs/VFX特效纹理生成工作流.md。
const PARTICLE_TEX_SPARK_METAL := preload("res://assets/effects/particle_textures/spark_metal.png")     # 动能火花（黄橙短条，DIRECT/PISTOL/SMG/MG/RIFLE/SHOTGUN/SNIPER）
const PARTICLE_TEX_SPARK_ENERGY := preload("res://assets/effects/particle_textures/spark_energy.png")   # 能量火花（蓝白电弧，OMEGA/RAIL/LASER）
const PARTICLE_TEX_SPARK_HEAVY  := preload("res://assets/effects/particle_textures/spark_heavy.png")    # 重型碎片（不规则金属块，ROCKET/FLAK/MISSILE）
const PARTICLE_TEX_SMOKE_GENERIC := preload("res://assets/effects/particle_textures/smoke_generic.png") # 常规烟尘（灰棕团，ROCKET/FLAK/MISSILE）
const PARTICLE_TEX_SMOKE_ENERGY  := preload("res://assets/effects/particle_textures/smoke_energy.png")   # 能量烟（蓝灰团，OMEGA/RAIL/LASER）
const PARTICLE_TEX_MUZZLE_HEAVY  := preload("res://assets/effects/particle_textures/muzzle_heavy.png")  # 重型枪口火（橙红爆发，ROCKET/FLAK/MISSILE）
## v17e 锐利贴图组（tools/generate_sharp_vfx_textures.py 程序化生成，硬边）——
## 替换软圆斑根因：旧贴图 128px 被当 32px 标定 → 全系统粒子超尺寸 2-4 倍。
## 当前使用：muzzle_jet_sym（轻武器枪口，白核居中+两侧橙尾）、flame_star（重型枪口放射火舌）、
## spark_streak（动能命中火花+拖尾，白热头+橙尾指向+X）。
## 注：shard_metal_v1/v2/v3 已弃用（用户反馈棱角多边形不如软圆块 SPARK_HEAVY，纹理文件保留但不再 preload）。
const PARTICLE_TEX_MUZZLE_JET    := preload("res://assets/effects/particle_textures/muzzle_jet_sym.png")     # 轻武器枪口前向喷流（白核居中+两侧橙尾，朝向无关）
const PARTICLE_TEX_FLAME_STAR    := preload("res://assets/effects/particle_textures/flame_star.png")     # 重型枪口火焰（8放射火舌，已被 flame_jet_sym 替代，保留兼容）
## v18-R5: 重型枪口水平火舌（对称，±X）——flame_star 的 8 臂放射星被 AI 读成
## "径向爆散/无方向扩散的火花炸散"（火箭/导弹枪口 2-4 分主诉）。粒子不随速度旋转
## + spawn_impact_sprite 随机旋转 → 必须对称（muzzle_jet_sym 同范式）。内容实宽 149px。
const PARTICLE_TEX_FLAME_JET    := preload("res://assets/effects/particle_textures/flame_jet_sym.png")
## v18-R9 摄影感贴图组（tools/generate_realistic_vfx_textures.py：黑体色序+值噪声边缘+簇状结构）。
## 用户感知否决"火星/火花/火焰/金属碎片假"——病根是纯几何楔形/锥形边缘太规则、色温线性。
## 新贴图三要素：白热→亮黄→橙→暗红非线性黑体序；噪声扰动边缘；多元素簇状。
const PARTICLE_TEX_SPARK_DROP   := preload("res://assets/effects/particle_textures/spark_drop.png")    # 簇状熔融金属滴（内容73×78）
const PARTICLE_TEX_METAL_CHUNK  := preload("res://assets/effects/particle_textures/metal_chunk.png")   # 暗金属碎块簇+炽热边（内容79×68）
const PARTICLE_TEX_FLAME_PUFF   := preload("res://assets/effects/particle_textures/flame_puff.png")    # 火焰团（内容150×96）
const PARTICLE_TEX_FLAME_JET_V2 := preload("res://assets/effects/particle_textures/flame_jet_v2.png")  # 方向性火舌 v2（内容160×45）
const PARTICLE_TEX_SPARK_STREAK  := preload("res://assets/effects/particle_textures/spark_streak.png")   # 火花拖痕（白热头+橙尾，指向+X）
const PARTICLE_TEX_MUZZLE_ENERGY := preload("res://assets/effects/projectiles/weapons_realistic/weapon_artillery_muzzle.png")  # 能量枪口火（白青喷射流）
const PARTICLE_TEX_MUZZLE_LIGHT  := preload("res://assets/effects/particle_textures/muzzle_light.png")  # 轻型枪口火（橙点，DIRECT/PISTOL/RIFLE）
const PARTICLE_TEX_EMBER         := preload("res://assets/effects/particle_textures/spark_ember.png")    # 火星点缀（橙色小点）
## v9.2: 放射状命中贴图——区别于拖尾的顺向条纹，命中用放射爆点（"飞行"vs"撞击"形状可分）
const PARTICLE_TEX_IMPACT_METAL  := preload("res://assets/effects/particle_textures/impact_metal.png")   # 动能命中放射火花
const PARTICLE_TEX_IMPACT_ENERGY := preload("res://assets/effects/particle_textures/impact_energy.png") # 能量命中放射爆裂
const PARTICLE_TEX_IMPACT_SCORCH := preload("res://assets/effects/particle_textures/impact_scorch.png")  # v11 弹痕锚点(暗凹陷+刮擦线,持久贴命中点)

# ── 池化上限 ──
const MAX_RINGS: int = 80
const MAX_DEBRIS: int = 140  # v10: smoke_puff/shrapnel 层复用 debris 池
const MAX_SPARKS: int = 320  # v10: flash 层复用 spark 池
# v7.4 性能优化：ring 顶点预分配。原 _configure_ring_polygon 每帧 new PackedVector2Array + 48 append，
# 80 ring 激活时每帧 80×48 分配。改为每 ring 绑定预分配 buffer，每帧只原地改坐标（零堆分配）。
const _RING_SEGS: int = 24       # 圆环段数（外圈+内圈交错 = 48 顶点）
const _RING_VERTS: int = 48      # _RING_SEGS * 2

# ── 对象池 ──
static var _ring_pool: Array = []       # 可复用 Polygon2D（冲击波环）
static var _debris_pool: Array = []     # 可复用 CPUParticles2D（碎片/烟尘）
static var _spark_pool: Array = []      # 可复用 CPUParticles2D（主火花）
static var _active_rings: int = 0
static var _active_debris: int = 0
static var _active_sparks: int = 0

# v7.4: ring 顶点 buffer 缓存——ring(Polygon2D) -> Dictionary{_unit, _scratch}
# _unit: 预计算的单位圆坐标（半径=1，48 点），acquire 时算一次
# _scratch: 工作数组，每帧 = _unit × radius 原地缩放（零分配）
static var _ring_buffers: Dictionary = {}

# v7.4: Line2D 特效池（穿透光线/闪电链/激光余晖共用）。原每次 new Line2D + queue_free
static var _beam_pool: Array = []
static var _active_beams: int = 0
const MAX_BEAMS: int = 60

# v8.4: 命中贴图 Sprite 池（重型爆炸武器的 *_impact.png 渲染）。原 v8.0 移除贴图改纯粒子，
# 现重接贴图让爆炸有"形状感"——仅 weapon_projectile_vfx 在有 impact_texture 时调用。
static var _impact_sprite_pool: Array = []
static var _active_impact_sprites: int = 0
const MAX_IMPACT_SPRITES: int = 160  # v9.2: 80→160（双层贴图：光晕+主体，每次爆炸/开火用 2 个）

# v9.x: 组合技指示器池（weakpoint_expose / radar_lock / laser_resonance）。
# 原每次 new Node2D/Polygon2D + queue_free，违背文件"所有特效走对象池"原则。
# resonance 每次命中触发（高频）、radar 周期性 tick、持续 5-6s，密集战斗累积节点。
# 池按 kind 分组（weakpoint=Node2D+2Line2D子 / radar_lock=Polygon2D / resonance=Polygon2D）。
# 每个指示器有 2 个 tween（脉动 loops + 延迟淡出），release 时通过 _vfx_tweens meta 全部 kill。
static var _indicator_pool: Dictionary = {}  # kind -> Array[Node]
static var _active_indicators: int = 0
const MAX_INDICATORS: int = 40  # weakpoint 3s / radar 6s / resonance 5s，并发量可控
const _INDICATOR_KINDS: Array = ["weakpoint", "radar_lock", "resonance"]

# ── ADD 混合材质缓存 ──
static var _add_mat: CanvasItemMaterial = null

# ── v13.1: 攻击方阵营色——命中环/攻击追踪线的阵营辨识（一眼看出"谁在打谁"）──
const SIDE_COLOR_PLAYER := Color(0.35, 0.85, 1.0, 0.9)   # 我方攻击 = 青蓝
const SIDE_COLOR_ENEMY := Color(1.0, 0.45, 0.25, 0.9)    # 敌方攻击 = 橙红

static func side_color(is_player: bool) -> Color:
	return SIDE_COLOR_PLAYER if is_player else SIDE_COLOR_ENEMY


## v18 四源重构·元素伤害维度：元素亲和配色（火橙红/雷蓝白/虚紫）
## 用于 spawn_layered_impact 的 opts.element_affinity 着色与 UI 查询
const ELEMENT_COLORS: Dictionary = {
	1: Color(1.0, 0.45, 0.15, 1.0),  # 火 FIRE
	2: Color(0.55, 0.75, 1.0, 1.0),  # 雷 LIGHTNING
	3: Color(0.75, 0.40, 1.0, 1.0),  # 虚 VOID
}


static func element_color(affinity: int) -> Color:
	return ELEMENT_COLORS.get(affinity, Color.WHITE)

# ── v9.2: 烟柱 Gradient 按颜色缓存（spawn_smoke_column 频繁调用）──
static var _smoke_grad_cache: Dictionary = {}

## ======================================================================
## 主入口：分层化命中特效
## ======================================================================
## opts 可选字段：
##   "is_crit": bool     — 暴击（叠加金色脉动光环）
##   "is_pierce": bool   — 穿透（叠加紫色穿甲光线，需配合 direction）
##   "direction": Vector2 — 穿透光线方向（默认向右）
##   "element_affinity": int — v18 元素亲和（0无/1火/2雷/3虚），≠0 时基色向元素色 lerp 45%
## [param p_weapon_name] 武器名（v8.x：直射系亚类分流用，区分机枪/步枪/坦克炮等）
static func spawn_layered_impact(parent: Node2D, world_pos: Vector2, weapon_type: int, is_player: bool, combat_kind: int = -1, opts: Dictionary = {}, p_weapon_name: String = "") -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var motion_reduce: bool = DT.is_motion_reduce()
	# 基色（复用 WeaponProjectileVfx 的配色逻辑）
	var base_color: Color = _impact_color(weapon_type, combat_kind, is_player)
	# v18 元素伤害维度：带元素亲和的攻击方，命中基色混入元素色（45%，保留武器辨识度，
	# 与 v13.1 阵营环色 55% 同款思路）。affinity=0（默认）时配色与改动前逐字节一致。
	var elem_aff: int = int(opts.get("element_affinity", 0))
	if elem_aff != 0 and ELEMENT_COLORS.has(elem_aff):
		base_color = base_color.lerp(ELEMENT_COLORS[elem_aff], 0.45)
	# 配方（v8.x：传 weapon_name 做直射系亚类细分）
	var recipe: Dictionary = _impact_recipe(weapon_type, p_weapon_name)
	# v9.4: power_tier 威力分级缩放——HEAVY 档放大粒子层（环半径/火花数/尺寸 ×1.4），
	# LIGHT/MEDIUM ×1.0 不变。配方表本身不动（保持 weapon_type+flavor 分级），tier 只做倍率叠加。
	recipe = _apply_tier_scale(recipe, opts)
	# v18: 轻武器（wt 0/4）命中减层标记——v17 审计 3 分格"规模严重超标/火球帧"的病根是
	# v10 真实度层无条件叠加：flash 放射贴图(115px 内容×2.4-4.4=276-506px) + 烟团(128×1.25-2.25
	# =160-288px) + 破片(128×0.5-1.1=64-141px) 全压在轻武器命中上，亮核 119px 读成"小火球"。
	# 族规格明令："放射状黄白小火花+微量烟，无火球帧"——轻武器只留 火花+快环+弹痕+微烟。
	var is_light_kinetic: bool = weapon_type in [0, 4]
	# 第1层：冲击波环（motion_reduce 时跳过）
	# v13.1: 环色混入攻击方阵营色（55%）——密集交火时一眼分辨"这团爆炸是谁打的"。
	# 火花/碎片层保持武器本色（武器辨识优先），阵营信息只承载在环上不喧宾夺主。
	if not motion_reduce:
		var ring_color: Color = base_color.lerp(side_color(is_player), 0.55)
		_spawn_ring(parent, world_pos, recipe.get("ring_r", 24.0), recipe.get("ring_dur", 0.2), ring_color)
		# v17k: 第二慢环（快环收束动量 + 慢环拉开扩散层次）——boss 轮 v17j 同款模式，
		# AI 高频批"冲击波单层无落差"。慢环半径 ×1.4、alpha 减半、时长 +60%。
		# v18: 轻武器跳过（36→50px 双环在小命中上占满视野，"规模超标"共犯）。
		if not is_light_kinetic:
			_spawn_ring(parent, world_pos, float(recipe.get("ring_r", 24.0)) * 1.4,
				float(recipe.get("ring_dur", 0.2)) * 1.6, Color(ring_color.r, ring_color.g, ring_color.b, ring_color.a * 0.5))
		_spawn_impact_decal(parent, world_pos, weapon_type)  # v11 弹痕锚点(在火花之下,火花从弹痕溅起)
	# 第2层：主火花（始终生成）
	# v20.9-R2: 霰弹(5)散射签名——单点火花+中央大闪光读成"单弹头命中"（AI 双侧一致
	# 批"缺散射图案/规则饱满白色光斑"）。改 6 弹丸簇沿来向垂直轴扇开（6 发 18° 散射
	# 的着面投影），火花总量不变；flash 层对霰弹跳过（"单点爆光"病根）。
	var is_shotgun: bool = weapon_type == 5
	if is_shotgun:
		_spawn_shotgun_scatter(parent, world_pos, recipe, base_color, opts)
	else:
		_spawn_sparks(parent, world_pos, recipe, base_color, weapon_type)
	# 第3层：碎片/烟尘（重型武器，motion_reduce 时跳过）
	if not motion_reduce and recipe.has("debris"):
		_spawn_debris(parent, world_pos, recipe["debris"], base_color, weapon_type)
	# v10 真实度层（报告建议）：瞬时闪光 / 轻烟团 / 金属破片。按武器族驱动，motion_reduce 时全跳过。
	# 已有 debris（重型烟尘）的不重复加 smoke_puff，避免双烟。
	# v18: 轻武器(0/4)跳过 flash+破片（火球帧两主犯），烟团缩到"微量烟"档
	#   （128px 贴图×0.25-0.5=32-64px 微烟，3 粒，0.45s 快散）。
	if not motion_reduce:
		if not is_light_kinetic:
			if not is_shotgun:
				_spawn_flash_layer(parent, world_pos, base_color, weapon_type, {})
			if not recipe.has("debris"):
				_spawn_smoke_puff_layer(parent, world_pos, base_color, weapon_type, {})
			_spawn_shrapnel_layer(parent, world_pos, base_color, weapon_type, {})
		elif not recipe.has("debris"):
			# v18-R9b: 微烟 3→5 粒（R9 后 AI 批"烟雾层完全缺失"——3 粒在簇滴命中里
			# 读不出）。smin/smax 经 DSCALE 0.5 × 128px 贴图 → 51-90px 软散烟仍"微量"档。
			_spawn_smoke_puff_layer(parent, world_pos, base_color, weapon_type,
				{"amount": 5, "life": 0.45, "smin": 0.8, "smax": 1.4})
	# v13: 战场痕迹——重型爆炸武器命中留下焦痕弹坑(概率 50%,免刷屏;幂次越小越稀)
	if not motion_reduce and (weapon_type in [1, 2, 3, 7, 9] or int(opts.get("power_tier", -1)) == 2):
		if randf() < 0.5:
			var tr_r: float = clampf(float(recipe.get("ring_r", 24.0)) * 0.5, 8.0, 18.0)
			spawn_battle_trace(parent, world_pos, tr_r, "scorch")
	# 特殊伤害叠加
	if opts.get("is_crit", false) and not motion_reduce:
		spawn_crit_aura(parent, world_pos)
	if opts.get("is_pierce", false) and not motion_reduce:
		var dir: Variant = opts.get("direction", Vector2.RIGHT)
		# v9.4: piercing_shot 技能穿透走 enhanced 加宽加长版（opts 透传标记）
		var enhanced: bool = bool(opts.get("pierce_enhanced", false))
		spawn_pierce_beam(parent, world_pos, dir if dir is Vector2 else Vector2.RIGHT, Color(0.85, 0.55, 1.0, 1.0), enhanced)


## v9.4: 按 power_tier 缩放命中配方参数（让重型武器命中粒子更猛烈）。
## HEAVY(2) 档：ring_r/spark_amount/spark 尺寸 ×1.4；LIGHT(0)/MEDIUM(1) ×1.0 不变。
## 用字面量 tier 值（0/1/2/3）避免对 WeaponProjectileVfx 的循环依赖。
## 返回缩放后的 recipe 副本（原配方表不被污染）。
static func _apply_tier_scale(recipe: Dictionary, opts: Dictionary) -> Dictionary:
	var tier: int = int(opts.get("power_tier", -1))
	if tier != 2:  # 仅 HEAVY(2) 缩放；其他档（含缺省 -1/0/1）不缩放，向后兼容
		return recipe
	const SCALE := 0.85  # v17e-R2: 1.4→1.2，火箭爆炸 HEAVY 档过大（f03 ~110px > 参考框 64px），降低到 1.2 更克制
	var r: Dictionary = recipe.duplicate(true)
	r["ring_r"] = float(r.get("ring_r", 24.0)) * SCALE
	r["spark_amount"] = int(round(float(r.get("spark_amount", 16)) * SCALE))
	r["spark_smin"] = float(r.get("spark_smin", 2.0)) * SCALE
	r["spark_smax"] = float(r.get("spark_smax", 3.0)) * SCALE
	# 碎片层（如有）也放大粒子数
	if r.has("debris"):
		var d: Dictionary = r["debris"]
		d["amount"] = int(round(float(d.get("amount", 16)) * SCALE))
	return r


## v20.9-R2: 霰弹(5)命中散射签名——族规格"散射状小贴图+宽散火花"。
## 6 弹丸簇沿来向垂直轴 ±26px 扇开（对应 6 发 18° 散射的着面投影），每簇 1/6
## 火花量、0.6 倍尺寸、0.20s 快闪——火花总量与单点方案持平（无性能差），图案从
## "单弹头爆点"变"弹群散布"。方向取 opts.direction（bullet v12d 起恒传真实来向；
## 审计格缺省 RIGHT → 垂直扇面，确定性可复拍）。历史教训：v19-R28 多簇实验伤及
## f08 是共享路径未门控；本函数仅 wt==5 调用，其他族零影响。
static func _spawn_shotgun_scatter(parent: Node2D, world_pos: Vector2, recipe: Dictionary, base_color: Color, opts: Dictionary) -> void:
	var dir_v: Variant = opts.get("direction", Vector2.RIGHT)
	var dir: Vector2 = dir_v if dir_v is Vector2 and (dir_v as Vector2).length_squared() > 0.001 else Vector2.RIGHT
	var perp := Vector2(-dir.y, dir.x)
	var sub: Dictionary = recipe.duplicate()
	sub["spark_amount"] = maxi(4, int(recipe.get("spark_amount", 46)) / 6)
	sub["spark_smin"] = float(recipe.get("spark_smin", 0.5)) * 0.75
	sub["spark_smax"] = float(recipe.get("spark_smax", 1.0)) * 0.75
	sub["spark_life"] = 0.20
	# v20.9-R2b: 散射几何标定——簇跨度 ±36px（76px 全宽 ≈ 64px 参考框，"宽散火花"规格）；
	# 簇内降速 350-650→200-420（快火花把几何 smear 成随机团，慢火花让扇面保持可读）。
	sub["spark_vmin"] = 200.0
	sub["spark_vmax"] = 420.0
	for i in range(6):
		var t: float = (float(i) / 5.0) * 2.0 - 1.0  # -1..1 均布 6 簇
		var offset := perp * (t * 36.0) + dir * randf_range(-6.0, 6.0)
		_spawn_sparks(parent, world_pos + offset, sub, base_color, 5)
		# v20.9-R2c: 弹着小贴图（族规格"散射状小贴图"字面项）——隔簇投放控量
		# （游戏内 6 弹丸各带一套散射，逐簇全投会 ×6 放大成 36 枚/齐射）
		if i % 2 == 0 and not DT.is_motion_reduce():
			_spawn_pellet_mark(parent, world_pos + offset)


## v20.9-R2c: 霰弹弹着点小贴图——复用 scorch 贴图 0.35 缩放（约 22px 着点痕），
## 与中央主弹痕（_spawn_impact_decal 0.6）拉开大小层次。寿命同主弹痕（0.35s 保持 + 0.30s 渐隐）。
static func _spawn_pellet_mark(parent: Node2D, pos: Vector2) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var decal := Sprite2D.new()
	decal.texture = PARTICLE_TEX_IMPACT_SCORCH
	decal.position = pos
	decal.scale = Vector2(0.35, 0.35)
	decal.rotation = randf() * TAU
	decal.modulate = Color(1.0, 1.0, 1.0, 0.92)
	decal.add_to_group("battle_vfx")
	parent.add_child(decal)
	var tree := decal.get_tree()
	if tree != null:
		var tw := tree.create_tween().bind_node(decal)
		tw.tween_interval(0.35)
		tw.tween_property(decal, "modulate:a", 0.0, 0.30)
		tw.tween_callback(decal.queue_free)


## ======================================================================
## 特殊伤害专用特效
## ======================================================================

## 暴击金色脉动光环（v8.2：加长到可清晰感知）
static func spawn_crit_aura(parent: Node2D, world_pos: Vector2) -> void:
	# v17e: 侧视椭圆冲击波（aspect_ratio=1.6）
	# 第一层：快速扩张大光环
	var ring1 := _acquire_ring()
	if ring1 == null:
		return
	ring1.position = world_pos
	_configure_ring_polygon(ring1, 8.0, Color(1.0, 0.88, 0.35, 1.0), 2.0)  # 亮金椭圆
	parent.add_child(ring1)
	var target_r: float = 46.0
	var tween1 := ring1.create_tween()
	tween1.tween_method(func(r: float): _configure_ring_polygon(ring1, r, Color(1.0, 0.88, 0.35, 1.0 * (1.0 - r / target_r)), 2.0), 8.0, target_r, 0.45)
	tween1.tween_callback(func(): _release_ring(ring1))
	# 第二层：延迟0.08s的二次脉冲（让暴击有"连击"的层次感）
	var ring2 := _acquire_ring()
	if ring2 == null:
		return
	ring2.position = world_pos
	_configure_ring_polygon(ring2, 6.0, Color(1.0, 0.7, 0.2, 0.7), 2.0)
	parent.add_child(ring2)
	var tween2 := ring2.create_tween()
	tween2.tween_interval(0.08)
	tween2.tween_method(func(r: float): _configure_ring_polygon(ring2, r, Color(1.0, 0.7, 0.2, 0.7 * (1.0 - r / 34.0)), 2.0), 6.0, 34.0, 0.40)
	tween2.tween_callback(func(): _release_ring(ring2))


## v7.4: 暴击辐射火花（复用 spark 池，替代 damage_number_display 每次 new CPUParticles2D+Gradient）。
## 参数对齐原 damage_number_display._spawn_crit_sparks 的配置。
static func spawn_crit_sparks(parent: Node2D, world_pos: Vector2, is_full_crit: bool) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	if _active_sparks >= MAX_SPARKS:
		return
	_active_sparks += 1
	var p := _acquire_spark_particle()
	if p == null:
		_active_sparks -= 1
		return
	# v9.2: 暴击火花用熔滴簇贴图（池复用需显式赋值，否则继承上次的 texture）
	p.texture = PARTICLE_TEX_SPARK_DROP
	var intensity: float = 0.8 if is_full_crit else 0.5
	p.position = world_pos
	p.lifetime = 0.40
	p.amount = int(intensity * 14)
	p.emission_sphere_radius = 1.5
	p.direction = Vector2(0, 0)
	p.spread = 360.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 60.0
	# v9.2: 暴击火花贴图化缩小（原 0.6-1.2 → 0.3-0.5）
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.5
	# 金色渐变（暴击配色）；固定 Gradient 可考虑缓存，但暴击频率远低于普通命中，暂不复用 _spark_ramp_cache
	var ramp := _get_crit_ramp()
	p.color_ramp = ramp
	parent.add_child(p)
	var tree := p.get_tree()
	if tree != null:
		var timer := tree.create_timer(p.lifetime + 0.1)
		_connect_deferred_release(timer, p, _release_spark_particle)


## v8.x: 单位受击血溅（复用 debris 池）。替代 v7.4 受击"整体变色虚化"——单位保持卡图清晰，
## 打击感外化到命中点：暗红血溅（沿弹道反向飞溅+重力下落）+ 叠加少量金色火花（BLEND_ADD 一闪）。
## direction：弹道反方向（attacker→unit 反向），强度越大粒子越多越远。
static var _spark_blood_ramp: Gradient = null
static func spawn_hit_blood(parent: Node2D, world_pos: Vector2, direction: Vector2, strength: float, is_player: bool) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	if DT.is_motion_reduce():
		return
	# 第1层：暗红血溅（debris 池，重力下落）
	if _active_debris < MAX_DEBRIS:
		_active_debris += 1
		var p := _acquire_debris_particle()
		if p == null:
			_active_debris -= 1
		else:
			# v9.2: 血溅用常规烟尘贴图（池复用需显式赋值，否则继承上次的 texture）
			p.texture = PARTICLE_TEX_SMOKE_GENERIC
			# 我方/敌方血色微差（我方亮红、敌方暗红），均不饱和以免糊图
			var d: Vector2 = direction.normalized() if direction.length() > 0.01 else Vector2.ZERO
			p.position = world_pos
			p.lifetime = 0.42
			# 强度 → 数量（直射 strength=3→8 粒子；爆炸 6→14；暴击 10→20）
			var n: int = int(clamp(strength * 2.5, 6.0, 20.0))
			p.amount = n
			p.emission_sphere_radius = 3.0
			p.direction = d
			p.spread = 70.0
			p.initial_velocity_min = 60.0
			p.initial_velocity_max = 150.0
			p.gravity = Vector2(0, 220.0)
			# v9.2: 血溅贴图化缩小（原 1.6-3.0 → 0.6-1.2）
			p.scale_amount_min = 0.6
			p.scale_amount_max = 1.2
			p.color_ramp = _get_blood_ramp(is_player)
			# 注：debris 池默认带 ADD material（_acquire_debris_particle 新建时设）。
			# 不在此覆盖 material=null——会污染池（复用时其他 debris 特效失去 ADD）。
			# 血溅走 ADD 偏亮（暗红→粉红血雾高光），与火花层视觉协调，且零池污染风险。
			parent.add_child(p)
			var tree := p.get_tree()
			if tree != null:
				var timer := tree.create_timer(p.lifetime + 0.1)
				_connect_deferred_release(timer, p, _release_debris_particle)
	# 第2层：金色火花（spark 池，ADD 一闪即逝）—— 承担"打击感高光"
	if _active_sparks < MAX_SPARKS:
		_active_sparks += 1
		var sp := _acquire_spark_particle()
		if sp == null:
			_active_sparks -= 1
		else:
			# v9.2/v9.4: 血溅金色火花——v9.4 改用圆点亮斑（MUZZLE_LIGHT 橙点），弃用长条 SPARK_METAL
			# （长条贴图 + 高速会拉成长条火星，FORT 持续承伤时脚下堆积成杂乱长条带）。
			# 同时降低速度（200→110）避免圆点也被拉长，保持"一闪即逝高光"语义。
			sp.texture = PARTICLE_TEX_MUZZLE_LIGHT
			var d: Vector2 = direction.normalized() if direction.length() > 0.01 else Vector2.ZERO
			sp.position = world_pos
			sp.lifetime = 0.16
			sp.amount = int(clamp(strength * 1.2, 4.0, 12.0))
			sp.emission_sphere_radius = 2.0
			sp.direction = d
			sp.spread = 90.0
			sp.initial_velocity_min = 50.0
			sp.initial_velocity_max = 110.0
			sp.gravity = Vector2(0, 0)
			# v9.2: 血溅金色火花贴图化缩小
			sp.scale_amount_min = 0.4
			sp.scale_amount_max = 0.7
			sp.color_ramp = _get_blood_spark_ramp()
			parent.add_child(sp)
			var tree2 := sp.get_tree()
			if tree2 != null:
				var timer2 := tree2.create_timer(sp.lifetime + 0.1)
				_connect_deferred_release(timer2, sp, _release_spark_particle)


## 单位死亡反馈：阵营色冲击波 + 碎片/血雾爆散（复用 debris 池，0.45s 重力下落）。
## 在单位 _play_death_fadeout 开头调用一次，让"死亡"与"受击"产生明确的视觉差。
## 走对象池 + motion_reduce 短路，零额外 GC。
static func spawn_death_burst(parent: Node2D, world_pos: Vector2, is_player: bool) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	if DT.is_motion_reduce():
		return
	# 阵营色：我方青蓝、敌方暗红（与 hit_blood 配色一致，避免饱和糊图）
	var faction_c: Color = Color(0.35, 0.7, 1.0, 0.85) if is_player else Color(0.9, 0.35, 0.2, 0.85)
	# v13: 残骸印记——阵亡位置留暗痕,战场"打过的痕迹"能累积
	spawn_battle_trace(parent, world_pos, 12.0 + randf() * 6.0, "wreck")
	# 第1层：阵营色小冲击波（半径 8→32，0.38s 扩散淡出）
	spawn_shockwave(parent, world_pos, 32.0, faction_c)
	# 第2层：碎片/血雾爆散（debris 池，向上+四周迸射后重力下落）
	if _active_debris < MAX_DEBRIS:
		_active_debris += 1
		var p := _acquire_debris_particle()
		if p == null:
			_active_debris -= 1
		else:
			# v9.2: 死亡爆散用常规烟尘贴图（池复用需显式赋值）
			p.texture = PARTICLE_TEX_SMOKE_GENERIC
			p.position = world_pos
			p.lifetime = 0.45
			p.amount = 10  # 克制：10 粒碎片，足够形成"散开"感而不撞池上限
			p.emission_sphere_radius = 4.0
			p.direction = Vector2(0, -1)  # 略微向上的爆散方向
			p.spread = 110.0
			p.initial_velocity_min = 80.0
			p.initial_velocity_max = 180.0
			p.gravity = Vector2(0, 240.0)
			# v9.2: 死亡爆散贴图化缩小
			p.scale_amount_min = 0.7
			p.scale_amount_max = 1.3
			p.color_ramp = _get_blood_ramp(is_player)
			parent.add_child(p)
			var tree := p.get_tree()
			if tree != null:
				var timer := tree.create_timer(p.lifetime + 0.1)
				_connect_deferred_release(timer, p, _release_debris_particle)


## v8.x: 血溅 Gradient 缓存（敌我各一份，alpha 1.0→0.0 渐隐）
static var _blood_ramp_player: Gradient = null
static var _blood_ramp_enemy: Gradient = null
static func _get_blood_ramp(is_player: bool) -> Gradient:
	var target := _blood_ramp_player if is_player else _blood_ramp_enemy
	if target != null:
		return target
	var base_c: Color = Color(0.82, 0.18, 0.12) if is_player else Color(0.62, 0.10, 0.07)
	var g := Gradient.new()
	g.add_point(0, Color(base_c.r, base_c.g, base_c.b, 1.0))
	g.add_point(1.0, Color(base_c.r, base_c.g, base_c.b, 0.0))
	if is_player:
		_blood_ramp_player = g
	else:
		_blood_ramp_enemy = g
	return g


static func _get_blood_spark_ramp() -> Gradient:
	if _spark_blood_ramp == null:
		_spark_blood_ramp = Gradient.new()
		_spark_blood_ramp.add_point(0, Color(1.0, 0.85, 0.4, 1.0))
		_spark_blood_ramp.add_point(1.0, Color(1.0, 0.55, 0.15, 0.0))
	return _spark_blood_ramp


## v9.6 枪口火轻重分派域——全 VFX 层统一"新枚举优先"约定（与 WeaponProjectileVfx.proj_texture 一致）：
## 碰撞值 1/2 恒按新枚举 INDIRECT/AERIAL 解释（曲射火炮/空射=重型窄锥喷射），
## legacy RIFLE(1)/MG(2) 在 VFX 层已让位（proj_texture 同样不达，本处与其对齐）。
## 重型域 = 新枚举 INDIRECT(1)/AERIAL(2)/SUPPORT(3，与 legacy ROCKET(3) 撞值，均取重型) +
##          legacy ROCKET(3)/LASER(8)/FLAK(7)/MISSILE(9)/OMEGA(10)/RAIL(11)。
## 审计编号 V8：原分支只认 legacy 域，新枚举主链路上曲射火炮(INDIRECT=1)拿的是轻枪口火。
## v17 修复：LASER(8) 此前漏在重型域外（energy 集 [6,8,10,11] 中 8 因先判 light 不可达）——
## 激光命中走签名灼烧特效而枪口是"橙点轻型火"，开火与命中形态割裂。补入后激光枪口=白青喷射流。
## 注：SNIPER(6) 保持轻型（族内多为动能狙击枪，非能量武器）。
const HEAVY_MUZZLE_WT: Array = [1, 2, 3, 7, 8, 9, 10, 11]

## v16: legacy 轻武器域归一——调用方持有的 wt 若是 legacy 值（敌方 archetype/直射 batch 的
## BATCH_FIRE_WEAPON_TYPES=[0,4,1,2]），其中 1/2 是 RIFLE/MG，会被上面"新枚举优先"约定
## 读成 INDIRECT/AERIAL（重型枪口火/爆炸贴图/火球帧），步枪机枪被渲染成火炮。
## legacy 域调用方（敌方枪口火、直射 batch 命中）传参前先经本函数归一为 0(SMG 档轻武器)。
static func normalize_light_kinetic_wt(wt: int) -> int:
	return 0 if wt == 1 or wt == 2 else wt

## v7.4: 炮口火焰（复用 spark 池，替代 bullet.gd 每次 new CPUParticles2D+Gradient）。
## 参数对齐原 bullet._spawn_muzzle_effect 的配置。
static func spawn_muzzle_flash(parent: Node2D, local_pos: Vector2, facing_right: bool, weapon_type: int = 0) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	if _active_sparks >= MAX_SPARKS:
		return
	_active_sparks += 1
	var p := _acquire_spark_particle()
	if p == null:
		_active_sparks -= 1
		return
	# v9.2: 枪口火按武器类型分流贴图；v9.6: 轻重判定改用 HEAVY_MUZZLE_WT（双枚举归一）
	var is_light_wt: bool = not (weapon_type in HEAVY_MUZZLE_WT)
	# v6.1: 能量武器（LASER/OMEGA/RAIL）使用方向性长条纹理 + 更窄锥角 + 更高速度，呈现喷射流形态
	var is_energy_wt: bool = not is_light_wt and weapon_type in [6, 8, 10, 11]
	if is_light_wt:  # 轻型动能武器
		p.texture = PARTICLE_TEX_MUZZLE_JET  # v17e: 前向喷流（侧视），替代四向星芒
	elif is_energy_wt:  # 能量武器：喷射流
		p.texture = PARTICLE_TEX_MUZZLE_ENERGY
	else:  # 重型化学武器（曲射/空射/火箭/高炮/导弹）
		p.texture = PARTICLE_TEX_FLAME_JET_V2  # v18-R9: 噪声渐变火舌（黑体色序摄影感）
	p.position = local_pos
	# ── v17c 枪口火去火球化（AI 评分基线 3.67/10 + 三裁判一致：读成"爆炸/燃烧团"而非开火）──
	# 病灶：旧参数轻武器 spread=150° 近乎全向 + 寿命 0.4s + 低速 50-140 → 橙色云雾缓慢漂散
	# = "持续燃烧"；重型 44 粒 × 0.4s 同样拖成火球团。真实枪口火是【瞬时定向】的：
	#   轻武器（步枪/机枪）= 0.1s 级细碎火星锥，一闪即逝
	#   重型化学（炮/火箭）= 0.2s 级定向爆喷 + 独立发射药烟层（烟保留，火要短）
	#   能量（激光/磁轨/欧米茄）= 细长高速喷流，比化学炮稍持久
	# 参考聚合自 docs/vfx_realism_report_v17.md 高优先级建议（48 格三模式之首）。
	if is_light_wt:
		# v18: 轻武器枪口"细碎火星"化（v17 复审高频批"糊成一团/连续拖尾/尺度偏大"）。
		# 病灶：26 粒 × 12-26px × 0.14s × 48° 锥相互重叠——单发读成"橙色糊团"，
		# 连发（审计 3 连拍/实战 SMG 10发/s）叠成连续火舌。规格要"细碎橙火星一闪即逝"：
		# 减粒（26→12，拉开粒间距）+ 缩尺寸（12-26→7-15px，贴回 ≤16px 规格）
		# + 提速缩寿（560×0.10s 轨迹更利落，驻留减半）+ 收锥（48°→30°，减少纵向涂抹）。
		p.lifetime = 0.10            # 一闪即逝（0.14 仍有拖尾感）
		p.amount = 12                # v18: 26→12（密度是糊团主因；ADD 亮贴图 12 粒足够可见）
		p.emission_sphere_radius = 1.0  # v18: 1.5→1.0 进一步收紧爆发核心
		p.spread = 30.0              # v18: 48→30 更窄锥（细碎感）
		p.initial_velocity_min = 340.0   # v18: 260→340 快出快灭
		p.initial_velocity_max = 560.0   # v18: 460→560
		# 贴图内容实宽 100px（v17b 注释 74-84px 已过时，PIL 复测 100×26）。
		p.scale_amount_min = 0.07    # → 单粒显示 ~7px 细火星
		p.scale_amount_max = 0.15    # → ~15px（≤16px 规格内）
	elif is_energy_wt:
		p.lifetime = 0.24            # 喷流稍持久但告别 0.4s
		p.amount = 36                # v17l: 28→36（AI 批"开火无存在感"）
		p.emission_sphere_radius = 1.5
		p.spread = 8.0               # 极窄喷流（保持）
		p.initial_velocity_min = 560.0
		p.initial_velocity_max = 980.0
		# v17b 实测贴图内容 974×597px。v17l: 0.035-0.085→0.05-0.12（喷流亮体加码）
		p.scale_amount_min = 0.05
		p.scale_amount_max = 0.12
	else:  # 重型化学（曲射/空射/火箭/高炮/导弹）
		p.lifetime = 0.22            # 大闪光但短促（原 0.40）
		p.amount = 42                # v17l: 30→42（AI 批"开火像枪不像炮"）
		p.emission_sphere_radius = 3.0
		p.spread = 24.0              # 更紧的定向爆喷（原 32°）
		p.initial_velocity_min = 420.0
		p.initial_velocity_max = 760.0
		# v17b 实测 flame_jet_v2 画布 160×56；v19-R18 PIL 复测内容带仅 160×35（y[10,44]）。
		# 旧 0.20-0.38 按画布宽标定 → 火舌仅 32-61px 宽 × 7-13px 高薄片，AI 批
		# "分散破碎/缺集中爆发"（与轻武器黑名单#1 同源：scale 基准混用画布与内容带）。
		# 按带高实寸重标定：0.42-0.68 → 67-109px 宽 × 15-24px 高火舌。
		p.scale_amount_min = 0.42
		p.scale_amount_max = 0.68
	p.direction = Vector2(1, 0) if facing_right else Vector2(-1, 0)
	p.color_ramp = _get_muzzle_ramp() if not is_energy_wt else _get_energy_muzzle_ramp()
	parent.add_child(p)
	var tree := p.get_tree()
	if tree != null:
		var timer := tree.create_timer(p.lifetime + 0.1)
		_connect_deferred_release(timer, p, _release_spark_particle)
	# v19-R17: 轻武器枪口白热闪核（R36 重做）。
	# R17 首版用 MUZZLE_JET 横条贴图(100×24 宽高比 4:1)×scale 1.4-2.0 + 随机旋转
	# → 画面呈现 140-200px 横向长光条（用户反馈"横着的长光条"）。
	# R36 改用 IMPACT_METAL 放射圆爆贴图 + 紧凑尺寸——瞬态"炸一下"的圆闪，非长条。
	if is_light_wt and not DT.is_motion_reduce() and _active_impact_sprites < MAX_IMPACT_SPRITES:
		# 第 1 层：白热圆闪核（放射纹，快速膨胀骤淡）
		var lcore := _acquire_impact_sprite()
		if lcore != null:
			lcore.texture = PARTICLE_TEX_IMPACT_METAL     # 放射圆爆纹（等比，无长条）
			lcore.position = local_pos
			lcore.rotation = randf() * TAU
			lcore.scale = Vector2(0.45, 0.45)             # ~58px 圆闪（轻武器级）
			lcore.modulate = Color(1.0, 0.98, 0.90, 1.0)  # 近纯白
			lcore.visible = true
			lcore.material = _get_add_mat()
			parent.add_child(lcore)
			lcore.add_to_group("battle_vfx")
			var tw_core := lcore.create_tween()
			tw_core.tween_property(lcore, "scale", Vector2(0.65, 0.65), 0.05).set_ease(Tween.EASE_OUT)
			tw_core.parallel().tween_property(lcore, "modulate:a", 0.0, 0.12).set_ease(Tween.EASE_IN)
			tw_core.tween_callback(func(): _release_impact_sprite(lcore))
		# 第 2 层：宽幅低透暖光晕（R36: 同样改放射纹避免长条）
		if _active_impact_sprites < MAX_IMPACT_SPRITES:
			var lglow := _acquire_impact_sprite()
			if lglow != null:
				lglow.texture = PARTICLE_TEX_IMPACT_METAL   # R36: 横条→放射圆纹
				lglow.position = local_pos
				lglow.rotation = randf() * TAU
				lglow.scale = Vector2(0.60, 0.60)             # ~77px 光晕
				lglow.modulate = Color(1.0, 0.82, 0.55, 0.40)  # 暖橙光晕
				lglow.visible = true
				lglow.material = _get_add_mat()
				parent.add_child(lglow)
				lglow.add_to_group("battle_vfx")
				var tw_glow := lglow.create_tween()
				tw_glow.tween_property(lglow, "scale", Vector2(0.85, 0.85), 0.07).set_ease(Tween.EASE_OUT)
				tw_glow.parallel().tween_property(lglow, "modulate:a", 0.0, 0.15).set_ease(Tween.EASE_IN)
				tw_glow.tween_callback(func(): _release_impact_sprite(lglow))
	# v19-R31: 磁轨炮(wt11)白热爆闪核——R30 AI 复审批 f11 双方枪口"仅几粒散蓝点，
	# 缺高能量释放感"(2-3/10)。根因：R17 闪核只加给轻武器(is_light_wt)，wt11 走能量
	# 分支(细喷流 36 粒 × 0.05-0.12 scale)没吃到爆闪修复。磁轨是超高初速动能武器，
	# 枪口该有"炮"级爆闪：大幅白热核(IMPACT_METAL 放射纹) + 青色电磁辉光。
	if weapon_type == 11 and not DT.is_motion_reduce() and _active_impact_sprites < MAX_IMPACT_SPRITES:
		# 第 1 层：白热爆闪核（放射状金属爆纹，快速膨胀骤淡）
		if _active_impact_sprites < MAX_IMPACT_SPRITES:
			var rcore := _acquire_impact_sprite()
			if rcore != null:
				rcore.texture = PARTICLE_TEX_IMPACT_METAL    # 放射金属爆纹（动能撞击签名）
				rcore.position = local_pos
				rcore.rotation = randf() * TAU
				rcore.scale = Vector2(2.5, 2.5)              # ~320px 爆闪（重炮级）
				rcore.modulate = Color(1.0, 0.98, 0.92, 1.0)  # 白热
				rcore.visible = true
				rcore.material = _get_add_mat()
				parent.add_child(rcore)
				rcore.add_to_group("battle_vfx")
				var tw_rc := rcore.create_tween()
				tw_rc.tween_property(rcore, "scale", Vector2(3.5, 3.5), 0.06).set_ease(Tween.EASE_OUT)
				tw_rc.parallel().tween_property(rcore, "modulate:a", 0.0, 0.12).set_ease(Tween.EASE_IN)
				tw_rc.tween_callback(func(): _release_impact_sprite(rcore))
		# 第 2 层：青色电磁辉光（宽幅低透，电磁场爆发感）
		if _active_impact_sprites < MAX_IMPACT_SPRITES:
			var rglow := _acquire_impact_sprite()
			if rglow != null:
				rglow.texture = PARTICLE_TEX_MUZZLE_ENERGY   # 能量贴图（青色辉光）
				rglow.position = local_pos
				rglow.rotation = randf() * TAU
				rglow.scale = Vector2(0.45, 0.45)            # ~460px 炮级电磁辉光（v19-R32 超屏修复：原1.8/2.6→1843/2662px，2倍屏宽全屏洗礼）
				rglow.modulate = Color(0.5, 0.85, 1.0, 0.5)   # 青色电磁辉光
				rglow.visible = true
				rglow.material = _get_add_mat()
				parent.add_child(rglow)
				rglow.add_to_group("battle_vfx")
				var tw_rg := rglow.create_tween()
				tw_rg.tween_property(rglow, "scale", Vector2(0.65, 0.65), 0.08).set_ease(Tween.EASE_OUT)
				tw_rg.parallel().tween_property(rglow, "modulate:a", 0.0, 0.16).set_ease(Tween.EASE_IN)
				tw_rg.tween_callback(func(): _release_impact_sprite(rglow))
	# v13: 重型发射烟团——火箭/导弹发射的发射药烟，喷射后的低速扩散烟（短寿命不糊屏）
	# v6.1: 能量武器用蓝色等离子废烟替代灰色化学烟雾
	if not is_light_wt and not DT.is_motion_reduce() and _active_debris < MAX_DEBRIS:
		_active_debris += 1
		var sm := _acquire_debris_particle()
		if sm == null:
			_active_debris -= 1
		else:
			sm.texture = PARTICLE_TEX_SMOKE_ENERGY if is_energy_wt else PARTICLE_TEX_SMOKE_GENERIC
			sm.position = local_pos
			sm.lifetime = 0.35
			sm.amount = 6
			sm.emission_sphere_radius = 4.0
			sm.direction = Vector2(1, 0) if facing_right else Vector2(-1, 0)
			sm.spread = 70.0
			sm.initial_velocity_min = 30.0
			sm.initial_velocity_max = 90.0
			sm.gravity = Vector2(0, -15.0)
			# v17c: 烟是配角——v17c 把枪口火砍小砍短后，原 0.6-1.2 缩放（×128px 贴图=77-154px
			# 发亮 ADD 烟团、寿命 0.35s 比火长）反客为主，AI 复测全部格子被读成"烟雾云"（3.5↓）。
			# 缩到火球一半以下的软烟，发射药烟的语义保留但不再淹没开火闪光。
			sm.scale_amount_min = 0.28
			sm.scale_amount_max = 0.55
			sm.color = Color(0.55, 0.52, 0.48, 0.45) if not is_energy_wt else Color(0.35, 0.55, 0.7, 0.4)
			sm.color_ramp = _get_smoke_grad(Color(0.55, 0.52, 0.48, 0.45)) if not is_energy_wt else _get_smoke_grad(Color(0.35, 0.55, 0.7, 0.4))
			sm.emitting = true
			parent.add_child(sm)
			var tree_sm := sm.get_tree()
			if tree_sm != null:
				_connect_deferred_release(tree_sm.create_timer(sm.lifetime + 0.1), sm, _release_debris_particle)
	# v18-R8: 欧米茄(10)枪口补径向放电签名——impact 已有 7 星芒而枪口只有细喷流，
	# AI 批"零条射线/无能量核/无辉光环"（f10 muzzle 3-4/10）。紧凑版三层：能量核 +
	# 5 短星芒 + 辉光环，全复用现有池。配色与 spawn_omega_discharge 敌我分色对齐。
	if weapon_type == 10 and not DT.is_motion_reduce():
		var mcol: Color = Color(0.75, 0.40, 1.0, 1.0) if facing_right else Color(0.50, 1.0, 0.40, 1.0)
		mcol = _era_tint_energy(mcol)
		# ① 能量核（白热闪 → 族色，ADD 快速放大骤淡）
		if _active_impact_sprites < MAX_IMPACT_SPRITES:
			var ocore := _acquire_impact_sprite()
			if ocore != null:
				ocore.texture = PARTICLE_TEX_IMPACT_ENERGY
				ocore.position = local_pos
				ocore.scale = Vector2(1.0, 1.0)
				ocore.modulate = Color(1.0, 1.0, 1.0, 1.0)
				ocore.visible = true
				ocore.material = _get_add_mat()
				parent.add_child(ocore)
				ocore.add_to_group("battle_vfx")
				var twc := ocore.create_tween().bind_node(ocore)
				twc.tween_property(ocore, "scale", Vector2(1.8, 1.8), 0.06)
				twc.parallel().tween_property(ocore, "modulate:a", 0.0, 0.16)
				twc.tween_callback(func():
					if is_instance_valid(ocore):
						ocore.material = null
						_release_impact_sprite(ocore))
		# ② 5 条短星芒（径向，随机相位防死板）
		for i in range(5):
			var ray := _acquire_beam()
			if ray == null:
				break
			var ang: float = (float(i) / 5.0) * TAU + randf() * 0.4
			var rdir := Vector2(cos(ang), sin(ang))
			var outer: float = 34.0 + randf() * 18.0
			ray.width = 2.4
			ray.default_color = Color(mcol.r, mcol.g, mcol.b, 0.95)
			ray.joint_mode = Line2D.LINE_JOINT_ROUND
			ray.end_cap_mode = Line2D.LINE_CAP_ROUND
			ray.add_point(local_pos + rdir * 6.0)
			ray.add_point(local_pos + rdir * outer)
			ray.position = Vector2.ZERO
			ray.material = _get_add_mat()
			parent.add_child(ray)
			var twr := ray.create_tween().bind_node(ray)
			twr.tween_interval(0.02)
			twr.tween_property(ray, "modulate:a", 0.0, 0.16)
			twr.tween_callback(func():
				if is_instance_valid(ray):
					ray.material = null
					_release_beam(ray))
		# ③ 辉光环（慢扩散余波）
		spawn_shockwave(parent, local_pos, 42.0, Color(mcol.r, mcol.g, mcol.b, 0.55))


## v7.4: 固定 Gradient 缓存（暴击/炮口专用，避免每次 new Gradient）
static var _crit_ramp: Gradient = null
static var _muzzle_ramp: Gradient = null

static func _get_crit_ramp() -> Gradient:
	if _crit_ramp == null:
		_crit_ramp = Gradient.new()
		_crit_ramp.add_point(0, Color(1.0, 0.95, 0.5, 1.0))
		_crit_ramp.add_point(1.0, Color(1.0, 0.95, 0.5, 0.0))
	return _crit_ramp

static func _get_muzzle_ramp() -> Gradient:
	if _muzzle_ramp == null:
		_muzzle_ramp = Gradient.new()
		_muzzle_ramp.add_point(0, Color(1.0, 0.98, 0.85, 1.0))  # v10: 白热核心(原黄 0.9,0.4)
		_muzzle_ramp.add_point(0.25, Color(1.0, 0.85, 0.4, 1.0))
		_muzzle_ramp.add_point(0.6, Color(1.0, 0.5, 0.1, 0.5))
		_muzzle_ramp.add_point(1.0, Color(1.0, 0.3, 0.0, 0.0))
	return _muzzle_ramp

## v6.1: 能量武器（LASER/OMEGA/RAIL）枪口火色阶——白青核心→透明蓝绿边缘，呈现等离子喷射流
static var _energy_muzzle_ramp: Gradient = null
static func _get_energy_muzzle_ramp() -> Gradient:
	if _energy_muzzle_ramp == null:
		_energy_muzzle_ramp = Gradient.new()
		_energy_muzzle_ramp.add_point(0.0, Color(1.0, 1.0, 1.0, 1.0))   # 白热核心
		_energy_muzzle_ramp.add_point(0.2, Color(0.8, 1.0, 1.0, 1.0))    # 白青
		_energy_muzzle_ramp.add_point(0.5, Color(0.4, 0.85, 1.0, 0.8))   # 饱和青蓝
		_energy_muzzle_ramp.add_point(0.8, Color(0.2, 0.6, 0.9, 0.3))    # 淡蓝边缘
		_energy_muzzle_ramp.add_point(1.0, Color(0.1, 0.4, 0.7, 0.0))    # 完全透明
	return _energy_muzzle_ramp

## P3 性能优化：热路径 Gradient 缓存（轨道炮碎片/激光灼热/熔融火星/欧米茄放电，
## 原每次命中 new Gradient + add_point 堆分配）。颜色随武器变的按 Color 键缓存（武器色离散有限）。
static var _rail_spall_ramp: Gradient = null
static var _molten_ramp: Gradient = null
static var _tinted_ramp_cache: Dictionary = {}  # Color -> Gradient（beam/pcol 渐变同构复用）

static func _get_rail_spall_ramp() -> Gradient:
	if _rail_spall_ramp == null:
		_rail_spall_ramp = Gradient.new()
		_rail_spall_ramp.add_point(0.0, Color(1.0, 1.0, 0.95, 1.0))
		_rail_spall_ramp.add_point(0.4, Color(1.0, 0.7, 0.4, 0.9))
		_rail_spall_ramp.add_point(1.0, Color(0.4, 0.2, 0.1, 0.0))
	return _rail_spall_ramp

static func _get_molten_ramp() -> Gradient:
	if _molten_ramp == null:
		_molten_ramp = Gradient.new()
		_molten_ramp.add_point(0.0, Color(1.0, 0.9, 0.5, 1.0))
		_molten_ramp.add_point(0.5, Color(1.0, 0.45, 0.1, 0.9))
		_molten_ramp.add_point(1.0, Color(0.3, 0.1, 0.0, 0.0))
	return _molten_ramp

## 按基色缓存的渐变（白核 → 基色 40% 亮度衰减），激光灼热与欧米茄放电共用同构
static func _get_tinted_ramp(base_col: Color) -> Gradient:
	if not _tinted_ramp_cache.has(base_col):
		var g := Gradient.new()
		g.add_point(0.0, Color(1.0, 1.0, 1.0, 1.0))
		g.add_point(0.4, Color(base_col.r, base_col.g, base_col.b, 0.9))
		g.add_point(1.0, Color(base_col.r * 0.4, base_col.g * 0.4, base_col.b * 0.5, 0.0))
		_tinted_ramp_cache[base_col] = g
	return _tinted_ramp_cache[base_col]


## v13.1: 攻击追踪线——瞬发/技能伤害（无弹道）时从攻击方到受击方拉一条阵营色细线，
## 补足"谁在打谁"的方向感。窄线+短淡出（0.16s），不与子弹弹道（自带 tracer）叠加。
## 复用 _spawn_beam_glow 池；距离过近（<40px，近战/同位）不画。
static func spawn_attack_tracer(parent: Node2D, from_pos: Vector2, to_pos: Vector2, is_player: bool) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	if DT.is_motion_reduce():
		return
	if from_pos.distance_to(to_pos) < 40.0:
		return
	var col: Color = side_color(is_player)
	col.a = 0.75
	_spawn_beam_glow(parent, from_pos, from_pos.lerp(to_pos, 0.92), col, 3.0, 0.16)

## v10 真实度：光束辉光晕——锐利主光束后铺宽低 alpha 的 ADD 辉光(报告:激光/穿透/闪电/光柱缺辉光,仅一条细线)。
static func _spawn_beam_glow(parent: Node2D, from_pos: Vector2, to_pos: Vector2, color: Color, width: float, fade: float = 0.35) -> void:
	var glow := _acquire_beam()
	if glow == null:
		return
	glow.width = width
	glow.default_color = Color(color.r, color.g, color.b, 0.32)
	glow.joint_mode = Line2D.LINE_JOINT_ROUND
	glow.end_cap_mode = Line2D.LINE_CAP_ROUND
	glow.add_point(from_pos)
	glow.add_point(to_pos)
	glow.position = Vector2.ZERO
	parent.add_child(glow)
	var tw := glow.create_tween()
	tw.tween_property(glow, "modulate:a", 0.0, fade)
	tw.tween_callback(func(): _release_beam(glow))


## 穿透紫色穿甲光线（v8.2：加长淡出到可看清）。v7.4: 改用 beam 池
## color: 光线颜色（默认亮紫，给 piercing_shot 相位仪/敌方大招传专属配色）
## enhanced: v9.4 增强——加宽加长加余晖，给 piercing_shot 技能穿透(玩家)/single_target(敌方) 用，
##   让"技能级穿透"区别于"普通穿甲"（宽 5→8，长 60→100，淡出 0.35→0.45）。
## length_scale: 长度倍率（默认1.0=60px；敌方 single_target 传更大值让下劈激光更长）
static func spawn_pierce_beam(parent: Node2D, world_pos: Vector2, direction: Vector2, color: Color = Color(0.85, 0.55, 1.0, 1.0), enhanced: bool = false, length_scale: float = 1.0) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var beam := _acquire_beam()
	if beam == null:
		return
	color = _era_tint_energy(color)  # v13: 时代化能量配色
	var base_width: float = 8.0 if enhanced else 5.0
	beam.width = base_width
	beam.default_color = color
	beam.joint_mode = Line2D.LINE_JOINT_ROUND
	beam.end_cap_mode = Line2D.LINE_CAP_ROUND
	var d := direction.normalized()
	var tail_off: float = 16.0
	var head_off: float = 60.0 * length_scale * (1.6 if enhanced else 1.0)  # 增强版加长
	var start := world_pos - d * tail_off
	var end := world_pos + d * head_off  # 加长
	_spawn_beam_glow(parent, start, end, color, 16.0 if enhanced else 12.0, 0.40)  # v10: 穿透辉光
	beam.add_point(start)
	beam.add_point(end)
	beam.position = Vector2.ZERO
	parent.add_child(beam)
	var tween := beam.create_tween()
	# 先变细再淡出（模拟穿甲弹穿透后能量消散）；增强版余晖更长
	var fade_t: float = 0.45 if enhanced else 0.35
	tween.tween_property(beam, "width", 2.0, 0.15)
	tween.parallel().tween_property(beam, "modulate:a", 0.0, fade_t)
	tween.tween_callback(func(): _release_beam(beam))


## v12 轨道炮签名穿透命中 —— 动能穿透,不走通用"贴图+爆炸帧"流水线。
## 轨道炮是超高初速动能穿甲弹,该有的是【震撼+穿透】,而非蓝色能量球:
##   ① 入口瞬时过曝白闪(ADD 星芒) + 锐利白冲击环 = 撞击"震撼"
##   ② 白热穿透光迹:从入口贯穿目标到出口(亮核+辉光,短促保留后淡出) = "穿透感"灵魂
##   ③ 出口 spall:目标背面喷一锥白热碎片+尘(证明打穿了,不是表面爆炸)
##   ④ 入口少量白火花(动能,非蓝色能量粒子)
## [param dir] 穿透方向(默认右);[param penetrate_dist] 贯穿距离(目标宽+余量)
static func spawn_railgun_penetration(parent: Node2D, pos: Vector2, dir: Vector2 = Vector2.RIGHT, penetrate_dist: float = 170.0) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var motion_reduce: bool = DT.is_motion_reduce()
	var d := dir.normalized() if dir.length() > 0.01 else Vector2.RIGHT
	var entry := pos
	var exit := pos + d * penetrate_dist
	# ① 入口过曝白闪(impact_metal 星芒贴图,纯白,ADD,极短放大后骤淡)
	if _active_impact_sprites < MAX_IMPACT_SPRITES:
		var flash := _acquire_impact_sprite()
		if flash != null:
			flash.texture = PARTICLE_TEX_IMPACT_METAL
			flash.position = entry
			flash.scale = Vector2(1.8, 1.8)
			flash.modulate = Color(1.0, 1.0, 1.0, 1.0)
			flash.visible = true
			flash.material = _get_add_mat()
			parent.add_child(flash)
			flash.add_to_group("battle_vfx")
			var twf := flash.create_tween().bind_node(flash)
			twf.tween_property(flash, "scale", Vector2(2.8, 2.8), 0.05)
			twf.parallel().tween_property(flash, "modulate:a", 0.0, 0.12)
			twf.tween_callback(func():
				if is_instance_valid(flash):
					flash.material = null
					_release_impact_sprite(flash))
	# 入口锐利白冲击环(震撼)
	if not motion_reduce:
		spawn_shockwave(parent, entry, 95.0, Color(1.0, 1.0, 0.95, 0.9))
	# ② 白热穿透光迹:贯穿入口→出口,亮核 + 辉光,贯穿瞬间保持全亮后骤淡
	var core := _acquire_beam()
	if core != null:
		var start := entry - d * 26.0
		var endp := exit + d * 36.0
		core.width = 8.0
		core.default_color = Color(1.0, 0.98, 0.92, 1.0)
		core.joint_mode = Line2D.LINE_JOINT_ROUND
		core.end_cap_mode = Line2D.LINE_CAP_ROUND
		core.add_point(start)
		core.add_point(endp)
		core.position = Vector2.ZERO
		core.material = _get_add_mat()  # ADD 让白热光迹过曝发亮
		parent.add_child(core)
		_spawn_beam_glow(parent, start, endp, Color(1.0, 0.95, 0.85, 1.0), 26.0, 0.30)
		var twb := core.create_tween().bind_node(core)
		twb.tween_interval(0.10)  # v12b: 全亮保持更久(0.04→0.10),让峰值帧仍见清晰光迹
		twb.tween_property(core, "width", 2.5, 0.20)
		twb.parallel().tween_property(core, "modulate:a", 0.0, 0.28)
		twb.tween_callback(func():
			if is_instance_valid(core):
				core.material = null
				_release_beam(core))
	# ②b 超高速运动模糊线(streak lines):穿透光迹接近侧的细平行余像,卖"超高速弹丸的残影"。
	# 视觉报告建议——原效果光迹读成激光,缺"速度感";加 3 条逐条后移的细线给动量方向。
	# 只铺在接近侧(入口左/射击者方向),不穿过目标——是"弹丸飞来的速度线",非二次光迹。
	if not motion_reduce:
		var perp := Vector2(-d.y, d.x)  # 垂直法线
		for i in range(4):  # v13: 3→4 条(峰值帧读图报"速度线几乎不可见",加一条近距内层线)
			var sl := _acquire_beam()
			if sl == null:
				break
			var side: float = 1.0 if i % 2 == 0 else -1.0
			var off: float = (5.0 + i * 3.5) * side       # 两侧逐条外扩
			var trail_back: float = 40.0 + i * 16.0        # 逐条后移(拖尾层次),v12d 加长
			var s_start := entry - d * (24.0 + trail_back) + perp * off
			var s_end := entry - d * 4.0 + perp * off
			sl.width = 4.6 - i * 0.5  # v13 加粗(3.2→4.6)——宽度是不显眼主因之一
			sl.default_color = Color(0.88, 0.95, 1.0, 0.95)  # v12d 提亮(0.80→0.95)+微蓝:电磁等离子余像
			sl.joint_mode = Line2D.LINE_JOINT_ROUND
			sl.end_cap_mode = Line2D.LINE_CAP_ROUND
			sl.add_point(s_start)
			sl.add_point(s_end)
			sl.position = Vector2.ZERO
			sl.material = _get_add_mat()
			parent.add_child(sl)
			var tsl := sl.create_tween().bind_node(sl)
			tsl.tween_interval(0.02)
			tsl.tween_property(sl, "modulate:a", 0.0, 0.28 + i * 0.04)  # v13 延长淡出(0.16→0.28):峰值帧 frame8 时原已淡到 ~30% alpha,是"不可见"主因
			tsl.tween_callback(func():
				if is_instance_valid(sl):
					sl.material = null
					_release_beam(sl))
	# ③ 出口 spall:目标背面喷一锥白热碎片+尘(穿透证据)——这是区分"激光"与"动能穿透"的
	# 关键视觉锚(报告原效果读成激光:缺出口碎片)。加大数量/尺寸/速度让碎片云清晰可辨。
	if not motion_reduce and _active_debris < MAX_DEBRIS:
		_active_debris += 1
		var spall := _acquire_debris_particle()
		if spall != null:
			spall.position = exit
			# v17d: 换棱角金属破片贴图 + 尺寸重标定（旧 0.7-2.0×128px=90-256px 巨块）
			spall.texture = PARTICLE_TEX_SPARK_DROP   # v18-R9: 白热熔滴簇（黑体色序摄影感）
			spall.amount = 32
			spall.lifetime = 0.6
			spall.lifetime_randomness = 0.3
			spall.initial_velocity_min = 340.0
			spall.initial_velocity_max = 660.0
			spall.direction = d
			spall.spread = 60.0
			spall.gravity = Vector2(0, 55.0)
			# v17e: 尺度修正——旧 0.7-2.0×128px=89-256px 巨块 → 0.15-0.35×128=19-45px 合理
			spall.scale_amount_min = 0.15
			spall.scale_amount_max = 0.35
			spall.color = Color(1.0, 0.95, 0.85, 1.0)
			spall.color_ramp = _get_rail_spall_ramp()  # P3: 固定色渐变缓存
			spall.emitting = true
			parent.add_child(spall)
			var tree := spall.get_tree()
			if tree != null:
				var timer := tree.create_timer(spall.lifetime + 0.1)
				_connect_deferred_release(timer, spall, _release_debris_particle)
		else:
			_active_debris -= 1
	# ③b 出口尘云:碎片伴随的灰白烟尘(被穿透的装甲蒸发感),复用 debris 池 is_smoke 模式
	if not motion_reduce and _active_debris < MAX_DEBRIS:
		_active_debris += 1
		var dust := _acquire_debris_particle()
		if dust != null:
			dust.position = exit
			dust.texture = PARTICLE_TEX_SMOKE_GENERIC
			dust.amount = 8
			dust.lifetime = 0.7
			dust.initial_velocity_min = 60.0
			dust.initial_velocity_max = 160.0
			dust.direction = d
			dust.spread = 70.0
			dust.gravity = Vector2(0, -20.0)
			dust.scale_amount_min = 1.2
			dust.scale_amount_max = 2.4
			dust.color = Color(0.6, 0.58, 0.55, 0.5)
			dust.color_ramp = _get_smoke_grad(Color(0.6, 0.58, 0.55, 0.5))
			dust.emitting = true
			parent.add_child(dust)
			var tree2 := dust.get_tree()
			if tree2 != null:
				var timer3 := tree2.create_timer(dust.lifetime + 0.1)
				_connect_deferred_release(timer3, dust, _release_debris_particle)
		else:
			_active_debris -= 1
	# ④ 入口回溅(超高速反向 ejecta):真实弹道学——hyper-velocity 命中入口向射击者方向反喷
	# 白热碎片(方向 -d = 反穿透)。这是给静态帧定"动量方向"的关键:碎片朝左飞+出口 spall
	# 朝右飞 = 弹丸从左穿到右,一眼读出"贯穿方向"。原方向 (0,-1) 是通用上喷,无方向信息。
	if not motion_reduce and _active_sparks < MAX_SPARKS:
		_active_sparks += 1
		var sp := _acquire_spark_particle()
		if sp != null:
			sp.position = entry
			sp.texture = PARTICLE_TEX_SPARK_METAL
			sp.amount = 14
			sp.lifetime = 0.24
			sp.lifetime_randomness = 0.3
			sp.initial_velocity_min = 320.0
			sp.initial_velocity_max = 620.0
			sp.direction = -d  # 反穿透方向(向射击者)
			sp.spread = 50.0
			sp.angle_min = 0.0
			sp.angle_max = 360.0
			sp.gravity = Vector2(0, 45.0)  # v12e: 斜俯视地面感知(130→45),回溅碎片不穿透地面
			sp.scale_amount_min = 0.34
			sp.scale_amount_max = 0.56
			sp.color = Color(1.0, 0.98, 0.9, 1.0)
			sp.color_ramp = _get_spark_ramp(Color(1.0, 0.98, 0.9, 1.0), 0)
			sp.emitting = true
			parent.add_child(sp)
			var tree := sp.get_tree()
			if tree != null:
				var timer2 := tree.create_timer(sp.lifetime + 0.1)
				_connect_deferred_release(timer2, sp, _release_spark_particle)
		else:
			_active_sparks -= 1


## v12d: 激光签名灼烧效果——表面能量沉积(非动能穿透)。
##   与轨道炮刻意区分:轨道炮=贯穿+出口spall+速度线(实心弹丸);激光=表面灼烧+焦痕+
##   热火花上升+辉光脉冲(相干光束烧蚀)。原激光与轨道炮/欧米茄共用 OMEGA 贴图+能量帧,
##   读成"通用能量团";本函数给它独立签名。
##   is_player: 玩家方=青白冷光;敌方=红橙热光——战术可读性(一眼分清谁的激光)。
##   dir: 攻击方向(来弹方向,v12d 加)——激光是从射手射来的相干光束,命中点画一段指向来源的来弹光束。
static func spawn_laser_burn(parent: Node2D, pos: Vector2, is_player: bool = true, dir: Vector2 = Vector2.RIGHT) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var motion_reduce: bool = DT.is_motion_reduce()
	var beam_col: Color = Color(0.70, 0.95, 1.0, 1.0) if is_player else Color(1.0, 0.50, 0.35, 1.0)
	beam_col = _era_tint_energy(beam_col)  # v13: 时代化能量配色(敌我冷暖关系保持:暖化后仍偏白)
	var d := dir.normalized() if dir.length() > 0.01 else Vector2.RIGHT
	# ⓪ 来弹光束:从射手方向(pos - d*L)射向命中点的相干光束——给激光"从哪打来"的方向感。
	# 比核心光斑细、ADD、快速淡出(命中瞬间残留的入射光路)。
	var lb := _acquire_beam()
	if lb != null:
		var lb_start := pos - d * 110.0
		var lb_end := pos
		lb.width = 4.0
		lb.default_color = Color(beam_col.r, beam_col.g, beam_col.b, 0.95)
		lb.joint_mode = Line2D.LINE_JOINT_ROUND
		lb.end_cap_mode = Line2D.LINE_CAP_ROUND
		lb.add_point(lb_start)
		lb.add_point(lb_end)
		lb.position = Vector2.ZERO
		lb.material = _get_add_mat()
		parent.add_child(lb)
		_spawn_beam_glow(parent, lb_start, lb_end, beam_col, 12.0, 0.16)
		var twlb := lb.create_tween().bind_node(lb)
		twlb.tween_interval(0.03)
		twlb.tween_property(lb, "width", 1.5, 0.14)
		twlb.parallel().tween_property(lb, "modulate:a", 0.0, 0.20)
		twlb.tween_callback(func():
			if is_instance_valid(lb):
				lb.material = null
				_release_beam(lb))
	# ① 聚焦灼热光斑:白热核心(亮于光束色),放大→收缩→转光束色(冷却),ADD 过曝
	if _active_impact_sprites < MAX_IMPACT_SPRITES:
		var spot := _acquire_impact_sprite()
		if spot != null:
			spot.texture = PARTICLE_TEX_IMPACT_ENERGY
			spot.position = pos
			spot.scale = Vector2(1.6, 1.6)
			spot.modulate = Color(1.0, 1.0, 1.0, 1.0)  # 白热核心(冲击瞬间全白)
			spot.visible = true
			spot.material = _get_add_mat()
			parent.add_child(spot)
			spot.add_to_group("battle_vfx")
			var tws := spot.create_tween().bind_node(spot)
			tws.tween_property(spot, "scale", Vector2(1.8, 1.8), 0.06)  # 紧聚焦光斑(激光=相干,小光点)
			tws.tween_property(spot, "modulate", beam_col, 0.10)  # 白热→光束色(冷却)
			tws.parallel().tween_property(spot, "scale", Vector2(0.9, 0.9), 0.18)
			tws.tween_property(spot, "modulate:a", 0.0, 0.22)
			tws.tween_callback(func():
				if is_instance_valid(spot):
					spot.material = null
					_release_impact_sprite(spot))
	# ② 能量辉光晕:光束色冲击环脉冲一次(能量扩散,非动能震波)
	if not motion_reduce:
		spawn_shockwave(parent, pos, 60.0, Color(beam_col.r, beam_col.g, beam_col.b, 0.55))
	# ③ 焦痕:深色烧蚀印记,长留(1.2s——比动能焦痕久,激光持续烧蚀表面)。
	# v12d-fix: 焦痕必须比光斑大(scale 1.6→2.6,>光斑 2.15),否则被 ADD 光斑完全淹没看不到。
	# 外圈焦黑+微暖色边(烧灼感,非纯黑阴影),作为"激光烧穿表面"的核心证据。
	if not motion_reduce and _active_impact_sprites < MAX_IMPACT_SPRITES:
		var scorch := _acquire_impact_sprite()
		if scorch != null:
			scorch.texture = PARTICLE_TEX_IMPACT_SCORCH
			scorch.position = pos
			scorch.scale = Vector2(1.6, 1.6)
			scorch.modulate = Color(0.14, 0.08, 0.05, 0.82)  # 深焦黑+微暖红边(烧灼)
			scorch.visible = true
			parent.add_child(scorch)
			scorch.add_to_group("battle_vfx")
			var twc := scorch.create_tween().bind_node(scorch)
			twc.tween_property(scorch, "scale", Vector2(2.6, 2.6), 0.25)  # 焦痕扩大到超光斑(持续烧)
			twc.tween_interval(0.6)
			twc.tween_property(scorch, "modulate:a", 0.0, 0.4)
			twc.tween_callback(func():
				if is_instance_valid(scorch):
					_release_impact_sprite(scorch))
	# ④ 上升热火花:小火花向上飘(热对流),非定向 spall——区别于轨道炮的锥形碎片。
	# v12d-fix: 原 16 个/慢速 40-110/小 0.3-0.5 太弱,峰值帧几乎看不见;加到 26 个/快 100-210/大 0.5-0.8。
	if not motion_reduce and _active_sparks < MAX_SPARKS:
		_active_sparks += 1
		var heat := _acquire_spark_particle()
		if heat != null:
			heat.position = pos
			heat.texture = PARTICLE_TEX_SPARK_ENERGY
			heat.amount = 26
			heat.lifetime = 0.5
			heat.lifetime_randomness = 0.3
			heat.initial_velocity_min = 100.0
			heat.initial_velocity_max = 210.0
			heat.direction = Vector2(0, -1)  # 向上(热气上升)
			heat.spread = 35.0
			heat.angle_min = 0.0
			heat.angle_max = 360.0
			heat.gravity = Vector2(0, -40.0)  # 负重力(持续上飘)
			heat.scale_amount_min = 0.5
			heat.scale_amount_max = 0.8
			heat.color = beam_col
			heat.color_ramp = _get_tinted_ramp(beam_col)  # P3: 按武器色缓存渐变
			heat.emitting = true
			parent.add_child(heat)
			var tree := heat.get_tree()
			if tree != null:
				_connect_deferred_release(tree.create_timer(heat.lifetime + 0.1), heat, _release_spark_particle)
		else:
			_active_sparks -= 1
	# ④b 熔融火星:几颗亮橙熔融碎屑上飞(激光烧熔金属溅起),区别于光束色火花——是"被烧熔的物质"。
	if not motion_reduce and _active_debris < MAX_DEBRIS:
		_active_debris += 1
		var molten := _acquire_debris_particle()
		if molten != null:
			molten.position = pos
			molten.texture = PARTICLE_TEX_EMBER
			molten.amount = 8
			molten.lifetime = 0.55
			molten.lifetime_randomness = 0.3
			molten.initial_velocity_min = 120.0
			molten.initial_velocity_max = 240.0
			molten.direction = Vector2(0, -1)
			molten.spread = 50.0
			molten.gravity = Vector2(0, 55.0)  # v12e: 斜俯视地面感知(180→55),熔融火星上飞后 gently 落回不穿透地面
			molten.scale_amount_min = 0.4
			molten.scale_amount_max = 0.7
			molten.color = Color(1.0, 0.6, 0.2, 1.0)
			molten.color_ramp = _get_molten_ramp()  # P3: 固定色渐变缓存
			molten.emitting = true
			parent.add_child(molten)
			var tree3 := molten.get_tree()
			if tree3 != null:
				_connect_deferred_release(tree3.create_timer(molten.lifetime + 0.1), molten, _release_debris_particle)
		else:
			_active_debris -= 1


## v12d: 欧米茄粒子炮签名放电——重型带电粒子径向迸发(大能量核+星芒射线+外向电火花+持续辉光)。
##   与激光/轨道炮刻意区分:激光=紧焦烧灼+焦痕+上升火星;轨道炮=贯穿+spall+速度线;
##   欧米茄=大范围径向放电(粒子炮打到表面炸开放射状能量,四面八方)。原与激光/轨道炮共用 OMEGA 贴图。
##   is_player: 玩家=紫罗兰粒子;敌方=酸绿粒子——战术可读性。
##   dir: 攻击方向(来弹方向,v12d 加)——粒子炮从射手射来一束粒子流,命中点画指向来源的入射流。
static func spawn_omega_discharge(parent: Node2D, pos: Vector2, is_player: bool = true, dir: Vector2 = Vector2.RIGHT) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var motion_reduce: bool = DT.is_motion_reduce()
	var pcol: Color = Color(0.75, 0.40, 1.0, 1.0) if is_player else Color(0.50, 1.0, 0.40, 1.0)
	pcol = _era_tint_energy(pcol)  # v13: 时代化能量配色
	var d := dir.normalized() if dir.length() > 0.01 else Vector2.RIGHT
	# ⓪ 来弹粒子流:从射手方向(pos - d*L)射向命中点的粒子束——给欧米茄"从哪打来"的方向感。
	# 比激光粗(粒子流非相干光束)、带辉光、ADD。
	var istream := _acquire_beam()
	if istream != null:
		var is_start := pos - d * 95.0
		var is_end := pos
		istream.width = 7.0
		istream.default_color = Color(pcol.r, pcol.g, pcol.b, 0.9)
		istream.joint_mode = Line2D.LINE_JOINT_ROUND
		istream.end_cap_mode = Line2D.LINE_CAP_ROUND
		istream.add_point(is_start)
		istream.add_point(is_end)
		istream.position = Vector2.ZERO
		istream.material = _get_add_mat()
		parent.add_child(istream)
		_spawn_beam_glow(parent, is_start, is_end, pcol, 18.0, 0.16)
		var twis := istream.create_tween().bind_node(istream)
		twis.tween_interval(0.03)
		twis.tween_property(istream, "width", 2.0, 0.16)
		twis.parallel().tween_property(istream, "modulate:a", 0.0, 0.22)
		twis.tween_callback(func():
			if is_instance_valid(istream):
				istream.material = null
				_release_beam(istream))
	# ① 大型能量核心:impact_energy 贴图,ADD,放大后缓缩(重武器,比激光核大且久)
	if _active_impact_sprites < MAX_IMPACT_SPRITES:
		var ocore := _acquire_impact_sprite()
		if ocore != null:
			ocore.texture = PARTICLE_TEX_IMPACT_ENERGY
			ocore.position = pos
			ocore.scale = Vector2(2.0, 2.0)
			ocore.modulate = Color(1.0, 1.0, 1.0, 1.0)  # 白热冲击瞬间
			ocore.visible = true
			ocore.material = _get_add_mat()
			parent.add_child(ocore)
			ocore.add_to_group("battle_vfx")
			var twc := ocore.create_tween().bind_node(ocore)
			twc.tween_property(ocore, "scale", Vector2(3.2, 3.2), 0.08)  # 大爆开
			twc.tween_property(ocore, "modulate", pcol, 0.12)  # 白→粒子色
			twc.parallel().tween_property(ocore, "scale", Vector2(1.8, 1.8), 0.30)  # 缓缩(持续辉光)
			twc.tween_property(ocore, "modulate:a", 0.0, 0.35)
			twc.tween_callback(func():
				if is_instance_valid(ocore):
					ocore.material = null
					_release_impact_sprite(ocore))
	# ② 径向星芒放电:7 条细线从中心向外辐射(粒子迸发特征——能量四面八方炸开)
	if not motion_reduce:
		var ray_count := 7
		for i in range(ray_count):
			var ray := _acquire_beam()
			if ray == null:
				continue
			var ang: float = (float(i) / float(ray_count)) * TAU + randf() * 0.3
			var rdir := Vector2(cos(ang), sin(ang))
			var inner := 8.0
			var outer := 70.0 + randf() * 30.0
			ray.width = 2.6
			ray.default_color = Color(pcol.r, pcol.g, pcol.b, 0.95)
			ray.joint_mode = Line2D.LINE_JOINT_ROUND
			ray.end_cap_mode = Line2D.LINE_CAP_ROUND
			ray.add_point(pos + rdir * inner)
			ray.add_point(pos + rdir * outer)
			ray.position = Vector2.ZERO
			ray.material = _get_add_mat()
			parent.add_child(ray)
			var twr := ray.create_tween().bind_node(ray)
			twr.tween_interval(0.02)
			twr.tween_property(ray, "modulate:a", 0.0, 0.18)
			twr.tween_callback(func():
				if is_instance_valid(ray):
					ray.material = null
					_release_beam(ray))
	# ③ 外向能量火花:粒子向四面散开(spread 180 径向),区别于激光的上升火星。
	if not motion_reduce and _active_sparks < MAX_SPARKS:
		_active_sparks += 1
		var sp := _acquire_spark_particle()
		if sp != null:
			sp.position = pos
			sp.texture = PARTICLE_TEX_SPARK_ENERGY
			sp.amount = 22
			sp.lifetime = 0.4
			sp.lifetime_randomness = 0.3
			sp.initial_velocity_min = 180.0
			sp.initial_velocity_max = 360.0
			sp.direction = Vector2(0, -1)
			sp.spread = 180.0  # 全方向(径向迸发)
			sp.angle_min = 0.0
			sp.angle_max = 360.0
			sp.gravity = Vector2(0, 35.0)  # v12e: 斜俯视地面感知(60→35),径向电火花不穿透地面
			sp.scale_amount_min = 0.4
			sp.scale_amount_max = 0.7
			sp.color = pcol
			sp.color_ramp = _get_tinted_ramp(pcol)  # P3: 按基色缓存渐变（与激光灼热同构复用）
			sp.emitting = true
			parent.add_child(sp)
			var tree := sp.get_tree()
			if tree != null:
				_connect_deferred_release(tree.create_timer(sp.lifetime + 0.1), sp, _release_spark_particle)
		else:
			_active_sparks -= 1
	# ④ 持续辉光环:慢扩散能量环(重武器余波)
	if not motion_reduce:
		spawn_shockwave(parent, pos, 80.0, Color(pcol.r, pcol.g, pcol.b, 0.5))


## 溅射冲击波环（v8.2：加长到可看清）
static func spawn_shockwave(parent: Node2D, world_pos: Vector2, radius: float, color: Color = Color(1.0, 0.6, 0.2, 0.8), aspect_ratio: float = 2.0) -> void:
	# v17e: 侧视游戏冲击波压扁为椭圆（aspect_ratio > 1 = 横向拉伸）。
	# aspect_ratio=2.0 → 宽度 2× 高度，侧视视角下冲击波明显扁椭圆（非正圆"气球"感）。
	if parent == null or not is_instance_valid(parent):
		return
	var ring := _acquire_ring()
	if ring == null:
		return
	ring.position = world_pos
	_configure_ring_polygon(ring, 8.0, color, aspect_ratio)
	parent.add_child(ring)
	# v12e: 消散感——扩散到 1.22x 半径(向外继续散,不停在固定位置=不"撞墙消失"),
	# alpha 用 ease(开头实→末尾平滑渐淡,非末尾骤淡),duration 0.40→0.52 留尾。
	var tween := ring.create_tween()
	var end_r: float = radius * 1.22
	var base_a: float = color.a
	tween.tween_method(
		func(r: float):
			var t: float = clampf((r - 8.0) / maxf(end_r - 8.0, 1.0), 0.0, 1.0)
			# ease_out_cubic 近似:留尾(前段实,后段渐淡),t^1.6 让淡出更柔
			var a: float = base_a * (1.0 - pow(t, 1.6))
			_configure_ring_polygon(ring, r, Color(color.r, color.g, color.b, a), aspect_ratio),
		8.0, end_r, 0.52)
	tween.tween_callback(func(): _release_ring(ring))


## 闪电链电弧（锯齿线段，主目标→次目标）。v7.4: 改用 beam 池
static func spawn_lightning_arc(parent: Node2D, from_pos: Vector2, to_pos: Vector2, color: Color = Color(0.5, 0.7, 1.0, 1.0)) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var arc := _acquire_beam()
	if arc == null:
		return
	color = _era_tint_energy(color)  # v13: 时代化能量配色(早时代蓝紫→暖/降饱和)
	_spawn_beam_glow(parent, from_pos, to_pos, color, 11.0, 0.28)  # v10: 闪电辉光晕
	arc.width = 2.5
	arc.default_color = color
	arc.joint_mode = Line2D.LINE_JOINT_ROUND
	# 锯齿：在 from→to 之间插 4-5 个带 jitter 的点
	var segs := 5
	arc.add_point(from_pos)
	for i in range(1, segs):
		var t := float(i) / float(segs)
		var pt := from_pos.lerp(to_pos, t)
		# 垂直于方向偏移
		var perp := (to_pos - from_pos).normalized().rotated(PI / 2.0)
		var jitter := randf_range(-14.0, 14.0)
		pt += perp * jitter
		arc.add_point(pt)
	arc.add_point(to_pos)
	arc.position = Vector2.ZERO
	parent.add_child(arc)
	var tween := arc.create_tween()
	tween.tween_property(arc, "modulate:a", 0.0, 0.30)  # v8.2: 0.12→0.30，电弧原太短一闪即逝
	tween.tween_callback(func(): _release_beam(arc))


## ======================================================================
## 内部：三层特效生成
## ======================================================================

## v8.1: 激光命中光束余晖（v8.2：加长淡出到可看清）。v7.4: 改用 beam 池
static func spawn_laser_beam(parent: Node2D, from_pos: Vector2, to_pos: Vector2, color: Color = Color(0.3, 0.8, 1.0, 0.95)) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var beam := _acquire_beam()
	if beam == null:
		return
	color = _era_tint_energy(color)  # v13: 时代化能量配色
	beam.width = 7.0
	beam.default_color = color
	beam.joint_mode = Line2D.LINE_JOINT_ROUND
	beam.end_cap_mode = Line2D.LINE_CAP_ROUND
	_spawn_beam_glow(parent, from_pos, to_pos, color, 24.0, 0.34)  # v10: 激光辉光晕
	beam.add_point(from_pos)
	beam.add_point(to_pos)
	beam.position = Vector2.ZERO
	parent.add_child(beam)
	var tween := beam.create_tween()
	tween.tween_property(beam, "width", 2.0, 0.25)  # v8.2: 0.12→0.25 变细
	tween.parallel().tween_property(beam, "modulate:a", 0.0, 0.30)  # v8.2: 0.14→0.30 淡出
	tween.tween_callback(func(): _release_beam(beam))


## v8.4: 命中贴图爆炸（重型爆炸武器专属）。
## 在 world_pos 处用 Sprite2D 渲染 *_impact.png 贴图，快速放大→缓慢淡出，让爆炸有"形状感"。
## 与 spawn_layered_impact 配合使用：贴图层 + 粒子层叠加（先贴图后粒子）。
## v9.2: ADD 发光混合（爆炸火光感）+ 两层叠加（外层光晕 + 内层主体），真实感对标核武 fireball。
## life: 总生命周期秒（默认 0.45）；scale_peak: 峰值缩放（默认 1.0，调用方按贴图基准像素调整）
static func spawn_impact_sprite(parent: Node2D, world_pos: Vector2, texture: Texture2D, scale_peak: float = 1.0, life: float = 0.45) -> void:
	if parent == null or not is_instance_valid(parent) or texture == null:
		return
	if DT.is_motion_reduce():
		return  # 减动效：跳过贴图层，粒子层已足够
	# v12e: 每次爆炸加随机旋转 + 缩放抖动(±10%),避免每次都轴对齐=死圆/重复。
	# (爆炸贴图非完美对称,旋转能制造变化;即便贴图偏圆,缩放抖动也让大小不死板)
	var rot: float = randf() * TAU
	var sc_jit: float = 0.90 + randf() * 0.22  # 0.90~1.12
	var pk: float = scale_peak * sc_jit
	# v9.2: 第1层——外层光晕（ADD 混合，大尺度低 alpha，模拟爆炸整体火光弥散）
	var glow := _acquire_impact_sprite()
	if glow != null:
		glow.texture = texture
		glow.position = world_pos
		glow.rotation = rot
		glow.scale = Vector2(pk * 1.4, pk * 1.4)
		glow.modulate = Color(1.0, 0.85, 0.6, 0.5)  # 暖白光晕
		glow.visible = true
		glow.material = _get_add_mat()  # ADD 混合让光晕发亮
		parent.add_child(glow)
		glow.add_to_group("battle_vfx")  # v9.4: 战斗结束兜底清理（tween 中断时不残留）
		var tw_glow := glow.create_tween()
		tw_glow.tween_property(glow, "scale", Vector2(pk * 1.8, pk * 1.8), life * 0.5).set_ease(Tween.EASE_OUT)
		tw_glow.parallel().tween_property(glow, "modulate:a", 0.0, life * 0.8).set_ease(Tween.EASE_IN)
		tw_glow.tween_callback(func(): _release_impact_sprite(glow))
	# v9.2: 第2层——主体火球（ADD 混合，快速膨胀→淡出，模拟火球爆炸消散）
	var sprite := _acquire_impact_sprite()
	if sprite == null:
		return  # 池满，静默丢弃（节流）
	sprite.texture = texture
	sprite.position = world_pos
	sprite.rotation = rot + (randf() - 0.5) * 0.6  # 主体与光晕略错开旋转(更不规则)
	sprite.scale = Vector2(pk * 0.5, pk * 0.5)  # 起始小
	sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	sprite.visible = true
	sprite.material = _get_add_mat()  # v9.2: ADD 混合让爆炸有火光明亮感
	parent.add_child(sprite)
	sprite.add_to_group("battle_vfx")  # v9.4: 战斗结束兜底清理（tween 中断时不残留）
	# 快速膨胀到峰值 → 缓慢淡出（模拟爆炸火球膨胀消散）
	var tween := sprite.create_tween()
	tween.tween_property(sprite, "scale", Vector2(pk, pk), life * 0.3).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, life).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): _release_impact_sprite(sprite))


## v9.3c: 大招专属贴图爆炸（敌我双方大招命中演出，对齐核子轰炸表现力）。
## 与 spawn_impact_sprite 的区别：
##   ① 配色染色（tint 参数 lerp 贴图原色，让每类大招有专属色调）
##   ② 前置预警环（命中前 0.15s 收缩环，给玩家反应时间）
##   ③ 更长寿命（大招级 0.8s，普通命中 0.45s）+ 更大尺度
##   ④ 三层叠加（外光晕 + 主体 + 底环），层次更丰富
## 用于敌方 boss active_spells + 我方相位仪 active_ability 的命中瞬间。
## tint: 染色色（如紫色给虚空、橙红给火焰、蓝白给闪电）；Color.WHITE = 不染色保留贴图原色。
## target_width: 主体贴图峰值显示宽度（像素，如护盾 260 / 大招 360）。按贴图分辨率反算 scale，
##   避免 1024px 贴图被当绝对乘数导致溢屏（与 spawn_rising_sprite:737/spawn_ground_burn:687 同范式）。
static func spawn_spell_burst(parent: Node2D, world_pos: Vector2, texture: Texture2D, tint: Color = Color.WHITE, target_width: float = 320.0, life: float = 0.8) -> void:
	if parent == null or not is_instance_valid(parent) or texture == null:
		return
	if DT.is_motion_reduce():
		return
	# v13: 大招级门槛——target_width ≥ 250 才叠"大招四件套"(白闪核/震动/焦痕/烟)。
	# 150~200px 的小技能(护盾/增益)保持轻量，不震屏不留焦痕。
	var is_ult_scale: bool = target_width >= 250.0
	# 按贴图分辨率反算 scale（target_width 是显示像素，不是贴图像素乘数）
	# v17f: 用内容实宽查表（旧版画布宽 1024 → chain_lightning 等窄内容贴图被缩小到目标的 50-80%）
	var tex_w: float = _content_width_of(texture, SPELL_BURST_CONTENT_W)
	var peak_scale: float = target_width / tex_w if tex_w > 0.0 else 1.0
	# 染色色（lerp 贴图原色→tint，0.5 混合保留贴图细节又带专属色调）
	var body_tint: Color = tint if tint == Color.WHITE else Color(tint.r, tint.g, tint.b, 1.0)
	var glow_tint: Color = Color(tint.r, tint.g, tint.b, 0.5) if tint != Color.WHITE else Color(1.0, 0.85, 0.6, 0.5)
	# 前置预警环（0→0.15s 收缩，提示命中位置）——半径跟随 target_width 同比例缩放，大爆炸预警也大
	var warn_r: float = target_width * 0.3  # 预警环半径=目标宽度的30%（护盾78/大招108）
	var warn_ring := _acquire_ring()
	if warn_ring != null:
		warn_ring.position = world_pos
		_configure_ring_polygon(warn_ring, warn_r, Color(body_tint.r, body_tint.g, body_tint.b, 0.7))
		parent.add_child(warn_ring)
		var captured_warn: Polygon2D = warn_ring
		var captured_wtint: Color = body_tint
		var captured_warn_r: float = warn_r
		var tw_warn := warn_ring.create_tween()
		tw_warn.tween_method(func(r: float): _configure_ring_polygon(captured_warn, r, Color(captured_wtint.r, captured_wtint.g, captured_wtint.b, 0.7 * (r / captured_warn_r if captured_warn_r > 0.0 else 0.0))), warn_r, warn_r * 0.33, 0.15)
		tw_warn.tween_callback(func(): _release_ring(captured_warn))
	# 延迟 0.15s 后贴图爆炸（与预警环同步）
	var weak_parent: WeakRef = weakref(parent)
	var captured_pos: Vector2 = world_pos
	var captured_tex: Texture2D = texture
	var captured_body: Color = body_tint
	var captured_glow: Color = glow_tint
	var captured_scale: float = peak_scale
	# v14: tint≠白时改用"亮度保持重着色"shader——modulate 乘法染不动橙红火焰贴图,
	# 虚空/闪电类大招贴图保持橙红被误读为通用爆炸(读图 6/10);shader 按亮度重着色
	var captured_use_shader: bool = tint != Color.WHITE
	var captured_tint_c: Color = Color(tint.r, tint.g, tint.b, 1.0)
	# 底环半径也跟随 target_width（护盾260→底环130，大招360→底环180）
	var captured_ring_r: float = target_width * 0.5
	var tw_delay := parent.create_tween()
	tw_delay.tween_interval(0.15)
	tw_delay.tween_callback(func():
		var p: Node2D = weak_parent.get_ref() as Node2D
		if p == null or not is_instance_valid(p):
			return
		# v13 第0层: 白闪核(大招过曝闪)——先于主体 0.08s，制造"大招级"峰值帧。
		# 小技能不叠(is_ult_scale 门槛)，与普通命中拉开档次。
		if is_ult_scale and _active_impact_sprites < MAX_IMPACT_SPRITES:
			var flash := _acquire_impact_sprite()
			if flash != null:
				flash.texture = PARTICLE_TEX_IMPACT_ENERGY
				flash.position = captured_pos
				flash.scale = Vector2(1.6, 1.6)
				flash.modulate = Color(1.0, 1.0, 1.0, 1.0)
				flash.visible = true
				flash.material = _get_add_mat()
				p.add_child(flash)
				flash.add_to_group("battle_vfx")
				var twf := flash.create_tween().bind_node(flash)
				twf.tween_property(flash, "scale", Vector2(3.0, 3.0), 0.06)
				twf.parallel().tween_property(flash, "modulate:a", 0.0, 0.10)
				twf.tween_callback(func():
					if is_instance_valid(flash):
						flash.material = null
						_release_impact_sprite(flash))
		# v13: 屏幕震动(大招级)——走 combo banner 同款容错查找，无 BattleCamera(展示场)则跳过
		if is_ult_scale:
			var tree_shake := Engine.get_main_loop() as SceneTree
			if tree_shake != null and tree_shake.root != null:
				var cam := tree_shake.root.get_node_or_null("Main/BattleContainer/SubViewportContainer/SubViewport/Battlefield/BattleCamera")
				if cam != null and cam.has_method("shake"):
					cam.call("shake", 6.0, 0.3)
		# 第1层：外光晕（ADD，大尺度低 alpha）
		# v19-R32 超屏修复：终态 ×2.0→×1.5（起点 ×1.5→×1.3）。原×2.0 时光晕宽≈主体2倍
		# （480级大招光晕达960px+，chain_lightning 画布1649px），超出 1280×580 战斗视口上下边。
		var glow := _acquire_impact_sprite()
		if glow != null:
			glow.texture = captured_tex
			glow.position = captured_pos
			glow.scale = Vector2(captured_scale * 1.3, captured_scale * 1.3)
			glow.modulate = Color(1, 1, 1, captured_glow.a) if captured_use_shader else captured_glow
			glow.visible = true
			glow.material = _get_tint_add_mat(captured_tint_c) if captured_use_shader else _get_add_mat()
			p.add_child(glow)
			glow.add_to_group("battle_vfx")
			var tw_g := glow.create_tween()
			tw_g.tween_property(glow, "scale", Vector2(captured_scale * 1.5, captured_scale * 1.5), life * 0.5).set_ease(Tween.EASE_OUT)
			tw_g.parallel().tween_property(glow, "modulate:a", 0.0, life * 0.8).set_ease(Tween.EASE_IN)
			tw_g.tween_callback(func(): _release_impact_sprite(glow))
		# 第2层：主体（ADD，膨胀→淡出，染色）
		var sprite := _acquire_impact_sprite()
		if sprite == null:
			return
		sprite.texture = captured_tex
		sprite.position = captured_pos
		sprite.scale = Vector2(captured_scale * 0.5, captured_scale * 0.5)
		sprite.modulate = Color(1, 1, 1, 1) if captured_use_shader else captured_body
		sprite.visible = true
		sprite.material = _get_tint_add_mat(captured_tint_c) if captured_use_shader else _get_add_mat()
		p.add_child(sprite)
		sprite.add_to_group("battle_vfx")
		var tw_s := sprite.create_tween()
		tw_s.tween_property(sprite, "scale", Vector2(captured_scale, captured_scale), life * 0.3).set_ease(Tween.EASE_OUT)
		tw_s.parallel().tween_property(sprite, "modulate:a", 0.0, life).set_ease(Tween.EASE_IN)
		tw_s.tween_callback(func(): _release_impact_sprite(sprite))
		# 第3层：底环（命中扩散，配色，半径跟随 target_width）
		# v13: 双冲击环(快环+慢环)替代单环——快环紧随爆点收束动量，慢环拉开扩散层次
		spawn_shockwave(p, captured_pos, captured_ring_r * 0.8, Color(captured_body.r, captured_body.g, captured_body.b, 0.85))
		spawn_shockwave(p, captured_pos, captured_ring_r, Color(captured_body.r, captured_body.g, captured_body.b, 0.55))
		# v13 第4层: 持久证据——地面焦痕(大招留下"来过"的痕迹)+ 上升烟柱。
		# 大招和普通命中的本质差：普通命中 0.45s 消散即止；大招打完地上还该有东西。
		if is_ult_scale:
			spawn_ground_burn(p, captured_pos, captured_ring_r * 0.9, 0.25, PARTICLE_TEX_IMPACT_SCORCH)
			if _active_debris < MAX_DEBRIS:
				_active_debris += 1
				var smoke := _acquire_debris_particle()
				if smoke == null:
					_active_debris -= 1
				else:
					smoke.texture = PARTICLE_TEX_SMOKE_GENERIC
					smoke.position = captured_pos
					smoke.lifetime = 0.8
					smoke.amount = 12
					smoke.emission_sphere_radius = 6.0
					smoke.direction = Vector2(0, -1)
					smoke.spread = 55.0
					smoke.initial_velocity_min = 40.0
					smoke.initial_velocity_max = 110.0
					smoke.gravity = Vector2(0, -35.0)
					smoke.scale_amount_min = 1.0
					smoke.scale_amount_max = 2.2
					smoke.color = Color(0.45, 0.42, 0.40, 0.5)
					smoke.color_ramp = _get_smoke_grad(Color(0.45, 0.42, 0.40, 0.5))
					smoke.emitting = true
					p.add_child(smoke)
					var tree_smoke := smoke.get_tree()
					if tree_smoke != null:
						_connect_deferred_release(tree_smoke.create_timer(smoke.lifetime + 0.1), smoke, _release_debris_particle)
	)


## ======================================================================
# v8.5+: 战术核武专用公共 VFX（蘑菇云 / 地面焦痕）
# 蘑菇云移植自 phase_instrument_abilities._spawn_smoke_column（公共化复用），
# 让战术核武机制与相位仪核子轰炸共用同一蘑菇云实现。
## ======================================================================

## 上升烟柱粒子（核爆蘑菇云效果）。移植自 phase_instrument_abilities._spawn_smoke_column。
## CPUParticles2D 向上发射 + ADD 混合 + 底浓顶淡渐变，2.5s 后停发并回收。
## tint 由调用方传入（玩家绿 / 敌方暗红橙 / 中性灰）。
static func spawn_smoke_column(parent: Node2D, pos: Vector2, tint: Color = Color(0.5, 0.5, 0.5, 0.5)) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var p := CPUParticles2D.new()
	p.process_mode = Node.PROCESS_MODE_PAUSABLE  # v9.4: 暂停时冻结（蘑菇云烟柱持续2.4s，不设会暂停时继续飘）
	p.position = pos
	p.amount = 36
	p.lifetime = 2.4
	p.one_shot = false
	p.emitting = true
	p.explosiveness = 0.25
	p.direction = Vector2(0, -1)  # 向上
	p.spread = 30.0  # 蘑菇头扩散
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 110.0
	p.gravity = Vector2(0, -20.0)  # 持续上飘
	p.scale_amount_min = 5.0
	p.scale_amount_max = 11.0
	p.color = tint
	# 烟柱渐变：底部浓→顶部淡（v9.2: 按 tint 颜色缓存 Gradient，避免每次烟柱 new）
	p.color_ramp = _get_smoke_grad(tint)
	# v9.2: 复用共享 ADD 材质（_get_add_mat 已缓存），不再每次 new CanvasItemMaterial
	p.material = _get_add_mat()
	parent.add_child(p)
	p.add_to_group("battle_vfx")  # 战斗结束统一清理（自毁链 2.5s+2.4s，中途结束战斗可能未销毁）
	# 2.5s 后停止发射并回收（WeakRef 防 "Lambda capture was freed"）
	var tree := parent.get_tree()
	if tree == null:
		return
	var timer := tree.create_timer(2.5)
	var weak_p: WeakRef = weakref(p)
	timer.timeout.connect(func():
		var captured_p: Variant = weak_p.get_ref()
		if captured_p == null or not is_instance_valid(captured_p):
			return
		captured_p.emitting = false
		var t2 := tree.create_timer(captured_p.lifetime + 0.1)
		t2.timeout.connect(func():
			var captured_p2: Variant = weak_p.get_ref()
			if captured_p2 != null and is_instance_valid(captured_p2):
				captured_p2.queue_free())
	)


## 地面焦痕（核爆遗留痕迹）。加到 parent，永久持续到战斗结束随场景清理。
## radius: 焦痕半径；fade_in: 初始淡入到目标 alpha 的时间（默认 0.3s，模拟焦痕"烧出来"）。
## texture: 可选焦痕贴图（有则用贴图更逼真，无则回退纯色多边形）。贴图按 radius 缩放到目标尺寸。
static func spawn_ground_burn(parent: Node2D, pos: Vector2, radius: float, fade_in: float = 0.3, texture: Texture2D = null) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	if DT.is_motion_reduce():
		return  # 减动效：跳过永久焦痕（视觉冗余）
	# 焦痕放单位层之下（z_index 负值，地面层），避免盖住单位
	if texture != null:
		# 贴图版焦痕：按 radius 缩放贴图（贴图基准半径=纹理宽度/2，缩放=radius/基准）
		var burn_sprite := Sprite2D.new()
		burn_sprite.position = pos
		burn_sprite.texture = texture
		var base_r: float = float(texture.get_width()) * 0.5
		var s: float = radius / base_r if base_r > 0.0 else 1.0
		burn_sprite.scale = Vector2(s, s)
		burn_sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
		burn_sprite.z_index = -5
		parent.add_child(burn_sprite)
		burn_sprite.add_to_group("battle_vfx")  # 焦痕是永久节点无回收，靠战斗结束统一清理
		if fade_in > 0.0:
			var tween := burn_sprite.create_tween()
			tween.tween_property(burn_sprite, "modulate:a", 0.85, fade_in)
		else:
			burn_sprite.modulate.a = 0.85
	else:
		# 纯色多边形版（无贴图回退）
		var burn := Polygon2D.new()
		burn.position = pos
		# 32 段实心圆（焦痕不需要空心环）
		var segments := 32
		var pts := PackedVector2Array()
		for i in range(segments):
			var ang := (TAU * i) / segments
			pts.append(Vector2(cos(ang), sin(ang)) * radius)
		burn.polygon = pts
		burn.color = Color(0.08, 0.04, 0.02, 0.0)  # 起始透明，淡入到目标 alpha
		# 焦痕放单位层之下（z_index 负值，地面层），避免盖住单位
		burn.z_index = -5
		parent.add_child(burn)
		burn.add_to_group("battle_vfx")  # 焦痕是永久节点无回收，靠战斗结束统一清理
		if fade_in > 0.0:
			var tween := burn.create_tween()
			tween.tween_property(burn, "color:a", 0.55, fade_in)
		else:
			burn.color.a = 0.55


## ======================================================================
# v13: 战场痕迹系统(焦痕/弹坑/残骸)
# Phase2 真实战斗审计:地面"太干净"(战场痕迹 2-3/10)。重型爆炸命中/单位死亡
# 留下池化地面痕,ring buffer 上限复用最旧;~14s 后 4s 缓慢淡出(能累积不无限堆)。
## ======================================================================
static var _trace_nodes: Array = []
static var _trace_cursor: int = 0
const MAX_TRACES: int = 48
const TRACE_TEX_BASE_R: float = 32.0  # impact_scorch 贴图基准半径(64px/2)

## kind: "scorch"(重型命中弹坑焦痕) / "wreck"(单位阵亡残骸印记,更大更暗)
static func spawn_battle_trace(parent: Node2D, world_pos: Vector2, radius: float, kind: String = "scorch") -> void:
	if parent == null or not is_instance_valid(parent):
		return
	if DT.is_motion_reduce():
		return
	var node: Sprite2D = null
	if _trace_nodes.size() < MAX_TRACES:
		node = Sprite2D.new()
		node.texture = PARTICLE_TEX_IMPACT_SCORCH
		node.z_index = -4  # 地面层,单位之下(核爆焦痕 -5 之上)
		node.visible = false
		_trace_nodes.append(node)
	else:
		var idx: int = _trace_cursor % MAX_TRACES
		_trace_cursor = (_trace_cursor + 1) % MAX_TRACES
		# 池内节点可能随旧战场一起被 free(静态数组持失效引用)。
		# 对已释放对象做 "as Sprite2D" 转型会直接报错——必须先 is_instance_valid 再转型。
		var pooled: Variant = _trace_nodes[idx]
		if typeof(pooled) == TYPE_OBJECT and is_instance_valid(pooled) and pooled is Sprite2D:
			node = pooled
		if node == null:
			node = Sprite2D.new()
			node.texture = PARTICLE_TEX_IMPACT_SCORCH
			node.z_index = -4
			node.visible = false
			_trace_nodes[idx] = node
	# 复用节点可能挂在别的战场父节点下——reparent 到当前
	if node.get_parent() != parent:
		if node.get_parent() != null:
			node.reparent(parent)
		else:
			parent.add_child(node)
	# 杀旧 tween,重新安排生命周期(0.18s 烧出 → 14s 保持 → 4s 淡出)
	# Godot 4.5: get_meta 带默认值仍会对缺失 key 打 ERROR——先 has_meta 守卫
	if node.has_meta("_trace_tw"):
		var old_tw: Variant = node.get_meta("_trace_tw")
		if old_tw is Tween:
			(old_tw as Tween).kill()
	var sc: float = radius / TRACE_TEX_BASE_R
	node.position = world_pos
	node.rotation = randf() * TAU
	node.scale = Vector2(sc, sc) * (0.9 + randf() * 0.25)
	node.visible = true
	var is_wreck: bool = kind == "wreck"
	node.modulate = Color(0.10, 0.08, 0.06, 0.0) if is_wreck else Color(0.16, 0.12, 0.08, 0.0)
	var peak_a: float = 0.55 if is_wreck else 0.42
	var tw := node.create_tween()
	tw.tween_property(node, "modulate:a", peak_a, 0.18)
	tw.tween_interval(14.0)
	tw.tween_property(node, "modulate:a", 0.0, 4.0)
	tw.tween_callback(func():
		if is_instance_valid(node):
			node.visible = false)
	node.set_meta("_trace_tw", tw)


## ======================================================================
# v13: 时代化能量配色
# Phase2 审计:冷战关出现蓝紫能量特效违和(读图 6/10)。一战/二战的蓝紫能量色
# 转暖橙白(读作燃烧/曳光),冷战降饱和 30%;现代/近未来保持原色。
# 仅战斗中生效(BattleManager.battle_active),vfx_showcase 展示场不受影响。
## ======================================================================
static var _era_cache: int = -2      # -2=未查, -1=非战斗(不调色)
static var _era_check_msec: int = -1

static func _current_battle_era() -> int:
	var now := Time.get_ticks_msec()
	if _era_check_msec > 0 and now - _era_check_msec < 2000:
		return _era_cache
	_era_cache = -1
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var bm: Node = tree.root.get_node_or_null("BattleManager")
		if bm != null and bool(bm.get("battle_active")):
			var gm: Node = tree.root.get_node_or_null("GameManager")
			if gm != null:
				var lvl: int = int(gm.get("current_level"))
				if lvl > 0:
					_era_cache = GC.get_era_for_level(lvl)
	_era_check_msec = now
	return _era_cache

## 高饱和蓝/紫/青能量色按时代重映射;暖色与低饱和色(白热核心)原样放行。
static func _era_tint_energy(c: Color) -> Color:
	var era := _current_battle_era()
	if era < 0 or era > 2:
		return c  # 非战斗 / 现代(3) / 近未来(4):不调
	var s := c.s
	if s < 0.22:
		return c  # 近白/灰不调(白热核心保持)
	var h := c.h
	if h < 0.46 or h > 0.90:
		return c  # 暖色(橙红黄)放行
	if era <= 1:
		# 一战/二战:蓝紫 → 暖橙白(转色相到橙,降饱和,提亮)
		return Color.from_hsv(0.07, s * 0.55, minf(c.v * 1.08, 1.0), c.a)
	# 冷战:降饱和 30% 微降亮度(早期能量武器"实验感")
	return Color.from_hsv(h, s * 0.7, c.v * 0.95, c.a)


## 上升贴图精灵（蘑菇云贴图版）：放大+上飘+淡出，区别于 spawn_impact_sprite 的纯放大。
## target_width: 蘑菇云峰值宽度（像素，默认 320）——按贴图原始像素反算 scale，避免贴图分辨率不同时尺寸失控。
## rise: 上飘距离（像素）；life: 总生命周期。
## 普通混合（非 ADD）——蘑菇云是烟尘实体不是发光体，ADD 会让它过曝失去形状。
static func spawn_rising_sprite(parent: Node2D, pos: Vector2, texture: Texture2D, target_width: float = 320.0, rise: float = 120.0, life: float = 1.4) -> void:
	if parent == null or not is_instance_valid(parent) or texture == null:
		return
	if DT.is_motion_reduce():
		return
	var sprite := _acquire_impact_sprite()
	if sprite == null:
		return
	sprite.texture = texture
	sprite.position = pos
	# 按目标像素宽度反算 scale（贴图分辨率不同时尺寸一致）
	var tex_w: float = float(texture.get_width())
	var peak_scale: float = target_width / tex_w if tex_w > 0.0 else 1.0
	var start_scale: float = peak_scale * 0.4  # 起始 40% 大小，放大到峰值
	sprite.scale = Vector2(start_scale, start_scale)
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.95)
	sprite.visible = true
	# 普通混合（不 ADD）——保留蘑菇云形状的明暗细节
	parent.add_child(sprite)
	sprite.add_to_group("battle_vfx")  # v9.4: 战斗结束兜底清理（life 1.4s 可能跨战斗结束残留）
	# 放大到峰值 + 上飘 + 淡出（模拟蘑菇云升腾消散）
	var tween := sprite.create_tween()
	tween.parallel().tween_property(sprite, "scale", Vector2(peak_scale, peak_scale), life * 0.5).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "position:y", pos.y - rise, life).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, life).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		_release_impact_sprite(sprite))


## 蘑菇云帧动画版（核爆专用）：用 AI 生成的精灵表切割出的多帧，AnimatedSprite2D 逐帧播放。
## 比 spawn_rising_sprite（单 sprite + tween 缩放）更流畅震撼——每帧都是 AI 画的不同成长阶段。
## frame_textures: 帧贴图数组（ Texture2D[]，按时间顺序）；空或 null 回退 false 让调用方用单 sprite。
## target_width: 峰值宽度（像素）；rise: 上飘距离；fps: 帧率（8fps × 9帧 ≈ 1.1s）。
## 成功创建 AnimatedSprite2D 返回 true；帧贴图不足返回 false（调用方回退 spawn_rising_sprite）。
static func spawn_animated_nuclear(parent: Node2D, pos: Vector2, frame_textures: Array, target_width: float = 320.0, rise: float = 120.0, fps: float = 8.0) -> bool:
	if parent == null or not is_instance_valid(parent):
		return false
	if frame_textures == null or frame_textures.size() < 2:
		return false  # 帧数不足，调用方回退单 sprite
	if DT.is_motion_reduce():
		return false  # 减动效：回退单 sprite（帧动画细节多，减动效不需要）
	# 按第一帧贴图分辨率反算 scale（所有帧应同分辨率）
	var first_tex: Texture2D = frame_textures[0]
	var tex_w: float = float(first_tex.get_width())
	var peak_scale: float = target_width / tex_w if tex_w > 0.0 else 1.0
	# 代码建 SpriteFrames（VFX 是临时节点，代码建比 .tres 灵活，不占资源树）
	var frames := SpriteFrames.new()
	frames.add_animation("grow")
	frames.set_animation_loop("grow", false)  # 播完自动停（非循环）
	frames.set_animation_speed("grow", fps)
	for i in frame_textures.size():
		var tex: Texture2D = frame_textures[i]
		if tex != null:
			frames.add_frame("grow", tex)
	# 创建 AnimatedSprite2D
	var anim := AnimatedSprite2D.new()
	anim.sprite_frames = frames
	anim.position = pos
	anim.scale = Vector2(peak_scale, peak_scale)
	# v11: 蘑菇云帧本身仅 33-44% 不透明(灰烟),提亮 modulate 让烟柱在战场上清晰可辨(原 1.0 太暗被吞)
	anim.modulate = Color(1.35, 1.3, 1.25, 1.0)
	anim.z_index = 30  # 蘑菇云盖在单位上方
	anim.play("grow")
	parent.add_child(anim)
	anim.add_to_group("battle_vfx")  # ~1s 自毁，可能跨清场，战斗结束统一兜底清理
	# 总时长 = 帧数 / fps
	var life: float = float(frame_textures.size()) / fps
	# v11 修复:生长期间保持完全不透明,【生长完成后】才淡出。原代码边长边淡(EASE_IN),
	# 导致蘑菇云永远到不了"完全成型且可见"的状态——展示场峰值帧拍到的是近乎透明的空景。
	var tween := anim.create_tween()
	tween.tween_property(anim, "position:y", pos.y - rise, life).set_ease(Tween.EASE_OUT)  # 上飘(生长期间不透明)
	tween.tween_property(anim, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN)  # 生长完成后才淡出
	# 播完销毁（帧动画不进对象池——核爆 CD 45s 频率低，new 节点无性能压力）
	tween.tween_callback(func():
		if is_instance_valid(anim):
			anim.queue_free())
	return true


## 能量光柱（核子轰炸专用，替代蘑菇云）。从天而降的垂直能量束打击命中点。
## 与 spawn_rising_sprite（蘑菇云向上）方向相反——能量武器=从天而降，核武器=地面升腾。
## 实现一条从高空降落到命中点的 Line2D 光束 + ADD 混合发光 + 快速收缩消散。
static func spawn_energy_pillar(parent: Node2D, pos: Vector2, color: Color = Color(0.5, 0.6, 1.0, 0.7), height: float = 400.0, life: float = 0.6) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	if DT.is_motion_reduce():
		return
	color = _era_tint_energy(color)  # v13: 时代化能量配色
	var beam := _acquire_beam()
	if beam == null:
		return
	beam.width = 18.0
	beam.default_color = color
	beam.joint_mode = Line2D.LINE_JOINT_ROUND
	beam.end_cap_mode = Line2D.LINE_CAP_ROUND
	# 从命中点正上方 height 高度降落到命中点（垂直能量束）
	_spawn_beam_glow(parent, Vector2(pos.x, pos.y - height), pos, color, 46.0, life)  # v10: 加宽辉光(原仅 width18 细线)
	beam.add_point(Vector2(pos.x, pos.y - height))
	beam.add_point(pos)
	beam.position = Vector2.ZERO
	# ADD 混合发光（与蘑菇云 spawn_smoke_column 同 blend 模式，能量武器感）
	beam.material = _get_add_mat()
	parent.add_child(beam)
	# 光束快速变细 + 淡出（能量打击瞬间消散，非持续燃烧）
	var tween := beam.create_tween()
	tween.tween_property(beam, "width", 3.0, life * 0.5)
	tween.parallel().tween_property(beam, "modulate:a", 0.0, life)
	tween.tween_callback(func():
		beam.material = null  # 清理材质引用（_add_mat 是共享缓存，不 free）
		_release_beam(beam))


## v9.3: 召唤传送门（敌方召唤类大招专用）。
## 程序化螺旋光环：三层同心环，从大收缩到小 + 旋转 + 淡出，模拟"传送门开门/关闭"。
## 复用 ring 池（与冲击波环同池），零新节点类型。duration: 总持续秒（默认 0.9）。
static func spawn_summon_portal(parent: Node2D, pos: Vector2, color: Color = Color(0.7, 0.3, 1.0, 0.9), duration: float = 0.9) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	if DT.is_motion_reduce():
		return
	# 三层同心环（外/中/内），各自不同起始半径和延迟，形成层次感
	for layer in range(3):
		var ring := _acquire_ring()
		if ring == null:
			continue
		var start_r: float = 110.0 - float(layer) * 28.0  # 外110/中82/内54
		ring.position = pos
		_configure_ring_polygon(ring, start_r, color)
		parent.add_child(ring)
		var layer_delay: float = float(layer) * 0.08
		var captured_ring: Polygon2D = ring
		var captured_color: Color = color
		var captured_start: float = start_r
		var tw := ring.create_tween()
		tw.tween_interval(layer_delay)
		# 收缩到中心 + 旋转 + 淡出（半径缩小时 alpha 按比例衰减）
		tw.tween_method(func(r: float): _configure_ring_polygon(captured_ring, r, Color(captured_color.r, captured_color.g, captured_color.b, captured_color.a * (r / captured_start if captured_start > 0.0 else 0.0))), start_r, 16.0, duration - layer_delay)
		tw.parallel().tween_property(ring, "rotation", TAU * 0.8, duration - layer_delay)
		tw.tween_callback(func(): _release_ring(captured_ring))


## v9.5: 通用大招弹道飞行体（让大招有"飞过来"的过程，更写实）。
## 基于 _spawn_nuclear_missile（战术核武导弹）范式，扩展为支持多种轨迹类型。
## trajectory: "vertical"=垂直从天而降（陨石/轨道弹/神罚） | "arc"=贝塞尔弧线（核导弹/曲射） | "dive"=低空俯冲（空投燃烧弹）
## texture: 飞行体贴图（缺失回退 laser_beam 线段，保证弹道可见）
## target_width: 飞行体显示宽度（像素，按贴图分辨率反算 scale，与 spawn_spell_burst 同范式）
## tint: 飞行体染色（不同大招专属配色）；Color.WHITE=保留贴图原色
## trail_color: 拖尾颜色（飞行时尾部跟随的发光线段，None=无拖尾）
## on_arrival: 可选回调（飞行到达时触发，供调用方接爆炸特效/伤害结算）
## 返回飞行总时长（秒），调用方据此延迟后续结算（避免"敌人先死、弹还在飞"）。
## v17f: 大招弹体/爆炸贴图内容宽查表（PIL 实测 getbbox，画布均 1024）。
## 根因：spawn_ultimate_projectile/spawn_spell_burst 的 mscale 用画布宽 1024 标定，
## 但内容只占画布 12-46% → 弹体实际显示 12-29px（目标 40-64px），一根细线几乎不可见。
## 新增贴图必须先量实寸再补录本表（vfx-tuning skill 第 2 步铁律）。
const ULT_PROJ_CONTENT_W: Dictionary = {
	"ult_meteor": 330.0,
	"ult_void_orb": 464.0,
	"ult_orbital": 195.0,
	"ult_inferno_bomb": 263.0,
	"ult_divine_spear": 317.0,
	"ult_nuke_player": 988.0,   # v19-R32 补录（核子轰炸弹体，原回退画布1024略偏小）
}
const SPELL_BURST_CONTENT_W: Dictionary = {
	"apocalypse_meteor": 856.0,
	"apocalypse_void": 936.0,
	"inferno_hell": 985.0,
	"chain_lightning": 497.0,
	"summon_portal": 903.0,
	"debuff_dark": 923.0,
	# v19-R32 补录（PIL getbbox 实测；原回退画布1024，player系约偏小10%）
	"player_barrage": 890.0,
	"player_fortress": 904.0,
	"player_rage": 883.0,
	"player_shield": 916.0,
}

## v17f: 按贴图资源路径查内容宽（未收录回退画布宽，行为同旧版）。
static func _content_width_of(texture: Texture2D, table: Dictionary) -> float:
	if texture == null:
		return 0.0
	var path: String = texture.resource_path
	if not path.is_empty():
		var fname: String = path.get_file().get_basename()
		if table.has(fname):
			return float(table[fname])
	return float(texture.get_width())

static func spawn_ultimate_projectile(parent: Node2D, from: Vector2, target: Vector2, texture: Texture2D, trajectory: String = "vertical", target_width: float = 48.0, tint: Color = Color.WHITE, trail_color: Color = Color(1.0, 0.8, 0.3, 0.9), flight_time: float = 0.5, on_arrival: Callable = Callable()) -> float:
	if parent == null or not is_instance_valid(parent):
		return 0.0
	if DT.is_motion_reduce():
		# 减动效：跳过飞行，直接触发到达回调（保持伤害时序，只省视觉）
		if on_arrival.is_valid():
			on_arrival.call(target)
		return 0.0
	# 无贴图回退：用激光线段表示弹道（保证"有东西飞过来"的视觉）
	if texture == null:
		var beam_color: Color = tint if tint != Color.WHITE else Color(1.0, 0.9, 0.4, 1.0)
		VfxImpactFactory.spawn_laser_beam(parent, from, target, beam_color)
		if on_arrival.is_valid():
			var tw_fb := parent.create_tween()
			tw_fb.tween_interval(flight_time)
			tw_fb.tween_callback(func(): on_arrival.call(target))
		return flight_time
	# 创建飞行体 Sprite2D
	var missile := Sprite2D.new()
	missile.texture = texture
	# v17f: 按内容实宽标定（旧版用画布宽 1024 → 弹体只显示目标的 12-46%，细线不可见）
	var tex_w: float = _content_width_of(texture, ULT_PROJ_CONTENT_W)
	var mscale: float = target_width / tex_w if tex_w > 0.0 else 0.05
	missile.scale = Vector2(mscale, mscale)
	missile.modulate = tint
	missile.global_position = from
	missile.z_index = 50  # 盖在单位上方，飞行时清晰可见
	parent.add_child(missile)
	missile.add_to_group("battle_vfx")  # 战斗结束兜底清理
	# 按轨迹类型计算贝塞尔控制点
	var apex: Vector2
	match trajectory:
		"vertical":
			# 垂直下落：起点在目标正上方高空，apex 在起点→目标连线的上 1/3（轻微弧度，主要垂直）
			apex = Vector2(target.x, from.y)  # 先水平对齐再垂直下落
		"dive":
			# 低空俯冲：浅弧度（空投燃烧弹，从侧方低空飞入）
			apex = Vector2((from.x + target.x) / 2.0, min(from.y, target.y) - 60.0)
		_:  # "arc" 默认
			# 标准贝塞尔弧：中点上方抬升（像炮弹/导弹抛物线）
			apex = Vector2((from.x + target.x) / 2.0, min(from.y, target.y) - 160.0)
	# 拖尾线段（飞行时跟随，ADD 发光，强化"飞行感"）
	# v17g: 单线 6px→主线 12px + 辉光线 26px 双层（AI 批"拖尾单薄"——boss 大招弹体的
	# 拖尾要有体量，单细线像缝衣针；双层=锐利核心+弥散辉光，保留 ADD）。
	var has_trail: bool = trail_color.a > 0.0
	var trail_beam: Line2D = null
	var trail_glow: Line2D = null
	if has_trail:
		trail_beam = _acquire_beam()
		if trail_beam != null:
			trail_beam.width = 12.0
			trail_beam.default_color = trail_color
			trail_beam.joint_mode = Line2D.LINE_JOINT_ROUND
			trail_beam.end_cap_mode = Line2D.LINE_CAP_ROUND
			trail_beam.material = _get_add_mat()
			parent.add_child(trail_beam)
		trail_glow = _acquire_beam()
		if trail_glow != null:
			trail_glow.width = 26.0
			trail_glow.default_color = Color(trail_color.r, trail_color.g, trail_color.b, 0.30)
			trail_glow.joint_mode = Line2D.LINE_JOINT_ROUND
			trail_glow.end_cap_mode = Line2D.LINE_CAP_ROUND
			trail_glow.material = _get_add_mat()
			parent.add_child(trail_glow)
	# 贝塞尔飞行 + 朝向旋转 + 拖尾更新
	var prev_pt: Vector2 = from
	var captured_missile: Sprite2D = missile
	var captured_trail: Line2D = trail_beam
	var captured_trail_glow: Line2D = trail_glow
	var captured_from: Vector2 = from
	var captured_apex: Vector2 = apex
	var captured_target: Vector2 = target
	var captured_arrival: Callable = on_arrival
	var tw := parent.create_tween()
	tw.tween_method(func(progress: float):
		if not is_instance_valid(captured_missile):
			return
		var t: float = progress
		var q0 := captured_from.lerp(captured_apex, t)
		var q1 := captured_apex.lerp(captured_target, t)
		var pt := q0.lerp(q1, t)
		captured_missile.global_position = pt
		# 朝向飞行方向
		# v17f: 竖直贴图约定（头朝 +Y 即画面下方）——rotation=dir.angle() 把贴图 +X 对准
		# 飞行方向，竖贴图会被转成横躺。偏移 -PI/2 让贴图 +Y（弹头）对准飞行方向：
		# vertical(0,1)→rot=0 头朝下 ✓；dive(1,1)→rot=-π/4 头朝右下 ✓。
		var dir := pt - prev_pt
		if dir.length() > 0.5:
			captured_missile.rotation = dir.angle() - PI / 2.0
		prev_pt = pt
		# 更新拖尾（从飞行体后方延伸；主线 24px + 辉光 44px 更长，层次感）
		if captured_trail != null and is_instance_valid(captured_trail):
			captured_trail.clear_points()
			captured_trail.add_point(pt - dir.normalized() * 26.0)
			captured_trail.add_point(pt)
		if captured_trail_glow != null and is_instance_valid(captured_trail_glow):
			captured_trail_glow.clear_points()
			captured_trail_glow.add_point(pt - dir.normalized() * 46.0)
			captured_trail_glow.add_point(pt)
	, 0.0, 1.0, flight_time)
	# 到达：移除飞行体 + 回收拖尾 + 触发回调
	tw.tween_callback(func():
		if is_instance_valid(captured_missile):
			captured_missile.queue_free()
		if captured_trail != null and is_instance_valid(captured_trail):
			captured_trail.material = null
			_release_beam(captured_trail)
		if captured_trail_glow != null and is_instance_valid(captured_trail_glow):
			captured_trail_glow.material = null
			_release_beam(captured_trail_glow)
		if captured_arrival.is_valid():
			captured_arrival.call(captured_target))
	return flight_time


## 完整局部核爆效果（火球+冲击波+蘑菇云帧动画+焦痕）。
## 供战术核武（单点）和核子轰炸（多点循环）共用同一套核爆视觉。
## textures: 预加载的核爆贴图包 {"fireball":Tex, "shockwave":Tex, "burn":Tex, "mushroom_frames":Tex[]}
##   缺失的贴图自动跳过对应层（部分核爆仍可见）；mushroom_frames 空则蘑菇云回退单 sprite
## colors: 配色 {"shock":C, "aftershock":C, "smoke":C}
## 全屏闪白/震屏/标题等全局效果不在此方法——由调用方按需触发（多点时只触发一次）。
## 完整局部核爆效果（火球+冲击波+蘑菇云帧动画+焦痕）。
## 供战术核武（单点）和核子轰炸（多点循环）共用同一套核爆视觉。
## textures: 预加载的核爆贴图包 {"fireball":Tex, "shockwave":Tex, "burn":Tex, "mushroom_frames":Tex[]}
##   缺失的贴图自动跳过对应层（部分核爆仍可见）；mushroom_frames 空则蘑菇云回退单 sprite
## colors: 配色 {"shock":C, "aftershock":C, "smoke":C}
## size_scale: 整体尺寸缩放（1.0=战术核武完整尺寸；核子轰炸多点用 0.6 缩小，避免半径覆盖到己方）
## 全屏闪白/震屏/标题等全局效果不在此方法——由调用方按需触发（多点时只触发一次）。
static func spawn_nuclear_explosion(parent: Node2D, pos: Vector2, textures: Dictionary, colors: Dictionary, size_scale: float = 1.0) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var shock_color: Color = colors.get("shock", Color(1.0, 0.85, 0.5, 0.9))
	var aftershock_color: Color = colors.get("aftershock", Color(0.9, 0.5, 0.2, 0.5))
	var smoke_tint: Color = colors.get("smoke", Color(0.35, 0.32, 0.30, 0.6))
	# 尺寸缩放（核子轰炸多点用 0.6，避免余波环覆盖到靠近的我方单位）
	# v19-R32 超屏修复：after_radius 320→240（aspect 2.0 椭圆纵向 2×radius×1.22 扩散，
	# 原 320 达 781px 超出 580 视口高；240→586px 贴边，横向 1171px 不超宽）
	var fireball_scale: float = 0.35 * size_scale
	var shockwave_tex_scale: float = 0.30 * size_scale
	var main_radius: float = 200.0 * size_scale
	var after_radius: float = 240.0 * size_scale
	var mushroom_w: float = 400.0 * size_scale
	var mushroom_rise: float = 140.0 * size_scale
	var burn_radius: float = 90.0 * size_scale
	# v10: t=0 瞬时强光闪(报告:核爆缺电磁脉冲闪光)——大尺度 ADD 白黄光斑 0.18s 衰减
	var flash_tex: Texture2D = textures.get("fireball", null)
	if flash_tex != null and _active_impact_sprites < MAX_IMPACT_SPRITES:
		var nuke_flash := _acquire_impact_sprite()
		if nuke_flash != null:
			nuke_flash.texture = flash_tex
			nuke_flash.position = pos
			nuke_flash.scale = Vector2(size_scale * 1.0, size_scale * 1.0)  # v19-R32 超屏修复：原×2.0→1024贴图最大2048px超屏
			nuke_flash.modulate = Color(1.0, 0.95, 0.82, 0.92)
			nuke_flash.visible = true
			nuke_flash.material = _get_add_mat()
			parent.add_child(nuke_flash)
			nuke_flash.add_to_group("battle_vfx")
			var twf := nuke_flash.create_tween()
			twf.tween_property(nuke_flash, "modulate:a", 0.0, 0.18).set_ease(Tween.EASE_OUT)
			twf.tween_callback(func():
				if is_instance_valid(nuke_flash):
					nuke_flash.material = null
					_release_impact_sprite(nuke_flash))
	# ①火球贴图
	var fireball_tex: Texture2D = textures.get("fireball", null)
	if fireball_tex != null:
		spawn_impact_sprite(parent, pos, fireball_tex, fireball_scale, 0.4)
	# ②主冲击波：贴图 + 程序化环叠加
	var shockwave_tex: Texture2D = textures.get("shockwave", null)
	if shockwave_tex != null:
		spawn_impact_sprite(parent, pos, shockwave_tex, shockwave_tex_scale, 0.45)
	spawn_shockwave(parent, pos, main_radius, shock_color)
	# ③余波环（延迟 0.08s）
	var after_tw := parent.create_tween()
	after_tw.tween_interval(0.08)
	after_tw.tween_callback(func():
		if is_instance_valid(parent):
			spawn_shockwave(parent, pos, after_radius, aftershock_color))
	# ④蘑菇云：优先帧动画，失败回退单 sprite
	var mushroom_frames: Array = textures.get("mushroom_frames", [])
	var mushroom_played: bool = false
	if not mushroom_frames.is_empty():
		mushroom_played = spawn_animated_nuclear(parent, pos, mushroom_frames, mushroom_w, mushroom_rise, 8.0)
	if not mushroom_played:
		var mushroom_tex: Texture2D = textures.get("mushroom", null)
		if mushroom_tex != null:
			spawn_rising_sprite(parent, pos, mushroom_tex, mushroom_w, mushroom_rise, 1.4)
	spawn_smoke_column(parent, pos, smoke_tint)
	# ⑤地面焦痕（贴图版，缺失回退纯色多边形）
	var burn_tex: Texture2D = textures.get("burn", null)
	spawn_ground_burn(parent, pos, burn_radius, 0.3, burn_tex)


## ======================================================================
## v8.4: 武器类改造专属视觉（变体叠加层）
## 在基础三层特效之上，为 5 种武器类改造叠加独有的视觉特征：
##   cluster     — 子母弹：主爆炸 + 6 个随机散布的小溅射点（子弹药撒布）
##   thermobaric — 温压弹：超大冲击波 + 0.15s 后二次爆炸（温压二次燃烧）
##   proximity   — 近炸引信：高空环 + 向下火花锥（空爆闪光）
##   guided      — 制导炮弹：精准命中指示环（快速收缩同心环）
##   gun_missile — 炮射导弹：蓝白拖尾火花锥（区分标准导弹的橙红）
## 所有变体复用现有 ring/spark 池，motion_reduce 时只保留最简特征。
## ======================================================================
static func spawn_variant_overlay(parent: Node2D, world_pos: Vector2, weapon_type: int, variant: String, is_player: bool) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	match variant:
		"cluster":
			_spawn_cluster_burst(parent, world_pos, is_player)
		"thermobaric":
			_spawn_thermobaric_blast(parent, world_pos, is_player)
		"proximity":
			_spawn_proximity_airburst(parent, world_pos, is_player)
		"guided":
			_spawn_guided_indicator(parent, world_pos, is_player)
		"gun_missile":
			_spawn_gun_missile_trail(parent, world_pos, is_player)


## 子母弹：主爆炸周围撒布 6 个小溅射点（子弹药分离）
static func _spawn_cluster_burst(parent: Node2D, pos: Vector2, is_player: bool) -> void:
	if DT.is_motion_reduce():
		return  # 减动效：跳过子弹药撒布
	# 6 个围绕主爆点的小溅射，半径 30-55px 随机散布
	for i in range(6):
		var angle: float = (TAU * i) / 6.0 + randf_range(-0.3, 0.3)
		var dist: float = randf_range(30.0, 55.0)
		var sub_pos: Vector2 = pos + Vector2(cos(angle), sin(angle)) * dist
		# 每个子弹药一个小环 + 少量火花（复用基础特效，武器类型用 ROCKET=3 的配方）
		spawn_layered_impact(parent, sub_pos, 3, is_player, -1)


## 温压弹：超大冲击波（半径×1.5）+ 延迟二次爆炸
static func _spawn_thermobaric_blast(parent: Node2D, pos: Vector2, is_player: bool) -> void:
	# 超大冲击波（橙红，半径 130）
	var blast_color: Color = Color(1.0, 0.4, 0.1, 0.9)
	spawn_shockwave(parent, pos, 130.0, blast_color)
	if DT.is_motion_reduce():
		return  # 减动效：跳过二次爆炸
	# 延迟 0.15s 后二次爆炸（温压弹的持续燃烧特性）
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var weak_parent: WeakRef = weakref(parent)
	tree.create_timer(0.15).timeout.connect(func():
		if not is_instance_valid(weak_parent.get_ref()):
			return
		var captured_parent: Node2D = weak_parent.get_ref() as Node2D
		if captured_parent == null:
			return
		spawn_layered_impact(captured_parent, pos, 3, is_player, -1)
	)


## 近炸引信：高空环 + 向下火花锥（空爆闪光，区别于地面爆炸）
static func _spawn_proximity_airburst(parent: Node2D, pos: Vector2, is_player: bool) -> void:
	# 空爆闪光环（白色，比地面爆炸更亮更快）
	var airburst_color: Color = Color(1.0, 0.85, 0.5, 0.85)
	spawn_shockwave(parent, pos, 70.0, airburst_color)
	if DT.is_motion_reduce():
		return
	# 向下火花锥（模拟破片向下散布击中下方目标）
	if _active_sparks >= MAX_SPARKS:
		return
	_active_sparks += 1
	var p := _acquire_spark_particle()
	if p == null:
		_active_sparks -= 1
		return
	# v9.2: 空爆火花用金属贴图（池复用需显式赋值）
	p.texture = PARTICLE_TEX_SPARK_METAL
	p.position = pos + Vector2(0, -10)  # v8.4: 用 position（与工厂惯例一致，pos 已是 world 坐标）
	p.amount = 16
	p.lifetime = 0.40
	p.direction = Vector2.DOWN
	p.spread = 60.0  # 向下锥形
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 200.0
	p.gravity = Vector2(0, 150)
	p.color = Color(1.0, 0.8, 0.4, 1.0)
	p.color_ramp = _get_spark_ramp(p.color)  # v8.4: 与 _spawn_sparks 一致，设色带避免池复用残留
	# v9.2: 空爆火花贴图化缩小
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	parent.add_child(p)
	var tree := p.get_tree()
	if tree != null:
		# v7.5 同款：用 _connect_deferred_release 避免 "Lambda capture was freed" 运行时错误
		var timer := tree.create_timer(p.lifetime + 0.1)
		_connect_deferred_release(timer, p, _release_spark_particle)


## 制导炮弹：精准命中指示环（两层快速收缩同心环）
static func _spawn_guided_indicator(parent: Node2D, pos: Vector2, is_player: bool) -> void:
	if DT.is_motion_reduce():
		return
	# 外环（青色，快速收缩 → 精准点）
	var outer := _acquire_ring()
	if outer != null:
		outer.position = pos
		_configure_ring_polygon(outer, 50.0, Color(0.4, 0.9, 1.0, 0.7))
		parent.add_child(outer)
		var tw1 := outer.create_tween()
		tw1.tween_method(func(r: float): _configure_ring_polygon(outer, r, Color(0.4, 0.9, 1.0, 0.7 * (r / 50.0))), 50.0, 8.0, 0.25)
		tw1.tween_callback(func(): _release_ring(outer))
	# 内环（延迟 0.08s，更小更快 → 强化"锁定"感）
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree:
		var weak_parent: WeakRef = weakref(parent)
		var captured_pos: Vector2 = pos  # 值类型，lambda 直接捕获安全
		tree.create_timer(0.08).timeout.connect(func():
			var wp: Node2D = weak_parent.get_ref() as Node2D
			if wp == null or not is_instance_valid(wp):
				return
			var inner := _acquire_ring()
			if inner == null:
				return
			inner.position = captured_pos
			_configure_ring_polygon(inner, 30.0, Color(0.6, 1.0, 1.0, 0.8))
			wp.add_child(inner)
			var tw2 := inner.create_tween()
			tw2.tween_method(func(r: float): _configure_ring_polygon(inner, r, Color(0.6, 1.0, 1.0, 0.8 * (r / 30.0))), 30.0, 5.0, 0.18)
			tw2.tween_callback(func(): _release_ring(inner))
		)


## 炮射导弹：蓝白拖尾火花（区分标准导弹的橙红色调）
static func _spawn_gun_missile_trail(parent: Node2D, pos: Vector2, is_player: bool) -> void:
	if DT.is_motion_reduce() or _active_sparks >= MAX_SPARKS:
		return
	_active_sparks += 1
	var p := _acquire_spark_particle()
	if p == null:
		_active_sparks -= 1
		return
	# v9.2: 导弹尾迹用金属贴图（池复用需显式赋值）
	p.texture = PARTICLE_TEX_SPARK_METAL
	p.position = pos  # v8.4: 用 position（与工厂惯例一致）
	p.amount = 20
	p.lifetime = 0.45
	p.direction = Vector2(0, 0)
	p.spread = 360.0
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 100.0
	p.gravity = Vector2(0, 0)
	# 蓝白色调（炮射导弹特征，区别于标准导弹的橙红）
	p.color = Color(0.6, 0.8, 1.0, 1.0)
	p.color_ramp = _get_spark_ramp(p.color)  # v8.4: 与 _spawn_sparks 一致，设色带避免池复用残留
	# v9.2: 导弹尾迹贴图化缩小
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	parent.add_child(p)
	var tree := p.get_tree()
	if tree != null:
		# v7.5 同款：用 _connect_deferred_release 避免 "Lambda capture was freed" 运行时错误
		var timer := tree.create_timer(p.lifetime + 0.1)
		_connect_deferred_release(timer, p, _release_spark_particle)


## 冲击波环
static func _spawn_ring(parent: Node2D, pos: Vector2, target_r: float, duration: float, color: Color, aspect_ratio: float = 1.6) -> void:
	# v17e: 侧视冲击波压扁（aspect_ratio=2.0 → 宽度 2× 高度，明显椭圆）
	var ring := _acquire_ring()
	if ring == null:
		return
	ring.position = pos
	_configure_ring_polygon(ring, 5.0, Color(color.r, color.g, color.b, 0.8), aspect_ratio)
	parent.add_child(ring)
	var tween := ring.create_tween()
	# 扩散同时 alpha 从 0.8 → 0
	var col_end := Color(color.r, color.g, color.b, 0.0)
	tween.tween_method(func(r: float): _configure_ring_polygon(ring, r, color.lerp(col_end, (r - 5.0) / maxf(target_r - 5.0, 1.0))), 5.0, target_r, duration)
	tween.tween_callback(func(): _release_ring(ring))


## 主火花（工厂自管池化粒子，按配方差异化）
## v9.4: 命中粒子火花层
static func _spawn_sparks(parent: Node2D, pos: Vector2, recipe: Dictionary, base_color: Color, weapon_type: int) -> void:
	if _active_sparks >= MAX_SPARKS:
		return
	_active_sparks += 1
	var p := _acquire_spark_particle()
	if p == null:
		_active_sparks -= 1
		return
	p.position = pos
	p.color = base_color
	# v9.2: 命中粒子用放射状贴图（区别于拖尾的顺向条纹）
	# v19-R36b: 动能命中火花 SPARK_STREAK→SPARK_DROP——CPUParticles2D 无法随速度
	# 方向旋转粒子，径向 360° 爆散配固定水平横条 = "竖直飞的火花是横条"形向矛盾
	# （AI 实锤 >80% 水平横条；条状贴图只适合顺弹道的拖尾场景）。
	if weapon_type in [8, 10]:  # LASER / OMEGA — 放射能量爆裂
		p.texture = PARTICLE_TEX_IMPACT_ENERGY
	elif weapon_type == 11:
		p.texture = PARTICLE_TEX_IMPACT_METAL
	elif weapon_type in [3, 7, 9]:  # ROCKET / FLAK / MISSILE — 爆炸火花
		p.texture = PARTICLE_TEX_SPARK_DROP
	else:  # 动能直射类（含 SHOTGUN/SNIPER）— 各向同性圆滴，任意飞散方向形状都正确
		p.texture = PARTICLE_TEX_SPARK_DROP
	# 按配方差异化参数
	p.amount = int(recipe.get("spark_amount", 18))
	p.initial_velocity_min = float(recipe.get("spark_vmin", 40.0))
	p.initial_velocity_max = float(recipe.get("spark_vmax", 120.0))
	var base_life: float = float(recipe.get("spark_life", 0.28))
	if weapon_type in [0, 1, 2, 4]:
		base_life = minf(base_life, 0.34)
	p.lifetime = base_life
	const SPARK_SCALE_FIX_KINETIC: float = 0.40
	const SPARK_SCALE_FIX_ENERGY: float = 0.40
	var _fix: float = SPARK_SCALE_FIX_ENERGY if weapon_type in [8, 10, 11] else SPARK_SCALE_FIX_KINETIC
	p.scale_amount_min = float(recipe.get("spark_smin", 1.5)) * _fix
	p.scale_amount_max = float(recipe.get("spark_smax", 3.0)) * _fix
	# v11c: 动能火花提速+缩尺
	if weapon_type not in [8, 10, 11, 3, 7, 9]:
		p.initial_velocity_min *= 1.6
		p.initial_velocity_max *= 1.6
		p.scale_amount_min *= 0.7
		p.scale_amount_max *= 0.7
	p.lifetime_randomness = 0.3
	# v11 关键修复:动能火花加随机旋转(0-360°)让 streak 四散
	if weapon_type not in [8, 10, 11]:
		p.angle_min = 0.0
		p.angle_max = 360.0
	# v10: 火花沿撞击法线锥形喷射
	p.direction = Vector2(0, -1)
	if recipe.get("spark_dir", false):
		p.spread = float(recipe.get("spark_spread", 55.0))
	else:
		p.spread = minf(float(recipe.get("spark_spread", 360.0)), 110.0)
	p.color_ramp = _get_spark_ramp(base_color, weapon_type)
	parent.add_child(p)
	var tree := p.get_tree()
	if tree != null:
		var timer := tree.create_timer(p.lifetime + 0.1)
		_connect_deferred_release(timer, p, _release_spark_particle)


## v16.2: 独立火花层测试入口——仅触发第2层主火花，不生成环/碎片/闪光等其他层。
## 直接用真实 _impact_recipe 参数，保证与实战完全一致。
static func spawn_sparks_only(parent: Node2D, pos: Vector2, weapon_type: int, is_player: bool = true) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var recipe: Dictionary = _impact_recipe(weapon_type, "")
	var base_color: Color = _impact_color(weapon_type, -1, is_player)
	_spawn_sparks(parent, pos, recipe, base_color, weapon_type)


## v16.2: 独立冲击波环测试入口——仅触发第1层环，不含火花/碎片/闪光。
static func spawn_ring_only(parent: Node2D, pos: Vector2, weapon_type: int, is_player: bool = true) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var recipe: Dictionary = _impact_recipe(weapon_type, "")
	var base_color: Color = _impact_color(weapon_type, -1, is_player)
	var ring_color: Color = base_color.lerp(side_color(is_player), 0.55)
	_spawn_ring(parent, pos, recipe.get("ring_r", 24.0), recipe.get("ring_dur", 0.2), ring_color)


## v16.2: 独立碎片/烟尘测试入口——仅触发第3层 debris，不含环/火花/闪光。
static func spawn_debris_only(parent: Node2D, pos: Vector2, weapon_type: int, is_player: bool = true) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var recipe: Dictionary = _impact_recipe(weapon_type, "")
	if not recipe.has("debris"):
		# 无 debris 配方时，对重型武器生成默认烟尘（动能直射等无 debris）
		if weapon_type in [3, 7, 9]:
			recipe["debris"] = {"amount": 16, "life": 0.8, "vmin": 40.0, "vmax": 100.0,
				"smin": 2.5, "smax": 5.0, "is_smoke": true,
				"smoke_color": Color(0.45, 0.4, 0.35, 0.45)}
		elif weapon_type in [8, 10, 11]:
			recipe["debris"] = {"amount": 10, "life": 0.6, "vmin": 30.0, "vmax": 80.0,
				"smin": 2.0, "smax": 4.0, "is_smoke": true,
				"smoke_color": Color(0.35, 0.4, 0.8, 0.4)}
		else:
			return  # 轻武器无 debris 层
	var base_color: Color = _impact_color(weapon_type, -1, is_player)
	_spawn_debris(parent, pos, recipe["debris"], base_color, weapon_type)


## v16.2: 独立闪光测试入口
static func spawn_flash_only(parent: Node2D, pos: Vector2, weapon_type: int, is_player: bool = true) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var base_color: Color = _impact_color(weapon_type, -1, is_player)
	_spawn_flash_layer(parent, pos, base_color, weapon_type, {})


## v16.2: 独立轻烟团测试入口
static func spawn_smoke_puff_only(parent: Node2D, pos: Vector2, weapon_type: int, is_player: bool = true) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var base_color: Color = _impact_color(weapon_type, -1, is_player)
	_spawn_smoke_puff_layer(parent, pos, base_color, weapon_type, {})


## v16.2: 独立金属破片测试入口
static func spawn_shrapnel_only(parent: Node2D, pos: Vector2, weapon_type: int, is_player: bool = true) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var base_color: Color = _impact_color(weapon_type, -1, is_player)
	_spawn_shrapnel_layer(parent, pos, base_color, weapon_type, {})


## v16.2: 独立弹痕锚点测试入口（仅动能武器有效）
static func spawn_decal_only(parent: Node2D, pos: Vector2, weapon_type: int, is_player: bool = true) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	_spawn_impact_decal(parent, pos, weapon_type)


## v16.2: 弹体贴图展示——在测试位置生成一个静止的弹体 Sprite2D（贴图版或程序化多边形）。
## 用于独立查看不同武器类型的弹体形状/贴图，不受子弹飞行影响。
## 展示 1.5s 后自动淡出并移除，避免累积残留。
static func spawn_bullet_debug(parent: Node2D, pos: Vector2, weapon_type: int, is_player: bool = true) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	const WPV := preload("res://scripts/weapon_projectile_vfx.gd")
	var tint := Color.WHITE if is_player else Color(1.0, 0.38, 0.52)
	var use_beam := (weapon_type == 6 or weapon_type == 8)
	var node: Node2D = null
	# 程序化弹头（轻武器 0/1/2/4）
	if not use_beam and weapon_type in [0, 1, 2, 4]:
		var poly := Polygon2D.new()
		poly.polygon = WPV.build_bullet_points(weapon_type, 1.0)
		poly.position = pos
		poly.modulate = Color(1.0, 0.95, 0.2) if is_player else Color(1.0, 0.4, 0.2)
		parent.add_child(poly)
		node = poly
	# 贴图弹道（重型/能量/曲射）
	elif not use_beam:
		var tex := WPV.proj_texture(weapon_type)
		if tex != null:
			var sp := Sprite2D.new()
			sp.texture = tex
			sp.position = pos
			sp.scale = Vector2(WPV.proj_scale(weapon_type) * 5.0, WPV.proj_scale(weapon_type) * 5.0)
			sp.modulate = tint
			sp.material = _get_add_mat()
			parent.add_child(sp)
			node = sp
	# 光束武器（SNIPER/LASER）
	if node == null and use_beam:
		var beam_col := Color(0.4, 0.9, 1.0) if is_player else Color(1.0, 0.5, 0.4)
		if weapon_type == 8:  # LASER
			beam_col = Color(0.2, 0.85, 1.0) if is_player else Color(1.0, 0.3, 0.6)
		var bl := Line2D.new()
		bl.width = 3.0 if weapon_type == 6 else 4.5
		bl.default_color = beam_col
		bl.joint_mode = Line2D.LINE_JOINT_ROUND
		bl.end_cap_mode = Line2D.LINE_CAP_ROUND
		bl.add_point(Vector2(-30.0, 0.0))
		bl.add_point(Vector2(30.0, 0.0))
		bl.position = pos
		parent.add_child(bl)
		node = bl
	# 1.5s 后淡出移除
	if node != null:
		var tree := parent.get_tree()
		if tree != null:
			var tw := node.create_tween()
			tw.tween_interval(1.3)
			tw.tween_property(node, "modulate:a", 0.0, 0.2)
			tw.tween_callback(func():
				if is_instance_valid(node) and node.get_parent():
					node.get_parent().remove_child(node)
				node.queue_free())


## ======================================================================
## 内部：对象池
## 的强引用 p，触发时引擎报 "Lambda capture at index 0 was freed. Passed null"。
## 解法：lambda 捕获 WeakRef 而非强引用；WeakRef 不阻止对象释放，get_ref() 在
## 对象已释放时返回 null，release 函数已有 null 守卫，安全返回。
static func _connect_deferred_release(timer: SceneTreeTimer, node: Node, release_fn: Callable) -> void:
	var weak: WeakRef = weakref(node)
	timer.timeout.connect(func() -> void:
		var n: Variant = weak.get_ref()
		if n != null and is_instance_valid(n):
			release_fn.call(n)
	)


## 火花色带缓存（Gradient，按颜色键缓存）
static var _spark_ramp_cache: Dictionary = {}
# v10: 火花色带按武器族分——动能/爆炸走热衰减(白→黄→橙→暗红→淡出),
# 能量武器(激光/欧米茄/电磁)保留蓝青但加白热核心。报告:原"白→武器色→淡出"颜色单一缺高温梯度。
static func _get_spark_ramp(base_color: Color, weapon_type: int = -1) -> Gradient:
	var family: String = "energy" if weapon_type in [8, 10, 11] else "thermal"
	var key: String = family + "_%02x%02x%02x" % [int(base_color.r*255), int(base_color.g*255), int(base_color.b*255)]
	if _spark_ramp_cache.has(key):
		return _spark_ramp_cache[key]
	var g := Gradient.new()
	if family == "thermal":
		# 真实金属火花热衰减:白热核心→亮黄→橙→暗红→近黑淡出
		# v11c: 亮黄阶段延长(0.15→0.32),让散开的火花仍处白热/亮黄(报告:火花过快变暗变橙)
		g.add_point(0.0, Color(1.0, 1.0, 1.0, 1.0))
		g.add_point(0.32, Color(1.0, 0.9, 0.4, 1.0))
		g.add_point(0.58, Color(1.0, 0.55, 0.12, 0.95))
		g.add_point(0.82, Color(0.5, 0.06, 0.0, 0.65))
		g.add_point(1.0, Color(0.2, 0.02, 0.0, 0.0))
	else:
		# 能量武器:白热核心→武器本色(蓝青)→淡出
		g.add_point(0.0, Color(1.0, 1.0, 1.0, 1.0))
		g.add_point(0.25, base_color)
		g.add_point(1.0, Color(base_color.r, base_color.g, base_color.b, 0.0))
	_spark_ramp_cache[key] = g
	return g


## 碎片/烟尘
static func _spawn_debris(parent: Node2D, pos: Vector2, debris_cfg: Dictionary, base_color: Color, weapon_type: int) -> void:
	if _active_debris >= MAX_DEBRIS:
		return
	_active_debris += 1
	var p := _acquire_debris_particle()
	if p == null:
		_active_debris -= 1
		return
	p.position = pos
	# v9.2: 烟尘/碎片按武器类型分流贴图（池复用需显式赋值，否则继承上次的 texture）
	if weapon_type in [8, 10, 11]:
		p.texture = PARTICLE_TEX_SMOKE_ENERGY
	else:
		p.texture = PARTICLE_TEX_SMOKE_GENERIC
	p.amount = int(debris_cfg.get("amount", 10))
	p.lifetime = float(debris_cfg.get("life", 0.5))
	p.initial_velocity_min = float(debris_cfg.get("vmin", 30.0))
	p.initial_velocity_max = float(debris_cfg.get("vmax", 90.0))
	# v9.2: 烟尘贴图化后 scale 同样需缩小（64px 贴图 × scale）。统一 ×0.5
	# 配方值 2.0-5.5 × 0.5 = 1.0-2.75 → 64px 贴图显示 64-176px（烟尘本就该大些）
	const DEBRIS_SCALE_FIX: float = 0.5
	p.scale_amount_min = float(debris_cfg.get("smin", 2.0)) * DEBRIS_SCALE_FIX
	p.scale_amount_max = float(debris_cfg.get("smax", 4.0)) * DEBRIS_SCALE_FIX
	# 烟尘向上、碎片有重力
	if bool(debris_cfg.get("is_smoke", false)):
		if bool(debris_cfg.get("low_dust", false)):
			# v8.x: 曲射落地扬尘——横向低矮扩散（贴地），区别于爆炸烟柱的垂直上升
			p.direction = Vector2(1, 0)  # 横向（左甩+右甩由 spread=180 实现）
			p.spread = 180.0
			p.gravity = Vector2(0, 40.0)  # 轻微下沉，模拟尘土回落
			p.color = debris_cfg.get("smoke_color", Color(0.5, 0.45, 0.38, 0.45))
		else:
			p.direction = Vector2(0, -1)  # 向上
			p.spread = 40.0
			p.gravity = Vector2(0, -8.0)  # 轻微上飘
			p.color = debris_cfg.get("smoke_color", Color(0.4, 0.35, 0.3, 0.6))
	else:
		p.direction = Vector2(0, 0)
		p.spread = 360.0
		p.gravity = Vector2(0, 200.0)  # 重力下落
		p.color = debris_cfg.get("debris_color", Color(0.6, 0.5, 0.4, 1.0))
	p.emitting = true
	parent.add_child(p)
	var tree := p.get_tree()
	if tree != null:
		# +0.1s 余量（同 _spawn_sparks，防尾段截断）
		var timer := tree.create_timer(p.lifetime + 0.1)
		_connect_deferred_release(timer, p, _release_debris_particle)


## ======================================================================
## v10 真实度层：瞬时闪光 / 轻烟团 / 金属破片（报告建议新增层，复用现有池）
## ======================================================================
## 瞬时白光闪光——命中瞬间动能→热能强光(0.06-0.12s)。复用 spark 池。
static func _spawn_flash_layer(parent: Node2D, pos: Vector2, base_color: Color, weapon_type: int, cfg: Dictionary) -> void:
	if _active_sparks >= MAX_SPARKS:
		return
	_active_sparks += 1
	var p := _acquire_spark_particle()
	if p == null:
		_active_sparks -= 1
		return
	p.position = pos
	# v11: 命中瞬时白光锚点(报告:命中点缺瞬时高光,金属撞击应有"星芒状白闪")。
	# 动能用放射状星贴图(IMPACT_METAL)+纯白过曝+极短寿命+放大尺寸 → 清晰命中闪光视觉锚。
	p.texture = PARTICLE_TEX_IMPACT_METAL if not (weapon_type in [8, 10, 11]) else PARTICLE_TEX_IMPACT_ENERGY
	var is_energy: bool = weapon_type in [8, 10, 11]
	p.angle_min = 0.0
	p.angle_max = 0.0
	p.amount = int(cfg.get("amount", 2))
	p.explosiveness = 1.0
	p.lifetime = float(cfg.get("life", 0.07))
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.0
	p.direction = Vector2.ZERO
	p.spread = 0.0
	p.gravity = Vector2.ZERO
	const FSCALE: float = 0.4
	p.scale_amount_min = float(cfg.get("smin", 6.0)) * FSCALE
	p.scale_amount_max = float(cfg.get("smax", 11.0)) * FSCALE
	var flash_col: Color = Color(1.0, 1.0, 0.96, 1.0) if not is_energy else Color(0.85, 0.95, 1.0, 1.0)
	p.color = flash_col
	var g := Gradient.new()
	g.add_point(0.0, flash_col)
	g.add_point(0.5, Color(flash_col.r, flash_col.g * 0.9, flash_col.b * 0.6, 0.6))
	g.add_point(1.0, Color(flash_col.r, flash_col.g * 0.6, flash_col.b * 0.3, 0.0))
	p.color_ramp = g
	parent.add_child(p)
	var tree := p.get_tree()
	if tree != null:
		var timer := tree.create_timer(p.lifetime + 0.05)
		_connect_deferred_release(timer, p, _release_spark_particle)


## 轻烟团——金属撞击微量黑灰烟(动能武器原完全无烟)。复用 debris 池。
static func _spawn_smoke_puff_layer(parent: Node2D, pos: Vector2, base_color: Color, weapon_type: int, cfg: Dictionary) -> void:
	if _active_debris >= MAX_DEBRIS:
		return
	_active_debris += 1
	var p := _acquire_debris_particle()
	if p == null:
		_active_debris -= 1
		return
	p.position = pos
	var is_energy: bool = weapon_type in [8, 10, 11]
	p.texture = PARTICLE_TEX_SMOKE_ENERGY if is_energy else PARTICLE_TEX_SMOKE_GENERIC
	var light_factor: float = 0.85 if weapon_type in [0, 1, 2, 4] else 1.0  # v11b: 0.5→0.85 轻武器烟量恢复可见(报告:完全无烟)
	p.amount = int(float(cfg.get("amount", 6)) * light_factor)
	p.lifetime = float(cfg.get("life", 0.7))
	p.initial_velocity_min = float(cfg.get("vmin", 20.0))
	p.initial_velocity_max = float(cfg.get("vmax", 55.0))
	const DSCALE: float = 0.5
	p.scale_amount_min = float(cfg.get("smin", 2.5)) * DSCALE
	p.scale_amount_max = float(cfg.get("smax", 4.5)) * DSCALE
	p.direction = Vector2(0, -1)   # 向上飘
	p.spread = 55.0
	p.gravity = Vector2(0, -15.0)  # 轻微上飘
	var smoke_col: Color = cfg.get("color", (Color(0.32, 0.3, 0.28, 0.55) if not is_energy else Color(0.3, 0.38, 0.6, 0.45)))
	p.color = smoke_col
	p.color_ramp = _get_smoke_grad(smoke_col)
	parent.add_child(p)
	var tree := p.get_tree()
	if tree != null:
		var timer := tree.create_timer(p.lifetime + 0.1)
		_connect_deferred_release(timer, p, _release_debris_particle)


## 金属破片——装甲剥落的小碎片(银白/暗金,重力下坠)。复用 debris 池。
static func _spawn_shrapnel_layer(parent: Node2D, pos: Vector2, base_color: Color, weapon_type: int, cfg: Dictionary) -> void:
	if _active_debris >= MAX_DEBRIS:
		return
	_active_debris += 1
	var p := _acquire_debris_particle()
	if p == null:
		_active_debris -= 1
		return
	p.position = pos
	p.texture = PARTICLE_TEX_METAL_CHUNK if weapon_type not in [8, 10, 11] else PARTICLE_TEX_SPARK_ENERGY
	# v18-R9: SPARK_HEAVY→METAL_CHUNK——暗金属碎块簇（暗钢色+受光面+炽热边+高光点）。
	# 旧"软圆块"无金属质感被用户感知否决；v17e 棱角多边形也被否决——
	# 这次是"小碎块+暗色为主+局部炽热"，摄影感的暗亮对比而非形状变化。
	# 破片 = 快速小碎块 + 强重力下坠。新值：500-900px/s、19-45px、0.45s、重力 500、
	# 银白金属色（区别于火焰的暖橙）。
	var is_explosive: bool = weapon_type in [1, 2, 3, 7, 9]
	var light_factor: float = 0.85 if weapon_type in [0, 4] else 1.0  # v18: 0/4 已减层，此值仅剩兜底意义
	if is_explosive:
		p.material = _get_normal_mat()  # v18-R9: 暗色实体用 MIX（ADD 洗掉暗部）；release 时归位 ADD
		p.amount = 14
		p.lifetime = 0.45
		p.lifetime_randomness = 0.3
		p.initial_velocity_min = 500.0
		p.initial_velocity_max = 900.0
		p.scale_amount_min = 0.15
		p.scale_amount_max = 0.35
		p.direction = Vector2(0, -1)   # 上半锥抛出
		p.spread = 150.0
		p.gravity = Vector2(0, 500.0)  # 强重力：抛物线下坠 = "固体破片"读感
		# v18-R9: color 白——metal_chunk 自带暗钢/受光/炽热边色彩，modulate 会洗掉层次。
		# 渐变只控 alpha 渐隐（末尾整体变透明而非变色）。
		p.color = Color.WHITE
		var sge := Gradient.new()
		sge.add_point(0.0, Color(1, 1, 1, 1.0))
		sge.add_point(0.6, Color(1, 1, 1, 0.9))
		sge.add_point(1.0, Color(1, 1, 1, 0.0))
		p.color_ramp = sge
		parent.add_child(p)
		var tree_e := p.get_tree()
		if tree_e != null:
			var timer_e := tree_e.create_timer(p.lifetime + 0.1)
			_connect_deferred_release(timer_e, p, _release_debris_particle)
		return
	p.amount = int(float(cfg.get("amount", 10)) * light_factor)
	p.lifetime = float(cfg.get("life", 0.6))
	p.initial_velocity_min = float(cfg.get("vmin", 120.0))
	p.initial_velocity_max = float(cfg.get("vmax", 320.0))
	const DSCALE2: float = 0.5
	p.scale_amount_min = float(cfg.get("smin", 1.0)) * DSCALE2
	p.scale_amount_max = float(cfg.get("smax", 2.2)) * DSCALE2
	p.direction = Vector2(0, -1)   # 向上锥扇出后重力下坠
	p.spread = 100.0
	p.gravity = Vector2(0, 260.0)  # 重力下落(破片抛物线)
	var shrap_col: Color = cfg.get("color", (Color(0.85, 0.78, 0.55, 1.0) if weapon_type not in [8, 10, 11] else Color(0.6, 0.75, 1.0, 1.0)))
	p.color = shrap_col
	var sg := Gradient.new()
	sg.add_point(0.0, shrap_col)
	sg.add_point(0.6, Color(shrap_col.r * 0.6, shrap_col.g * 0.5, shrap_col.b * 0.4, 0.9))
	sg.add_point(1.0, Color(0.2, 0.15, 0.1, 0.0))
	p.color_ramp = sg
	parent.add_child(p)
	var tree := p.get_tree()
	if tree != null:
		var timer := tree.create_timer(p.lifetime + 0.1)
		_connect_deferred_release(timer, p, _release_debris_particle)


## v11 弹痕锚点层:持久(0.6s)暗凹陷+刮擦线贴图贴在命中点,给"打中了"明确视觉定位。
## 报告反复要求"弹孔/凹陷视觉锚点/弹痕"——纯粒子无定位感,这个静态贴图锚住命中点。
## 仅动能武器(能量灼烧/重型爆炸另留各自的灼痕/爆坑,不叠小弹痕)。
static func _spawn_impact_decal(parent: Node2D, pos: Vector2, weapon_type: int) -> void:
	if weapon_type in [8, 10, 11, 3, 7, 9]:
		return  # 能量/重型爆炸不留小弹痕
	if parent == null or not is_instance_valid(parent):
		return
	var decal := Sprite2D.new()
	decal.texture = PARTICLE_TEX_IMPACT_SCORCH
	decal.position = pos
	decal.scale = Vector2(0.6, 0.6)
	decal.rotation = randf() * TAU   # 随机旋转,避免每个弹痕朝向一致
	decal.modulate = Color(1.0, 1.0, 1.0, 0.92)
	decal.add_to_group("battle_vfx")
	parent.add_child(decal)
	var tree := decal.get_tree()
	if tree != null:
		# bind_node:节点被清场 group-free 时自动 kill tween,避免操作已释放节点
		var tw := tree.create_tween().bind_node(decal)
		tw.tween_interval(0.35)   # 先保持清晰可辨
		tw.tween_property(decal, "modulate:a", 0.0, 0.30)
		tw.tween_callback(decal.queue_free)


## ======================================================================
## 内部：配色 & 配方表
## ======================================================================

## 命中主色（v8.4: 配色表真身，WeaponProjectileVfx.IMPACT_COLOR_BY_WT 已废弃迁移至此）
static func _impact_color(weapon_type: int, combat_kind: int, is_player: bool) -> Color:
	const COLOR_BY_WT: Dictionary = {
		0: Color(0.95, 0.92, 0.5, 1.0),   # DIRECT/SMG 黄白
		4: Color(0.95, 0.92, 0.5, 1.0),   # PISTOL
		5: Color(1.0, 0.7, 0.3, 1.0),     # SHOTGUN 橙
		6: Color(1.0, 0.95, 0.6, 1.0),    # SNIPER 亮黄
		3: Color(1.0, 0.55, 0.2, 1.0),    # ROCKET 橙红
		7: Color(1.0, 0.55, 0.2, 1.0),    # FLAK
		9: Color(1.0, 0.45, 0.15, 1.0),   # MISSILE 深橙
		1: Color(1.0, 0.5, 0.15, 1.0),    # INDIRECT 曲射爆炸
		2: Color(1.0, 0.4, 0.1, 1.0),     # AERIAL 空射导弹
		8: Color(0.3, 0.8, 1.0, 1.0),     # LASER 蓝
		10: Color(0.4, 0.6, 1.0, 1.0),    # OMEGA 能量蓝
		11: Color(0.5, 0.9, 1.0, 1.0),    # RAIL 电磁青
	}
	const TINT_BY_KIND: Dictionary = {
		0: Color(1.0, 0.95, 0.6),   # LIGHT 黄白火花
		2: Color(1.0, 0.95, 0.6),   # SUPPORT
		1: Color(1.0, 0.55, 0.25),  # ARMOR 橙红金属碎屑
		4: Color(1.0, 0.55, 0.25),  # FORT
		3: Color(1.0, 1.0, 1.0),    # AIR 保留原色
	}
	var base: Color = COLOR_BY_WT.get(weapon_type, Color(0.95, 0.92, 0.5))
	# 武器本色保留为主（70%），combat_kind 只做轻微染色（30%），不再完全覆盖丢失武器特征色。
	# 原 base = TINT_BY_KIND[...] 直接覆盖导致所有武器打同目标都同色（看不出差异）。
	if combat_kind >= 0 and TINT_BY_KIND.has(combat_kind):
		base = base.lerp(TINT_BY_KIND[combat_kind], 0.3)
	if not is_player:
		base = base.lerp(Color(1.0, 0.45, 0.55), 0.25)  # 敌方轻微偏粉（25%），保留武器色
	# v13: 能量系(激光/粒子炮/磁轨)按时代调色——一战/二战蓝紫转暖橙白,冷战降饱和
	if weapon_type in [8, 10, 11]:
		return _era_tint_energy(base)
	return base


## 武器配方表（按 weapon_type 数值索引）
## 注：weapon_type=1 在 bullet 路径=INDIRECT(曲射)，在 batch 路径=RIFLE(直射)，
## 取折中"中火"配置（既不太像火炮也不太像步枪），不加剧既有歧义。
## v8.2: 整体加长寿命到"可清晰感知"区间（火花≥0.45s/环≥0.35s），保留武器间梯度。
## v8.3 视觉增强：环 ×1.5、duration +0.08、spark_amount +50%、spark_vmax +60%、debris +30%
## 让命中爆炸有"砰"的分量感（原环到 24px 就没了，火花 0.15s 消散）
## v9.2: 命中配方缓存——配方是只读静态数据（按 weapon_type+flavor 固定），
## 每次 new Dictionary 字面量在密集命中下是显著的堆分配源。
## 按 (weapon_type*100+flavor) 整数键缓存，命中后返回同一引用（调用方只 .get() 读不改）。
static var _recipe_cache: Dictionary = {}

static func _impact_recipe(weapon_type: int, weapon_name: String = "") -> Dictionary:
	# v8.x: 直射系亚类分类（仅 0/1/2/4 生效，其他返回 NONE 走原配方）
	var flavor: int = DirectWeaponFlavor.classify(weapon_name, weapon_type)
	# v9.2: 缓存命中——同一 (weapon_type, flavor) 的配方是只读的，首次构建后直接返回引用。
	var cache_key: int = weapon_type * 100 + flavor
	if _recipe_cache.has(cache_key):
		return _recipe_cache[cache_key]
	var d: Dictionary = _impact_recipe_build(weapon_type, flavor)
	_recipe_cache[cache_key] = d
	return d

## v9.2: 原 _impact_recipe 的 match 主体（拆出以便 _impact_recipe 做缓存包装）。
static func _impact_recipe_build(weapon_type: int, flavor: int) -> Dictionary:
	match weapon_type:
		0, 4:  # DIRECT/SMG/PISTOL — 小环 + 少量高亮火花（v8.4 重平衡：减粒子数提单粒子亮度）
			# v8.x 亚类细分：机枪/坦克炮/步枪/手枪 各自不同的命中反馈强度
			match flavor:
				DirectWeaponFlavor.Flavor.MG:
					# 机枪：弹着点更密（火花略多 + 环略大），连发时形成密集弹痕
					# v11: 高速+短寿+小尺寸 → 锐利密集火花(报告:机枪该有密集弹痕,非大火球)
					return {
						"ring_r": 34.0, "ring_dur": 0.30,
						"spark_amount": 30, "spark_vmin": 340.0, "spark_vmax": 660.0,
						"spark_smin": 0.55, "spark_smax": 1.2, "spark_life": 0.24, "spark_spread": 360.0,
					}
				DirectWeaponFlavor.Flavor.TANK_GUN:
					# 坦克炮：重炮命中（大环 + 粗火花），与轻武器弹着点明显区分
					# v11: 重炮保持较大尺寸/较长寿命(穿甲重击),但速度提高显冲击力
					return {
						"ring_r": 52.0, "ring_dur": 0.40,
						"spark_amount": 34, "spark_vmin": 380.0, "spark_vmax": 740.0,
						"spark_smin": 0.8, "spark_smax": 1.6, "spark_life": 0.30, "spark_spread": 360.0,
					}
				DirectWeaponFlavor.Flavor.RIFLE:
					# 步枪：高速集中喷射（窄角，穿甲感），区别于冲锋枪的圆散
					# v11: 窄锥高速喷射(报告:步枪该 800-1200px/s 窄角扇形)
					return {
						"ring_r": 30.0, "ring_dur": 0.28,
						"spark_amount": 28, "spark_vmin": 360.0, "spark_vmax": 700.0,
						"spark_smin": 0.5, "spark_smax": 1.1, "spark_life": 0.22, "spark_spread": 70.0,
						"spark_dir": true,
					}
				DirectWeaponFlavor.Flavor.SMALL_ARMS:
					# 手枪/卡宾：最弱命中（小环 + 少火花），体现轻武器
					return {
						"ring_r": 22.0, "ring_dur": 0.26,
						"spark_amount": 18, "spark_vmin": 280.0, "spark_vmax": 540.0,
						"spark_smin": 0.5, "spark_smax": 1.0, "spark_life": 0.20, "spark_spread": 360.0,
					}
				_:
					# GENERIC/UNKNOWN：原基准（冲锋枪/通用直射）
					# v11: 高速短寿小尺寸锐利火花(报告:冲锋枪该尖锐瞬时冲击,非松散云团)
					return {
						"ring_r": 28.0, "ring_dur": 0.28,
						"spark_amount": 24, "spark_vmin": 320.0, "spark_vmax": 620.0,
						"spark_smin": 0.5, "spark_smax": 1.1, "spark_life": 0.22, "spark_spread": 360.0,
					}
		6:  # SNIPER — 中环 + 高速集中喷射
			# v11: 狙击最高速集中(大口径穿甲,火花最猛烈)
			return {
				"ring_r": 48.0, "ring_dur": 0.36,
				"spark_amount": 32, "spark_vmin": 420.0, "spark_vmax": 820.0,
				"spark_smin": 0.5, "spark_smax": 1.0, "spark_life": 0.26, "spark_spread": 55.0,
				"spark_dir": true,
			}
		5:  # SHOTGUN — 宽散布
			# v11: 霰弹多粒子宽散布(弹丸散射火花)
			# v18-R11c 实验：环半径 44→36、火花降速 600→350，未通过验证（f05 enemy_traj 4→3），已回退。
			# v19-R23 尝试 spark_dir+窄锥 导致轨迹格"命中火花"混淆"飞行弹体"(f05_traj 5→2)，已回退。
			# v19-R28 多簇 spawn 实验损伤 f08（family 4.33→3.17），回退为参数调优。
			# v19-R29: 加宽锥角+提速，模拟弹丸散射感（不拆簇，避免跨族影响）。
			return {
				"ring_r": 44.0, "ring_dur": 0.34,
				"spark_amount": 46, "spark_vmin": 350.0, "spark_vmax": 650.0,
				"spark_smin": 0.5, "spark_smax": 1.0, "spark_life": 0.26, "spark_spread": 110.0,
			}
		1:  # INDIRECT(曲射) / RIFLE(batch直射) — 中火折中
			# v8.x 亚类细分：曲射(迫击炮/野战炮等无步枪关键词)加地面扬尘，体现"炮弹落地"；
			# RIFLE 直射(batch 路径) 走窄角集中火花，与直射步枪一致。
			if flavor == DirectWeaponFlavor.Flavor.RIFLE:
				return {
					"ring_r": 36.0, "ring_dur": 0.32,
					"spark_amount": 28, "spark_vmin": 360.0, "spark_vmax": 700.0,
					"spark_smin": 0.5, "spark_smax": 1.1, "spark_life": 0.22, "spark_spread": 70.0,
					"spark_dir": true,
				}
			# 曲射：加低矮横向扬尘（is_smoke + 低重力），模拟炮弹落地激起的尘土
			return {
				"ring_r": 48.0, "ring_dur": 0.48,
				"spark_amount": 32, "spark_vmin": 90.0, "spark_vmax": 260.0,
				"spark_smin": 2.0, "spark_smax": 3.8, "spark_life": 0.60, "spark_spread": 360.0,
				"debris": {"amount": 14, "life": 0.9, "vmin": 40.0, "vmax": 90.0, "smin": 3.5, "smax": 5.5, "is_smoke": true, "smoke_color": Color(0.5, 0.45, 0.38, 0.45), "low_dust": true},
			}
		3:  # ROCKET — 大环 + 烟尘
			return {
				"ring_r": 80.0, "ring_dur": 0.60,
				"spark_amount": 48, "spark_vmin": 100.0, "spark_vmax": 320.0,
				"spark_smin": 3.0, "spark_smax": 6.0, "spark_life": 0.70, "spark_spread": 360.0,
				"debris": {"amount": 18, "life": 1.0, "vmin": 50.0, "vmax": 120.0, "smin": 3.0, "smax": 5.0, "is_smoke": true, "smoke_color": Color(0.4, 0.35, 0.3, 0.5)},
			}
		9, 2:  # MISSILE / AERIAL — 大环 + 碎片 + 烟柱
			return {
				"ring_r": 90.0, "ring_dur": 0.65,
				"spark_amount": 55, "spark_vmin": 110.0, "spark_vmax": 350.0,
				"spark_smin": 3.0, "spark_smax": 7.0, "spark_life": 0.75, "spark_spread": 360.0,
				"debris": {"amount": 20, "life": 1.1, "vmin": 60.0, "vmax": 140.0, "smin": 2.0, "smax": 4.0, "is_smoke": false, "debris_color": Color(0.5, 0.45, 0.4, 1.0)},
			}
		7:  # FLAK — 中大环 + 烟尘
			return {
				"ring_r": 64.0, "ring_dur": 0.52,
				"spark_amount": 38, "spark_vmin": 90.0, "spark_vmax": 270.0,
				"spark_smin": 2.5, "spark_smax": 5.0, "spark_life": 0.62, "spark_spread": 360.0,
				"debris": {"amount": 16, "life": 0.9, "vmin": 45.0, "vmax": 95.0, "smin": 3.0, "smax": 4.0, "is_smoke": true, "smoke_color": Color(0.45, 0.4, 0.35, 0.45)},
			}
		8:  # LASER — 细环 + 高速线状火花（能量武器灼烧感，仍比动能武器短，但已能看清）
			return {
				"spark_amount": 25, "spark_vmin": 140.0, "spark_vmax": 350.0,
				"spark_smin": 1.2, "spark_smax": 2.2, "spark_life": 0.40, "spark_spread": 40.0,
				"spark_dir": true,
			}
		10:  # OMEGA(离子/等离子炮) — 蓝色 + 蓝紫灼烧烟尘（能量武器融化装甲感）
			return {
				"ring_r": 50.0, "ring_dur": 0.45,
				"spark_amount": 35, "spark_vmin": 90.0, "spark_vmax": 280.0,
				"spark_smin": 2.0, "spark_smax": 4.5, "spark_life": 0.58, "spark_spread": 360.0,
				"debris": {"amount": 12, "life": 0.7, "vmin": 30.0, "vmax": 70.0, "smin": 2.5, "smax": 4.0, "is_smoke": true, "smoke_color": Color(0.35, 0.4, 0.8, 0.4)},
			}
		11:  # RAIL(电磁轨道炮) — 青色 + 高速定向喷射（电磁穿透感，窄角集中）
			return {
				"ring_r": 44.0, "ring_dur": 0.40,
				"spark_amount": 30, "spark_vmin": 160.0, "spark_vmax": 380.0,
				"spark_smin": 1.5, "spark_smax": 3.0, "spark_life": 0.50, "spark_spread": 45.0,
				"spark_dir": true,
			}
		_:
			return {
				"ring_r": 42.0, "ring_dur": 0.42,
				"spark_amount": 28, "spark_vmin": 80.0, "spark_vmax": 240.0,
				"spark_smin": 1.8, "spark_smax": 3.2, "spark_life": 0.56, "spark_spread": 360.0,
			}


## ======================================================================
## 内部：对象池
## ======================================================================

static func _get_add_mat() -> CanvasItemMaterial:
	if _add_mat == null:
		_add_mat = CanvasItemMaterial.new()
		_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _add_mat

## v18-R9: 普通混合材质（暗色实体贴图用——metal_chunk 暗钢碎块在 ADD 下会被洗成
## 不可见：ADD 是 dst+=src，暗 src ≈ 无贡献）。缓存共享同 _add_mat 范式。
static var _normal_mat: CanvasItemMaterial = null

static func _get_normal_mat() -> CanvasItemMaterial:
	if _normal_mat == null:
		_normal_mat = CanvasItemMaterial.new()
		_normal_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	return _normal_mat

## v9.2: 烟柱 Gradient 按颜色键缓存——tint 颜色种类有限（几种烟色），
## 按 RGB 量化键复用同一 Gradient 引用，避免每次烟柱 new Gradient + 3 个 add_point。
static func _get_smoke_grad(tint: Color) -> Gradient:
	var key: String = "%02x%02x%02x" % [int(tint.r * 255), int(tint.g * 255), int(tint.b * 255)]
	if _smoke_grad_cache.has(key):
		return _smoke_grad_cache[key]
	var grad := Gradient.new()
	grad.add_point(0, Color(tint.r, tint.g, tint.b, 0.85))
	grad.add_point(0.5, Color(tint.r, tint.g, tint.b, 0.45))
	grad.add_point(1.0, Color(tint.r, tint.g, tint.b, 0.0))
	_smoke_grad_cache[key] = grad
	return grad


## 冲击波环（Polygon2D）池
static func _acquire_ring() -> Polygon2D:
	var i := _ring_pool.size() - 1
	while i >= 0:
		var candidate = _ring_pool[i]
		_ring_pool.remove_at(i)
		if candidate != null and is_instance_valid(candidate) and not candidate.is_queued_for_deletion():
			# v7.5: 防御性剥离残留 parent（同 _acquire_spark_particle）
			if candidate.get_parent() != null:
				candidate.get_parent().remove_child(candidate)
			_active_rings += 1
			candidate.visible = true
			candidate.modulate.a = 1.0
			_ensure_ring_buffer(candidate)  # v7.4: 防御性确保 buffer 存在
			return candidate
		else:
			# 失效节点，清理其 buffer 缓存
			_ring_buffers.erase(candidate)
		i -= 1
	if _active_rings >= MAX_RINGS:
		return null
	_active_rings += 1
	var ring := Polygon2D.new()
	ring.material = _get_add_mat()
	_ensure_ring_buffer(ring)  # v7.4: 新建 ring 时预分配顶点 buffer
	return ring


## v7.4: 为 ring 创建/确保预分配顶点 buffer（单位圆坐标 + 工作数组）。
## 单位圆坐标按原 _configure_ring_polygon 的内外圈交错布局预计算，每帧只需 × radius 缩放。
static func _ensure_ring_buffer(ring: Polygon2D) -> void:
	if _ring_buffers.has(ring):
		return
	var unit_pts := PackedVector2Array()
	unit_pts.resize(_RING_VERTS)
	for i in range(_RING_SEGS):
		var a := (float(i) / float(_RING_SEGS)) * TAU
		var outer := Vector2(cos(a), sin(a))
		var inner := Vector2(cos(a + PI / _RING_SEGS), sin(a + PI / _RING_SEGS))
		unit_pts[i * 2] = outer       # 外圈点（radius 缩放）
		unit_pts[i * 2 + 1] = inner   # 内圈点（radius-3 缩放，configure 时动态算）
	var scratch := PackedVector2Array()
	scratch.resize(_RING_VERTS)
	_ring_buffers[ring] = {"unit": unit_pts, "scratch": scratch}


static func _release_ring(ring: Polygon2D) -> void:
	if ring == null or not is_instance_valid(ring):
		_active_rings -= 1
		_ring_buffers.erase(ring)  # v7.4: 清理失效 buffer 缓存
		return
	# v7.5: 用 get_parent()!=null 判定而非 is_inside_tree()。父节点可能在战斗拆卸时
	# 被移出场景树但尚未 free，此时 is_inside_tree()=false 会跳过 remove_child，
	# 导致 ring 带父归还池中，下次 acquire 的 add_child 触发 "already has a parent"。
	if ring.get_parent() != null:
		ring.get_parent().remove_child(ring)
	ring.visible = false
	_active_rings -= 1
	if _ring_pool.size() < MAX_RINGS:
		_ring_pool.append(ring)  # buffer 保留，下次 acquire 复用
	else:
		_ring_buffers.erase(ring)  # v7.4: 即将 free，清理 buffer 缓存
		ring.queue_free()


## v7.4: 配置 Polygon2D 为给定半径的圆环（空心，24段）。
## 原实现每次 new PackedVector2Array + 48 append（每帧每 ring 一次 = 热点 GC 源）。
## 现从预分配 buffer 取数组，原地 × radius 缩放（零堆分配），最后整体赋值给 polygon。
static func _configure_ring_polygon(ring: Polygon2D, radius: float, color: Color, aspect_ratio: float = 1.0) -> void:
	var buf: Dictionary = _ring_buffers.get(ring, {})
	if buf.is_empty():
		_ensure_ring_buffer(ring)
		buf = _ring_buffers[ring]
	var unit_pts: PackedVector2Array = buf["unit"]
	var scratch: PackedVector2Array = buf["scratch"]
	var inner := maxf(radius - 3.0, 1.0)
	for i in range(_RING_VERTS):
		var vx: float = unit_pts[i].x * radius * aspect_ratio  # v17e: 横向拉伸做侧视椭圆
		var vy: float = unit_pts[i].y * radius
		if i % 2 == 0:
			scratch[i] = Vector2(vx, vy)    # 外圈
		else:
			scratch[i] = Vector2(vx, vy)     # 内圈
	ring.polygon = scratch  # 引擎侧拷贝无法避免，但 GDScript 侧零分配
	ring.color = color


## v7.4: Line2D 特效池（穿透光线/闪电链/激光余晖共用）
static func _acquire_beam() -> Line2D:
	var i := _beam_pool.size() - 1
	while i >= 0:
		var candidate = _beam_pool[i]
		_beam_pool.remove_at(i)
		if candidate != null and is_instance_valid(candidate) and not candidate.is_queued_for_deletion():
			# v7.5: 防御性剥离残留 parent（同 _acquire_spark_particle）
			if candidate.get_parent() != null:
				candidate.get_parent().remove_child(candidate)
			_active_beams += 1
			candidate.visible = true
			candidate.modulate.a = 1.0
			candidate.clear_points()  # 清空旧点（复用时重设）
			return candidate
		i -= 1
	if _active_beams >= MAX_BEAMS:
		return null
	_active_beams += 1
	var beam := Line2D.new()
	beam.material = _get_add_mat()
	return beam


static func _release_beam(beam: Line2D) -> void:
	if beam == null or not is_instance_valid(beam):
		_active_beams -= 1
		return
	# v7.5: 用 get_parent()!=null 判定（同 _release_ring 注释说明）
	if beam.get_parent() != null:
		beam.get_parent().remove_child(beam)
	beam.visible = false
	beam.clear_points()
	_active_beams -= 1
	if _beam_pool.size() < MAX_BEAMS:
		_beam_pool.append(beam)
	else:
		beam.queue_free()


## 碎片/烟尘（CPUParticles2D）池
static func _acquire_debris_particle() -> CPUParticles2D:
	var i := _debris_pool.size() - 1
	while i >= 0:
		var candidate = _debris_pool[i]
		_debris_pool.remove_at(i)
		if candidate != null and is_instance_valid(candidate) and not candidate.is_queued_for_deletion():
			# v7.5: 防御性剥离残留 parent（同 _acquire_spark_particle）
			if candidate.get_parent() != null:
				candidate.get_parent().remove_child(candidate)
			candidate.visible = true
			candidate.emitting = true
			candidate.restart()
			return candidate
		i -= 1
	var p := CPUParticles2D.new()
	p.process_mode = Node.PROCESS_MODE_PAUSABLE  # v9.4: 暂停时冻结
	p.one_shot = true
	p.explosiveness = 0.9
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 4.0
	p.material = _get_add_mat()
	# v9.2: 默认贴图（常规烟尘）——调用方 acquire 后会按 weapon_type 覆盖
	p.texture = PARTICLE_TEX_SMOKE_GENERIC
	return p


static func _release_debris_particle(p: CPUParticles2D) -> void:
	if p == null or not is_instance_valid(p):
		_active_debris -= 1
		return
	# v7.5: 用 get_parent()!=null 判定（同 _release_ring 注释说明）
	if p.get_parent() != null:
		p.get_parent().remove_child(p)
	p.emitting = false
	p.visible = false
	p.position = Vector2.ZERO
	# v9.2: 不清 texture——粒子池复用时保留贴图，调用方 acquire 后按 weapon_type 覆盖。
	# 若清 null，下次 acquire 若调用方漏赋 texture 会回退方形方块。
	# v18-R9: 材质恢复池默认 ADD——金属碎块层会临时覆盖普通混合（暗色实体），
	# 归还时归位，防止其他 debris 消费方（烟/血溅）拿到 MIX 丢失发光感。
	p.material = _get_add_mat()
	_active_debris -= 1
	if _debris_pool.size() < MAX_DEBRIS:
		_debris_pool.append(p)
	else:
		p.queue_free()


## 主火花（CPUParticles2D）池
static func _acquire_spark_particle() -> CPUParticles2D:
	var i := _spark_pool.size() - 1
	while i >= 0:
		var candidate = _spark_pool[i]
		_spark_pool.remove_at(i)
		if candidate != null and is_instance_valid(candidate) and not candidate.is_queued_for_deletion():
			# v7.5: 防御——若池中残留 parent（release 漏判 / 战斗拆卸时序），
			# 此处剥离避免 add_child "already has a parent"。
			if candidate.get_parent() != null:
				candidate.get_parent().remove_child(candidate)
			candidate.visible = true
			candidate.emitting = true
			candidate.restart()
			return candidate
		i -= 1
	var p := CPUParticles2D.new()
	p.process_mode = Node.PROCESS_MODE_PAUSABLE  # v9.4: 暂停时冻结（默认 INHERIT 会跟随 ALWAYS 父节点继续动）
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.28
	p.amount = 18
	p.gravity = Vector2(0, 0)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 2.0
	p.direction = Vector2(0, 0)
	p.spread = 360.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 120.0
	# v9.2: 贴图化后的默认 scale（调用方会覆盖，此为防御性兜底）
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	p.color = Color(1.0, 0.95, 0.6, 1.0)
	p.material = _get_add_mat()
	# v9.2: 默认贴图（动能火花）——调用方 acquire 后会按 weapon_type 覆盖；
	# 此处赋默认值是防御性：若未来新增调用方漏赋 texture，至少不是方块
	p.texture = PARTICLE_TEX_SPARK_METAL
	p.emitting = true
	return p


static func _release_spark_particle(p: CPUParticles2D) -> void:
	if p == null or not is_instance_valid(p):
		_active_sparks -= 1
		return
	# v7.5: 用 get_parent()!=null 判定（同 _release_ring 注释说明）
	if p.get_parent() != null:
		p.get_parent().remove_child(p)
	p.emitting = false
	p.visible = false
	p.position = Vector2.ZERO
	# v9.2: 不清 texture（同 _release_debris_particle，池复用需保留贴图）
	_active_sparks -= 1
	if _spark_pool.size() < MAX_SPARKS:
		_spark_pool.append(p)
	else:
		p.queue_free()


## v8.4: 命中贴图 Sprite2D 池（重型爆炸武器 *_impact.png 渲染）
static func _acquire_impact_sprite() -> Sprite2D:
	var i := _impact_sprite_pool.size() - 1
	while i >= 0:
		var candidate = _impact_sprite_pool[i]
		_impact_sprite_pool.remove_at(i)
		if candidate != null and is_instance_valid(candidate) and not candidate.is_queued_for_deletion():
			# v7.5 同款防御：剥离残留 parent
			if candidate.get_parent() != null:
				candidate.get_parent().remove_child(candidate)
			_active_impact_sprites += 1
			return candidate
		i -= 1
	if _active_impact_sprites >= MAX_IMPACT_SPRITES:
		return null  # 硬上限节流
	_active_impact_sprites += 1
	var s := Sprite2D.new()
	s.centered = true
	s.offset = Vector2.ZERO
	s.scale = Vector2.ONE  # Sprite2D 无 expand_mode（属 TextureRect/Control）；按 scale 渲染是默认行为
	s.visible = false
	return s


static func _release_impact_sprite(s: Sprite2D) -> void:
	if s == null or not is_instance_valid(s):
		_active_impact_sprites -= 1
		return
	if s.get_parent() != null:
		s.get_parent().remove_child(s)
	s.visible = false
	s.position = Vector2.ZERO
	s.texture = null  # 释放贴图引用，避免池中持有资源
	if s.is_in_group("battle_vfx"):
		s.remove_from_group("battle_vfx")  # v9.4: 归还池时移除组（避免池中节点被 end_battle 误清）
	_active_impact_sprites -= 1
	if _impact_sprite_pool.size() < MAX_IMPACT_SPRITES:
		_impact_sprite_pool.append(s)
	else:
		s.queue_free()




## ======================================================================
## v9.1 组合技套路视觉层
## 浓度场区域 / 激活横幅 / 光束分裂反射 / 弱点暴露 / 雷达锁定 / 扩散波纹
## ======================================================================

## 战场纳米浓度可视化（青色半透明区域）。
## amount: 当前浓度（0~50）；parent 是 battlefield Node2D；world_pos 是战场中心。
## 浓度越高：范围越大、alpha 越高。每 0.5s 由 battlefield 重建（非每帧 spawn）。
static func spawn_nano_field(parent: Node2D, world_pos: Vector2, amount: float) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	if amount <= 0.5:
		_cleanup_field_vfx(parent, "combo_nano_field")
		return
	var t: float = clampf(amount / 50.0, 0.0, 1.0)
	var radius: float = lerp(100.0, 280.0, t)
	var alpha: float = lerp(0.0, 0.15, t)
	_cleanup_field_vfx(parent, "combo_nano_field")
	var pts := PackedVector2Array()
	var segments := 32
	for i in range(segments):
		var ang := TAU * float(i) / float(segments)
		pts.append(Vector2(cos(ang), sin(ang)) * radius)
	var poly := Polygon2D.new()
	poly.polygon = pts
	poly.position = world_pos
	poly.color = Color(0.2, 0.9, 1.0, alpha)
	poly.z_index = -5  # 盖在地面背景之上、单位之下
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	poly.material = mat
	poly.name = "combo_nano_field"
	parent.add_child(poly)
	poly.add_to_group("battle_vfx")  # 浓度场 name 管理替换，战斗结束若浓度还在则残留


## 战场化学污染可视化（绿色半透明区域）。
## amount: 当前浓度（0~60）；同 spawn_nano_field 参数约定。
static func spawn_chem_field(parent: Node2D, world_pos: Vector2, amount: float) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	if amount <= 0.5:
		_cleanup_field_vfx(parent, "combo_chem_field")
		return
	var t: float = clampf(amount / 60.0, 0.0, 1.0)
	var radius: float = lerp(80.0, 320.0, t)
	var alpha: float = lerp(0.0, 0.18, t)
	_cleanup_field_vfx(parent, "combo_chem_field")
	var pts := PackedVector2Array()
	var segments := 32
	for i in range(segments):
		var ang := TAU * float(i) / float(segments)
		pts.append(Vector2(cos(ang), sin(ang)) * radius)
	var poly := Polygon2D.new()
	poly.polygon = pts
	poly.position = world_pos
	poly.color = Color(0.3, 1.0, 0.2, alpha)
	poly.z_index = -5
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	poly.material = mat
	poly.name = "combo_chem_field"
	parent.add_child(poly)
	poly.add_to_group("battle_vfx")  # 浓度场 name 管理替换，战斗结束若浓度还在则残留


## 清理已存在的浓度场 VFX（防止重复创建）。
static func _cleanup_field_vfx(parent: Node2D, node_name: String) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var old := parent.get_node_or_null(node_name)
	if old != null and is_instance_valid(old):
		old.queue_free()


## 化学爆炸扩散波纹（套路1 chem_burst 触发时）。
## 从源单位向外 radiate 绿色冲击波环。
static func spawn_chem_burst_wave(parent: Node2D, pos: Vector2) -> void:
	spawn_shockwave(parent, pos, 80.0, Color(0.3, 1.0, 0.2, 0.9))


## 纳米传染波纹（套路3 nano_spread 触发时）。
## 青色冲击波环。
static func spawn_nano_spread_wave(parent: Node2D, pos: Vector2) -> void:
	spawn_shockwave(parent, pos, 60.0, Color(0.2, 0.9, 1.0, 0.85))


## 屏幕顶部组合技激活横幅。
## text: 横幅文字；duration: 显示时长（秒）；is_team: 是否全队激活（影响样式+震动）。
static func show_combo_activate_banner(text: String, duration: float = 2.0, is_team: bool = false) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var hud := tree.root.get_node_or_null("Main/HudLayer")
	if hud == null:
		return
	# 防重复：同名横幅未消失则跳过
	if hud.has_node("ComboActivateBanner"):
		return
	var banner := Label.new()
	banner.name = "ComboActivateBanner"
	banner.text = text
	var banner_w: float = 400.0
	banner.size = Vector2(banner_w, 36)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 18 if is_team else 14)
	banner.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6, 1))
	banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	banner.add_theme_constant_override("outline_size", 3)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(banner)
	# v9.x：动态居中 x（原硬编码 440 = (1280-400)/2，stretch/缩放时不居中）。
	# 必须在 add_child 后取 viewport（之前 banner 未入树，get_viewport() 返回 null）。
	# y 起点 -40 保持（与下方 tween 的 position:y 动画解耦，不受影响）。
	var vp_w: float = 1280.0
	var vp := banner.get_viewport()
	if vp != null:
		vp_w = vp.get_visible_rect().size.x
	banner.position = Vector2((vp_w - banner_w) * 0.5, -40)
	# 入场（从上方滑入 + 淡入）
	var tw := banner.create_tween()
	tw.set_parallel(true)
	tw.tween_property(banner, "position:y", 60.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(banner, "modulate:a", 1.0, 0.3)
	# 停留后淡出 + 滑出
	var hold := maxf(duration - 0.6, 0.2)
	tw.chain().tween_interval(hold)
	tw.tween_property(banner, "modulate:a", 0.0, 0.3)
	tw.parallel().tween_property(banner, "position:y", -20.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): if is_instance_valid(banner): banner.queue_free())
	# 全队激活：轻微震动
	if is_team:
		var cam := tree.root.get_node_or_null("Main/BattleContainer/SubViewportContainer/SubViewport/Battlefield/BattleCamera")
		if cam != null and cam.has_method("shake"):
			cam.call("shake", 3.0, 0.15)


## 光束多重攻击次级射线（套路4 beam_split）。
## 从 target_pos 射向各 secondary_pos，color 同主激光。复用 spawn_laser_beam。
static func spawn_beam_split_arcs(parent: Node2D, target_pos: Vector2,
		secondary_positions: Array, color: Color = Color(0.9, 0.8, 1.0, 0.95)) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	for sp in secondary_positions:
		if sp == null:
			continue
		spawn_laser_beam(parent, target_pos, sp, color)


## 光束反射射线（套路4 beam_reflect）。
## 从 target_pos 反射到 reflect_pos，颜色偏暗。
static func spawn_beam_reflect_arc(parent: Node2D, target_pos: Vector2,
		reflect_pos: Vector2) -> void:
	spawn_laser_beam(parent, target_pos, reflect_pos, Color(0.7, 0.6, 0.9, 0.7))


## 弱点暴露指示器（套路5 weakpoint_expose）。
## 目标头顶红色 X 十字，脉动放大，duration 秒后淡出移除。
## parent 应为目标单位的父节点（让指示器跟随世界坐标）。
## v9.x：改走 _indicator_pool（Node2D 父 + 2 Line2D 子结构池化，子节点保留只重置父）。
static func spawn_weakpoint_indicator(parent: Node2D, pos: Vector2, duration: float = 3.0) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var marker := _acquire_indicator("weakpoint")
	if marker == null:
		return
	marker.position = pos
	marker.scale = Vector2.ONE
	marker.modulate = Color(1, 1, 1, 1)
	marker.z_index = 30
	parent.add_child(marker)
	# 脉动呼吸
	var pulse := marker.create_tween()
	pulse.set_loops()
	pulse.tween_property(marker, "scale", Vector2(1.2, 1.2), 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(marker, "scale", Vector2(0.85, 0.85), 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# duration 后淡出移除
	var fade := marker.create_tween()
	fade.tween_interval(duration)
	fade.tween_property(marker, "modulate:a", 0.0, 0.3)
	fade.tween_callback(func(): if is_instance_valid(marker): _release_indicator(marker))
	# 记录 tween 供 release 时 kill（脉动是 loops 无限，淡出完成后 callback 触发 release）
	marker.set_meta("_vfx_tweens", [pulse, fade])


## 雷达锁定圈（套路5 radar_lock）。
## 目标脚下蓝色旋转扫描圈，duration 秒后淡出。
## parent 应为目标单位的父节点。
## v9.x：改走 _indicator_pool。防重复仍用 name 标记（acquire 时设，release 时清）。
static func spawn_radar_lock_ring(parent: Node2D, pos: Vector2, duration: float = 6.0) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	# 防重复：同一位置已有雷达圈则跳过（用 name 标记）
	var ring_name := "combo_radar_lock_%d_%d" % [int(pos.x), int(pos.y)]
	if parent.has_node(ring_name):
		return
	var poly: Polygon2D = _acquire_indicator("radar_lock")
	if poly == null:
		return
	poly.name = ring_name  # 防重复标记（release 时清除，避免池中残留 name 干扰 has_node）
	poly.position = Vector2(pos.x, pos.y + 18)  # 脚下
	poly.scale = Vector2.ONE
	poly.rotation = 0.0
	poly.modulate = Color(1, 1, 1, 1)
	poly.scale = Vector2(1.6, 1.6)  # v14: 读图 5/10"环太细弱"——加大一档
	poly.color = Color(0.40, 0.95, 1.0, 0.65)
	poly.z_index = 15
	parent.add_child(poly)
	# 缓慢旋转
	var rot_tw := poly.create_tween()
	rot_tw.set_loops()
	rot_tw.tween_property(poly, "rotation", TAU, 4.0).set_trans(Tween.TRANS_LINEAR)
	# v14 内环:反向旋转的红色警示环,双环结构让"锁定"语义更强
	var inner: Polygon2D = _acquire_indicator("radar_lock")
	if inner != null:
		inner.position = Vector2(pos.x, pos.y + 18)
		inner.scale = Vector2.ONE
		inner.rotation = 0.0
		inner.modulate = Color(1, 1, 1, 1)
		inner.color = Color(1.0, 0.45, 0.35, 0.8)
		inner.z_index = 15
		parent.add_child(inner)
		var rot2 := inner.create_tween()
		rot2.set_loops()
		rot2.tween_property(inner, "rotation", -TAU, 2.4).set_trans(Tween.TRANS_LINEAR)
		var fade2 := inner.create_tween()
		fade2.tween_interval(duration)
		fade2.tween_property(inner, "modulate:a", 0.0, 0.5)
		fade2.tween_callback(func(): if is_instance_valid(inner): _release_indicator(inner))
		inner.set_meta("_vfx_tweens", [rot2, fade2])
	# duration 后淡出
	var fade_tw := poly.create_tween()
	fade_tw.tween_interval(duration)
	fade_tw.tween_property(poly, "modulate:a", 0.0, 0.5)
	fade_tw.tween_callback(func(): if is_instance_valid(poly): _release_indicator(poly))
	poly.set_meta("_vfx_tweens", [rot_tw, fade_tw])


## 激光谐振标记环（套路4 laser_resonance）。
## 目标头顶白色光环，层数越多越亮。持续 5s（与谐振 meta 同步刷新）。
## v9.x：改走 _indicator_pool。
static func spawn_resonance_ring(parent: Node2D, pos: Vector2, stacks: int, duration: float = 5.0) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	if stacks <= 0:
		return
	var ring: Polygon2D = _acquire_indicator("resonance")
	if ring == null:
		return
	ring.position = Vector2(pos.x, pos.y - 30)  # 头顶
	ring.scale = Vector2.ONE
	ring.modulate = Color(1, 1, 1, 1)
	var alpha: float = clampf(0.4 + stacks * 0.14, 0.4, 0.95)  # v14: 读图 5/10"偏淡"——基础亮度与层数增益翻倍
	ring.color = Color(0.85, 0.95, 1.0, alpha)
	ring.z_index = 28
	parent.add_child(ring)
	# 脉动
	var pulse := ring.create_tween()
	pulse.set_loops()
	pulse.tween_property(ring, "scale", Vector2(1.3, 1.3), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(ring, "scale", Vector2(0.85, 0.85), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# duration 后淡出
	var fade := ring.create_tween()
	fade.tween_interval(duration)
	fade.tween_property(ring, "modulate:a", 0.0, 0.3)
	fade.tween_callback(func(): if is_instance_valid(ring): _release_indicator(ring))
	ring.set_meta("_vfx_tweens", [pulse, fade])


## v14: 持续削弱印记环(暗蚀/虚弱类 debuff 命中后长留 3-5s)。
## 读图 6/10"读作一次性爆炸而非持续削弱"——双环反向旋转+呼吸脉动,
## 让"debuff 挂在身上"的持续语义成立(爆炸消散后环还在转 = 还在被削弱)。
static func spawn_lingering_debuff_ring(parent: Node2D, pos: Vector2, color: Color, duration: float = 4.0) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	if DT.is_motion_reduce():
		return
	var root := Node2D.new()
	root.position = pos
	root.z_index = 12
	parent.add_child(root)
	root.add_to_group("battle_vfx")
	for layer in range(2):
		var ring := Polygon2D.new()
		var r: float = 34.0 + float(layer) * 12.0
		var pts := PackedVector2Array()
		for i in range(28):
			var ang := TAU * float(i) / 28.0
			pts.append(Vector2(cos(ang), sin(ang)) * r)
		ring.polygon = pts
		ring.color = Color(color.r, color.g, color.b, 0.0)
		ring.material = _get_add_mat()
		root.add_child(ring)
		var dir: float = 1.0 if layer == 0 else -1.0
		var rot := ring.create_tween()
		rot.set_loops()
		rot.tween_property(ring, "rotation", dir * TAU, 3.5 + float(layer)).set_trans(Tween.TRANS_LINEAR)
		var pulse := ring.create_tween()
		pulse.set_loops()
		pulse.tween_property(ring, "scale", Vector2(1.08, 1.08), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(ring, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		var fin := ring.create_tween()
		fin.tween_property(ring, "color:a", 0.42 - float(layer) * 0.14, 0.4)
	# 整体 duration 后淡出移除
	var fade := root.create_tween()
	fade.tween_interval(duration)
	fade.tween_property(root, "modulate:a", 0.0, 0.6)
	fade.tween_callback(func(): if is_instance_valid(root): root.queue_free())


## v14: 亮度保持重着色 ADD 材质(按颜色缓存共享)。
## 把橙红火焰贴图按亮度结构重着色为技能专属色(虚空紫/闪电蓝),modulate 乘法做不到。
static var _tint_shader: Shader = null
static var _tint_mats: Dictionary = {}

static func _get_tint_add_mat(tint: Color) -> ShaderMaterial:
	if _tint_shader == null:
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;\n" \
			+ "render_mode blend_add;\n" \
			+ "uniform vec4 tint : source_color = vec4(1.0);\n" \
			+ "uniform float amount : hint_range(0.0, 1.0) = 0.72;\n" \
			+ "void fragment() {\n" \
			+ "\tvec4 c = texture(TEXTURE, UV) * COLOR;\n" \
			+ "\tfloat lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));\n" \
			+ "\tvec3 recol = lum * tint.rgb * 1.6;\n" \
			+ "\tCOLOR = vec4(mix(c.rgb, recol, amount), c.a);\n" \
			+ "}"
		_tint_shader = sh
	var key := tint.to_html(false)
	if not _tint_mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = _tint_shader
		m.set_shader_parameter("tint", Color(tint.r, tint.g, tint.b, 1.0))
		m.set_shader_parameter("amount", 0.72)
		_tint_mats[key] = m
	return _tint_mats[key] as ShaderMaterial


# =========================================================================
## v9.x: 组合技指示器对象池（acquire/release + 三种 kind 的节点构造）
# =========================================================================

## 从指示器池取一个节点（按 kind）。池空或达上限则新建；满则返回 null 节流。
## kind: "weakpoint"(Node2D+2Line2D子) / "radar_lock"(Polygon2D) / "resonance"(Polygon2D)
## 返回的节点已剥离残留 parent、kill 残留 tween、重置 transform/modulate。
static func _acquire_indicator(kind: String) -> Node2D:
	var pool: Array = _indicator_pool.get(kind, [])
	# 从池尾向前取，首个有效节点返回
	var i := pool.size() - 1
	while i >= 0:
		var candidate: Node = pool[i]
		pool.remove_at(i)
		if candidate != null and is_instance_valid(candidate) and not candidate.is_queued_for_deletion():
			# 剥离残留 parent（防 add_child "already has a parent"）
			if candidate.get_parent() != null:
				candidate.get_parent().remove_child(candidate)
			# kill 残留 tween（脉动 loops + 淡出，复用时重建）
			_kill_indicator_tweens(candidate)
			# 重置通用状态
			candidate.visible = true
			candidate.modulate = Color(1, 1, 1, 1)
			candidate.scale = Vector2.ONE
			candidate.rotation = 0.0
			# radar_lock 带 name 防重复标记，acquire 时清除（由 spawn 重设）
			if not candidate.name.is_empty() and candidate.name.begins_with("combo_radar_lock_"):
				candidate.name = ""
			_indicator_pool[kind] = pool
			_active_indicators += 1
			return candidate
		i -= 1
	_indicator_pool[kind] = pool
	# 池空：检查全局上限
	if _active_indicators >= MAX_INDICATORS:
		return null  # 节流
	_active_indicators += 1
	# 按 kind 新建对应结构
	return _create_indicator(kind)


## 新建一个指示器节点（首次或池扩容时）。
## 所有新建节点都 set_meta("_vfx_kind", kind)，_release_indicator 据此归还对应池。
static func _create_indicator(kind: String) -> Node2D:
	match kind:
		"weakpoint":
			# Node2D 父 + 2 Line2D 子（X 十字），子节点配置固定，池化时保留只重置父
			var marker := Node2D.new()
			marker.set_meta("_vfx_kind", kind)
			var line_a := Line2D.new()
			line_a.width = 3.0
			line_a.default_color = Color(1.0, 0.3, 0.2, 1.0)
			line_a.joint_mode = Line2D.LINE_JOINT_ROUND
			line_a.end_cap_mode = Line2D.LINE_CAP_ROUND
			line_a.add_point(Vector2(-14, -14))
			line_a.add_point(Vector2(14, 14))
			marker.add_child(line_a)
			var line_b := Line2D.new()
			line_b.width = 3.0
			line_b.default_color = Color(1.0, 0.3, 0.2, 1.0)
			line_b.joint_mode = Line2D.LINE_JOINT_ROUND
			line_b.end_cap_mode = Line2D.LINE_CAP_ROUND
			line_b.add_point(Vector2(-14, 14))
			line_b.add_point(Vector2(14, -14))
			marker.add_child(line_b)
			return marker
		"radar_lock":
			# 雷达锁定圈：28 段实心圆（半径 30），ADD 混合。顶点固定，池化时只重设 color/position。
			var poly := Polygon2D.new()
			poly.set_meta("_vfx_kind", kind)
			poly.material = _get_add_mat()
			poly.polygon = _build_circle_polygon(28, 30.0)
			return poly
		"resonance":
			# 谐振环：24 段实心圆（半径 16），ADD 混合。顶点固定。
			var poly := Polygon2D.new()
			poly.set_meta("_vfx_kind", kind)
			poly.material = _get_add_mat()
			poly.polygon = _build_circle_polygon(24, 16.0)
			return poly
		_:
			# 未知 kind 兜底：返回普通 Node2D（不应发生）
			var fallback := Node2D.new()
			fallback.set_meta("_vfx_kind", "resonance")
			return fallback


## 归还指示器到池。kill 所有 tween、移除 parent、清 name、归还对应 kind 池。
## 设计与 _release_ring 一致：失效节点直接返回不操作（不计入 active，避免计数变负）。
## 指示器生命周期长（3-6s），战斗拆卸时 fade callback 可能不触发 → 计数有慢速泄漏风险，
## 但与现有 ring/spark 池同等行为，且泄漏只导致节流（不崩溃），可接受。
static func _release_indicator(node: Node2D) -> void:
	if node == null or not is_instance_valid(node):
		return  # 失效节点：不操作（不计入 active，避免计数变负）
	# kill 该节点所有 tween（通过 _vfx_tweens meta 记录的引用）
	_kill_indicator_tweens(node)
	# 移除 parent
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	# 清 name（radar_lock 防重复标记），避免池中残留 name 干扰下次 has_node 检查
	if not node.name.is_empty() and node.name.begins_with("combo_radar_lock_"):
		node.name = ""
	node.visible = false
	# 按 _vfx_kind meta 归还对应池
	var kind: String = node.get_meta("_vfx_kind", "")
	if kind.is_empty():
		kind = "resonance"  # 兜底（未知 kind 归到最简单的 resonance 池）
	var pool: Array = _indicator_pool.get(kind, [])
	if pool.size() < MAX_INDICATORS:
		pool.append(node)
		_indicator_pool[kind] = pool
	else:
		node.queue_free()
	_active_indicators -= 1


## kill 指示器节点记录的所有 tween（_vfx_tweens meta），清 meta。
## 脉动 tween 是 set_loops() 无限循环，release 时若不 kill 会继续跑并泄露。
static func _kill_indicator_tweens(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.has_meta("_vfx_tweens"):
		var tweens: Array = node.get_meta("_vfx_tweens", [])
		for tw in tweens:
			if tw is Tween and (tw as Tween).is_valid():
				(tw as Tween).kill()
		node.remove_meta("_vfx_tweens")


## 构建实心圆 Polygon2D 顶点数组（segments 段，radius 半径）。
## 供 radar_lock / resonance 指示器建顶点用（顶点固定，池化时不重建）。
static func _build_circle_polygon(segments: int, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segments):
		var ang := TAU * float(i) / float(segments)
		pts.append(Vector2(cos(ang), sin(ang)) * radius)
	return pts


## v9.x：战斗结束时重置指示器池（由 BattleManager.end_battle 调用）。
## 解决长生命周期指示器（3-6s）的计数泄漏：战斗中途结束/场景拆卸时 fade callback
## 可能不触发，节点被外部 free 而 _active_indicators 未 -1，累积多场后池被永久锁死。
## 本方法：① free 池中所有归还节点 ② 清空池 ③ 计数归零。
## 仍在场景树中活跃的指示器（未淡出）由场景树拆卸自然回收，不在此强行清理——
## reset 后计数归零即允许下场战斗重新分配，不再因计数泄漏阻塞节流。
static func reset_indicator_pool() -> void:
	for kind in _INDICATOR_KINDS:
		var pool: Array = _indicator_pool.get(kind, [])
		for node in pool:
			if node != null and is_instance_valid(node):
				node.queue_free()
		_indicator_pool[kind] = []
	_active_indicators = 0
