extends RefCounted
class_name FactionConquestBuffs
## v6.9: 势力占领关卡 —— 占领势力对关卡敌人的加成表
##
## 设计理念：
## - 占领势力的等级越高，其领地内的敌人越强（体现"势力占领"设定）
## - 每势力一个"战斗风格"主题，与势力设定呼应：
##     钢壁防务(iron_wall_corp)   → 防御型：敌人更硬（HP↑）
##     新星兵工(nova_arms)        → 火力型：敌人更猛（攻击↑）
##     以太动力(aether_dynamics)  → 机动型：敌人更快更均衡（攻/速↑）
##     量子后勤(quantum_logistics)→ 量多型：敌人攻防均衡小增（攻/HP↑）
##     螺旋侦察(helix_recon)      → 闪避型：敌人HP↑/速度↑（侦察兵难缠）
##     虚空相位(void_research)    → 法则型：敌人攻击暴击↑（神秘强敌）
##     边境联合(frontier_union)   → 通用型：中性的均衡加成（备用，该势力无固有领地）
##
## 数值约束（平衡性）：
## - 势力等级范围 1-10（见 FactionReputation.LEVEL_THRESHOLDS）
## - 单维度上限：attack_mul ≤ 1.40, hp_mul ≤ 1.30, speed_mul ≤ 1.15
## - 满级(10)总威胁倍率（attack×hp）控制在 ~1.8 以内，避免后期关卡过难
## - 乘区接入 enemy_stat_resolver.gd 的 dmg_mul_chain / hp_mul_chain（敌方加成链）
##   与 v6.8 收敛方向一致：只增强敌方，不复活已停用的我方势力加成
##
## 查询接口：
##   FactionConquestBuffs.get_buff(faction_id, faction_level) -> Dictionary
##   返回 { "hp_mul": float, "attack_mul": float, "speed_mul": float }
##   缺省键视为 1.0（无加成）；faction_id 为空（无主之地）返回空字典

