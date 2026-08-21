extends RefCounted
class_name WeaponVisualProfiles
## 武器视觉档案注册表（v17）——"一把武器该长什么样"的单一真理源
##
## 病根回顾（为什么反复修复仍出现"步枪被渲染成火炮"类问题）：
##   1. 视觉分派键是 weapon_type 整数，而项目里两套枚举（新 4 值 / legacy 12 值）
##      在 1/2/3 上撞值。VFX 层约定"新枚举优先"，每个调用点都要自己猜手里的值
##      属于哪套域——猜错一次就是一个视觉 bug（历史上 v9.6 审计 V8/V9、v16 归一、
##      construct_unit_ai 的"朝向猜域"补丁均源于此）。
##   2. 226 个武器名坍缩到 ~12 个 wt 档，武器名里的精确语义（激光/磁轨/等离子…）
##      只在槽位初始化时被解读一次，消费侧（枪口火/命中/弹体）拿不到。
##
## 本文件的两层职责：
##   A. 解析器 resolve_visual_wt()：**武器名优先**（名字是唯一无歧义的信号，
##      v16 起已透传到所有消费点），域感知 wt 兜底（名空/无信号时保持旧行为）。
##      返回无歧义的视觉 wt（= Family 枚举值），所有渲染路径统一经此解析，
##      不再各自归一/猜域。
##   B. 档案表 PROFILES：每个武器族的完整视觉身份（枪口火/命中/弹体/震屏/验收
##      规格）。是审计工具（vfx_audit_matrix）与验收文档的单一数据源。
##      注意：muzzle/impact 等字段是审计分类标签，运行时渲染分派仍由 VFX 层
##      按 visual_wt 执行——两者的一致性由 tests/weapon_visual_profiles_smoke.gd 锁定。
##
## 视觉 wt 空间（与 Family 枚举值恒等，无二次映射）：
##   0=轻动能(SMG/步枪/机枪/坦克炮归一档, 亚类由 DirectWeaponFlavor 按名细分)
##   1=曲射炮弹  2=空射  3=火箭  4=手枪  5=霰弹  6=狙击/光束
##   7=高炮  8=激光  9=导弹  10=欧米茄粒子炮  11=磁轨

const CardRes: GDScript = preload("res://resources/card_resource.gd")

## 武器视觉族（值=视觉 wt，见文件头说明）
enum Family {
	LIGHT_KINETIC = 0,
	INDIRECT_ARTY = 1,
	AERIAL = 2,
	ROCKET = 3,
	SMALL_ARMS = 4,
	SHOTGUN = 5,
	SNIPER_BEAM = 6,
	FLAK = 7,
	LASER = 8,
	MISSILE = 9,
	OMEGA = 10,
	RAIL = 11,
}

## ======================================================================
## A. 解析器（所有渲染路径的唯一入口）
## ======================================================================

## 解析武器名 → 视觉 wt。优先级：签名精确表 → 视觉关键词 → 域感知 wt 兜底。
## [param weapon_name] 武器显示名（v16 起所有开火/命中路径已透传；空名直接走兜底）
## [param raw_wt] 调用方持有的原始 weapon_type（域可能混合，仅兜底时使用）
## [param shooter_is_player] 我方=true（新枚举域：1/2=曲射/空射）；敌方=false
##   （legacy 域：1/2=步枪/机枪，归一为 0 轻动能——保持 normalize_light_kinetic_wt 行为）
## 返回 Family 值（恒在 0-11），可直接传给 VfxImpactFactory / WeaponProjectileVfx。
static func resolve_visual_wt(weapon_name: String, raw_wt: int, shooter_is_player: bool) -> int:
	return int(resolve_traced(weapon_name, raw_wt, shooter_is_player)["visual_wt"])

