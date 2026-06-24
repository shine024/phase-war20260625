extends RefCounted
class_name FactionQuestGenerator
## v6.9: 势力动态任务生成器
##
## 设计理念：
## - 玩家进入某势力领地关卡时，该势力向玩家发布委托（动态生成任务）
## - 任务主题与势力设定呼应（钢壁=防御战、新星=火力战、虚空=相位师战等）
## - 任务奖励含 company_rep/faction_rep（完成任务影响势力声望）—— 复用 _grant_rewards 成熟链路
## - 高声望等级的势力发布更高级任务（目标更高、奖励更丰厚）
##
## 生成时机（由 QuestManager.refresh_faction_quests 调用本生成器）：
##   - 进入该势力领地关卡（game_manager 触发）
##   - 玩家声望等级提升（fsm.faction_level_up 信号）
##
## 任务模板：每势力 3 个模板，按权重抽取（确保多样性，不重复生成同类）

const QuestDefs = preload("res://data/quest_definitions.gd")

## 势力主题配置（关卡范围来自 level_information.gd，相位师名来自 NPC_PHASE_MASTERS）
## 注意：关卡范围与 level_information.gd 对齐（1-20关无主之地，不参与动态任务生成）
const FACTION_THEMES: Dictionary = {
	"nova_arms": {
		"name": "新星兵工",
		"level_range": [21, 40],
		"enemy_faction": "iron_wall_corp",   # 势力敌对关系（新星↔钢壁竞争）
		"master_name": "炽焰星痕",
		"theme": "火力压制",
	},
	"aether_dynamics": {
		"name": "以太动力",
		"level_range": [41, 60],
		"enemy_faction": "nova_arms",        # 以太↔新星竞争
		"master_name": "雷霆判官",
		"theme": "机动突击",
	},
	"quantum_logistics": {
		"name": "量子后勤",
		"level_range": [61, 80],
		"enemy_faction": "",
		"master_name": "量子幽灵",
		"theme": "资源争夺",
	},
	"helix_recon": {
		"name": "螺旋侦察",
		"level_range": [81, 90],
		"enemy_faction": "void_research",    # 螺旋↔虚空竞争
		"master_name": "虚空低语",
		"theme": "侦察渗透",
	},
	"void_research": {
		"name": "虚空相位",
		"level_range": [91, 100],
		"enemy_faction": "helix_recon",      # 虚空↔螺旋竞争
		"master_name": "终焉之镰",
		"theme": "相位研究",
	},
}

## 生成势力动态任务
## [param faction_id] 势力ID
## [param faction_level] 势力等级（1-10，决定任务难度/奖励）
## [return] 任务定义 Dictionary（已含 is_dynamic=true 标记）；生成失败返回空字典
static func generate_quest(faction_id: String, faction_level: int) -> Dictionary:
	var theme: Dictionary = FACTION_THEMES.get(faction_id, {})
	if theme.is_empty():
		return {}
	var fname: String = String(theme.get("name", faction_id))
	var lvl_range: Array = theme.get("level_range", [1, 100])
	var enemy_faction: String = String(theme.get("enemy_faction", ""))
	var master_name: String = String(theme.get("master_name", ""))
	var difficulty_tier: int = clampi((faction_level - 1) / 3, 0, 3)  # 0-3 档

	# 按权重抽取任务类型
	var quest_types: Array = [
		{"type": "win_battles", "weight": 40},
		{"type": "kill_enemies", "weight": 30},
	]
	# 有敌对势力的才能生成 attack_faction 任务
	if not enemy_faction.is_empty():
		quest_types.append({"type": "attack_faction", "weight": 20})
	# 有相位师名的才能生成 defend_faction 任务（驻防击退）
	if not master_name.is_empty():
		quest_types.append({"type": "defend_faction", "weight": 10})

	var picked_type: String = _weighted_pick(quest_types)
	var quest_def: Dictionary = _build_quest_def(picked_type, faction_id, faction_level, theme, difficulty_tier)
	if quest_def.is_empty():
		return {}
	quest_def["id"] = _make_quest_id(faction_id, picked_type, difficulty_tier)
	quest_def["title"] = "【%s委托】%s" % [fname, String(quest_def.get("_short_title", "作战任务"))]
	quest_def["company_id"] = faction_id
	return quest_def


# ──────────────── 内部：任务定义构建 ────────────────

