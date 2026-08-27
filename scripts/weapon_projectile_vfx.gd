extends RefCounted
class_name WeaponProjectileVfx
## 武器弹道 / 命中贴图与缩放（玩家 Bullet 与敌方批处理共用）
## v6.0: 按武器名称查找专属贴图

const GC = preload("res://resources/game_constants.gd")
const WeaponVfxMapping: GDScript = preload("res://data/weapon_vfx_mapping.gd")
# v20.16: 直射亚类分类器——弹头形状亚类分化（机枪/步枪/直射炮三形分流）
const DirectWeaponFlavor = preload("res://data/direct_weapon_flavor.gd")
# v8.1: 命中特效委托给分层化工厂（冲击波环+主火花+碎片烟尘）
const VfxFactory = preload("res://scripts/battle/vfx_impact_factory.gd")

const TEX_DIR := "res://assets/effects/projectiles/weapons_realistic/"
## v8.4: 通用命中贴图兜底——仓库现有但此前零引用的通用爆炸贴图。
## 当武器 display_name 不在 WEAPON_ID_MAP（如"炮射导弹"/"萨姆-7防空导弹"/未来单位）时，
## fallback 到此贴图，保证所有重型爆炸武器的命中贴图层都能生效（而非回退纯粒子）。
const FALLBACK_IMPACT_TEX := preload(TEX_DIR + "weapon_artillery_impact.png")
## v9.2: 按武器类型的通用命中贴图——仓库现有但此前零引用的 5 张通用图。
## 让 OMEGA/RAIL/激光/狙击/霰弹/轻武器的命中从纯粒子升级为"贴图+粒子"分层，
## 大幅提升真实感（此前这些武器命中只有 CPUParticles2D 小方块）。
const IMPACT_TEX_OMEGA := preload(TEX_DIR + "weapon_impact_omega.png")        # 能量/磁轨/欧米茄/激光
const IMPACT_TEX_SNIPER := preload(TEX_DIR + "weapon_impact_sniper.png")      # 狙击
const IMPACT_TEX_SHOTGUN := preload(TEX_DIR + "weapon_impact_shotgun.png")    # 霰弹
const IMPACT_TEX_SMALL_ARMS := preload(TEX_DIR + "weapon_impact_small_arms.png")  # 轻武器(机枪/步枪/手枪/直射)
const IMPACT_TEX_EXPLOSIVE := preload(TEX_DIR + "weapon_impact_explosive.png")    # 通用爆炸(曲射/空射兜底)
## v9.2: 爆炸帧动画序列——下放核武帧动画范式给常规爆炸武器。
## 6 帧 512×512（火球膨胀→烟尘弥散），10fps，0.6s 总长。
## 生成工作流：docs/VFX特效纹理生成工作流.md，当前为占位透明 PNG。
const EXPLOSION_FRAMES_DIR := "res://assets/effects/explosion_frames/"
const EXPLOSION_CONV_FRAMES := [
	preload(EXPLOSION_FRAMES_DIR + "explosion_conv_f0.png"),
	preload(EXPLOSION_FRAMES_DIR + "explosion_conv_f1.png"),
	preload(EXPLOSION_FRAMES_DIR + "explosion_conv_f2.png"),
	preload(EXPLOSION_FRAMES_DIR + "explosion_conv_f3.png"),
	preload(EXPLOSION_FRAMES_DIR + "explosion_conv_f4.png"),
	preload(EXPLOSION_FRAMES_DIR + "explosion_conv_f5.png"),
]
const EXPLOSION_ENERGY_FRAMES := [
	preload(EXPLOSION_FRAMES_DIR + "explosion_energy_f0.png"),
	preload(EXPLOSION_FRAMES_DIR + "explosion_energy_f1.png"),
	preload(EXPLOSION_FRAMES_DIR + "explosion_energy_f2.png"),
	preload(EXPLOSION_FRAMES_DIR + "explosion_energy_f3.png"),
	preload(EXPLOSION_FRAMES_DIR + "explosion_energy_f4.png"),
	preload(EXPLOSION_FRAMES_DIR + "explosion_energy_f5.png"),
]

## v9.2: 按 weapon_type 返回通用命中贴图（无专属贴图时的类型化兜底，区别于 FALLBACK 的单一图）。
## 返回 null 表示该类型不推荐贴图层（理论上不会发生，所有类型都有映射）。
## v9.6(审计V9) 域约定：weapon_type 碰撞值按【新枚举优先】解释——与 proj_texture() 的
## "New enum first" 一致。即 1/2 恒为 INDIRECT/AERIAL（曲射/空射→爆炸贴图）；
## legacy RIFLE(1)/MG(2) 在 VFX 层已让位（其弹丸贴图 PROJ_TEX_LEGACY[1]/[2] 同样不达）。
## 新增分派代码时严禁在同一 match 里混写两套枚举语义（本次审计的病根）。
static func generic_impact_tex_by_wt(weapon_type: int) -> Texture2D:
	match weapon_type:
		10, 11, 8:   # legacy OMEGA / RAIL / LASER — 能量类，复用 omega 贴图（蓝白能量爆裂感）
			return IMPACT_TEX_OMEGA
		6:           # legacy SNIPER（光束武器名覆盖也返回 6）
			return IMPACT_TEX_SNIPER
		5:           # legacy SHOTGUN
			return IMPACT_TEX_SHOTGUN
		0, 4:        # 新枚举 DIRECT / legacy SMG / legacy PISTOL — 轻武器
			return IMPACT_TEX_SMALL_ARMS
		1, 2:        # 新枚举 INDIRECT/AERIAL — 曲射/空射，无专属时用通用爆炸
			return IMPACT_TEX_EXPLOSIVE
		3, 7, 9:     # legacy ROCKET/FLAK/MISSILE + 新枚举 SUPPORT(3 撞值) — 爆炸类，走专属查表，兜底通用爆炸
			return IMPACT_TEX_EXPLOSIVE
		_:           # 未知类型，兜底
			return IMPACT_TEX_EXPLOSIVE

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
	1: 0.70,  # v17m: 曲射炮弹可见性（AI 批'弹道不可见'）。R30 实验放大至 0.95 损害轨迹评分，回退
	2: 0.60,  # R30 实验放大至 0.85 损害轨迹评分，回退
	# v9.2: 拉大轻武器与终极武器的弹体尺寸差异，让"小兵 vs 终极单位"一眼可辨。
	#   轻武器（SMG/PISTOL）：保持小但可见（显示 ~4-5px 高）
	#   中型（RIFLE/MG/SHOTGUN/SNIPER/FLAK）：中等（显示 ~6-10px 高）
	#   能量/重型（LASER/OMEGA/RAIL/MISSILE/ROCKET）：粗壮（显示 ~10-18px 高，威慑感）
	# Legacy: SMG=0, RIFLE=1, MG=2, ROCKET=3, PISTOL=4, SHOTGUN=5, SNIPER=6, FLAK=7, LASER=8, MISSILE=9, OMEGA=10, RAIL=11
	3: 0.95,    # ROCKET — v17m: 0.70→0.95（AI 批"弹道近乎隐形"，火箭弹体要有存在感）
	5: 0.50,    # SHOTGUN — 霰弹团（原 0.33，加粗让霰弹团可见）
	6: 0.55,    # SNIPER — 高速穿甲弹（原 0.33）
	7: 0.60,    # FLAK — 高炮弹（原 0.39）
	8: 0.70,    # LASER — 能量光束（原 0.30）
	9: 0.95,    # MISSILE — v17m: 0.75→0.95（同火箭，弹体可见性）
	10: 0.95,   # OMEGA — 终极能量炮，最粗（原 0.51）
	11: 0.85,   # RAIL — 电磁轨道炮（原 0.48）
	4: 0.38,    # PISTOL — 轻武器但可见（原 0.22，加粗让手枪弹看得见）
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