## 加成系数表：每势力 × 等级档（1/3/5/7/10 代表等级区间，get_buff 会向下取整）
## 设计为"阶梯式"：每3级提升一档，避免每级微小变化难以感知
const FACTION_BUFFS: Dictionary = {
	# 钢壁防务 —— 防御型：敌人血量显著提升，攻击略增（铁壁难破）
	"iron_wall_corp": {
		1:  {"attack_mul": 1.00, "hp_mul": 1.05, "speed_mul": 1.00},
		3:  {"attack_mul": 1.03, "hp_mul": 1.10, "speed_mul": 1.00},
		5:  {"attack_mul": 1.05, "hp_mul": 1.18, "speed_mul": 1.00},
		7:  {"attack_mul": 1.08, "hp_mul": 1.24, "speed_mul": 1.00},
		10: {"attack_mul": 1.10, "hp_mul": 1.30, "speed_mul": 1.00},
	},
	# 新星兵工 —— 火力型：敌人攻击大幅提升（火力压制）
	"nova_arms": {
		1:  {"attack_mul": 1.05, "hp_mul": 1.00, "speed_mul": 1.00},
		3:  {"attack_mul": 1.12, "hp_mul": 1.02, "speed_mul": 1.00},
		5:  {"attack_mul": 1.22, "hp_mul": 1.05, "speed_mul": 1.00},
		7:  {"attack_mul": 1.32, "hp_mul": 1.08, "speed_mul": 1.00},
		10: {"attack_mul": 1.40, "hp_mul": 1.10, "speed_mul": 1.00},
	},
	# 以太动力 —— 机动型：敌人攻速/速度提升，整体均衡增强
	"aether_dynamics": {
		1:  {"attack_mul": 1.03, "hp_mul": 1.02, "speed_mul": 1.03},
		3:  {"attack_mul": 1.08, "hp_mul": 1.05, "speed_mul": 1.05},
		5:  {"attack_mul": 1.14, "hp_mul": 1.08, "speed_mul": 1.08},
		7:  {"attack_mul": 1.20, "hp_mul": 1.12, "speed_mul": 1.10},
		10: {"attack_mul": 1.26, "hp_mul": 1.16, "speed_mul": 1.15},
	},
	# 量子后勤 —— 量多型：敌人攻防均衡小增（补给充足，数量压制）
	"quantum_logistics": {
		1:  {"attack_mul": 1.02, "hp_mul": 1.03, "speed_mul": 1.00},
		3:  {"attack_mul": 1.06, "hp_mul": 1.07, "speed_mul": 1.00},
		5:  {"attack_mul": 1.10, "hp_mul": 1.12, "speed_mul": 1.00},
		7:  {"attack_mul": 1.15, "hp_mul": 1.18, "speed_mul": 1.00},
		10: {"attack_mul": 1.20, "hp_mul": 1.24, "speed_mul": 1.00},
	},
	# 螺旋侦察 —— 闪避型：敌人速度/血量提升（侦察兵难缠，机动规避）
	"helix_recon": {
		1:  {"attack_mul": 1.02, "hp_mul": 1.03, "speed_mul": 1.05},
		3:  {"attack_mul": 1.05, "hp_mul": 1.07, "speed_mul": 1.08},
		5:  {"attack_mul": 1.08, "hp_mul": 1.12, "speed_mul": 1.10},
		7:  {"attack_mul": 1.12, "hp_mul": 1.16, "speed_mul": 1.12},
		10: {"attack_mul": 1.16, "hp_mul": 1.20, "speed_mul": 1.15},
	},
	# 虚空相位 —— 法则型：敌人攻击暴击提升（神秘强敌，威胁最高）
	"void_research": {
		1:  {"attack_mul": 1.05, "hp_mul": 1.02, "speed_mul": 1.00},
		3:  {"attack_mul": 1.13, "hp_mul": 1.05, "speed_mul": 1.00},
		5:  {"attack_mul": 1.22, "hp_mul": 1.08, "speed_mul": 1.02},
		7:  {"attack_mul": 1.32, "hp_mul": 1.12, "speed_mul": 1.05},
		10: {"attack_mul": 1.40, "hp_mul": 1.16, "speed_mul": 1.08},
	},
	# 边境联合 —— 通用型：中性均衡加成（备用，该势力无固有领地，仅占领变动时可能触发）
	"frontier_union": {
		1:  {"attack_mul": 1.02, "hp_mul": 1.02, "speed_mul": 1.02},
		3:  {"attack_mul": 1.06, "hp_mul": 1.06, "speed_mul": 1.04},
		5:  {"attack_mul": 1.10, "hp_mul": 1.10, "speed_mul": 1.06},
		7:  {"attack_mul": 1.14, "hp_mul": 1.14, "speed_mul": 1.08},
		10: {"attack_mul": 1.18, "hp_mul": 1.18, "speed_mul": 1.10},
	},
}

## 等级档位（用于向下取整查找）
const _LEVEL_TIERS: Array = [1, 3, 5, 7, 10]


## 获取势力对敌人的加成系数
## [param faction_id] 占领势力ID（公司ID，如 "nova_arms"）
## [param faction_level] 势力等级（1-10）
## [return] 加成字典 { hp_mul, attack_mul, speed_mul }；faction_id 为空或未知返回空字典
static func get_buff(faction_id: String, faction_level: int) -> Dictionary:
	if faction_id.is_empty():
		return {}
	var faction_table: Dictionary = FACTION_BUFFS.get(faction_id, {})
	if faction_table.is_empty():
		return {}
	# 向下取整到最近的档位
	var tier: int = 1
	for t in _LEVEL_TIERS:
		if faction_level >= t:
			tier = t
	return faction_table.get(tier, {}).duplicate(true)


## 获取某势力在指定等级的加成描述（供 UI / 调试用）
## [return] 形如 "攻击+40% / HP+10%" 的可读字符串
static func describe_buff(faction_id: String, faction_level: int) -> String:
	var buff: Dictionary = get_buff(faction_id, faction_level)
	if buff.is_empty():
		return "无加成"
	var parts: Array = []
	var atk: float = float(buff.get("attack_mul", 1.0))
	var hp: float = float(buff.get("hp_mul", 1.0))
	var spd: float = float(buff.get("speed_mul", 1.0))
	if atk > 1.0:
		parts.append("攻击+%.0f%%" % ((atk - 1.0) * 100.0))
	if hp > 1.0:
		parts.append("HP+%.0f%%" % ((hp - 1.0) * 100.0))
	if spd > 1.0:
		parts.append("速度+%.0f%%" % ((spd - 1.0) * 100.0))
	if parts.is_empty():
		return "无加成"
	return " / ".join(parts)
