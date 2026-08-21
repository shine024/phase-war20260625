extends RefCounted
class_name EnemyFactionSkills
## v18 四源重构·批次3 —— 敌方势力技能树（协同类技能）
##
## 来源：原 traits 中的 synergy_boost/synergy_types key（forgemaster 钢焰协同等）+ passive
## synergy_boost effect（生成器同批产出）。协同的运行时落点：
##   - 行为层：出兵套路偏好（MasterPatterns 按 faction/synergy_types 派生补兵 tag——既有行为，数据源显式化）
##   - 数值层：本轮为 0（保持已批准强度比率 1.04；条件型协同数值留 TODO）
##   - 展示层：信息卡四源之一

## master_id → 协同技能
const MASTER_SYNERGY: Dictionary = {
	"enemy_master_013": {
		"id": "forgemaster",
		"name": "熔铸大师",
		"synergy_boost": 0.25,
		"types": ["steel", "flame"]
	},
	"enemy_master_014": {
		"id": "electromagnetic_armor",
		"name": "电磁装甲师",
		"synergy_boost": 0.2,
		"types": ["thunder", "steel"]
	},
	"enemy_master_015": {
		"id": "chaos_flame_trait",
		"name": "熵增炎魔",
		"synergy_boost": 0.2,
		"types": ["flame", "void"]
	},
	"enemy_master_020": {
		"id": "em_war_god",
		"name": "电磁战神",
		"synergy_boost": 0.3,
		"types": ["steel", "thunder"]
	},
	"enemy_master_021": {
		"id": "chaos_inferno_trait",
		"name": "混沌炎魔",
		"synergy_boost": 0.3,
		"types": ["flame", "void"]
	},
}


static func get_synergy(master_id: String) -> Dictionary:
	return (MASTER_SYNERGY.get(master_id, {}) as Dictionary).duplicate(true)


## 协同数值加成（本轮恒 0——条件型协同机制未实装，返回值供未来接入 stats 通道）
static func get_synergy_numeric(_master_id: String) -> float:
	return 0.0
