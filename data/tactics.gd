extends RefCounted
class_name Tactics
## ═══════════════════════════════════════════════════════════
##  v8.x 战法定义（18 个：12 基础 + 6 高级）
##
##  战法 = 阵容检测 + 自动 Buff。
##  TacticDetector 每 1s 检测场上兵种组合，满足 conditions 即激活 effects。
##  effects 为全局 stat_bonus，应用到全体友军。
##
##  战法激活条件（conditions）字段：
##    min_count_by_kind: {CombatKind值: 最少数量}   # 按战斗类型计数
##    min_count_by_tag: {标签名: 最少数量}          # 按兵种标签计数
##    require_distinct_kinds: 3                      # 需要的不同 CombatKind 数量
##    require_tactic_unlocked: true                  # 是否需要技能树解锁（高级战法）
##
##  战法效果（effects）字段：
##    stat_bonus: {key: value}    # 全局加成（同 phase_master_skill_tree 格式）
##    special: [...]              # 特殊机制标记（由 TacticDetector 写入 unit meta）
## ═══════════════════════════════════════════════════════════

const GC = preload("res://resources/game_constants.gd")

## 12 个基础战法（无需技能树解锁，阵容满足条件即激活）
const BASIC_TACTICS: Dictionary = {
	"tactic_pincer": {
		"id": "tactic_pincer", "name": "钳形攻势", "tier": 1,
		"desc": "≥2 ARMOR + ≥1 FAST：ARMOR 对最高威胁敌方+25% 伤害",
		"conditions": {
			"min_count_by_kind": {GC.CombatKind.ARMOR: 2},
			"min_count_by_tag": {"fast": 1}
		},
		"effects": {"stat_bonus": {"atk_armor_vs_threat": 0.25}}
	},
	"tactic_hedgehog": {
		"id": "tactic_hedgehog", "name": "刺猬防御", "tier": 1,
		"desc": "≥3 FORT + ≥1 ENGINEER：全体-25% 受伤",
		"conditions": {
			"min_count_by_kind": {GC.CombatKind.FORT: 3},
			"min_count_by_tag": {"engineer": 1}
		},
		"effects": {"stat_bonus": {"damage_reduction": 0.25}}
	},
	"tactic_flank_pincer": {
		"id": "tactic_flank_pincer", "name": "两翼包抄", "tier": 1,
		"desc": "≥2 FAST（两侧分布）：FAST 伤害+30%，中央防御+30%",
		"conditions": {"min_count_by_tag": {"fast": 2}},
		"effects": {"stat_bonus": {"atk_fast_bonus": 0.30, "def_center_bonus": 0.30}}
	},
	"tactic_crossfire": {
		"id": "tactic_crossfire", "name": "交叉火力", "tier": 1,
		"desc": "≥3 SNIPER：SNIPER 射程+30%、伤害+25%、必命中",
		"conditions": {"min_count_by_tag": {"sniper": 3}},
		"effects": {"stat_bonus": {"attack_range_sniper": 0.30, "sniper_damage_bonus": 0.25},
		            "special": ["sniper_never_miss"]}
	},
	"tactic_fortress_line": {
		"id": "tactic_fortress_line", "name": "堡垒防线", "tier": 1,
		"desc": "≥4 FORT：全体-35% 受伤，部署速度-20%",
		"conditions": {"min_count_by_kind": {GC.CombatKind.FORT: 4}},
		"effects": {"stat_bonus": {"damage_reduction": 0.35, "deploy_speed": -0.20}}
	},
	"tactic_draw_deep": {
		"id": "tactic_draw_deep", "name": "诱敌深入", "tier": 1,
		"desc": "≥1 FAST（前排）+ ≥3 后排：FAST 受伤-30%，后排攻击+25%",
		"conditions": {"min_count_by_tag": {"fast": 1}, "min_backline_count": 3},
		"effects": {"stat_bonus": {"damage_reduction_fast": 0.30, "atk_backline_bonus": 0.25}}
	},
	"tactic_scorched_line": {
		"id": "tactic_scorched_line", "name": "焦土防线", "tier": 1,
		"desc": "≥2 FLAME 卡片技能 + ≥1 FORT：全体免疫燃烧，火焰伤害+30%",
		"conditions": {
			"min_card_skill_family": {"flame": 2},
			"min_count_by_kind": {GC.CombatKind.FORT: 1}
		},
		"effects": {"stat_bonus": {"flame_damage_bonus": 0.30},
		            "special": ["immune_burn"]}
	},
	"tactic_saturation": {
		"id": "tactic_saturation", "name": "饱和打击", "tier": 1,
		"desc": "≥2 ARTILLERY + ≥1 ECM：火炮伤害+50%、射程+20%",
		"conditions": {
			"min_count_by_tag": {"artillery": 2, "ecm": 1}
		},
		"effects": {"stat_bonus": {"atk_artillery_bonus": 0.50, "attack_range_artillery": 0.20}}
	},
	"tactic_decapitation": {
		"id": "tactic_decapitation", "name": "斩首行动", "tier": 1,
		"desc": "≥1 SNIPER + ≥1 STALKER + VOID 技能：对 Boss/相位师伤害×2",
		"conditions": {
			"min_count_by_tag": {"sniper": 1, "stalker": 1},
			"min_card_skill_family": {"void": 1}
		},
		"effects": {"stat_bonus": {"atk_vs_boss_mult": 1.0},
		            "special": ["decapitation_active"]}
	},
	"tactic_feint": {
		"id": "tactic_feint", "name": "声东击西", "tier": 1,
		"desc": "≥1 ECM + ≥2 FAST：FAST 暴击+25%，ECM 受伤-25%",
		"conditions": {"min_count_by_tag": {"ecm": 1, "fast": 2}},
		"effects": {"stat_bonus": {"crit_fast_bonus": 0.25, "damage_reduction_ecm": 0.25}}
	},
	"tactic_siege_intercept": {
		"id": "tactic_siege_intercept", "name": "围点打援", "tier": 1,
		"desc": "≥2 FORT + ≥1 ARMOR：FORT 受伤-20%，ARMOR 对新进入敌方+50%",
		"conditions": {
			"min_count_by_kind": {GC.CombatKind.FORT: 2, GC.CombatKind.ARMOR: 1}
		},
		"effects": {"stat_bonus": {"damage_reduction_fort": 0.20, "atk_armor_vs_new_enemy": 0.50}}
	},
	"tactic_depth_operation": {
		"id": "tactic_depth_operation", "name": "纵深作战", "tier": 1,
		"desc": "≥3 不同 CombatKind：全体全属性+10%",
		"conditions": {"require_distinct_kinds": 3},
		"effects": {"stat_bonus": {"atk_light": 0.10, "atk_armor": 0.10, "atk_air": 0.10,
		                           "def_light": 0.10, "def_armor": 0.10, "def_air": 0.10,
		                           "max_hp": 0.10}}
	},
}