## v18: 命中贴图内容实宽表（PIL getbbox 实测；画布实为 1536×1024，非旧注释假设的 512px）。
## 新增贴图必须先量实寸再录（vfx-tuning skill 第 2 步铁律——v17"注释 32px 实为 128px"
## 同型病根已三次复发）。key=文件名去扩展名。
const IMPACT_CONTENT_W: Dictionary = {
	"weapon_artillery_impact": 857.0,    # 1024 画布；按名查表唯一实存贴图（hash 版全部缺失，均回落此图）
	"weapon_impact_small_arms": 1062.0,  # 1536 画布
	"weapon_impact_sniper": 1194.0,
	"weapon_impact_shotgun": 1263.0,
	"weapon_impact_explosive": 1410.0,
	"weapon_impact_omega": 1274.0,
}

## v18: 按武器族的目标显示宽（px，对齐 64px 参考单位验收规格）。
## 狙击=0.75×单位（精确药剂感）/ 霰弹=1.1× / 爆炸族=1.75×（炮级上限 2×单位内）。
## 注：8/10/11 的签名特效分支在本层之前早退，表中值仅为兜底。
const IMPACT_TARGET_W_BY_WT: Dictionary = {
	6: 48.0,    # SNIPER — 精确命中小爆点
	5: 72.0,    # SHOTGUN — 散射命中
	8: 96.0,    # LASER（兜底）
	# v18-R4: 爆炸族目标宽 112→96（见表内注释）
	1: 96.0,    # INDIRECT — 炮级
	2: 96.0,    # AERIAL
	3: 96.0,    # ROCKET — v18-R4: 112→96（同爆炸族）
	# v18-R4: 爆炸族(1/2/3/7/9) 112→96px——规格"火炮级爆炸直径≈单位高度1-2倍"，
	# 96px=1.5×单位取中值；112 叠 HEAVY×1.3 后 146px 仍在 2×上限内。
	7: 96.0,    # FLAK
	9: 96.0,    # MISSILE
	10: 112.0,  # OMEGA（兜底）
	11: 112.0,  # RAIL（兜底）
}

## v18: 命中贴图内容宽查表。未收录贴图回退 画布宽×0.7（同目录贴图内容占比实测 0.69-0.92
## 的保守中值），避免未实测贴图再次爆尺寸。
static func _impact_content_width(texture: Texture2D) -> float:
	if texture == null:
		return 512.0
	var path: String = texture.resource_path
	if not path.is_empty():
		var fname: String = path.get_file().get_basename()
		if IMPACT_CONTENT_W.has(fname):
			return float(IMPACT_CONTENT_W[fname])
	return float(texture.get_width()) * 0.7

const REF_TEX_PX: float = 512.0
# v8.3 视觉增强：0.05 → 0.10（×2），让贴图弹体在战场上清晰可见
const PROJ_DISPLAY_SCALE_MUL: float = 0.10

## ========== v9.4: 程序化弹头多边形（替代长条横向贴图）==========
## 原因：weapon_*_projectile.png 系列是水平长条贴图（比例 4:1~12:1），弹道斜向时
## 即使旋转也对不齐飞行方向，视觉违和（长条横躺）。改用程序化 7 点弹头多边形：
## 弹体矩形 + 弹头锥形，指向 +X，原点居中（绕中心旋转），任意角度自然对齐。
## 被 simple_enemy/player_projectile_batch（直射轻武器 MultiMesh）和 bullet.gd 共用。
## 算法迁移自 bullet.gd:_apply_bullet_shape（v8.3 基准 ×2），消除重复定义。

# 程序化弹头战场显示缩放。基准多边形约 12×7 逻辑像素（body=8/nose=4/half_h=3.5），
# × 此缩放后约 9.6×5.6 px，与原长条贴图轻武器显示尺寸（SMG ~18×3 / PISTOL ~15×3）量级相当。
# batch 调用 build_bullet_arraymesh 时传入；bullet.gd 的 Polygon2D 路径用各自 size_scale。
const PROJ_BULLET_DISPLAY_SCALE: float = 1.3  # v17k-R2: 0.8→1.3（10px 弹体缩图后不可读，AI 9/12 格批'弹道隐形'）

## ── v20.16: 直射亚类形状层键（batch MultiMesh 渲染层合成键）──
## 病根：玩家侧直射武器 fire() 传入 wt 恒为新枚举 DIRECT=0 → 批处理层键恒 0，
## 步枪/机枪/坦克炮全渲染同一 SMG 网格；legacy RIFLE(1)/MG(2) 在 build_bullet_points
## 又共用同一分支——弹头形状同质化。修复：用 DirectWeaponFlavor（武器名优先分类，
## 与命中端 resolve_visual_wt 同原则）把直射弹道分流到亚类专属渲染层，每层独立网格。
## 键值取 100+，避开 0-11 的 wt 值域（新枚举 4 值 + legacy 12 值均不撞）。
const FLAVOR_LAYER_RIFLE: int = 100     # 步枪——细长尖锥
const FLAVOR_LAYER_MG: int = 101        # 机枪——短钝弹丸
const FLAVOR_LAYER_TANK_GUN: int = 102  # 直射坦克炮——大号钝头炮弹
## v20.16d: 手枪/卡宾——微型近光点弹体。此前 SMALL_ARMS 与 GENERIC 共用 wt 档默认层，
## 形状/染色/曳光/弹速四轴全同（用户主诉"单体弹道差异太小"的病根之一）。
const FLAVOR_LAYER_SMALL_ARMS: int = 103
## 坦克炮弹战场显示缩放（其余亚类沿用 PROJ_BULLET_DISPLAY_SCALE；炮弹要一眼炮弹级）
const TANK_GUN_DISPLAY_SCALE: float = 2.0

