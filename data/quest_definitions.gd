extends RefCounted
class_name QuestDefinitions

const _QUESTS_JSON_PATH := "res://data/json/quest_definitions.json"
static var QUESTS: Array = _load_json_array(_QUESTS_JSON_PATH, LEGACY_QUESTS)

## v6.9: 动态任务集合（运行时注册，不写入静态 QUESTS）
## 由 QuestManager.register_dynamic_quest 委托填充；get_by_id/get_available_ids 自动同时查询两个集合
## 存档由 QuestManager.save_state 持久化（保存定义 + 注册状态），读档后回填到这里
static var _DYNAMIC_QUESTS: Dictionary = {}  # quest_id -> quest_def Dictionary

static func _load_json_array(path: String, fallback: Array) -> Array:
	if not FileAccess.file_exists(path):
		return fallback
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("schema_version", 0)) != 1:
		return fallback
	var data = parsed.get("data", fallback)
	return data if typeof(data) == TYPE_ARRAY else fallback

## 委托任务定义：可自由接取，完成得奖励
##
## objective_type:
##   - win_battles / kill_enemies / collect_fragments / clear_level: 通用任务
##   - attack_faction: 进攻任务，击败某势力的相位师
##   - defend_faction: 防守任务，保护某势力免受相位师进攻
## target:
##   - win_battles→int场次
##   - kill_enemies→int数量
##   - collect_fragments：已废弃（v3），新任务用 collect_cards
##   - attack_faction→{target_faction: 势力ID, target_master: 相位师名}
##   - defend_faction→{defend_faction: 势力ID, attacker_master: 相位师名}
## rewards: { nano_materials; unlock_blueprint; ... }
## company_rep 与 FactionSystemManager 声望同源（任务奖励仍可用 company_rep 键名）
##
## v6.7(剧情任务): 自由模式剧情任务字段（向后兼容，缺省值不影响旧任务）
##   category: 任务分类，"commission"(委托,默认) / "story"(剧情) / "daily"(日常)
##   trigger_level: 剧情任务绑定的关卡号（仅 category=="story" 用）
##   pre_battle_dialogues: 战前对话队列，每项 {speaker, text, choices?}
##   post_battle_dialogues: 战后对话队列，每项 {speaker, text, choices?}
##
## v6.9(势力占领): 动态任务与随机结果字段（向后兼容，缺省值不影响旧任务）
##   is_dynamic: 是否运行时生成的动态任务（由 FactionQuestGenerator 生成，QuestManager 注册）
##   outcome_table: 结果变体表（可选），完成时按权重抽取替代固定 rewards，体现"任务结果不确定"
##     格式: [{weight:int, label:String, rewards:Dictionary}, ...]
##     label 用于完成提示（如"情报行动：部分成功"），rewards 走 _grant_rewards 标准链路
##     缺省 outcome_table（或空数组）→ 走固定 rewards（向后兼容所有现有任务）

