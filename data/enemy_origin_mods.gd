extends RefCounted
class_name EnemyOriginMods
## v6.0: 敌源改造（Enemy-Origin Modification）定义表
## 只有通过战斗特定敌人并获取足够素材情报后才能解锁的专属改造选项
##
## 与现有20种通用MOD不同，敌源MOD具有：
##   - 唯一性：每种敌源MOD只对应特定敌人类型
##   - 特色效果：效果直接关联敌人的战斗特色
##   - 成长性：素材情报越高，敌源MOD的效果越强（1-3级）
##
## D槽：每张卡拥有1个独立敌源MOD槽位（不与A/B/C槽冲突）

# ── 敌源改造定义表 ─────────────────────────────────────────────────
# 每条记录包含：
#   id: 唯一标识
#   name: 中文名称
#   desc: 简短描述
#   source_enemy_type: 关联敌人类型（对应IntelDimensions的enemy_type）
#   required_material_intel: 基础素材情报阈值（解锁最低等级所需）
#   tiers: 3级效果数组，每级包含 tier, effects, desc, required_material_intel
#   compatible_combat_kinds: 适用的combat_kind数组（0=轻装,1=装甲,2=支援,3=空中,4=堡垒）
#   slot_type: 槽位类型（固定为"enemy_origin"）
#   flavor_text: 背景风味文字

