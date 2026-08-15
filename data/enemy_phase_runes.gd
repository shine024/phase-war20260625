extends RefCounted
class_name EnemyPhaseRunes
## v7.2: 敌方相位师符文加成表（镜像我方 runes.gd）
##
## 用途：敌方相位师 equipment.runes 数组里的 rune_id 经此表换算成产兵加成，
## 镜像我方 PhaseInstrumentManager.get_rune_bonus 的效果量级。
## 每个敌方符文给固定加成（atk_pct/hp_pct/def_pct/atk_speed），按 tier 分档。
##
## 设计：与我方符文等量对称。我方满符文槽（7星6格）约贡献 atk+12%/hp+10%，
## 敌方对应 tier 的符文组合贡献相当量级。

## 敌方符文定义（按 tier 分档，每档1套预设组合，等量我方同星级符文）
const ENEMY_RUNES: Dictionary = {
	# T1-2（对称我方3星）：单符文，温和加成
	"e_rune_t1_iron":     {"atk_pct": 0.02, "hp_pct": 0.02, "def_pct": 0.01, "atk_speed": 0.0},
	"e_rune_t1_vigor":    {"atk_pct": 0.03, "hp_pct": 0.03, "def_pct": 0.0,  "atk_speed": 0.0},
	# T3-4（对称我方5星）：中等符文
	"e_rune_t3_storm":    {"atk_pct": 0.04, "hp_pct": 0.03, "def_pct": 0.02, "atk_speed": 0.03},
	"e_rune_t3_bulwark":  {"atk_pct": 0.02, "hp_pct": 0.05, "def_pct": 0.04, "atk_speed": 0.0},
	"e_rune_t3_precision":{"atk_pct": 0.05, "hp_pct": 0.02, "def_pct": 0.02, "atk_speed": 0.04},
	# T5（对称我方7星）：高级符文
	"e_rune_t5_apex":     {"atk_pct": 0.06, "hp_pct": 0.05, "def_pct": 0.03, "atk_speed": 0.04},
	"e_rune_t5_eternity": {"atk_pct": 0.04, "hp_pct": 0.07, "def_pct": 0.05, "atk_speed": 0.0},
	# T6-7（对称我方7星满配）：顶级符文
	"e_rune_t6_genesis":  {"atk_pct": 0.05, "hp_pct": 0.05, "def_pct": 0.04, "atk_speed": 0.05},
	"e_rune_t6_void":     {"atk_pct": 0.07, "hp_pct": 0.04, "def_pct": 0.03, "atk_speed": 0.06},
}

## 按 tier 取预设符文组合（敌方 equipment.runes 直接存 rune_id 数组，此为便捷生成）
static func get_runes_for_tier(tier: int) -> Array:
	match tier:
		1, 2:
			return ["e_rune_t1_iron"]
		3, 4:
			return ["e_rune_t3_storm", "e_rune_t3_bulwark", "e_rune_t3_precision"]
		5:
			return ["e_rune_t5_apex", "e_rune_t5_eternity", "e_rune_t5_apex", "e_rune_t5_eternity", "e_rune_t5_apex"]
		6, 7:
			return ["e_rune_t6_genesis", "e_rune_t6_void", "e_rune_t6_genesis", "e_rune_t6_void", "e_rune_t6_genesis", "e_rune_t6_void"]
		_:
			return []

## 计算符文组合的总加成（镜像我方 get_rune_bonus）
static func get_combined_bonus(rune_ids: Array) -> Dictionary:
	var total := {"atk_pct": 0.0, "hp_pct": 0.0, "def_pct": 0.0, "atk_speed": 0.0}
	for rid in rune_ids:
		var r: String = String(rid)
		var def: Dictionary = ENEMY_RUNES.get(r, {})
		if def.is_empty():
			continue
		total["atk_pct"] = float(total["atk_pct"]) + float(def.get("atk_pct", 0.0))
		total["hp_pct"] = float(total["hp_pct"]) + float(def.get("hp_pct", 0.0))
		total["def_pct"] = float(total["def_pct"]) + float(def.get("def_pct", 0.0))
		total["atk_speed"] = float(total["atk_speed"]) + float(def.get("atk_speed", 0.0))
	return total
