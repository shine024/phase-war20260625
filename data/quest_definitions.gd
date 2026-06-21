extends RefCounted
class_name QuestDefinitions

const _QUESTS_JSON_PATH := "res://data/json/quest_definitions.json"
static var QUESTS: Array = _load_json_array(_QUESTS_JSON_PATH, LEGACY_QUESTS)

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

	# 真实者的邀请 — 第25天由真实者 NPC 对话揭示（realist_first_contact）
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
		"hidden": true,
		"prereq": "",
		"branches": {
			"join":   {"next_quest": "q_realist_join"},
			"reject": {"next_quest": "q_realist_reject"},
			"delay":  {"next_quest": "q_realist_delay"},
		},
	},
	# 分支A：加入真实者
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
		"hidden": true,
		"prereq": "q_realist_invite",
	},
	# 分支B：拒绝真实者
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
		"hidden": true,
		"prereq": "q_realist_invite",
	},
	# 分支C：拖延（中立线）
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
		"hidden": true,
		"prereq": "q_realist_invite",
	},

	# 林薇支线任务 — 第40天由林薇归来对话揭示（linwei_return）
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
		"hidden": true,
		"prereq": "",
	},

	# 扎克支线任务 — 第100天由扎克48关真相对话揭示（zack_engineer_memory）
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
		"hidden": true,
		"prereq": "",
	},
]

static func get_all() -> Array:
	var out: Array = []
	for q in QUESTS:
		out.append(q.duplicate(true))
	return out

static func get_by_id(quest_id: String) -> Dictionary:
	for q in QUESTS:
		if q.get("id", "") == quest_id:
			return q.duplicate(true)
	return {}

static func get_available_ids() -> Array:
	var arr: Array = []
	for q in QUESTS:
		arr.append(q.get("id", ""))
	return arr