## 亚类 → 形状层键。GENERIC/NONE 返回 -1（用原 wt 层，形状零变化）。
static func flavor_layer_key(flavor: int) -> int:
	match flavor:
		DirectWeaponFlavor.Flavor.RIFLE: return FLAVOR_LAYER_RIFLE
		DirectWeaponFlavor.Flavor.MG: return FLAVOR_LAYER_MG
		DirectWeaponFlavor.Flavor.TANK_GUN: return FLAVOR_LAYER_TANK_GUN
		DirectWeaponFlavor.Flavor.SMALL_ARMS: return FLAVOR_LAYER_SMALL_ARMS
		_: return -1

## 形状层键 → 亚类（批处理 _make_layer 反解用）。非亚类键返回 -1。
static func _flavor_for_layer_key(layer_key: int) -> int:
	match layer_key:
		FLAVOR_LAYER_RIFLE: return DirectWeaponFlavor.Flavor.RIFLE
		FLAVOR_LAYER_MG: return DirectWeaponFlavor.Flavor.MG
		FLAVOR_LAYER_TANK_GUN: return DirectWeaponFlavor.Flavor.TANK_GUN
		FLAVOR_LAYER_SMALL_ARMS: return DirectWeaponFlavor.Flavor.SMALL_ARMS
		_: return -1

## ── v20.16b: 直射亚类弹道参数（弹速/弹体染色/曳光线，单射源）──
## 消费方：batch 两文件的 speed/tint/tracer 与 bullet.gd 的弹速/弹头染色。
## 配色与 bullet.gd _trail_color_for_weapon 同一语言（阵营无关——武器辨识优先，
## 阵营信息由命中环承担，规格通用原则 5）。
## NONE/SMALL_ARMS/GENERIC 全部返回入参原值（零行为变化）。

## 亚类弹速系数（乘在 wt 档弹速上，保留敌方 legacy 槽位的基础差异）。
## v20.16d: 系数拉开——v20.16b 的 0.75~1.3（540-936px/s）在 300-500px 交火距离下飞行时间
## 差 <0.15s 肉眼读不出；拉开到 0.75~1.5 后弹速阶梯：坦克炮 540 < 手枪 576 < 机枪 612 <
## 通用 720 < 步枪 1080（<狙击 1100 <激光 1400，保持"步枪不快过狙击"的层级）。
static func flavor_speed_mul(flavor: int) -> float:
	match flavor:
		DirectWeaponFlavor.Flavor.RIFLE: return 1.50
		DirectWeaponFlavor.Flavor.MG: return 0.85
		DirectWeaponFlavor.Flavor.TANK_GUN: return 0.75
		DirectWeaponFlavor.Flavor.SMALL_ARMS: return 0.80
		_: return 1.0

## 亚类弹速（base 为 wt 档弹速）。未分化亚类恒等返回。
static func flavor_speed(flavor: int, base_speed: float) -> float:
	return base_speed * flavor_speed_mul(flavor)

## 亚类弹头染色（阵营无关）。仅对已分化亚类（flavor_layer_key >= 0）有意义。
static func flavor_tint(flavor: int) -> Color:
	match flavor:
		DirectWeaponFlavor.Flavor.RIFLE: return Color(0.62, 0.95, 1.0)    # 步枪 冷青白
		DirectWeaponFlavor.Flavor.MG: return Color(1.0, 0.95, 0.32)       # 机枪 亮黄
		DirectWeaponFlavor.Flavor.TANK_GUN: return Color(1.0, 0.74, 0.30) # 坦克炮 橙白
		# v20.16d: 手枪暖白（近白微暖）——与机枪亮黄拉开（弹体小，色温是主要辨识轴）
		DirectWeaponFlavor.Flavor.SMALL_ARMS: return Color(1.0, 0.96, 0.82)
		_: return Color(1.0, 1.0, 1.0)

## 渲染层弹头染色：亚类层用亚类色（阵营无关），基础层返回阵营基础 tint。
static func layer_tint(layer_key: int, base_tint: Color) -> Color:
	var f := _flavor_for_layer_key(layer_key)
	if f >= 0:
		return flavor_tint(f)
	return base_tint

## 亚类曳光线宽度。机枪基准 / 步枪细 / 坦克炮粗（重弹余辉，非细 streak）/ 手枪窄。
## v20.16d: 机枪 2.5→3.0（弹幕流加粗）、步枪 2.0→1.8（细亮快弹）。
static func tracer_width_for(layer_key: int) -> float:
	match layer_key:
		FLAVOR_LAYER_MG: return 3.0
		FLAVOR_LAYER_RIFLE: return 1.8
		FLAVOR_LAYER_TANK_GUN: return 3.5
		FLAVOR_LAYER_SMALL_ARMS: return 2.0
		_: return 2.5

## 亚类曳光线长度。机枪加长（弹幕感）/ 步枪略长（精确轨迹）/ 坦克炮缩短
## （重弹本体即视觉主体，曳光只留余辉）。
## v20.16d: 长度拉开——机枪 34→42 / 步枪 30→46（速度 1080 配长曳光读"快"）/
## 手枪 12（光点短闪）；v20.16b 的 26/30/34 三档肉眼不可分。
static func tracer_len_for(layer_key: int) -> float:
	match layer_key:
		FLAVOR_LAYER_MG: return 42.0
		FLAVOR_LAYER_RIFLE: return 46.0
		FLAVOR_LAYER_TANK_GUN: return 14.0
		FLAVOR_LAYER_SMALL_ARMS: return 12.0
		_: return 26.0

## 亚类曳光线颜色（同 flavor_tint 语言，曳光透明度 0.82）。基础层返回阵营基准色。
static func tracer_color_for(layer_key: int, base_color: Color) -> Color:
	var f := _flavor_for_layer_key(layer_key)
	if f < 0:
		return base_color
	var c := flavor_tint(f)
	c.a = 0.82
	return c

