extends RefCounted
class_name FactionQuestGenerator
## v6.9: 势力动态任务生成器（v6.22 贡献驱动改版重写）
##
## v6.22 设计定案（docs/势力重构_贡献驱动改版_2026-09-22.md §5 批2c）：
## - 任务=贡献主驱动，委托分三类：
##   流程性（win_battles/kill_enemies）、培养性（collect_cards/enhance/buy_items/reach_intel/salvage_items）、
##   目的性（clear_level/clear_boss_count）
## - 去 enemy_faction/master_name 战争框架（不再有"进攻/防守某势力"）；level_range 保留=历史辖区触发区段，
##   触发链 game_manager._maybe_refresh_faction_quests_for_level 不动
## - 奖励键统一 faction_rep（读侧保留 company_rep 双键兼容），只发正贡献
## - outcome_table 随机结果机制保留，文案改协作口径
## - 7 家组织全覆盖（此前 5 家，缺 iron_wall_corp/frontier_union）
##
## 生成时机（由 QuestManager.refresh_faction_quests 调用本生成器）：
##   - 进入该组织历史辖区关卡（game_manager 触发）
##   - 玩家贡献等级提升（fsm.faction_level_up 信号）

const QuestDefs = preload("res://data/quest_definitions.gd")

## 势力主题配置（level_range=历史辖区区段，来自 level_information.gd 静态表；
## iron_wall_corp/frontier_union 无专属辖区带，给宽区段随前线推进发布委托）
const FACTION_THEMES: Dictionary = {
	"iron_wall_corp": {
		"name": "钢壁防务",
		"level_range": [21, 60],
		"theme": "装备检验",
	},
	"nova_arms": {
		"name": "新星兵工",
		"level_range": [21, 40],
		"theme": "火力支援",
	},
	"aether_dynamics": {
		"name": "以太动力",
		"level_range": [41, 60],
		"theme": "机动协同",
	},
	"quantum_logistics": {
		"name": "量子后勤",
		"level_range": [61, 80],
		"theme": "物资调度",
	},
	"helix_recon": {
		"name": "螺旋侦察",
		"level_range": [81, 90],
		"theme": "情报整编",
	},
	"void_research": {
		"name": "虚空相位",
		"level_range": [91, 100],
		"theme": "相位研究",
	},
	"frontier_union": {
		"name": "边境联合",
		"level_range": [21, 100],
		"theme": "护路维稳",
	},
}

## 三类委托模板池（type + 权重）。目标数值随贡献等级档位（0-3）放大。
const QUEST_TYPES: Array = [
	# 流程性：例行作战
	{"type": "win_battles", "weight": 26},
	{"type": "kill_enemies", "weight": 20},
	# 培养性：收集/强化/研究/回收
	{"type": "collect_cards", "weight": 10},
	{"type": "enhance", "weight": 6},
	{"type": "buy_items", "weight": 5},
	{"type": "reach_intel", "weight": 11},
	{"type": "salvage_items", "weight": 10},
	# 目的性：推进/剿灭
	{"type": "clear_level", "weight": 7},
	{"type": "clear_boss_count", "weight": 5},
]

## 生成势力动态任务
## [param faction_id] 势力ID
## [param faction_level] 贡献等级（1-10，决定任务难度/奖励）
## [return] 任务定义 Dictionary（已含 is_dynamic 标记链）；生成失败返回空字典
static func generate_quest(faction_id: String, faction_level: int) -> Dictionary:
	var theme: Dictionary = FACTION_THEMES.get(faction_id, {})
	if theme.is_empty():
		return {}
	var fname: String = String(theme.get("name", faction_id))
	var lvl_range: Array = theme.get("level_range", [21, 100])
	var difficulty_tier: int = clampi((faction_level - 1) / 3, 0, 3)  # 0-3 档

	var picked_type: String = _weighted_pick(QUEST_TYPES)
	var quest_def: Dictionary = _build_quest_def(picked_type, faction_id, faction_level, theme, difficulty_tier)
	if quest_def.is_empty():
		return {}
	quest_def["id"] = _make_quest_id(faction_id, picked_type, difficulty_tier)
	quest_def["title"] = "【%s委托】%s" % [fname, String(quest_def.get("_short_title", "协作任务"))]
	quest_def["company_id"] = faction_id
	return quest_def


# ──────────────── 内部：任务定义构建 ────────────────