const LEGACY_QUESTS: Array[Dictionary] = [
	# ==================== 原有任务 ====================

	{
		"id": "q_win_3",
		"title": "初战告捷",
		"description": "胜利完成 3 场战斗。",
		"objective_type": "win_battles",
		"target": 3,
		"company_id": "iron_wall_corp",
		"rewards": {
			"nano_materials": 10,
			"company_rep": {"iron_wall_corp": 10},
		},
	},
	{
		"id": "q_win_10",
		"title": "连战连捷",
		"description": "胜利完成 10 场战斗。",
		"objective_type": "win_battles",
		"target": 10,
		"company_id": "iron_wall_corp",
		"rewards": {
			"nano_materials": 25,
			"company_rep": {"iron_wall_corp": 20},
		},
	},
	{
		"id": "q_kill_20",
		"title": "歼灭敌单位",
		"description": "累计击毁 20 个敌方单位。",
		"objective_type": "kill_enemies",
		"target": 20,
		"company_id": "nova_arms",
		"rewards": {
			"nano_materials": 15,
			"company_rep": {"nova_arms": 12},
		},
	},
	{
		"id": "q_kill_50",
		"title": "火力压制",
		"description": "累计击毁 50 个敌方单位。",
		"objective_type": "kill_enemies",
		"target": 50,
		"company_id": "nova_arms",
		"rewards": {
			"nano_materials": 40,
			"company_rep": {"nova_arms": 20},
		},
	},
	{
		"id": "q_frag_smg",
		"title": "扩充军械库",
		"description": "解锁至少 3 种卡牌蓝图（v3：无碎片，以解锁卡种计）。",
		"objective_type": "collect_cards",
		"target": 3,
		"company_id": "void_research",
		"rewards": {
			"nano_materials": 20,
			"company_rep": {"void_research": 15},
		},
	},
	{
		"id": "q_clear_5",
		"title": "突破第5关",
		"description": "在第 5 关取得胜利。",
		"objective_type": "clear_level",
		"target": 5,
		"company_id": "frontier_union",
		"rewards": {
			"nano_materials": 15,
			"company_rep": {"frontier_union": 12},
		},
	},
	{
		"id": "q_clear_10",
		"title": "突破第10关",
		"description": "在第 10 关取得胜利。",
		"objective_type": "clear_level",
		"target": 10,
		"company_id": "frontier_union",
		"rewards": {
			"nano_materials": 30,
			"company_rep": {"frontier_union": 20},
		},
	},
	{
		"id": "q_win_5_any",
		"title": "五场胜利",
		"description": "任意关卡胜利 5 场。",
		"objective_type": "win_battles",
		"target": 5,
		"company_id": "quantum_logistics",
		"rewards": {
			"nano_materials": 12,
			"company_rep": {"quantum_logistics": 10},
		},
	},
	{
		"id": "q_win_20",
		"title": "百战精兵",
		"description": "胜利完成 20 场战斗。",
		"objective_type": "win_battles",
		"target": 20,
		"company_id": "iron_wall_corp",
		"rewards": {
			"nano_materials": 50,
			"company_rep": {"iron_wall_corp": 35},
		},
	},
	{
		"id": "q_kill_100",
		"title": "歼灭百敌",
		"description": "累计击毁 100 个敌方单位。",
		"objective_type": "kill_enemies",
		"target": 100,
		"company_id": "nova_arms",
		"rewards": {
			"nano_materials": 60,
			"company_rep": {"nova_arms": 40},
		},
	},
	{
		"id": "q_clear_20",
		"title": "突破第20关",
		"description": "在第 20 关取得胜利。",
		"objective_type": "clear_level",
		"target": 20,
		"company_id": "frontier_union",
		"rewards": {
			"nano_materials": 45,
			"company_rep": {"frontier_union": 30},
		},
	},

	# ==================== 进攻/防守任务 ====================

	{
		"id": "q_attack_void",
		"title": "进攻：虚空相位",
		"description": "击败虚空相位势力的相位师「终焉之镰」，夺取其领地。",
		"objective_type": "attack_faction",
		"target": {"target_faction": "void_research", "target_master": "终焉之镰"},
		"company_id": "nova_arms",
		"rewards": {
			"nano_materials": 80,
			"faction_rep": {"nova_arms": 25, "void_research": -20},
		},
	},
	{
		"id": "q_attack_nova",
		"title": "进攻：新星兵工",
		"description": "击败新星兵工势力的相位师「炽焰星痕」，夺取其领地。",
		"objective_type": "attack_faction",
		"target": {"target_faction": "nova_arms", "target_master": "炽焰星痕"},
		"company_id": "iron_wall_corp",
		"rewards": {
			"nano_materials": 80,
			"faction_rep": {"iron_wall_corp": 25, "nova_arms": -20},
		},
	},
	{
		"id": "q_attack_aether",
		"title": "进攻：以太动力",
		"description": "击败以太动力势力相位师「雷霆判官」，瓦解其防御体系。",
		"objective_type": "attack_faction",
		"target": {"target_faction": "aether_dynamics", "target_master": "雷霆判官"},
		"company_id": "quantum_logistics",
		"rewards": {
			"nano_materials": 80,
			"faction_rep": {"quantum_logistics": 25, "aether_dynamics": -20},
		},
	},
	{
		"id": "q_defend_iron",
		"title": "防守：钢壁防务",
		"description": "保护钢壁防务领地，击退进攻的敌方相位师。",
		"objective_type": "defend_faction",
		"target": {"defend_faction": "iron_wall_corp"},
		"company_id": "iron_wall_corp",
		"rewards": {
			"nano_materials": 60,
			"faction_rep": {"iron_wall_corp": 30},
		},
	},
	{
		"id": "q_defend_frontier",
		"title": "防守：边境联合",
		"description": "保护边境联合领地，击退敌方相位师的进攻。",
		"objective_type": "defend_faction",
		"target": {"defend_faction": "frontier_union"},
		"company_id": "frontier_union",
		"rewards": {
			"nano_materials": 60,
			"faction_rep": {"frontier_union": 30},
		},
	},
	{
		"id": "q_defend_helix",
		"title": "防守：螺旋侦察",
		"description": "保护螺旋侦察的侦察网络，击退来犯之敌。",
		"objective_type": "defend_faction",
		"target": {"defend_faction": "helix_recon"},
		"company_id": "helix_recon",
		"rewards": {
			"nano_materials": 60,
			"faction_rep": {"helix_recon": 30},
		},
	},

	# ==================== 新增：初级任务（新手引导） ====================

	{
		"id": "q_tutorial_win_1",
		"title": "首战告捷",
		"description": "完成你的第一场战斗胜利。",
		"objective_type": "win_battles",
		"target": 1,
		"company_id": "iron_wall_corp",
		"rewards": {
			"nano_materials": 5,
			"company_rep": {"iron_wall_corp": 5},
		},
	},
	{
		"id": "q_tutorial_enhance",
		"title": "强化尝试",
		"description": "强化任意一张卡片到 +3。",
		"objective_type": "enhance",
		"target": 3,
		"company_id": "void_research",
		"rewards": {
			"nano_materials": 15,
			"company_rep": {"void_research": 10},
		},
	},
	{
		"id": "q_tutorial_clear_3",
		"title": "初露锋芒",
		"description": "成功通关前3关中的任意一关。",
		"objective_type": "clear_level",
		"target": 3,
		"company_id": "frontier_union",
		"rewards": {
			"nano_materials": 8,
			"company_rep": {"frontier_union": 8},
		},
	},
	{
		"id": "q_tutorial_collect_5",
		"title": "收藏家",
		"description": "拥有至少5张不同的卡片。",
		"objective_type": "collect_cards",
		"target": 5,
		"company_id": "quantum_logistics",
		"rewards": {
			"nano_materials": 10,
			"company_rep": {"quantum_logistics": 8},
		},
	},
	{
		"id": "q_tutorial_law",
		"title": "法则初探",
		"description": "研究你的第一个战争法则。",
		"objective_type": "research_law",
		"target": 1,
		"company_id": "void_research",
		"rewards": {
			"nano_materials": 12,
			"company_rep": {"void_research": 10},
		},
	},
	{
		"id": "q_tutorial_faction",
		"title": "势力接触",
		"description": "与任意势力建立关系（声望达到10）。",
		"objective_type": "reach_reputation",
		"target": 10,
		"company_id": "helix_recon",
		"rewards": {
			"nano_materials": 10,
			"company_rep": {"helix_recon": 10},
		},
	},

	# ==================== 新增：战斗任务 ====================

	{
		"id": "q_battle_win_30",
		"title": "战争老手",
		"description": "累计胜利30场战斗。",
		"objective_type": "win_battles",
		"target": 30,
		"company_id": "iron_wall_corp",
		"rewards": {
			"nano_materials": 70,
			"company_rep": {"iron_wall_corp": 40},
		},
	},
	{
		"id": "q_battle_win_50",
		"title": "战场传奇",
		"description": "累计胜利50场战斗。",
		"objective_type": "win_battles",
		"target": 50,
		"company_id": "iron_wall_corp",
		"rewards": {
			"nano_materials": 100,
			"company_rep": {"iron_wall_corp": 60},
		},
	},
	{
		"id": "q_battle_kill_150",
		"title": "收割者",
		"description": "累计击毁150个敌方单位。",
		"objective_type": "kill_enemies",
		"target": 150,
		"company_id": "nova_arms",
		"rewards": {
			"nano_materials": 80,
			"company_rep": {"nova_arms": 50},
		},
	},
	{
		"id": "q_battle_kill_200",
		"title": "战场主宰",
		"description": "累计击毁200个敌方单位。",
		"objective_type": "kill_enemies",
		"target": 200,
		"company_id": "nova_arms",
		"rewards": {
			"nano_materials": 120,
			"company_rep": {"nova_arms": 70},
		},
	},
	{
		"id": "q_battle_clear_40",
		"title": "突破中期",
		"description": "通关第40关（二战时代终点）。",
		"objective_type": "clear_level",
		"target": 40,
		"company_id": "frontier_union",
		"rewards": {
			"nano_materials": 55,
			"company_rep": {"frontier_union": 35},
		},
	},
	{
		"id": "q_battle_clear_60",
		"title": "冷战胜利",
		"description": "通关第60关（冷战时代终点）。",
		"objective_type": "clear_level",
		"target": 60,
		"company_id": "frontier_union",
		"rewards": {
			"nano_materials": 65,
			"company_rep": {"frontier_union": 40},
		},
	},
	{
		"id": "q_battle_clear_80",
		"title": "现代主宰",
		"description": "通关第80关（现代时代终点）。",
		"objective_type": "clear_level",
		"target": 80,
		"company_id": "frontier_union",
		"rewards": {
			"nano_materials": 75,
			"company_rep": {"frontier_union": 45},
		},
	},
	{
		"id": "q_battle_clear_100",
		"title": "终极征服",
		"description": "通关第100关（近未来时代终点）。",
		"objective_type": "clear_level",
		"target": 100,
		"company_id": "frontier_union",
		"rewards": {
			"nano_materials": 200,
			"company_rep": {"frontier_union": 100},
		},
	},
	{
		"id": "q_battle_boss_3",
		"title": "Boss猎手",
		"description": "击败3个Boss关卡（每时代第20关）。",
		"objective_type": "clear_level",
		"target": 3,
		"company_id": "frontier_union",
		"rewards": {
			"nano_materials": 75,
			"company_rep": {"frontier_union": 45},
		},
	},
	{
		"id": "q_battle_all_era",
		"title": "时空穿越者",
		"description": "在所有5个时代都取得过胜利。",
		"objective_type": "clear_level",
		"target": 5,
		"company_id": "void_research",
		"rewards": {
			"nano_materials": 90,
			"company_rep": {"void_research": 50},
		},
	},
	{
		"id": "q_battle_quick_win",
		"title": "速战速决",
		"description": "在60秒内完成一场战斗胜利。",
		"objective_type": "quick_win",
		"target": 60,
		"company_id": "nova_arms",
		"rewards": {
			"nano_materials": 40,
			"company_rep": {"nova_arms": 25},
		},
	},

	# ==================== 新增：收集任务 ====================

	{
		"id": "q_collect_platform_10",
		"title": "平台收藏家",
		"description": "拥有10张不同的平台卡。",
		"objective_type": "collect_cards",
		"target": 10,
		"company_id": "quantum_logistics",
		"rewards": {
			"nano_materials": 20,
			"company_rep": {"quantum_logistics": 15},
		},
	},
	{
		"id": "q_collect_rare",
		"title": "稀世珍宝",
		"description": "拥有3张稀有度以上的卡片。",
		"objective_type": "collect_cards",
		"target": 3,
		"company_id": "void_research",
		"rewards": {
			"nano_materials": 30,
			"company_rep": {"void_research": 20},
		},
	},
	{
		"id": "q_collect_legendary",
		"title": "传说猎手",
		"description": "拥有1张传说稀有度的卡片。",
		"objective_type": "collect_cards",
		"target": 1,
		"company_id": "void_research",
		"rewards": {
			"nano_materials": 50,
			"company_rep": {"void_research": 35},
		},
	},
	{
		"id": "q_collect_fragments_50",
		"title": "碎片大师",
		"description": "拥有总计50个蓝图碎片（可包含不同类型）。",
		"objective_type": "collect_fragments",
		"target": {"total": 50},
		"company_id": "void_research",
		"rewards": {
			"nano_materials": 35,
			"company_rep": {"void_research": 25},
		},
	},
	{
		"id": "q_collect_ww2",
		"title": "二战收藏家",
		"description": "拥有5张二战时代的卡片。",
		"objective_type": "collect_cards",
		"target": 5,
		"company_id": "iron_wall_corp",
		"rewards": {
			"nano_materials": 22,
			"company_rep": {"iron_wall_corp": 16},
		},
	},
	{
		"id": "q_collect_modern",
		"title": "现代收藏家",
		"description": "拥有5张现代时代的卡片。",
		"objective_type": "collect_cards",
		"target": 5,
		"company_id": "aether_dynamics",
		"rewards": {
			"nano_materials": 28,
			"company_rep": {"aether_dynamics": 20},
		},
	},
	{
		"id": "q_collect_future",
		"title": "未来收藏家",
		"description": "拥有5张近未来时代的卡片。",
		"objective_type": "collect_cards",
		"target": 5,
		"company_id": "void_research",
		"rewards": {
			"nano_materials": 32,
			"company_rep": {"void_research": 22},
		},
	},

	# ==================== 新增：势力任务 ====================

	{
		"id": "q_faction_iron_30",
		"title": "钢壁盟友",
		"description": "与钢壁防务的声望达到30。",
		"objective_type": "reach_reputation",
		"target": 30,
		"company_id": "iron_wall_corp",
		"rewards": {
			"nano_materials": 35,
			"company_rep": {"iron_wall_corp": 20},
		},
	},
	{
		"id": "q_faction_nova_30",
		"title": "新星伙伴",
		"description": "与新星兵工的声望达到30。",
		"objective_type": "reach_reputation",
		"target": 30,
		"company_id": "nova_arms",
		"rewards": {
			"nano_materials": 35,
			"company_rep": {"nova_arms": 20},
		},
	},
	{
		"id": "q_faction_aether_30",
		"title": "以太之友",
		"description": "与以太动力的声望达到30。",
		"objective_type": "reach_reputation",
		"target": 30,
		"company_id": "aether_dynamics",
		"rewards": {
			"nano_materials": 35,
			"company_rep": {"aether_dynamics": 20},
		},
	},
	{
		"id": "q_faction_void_30",
		"title": "虚空探索者",
		"description": "与虚空研究所的声望达到30。",
		"objective_type": "reach_reputation",
		"target": 30,
		"company_id": "void_research",
		"rewards": {
			"nano_materials": 35,
			"company_rep": {"void_research": 20},
		},
	},
	{
		"id": "q_faction_all_20",
		"title": "各方势力",
		"description": "与所有7个势力的声望都达到20。",
		"objective_type": "reach_reputation",
		"target": 20,
		"company_id": "frontier_union",
		"rewards": {
			"nano_materials": 80,
			"company_rep": {"frontier_union": 50, "iron_wall_corp": 15, "nova_arms": 15, "aether_dynamics": 15, "void_research": 15, "quantum_logistics": 15, "helix_recon": 15},
		},
	},
	{
		"id": "q_faction_max_50",
		"title": "势力领袖",
		"description": "与任意一个势力的声望达到50。",
		"objective_type": "reach_reputation",
		"target": 50,
		"company_id": "quantum_logistics",
		"rewards": {
			"nano_materials": 60,
			"company_rep": {"quantum_logistics": 35},
		},
	},
	{
		"id": "q_faction_buy_10",
		"title": "购物达人",
		"description": "在公司商店购买10次物品。",
		"objective_type": "buy_items",
		"target": 10,
		"company_id": "quantum_logistics",
		"rewards": {
			"nano_materials": 25,
			"company_rep": {"quantum_logistics": 18},
		},
	},

	# ==================== 新增：挑战任务 ====================

	{
		"id": "q_challenge_all_era_boss",
		"title": "Boss征服者",
		"description": "击败所有5个时代的Boss关卡。",
		"objective_type": "clear_level",
		"target": 5,
		"company_id": "frontier_union",
		"rewards": {
			"nano_materials": 150,
			"company_rep": {"frontier_union": 80},
		},
	},
	{
		"id": "q_challenge_perfect",
		"title": "完美战役",
		"description": "在一场战斗中获得三星评价。",
		"objective_type": "perfect_battle",
		"target": 1,
		"company_id": "iron_wall_corp",
		"rewards": {
			"nano_materials": 60,
			"company_rep": {"iron_wall_corp": 40},
		},
	},
	{
		"id": "q_challenge_speed",
		"title": "闪电战",
		"description": "在30秒内完成一场战斗胜利。",
		"objective_type": "quick_win",
		"target": 30,
		"company_id": "aether_dynamics",
		"rewards": {
			"nano_materials": 65,
			"company_rep": {"aether_dynamics": 42},
		},
	},
	{
		"id": "q_challenge_survival",
		"title": "生存大师",
		"description": "在一场战斗中存活15个波次。",
		"objective_type": "survive_waves",
		"target": 15,
		"company_id": "iron_wall_corp",
		"rewards": {
			"nano_materials": 70,
			"company_rep": {"iron_wall_corp": 45},
		},
	},

	# ==================== v6.2 补充：螺旋侦察势力任务（原仅2个，补齐至8个） ====================

	{
		"id": "q_faction_helix_30",
		"title": "螺旋声望：信赖",
		"description": "与螺旋侦察系统建立信赖关系（声望达到30）。",
		"objective_type": "reach_reputation",
		"target": 30,
		"company_id": "helix_recon",
		"rewards": {
			"nano_materials": 25,
			"company_rep": {"helix_recon": 30},
		},
	},
	{
		"id": "q_helix_scout_50",
		"title": "侦察精英",
		"description": "累计击毁50个敌方单位，证明螺旋侦察的情报优势。",
		"objective_type": "kill_enemies",
		"target": 50,
		"company_id": "helix_recon",
		"rewards": {
			"nano_materials": 40,
			"company_rep": {"helix_recon": 25},
		},
	},
	{
		"id": "q_helix_intel_5",
		"title": "情报收集",
		"description": "完成5场战斗胜利，为螺旋侦察收集前线情报。",
		"objective_type": "win_battles",
		"target": 5,
		"company_id": "helix_recon",
		"rewards": {
			"nano_materials": 35,
			"company_rep": {"helix_recon": 20},
		},
	},
	{
		"id": "q_helix_recon_raid",
		"title": "突袭行动",
		"description": "击败3个相位大师，展示螺旋侦察的精准打击能力。",
		"objective_type": "kill_enemies",
		"target": 100,
		"company_id": "helix_recon",
		"rewards": {
			"nano_materials": 60,
			"company_rep": {"helix_recon": 40},
		},
	},
	{
		"id": "q_helix_speed_clear",
		"title": "闪电突进",
		"description": "快速完成10场战斗（每场90秒内结束），展现螺旋的机动优势。",
		"objective_type": "win_battles",
		"target": 10,
		"company_id": "helix_recon",
		"rewards": {
			"nano_materials": 50,
			"company_rep": {"helix_recon": 35},
		},
	},
	{
		"id": "q_helix_collect_modern",
		"title": "现代侦察装备",
		"description": "收集5张不同的现代时代卡牌，充实螺旋侦察的装备库。",
		"objective_type": "collect_cards",
		"target": 5,
		"company_id": "helix_recon",
		"rewards": {
			"nano_materials": 45,
			"company_rep": {"helix_recon": 30},
		},
	},

	# ==================== v6.6(剧情): 真实者支线任务（补剧情.txt 第四幕）====================
	# hidden=true 的任务初始不可见，由 NPC 对话 reveal_quest 揭示后才能接取
	# branches 定义玩家选择（加入/拒绝/拖延）后的后续任务链

	# 真实者的邀请 — 第10关进关自动揭示（自由模式无 city_map/NPC，改触发关揭示）
	# v6.7: 归入剧情标签，trigger_level=10 进关时自动揭示，玩家在任务面板接取
	{
		"id": "q_realist_invite",
		"title": "真实者的邀请",
		"description": "一个自称'真实者'的人声称看穿了无限城的循环真相。他说5742次重启是假的。加入他们？还是拒绝？",
		"objective_type": "win_battles",
		"target": 1,
		"company_id": "void_research",
		"rewards": {
			"nano_materials": 50,
			"company_rep": {"void_research": 25},
		},
		"category": "story",
		"trigger_level": 10,
		"hidden": true,
		"prereq": "",
		"branches": {
			"join":   {"next_quest": "q_realist_join"},
			"reject": {"next_quest": "q_realist_reject"},
			"delay":  {"next_quest": "q_realist_delay"},
		},
	},
	# 分支A：加入真实者（v6.7: 归入剧情，靠 prereq 链揭示）
	{
		"id": "q_realist_join",
		"title": "觉醒者的道路",
		"description": "你选择了加入真实者。在他们的指引下，探索城市的隐藏区域，寻找海伦隐瞒的真相。",
		"objective_type": "clear_level",
		"target": 60,
		"company_id": "void_research",
		"rewards": {
			"nano_materials": 80,
			"company_rep": {"void_research": 40},
		},
		"category": "story",
		"hidden": true,
		"prereq": "q_realist_invite",
	},
	# 分支B：拒绝真实者（v6.7: 归入剧情）
	{
		"id": "q_realist_reject",
		"title": "忠诚的相位师",
		"description": "你拒绝了真实者的诱惑。海伦认可了你的忠诚，指挥部对你开放了更多权限。",
		"objective_type": "reach_reputation",
		"target": 1000,
		"company_id": "iron_wall_corp",
		"rewards": {
			"nano_materials": 60,
			"company_rep": {"iron_wall_corp": 50},
		},
		"category": "story",
		"hidden": true,
		"prereq": "q_realist_invite",
	},
	# 分支C：拖延（中立线）（v6.7: 归入剧情）
	{
		"id": "q_realist_delay",
		"title": "骑墙的代价",
		"description": "你没有立刻做决定。真实者和海伦都在观察你。在这段时间里，证明你的实力，让双方都不敢轻视。",
		"objective_type": "win_battles",
		"target": 10,
		"company_id": "aether_dynamics",
		"rewards": {
			"nano_materials": 70,
			"company_rep": {"aether_dynamics": 30, "void_research": 15},
		},
		"category": "story",
		"hidden": true,
		"prereq": "q_realist_invite",
	},

	# 林薇支线任务 — 第15关进关自动揭示（v6.7: 归入剧情，trigger_level=15）
	{
		"id": "q_linwei_secret",
		"title": "E-10946的秘密",
		"description": "林薇提到了E-10946——只差一个编号的那个居民。调查她的过去，也许能解开林薇能量球裂纹的谜团。",
		"objective_type": "collect_cards",
		"target": 30,
		"company_id": "helix_recon",
		"rewards": {
			"nano_materials": 55,
			"company_rep": {"helix_recon": 35},
		},
		"category": "story",
		"trigger_level": 15,
		"hidden": true,
		"prereq": "",
	},

	# 扎克支线任务 — 第40关进关自动揭示（v6.7: 归入剧情，trigger_level=40）
	{
		"id": "q_zack_beyond_48",
		"title": "替扎克看看48关之后",
		"description": "扎克停在48关三年了。他请你走到48关，替他看看门后面到底是什么。这是对一个老工程师的承诺。",
		"objective_type": "clear_level",
		"target": 48,
		"company_id": "frontier_union",
		"rewards": {
			"nano_materials": 100,
			"company_rep": {"frontier_union": 50},
		},
		"category": "story",
		"trigger_level": 40,
		"hidden": true,
		"prereq": "",
	},

	# ==================== v6.7(剧情任务): 自由模式关卡剧情任务（docs/补剧情.txt 关卡映射）====================
	# category="story" + trigger_level 标记关卡剧情；前置 prereq 完成后自动揭示
	# 对话脚本依据补剧情.txt 第六~第十幕编写

	# 第六幕·第一个守护者 — 第20关 Boss战（铁血男爵）
	{
		"id": "q_story_first_guardian",
		"title": "第一个守护者",
		"description": "第20关的能量罩后，传说中的第一个守护者即将现身。林薇递来一枚修复晶核，说它能在关键时刻救你一命。",
		"objective_type": "clear_level",
		"target": 20,
		"company_id": "iron_wall_corp",
		"rewards": {
			"nano_materials": 120,
			"company_rep": {"iron_wall_corp": 40},
		},
		"category": "story",
		"trigger_level": 20,
		"prereq": "q_story_city_15",
		"hidden": true,
		"pre_battle_dialogues": [
			{"speaker": "林薇", "text": "E-10947，前面就是第20关了。听老人说，门后面是第一个守护者——铁血男爵。"},
			{"speaker": "林薇", "text": "拿着这枚修复晶核。如果撑不住，它能救你的相位仪一次。"},
			{"speaker": "陈末", "text": "你为什么帮我？我们是朋友，可你连自己能量球的裂纹都还没修好。"},
			{"speaker": "林薇", "text": "……有些事比裂纹更重要。去吧，证明无限城不止有洛克一个人能走到这里。"},
		],
		"post_battle_dialogues": [
			{"speaker": "旁白", "text": "铁血男爵崩解成一束光，钻进了你的相位仪。"},
			{"speaker": "陈末", "text": "这是……法则符文？"},
			{"speaker": "林薇", "text": "第一枚符文。恭喜你，真正成为了无限城的守护者之一。"},
		],
	},

	# 第八幕·守护者的低语 — 第60关（冷战时代守护者开始说话）
	{
		"id": "q_story_truth_60",
		"title": "守护者的低语",
		"description": "第60关的守护者不再沉默。它在战斗前对你说话，声音里带着一种奇怪的温度。这是无限城从未有过的记录。",
		"objective_type": "clear_level",
		"target": 60,
		"company_id": "aether_dynamics",
		"rewards": {
			"nano_materials": 220,
			"company_rep": {"aether_dynamics": 60},
		},
		"category": "story",
		"trigger_level": 60,
		"prereq": "q_story_first_guardian",
		"hidden": true,
		"pre_battle_dialogues": [
			{"speaker": "守护者", "text": "……你来了。E-10947。我等你很久了。"},
			{"speaker": "陈末", "text": "守护者会说话？前几个都是直接开战的。"},
			{"speaker": "守护者", "text": "它们是程序。我是被遗忘的……守门人。我看过无数次循环，你是少数能站在这里的相位师。"},
			{"speaker": "守护者", "text": "击败我，你将获得第二枚符文。但请记住——入侵是真实的。那个叫'真实者'的人，只是在逃避。"},
			{"speaker": "守护者", "text": "感受你的相位仪——每过一关，裂缝就宽一分。时间越久，入侵就越强。这是事实，不是循环。"},
		],
		"post_battle_dialogues": [
			{"speaker": "守护者", "text": "做得好……孩子。比洛克走得更远。"},
			{"speaker": "陈末", "text": "它知道洛克？还有……'入侵是真实的'，它指的是什么？"},
			{"speaker": "旁白", "text": "守护者化作深蓝符文。相位仪深处传来一阵尖锐的共振——那不是真相的回响，是入侵的波动。它在加速。"},
		],
	},

	# 第七幕·扎克的四十八 — 第48关（陈末替扎克看门后）
	{
		"id": "q_story_zack_48",
		"title": "替扎克看看48关之后",
		"description": "扎克停在48关三年。他对你说：「走到48关时，替我看看门后面到底是什么。」这是一个老工程师最后的执念。",
		"objective_type": "clear_level",
		"target": 48,
		"company_id": "frontier_union",
		"rewards": {
			"nano_materials": 180,
			"company_rep": {"frontier_union": 70},
		},
		"category": "story",
		"trigger_level": 48,
		"prereq": "q_story_first_guardian",
		"hidden": true,
		"pre_battle_dialogues": [
			{"speaker": "扎克", "text": "陈末。你也走到48关了。"},
			{"speaker": "扎克", "text": "三年前我停在这里。不是打不过——是我不敢看门后面是什么。"},
			{"speaker": "陈末", "text": "你在害怕什么？"},
			{"speaker": "扎克", "text": "我曾是工程师，我记得……一些片段。门后面也许有我自己的过去。替我看看，行吗？"},
			{"speaker": "陈末", "text": "我答应你。"},
		],
		"post_battle_dialogues": [
			{"speaker": "旁白", "text": "门后没有扎克的过去。只有一片纯粹的虚空，和一盏等待下一个通关者的灯。"},
			{"speaker": "陈末", "text": "扎克……48关后面什么都没有。只是一条更长的路。"},
			{"speaker": "扎克", "text": "（沉默良久）……谢谢你。也许，那才是我真正不敢面对的。"},
		],
	},

	# 第八幕·洛克止步之地 — 第83关（守护者模拟洛克形态）
	{
		"id": "q_story_locke_83",
		"title": "洛克止步之地",
		"description": "第83关——洛克曾经停下的地方。传说这里的守护者会模拟挑战者的形态，而它选中的，是洛克的影子。",
		"objective_type": "clear_level",
		"target": 83,
		"company_id": "iron_wall_corp",
		"rewards": {
			"nano_materials": 320,
			"company_rep": {"iron_wall_corp": 80},
		},
		"category": "story",
		"trigger_level": 83,
		"prereq": "q_story_truth_60",
		"hidden": true,
		"pre_battle_dialogues": [
			{"speaker": "洛克", "text": "83关。我到过这里，陈末。然后我转身了。"},
			{"speaker": "陈末", "text": "你为什么不继续？"},
			{"speaker": "洛克", "text": "因为门后面站着的是我自己。我没法击败自己——那时候我太在意输赢了。"},
			{"speaker": "旁白", "text": "守护者浮现。它的脸，是洛克年轻时的样子。"},
			{"speaker": "守护者", "text": "（洛克的声音）你愿意为通关付出什么？"},
		],
		"post_battle_dialogues": [
			{"speaker": "守护者", "text": "（消散前）……你做得比我好，陈末。"},
			{"speaker": "洛克", "text": "（门外，声音颤抖）谢谢你。替我走到了那一步。"},
			{"speaker": "陈末", "text": "前面还有17关。我们一起走完。"},
		],
	},

	# 第九幕·镜像自己 — 第99关（镜像守护者复制玩家）
	{
		"id": "q_story_mirror_99",
		"title": "镜像自己",
		"description": "第99关的守护者不模拟任何人——它模拟你。它复制你的卡组、你的相位仪、你的战斗风格。这场战斗唯一的敌人，是另一个你。",
		"objective_type": "clear_level",
		"target": 99,
		"company_id": "aether_dynamics",
		"rewards": {
			"nano_materials": 450,
			"company_rep": {"aether_dynamics": 100},
		},
		"category": "story",
		"trigger_level": 99,
		"prereq": "q_story_countdown_90",
		"hidden": true,
		"pre_battle_dialogues": [
			{"speaker": "海伦", "text": "E-10947。第99关。这是最后一道关卡——之后就是相位之主的领域。"},
			{"speaker": "海伦", "text": "提醒你：这里的守护者会读取你的相位仪。它将使用和你完全相同的卡组。"},
			{"speaker": "陈末", "text": "和另一个我打……有意思。"},
			{"speaker": "海伦", "text": "它没有你的犹豫，也没有你的执念。祝你好运。"},
		],
		"post_battle_dialogues": [
			{"speaker": "镜像", "text": "（倒下前）……原来这就是『愿意付出一切』的感觉。"},
			{"speaker": "陈末", "text": "我也是你。我们都在同一条路上。"},
			{"speaker": "旁白", "text": "镜像消散。第100关的门，缓缓打开。"},
		],
	},

	# 第十幕·最后的试炼 — 第100关（相位之主最终Boss）
	# v6.7重构: 相位之主战前揭穿"入侵是真的、重启是真的、真实者在骗自己"
	# 战后三重揭穿：真实者自我欺骗 + 海伦AI融合身份 + 裂口未关与双重跳跃由来
	{
		"id": "q_story_final_100",
		"title": "最后的试炼",
		"description": "第100关——相位之主的领域。它见证了入侵的真相，也见证了海伦的秘密。它问你：「你愿意为通关付出什么？」",
		"objective_type": "clear_level",
		"target": 100,
		"company_id": "iron_wall_corp",
		"rewards": {
			"nano_materials": 1000,
			"company_rep": {"iron_wall_corp": 150, "aether_dynamics": 100, "frontier_union": 80},
		},
		"category": "story",
		"trigger_level": 100,
		"prereq": "q_story_mirror_99",
		"hidden": true,
		"pre_battle_dialogues": [
			{"speaker": "旁白", "text": "第100关。场景是你记忆中的城市——办公楼、小区、那条你每天走的路。但天空有一道裂口，比之前任何一关都宽。"},
			{"speaker": "相位之主", "text": "欢迎，E-10947。我是相位之主，另一条时间线上的你。"},
			{"speaker": "陈末", "text": "另一条时间线……"},
			{"speaker": "相位之主", "text": "我曾走到这里，然后选择了放弃。但在我告诉你真相之前——忘掉那个叫'真实者'的人说的话。"},
			{"speaker": "相位之主", "text": "入侵是真实的。那道裂口是真的，异虫是真的，所有死去的相位师也是真的。所谓的5742次重启，是真的——每一次，都是海伦为保留你们的战力，强行把时间线拉了回来。"},
			{"speaker": "相位之主", "text": "真实者不敢面对这个残酷的事实，所以他骗自己说'那不是真的'。而你——你愿意为通关付出什么？"},
			{"speaker": "陈末", "text": "我已经没什么可失去了。那就……全部。"},
		],
		"post_battle_dialogues": [
			{"speaker": "相位之主", "text": "（崩解中）恭喜——你是5742次重启中，第7个走到这里的人。"},
			{"speaker": "陈末", "text": "等等。海伦的声音——第90关那次失真，'内环防线'……她到底是什么人？"},
			{"speaker": "相位之主", "text": "你注意到了。海伦，曾经是这座城市的传奇指挥官。当入侵第一次撕开裂口时，她带领所有人扛了整整三年。"},
			{"speaker": "相位之主", "text": "但人类扛不住那么久。最后，她放弃了肉体，把自己的意识与城市系统融合——成了你现在听到的那个声音。城市的每一声播报，都是她残留的意识在燃烧。"},
			{"speaker": "陈末", "text": "她……放弃了生命？"},
			{"speaker": "相位之主", "text": "为了守住你们。而且——你打败了异虫，但裂口没有关闭。它还在撕开。所以海伦设计了双重跳跃：把通关者的战力保存到下一次循环，直到有人能彻底关上那道裂口。"},
			{"speaker": "相位之主", "text": "去吧，陈末。替我们所有人，看一眼门后的光——然后，替海伦，把那道裂口关上。"},
			{"speaker": "旁白", "text": "相位之主消散成漫天星尘。你拿到了最后一枚符文。海伦的声音在广播里轻轻响起：'谢谢你，E-10947。'"},
		],
	},

	# ==================== v6.7(剧情任务·扩展): 补全补剧情.txt 关卡锚点 ====================

	# 第四幕·真实者初次接触 — 第10关（真实者第一次出现）
	# v6.7重构: 真实者是自我欺骗者——他不敢面对入侵的残酷，选择相信"重启是假的"
	# 台词保留"重启是假的"的说法（玩家被误导），但加入自我动摇的破绽（让敏锐的玩家察觉异样）
	{
		"id": "q_story_realist_10",
		"title": "真实者的阴影",
		"description": "第10关前，一个自称'真实者'的人第一次出现。他声称看穿了无限城的循环真相——说5742次重启是假的。但他的眼神里，有一种奇怪的逃避。",
		"objective_type": "clear_level",
		"target": 10,
		"company_id": "void_research",
		"rewards": {
			"nano_materials": 60,
			"company_rep": {"void_research": 30},
		},
		"category": "story",
		"trigger_level": 10,
		"prereq": "",
		"hidden": true,
		"pre_battle_dialogues": [
			{"speaker": "真实者", "text": "E-10947。我等你很久了。"},
			{"speaker": "陈末", "text": "你是谁？怎么知道我的编号？"},
			{"speaker": "真实者", "text": "我是'真实者'。我看穿了这个城市的循环——所谓的5742次重启……那不是真的。那不可能是真的。"},
			{"speaker": "陈末", "text": "你听起来……不太确定？"},
			{"speaker": "真实者", "text": "我确定！我选择相信那不是真的——否则这一切就太残酷了。记住我的话，第60关之后，你会明白的。"},
		],
		"post_battle_dialogues": [
			{"speaker": "旁白", "text": "真实者消失了，像从未出现过。但'我选择相信'这四个字，像一根刺扎进了你的相位仪——他在说服自己，不是在说服你。"},
		],
	},

	# 第二幕·城市功能解锁 — 第15关（林薇商店/训练场/势力声望引入）
	{
		"id": "q_story_city_15",
		"title": "城市的轮廓",
		"description": "第15关。你已经熟悉了无限城的节奏。林薇的商店、扎克的训练场、势力声望——这座城市的轮廓逐渐清晰。",
		"objective_type": "clear_level",
		"target": 15,
		"company_id": "helix_recon",
		"rewards": {
			"nano_materials": 90,
			"company_rep": {"helix_recon": 25, "iron_wall_corp": 15},
		},
		"category": "story",
		"trigger_level": 15,
		"prereq": "q_story_realist_10",
		"hidden": true,
		"pre_battle_dialogues": [
			{"speaker": "林薇", "text": "陈末，第15关了。该正式认识一下这座城了。"},
			{"speaker": "林薇", "text": "我的'四叶草'商店在东区——你打到的多余卡牌可以卖给我，我也能给你换些好东西。"},
			{"speaker": "扎克", "text": "训练场在我这儿。想变强，除了打关，还得练。"},
			{"speaker": "林薇", "text": "还有势力声望——你帮哪个势力打关，他们就会给你资源、卡牌、甚至独家技术。多留意。"},
		],
		"post_battle_dialogues": [
			{"speaker": "旁白", "text": "城市的功能向你敞开。前方的第20关，传说中第一个守护者的领地。"},
		],
	},

	# 时代Boss·钢铁元帅 — 第40关（二战时代守护者）
	{
		"id": "q_story_steel_marshal_40",
		"title": "钢铁洪流",
		"description": "第40关。钢铁元帅——二战时代的相位师主宰，统帅钢铁洪流碾碎过无数挑战者。他比铁血男爵更强。",
		"objective_type": "clear_level",
		"target": 40,
		"company_id": "iron_wall_corp",
		"rewards": {
			"nano_materials": 260,
			"company_rep": {"iron_wall_corp": 70},
		},
		"category": "story",
		"trigger_level": 40,
		"prereq": "q_story_first_guardian",
		"hidden": true,
		"pre_battle_dialogues": [
			{"speaker": "钢铁元帅", "text": "你击败了铁血男爵？有趣。但我是完全不同级别的对手。"},
			{"speaker": "陈末", "text": "又一个相位师……你这架势，比男爵凶多了。"},
			{"speaker": "钢铁元帅", "text": "我是钢铁元帅。我的装甲师团碾碎过整条时间线的反抗者。"},
			{"speaker": "钢铁元帅", "text": "弱者的道德！让我看看你的相位有多强！"},
		],
		"post_battle_dialogues": [
			{"speaker": "旁白", "text": "钢铁元帅倒下，他的相位核心爆炸，撕裂出通往冷战时代的裂缝。"},
			{"speaker": "陈末", "text": "两个守护者了……符文在共鸣。"},
		],
	},

	# 时代Boss·虚空领主 — 第80关（现代时代守护者）
	{
		"id": "q_story_void_lord_80",
		"title": "虚空之主",
		"description": "第80关。虚空领主——现代时代的相位师主宰，操控虚空能量扭曲现实。传闻它并非人类，而是相位能量的具象化。",
		"objective_type": "clear_level",
		"target": 80,
		"company_id": "aether_dynamics",
		"rewards": {
			"nano_materials": 400,
			"company_rep": {"aether_dynamics": 90},
		},
		"category": "story",
		"trigger_level": 80,
		"prereq": "q_story_truth_60",
		"hidden": true,
		"pre_battle_dialogues": [
			{"speaker": "虚空领主", "text": "……相位师。你带来的能量，让我饥饿。"},
			{"speaker": "陈末", "text": "它……不像之前的守护者。它在漂浮。"},
			{"speaker": "虚空领主", "text": "我不是人类。我是相位能量的具象——但我的源头，是入侵撕开的裂口。"},
			{"speaker": "虚空领主", "text": "我能感到源头在膨胀。时间越久，它就越饥饿，越强大。你以为你在通关？不——你在追赶一道正在变宽的裂口。"},
			{"speaker": "虚空领主", "text": "击败我，你将触及虚空的边缘。但记住——裂口，也在看着你。"},
		],
		"post_battle_dialogues": [
			{"speaker": "旁白", "text": "虚空领主崩解成纯粹的相位能量，被你的相位仪吸收。"},
			{"speaker": "陈末", "text": "这是……第四枚符文。但它说的'裂口'……入侵的源头，到底是什么？"},
			{"speaker": "旁白", "text": "第83关——洛克止步之地——就在前方。裂口的波动，比刚才更强了。"},
		],
	},

	# 第九幕前奏·海伦宣告倒计时 — 第90关（全城紧急事件）
	# v6.7重构: 海伦埋身世伏笔——脱口而出老指挥官术语，声音出现失真；同时强调入侵加速
	{
		"id": "q_story_countdown_90",
		"title": "倒计时",
		"description": "第90关。海伦的宣告响彻全城——倒计时开始了。奖励翻倍，传送门全天开放。但她的声音，似乎有什么不对。",
		"objective_type": "clear_level",
		"target": 90,
		"company_id": "iron_wall_corp",
		"rewards": {
			"nano_materials": 500,
			"company_rep": {"iron_wall_corp": 60, "aether_dynamics": 60},
		},
		"category": "story",
		"trigger_level": 90,
		"prereq": "q_story_locke_83",
		"hidden": true,
		"pre_battle_dialogues": [
			{"speaker": "海伦", "text": "全体相位师注意。我是海伦。倒计时正式开始——所有单位收缩到内环防线，传送门全天开放。"},
			{"speaker": "陈末", "text": "……内环防线？海伦，你是播报员，什么时候用过这种战术术语？"},
			{"speaker": "海伦", "text": "（声音出现一瞬间的失真，像是两个声音重叠）……没什么。口误。入侵的波动已突破阈值——每延迟一天，裂口就宽一分。必须抢在它完全撕开前通关。"},
			{"speaker": "海伦", "text": "无限城的最终考验——第100关的相位之主，即将完全觉醒。"},
			{"speaker": "陈末", "text": "等等，你的声音刚才……"},
			{"speaker": "海伦", "text": "没什么。E-10947，你是最有希望的候选人。去吧——为了所有人。"},
		],
		"post_battle_dialogues": [
			{"speaker": "旁白", "text": "第90关通过。海伦的声音在广播里渐渐消散，但那个'两个声音重叠'的瞬间，你记得很清楚。"},
			{"speaker": "陈末", "text": "海伦……你到底是谁？"},
			{"speaker": "旁白", "text": "第99关——镜像守护者——是最后的门槛。"},
		],
	},

	# ==================== v6.7(引导剧情): 系统教学关卡剧情 ====================
	# category="tutorial"：自动触发、不进任务面板、播过一次不重复、不占任务栏名额
	# pre_battle_dialogues 完成后自动给一次性纳米材料奖励

	# 引导1·第1关 — 相位仪与卡牌装配（首次战斗教学）
	{
		"id": "q_tutorial_equip_1",
		"title": "相位仪与卡牌",
		"description": "无限城的第一战。洛克教你把卡牌装进相位仪。",
		"objective_type": "win_battles",
		"target": 1,
		"company_id": "",
		"rewards": {"nano_materials": 20},
		"category": "tutorial",
		"trigger_level": 1,
		"prereq": "",
		"hidden": true,
		"pre_battle_dialogues": [
			{"speaker": "洛克", "text": "E-10947，欢迎来到无限城。看那个发光的球体——那是你的相位仪。"},
			{"speaker": "洛克", "text": "相位仪有四个槽位：红、蓝、绿、黄。每个颜色对应不同的战术职能。"},
			{"speaker": "洛克", "text": "战斗前，先打开背包，把卡牌拖进相位仪的槽位。没有卡牌，相位仪就是一块废铁。"},
			{"speaker": "陈末", "text": "我手上这张……铁壁护盾？"},
			{"speaker": "洛克", "text": "那是你的第一张卡。装上它，然后我们去打第一场。别担心——第一关的虫子很弱。"},
		],
	},

	# 引导2·第5关 — 卡牌强化（提升等级）
	{
		"id": "q_tutorial_enhance_5",
		"title": "卡牌强化",
		"description": "虫子变硬了。洛克教你用纳米材料强化卡牌等级。",
		"objective_type": "win_battles",
		"target": 1,
		"company_id": "",
		"rewards": {"nano_materials": 30},
		"category": "tutorial",
		"trigger_level": 5,
		"prereq": "",
		"hidden": true,
		"pre_battle_dialogues": [
			{"speaker": "洛克", "text": "等一下。你注意到没有？前几关的虫子越来越硬了。"},
			{"speaker": "陈末", "text": "是。我的铁壁护盾有点扛不住了。"},
			{"speaker": "洛克", "text": "该强化了。打开强化面板，消耗纳米材料提升卡牌等级。等级越高，属性越强。"},
			{"speaker": "洛克", "text": "但记住——强化有失败概率。失败的卡会掉级。所以，强化前先看看成功率。"},
			{"speaker": "洛克", "text": "我给你一点纳米材料。去试试。强化完，我们再打第5关。"},
		],
	},

	# 引导3·第10关 — 卡牌改造（安装模块）
	{
		"id": "q_tutorial_modify_10",
		"title": "卡牌改造",
		"description": "单纯的等级不够了。洛克教你给卡牌安装改造模块。",
		"objective_type": "win_battles",
		"target": 1,
		"company_id": "",
		"rewards": {"nano_materials": 40},
		"category": "tutorial",
		"trigger_level": 10,
		"prereq": "",
		"hidden": true,
		"pre_battle_dialogues": [
			{"speaker": "洛克", "text": "第10关。从这里开始，光靠等级堆不过去。"},
			{"speaker": "陈末", "text": "那怎么办？"},
			{"speaker": "洛克", "text": "改造。卡牌上有改造槽，可以装各种模块——穿甲、装甲、火力、侦察……每个模块都改变一张卡的战斗方式。"},
			{"speaker": "洛克", "text": "打开改造面板，给你的主战卡装一个模块。注意槽位类型和模块类型要匹配。"},
			{"speaker": "洛克", "text": "改造比强化稳——不失败，但要消耗合金。我给你一些资源。去试试。"},
		],
	},

	# 引导4·第15关 — 卡牌进化（升阶形态）
	{
		"id": "q_tutorial_evolve_15",
		"title": "卡牌进化",
		"description": "你的卡牌可以进化了。洛克教你把卡牌升阶到更高形态。",
		"objective_type": "win_battles",
		"target": 1,
		"company_id": "",
		"rewards": {"nano_materials": 50},
		"category": "tutorial",
		"trigger_level": 15,
		"prereq": "",
		"hidden": true,
		"pre_battle_dialogues": [
			{"speaker": "洛克", "text": "到第15关了。你的铁壁护盾——其实只是个起点形态。"},
			{"speaker": "陈末", "text": "起点形态？"},
			{"speaker": "洛克", "text": "卡牌能进化。满足条件后，一张普通卡可以变成更强的形态——新属性、新能力，甚至新外观。"},
			{"speaker": "洛克", "text": "打开进化面板。如果条件满足，你会看到进化选项。进化是单向的，想清楚再点。"},
			{"speaker": "洛克", "text": "有些进化路径是隐藏的，需要通过情报系统解锁。这个以后再说。先——试试基础的。"},
		],
	},

	# 引导5·第21关 — 法则符文（打完第20关守护者获得符文后，教如何使用）
	{
		"id": "q_tutorial_rune_21",
		"title": "法则符文",
		"description": "你从铁血男爵那里获得了第一枚法则符文。林薇教你怎么使用它。",
		"objective_type": "win_battles",
		"target": 1,
		"company_id": "",
		"rewards": {"nano_materials": 60},
		"category": "tutorial",
		"trigger_level": 21,
		"prereq": "",
		"hidden": true,
		"pre_battle_dialogues": [
			{"speaker": "林薇", "text": "陈末，恭喜你击败了铁血男爵——你的相位仪吸收了一枚法则符文。"},
			{"speaker": "陈末", "text": "符文？就是刚才那道光？我该怎么用？"},
			{"speaker": "林薇", "text": "法则符文是相位仪最强大的强化。每个符文对应一条法则——钢铁、烈焰、雷霆、虚空。"},
			{"speaker": "林薇", "text": "打开法则面板，研究你刚获得的那条。研究需要研究点。装备符文后战斗风格会大幅改变。"},
			{"speaker": "林薇", "text": "钢铁法则偏防御，烈焰偏爆发。选适合你的——后面的关会越来越难。"},
		],
	},
]