## ── v20.18: 单发路径点射节奏（视觉 burst）──
## 病根：数据层射速集中在 0.67-1.5/s，走单发 Bullet 路径的武器每 0.7-1.5s 一发，
## 机枪/步枪/手枪画面节奏完全相同（无"连发感"）。v20.18b 机枪数据层弹幕化后，
## 射速>2 的机枪进 batch 弹幕路径；≤2 的武器（步枪/手枪/二战重机枪）在单发路径
## 用视觉点射补节奏：一次攻击伤害只结算一次，后续发为纯视觉弹（delay 错开）。
## 消费方：construct_unit_ai 单发路径（敌方轻武器无条件走 batch，无需分派）。
const BURST_INTERVAL: float = 0.09  ## 点射间隔（秒）——60fps 下 5-6 帧，读"哒哒哒"

## 亚类点射数。机枪 3 连珠 / 步枪·冲锋枪 2 连发 / 手枪·坦克炮单发（重武器语义单发）。
static func burst_count_for(flavor: int) -> int:
	match flavor:
		DirectWeaponFlavor.Flavor.MG: return 3
		DirectWeaponFlavor.Flavor.RIFLE: return 2
		DirectWeaponFlavor.Flavor.GENERIC: return 2
		_: return 1  # SMALL_ARMS/TANK_GUN/NONE——单发

## ── v20.19: 机枪换弹周期（射击-停顿-再射击）──
## 病根：机枪匀速连射（2.0/s×3 连珠）无停顿，读感是"永动机"——真实机枪打完弹链
## 需换弹（用户提议"射击一会儿，等待，再射击"）。周期制：连续射击 SUSTAIN 秒 →
## 停火换弹 RELOAD 秒 → 循环。DPS 恒定红线：停顿期损失以单发伤害补偿
## DMG_COMP=(SUSTAIN+RELOAD)/SUSTAIN 预支（与 v20.18b 射速×2/atk÷2 同原则）。
## 消费方：construct_unit_ai（玩家侧）与 enemy_unit（敌方侧）的 do_attack 入口 gate。
const MG_SUSTAIN_SEC: float = 4.0   ## 连续射击窗口（秒）
const MG_RELOAD_SEC: float = 1.6    ## 换弹停顿窗口（秒）
## 伤害补偿系数——射击窗口内每发伤害预乘，补偿停顿期的 DPS 损失（5.6/4.0=1.4）
const MG_DMG_COMP: float = (MG_SUSTAIN_SEC + MG_RELOAD_SEC) / MG_SUSTAIN_SEC

## 是否启用换弹周期的武器（仅 MG 亚类直射；曲射/坦克炮/能量武器不适用）。
static func mg_cycle_active(weapon_name: String, weapon_type: int = 0) -> bool:
	return DirectWeaponFlavor.classify(weapon_name, weapon_type) == DirectWeaponFlavor.Flavor.MG

## ── v20.16c: TANK_GUN 口径量级分化（炮弹尺寸/曳光粗细随口径分层）──
## 病根：TANK_GUN 是单桶——FT-17"57mm/75mm坦克炮"与重装机甲"105mm主炮"（乃至
## 巨神"105mm/120mm主炮"、虚空领主"125mm滑膛炮"）弹道全同，初级坦克炮与
## 终级机甲主炮无视觉分层。口径数字就在武器名里，解析最大口径（"57mm/75mm"
## 取 75）分四档：≤60mm 0.65 / 61-90mm 0.85 / 91-115mm 1.05 / ≥116mm 1.25。
## 消费方 bullet.gd（坦克炮射速低，全走单发路径）：size_scale 与曳光宽同乘此系数。
## 无口径信号/解析失败返回 1.0（=105mm 档，主炮默认中档）。带缓存（每发 setup 查表）。
static var _caliber_scale_cache: Dictionary = {}

static func tank_caliber_scale(weapon_name: String) -> float:
	if weapon_name.is_empty():
		return 1.0
	if _caliber_scale_cache.has(weapon_name):
		return float(_caliber_scale_cache[weapon_name])
	var caliber: float = 0.0
	var re := RegEx.new()
	if re.compile("(\\d{2,3})\\s*mm") == OK:
		for m: RegExMatch in re.search_all(weapon_name):
			caliber = maxf(caliber, float(m.get_string(1).to_float()))
	var scale: float = 1.0
	if caliber > 0.0:
		if caliber <= 60.0:
			scale = 0.65   # 37/57mm 早期小口径
		elif caliber <= 90.0:
			scale = 0.85   # 75/76/85mm 中口径
		elif caliber <= 115.0:
			scale = 1.05   # 105mm 主炮档
		else:
			scale = 1.25   # 120/125mm 重主炮（终级单位）
	_caliber_scale_cache[weapon_name] = scale
	return scale

## ── v20.17: 曲射/空射弹道亚类（名字→弧线/节奏/弹体/染色系数，单射源）──
## 病根：indirect batch 弧线只按 wt 槽位（wt1 全员 1.6 高弧），武器名完全不参与弹道；
## 飞行时长全族共用 0.6+dist/2000*0.8 一个公式（_WEAPON_CONFIG 的 speed 字段零消费）——
## 迫击炮/榴弹炮/火箭炮同弧线同节奏（用户主诉"曲射空射也要有辨识力"）。
## 设计：系数乘在槽位基准上（与 flavor_speed_mul 同模式），无名/未命中恒 1.0 零行为变化。
## 消费方：simple_indirect_projectile_batch（主力路径）+ bullet.gd 曲射回退路径。
enum IndirectFlavor {
	NONE = -1,      # 未命中关键词——全系数 1.0，槽位基准原样
	MORTAR = 0,     # 迫击炮——高弧慢飘小弹
	HOWITZER = 1,   # 榴弹炮/野战炮/要塞炮——中弧标准节奏重弹
	ROCKET = 2,     # 火箭炮/火箭弹——低平弧快弹橙红
	MISSILE = 3,    # 导弹——低弧俯冲微加速
}
static var _indirect_flavor_cache: Dictionary = {}