## 带溯源版解析（审计工具/排错用）。返回：
##   {"visual_wt": int, "via": "exact"|"keyword"|"wt_fallback", "matched": String}
## via 说明——exact=签名精确表命中；keyword=视觉关键词命中；wt_fallback=名字无信号
## 按域解释原始 wt（保持解析前行为）。审计工具统计 wt_fallback 占比即为
## "视觉身份未确定"的武器清单（新武器漏配会在 smoke 阶段暴露）。
static func resolve_traced(weapon_name: String, raw_wt: int, shooter_is_player: bool) -> Dictionary:
	# ── 第1优先级：签名武器精确表（与弹道覆盖表同源，card_resource 是唯一真身）──
	# 值即视觉 wt（霰弹枪→5 / 全装型导弹巢→9 / 攻城电磁炮→11 / 重型等离子加农炮→10 / 磁轨狙击炮→6）
	if not weapon_name.is_empty():
		var exact: int = CardRes.trajectory_override_exact(weapon_name)
		if exact >= 0:
			return {"visual_wt": exact, "via": "exact", "matched": weapon_name}
	# ── 第2优先级：视觉关键词（按特征性从强到弱；命中即返回）──
	# 注意与弹道侧 _BEAM_WEAPON_KEYWORDS 的分工：弹道侧把所有光束语义词统一为
	# SNIPER(6) 光束弹道；视觉侧进一步细分——激光是烧灼(8)、磁轨是穿透(11)、
	# 等离子是径向放电(10)，其余光束才归狙击/光束(6)。
	if not weapon_name.is_empty():
		for kw in RAIL_KEYWORDS:
			if weapon_name.find(kw) >= 0:
				return {"visual_wt": Family.RAIL, "via": "keyword", "matched": kw}
		for kw in LASER_KEYWORDS:
			if weapon_name.find(kw) >= 0:
				return {"visual_wt": Family.LASER, "via": "keyword", "matched": kw}
		for kw in OMEGA_KEYWORDS:
			if weapon_name.find(kw) >= 0:
				return {"visual_wt": Family.OMEGA, "via": "keyword", "matched": kw}
		for kw in MISSILE_KEYWORDS:
			if weapon_name.find(kw) >= 0:
				return {"visual_wt": Family.MISSILE, "via": "keyword", "matched": kw}
		for kw in ROCKET_KEYWORDS:
			if weapon_name.find(kw) >= 0:
				return {"visual_wt": Family.ROCKET, "via": "keyword", "matched": kw}
		for kw in FLAK_KEYWORDS:
			if weapon_name.find(kw) >= 0:
				return {"visual_wt": Family.FLAK, "via": "keyword", "matched": kw}
		for kw in ARTY_KEYWORDS:
			if weapon_name.find(kw) >= 0:
				return {"visual_wt": Family.INDIRECT_ARTY, "via": "keyword", "matched": kw}
		for kw in SHOTGUN_KEYWORDS:
			if weapon_name.find(kw) >= 0:
				return {"visual_wt": Family.SHOTGUN, "via": "keyword", "matched": kw}
		for kw in BEAM_KEYWORDS:
			if weapon_name.find(kw) >= 0:
				return {"visual_wt": Family.SNIPER_BEAM, "via": "keyword", "matched": kw}
		# 轻动能捕获（兜底前最后一档）——含枪/炮语义词但未被上面任何重型/签名
		# 关键词命中的一律归轻动能族（坦克炮/反坦克炮/机枪/步枪等，亚类由
		# DirectWeaponFlavor 按名细分）。作用：让 wt_fallback 名单只剩真正
		# 无法识别的新武器——那才是审计需要暴露的"视觉身份未定"清单。
		for kw in LIGHT_KINETIC_KEYWORDS:
			if weapon_name.find(kw) >= 0:
				return {"visual_wt": Family.LIGHT_KINETIC, "via": "keyword", "matched": kw}
	# ── 第3优先级：域感知 wt 兜底（名字无信号，保持本文件出现前的行为）──
	# 我方域：新枚举优先，1/2/3 = 曲射/空射/支援(重型)——原样透传。
	# 敌方域：legacy 解释，1/2 = 步枪/机枪 → 归一 0（等价 normalize_light_kinetic_wt）。
	var wt: int = clampi(raw_wt, 0, 11)
	if not shooter_is_player and (wt == 1 or wt == 2):
		wt = 0
	return {"visual_wt": wt, "via": "wt_fallback", "matched": ""}