## v6.7(剧情任务): 返回该关卡对应的剧情任务列表（category=="story" 且 trigger_level 匹配）
## 注意：只返回 story 类（world_map 用来显示★标记，tutorial 不应显示标记）
static func get_quests_by_trigger_level(level: int) -> Array:
	var out: Array = []
	for q in QUESTS:
		if q.get("category", "commission") == "story" and int(q.get("trigger_level", 0)) == level:
			out.append(q.duplicate(true))
	return out

## v6.7(引导剧情): 返回该关卡所有可触发的剧情（story + tutorial）
## 供 GameManager 进关钩子使用，收集本关所有应播放的剧情对话
static func get_all_triggerable_at_level(level: int) -> Array:
	var out: Array = []
	for q in QUESTS:
		var cat: String = q.get("category", "commission")
		if (cat == "story" or cat == "tutorial") and int(q.get("trigger_level", 0)) == level:
			out.append(q.duplicate(true))
	return out

## v6.7(剧情任务): 返回指定 category 的任务 id 列表
static func get_ids_by_category(category: String) -> Array:
	var out: Array = []
	for q in QUESTS:
		if q.get("category", "commission") == category:
			out.append(q.get("id", ""))
	return out

static func get_all() -> Array:
	var out: Array = []
	for q in QUESTS:
		out.append(q.duplicate(true))
	return out

