extends RefCounted
class_name IntelRevealEvents
## v6.7: 情报揭示事件定义（单维度化）
## 原 v6.0 的 112 条事件（7类敌人 × 4维 × 4档）已合并为 28 条（7类敌人 × 4档）。
##
## key格式: "{enemy_type}_{tier}"  (tier: 0-3 对应 25%/50%/75%/100%)
## 合并规则：原同 tier 下 4 维 rewards 取并集，同类奖励取较高值。
## 例：原 infantry_basic_2(drop+10%) + infantry_tactical_1(stat_visibility:skill_list) + infantry_material_1(drop+15%)
##     → infantry_1: stat_visibility:full_stats + skill_list, drop_rate_bonus 0.15 (取较高)

# ── 揭示事件表（7类敌人 × 4档 = 28条） ─────────────────────────────
# rewards type说明：
#   "stat_visibility"     — 属性可见性等级提升
#   "weakness_bonus"      — 对该敌人类型弱点伤害加成 (bonus_damage: float)
#   "drop_rate_bonus"     — 掉落率加成 (bonus_pct: float)
#   "eom_unlock_hint"     — 敌源MOD解锁提示
#   "eom_unlock"          — 直接解锁敌源MOD (mod_id: String)
#   "intel_branch_hint"   — 进化分支线索文字
#   "intel_branch_unlock" — 直接解锁进化分支 (branch_id: String)
#   "lore_page"           — 解锁世界观页面