## 按武器名分类曲射亚类（优先级：迫击炮 > 火箭 > 榴弹族 > 导弹）。
## 只对走曲射路由（wt 1/2/3/7/9）的弹道有意义；直射名（坦克炮/步枪等）不路由到曲射，无影响。
static func classify_indirect(weapon_name: String) -> int:
	if weapon_name.is_empty():
		return IndirectFlavor.NONE
	if _indirect_flavor_cache.has(weapon_name):
		return int(_indirect_flavor_cache[weapon_name])
	var f: int = IndirectFlavor.NONE
	if weapon_name.find("迫击炮") >= 0:
		f = IndirectFlavor.MORTAR
	elif weapon_name.find("火箭炮") >= 0 or weapon_name.find("火箭弹") >= 0 \
			or weapon_name.find("火箭筒") >= 0:
		f = IndirectFlavor.ROCKET
	# 榴弹族在火箭后匹配——"227mm火箭炮"不该落榴弹族；"舰炮"不收（近防炮混名误伤）
	elif weapon_name.find("榴弹炮") >= 0 or weapon_name.find("野战炮") >= 0 \
			or weapon_name.find("要塞炮") >= 0 or weapon_name.find("加农炮") >= 0 \
			or weapon_name.find("火炮") >= 0 or weapon_name.find("步兵炮") >= 0:
		f = IndirectFlavor.HOWITZER
	elif weapon_name.find("导弹") >= 0:
		f = IndirectFlavor.MISSILE
	_indirect_flavor_cache[weapon_name] = f
	return f

## 亚类弧线高度系数（乘在槽位弧线倍率上）。迫击炮 1.0（槽位已是最高弧）/
## 榴弹族 0.65（wt1 1.6→1.04 中弧——远程炮平射弧）/ 火箭 0.35（wt1→0.56 低平直瞄）/
## 导弹 0.8（wt9 1.0→0.8 俯冲更直）。
static func indirect_apex_mul(flavor: int) -> float:
	match flavor:
		IndirectFlavor.MORTAR: return 1.0
		IndirectFlavor.HOWITZER: return 0.65
		IndirectFlavor.ROCKET: return 0.35
		IndirectFlavor.MISSILE: return 0.8
		_: return 1.0

## 亚类飞行时长系数（乘在槽位时长上；>1 更慢）。迫击炮 1.30（炮弹慢飘读"迫击炮"）/
## 火箭 0.72（低平快弹）/ 导弹 0.88（微加速俯冲）/ 榴弹族 1.0。
static func indirect_duration_mul(flavor: int) -> float:
	match flavor:
		IndirectFlavor.MORTAR: return 1.30
		IndirectFlavor.HOWITZER: return 1.0
		IndirectFlavor.ROCKET: return 0.72
		IndirectFlavor.MISSILE: return 0.88
		_: return 1.0

## 亚类弹体尺寸系数（per-instance scale）。榴弹族 1.2（重炮弹更大）/ 迫击炮 0.78（小弹）/
## 火箭 0.85（细长火箭弹）。
static func indirect_body_scale(flavor: int) -> float:
	match flavor:
		IndirectFlavor.MORTAR: return 0.78
		IndirectFlavor.HOWITZER: return 1.2
		IndirectFlavor.ROCKET: return 0.85
		IndirectFlavor.MISSILE: return 1.0
		_: return 1.0

## 亚类弹体染色（阵营无关覆盖，同 flavor_tint 语言）。火箭橙红（尾焰语义）/
## 导弹微橙白。NONE 返回入参 base（阵营 tint 原样）。
static func indirect_tint(flavor: int, base: Color) -> Color:
	match flavor:
		IndirectFlavor.ROCKET: return Color(1.0, 0.62, 0.30)
		IndirectFlavor.MISSILE: return Color(1.0, 0.85, 0.65)
		_: return base

## 返回弹头多边形顶点（7 点，顺时针，原点居中，指向 +X）。
## 可直接赋值给 Polygon2D.polygon（bullet.gd 路径），或传给 build_bullet_arraymesh 三角化。
## size_scale：尺寸系数（bullet.gd 传 _apply_bullet_shape 的 size_scale；batch 传 1.0，缩放交给 display_scale）。
## flavor（v20.16）：直射亚类（DirectWeaponFlavor.classify 值）——命中 RIFLE/MG/TANK_GUN 时
## 覆盖尺寸比例（机枪/步枪/直射炮三形分流，修复弹头同质化）；
## SMALL_ARMS/GENERIC/NONE 保持 wt 档基准，非直射武器 classify 恒 NONE 零影响。
## 注意：原 bullet.gd 多边形原点在左端（x 从 0 起），此处改为居中（x 从 -tip_x/2 起），
## 以便 MultiMesh 的 Transform2D 旋转时绕弹头中心转（左端原点会导致旋转时弹头偏离位置）。
static func build_bullet_points(weapon_type: int, size_scale: float = 1.0, flavor: int = -1) -> PackedVector2Array:
	var s := size_scale
	# 基准尺寸（v8.3 ×2）：总长约 12*scale，高约 7*scale
	var body_len: float = 8.0 * s   # 弹体长度
	var nose_len: float = 4.0 * s   # 弹头锥形长度
	var half_h: float = 3.5 * s     # 弹体半高
	var neck: float = 0.4           # 锥颈系数：锥底半宽 = nose_len * neck（越小越尖，越大越钝）
	# 按武器类型差异化比例（与 bullet.gd 原算法完全一致）
	match weapon_type:
		0, 4:  # SMG / PISTOL — 小口径手枪/冲锋枪：极短弹头（接近光点），高速密集时不连成长条
			body_len = 3.0 * s
			nose_len = 2.0 * s
			half_h = 2.5 * s
		1, 2:  # RIFLE / MG — 步枪/机枪：中等弹头（比冲锋枪长，体现步枪弹）
			body_len = 6.0 * s
			nose_len = 3.0 * s
			half_h = 2.8 * s
		5:  # SHOTGUN — 圆胖霰弹丸
			body_len = 6.0 * s
			nose_len = 3.0 * s
			half_h = 4.0 * s
		3, 9:  # ROCKET / MISSILE — 长粗导弹
			body_len = 9.0 * s
			nose_len = 4.0 * s
			half_h = 4.0 * s
		6:  # SNIPER — 长杆穿甲弹（v19-R36：狙击动能弹形，全族最长细，与激光光束分流）
			body_len = 12.0 * s
			nose_len = 5.0 * s
			half_h = 2.0 * s
		10, 11:  # OMEGA / RAIL — 细长高能弹
			body_len = 8.0 * s
			nose_len = 4.0 * s
			half_h = 1.6 * s
		7:  # FLAK — 短粗高炮弹
			body_len = 5.0 * s
			nose_len = 3.0 * s
			half_h = 3.6 * s
	# v20.16: 直射亚类覆盖（武器名优先于 wt 档）。玩家侧直射 wt 恒为 0（新枚举 DIRECT），
	# wt 档永远到不了 RIFLE/MG 分支——亚类是直射形状分化的唯一有效轴。
	if flavor != DirectWeaponFlavor.Flavor.NONE:
		match flavor:
			DirectWeaponFlavor.Flavor.RIFLE:
				# 步枪——细长尖锥（单发精确感；与机枪短钝一眼分流）
				body_len = 7.5 * s
				nose_len = 4.5 * s
				half_h = 1.8 * s
				neck = 0.3
			DirectWeaponFlavor.Flavor.MG:
				# 机枪——短钝弹丸（弹幕流亮点；钝头+矮胖与步枪细长反差）
				body_len = 5.0 * s
				nose_len = 2.0 * s
				half_h = 2.6 * s
				neck = 0.5
			DirectWeaponFlavor.Flavor.TANK_GUN:
				# 直射坦克炮——大号钝头炮弹（此前落 SMG 微型档；炮弹级体量）
				body_len = 10.0 * s
				nose_len = 4.0 * s
				half_h = 4.6 * s
				neck = 0.55
			DirectWeaponFlavor.Flavor.SMALL_ARMS:
				# v20.16d: 手枪/卡宾——微型近光点（比 SMG 档更小更圆；近距离点射读"小弹"）
				body_len = 2.5 * s
				nose_len = 1.5 * s
				half_h = 2.2 * s
				neck = 0.5
			_:
				pass  # GENERIC——保持 wt 档基准
	var tip_x: float = body_len + nose_len  # 弹头顶点 X
	var cx: float = tip_x * 0.5  # 居中原点
	# 7 点顺时针多边形（居中版，从弹体底部后端起）：
	# 后端平底 → 弹体底前 → 锥面收窄 → 弹尖 → 锥面展开 → 弹体顶前 → 后端平顶
	return PackedVector2Array([
		Vector2(-cx,             -half_h),            # 弹体底部后端
		Vector2(body_len - cx,   -half_h),            # 弹体底部前端
		Vector2(body_len - cx,   -nose_len * neck),   # 弹头底部锥面（下）
		Vector2(tip_x - cx,       0.0),               # 弹头顶点
		Vector2(body_len - cx,    nose_len * neck),   # 弹头底部锥面（上）
		Vector2(body_len - cx,    half_h),            # 弹体顶部前端
		Vector2(-cx,              half_h),            # 弹体顶部后端
	])