## 按任务类型构建定义（复用现有 objective_type，确保进度追踪/完成判定自动支持）
static func _build_quest_def(quest_type: String, faction_id: String, faction_level: int, theme: Dictionary, tier: int) -> Dictionary:
	var fname: String = String(theme.get("name", faction_id))
	var lvl_range: Array = theme.get("level_range", [21, 100])
	# 奖励随贡献等级提升（纳米材料 + 本组织贡献，只发正贡献）
	var nano_reward: int = 30 + faction_level * 15
	var rep_reward: int = 80 + faction_level * 40

	var def: Dictionary = {
		"category": "commission",
		"rewards": {
			"nano_materials": nano_reward,
			"faction_rep": {faction_id: rep_reward},
		},
	}

	match quest_type:
		# ── 流程性 ──
		"win_battles":
			var battles: int = [3, 4, 5, 6][tier]
			def["objective_type"] = "win_battles"
			def["target"] = battles
			def["_short_title"] = "例行作战 ×%d" % battles
			def["description"] = "为%s胜利完成 %d 场战斗。" % [fname, battles]
			# v6.9: 例行作战带随机结果（成功/部分成功/意外缴获）
			def["outcome_table"] = _make_win_battles_outcomes(nano_reward, rep_reward, faction_id)

		"kill_enemies":
			var kills: int = [20, 30, 40, 60][tier]
			def["objective_type"] = "kill_enemies"
			def["target"] = kills
			def["_short_title"] = "区域清剿 ×%d" % kills
			def["description"] = "击毁 %d 个迷失者单位，为%s清理作业区。" % [kills, fname]

		# ── 培养性 ──
		"collect_cards":
			var cards: int = [2, 3, 4, 6][tier]
			def["objective_type"] = "collect_cards"
			def["target"] = cards
			def["_short_title"] = "装备收编 ×%d" % cards
			def["description"] = "收集 %d 种新的战斗卡，扩充%s的装备图鉴。" % [cards, fname]

		"enhance":
			var times: int = [2, 3, 4, 6][tier]
			def["objective_type"] = "enhance"
			def["target"] = times
			def["_short_title"] = "装备强化 ×%d" % times
			def["description"] = "完成 %d 次战斗卡强化，帮助%s验证强化工艺。" % [times, fname]

		"buy_items":
			var buys: int = [2, 3, 4, 5][tier]
			def["objective_type"] = "buy_items"
			def["target"] = buys
			def["_short_title"] = "军需采买 ×%d" % buys
			def["description"] = "在商店完成 %d 次采买，帮%s盘活补给链。" % [buys, fname]

		"reach_intel":
			var aid: String = _pick_research_target(lvl_range)
			if aid.is_empty():
				return {}
			var pct: int = [25, 35, 50, 60][tier]
			def["objective_type"] = "reach_intel"
			def["target"] = {"archetype_id": aid, "target": pct}
			def["_short_title"] = "战术研究 %d%%" % pct
			def["description"] = "把「%s」的情报研究到 %d%%，协助%s完善敌方形态数据库。" % [_intel_display_name(aid), pct, fname]

		"salvage_items":
			var pieces: int = [8, 12, 18, 25][tier]
			def["objective_type"] = "salvage_items"
			def["target"] = pieces
			def["_short_title"] = "战场回收 ×%d" % pieces
			def["description"] = "回收 %d 件战场战利品，交给%s作拆解研究。" % [pieces, fname]

		# ── 目的性 ──
		"clear_level":
			var goal_level: int = clampi(int(lvl_range[1]) - [8, 5, 3, 1][tier], 2, 100)
			def["objective_type"] = "clear_level"
			def["target"] = goal_level
			def["_short_title"] = "推进第 %d 关" % goal_level
			def["description"] = "在第 %d 关取得胜利，为%s的推进计划提供掩护。" % [goal_level, fname]

		"clear_boss_count":
			var bosses: int = [1, 1, 2, 3][tier]
			def["objective_type"] = "clear_boss_count"
			def["target"] = bosses
			def["_short_title"] = "关隘肃清 ×%d" % bosses
			def["description"] = "击败 %d 个相位师盘踞的首领关卡（每时代终点关），帮%s扫清前进通道。" % [bosses, fname]

		_:
			return {}
	return def


## 培养性·reach_intel：按历史辖区区段抽一个该区段敌形（有情报键即合法）
static func _pick_research_target(lvl_range: Array) -> String:
	var EnemyArch := preload("res://data/enemy_archetypes.gd")
	var lo: int = maxi(1, int(lvl_range[0]))
	var hi: int = clampi(int(lvl_range[1]), lo, 100)
	var candidates: Array = []
	for aid in EnemyArch.get_all_ids():
		var era_start: int = _era_band_start(String(aid))
		if era_start >= lo - 20 and era_start <= hi:
			candidates.append(String(aid))
	if candidates.is_empty():
		return ""
	return String(candidates[randi() % candidates.size()])


## 敌形 id 时代前缀 → 该时代起始关（ww1=1/ww2=21/cold=41/mod=61/fut=81；未知归二战带）
static func _era_band_start(aid: String) -> int:
	if aid.begins_with("ww1"):
		return 1
	if aid.begins_with("ww2"):
		return 21
	if aid.begins_with("cold"):
		return 41
	if aid.begins_with("mod"):
		return 61
	if aid.begins_with("fut"):
		return 81
	return 21


## archetype 显示名兜底（档案名 → DefaultCards 展示名 → 裸 id）
static func _intel_display_name(aid: String) -> String:
	var DefaultCardsRef := preload("res://data/default_cards.gd")
	var c: CardResource = DefaultCardsRef.get_card_by_id(aid)
	if c != null:
		return c.display_name
	return aid


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


## v6.9: 为例行作战任务生成结果变体表（成功/部分成功/意外缴获）
## 让"势力委托"完成时有随机结果，体现"任务结果不确定"设定（v6.22 改协作口径）
static func _make_win_battles_outcomes(nano_base: int, rep_base: int, faction_id: String) -> Array:
	return [
		{
			"weight": 50,
			"label": "任务达成",
			"rewards": {
				"nano_materials": nano_base,
				"faction_rep": {faction_id: rep_base},
			},
		},
		{
			"weight": 35,
			"label": "部分达成（战损较大，补给减半）",
			"rewards": {
				"nano_materials": int(nano_base * 0.5),
				"faction_rep": {faction_id: int(rep_base * 0.5)},
			},
		},
		{
			"weight": 15,
			"label": "意外缴获敌方物资（追加贡献与纳米材料）",
			"rewards": {
				"nano_materials": nano_base + 20,
				"faction_rep": {faction_id: rep_base + 40},
			},
		},
	]