const ENEMY_ORIGIN_MODS: Dictionary = {

	# ═══ 步兵系 ═══
	"EOM_INFANTRY_01": {
		"id": "EOM_INFANTRY_01",
		"name": "步兵战术套件",
		"desc": "从步兵交战中学来的阵地战术",
		"source_enemy_type": "infantry",
		"required_material_intel": 0.50,
		"tiers": [
			{
				"tier": 1,
				"effects": {"hp_flat": 15, "defense_pct": 0.05},
				"desc": "生命+15, 防御+5%",
			},
			{
				"tier": 2,
				"effects": {"hp_flat": 30, "defense_pct": 0.10, "cover_bonus": 0.15},
				"desc": "生命+30, 防御+10%, 掩体加成+15%",
				"required_material_intel": 0.75,
			},
			{
				"tier": 3,
				"effects": {"hp_flat": 50, "defense_pct": 0.15, "cover_bonus": 0.25, "entrenchment": true},
				"desc": "生命+50, 防御+15%, 掩体加成+25%, 可挖掘阵地",
				"required_material_intel": 1.00,
			},
		],
		"compatible_combat_kinds": [0, 2],
		"slot_type": "enemy_origin",
		"flavor_text": "无数次堑壕战总结出的步兵生存法则",
	},

	# ═══ 火焰兵系 ═══
	"EOM_FLAME_01": {
		"id": "EOM_FLAME_01",
		"name": "热能抗性装甲",
		"desc": "研究火焰喷射兵后开发的热防护",
		"source_enemy_type": "flame",
		"required_material_intel": 0.50,
		"tiers": [
			{
				"tier": 1,
				"effects": {"fire_resist": 0.20, "hp_regen_pct": 0.005},
				"desc": "火焰抗性+20%, 每秒回复0.5%HP",
			},
			{
				"tier": 2,
				"effects": {"fire_resist": 0.40, "hp_regen_pct": 0.01, "reflect_fire": 0.10},
				"desc": "火焰抗性+40%, 每秒回复1%HP, 反射10%火焰伤害",
				"required_material_intel": 0.75,
			},
			{
				"tier": 3,
				"effects": {"fire_resist": 0.60, "hp_regen_pct": 0.02, "reflect_fire": 0.20, "fire_immunity": true},
				"desc": "火焰抗性+60%, 反射20%火焰伤害, 火焰免疫",
				"required_material_intel": 1.00,
			},
		],
		"compatible_combat_kinds": [0, 1, 2, 3],
		"slot_type": "enemy_origin",
		"flavor_text": "从火焰兵残骸中逆向工程的耐热合金涂层",
	},

	# ═══ 重装甲系 ═══
	"EOM_ARMOR_01": {
		"id": "EOM_ARMOR_01",
		"name": "反应装甲模块",
		"desc": "从坦克残骸中逆向工程得到的装甲技术",
		"source_enemy_type": "heavy_armor",
		"required_material_intel": 0.50,
		"tiers": [
			{
				"tier": 1,
				"effects": {"armor_pct": 0.15, "explosion_resist": 0.10},
				"desc": "装甲+15%, 爆炸抗性+10%",
			},
			{
				"tier": 2,
				"effects": {"armor_pct": 0.25, "explosion_resist": 0.20, "reflect_proj": 0.08},
				"desc": "装甲+25%, 爆炸抗性+20%, 反弹8%弹道",
				"required_material_intel": 0.75,
			},
			{
				"tier": 3,
				"effects": {"armor_pct": 0.40, "explosion_resist": 0.35, "reflect_proj": 0.15, "adaptive_armor": true},
				"desc": "装甲+40%, 自适应装甲, 反弹15%弹道",
				"required_material_intel": 1.00,
			},
		],
		"compatible_combat_kinds": [1],
		"slot_type": "enemy_origin",
		"flavor_text": "复合反应装甲的核心技术——被击中时主动偏转弹道",
	},

	# ═══ 火炮系 ═══
	"EOM_ARTILLERY_01": {
		"id": "EOM_ARTILLERY_01",
		"name": "弹道校准系统",
		"desc": "从火炮阵地获取的射击诸元数据",
		"source_enemy_type": "artillery",
		"required_material_intel": 0.50,
		"tiers": [
			{
				"tier": 1,
				"effects": {"accuracy_pct": 0.15, "range_flat": 1},
				"desc": "命中+15%, 射程+1",
			},
			{
				"tier": 2,
				"effects": {"accuracy_pct": 0.25, "range_flat": 1, "crit_bonus": 0.10},
				"desc": "命中+25%, 射程+1, 暴击+10%",
				"required_material_intel": 0.75,
			},
			{
				"tier": 3,
				"effects": {"accuracy_pct": 0.35, "range_flat": 2, "crit_bonus": 0.15, "precision_strike": true},
				"desc": "命中+35%, 射程+2, 精确打击",
				"required_material_intel": 1.00,
			},
		],
		"compatible_combat_kinds": [2, 3],
		"slot_type": "enemy_origin",
		"flavor_text": "利用缴获的弹道计算机数据大幅提升射击精度",
	},

	# ═══ 隐匿系 ═══
	"EOM_STEALTH_01": {
		"id": "EOM_STEALTH_01",
		"name": "光学迷彩涂层",
		"desc": "从隐形单位残骸中提取的光学伪装技术",
		"source_enemy_type": "stealth",
		"required_material_intel": 0.50,
		"tiers": [
			{
				"tier": 1,
				"effects": {"dodge_pct": 0.10, "enemy_accuracy_penalty": 0.05},
				"desc": "闪避+10%, 敌人命中-5%",
			},
			{
				"tier": 2,
				"effects": {"dodge_pct": 0.18, "enemy_accuracy_penalty": 0.10, "first_strike_bonus": 0.20},
				"desc": "闪避+18%, 敌人命中-10%, 先手+20%",
				"required_material_intel": 0.75,
			},
			{
				"tier": 3,
				"effects": {"dodge_pct": 0.25, "enemy_accuracy_penalty": 0.15, "first_strike_bonus": 0.30, "cloak_deploy": true},
				"desc": "闪避+25%, 部署隐身3秒",
				"required_material_intel": 1.00,
			},
		],
		"compatible_combat_kinds": [0],
		"slot_type": "enemy_origin",
		"flavor_text": "纳米级光学迷彩颗粒——让你的单位短暂消失在战场上",
	},

	# ═══ 空中系 ═══
	"EOM_AIR_01": {
		"id": "EOM_AIR_01",
		"name": "精确打击模块",
		"desc": "从空中单位残骸中提取的航电瞄准系统",
		"source_enemy_type": "air",
		"required_material_intel": 0.50,
		"tiers": [
			{
				"tier": 1,
				"effects": {"accuracy_pct": 0.20, "attack_speed_pct": 0.08},
				"desc": "命中+20%, 攻速+8%",
			},
			{
				"tier": 2,
				"effects": {"accuracy_pct": 0.30, "attack_speed_pct": 0.15, "dive_bonus": 0.20},
				"desc": "命中+30%, 攻速+15%, 俯冲伤害+20%",
				"required_material_intel": 0.75,
			},
			{
				"tier": 3,
				"effects": {"accuracy_pct": 0.40, "attack_speed_pct": 0.20, "dive_bonus": 0.35, "evasive_manuver": true},
				"desc": "命中+40%, 攻速+20%, 俯冲+35%, 规避机动",
				"required_material_intel": 1.00,
			},
		],
		"compatible_combat_kinds": [2, 3],
		"slot_type": "enemy_origin",
		"flavor_text": "军用级航电系统——锁定目标后自动修正弹道",
	},

	# ═══ 纳米BOSS系 ═══
	"EOM_BOSS_NANO": {
		"id": "EOM_BOSS_NANO",
		"name": "纳米再生核心",
		"desc": "从纳米核心BOSS中提取的自修复技术",
		"source_enemy_type": "boss_nano",
		"required_material_intel": 0.75,
		"tiers": [
			{
				"tier": 1,
				"effects": {"hp_regen_pct": 0.03, "revive_chance": 0.05},
				"desc": "每秒回复3%HP, 5%概率战斗中复活",
			},
			{
				"tier": 2,
				"effects": {"hp_regen_pct": 0.05, "revive_chance": 0.10, "nano_surge": true},
				"desc": "每秒回复5%HP, 10%复活, 纳米脉冲",
				"required_material_intel": 0.90,
			},
			{
				"tier": 3,
				"effects": {"hp_regen_pct": 0.08, "revive_chance": 0.15, "nano_surge": true, "resurrect_full": true},
				"desc": "每秒回复8%HP, 15%满血复活, 纳米脉冲",
				"required_material_intel": 1.00,
			},
		],
		"compatible_combat_kinds": [0, 1, 2, 3],
		"slot_type": "enemy_origin",
		"flavor_text": "纳米自组装的核心——使任何单位都获得恐怖的生存能力",
	},

	# ═══ 侦察系 ═══
	"EOM_SCOUT_01": {
		"id": "EOM_SCOUT_01",
		"name": "战术侦察套件",
		"desc": "从侦察交战中学来的战场感知技术",
		"source_enemy_type": "scout",
		"required_material_intel": 0.50,
		"tiers": [
			{
				"tier": 1,
				"effects": {"vision_range": 2, "recon_bonus_pct": 0.05},
				"desc": "视野+2, 侦察加成+5%",
			},
			{
				"tier": 2,
				"effects": {"vision_range": 3, "recon_bonus_pct": 0.10, "enemy_speed_penalty": 0.05},
				"desc": "视野+3, 侦察加成+10%, 敌人移速-5%",
				"required_material_intel": 0.75,
			},
			{
				"tier": 3,
				"effects": {"vision_range": 5, "recon_bonus_pct": 0.15, "enemy_speed_penalty": 0.10, "mark_target": true},
				"desc": "视野+5, 侦察+15%, 敌人-10%移速, 标记目标",
				"required_material_intel": 1.00,
			},
		],
		"compatible_combat_kinds": [0, 2],
		"slot_type": "enemy_origin",
		"flavor_text": "知己知彼——战场信息优势就是战斗力优势",
	},

	# ═══ 指挥系 ═══
	"EOM_COMMAND_01": {
		"id": "EOM_COMMAND_01",
		"name": "战术指挥网络",
		"desc": "从敌方指挥系统中学来的协同作战技术",
		"source_enemy_type": "command",
		"required_material_intel": 0.50,
		"tiers": [
			{
				"tier": 1,
				"effects": {"ally_damage_pct": 0.05, "ally_speed_pct": 0.05},
				"desc": "友方伤害+5%, 友方移速+5%",
			},
			{
				"tier": 2,
				"effects": {"ally_damage_pct": 0.10, "ally_speed_pct": 0.08, "morale_boost": true},
				"desc": "友方伤害+10%, 友方移速+8%, 士气提升",
				"required_material_intel": 0.75,
			},
			{
				"tier": 3,
				"effects": {"ally_damage_pct": 0.15, "ally_speed_pct": 0.12, "morale_boost": true, "formation_bonus": true},
				"desc": "友方+15%伤害, +12%速度, 阵型加成",
				"required_material_intel": 1.00,
			},
		],
		"compatible_combat_kinds": [0, 1, 2, 3],
		"slot_type": "enemy_origin",
		"flavor_text": "统一的指挥网络让每个作战单位都发挥出超常的协同效率",
	},
}

