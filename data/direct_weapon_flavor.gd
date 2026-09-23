extends RefCounted
class_name DirectWeaponFlavor
## 直射武器亚类分类器（v8.x）
##
## 问题：DIRECT 系（weapon_type=0/1/2/4）占了实际战斗 90%+ 的体量，
## 但弹道拖尾和命中配方互相几乎一样——SMG/RIFLE/MG/PISTOL/坦克炮共用
## 同一套黄白小火花，机枪连发看不出"弹幕"、坦克炮看不出"重炮"。
##
## 本分类器不改 weapon_type 枚举（那会侵入索敌/攻防结算），而是用
## 武器名（weapon_name，已透传到 bullet 与命中工厂）按关键词分流成 5 个亚类，
## 供 bullet._apply_trail_tier / _trail_color_for_weapon / VfxImpactFactory._impact_recipe
## 做轻量差异化（粒子密度、颜色、环大小）。
##
## 设计要点：
## 1. 纯静态、零状态、零分配——classify 只做字符串匹配
## 2. 仅对 DIRECT 系（轻武器）生效，重型/能量武器（weapon_type>=3 且非直射）直接返回 NONE
## 3. 关键词匹配优先级：坦克炮 > 机枪 > 步枪 > 手枪卡宾 > 通用（兜底）
## 4. 无法判定的（空名/无匹配）→ NONE，调用方走原 weapon_type 配方，零行为变化

## 亚类枚举
enum Flavor {
	NONE = -1,       # 非直射系，或无法判定——调用方走原 weapon_type 配方
	GENERIC = 0,     # 通用直射（步兵冲锋枪等，无显著特征）—— 基准档
	SMALL_ARMS = 1,  # 手枪/卡宾/马刀等轻武器 —— 最弱拖尾
	RIFLE = 2,       # 步枪（AK/M16/M4/毛瑟）—— 冷白细长拖尾
	MG = 3,          # 机枪/重机枪 —— 密集弹幕拖尾（粒子翻倍）
	TANK_GUN = 4,    # 坦克炮/主炮/滑膛炮 —— 重炮（大环+加粗弹体）
}

## 判定是否是直射系武器类型（这些才会走亚类分流）。
## weapon_type 值：0=DIRECT/SMG, 1=INDIRECT(曲射,但batch路径=RIFLE直射), 2=MG, 4=PISTOL
## 注意：1 在 bullet 单发路径是曲射，不该走直射亚类——但 _apply_trail_tier 已对 1
## 单独配档，这里仍返回 true 让 batch 路径(直射)的 RIFLE 能分流。
static func is_direct_family(weapon_type: int) -> bool:
	return weapon_type in [0, 1, 2, 4]

## 按武器名分类直射亚类。
## [param weapon_name] 武器名（如 "12.7mm重机枪"、"120mm主炮"、"AK-47突击步枪"）
## [param weapon_type] 武器类型（仅直射系才分类，非直射返回 NONE）
## [return] Flavor 枚举；非直射系或空名返回 NONE
static func classify(weapon_name: String, weapon_type: int = 0) -> int:
	if not is_direct_family(weapon_type):
		return Flavor.NONE
	if weapon_name.is_empty():
		return Flavor.NONE
	# 按优先级匹配关键词（先匹配的特征性更强的类）
	# 坦克炮/主炮/滑膛炮/反坦克炮 —— 口径 + "炮"且非高炮/防空炮/迫击炮
	# v38.6: 直装炮族（步兵炮/野战炮/要塞炮/肩炮/相位炮/裸口径"73mm炮"）先行收编
	if _is_tank_gun(weapon_name):
		return Flavor.TANK_GUN
	# 机枪/重机枪/高机枪/车载机枪 —— "机枪"关键词
	# v38.6: 速射机炮族（近防炮/航炮/机炮/链炮/高射炮/防空炮/高炮）并入 MG——
	# 与机枪同享 3 连珠点射 + 换弹周期（CIWS/防空速射的"哒哒哒-停顿"节奏），
	# 彻底退出 GENERIC 步枪级配方。纯能量炮（离子炮/湮灭光炮）不在此列（backlog）。
	if weapon_name.find("机枪") >= 0 or weapon_name.find("MG") >= 0 \
			or _is_rapid_cannon(weapon_name):
		return Flavor.MG
	# 手枪/卡宾/马刀 —— 轻武器
	if weapon_name.find("手枪") >= 0 or weapon_name.find("卡宾") >= 0 or weapon_name.find("马刀") >= 0:
		return Flavor.SMALL_ARMS
	# 步枪（突击步枪/步枪）—— "步枪"关键词
	if weapon_name.find("步枪") >= 0:
		return Flavor.RIFLE
	# 冲锋枪 —— 介于手枪和步枪之间，归 RIFLE 档（细长拖尾）
	if weapon_name.find("冲锋枪") >= 0:
		return Flavor.RIFLE
	# 兜底：有名字但无匹配关键词 → 通用直射
	return Flavor.GENERIC