const REVEAL_EVENTS: Dictionary = {

	# ═══════════════════════════════════════════════
	#  步兵系 (infantry)
	# ═══════════════════════════════════════════════
	"infantry_0": {
		"title": "初步情报·步兵识别",
		"desc": "首次交火后识别了敌方步兵单位的编制类型、装备与基本战术行为。",
		"rewards": [
			{"type": "stat_visibility", "value": "name_and_type"},
			{"type": "stat_visibility", "value": "equipment_type"},
			{"type": "stat_visibility", "value": "behavior_summary"},
		],
		"icon": "📋",
	},
	"infantry_1": {
		"title": "深入分析·步兵战术",
		"desc": "获取步兵的完整属性与技能列表：手榴弹、战壕挖掘、掩护射击等。蓝图碎片掉落率提升。",
		"rewards": [
			{"type": "stat_visibility", "value": "full_stats"},
			{"type": "stat_visibility", "value": "skill_list"},
			{"type": "drop_rate_bonus", "bonus_pct": 0.15},
		],
		"icon": "📊",
	},
	"infantry_2": {
		"title": "弱点破解·步兵反制",
		"desc": "确认步兵换弹与机动转移时存在约1.5秒的防御间隙！利用此窗口可造成额外25%伤害。同时解锁敌源改造【步兵战术套件】。",
		"rewards": [
			{"type": "weakness_bonus", "target_type": "infantry", "bonus_damage": 0.25},
			{"type": "eom_unlock", "mod_id": "EOM_INFANTRY_01"},
		],
		"icon": "💥",
	},
	"infantry_3": {
		"title": "完全掌握·步兵机密",
		"desc": "步兵相关情报全部破译！对步兵伤害再+10%，掉落率+50%，解锁隐藏进化分支【特种作战路线】。",
		"rewards": [
			{"type": "weakness_bonus", "target_type": "infantry", "bonus_damage": 0.10},
			{"type": "drop_rate_bonus", "bonus_pct": 0.50},
			{"type": "intel_branch_unlock", "branch_id": "IB_INFANTRY_SPECIAL"},
		],
		"icon": "🏆",
	},

	# ═══════════════════════════════════════════════
	#  火焰兵系 (flame)
	# ═══════════════════════════════════════════════
	"flame_0": {
		"title": "初步情报·火焰兵识别",
		"desc": "确认火焰喷射兵的存在——该单位使用凝胶燃料（遇水不可扑灭），倾向逼近近距离开火。",
		"rewards": [
			{"type": "stat_visibility", "value": "name_and_type"},
			{"type": "stat_visibility", "value": "equipment_type"},
			{"type": "stat_visibility", "value": "behavior_summary"},
		],
		"icon": "📋",
	},
	"flame_1": {
		"title": "深入分析·火焰战术",
		"desc": "掌握火焰兵完整参数与技能：持续灼烧、范围喷射、死亡燃料爆炸。蓝图碎片掉落率提升。",
		"rewards": [
			{"type": "stat_visibility", "value": "full_stats"},
			{"type": "stat_visibility", "value": "skill_list"},
			{"type": "drop_rate_bonus", "bonus_pct": 0.15},
		],
		"icon": "📊",
	},
	"flame_2": {
		"title": "弱点破解·燃料罐",
		"desc": "火焰兵的燃料罐是致命弱点！对火焰兵的穿甲/爆炸伤害+30%。同时解锁敌源改造【热能抗性装甲】。",
		"rewards": [
			{"type": "weakness_bonus", "target_type": "flame", "bonus_damage": 0.30},
			{"type": "eom_unlock", "mod_id": "EOM_FLAME_01"},
		],
		"icon": "💥",
	},
	"flame_3": {
		"title": "完全掌握·火焰机密",
		"desc": "火焰相关机密全部破译！额外+10%伤害，掉落率+50%，解锁隐藏进化分支【自适应装甲路线】。",
		"rewards": [
			{"type": "weakness_bonus", "target_type": "flame", "bonus_damage": 0.10},
			{"type": "drop_rate_bonus", "bonus_pct": 0.50},
			{"type": "intel_branch_unlock", "branch_id": "IB_ADAPTIVE_ARMOR"},
		],
		"icon": "🏆",
	},

	# ═══════════════════════════════════════════════
	#  重装甲系 (heavy_armor)
	# ═══════════════════════════════════════════════
	"heavy_armor_0": {
		"title": "初步情报·重装甲识别",
		"desc": "确认重装甲单位的存在——复合装甲+反应装甲层，以缓慢稳定速度推进，优先攻击最近单位。",
		"rewards": [
			{"type": "stat_visibility", "value": "name_and_type"},
			{"type": "stat_visibility", "value": "equipment_type"},
			{"type": "stat_visibility", "value": "behavior_summary"},
		],
		"icon": "📋",
	},
	"heavy_armor_1": {
		"title": "深入分析·重装甲战术",
		"desc": "掌握重装甲完整参数与技能：主炮轰击、碾压冲锋、紧急维修。蓝图碎片掉落率提升。",
		"rewards": [
			{"type": "stat_visibility", "value": "full_stats"},
			{"type": "stat_visibility", "value": "skill_list"},
			{"type": "drop_rate_bonus", "bonus_pct": 0.15},
		],
		"icon": "📊",
	},
	"heavy_armor_2": {
		"title": "弱点破解·侧后装甲",
		"desc": "重装甲侧面和后方装甲显著薄弱！从侧后方攻击可造成额外30%伤害。同时解锁敌源改造【反应装甲模块】。",
		"rewards": [
			{"type": "weakness_bonus", "target_type": "heavy_armor", "bonus_damage": 0.30},
			{"type": "eom_unlock", "mod_id": "EOM_ARMOR_01"},
		],
		"icon": "💥",
	},
	"heavy_armor_3": {
		"title": "完全掌握·重装甲机密",
		"desc": "重装甲相关机密全部破译！额外+10%伤害，掉落率+50%，解锁隐藏进化分支【破甲猎手路线】。",
		"rewards": [
			{"type": "weakness_bonus", "target_type": "heavy_armor", "bonus_damage": 0.10},
			{"type": "drop_rate_bonus", "bonus_pct": 0.50},
			{"type": "intel_branch_unlock", "branch_id": "IB_ARMOR_BREAKER"},
		],
		"icon": "🏆",
	},

	# ═══════════════════════════════════════════════
	#  火炮系 (artillery)
	# ═══════════════════════════════════════════════
	"artillery_0": {
		"title": "初步情报·火炮识别",
		"desc": "确认敌方火炮单位——超高射程可覆盖全图，停留后方优先打击我方高价值目标。",
		"rewards": [
			{"type": "stat_visibility", "value": "name_and_type"},
			{"type": "stat_visibility", "value": "equipment_type"},
			{"type": "stat_visibility", "value": "behavior_summary"},
		],
		"icon": "📋",
	},
	"artillery_1": {
		"title": "深入分析·火炮战术",
		"desc": "掌握火炮完整参数与技能：曲射炮击、烟雾遮蔽、集束炸弹。蓝图碎片掉落率提升。",
		"rewards": [
			{"type": "stat_visibility", "value": "full_stats"},
			{"type": "stat_visibility", "value": "skill_list"},
			{"type": "drop_rate_bonus", "bonus_pct": 0.15},
		],
		"icon": "📊",
	},
	"artillery_2": {
		"title": "弱点破解·装填窗口",
		"desc": "火炮开火后有约3秒的装填窗口，此时防御降至最低！攻击+30%伤害。同时解锁敌源改造【弹道校准系统】。",
		"rewards": [
			{"type": "weakness_bonus", "target_type": "artillery", "bonus_damage": 0.30},
			{"type": "eom_unlock", "mod_id": "EOM_ARTILLERY_01"},
		],
		"icon": "💥",
	},
	"artillery_3": {
		"title": "完全掌握·火炮机密",
		"desc": "火炮相关机密全部破译！额外+10%伤害，掉落率+50%，解锁隐藏进化分支【空中炮艇路线】的部分条件。",
		"rewards": [
			{"type": "weakness_bonus", "target_type": "artillery", "bonus_damage": 0.10},
			{"type": "drop_rate_bonus", "bonus_pct": 0.50},
			{"type": "intel_branch_hint", "text": "空中炮艇路线还需要更多空中单位和隐匿单位的情报来完全解锁。"},
		],
		"icon": "🏆",
	},

	# ═══════════════════════════════════════════════
	#  隐匿系 (stealth)
	# ═══════════════════════════════════════════════
	"stealth_0": {
		"title": "初步情报·隐匿识别",
		"desc": "确认隐匿型敌方单位——使用光学迷彩涂层（特定波段可探测），倾向先侦察再突袭。",
		"rewards": [
			{"type": "stat_visibility", "value": "name_and_type"},
			{"type": "stat_visibility", "value": "equipment_type"},
			{"type": "stat_visibility", "value": "behavior_summary"},
		],
		"icon": "📋",
	},
	"stealth_1": {
		"title": "深入分析·隐匿战术",
		"desc": "掌握隐匿完整参数与技能：光学迷彩、瞬移突击、后背刺杀。蓝图碎片掉落率提升。",
		"rewards": [
			{"type": "stat_visibility", "value": "full_stats"},
			{"type": "stat_visibility", "value": "skill_list"},
			{"type": "drop_rate_bonus", "bonus_pct": 0.15},
		],
		"icon": "📊",
	},
	"stealth_2": {
		"title": "弱点破解·暴露瞬间",
		"desc": "隐匿单位在攻击瞬间解除隐身！攻击判定后0.5秒内造成+30%伤害。同时解锁敌源改造【光学迷彩涂层】。",
		"rewards": [
			{"type": "weakness_bonus", "target_type": "stealth", "bonus_damage": 0.30},
			{"type": "eom_unlock", "mod_id": "EOM_STEALTH_01"},
		],
		"icon": "💥",
	},
	"stealth_3": {
		"title": "完全掌握·隐匿机密",
		"desc": "隐匿相关机密全部破译！额外+10%伤害，掉落率+50%。空中炮艇路线的隐匿战术条件已满足。",
		"rewards": [
			{"type": "weakness_bonus", "target_type": "stealth", "bonus_damage": 0.10},
			{"type": "drop_rate_bonus", "bonus_pct": 0.50},
			{"type": "intel_branch_hint", "text": "空中炮艇路线已接近完成！"},
		],
		"icon": "🏆",
	},

	# ═══════════════════════════════════════════════
	#  纳米BOSS系 (boss_nano)
	# ═══════════════════════════════════════════════
	"boss_nano_0": {
		"title": "初步情报·纳米核心识别",
		"desc": "确认纳米核心BOSS——自组装纳米材料构造体，以自适应AI运作，会动态调整攻击策略。",
		"rewards": [
			{"type": "stat_visibility", "value": "name_and_type"},
			{"type": "stat_visibility", "value": "equipment_type"},
			{"type": "stat_visibility", "value": "behavior_summary"},
		],
		"icon": "📋",
	},
	"boss_nano_1": {
		"title": "深入分析·纳米核心战术",
		"desc": "掌握纳米核心完整参数与技能：纳米脉冲波、自修复场、纳米吞噬、相位转换。掉落率提升20%。",
		"rewards": [
			{"type": "stat_visibility", "value": "full_stats"},
			{"type": "stat_visibility", "value": "skill_list"},
			{"type": "drop_rate_bonus", "bonus_pct": 0.20},
		],
		"icon": "📊",
	},
	"boss_nano_2": {
		"title": "弱点破解·修复中断窗口",
		"desc": "纳米核心每60秒有5秒纳米再生中断窗口，且自修复时防御降低！此时造成+30%额外伤害。解锁敌源改造【纳米再生核心】。",
		"rewards": [
			{"type": "weakness_bonus", "target_type": "boss_nano", "bonus_damage": 0.30},
			{"type": "eom_unlock", "mod_id": "EOM_BOSS_NANO"},
		],
		"icon": "💥",
	},
	"boss_nano_3": {
		"title": "完全掌握·纳米核心机密",
		"desc": "纳米核心相关机密全部破译！额外+10%伤害，掉落率+50%。自适应装甲路线的纳米条件已满足。",
		"rewards": [
			{"type": "weakness_bonus", "target_type": "boss_nano", "bonus_damage": 0.10},
			{"type": "drop_rate_bonus", "bonus_pct": 0.50},
			{"type": "intel_branch_hint", "text": "纳米机密完全掌握——与火焰技术结合即可开启自适应装甲！"},
		],
		"icon": "🏆",
	},

	# ═══════════════════════════════════════════════
	#  空中系 (air)
	# ═══════════════════════════════════════════════
	"air_0": {
		"title": "初步情报·空中单位识别",
		"desc": "确认敌方空中单位——使用轻量化航空合金与先进航电，飞行中持续攻击，优先打击防空最弱单位。",
		"rewards": [
			{"type": "stat_visibility", "value": "name_and_type"},
			{"type": "stat_visibility", "value": "equipment_type"},
			{"type": "stat_visibility", "value": "behavior_summary"},
		],
		"icon": "📋",
	},
	"air_1": {
		"title": "深入分析·空中战术",
		"desc": "掌握空中单位完整参数与技能：俯冲轰炸、空对地导弹、电子干扰。蓝图碎片掉落率提升。",
		"rewards": [
			{"type": "stat_visibility", "value": "full_stats"},
			{"type": "stat_visibility", "value": "skill_list"},
			{"type": "drop_rate_bonus", "bonus_pct": 0.15},
		],
		"icon": "📊",
	},
	"air_2": {
		"title": "弱点破解·爬升恢复期",
		"desc": "空中单位俯冲后有固定的爬升恢复期，此时防御显著降低！防空攻击+30%伤害。解锁敌源改造【精确打击模块】。",
		"rewards": [
			{"type": "weakness_bonus", "target_type": "air", "bonus_damage": 0.30},
			{"type": "eom_unlock", "mod_id": "EOM_AIR_01"},
		],
		"icon": "💥",
	},
	"air_3": {
		"title": "完全掌握·空中机密",
		"desc": "空中相关机密全部破译！额外+10%伤害，掉落率+50%。空中炮艇路线的航空条件已满足。",
		"rewards": [
			{"type": "weakness_bonus", "target_type": "air", "bonus_damage": 0.10},
			{"type": "drop_rate_bonus", "bonus_pct": 0.50},
			{"type": "intel_branch_hint", "text": "空中炮艇路线已接近完成！"},
		],
		"icon": "🏆",
	},
}