# ── 工具函数 ───────────────────────────────────────────────────────

## 获取敌源MOD定义
static func get_mod(mod_id: String) -> Dictionary:
	return ENEMY_ORIGIN_MODS.get(mod_id, {})

## 检查MOD是否存在
static func has_mod(mod_id: String) -> bool:
	return ENEMY_ORIGIN_MODS.has(mod_id)

## 获取所有MOD ID
static func get_all_mod_ids() -> Array:
	return ENEMY_ORIGIN_MODS.keys()

## 获取所有适合某combat_kind的MOD ID
static func get_mods_for_combat_kind(combat_kind: int) -> Array[String]:
	var result: Array[String] = []
	for mod_id in ENEMY_ORIGIN_MODS:
		var mod: Dictionary = ENEMY_ORIGIN_MODS[mod_id]
		var kinds: Array = mod.get("compatible_combat_kinds", [])
		if combat_kind in kinds:
			result.append(mod_id)
	return result

## 获取MOD当前有效等级（基于素材情报）
## material_intel: 该敌人类型的素材情报进度 (0.0-1.0)
## 逻辑：从高到低判断，命中即返回。tier 1 缺省 required_material_intel 时回退到顶层阈值。
static func get_effective_tier(mod_id: String, material_intel: float) -> int:
	var mod: Dictionary = ENEMY_ORIGIN_MODS.get(mod_id, {})
	var tiers: Array = mod.get("tiers", [])
	if tiers.is_empty():
		return 0
	## 顶层基础阈值（tier 1 的解锁门槛，如 0.50）；tier 级字段缺失时回退用此值
	var base_req: float = float(mod.get("required_material_intel", 0.0))
	## 从高到低判断：先尝试高等级，命中即返回，避免低等级门槛(0.0)提前截断
	for i in range(tiers.size() - 1, -1, -1):
		var tier_data: Dictionary = tiers[i]
		var tier_no: int = int(tier_data.get("tier", i + 1))
		## tier 1 通常无 required_material_intel 字段，回退到顶层 base_req
		var req: float = float(tier_data.get("required_material_intel", base_req if tier_no == 1 else 1.0))
		if material_intel >= req:
			return tier_no
	return 0  ## 未达基础要求

## 获取MOD当前等级的效果
static func get_tier_effects(mod_id: String, tier: int) -> Dictionary:
	var mod: Dictionary = ENEMY_ORIGIN_MODS.get(mod_id, {})
	var tiers: Array = mod.get("tiers", [])
	for tier_data in tiers:
		if int(tier_data.get("tier", 0)) == tier:
			return tier_data.get("effects", {})
	return {}

## 检查MOD是否可装备到某卡（combat_kind兼容性）
static func is_compatible(mod_id: String, combat_kind: int) -> bool:
	var mod: Dictionary = ENEMY_ORIGIN_MODS.get(mod_id, {})
	var kinds: Array = mod.get("compatible_combat_kinds", [])
	return combat_kind in kinds