## 坦克炮判定：含"主炮/滑膛炮/反坦克炮/坦克炮"，但排除"高炮/防空炮/迫击炮/榴弹炮/要塞炮"
## （后者属于曲射或防空，不走直射亚类）
## v38.6: 直装炮族先行判定（置于排除表之前）——组合名以最强火力词为准：
## "迫击炮/野战炮"（ZSU-23-4 数据债）按野战炮收 TANK_GUN，"150mm要塞炮/88mm防空炮"
## （近防炮系统/要塞炮台）按要塞炮收 TANK_GUN——这些直射槽重炮此前吃 GENERIC 步枪级
## 曳光配方（审计 R2 45 条的主体）。新增：步兵炮/野战炮/要塞炮/肩炮/相位炮 +
## 裸口径签名"mm炮"（"73mm炮"这类口径紧邻炮字、无中缀的组合，不误伤"mm防空炮"）。
static func _is_tank_gun(weapon_name: String) -> bool:
	# ── v38.6 直装炮族：出现即坦克炮级（优先于下方排除表）──
	if weapon_name.find("步兵炮") >= 0 or weapon_name.find("野战炮") >= 0 \
			or weapon_name.find("要塞炮") >= 0 or weapon_name.find("肩炮") >= 0 \
			or weapon_name.find("相位炮") >= 0:
		return true
	# 裸口径炮：口径数字紧邻"炮"（"73mm炮"）；"88mm防空炮"/"122mm火箭炮"等
	# 中缀组合不匹配（mm 后跟的是防/火等字），不与下方排除表冲突
	if weapon_name.find("mm炮") >= 0 or weapon_name.find("MM炮") >= 0:
		return true
	# 先排除曲射/防空类炮（它们不该被归为直射坦克炮）
	if weapon_name.find("高炮") >= 0 or weapon_name.find("防空炮") >= 0 \
		or weapon_name.find("高射炮") >= 0 or weapon_name.find("近防炮") >= 0 \
		or weapon_name.find("迫击炮") >= 0 or weapon_name.find("榴弹炮") >= 0 \
		or weapon_name.find("舰炮") >= 0:
		return false
	# 再匹配直射坦克炮特征
	# v17: 补"火炮/加农炮"——直射槽的 81/105mm 炮（如"81mm/105mm火炮"，UCT 出现 18+ 次）
	# 原归 GENERIC 通用直射，与步枪同观感；直射 HE 炮应有坦克炮级重环+加粗弹体。
	# 曲射/防空炮已在前排排除；"自行火炮"由 WeaponVisualProfiles 归曲射族不经本函数。
	# v38.3: 补"线膛炮"——v26.15e 修 FT-17 时收了"滑膛炮"漏了同族的"线膛炮"
	# （T-55/M60/M1/豹1/酋长/挑战者2/斯特赖克MGS 的 100-120mm 线膛炮主炮），
	# 落 GENERIC 兜底被 v20.18 点射误打 2 发视觉弹（单发语义主炮一次飞两发）。
	if weapon_name.find("主炮") >= 0 or weapon_name.find("滑膛炮") >= 0 \
		or weapon_name.find("线膛炮") >= 0 \
		or weapon_name.find("反坦克炮") >= 0 or weapon_name.find("坦克炮") >= 0 \
		or weapon_name.find("火炮") >= 0 or weapon_name.find("加农炮") >= 0:
		return true
	return false


## v38.6: 速射机炮族判定——自动炮/防空速射/近防系统，与机枪同观感节奏（MG 档）。
## 与 TANK_GUN 的分工：本族是"速射小口径"（20-40mm 级 + 多管速射），吃 3 连珠点射 +
## 换弹周期；单发重炮（73mm+ 步兵炮/野战炮/要塞炮）走 TANK_GUN 单发大弹。
static func _is_rapid_cannon(weapon_name: String) -> bool:
	if weapon_name.find("近防炮") >= 0 or weapon_name.find("航炮") >= 0 \
		or weapon_name.find("机炮") >= 0 or weapon_name.find("链炮") >= 0 \
		or weapon_name.find("高射炮") >= 0 or weapon_name.find("防空炮") >= 0 \
		or weapon_name.find("高炮") >= 0:
		return true
	return false