static func get_by_id(quest_id: String) -> Dictionary:
	for q in QUESTS:
		if q.get("id", "") == quest_id:
			return q.duplicate(true)
	# v6.9: 回退查动态任务集合
	if _DYNAMIC_QUESTS.has(quest_id):
		return (_DYNAMIC_QUESTS[quest_id] as Dictionary).duplicate(true)
	return {}

static func get_available_ids() -> Array:
	var arr: Array = []
	for q in QUESTS:
		arr.append(q.get("id", ""))
	# v6.9: 合并动态任务 id
	for qid in _DYNAMIC_QUESTS.keys():
		arr.append(String(qid))
	return arr

# ──────────────── v6.9: 动态任务注册接口 ────────────────

## 注册一个动态任务到全局集合（不写入静态 QUESTS）
## [param def] 完整任务定义（需含 id/objective_type/target/rewards 等字段，与静态任务同结构）
## [return] 注册成功返回 quest_id；id 冲突（静态或动态已存在）返回空字符串
static func register_dynamic_quest(def: Dictionary) -> String:
	var qid: String = String(def.get("id", ""))
	if qid.is_empty():
		return ""
	# 不允许覆盖静态任务
	for q in QUESTS:
		if q.get("id", "") == qid:
			return ""
	# 不允许覆盖已注册的动态任务
	if _DYNAMIC_QUESTS.has(qid):
		return ""
	# 强制标记为动态 + category 缺省 commission（委托）
	var safe_def: Dictionary = def.duplicate(true)
	safe_def["is_dynamic"] = true
	if not safe_def.has("category"):
		safe_def["category"] = "commission"
	_DYNAMIC_QUESTS[qid] = safe_def
	return qid

## 注销单个动态任务（任务完成/过期时调用）
static func unregister_dynamic_quest(quest_id: String) -> void:
	_DYNAMIC_QUESTS.erase(quest_id)

## 获取所有动态任务 id（供存档/调试）
static func get_dynamic_quest_ids() -> Array:
	return _DYNAMIC_QUESTS.keys()

## 获取所有动态任务定义（供存档持久化）
static func get_all_dynamic_quest_defs() -> Array:
	var out: Array = []
	for qid in _DYNAMIC_QUESTS.keys():
		out.append((_DYNAMIC_QUESTS[qid] as Dictionary).duplicate(true))
	return out

## 清空动态任务集合（存档读取前重置，避免重复注册）
static func clear_dynamic_quests() -> void:
	_DYNAMIC_QUESTS.clear()