# ── 视觉关键词表（按特征性从强到弱排列，先匹配先赢）──
# 与弹道侧关键词（card_resource._BEAM_WEAPON_KEYWORDS 等）语义分工见 resolve_traced 注释。
const RAIL_KEYWORDS: Array = ["轨道炮", "电磁轨道", "磁轨"]          # 动能穿透签名
const LASER_KEYWORDS: Array = ["激光", "雷射"]                       # 烧灼签名（区别于通用光束）
const OMEGA_KEYWORDS: Array = ["等离子"]                             # 径向放电签名
const MISSILE_KEYWORDS: Array = ["导弹"]                             # 含"防空导弹"（先于防空炮判定）
const ROCKET_KEYWORDS: Array = ["火箭"]                              # 火箭弹/火箭炮
const FLAK_KEYWORDS: Array = ["高炮", "防空炮", "高射炮", "近防炮"]   # 防空速射炮
const ARTY_KEYWORDS: Array = ["迫击炮", "榴弹炮", "要塞炮", "野战炮", "舰炮", "自行火炮"]  # 曲射压制火炮
const SHOTGUN_KEYWORDS: Array = ["霰弹"]                             # 面散射
const BEAM_KEYWORDS: Array = ["光束", "粒子束", "粒子炮", "电磁炮", "射线", "狙击", "狙击炮"]  # 其余光束/狙击
# 轻动能捕获（排最后，见 resolve_traced 内注释）。"火炮/加农炮"归此档：
# 直射槽的 105mm 炮直射步兵——族仍轻动能，但 DirectWeaponFlavor 给坦克炮级
# 加粗弹体+重环风味（直射 HE 弹道平直，爆炸观感交给 power_tier 伤害分级）。
# "MG" 兜拉丁字母机枪名（MG42 等，DirectWeaponFlavor 侧同词已匹配）。
const LIGHT_KINETIC_KEYWORDS: Array = ["火炮", "加农炮", "坦克炮", "反坦克炮", "机枪", "步枪", "冲锋枪", "手枪", "卡宾", "马刀", "MG", "炮", "枪"]