## 构建弹头 ArrayMesh（供 MultiMesh batch 用）。
## 取 build_bullet_points 的点 → triangulate_polygon 三角化 → add_surface_from_arrays。
## layer_key（v20.16）：wt 值（0-11，原语义）或亚类形状层键（FLAVOR_LAYER_*，100+）——
## 亚类层用 flavor 形状；坦克炮层默认放大到 TANK_GUN_DISPLAY_SCALE（炮弹级体量）。
## display_scale：战场显示缩放（缺省 -1 按层自动：坦克炮层 TANK_GUN_DISPLAY_SCALE，
## 其余 PROJ_BULLET_DISPLAY_SCALE，与旧签名默认值等价）。
static func build_bullet_arraymesh(layer_key: int, display_scale: float = -1.0) -> ArrayMesh:
	var flavor: int = _flavor_for_layer_key(layer_key)
	var wt: int = layer_key if flavor < 0 else 0  # 亚类层基准档取轻动能（尺寸全由 flavor 分支覆盖）
	var ds: float = display_scale
	if ds < 0.0:
		ds = TANK_GUN_DISPLAY_SCALE if flavor == DirectWeaponFlavor.Flavor.TANK_GUN else PROJ_BULLET_DISPLAY_SCALE
	var pts: PackedVector2Array = build_bullet_points(wt, ds, flavor)
	var tris: PackedInt32Array = Geometry2D.triangulate_polygon(pts)
	if tris.is_empty():
		push_warning("[WeaponProjectileVfx] 弹头三角化失败 wt=%d，回退矩形" % layer_key)
		# 兜底：用 body 段矩形（4 点）保证不崩
		var s := ds
		var bw := 8.0 * s
		var hh := 3.5 * s
		pts = PackedVector2Array([
			Vector2(-bw * 0.5, -hh), Vector2(bw * 0.5, -hh),
			Vector2(bw * 0.5, hh), Vector2(-bw * 0.5, hh)
		])
		tris = Geometry2D.triangulate_polygon(pts)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pts
	arrays[Mesh.ARRAY_INDEX] = tris
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	return am


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