## 按任务类型构建定义（复用现有 objective_type，确保进度追踪/完成判定自动支持）
static func _build_quest_def(quest_type: String, faction_id: String, faction_level: int, theme: Dictionary, tier: int) -> Dictionary:
	var fname: String = String(theme.get("name", faction_id))
	var lvl_range: Array = theme.get("level_range", [1, 100])
	var enemy_faction: String = String(theme.get("enemy_faction", ""))
	var master_name: String = String(theme.get("master_name", ""))
	# 奖励随势力等级提升（纳米材料 + 势力声望）
	var nano_reward: int = 30 + faction_level * 15
	var rep_reward: int = 80 + faction_level * 40  # 完成任务提升本势力声望

	var def: Dictionary = {
		"category": "commission",
		"rewards": {
			"nano_materials": nano_reward,
			"company_rep": {faction_id: rep_reward},
		},
	}

	match quest_type:
		"win_battles":
			var battles: int = [3, 4, 5, 6][tier]
			def["objective_type"] = "win_battles"
			def["target"] = battles
			def["_short_title"] = "战术作战×%d" % battles
			def["description"] = "为%s完成%d场胜利，巩固我们在该领地的影响力。" % [fname, battles]
			# 敌对势力任务额外扣敌对声望
			if not enemy_faction.is_empty():
				def["rewards"]["faction_rep"] = {enemy_faction: -(40 + faction_level * 20)}
			# v6.9: 战术作战带随机结果（成功/部分成功/意外缴获）
			def["outcome_table"] = _make_win_battles_outcomes(nano_reward, rep_reward, faction_id, enemy_faction, faction_level)

		"kill_enemies":
			var kills: int = [20, 30, 40, 60][tier]
			def["objective_type"] = "kill_enemies"
			def["target"] = kills
			def["_short_title"] = "清剿敌军×%d" % kills
			def["description"] = "消灭%d个敌方单位，削弱领地内的反抗力量。" % kills

		"attack_faction":
			# 打击敌对势力：在敌对势力领地击败其相位师
			# 复用 defend_faction 语义（在指定势力关卡击败相位师）——现有 attack_faction 靠
			# target_master 精确匹配名，而动态任务要匹配"任意该势力相位师"，defend_faction 更合适
			def["objective_type"] = "defend_faction"
			def["target"] = {"defend_faction": enemy_faction}
			def["_short_title"] = "打击%s" % enemy_faction
			def["description"] = "前往%s领地击败其相位师，为%s扩张势力范围。" % [enemy_faction, fname]
			def["rewards"]["faction_rep"] = {enemy_faction: -(100 + faction_level * 30)}

		"defend_faction":
			# 驻防击退：在本势力关卡击败来犯相位师
			def["objective_type"] = "defend_faction"
			def["target"] = {"defend_faction": faction_id}
			def["_short_title"] = "驻防击退"
			def["description"] = "在%s领地击败来犯的敌方相位师，保卫我们的领地。" % fname
			# 额外奖励：敌对势力声望下降
			if not enemy_faction.is_empty():
				def["rewards"]["faction_rep"] = {enemy_faction: -(60 + faction_level * 20)}

		_:
			return {}
	return def


## 加权随机抽取
static func _weighted_pick(items: Array) -> String:
	var total_weight: int = 0
	for item in items:
		total_weight += int(item.get("weight", 1))
	if total_weight <= 0:
		return ""
	var roll: int = randi() % total_weight
	for item in items:
		roll -= int(item.get("weight", 1))
		if roll < 0:
			return String(item.get("type", ""))
	return String(items[0].get("type", ""))


## 生成唯一任务 ID（含势力+类型+档位+随机后缀，避免重复）
static func _make_quest_id(faction_id: String, quest_type: String, tier: int) -> String:
	return "dyn_%s_%s_t%d_%d" % [faction_id, quest_type, tier, randi() % 100000]


## v6.9: 为战术作战任务生成结果变体表（成功/部分成功/意外缴获）
## 让"势力委托"完成时有随机结果，体现"任务结果不确定"设定
static func _make_win_battles_outcomes(nano_base: int, rep_base: int, faction_id: String, enemy_faction: String, faction_level: int) -> Array:
	var outcomes: Array = [
		{
			"weight": 50,
			"label": "圆满成功",
			"rewards": {
				"nano_materials": nano_base,
				"company_rep": {faction_id: rep_base},
			},
		},
		{
			"weight": 35,
			"label": "部分成功（战损较大，奖励减半）",
			"rewards": {
				"nano_materials": int(nano_base * 0.5),
				"company_rep": {faction_id: int(rep_base * 0.5)},
			},
		},
		{
			"weight": 15,
			"label": "意外缴获敌方物资（额外声望+纳米）",
			"rewards": {
				"nano_materials": nano_base + 20,
				"company_rep": {faction_id: rep_base + 40},
			},
		},
	]
	# 有敌对势力时，意外缴获额外削弱敌对声望
	if not enemy_faction.is_empty():
		outcomes[2]["rewards"]["faction_rep"] = {enemy_faction: -(60 + faction_level * 15)}
	return outcomes