## ======================================================================
## B. 档案表（审计工具与验收文档的单一数据源）
## ======================================================================
## 每族档案字段：
##   label     —— 中性族名（审计页展示）
##   muzzle    —— 枪口火类别：light(细火星) / energy(喷射流) / heavy(爆发球+发射烟)
##   impact    —— 命中类别：kinetic(放射火花) / explosive(火球帧+冲击波+烟) /
##                pierce(穿透光迹+出口spall) / burn(灼烧光斑+焦痕) / discharge(径向放电) /
##                scatter(散射命中) / beam_hit(光束药剂感)
##   projectile—— 弹体形态：poly_bullet(程序化弹头) / rocket_body / missile_body / beam_line
##   shake     —— 震屏档位（与 compute_power_tier 联动，族级为基准档）
##   spec      —— 验收规格一句话摘要（完整版见 docs/VFX武器族视觉规格.md，两处同步维护）
const PROFILES: Dictionary = {
	Family.LIGHT_KINETIC: {
		"label": "轻动能（冲锋枪/步枪/机枪/坦克炮）",
		"muzzle": "light", "impact": "kinetic", "projectile": "poly_bullet",
		"shake": "none（仅 HEAVY 伤害档震屏）",
		"spec": "枪口=细碎橙火星(~5-9px)一闪即逝；命中=放射状黄白小火花+微量烟，无火球帧无震屏；亚类(机枪弹幕/坦克炮重环)由 DirectWeaponFlavor 按武器名细分",
	},
	Family.INDIRECT_ARTY: {
		"label": "曲射火炮（迫击炮/榴弹炮）",
		"muzzle": "heavy", "impact": "explosive", "projectile": "poly_bullet",
		"shake": "medium",
		"spec": "枪口=大爆发火球+发射药烟团；弹道=高抛物线炮弹；命中=火球帧动画+冲击波环+焦痕弹坑(50%概率)",
	},
	Family.AERIAL: {
		"label": "空射武器",
		"muzzle": "heavy", "impact": "explosive", "projectile": "missile_body",
		"shake": "medium",
		"spec": "空射导弹俯冲弹道；命中=通用爆炸贴图+火球帧",
	},
	Family.ROCKET: {
		"label": "火箭弹（火箭炮/火箭巢）",
		"muzzle": "heavy", "impact": "explosive", "projectile": "rocket_body",
		"shake": "medium",
		"spec": "枪口=窄锥(32°)定向喷射+尾焰烟；弹道=低平弧火箭弹带尾焰；命中=火球帧+碎片烟尘",
	},
	Family.SMALL_ARMS: {
		"label": "手枪/卡宾（最轻档）",
		"muzzle": "light", "impact": "kinetic", "projectile": "poly_bullet",
		"shake": "none",
		"spec": "比步枪更弱一档：极短弹头(近光点)+最小火花；密集射击不连成长条",
	},
	Family.SHOTGUN: {
		"label": "霰弹",
		"muzzle": "light", "impact": "scatter", "projectile": "poly_bullet",
		"shake": "none",
		"spec": "6 发 18° 散射弹丸；命中=散射状小贴图+宽散火花",
	},
	Family.SNIPER_BEAM: {
		"label": "狙击/光束武器",
		"muzzle": "energy", "impact": "beam_hit", "projectile": "beam_line",
		"shake": "light",
		"spec": "枪口=白青喷射流；弹道=Line2D 直线光束；命中=精确药剂感小爆点（非激光烧灼——激光武器单独归 LASER 族）",
	},
	Family.FLAK: {
		"label": "高炮/防空速射炮",
		"muzzle": "heavy", "impact": "explosive", "projectile": "poly_bullet",
		"shake": "medium",
		"spec": "短粗高炮弹连发；命中=空爆贴图+小火球帧",
	},
	Family.LASER: {
		"label": "激光（烧灼签名）",
		"muzzle": "energy", "impact": "burn", "projectile": "beam_line",
		"shake": "light",
		"spec": "命中=来弹光束+白热聚焦光斑+焦痕+上升热火花+熔融火星（表面能量沉积，区别于动能穿透）",
	},
	Family.MISSILE: {
		"label": "导弹",
		"muzzle": "heavy", "impact": "explosive", "projectile": "missile_body",
		"shake": "medium",
		"spec": "大型导弹弹体+中弧弹道+专属命中贴图（按名查表，含通用爆炸兜底）",
	},
	Family.OMEGA: {
		"label": "欧米茄粒子炮（径向放电签名）",
		"muzzle": "energy", "impact": "discharge", "projectile": "poly_bullet",
		"shake": "heavy",
		"spec": "命中=来弹粒子流+大能量核+7条星芒射线+外向电火花+持续辉光环（四面八方炸开）",
	},
	Family.RAIL: {
		"label": "磁轨炮（动能穿透签名）",
		"muzzle": "energy", "impact": "pierce", "projectile": "poly_bullet",
		"shake": "heavy",
		"spec": "命中=入口过曝白闪+白热穿透光迹贯穿目标+出口spall碎片锥+回溅火花+速度线（超高初速动能穿甲，非激光）",
	},
}

## 全部族 id（升序；审计工具遍历用）
static func all_families() -> Array:
	var ids: Array = PROFILES.keys()
	ids.sort()
	return ids

## 取族档案（未知族返回空字典，调用方自行兜底）
static func profile_of(family: int) -> Dictionary:
	return PROFILES.get(family, {})

## 族中文名（审计页展示；未知族返回 "未知族#N"）
static func family_label(family: int) -> String:
	var p: Dictionary = profile_of(family)
	return String(p.get("label", "未知族#%d" % family))