## v9.2: 按 weapon_type 返回爆炸帧序列（有帧动画的武器才有，无则返回空数组）。
## 常规爆炸（ROCKET=3/FLAK=7/MISSILE=9）用橙红火球帧；能量爆炸（OMEGA=10/RAIL=11/LASER=8）用蓝白能量帧。
## 调用方用 _frames.size() >= 2 守卫判断是否有帧序列，空数组回退单贴图+粒子。
static func explosion_frames_by_wt(weapon_type: int) -> Array:
	match weapon_type:
		10, 11, 8:   # OMEGA / RAIL / LASER — 能量爆炸
			return EXPLOSION_ENERGY_FRAMES
		1, 2, 3, 7, 9:  # 曲射炮弹/空射/火箭/高炮/导弹 — 常规爆炸（v9.x: 1/2 补帧，炮弹命中也有火球分帧）
			return EXPLOSION_CONV_FRAMES
		_:            # 其他类型无帧序列
			return []


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
##        v9.4 新增可选："power_tier":int（0-3，命中特效威力分级，见 compute_power_tier）
## weapon_name（v8.4 新增，可选）：武器显示名，用于查命中贴图（仅重型爆炸武器 3/7/9 触发贴图层）
static func spawn_impact_with_kind(parent: Node2D, world_pos: Vector2, weapon_type: int, is_player_shot: bool, target_combat_kind: int = -1, opts: Dictionary = {}, weapon_name: String = "") -> void:
	if parent == null:
		return
	# v9.4: power_tier 核武级分派——NUCLEAR 直接走完整核爆特效栈（火球+双冲击波+蘑菇云+焦痕），
	# 跳过普通贴图/帧动画/粒子三层（核爆特效已包含这些层级的超级版）。
	# 缺省（opts 无 power_tier）按 -1 处理，走原逻辑，向后兼容。
	# 注：相位仪核子轰炸能力有独立的特效路径（phase_instrument_abilities），不走本函数；
	# 此处 NUCLEAR 分支处理的是普通武器弹道因高威力（radius≥70且atk≥1500）判为核武级的命中。
	var power_tier: int = int(opts.get("power_tier", -1))
	if power_tier == POWER_TIER.NUCLEAR:
		VfxFactory.spawn_nuclear_explosion(parent, world_pos, _NUKE_TEX, _nuke_colors(is_player_shot), 0.7)
		return
	# v12: 轨道炮(RAIL=11)走签名穿透效果(白闪+穿透光迹+出口spall),跳过通用贴图+爆炸帧+
	# 蓝色能量粒子三层(原轨道炮与激光/欧米茄共享能量贴图,毫无穿透动能感)。
	# v12d: 三把签名武器统一从 opts 读 attack direction(弹丸飞行方向,bullet.gd 已透传),
	# 让特效按真实来弹方向定向(贯穿/来弹光束 朝射手反方向)。
	var atk_dir: Variant = opts.get("direction", Vector2.RIGHT)
	var atk_d: Vector2 = atk_dir if atk_dir is Vector2 else Vector2.RIGHT
	if weapon_type == 11:
		VfxFactory.spawn_railgun_penetration(parent, world_pos, atk_d, 170.0)
		return
	# v12d: 激光(LASER=8)走签名灼烧效果(来弹光束+白热光斑+焦痕+热火花),跳过通用 OMEGA 贴图+
	# 能量帧(原与轨道炮/欧米茄共享,读成"通用能量团")。激光是表面能量沉积,非动能穿透。
	if weapon_type == 8:
		VfxFactory.spawn_laser_burn(parent, world_pos, is_player_shot, atk_d)
		return
	# v12d: 欧米茄粒子炮(OMEGA=10)走签名径向放电(来弹粒子流+大能量核+星芒射线+外向电火花),
	# 跳过通用 OMEGA 贴图+能量帧(原与激光/轨道炮共享)。欧米茄=重型粒子径向迸发。
	if weapon_type == 10:
		VfxFactory.spawn_omega_discharge(parent, world_pos, is_player_shot, atk_d)
		return
	# v18: 命中贴图层 scale 重标定（AI 审计 4.2/10 基线的主病根，像素级实测确认）。
	# 病根：weapon_impact_*.png 画布实为 1536px（内容 1062-1410px），旧 scale 按"512px
	# 基准 ×2 显示"标定（0.26-0.51×2）→ 实渲染 550-1300px，比 64px 参考单位大 8-18 倍；
	# 按名查表的 {hash}_impact.png 全部缺失，一律回落 FALLBACK(857px) 再乘 0.9-1.0
	# → ~800px 巨爆。修复：按【贴图内容实宽 × 族目标显示宽】反算 scale（v17f 同范式）。
	var impact_tex: Texture2D = null
	if weapon_type in [0, 4]:
		# v18: 轻动能(0)/手枪(4) 命中不叠加贴图层——族规格明令"放射状小火花+微量烟，
		# 无火球帧"（v17 审计 3 分格主违规项即此层）。粒子层(spawn_layered_impact)保留。
		impact_tex = null
	elif weapon_name != "" and weapon_type in [3, 7, 9]:
		impact_tex = impact_texture_by_name(weapon_name)
	else:
		# 非爆炸类/能量类——按 weapon_type 取通用贴图
		impact_tex = generic_impact_tex_by_wt(weapon_type)
	var peak_scale: float = 0.08
	if impact_tex != null:
		var target_w: float = float(IMPACT_TARGET_W_BY_WT.get(weapon_type, 112.0))
		peak_scale = target_w / _impact_content_width(impact_tex)
	# v9.4: HEAVY 档贴图放大（96→125px，对齐 HEAVY 档 128px 帧动画量级）
	# v18-R4: ×1.4→×1.3——112px 基准×1.4×1.12 抖动=246px 达 3.8×单位；96×1.3×1.12=140px
	# 落在 2×单位规格上限附近。
	if power_tier == POWER_TIER.HEAVY:
		peak_scale *= 1.3
	if impact_tex != null:
		VfxFactory.spawn_impact_sprite(parent, world_pos, impact_tex, peak_scale, 0.45)
	# v9.2/v9.4: 爆炸帧动画层——有帧序列的武器播帧动画（火球膨胀），宽度按 power_tier 分级。
	#   MEDIUM=96px（标准）/ HEAVY=160px（放大）/ LIGHT=0（无帧动画）。
	#   无帧序列的武器（轻武器等）explosion_frames_by_wt 返回空数组，跳过此层。
	var _frames: Array = explosion_frames_by_wt(weapon_type)
	# v9.4: 按 tier 决定帧动画宽度（LIGHT 不播；缺省 tier 走原 96px 逻辑兼容）
	var _frame_w: float = 96.0
	if power_tier >= 0:
		_frame_w = frame_width_for_tier(power_tier)
	if _frames.size() >= 2 and _frame_w > 0.0:
		# fps=10（0.6s 总长，紧凑爆炸感）；rise=24（轻微上飘，模拟烟尘升腾）
		VfxFactory.spawn_animated_nuclear(parent, world_pos, _frames, _frame_w, 24.0, 10.0)
	# v8.1: 委托 VfxImpactFactory 三层组合特效（粒子层，与贴图层叠加）
	# 注：SMG(0)/PISTOL(4) 的跳过守卫仍在 bullet._spawn_tex_impact_at 维护；
	# batch 路径（轻武器密集命中）不跳过——工厂配方表对轻武器用小快特效，命中反馈必要。
	# v8.x: 透传 weapon_name，让命中配方能按直射亚类（机枪/步枪/坦克炮等）细分
	VfxFactory.spawn_layered_impact(parent, world_pos, weapon_type, is_player_shot, target_combat_kind, opts, weapon_name)
	# v8.4: 武器类改造专属视觉——在基础特效之上叠加变体独有特征
	var _variant: String = String(opts.get("vfx_variant", ""))
	if not _variant.is_empty():
		VfxFactory.spawn_variant_overlay(parent, world_pos, weapon_type, _variant, is_player_shot)

## v7.x: 按 combat_kind 返回屏幕震动参数 (幅度, 时长)，无匹配返回 Vector2.ZERO
static func impact_shake_for_kind(target_combat_kind: int) -> Vector2:
	if target_combat_kind >= 0 and IMPACT_SHAKE_BY_KIND.has(target_combat_kind):
		return IMPACT_SHAKE_BY_KIND[target_combat_kind]
	return Vector2.ZERO