# ── 工具函数 ───────────────────────────────────────────────────────

## 构建揭示事件key
## 注意：dimension 参数保留以兼容旧调用签名（单维度化后内部忽略）
static func make_event_key(enemy_type: String, dimension: String, tier: int) -> String:
	return "%s_%d" % [enemy_type, tier]

## 获取揭示事件
## 注意：dimension 参数保留以兼容旧调用签名
static func get_event(enemy_type: String, dimension: String, tier: int) -> Dictionary:
	var key: String = make_event_key(enemy_type, dimension, tier)
	return REVEAL_EVENTS.get(key, {})

## 检查揭示事件是否存在
static func has_event(enemy_type: String, dimension: String, tier: int) -> bool:
	var key: String = make_event_key(enemy_type, dimension, tier)
	return REVEAL_EVENTS.has(key)

## 获取某敌人类型所有已定义的揭示事件
static func get_all_events_for_type(enemy_type: String) -> Dictionary:
	var result: Dictionary = {}
	var prefix: String = enemy_type + "_"
	for key in REVEAL_EVENTS:
		if key.begins_with(prefix):
			result[key] = REVEAL_EVENTS[key]
	return result

## 获取所有已定义的敌人类型
static func get_defined_enemy_types() -> Array[String]:
	var types: Array[String] = []
	for key in REVEAL_EVENTS:
		var parts: PackedStringArray = key.split("_")
		if parts.size() >= 2:
			var etype: String = parts[0]
			if not types.has(etype):
				types.append(etype)
	return types