## 6 个高级战法（需技能树解锁 tactic 节点后才生效）
const ADVANCED_TACTICS: Dictionary = {
	"tactic_blitz": {
		"id": "tactic_blitz", "name": "闪电穿插", "tier": 2,
		"desc": "≥3 FAST：FAST 攻速+40%、伤害+30%",
		"require_unlock": true,
		"conditions": {"min_count_by_tag": {"fast": 3}},
		"effects": {"stat_bonus": {"attack_speed_fast": 0.40, "atk_fast_bonus": 0.30}}
	},
	"tactic_sky_net": {
		"id": "tactic_sky_net", "name": "天罗地网", "tier": 2,
		"desc": "STEEL+THUNDER 技能：全体敌方攻速-30%、移速-30%",
		"require_unlock": true,
		"conditions": {
			"min_card_skill_family": {"steel": 1, "thunder": 1}
		},
		"effects": {"stat_bonus": {"enemy_attack_speed_penalty": 0.30, "enemy_move_speed_penalty": 0.30}}
	},
	"tactic_inferno_counter": {
		"id": "tactic_inferno_counter", "name": "纵火反击", "tier": 2,
		"desc": "≥2 FLAME 技能：全体 HP+20%，死亡 20% 复活",
		"require_unlock": true,
		"conditions": {"min_card_skill_family": {"flame": 2}},
		"effects": {"stat_bonus": {"max_hp": 0.20},
		            "special": ["phoenix_revive_20"]}
	},
	"tactic_4d_strike": {
		"id": "tactic_4d_strike", "name": "四维打击", "tier": 2,
		"desc": "4 家族各 1 技能：全体全属性+25%",
		"require_unlock": true,
		"conditions": {
			"min_card_skill_family": {"steel": 1, "flame": 1, "thunder": 1, "void": 1}
		},
		"effects": {"stat_bonus": {"atk_light": 0.25, "atk_armor": 0.25, "atk_air": 0.25,
		                           "def_light": 0.25, "def_armor": 0.25, "def_air": 0.25,
		                           "max_hp": 0.25}}
	},
	"tactic_total_war": {
		"id": "tactic_total_war", "name": "全面战争", "tier": 2,
		"desc": "4 终极技能：全体+40% 全属性，敌方每秒-1% HP",
		"require_unlock": true,
		"conditions": {"min_ultimate_skill_count": 4},
		"effects": {"stat_bonus": {"atk_light": 0.40, "atk_armor": 0.40, "atk_air": 0.40,
		                           "def_light": 0.40, "def_armor": 0.40, "def_air": 0.40,
		                           "max_hp": 0.40},
		            "special": ["enemy_hp_drain_1pct"]}
	},
}

## 获取所有战法定义（基础+高级）
static func get_all_tactics() -> Dictionary:
	var all: Dictionary = BASIC_TACTICS.duplicate()
	all.merge(ADVANCED_TACTICS, true)
	return all

## 根据 ID 查找战法
static func get_tactic(tactic_id: String) -> Dictionary:
	if BASIC_TACTICS.has(tactic_id):
		return BASIC_TACTICS[tactic_id].duplicate(true)
	if ADVANCED_TACTICS.has(tactic_id):
		return ADVANCED_TACTICS[tactic_id].duplicate(true)
	return {}

## 是否为高级战法（需技能树解锁）
static func is_advanced(tactic_id: String) -> bool:
	return ADVANCED_TACTICS.has(tactic_id)