## ========== v9.4: 命中特效 power_tier 四档分级（战术核武级区分标准）==========
## 解决问题：weapon_type 不含量级信息（终极粒子炮 atk2250 与普通曲射 wt 都=1），
## 同武器类型命中特效无差异。power_tier 用复合信号（explosion_radius+伤害+能力id）
## 把命中特效分 4 档，让"核武级"武器有明显视觉区分。
##
## Tier 分档与判据（任一满足即升级）：
##   0 LIGHT    默认（直射无爆炸+非狙击+低伤）—— 小火花，无帧动画
##   1 MEDIUM   explosion_radius∈[1,50) 或 damage∈[100,700) —— 96px 帧动画
##   2 HEAVY    explosion_radius∈[50,70) 或 damage∈[700,1500) —— 160px 帧动画 + 配方×1.4
##   3 NUCLEAR  radius≥70 且 damage≥1500 —— 完整核爆特效栈（相位仪核子轰炸能力走独立路径，不经本函数）
##
## 调用方（bullet/batch）命中时算 tier 写入 opts["power_tier"]，本函数据此分派渲染。
## 缺省（opts 无 power_tier）走原逻辑，向后兼容。
const POWER_TIER := {
	"LIGHT": 0,
	"MEDIUM": 1,
	"HEAVY": 2,
	"NUCLEAR": 3,
}
# 阈值常量（可调，集中管理）
const POWER_TIER_ATK_MEDIUM: float = 100.0    # damage≥100 → 至少 MEDIUM
const POWER_TIER_ATK_HEAVY: float = 700.0     # damage≥700 → HEAVY
const POWER_TIER_ATK_NUCLEAR: float = 1500.0  # damage≥1500（且 radius≥70）→ NUCLEAR
const POWER_TIER_RADIUS_MEDIUM: float = 1.0   # 有爆炸半径 → 至少 MEDIUM
const POWER_TIER_RADIUS_HEAVY: float = 50.0   # radius≥50 → HEAVY（MISSILE55/RAIL58）
const POWER_TIER_RADIUS_NUCLEAR: float = 70.0 # radius≥70（OMEGA，需叠加高伤才核武）

# v9.4: 核武级命中特效贴图包（preload，NUCLEAR tier 命中时用，与 phase_instrument_abilities 核爆共用资源）
const _NUKE_DIR := "res://assets/effects/nuclear/"
const _NUKE_TEX: Dictionary = {
	"fireball": preload(_NUKE_DIR + "nuke_fireball.png"),
	"shockwave": preload(_NUKE_DIR + "nuke_shockwave.png"),
	"mushroom": preload(_NUKE_DIR + "nuke_mushroom.png"),
	"burn": preload(_NUKE_DIR + "nuke_burn.png"),
	"mushroom_frames": [
		preload(_NUKE_DIR + "nuke_mushroom_f0.png"),
		preload(_NUKE_DIR + "nuke_mushroom_f1.png"),
		preload(_NUKE_DIR + "nuke_mushroom_f2.png"),
		preload(_NUKE_DIR + "nuke_mushroom_f3.png"),
		preload(_NUKE_DIR + "nuke_mushroom_f4.png"),
		preload(_NUKE_DIR + "nuke_mushroom_f5.png"),
		preload(_NUKE_DIR + "nuke_mushroom_f6.png"),
		preload(_NUKE_DIR + "nuke_mushroom_f7.png"),
		preload(_NUKE_DIR + "nuke_mushroom_f8.png"),
	],
}

## 核武级命中配色（按阵营分色，与 phase_instrument_abilities 核爆统一风格）
static func _nuke_colors(is_player_shot: bool) -> Dictionary:
	return {
		"shock": Color(1.0, 0.85, 0.5, 0.9),
		"aftershock": Color(0.6, 0.7, 1.0, 0.5) if is_player_shot else Color(1.0, 0.4, 0.2, 0.5),
		"smoke": Color(0.35, 0.32, 0.30, 0.6),
	}

## 复合判据计算 power_tier。调用方命中时调用，写入 opts["power_tier"]。
## explosion_radius：爆炸半径（直射武器=0）；damage：本次伤害值。
## 返回 0-3（POWER_TIER.LIGHT..NUCLEAR）。
## 注：相位仪「核子轰炸」能力有独立特效路径（phase_instrument_abilities 直接调
## spawn_nuclear_explosion + emit 闪白信号），不走本函数；此处 NUCLEAR 档
## 处理的是普通武器弹道因高威力（radius≥70 且 damage≥1500，如终极粒子炮）的命中。
static func compute_power_tier(weapon_type: int, explosion_radius: float, damage: float) -> int:
	# radius 维度：≥70 且叠加高伤(≥1500) → 核武（OMEGA 粒子炮/终极武器）
	if explosion_radius >= POWER_TIER_RADIUS_NUCLEAR and damage >= POWER_TIER_ATK_NUCLEAR:
		return POWER_TIER.NUCLEAR
	# radius 维度：[50,70) → HEAVY
	if explosion_radius >= POWER_TIER_RADIUS_HEAVY:
		return POWER_TIER.HEAVY
	# atk 维度：≥700 → HEAVY（直射终极武器补救：radius=0 但伤害 700-1500）
	if damage >= POWER_TIER_ATK_HEAVY:
		return POWER_TIER.HEAVY
	# radius 维度：[1,50) → MEDIUM（普通曲射/火箭/高炮）
	if explosion_radius >= POWER_TIER_RADIUS_MEDIUM:
		return POWER_TIER.MEDIUM
	# atk 维度：[100,700) → MEDIUM（中型直射武器）
	if damage >= POWER_TIER_ATK_MEDIUM:
		return POWER_TIER.MEDIUM
	# 默认 LIGHT（轻武器直射小兵）
	return POWER_TIER.LIGHT

## 按 power_tier 返回帧动画 target_width（px）。0=无帧动画。
## v18-R4: HEAVY 160→128——规格"火炮级爆炸直径 1-2×单位(64-128px)"，160 已达 2.5×；
## v12 报告同向建议"主爆炸尺寸缩小 60%"。MEDIUM 96 保持（1.5×单位中值）。
static func frame_width_for_tier(tier: int) -> float:
	match tier:
		0:  return 0.0     # LIGHT 无帧动画
		1:  return 96.0    # MEDIUM 标准
		2:  return 128.0   # HEAVY 放大（2×单位上限）
		3:  return 0.0     # NUCLEAR 走 spawn_nuclear_explosion，不播普通帧动画
		_: return 96.0

