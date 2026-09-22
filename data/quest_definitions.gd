extends RefCounted
class_name QuestDefinitions

const _QUESTS_JSON_PATH := "res://data/json/quest_definitions.json"
# v7.x 性能优化：改 getter 懒加载（仿 enemy_phase_masters.gd:50-57）。
# 原 static var 初始化器在类首次被 preload 时即同步读盘解析 JSON，
# 触达 preload 链就触发 I/O。改后推迟到首次访问 QUESTS 时。
static var _quests_cache: Array = []
static var _quests_inited: bool = false
static var QUESTS: Array:
	get:
		if not _quests_inited:
			_quests_inited = true
			_quests_cache = _load_json_array(_QUESTS_JSON_PATH, LEGACY_QUESTS)
		return _quests_cache

## v6.9: 动态任务集合（运行时注册，不写入静态 QUESTS）
## 由 QuestManager.register_dynamic_quest 委托填充；get_by_id/get_available_ids 自动同时查询两个集合
## 存档由 QuestManager.save_state 持久化（保存定义 + 注册状态），读档后回填到这里
static var _DYNAMIC_QUESTS: Dictionary = {}  # quest_id -> quest_def Dictionary

# v7.x 性能：静态 QUESTS 的 id→quest 字典索引（懒构建）。
# _check_story_mission_pre_battle 对每个命中任务调 get_by_id（原线性扫描 ~80 条），
# 嵌套查找形成 O(n²)。索引让单次查询降为 O(1)。QUESTS 运行期不变，索引构建一次即可。
static var _id_index: Dictionary = {}  # quest_id -> quest_def 引用（未深拷贝）
static var _id_index_built: bool = false

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
##   - （v6.22: attack_faction/defend_faction 战争框架已退役，委托改贡献驱动三类模板）
## target:
##   - win_battles→int场次
##   - kill_enemies→int数量
##   - collect_fragments：已废弃（v3），新任务用 collect_cards
## rewards: { nano_materials; unlock_blueprint; ... }
## faction_rep 与 FactionSystemManager 贡献轴同源（读侧保留 company_rep 旧键兼容；v6.22 新写统一 faction_rep）
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
			"nano_materials": 30,
			"faction_rep": {"iron_wall_corp": 10},
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
			"nano_materials": 75,
			"faction_rep": {"iron_wall_corp": 20},
		},
	},
	{
		"id": "q_kill_20",
		"title": "歼灭敌军",
		"description": "累计击毁 20 个敌方单位。",
		"objective_type": "kill_enemies",
		"target": 20,
		"company_id": "nova_arms",
		"rewards": {
			"nano_materials": 45,
			"faction_rep": {"nova_arms": 12},
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
			"nano_materials": 120,
			"faction_rep": {"nova_arms": 20},
		},
	},
	{
		"id": "q_frag_smg",
		"title": "扩充军械库",
		"description": "拥有至少 3 种不同的战斗卡。",
		"objective_type": "collect_cards",
		"target": 3,
		"company_id": "void_research",
		"rewards": {
			"nano_materials": 60,
			"faction_rep": {"void_research": 15},
		},
	},
	{
		"id": "q_clear_5",
		"title": "突破第 5 关",
		"description": "在第 5 关取得胜利。",
		"objective_type": "clear_level",
		"target": 5,
		"company_id": "frontier_union",
		"rewards": {
			"nano_materials": 45,
			"faction_rep": {"frontier_union": 12},
		},
	},
	{
		"id": "q_clear_10",
		"title": "突破第 10 关",
		"description": "在第 10 关取得胜利。",
		"objective_type": "clear_level",
		"target": 10,
		"company_id": "frontier_union",
		"rewards": {
			"nano_materials": 90,
			"faction_rep": {"frontier_union": 20},
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
			"nano_materials": 36,
			"faction_rep": {"quantum_logistics": 10},
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
			"nano_materials": 150,
			"faction_rep": {"iron_wall_corp": 35},
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
			"nano_materials": 180,
			"faction_rep": {"nova_arms": 40},
		},
	},
	{
		"id": "q_clear_20",
		"title": "突破第 20 关",
		"description": "在第 20 关取得胜利。",
		"objective_type": "clear_level",
		"target": 20,
		"company_id": "frontier_union",
		"rewards": {
			"nano_materials": 135,
			"faction_rep": {"frontier_union": 30},
		},
	},

	# ==================== 进攻/防守任务 ====================

	{
		"id": "q_attack_void",
		"title": "铲除相位威胁",
		"description": "击败 2 个相位师盘踞的首领关卡（每时代终点关），为新星兵工肃清前进通道。",
		"objective_type": "clear_boss_count",
		"target": 2,
		"company_id": "nova_arms",
		"rewards": {
			"nano_materials": 300,
			"faction_rep": {"nova_arms": 25},
		},
	},
	{
		"id": "q_attack_nova",
		"title": "火力破袭",
		"description": "累计击毁 60 个敌方单位，为钢壁防务检验新一批装甲装备。",
		"objective_type": "kill_enemies",
		"target": 60,
		"company_id": "iron_wall_corp",
		"rewards": {
			"nano_materials": 300,
			"faction_rep": {"iron_wall_corp": 25},
		},
	},
	{
		"id": "q_attack_aether",
		"title": "协同演练",
		"description": "胜利完成 5 场战斗，与以太动力校准后勤护送节奏。",
		"objective_type": "win_battles",
		"target": 5,
		"company_id": "quantum_logistics",
		"rewards": {
			"nano_materials": 300,
			"faction_rep": {"quantum_logistics": 25},
		},
	},
	{
		"id": "q_defend_iron",
		"title": "关隘肃清",
		"description": "攻克 1 个相位师盘踞的首领关卡，帮钢壁防务回收废弃装备。",
		"objective_type": "clear_boss_count",
		"target": 1,
		"company_id": "iron_wall_corp",
		"rewards": {
			"nano_materials": 180,
			"faction_rep": {"iron_wall_corp": 30},
		},
	},
	{
		"id": "q_defend_frontier",
		"title": "商路护航",
		"description": "累计击毁 50 个敌方单位，为边境联合的运输队打开安全通道。",
		"objective_type": "kill_enemies",
		"target": 50,
		"company_id": "frontier_union",
		"rewards": {
			"nano_materials": 180,
			"faction_rep": {"frontier_union": 30},
		},
	},
	{
		"id": "q_defend_helix",
		"title": "纵深侦察",
		"description": "胜利完成 6 场战斗，为螺旋侦察带回纵深情报。",
		"objective_type": "win_battles",
		"target": 6,
		"company_id": "helix_recon",
		"rewards": {
			"nano_materials": 180,
			"faction_rep": {"helix_recon": 30},
		},
	},

	# ==================== 新增：初级任务（新手引导） ====================

	{
		"id": "q_tutorial_win_1",
		"title": "首战告捷",
		"description": "取得第一场战斗胜利。",
		"objective_type": "win_battles",
		"target": 1,
		"company_id": "iron_wall_corp",
		"rewards": {
			"nano_materials": 15,
			"faction_rep": {"iron_wall_corp": 5},
		},
	},
	{
		"id": "q_tutorial_enhance",
		"title": "战斗卡升级",
		"description": "战斗卡累计升级 3 次（上阵参战即可积累经验）。",
		"objective_type": "enhance",
		"target": 3,
		"company_id": "void_research",
		"rewards": {
			"nano_materials": 45,
			"faction_rep": {"void_research": 10},
		},
	},
	{
		"id": "q_tutorial_clear_3",
		"title": "初露锋芒",
		"description": "在第 3 关取得胜利。",
		"objective_type": "clear_level",
		"target": 3,
		"company_id": "frontier_union",
		"rewards": {
			"nano_materials": 24,
			"faction_rep": {"frontier_union": 8},
		},
	},
	{
		"id": "q_tutorial_collect_5",
		"title": "收藏家",
		"description": "拥有至少 5 种不同的战斗卡。",
		"objective_type": "collect_cards",
		"target": 5,
		"company_id": "quantum_logistics",
		"rewards": {
			"nano_materials": 30,
			"faction_rep": {"quantum_logistics": 8},
		},
	},
	# v20.31: q_tutorial_law（法则初探，objective_type=research_law）已删除——法则系统
	# 随 P2-7 整体退役，notify_law_researched 零调用方，该任务接取后永不可完成。
	# 旧存档 accepted 列表里的残留 id 由 QuestManager 的 def.is_empty() 守卫安全跳过。
	{
		"id": "q_tutorial_faction",
		"title": "组织联络",
		"description": "任一组织对你的贡献达到 1200。",
		"objective_type": "reach_reputation",
		"target": 1200,
		"company_id": "helix_recon",
		"rewards": {
			"nano_materials": 30,
			"faction_rep": {"helix_recon": 10},
		},
	},

	# ==================== 新增：战斗任务 ====================

	{
		"id": "q_battle_win_30",
		"title": "战争老手",
		"description": "累计胜利 30 场战斗。",
		"objective_type": "win_battles",
		"target": 30,
		"company_id": "iron_wall_corp",
		"rewards": {
			"nano_materials": 210,
			"faction_rep": {"iron_wall_corp": 40},
		},
	},
	{
		"id": "q_battle_win_50",
		"title": "战场传奇",
		"description": "累计胜利 50 场战斗。",
		"objective_type": "win_battles",
		"target": 50,
		"company_id": "iron_wall_corp",
		"rewards": {
			"nano_materials": 300,
			"faction_rep": {"iron_wall_corp": 60},
		},
	},
	{
		"id": "q_battle_kill_150",
		"title": "歼灭战",
		"description": "累计击毁 150 个敌方单位。",
		"objective_type": "kill_enemies",
		"target": 150,
		"company_id": "nova_arms",
		"rewards": {
			"nano_materials": 240,
			"faction_rep": {"nova_arms": 50},
		},
	},
	{
		"id": "q_battle_kill_200",
		"title": "战场肃清",
		"description": "累计击毁 200 个敌方单位。",
		"objective_type": "kill_enemies",
		"target": 200,
		"company_id": "nova_arms",
		"rewards": {
			"nano_materials": 360,
			"faction_rep": {"nova_arms": 70},
		},
	},
	{
		"id": "q_battle_clear_40",
		"title": "二战终点",
		"description": "通关第 40 关（二战时代终点）。",
		"objective_type": "clear_level",
		"target": 40,
		"company_id": "frontier_union",
		"rewards": {
			"nano_materials": 165,
			"faction_rep": {"frontier_union": 35},
		},
	},
	{
		"id": "q_battle_clear_60",
		"title": "冷战终点",
		"description": "通关第 60 关（冷战时代终点）。",
		"objective_type": "clear_level",
		"target": 60,
		"company_id": "frontier_union",
		"rewards": {
			"nano_materials": 195,
			"faction_rep": {"frontier_union": 40},
		},
	},
	{
		"id": "q_battle_clear_80",
		"title": "现代终点",
		"description": "通关第 80 关（现代时代终点）。",
		"objective_type": "clear_level",
		"target": 80,
		"company_id": "frontier_union",
		"rewards": {
			"nano_materials": 225,
			"faction_rep": {"frontier_union": 45},
		},
	},
	{
		"id": "q_battle_clear_100",
		"title": "攻克终局",
		"description": "通关第 100 关（近未来时代终点）。",
		"objective_type": "clear_level",
		"target": 100,
		"company_id": "frontier_union",
		"rewards": {
			"nano_materials": 600,
			"faction_rep": {"frontier_union": 100},
		},
	},
	{
		"id": "q_battle_boss_3",
		"title": "首领猎手",
		"description": "击败 3 个首领关卡（每时代第 20 关）。",
		"objective_type": "clear_boss_count",
		"target": 3,
		"company_id": "frontier_union",
		"rewards": {
			"nano_materials": 225,
			"faction_rep": {"frontier_union": 45},
		},
	},
	{
		"id": "q_battle_all_era",
		"title": "五时代征战",
		"description": "通关全部 5 个时代。",
		"objective_type": "clear_all_era",
		"target": 5,
		"company_id": "void_research",
		"rewards": {
			"nano_materials": 270,
			"faction_rep": {"void_research": 50},
		},
	},
	{
		"id": "q_battle_quick_win",
		"title": "速战速决",
		"description": "在 60 秒内取得一场战斗胜利。",
		"objective_type": "quick_win",
		"target": 60,
		"company_id": "nova_arms",
		"rewards": {
			"nano_materials": 120,
			"faction_rep": {"nova_arms": 25},
		},
	},

	# ==================== 新增：收集任务 ====================

	{
		"id": "q_collect_platform_10",
		"title": "扩编卡册",
		"description": "拥有 10 种不同的战斗卡。",
		"objective_type": "collect_cards",
		"target": 10,
		"company_id": "quantum_logistics",
		"rewards": {
			"nano_materials": 60,
			"faction_rep": {"quantum_logistics": 15},
		},
	},
	{
		"id": "q_collect_rare",
		"title": "稀有收藏",
		"description": "拥有 3 种稀有度以上的战斗卡。",
		"objective_type": "collect_cards",
		"target": 3,
		"card_min_rarity": "rare",
		"company_id": "void_research",
		"rewards": {
			"nano_materials": 90,
			"faction_rep": {"void_research": 20},
		},
	},
	{
		"id": "q_collect_legendary",
		"title": "传说猎手",
		"description": "拥有 1 张传说稀有度的战斗卡。",
		"objective_type": "collect_cards",
		"target": 1,
		"company_id": "void_research",
		"rewards": {
			"nano_materials": 150,
			"faction_rep": {"void_research": 35},
		},
	},
	{
		"id": "q_collect_fragments_50",
		"title": "收藏大家",
		"description": "拥有至少 50 种不同的战斗卡。",
		"objective_type": "collect_fragments",
		"target": {"total": 50},
		"company_id": "void_research",
		"rewards": {
			"nano_materials": 105,
			"faction_rep": {"void_research": 25},
		},
	},
	{
		"id": "q_collect_ww2",
		"title": "二战收藏家",
		"description": "拥有 5 种二战时代的战斗卡。",
		"objective_type": "collect_cards",
		"target": 5,
		"company_id": "iron_wall_corp",
		"rewards": {
			"nano_materials": 66,
			"faction_rep": {"iron_wall_corp": 16},
		},
	},
	{
		"id": "q_collect_modern",
		"title": "现代收藏家",
		"description": "拥有 5 种现代时代的战斗卡。",
		"objective_type": "collect_cards",
		"target": 5,
		"card_era": 3,
		"company_id": "aether_dynamics",
		"rewards": {
			"nano_materials": 84,
			"faction_rep": {"aether_dynamics": 20},
		},
	},
	{
		"id": "q_collect_future",
		"title": "未来收藏家",
		"description": "拥有 5 种近未来时代的战斗卡。",
		"objective_type": "collect_cards",
		"target": 5,
		"company_id": "void_research",
		"rewards": {
			"nano_materials": 96,
			"faction_rep": {"void_research": 22},
		},
	},

	# ==================== 新增：势力任务 ====================

	{
		"id": "q_faction_iron_30",
		"title": "钢壁盟友",
		"description": "任一组织贡献达到 2000（钢壁防务同贺）。",
		"objective_type": "reach_reputation",
		"target": 2000,
		"company_id": "iron_wall_corp",
		"rewards": {
			"nano_materials": 105,
			"faction_rep": {"iron_wall_corp": 20},
		},
	},
	{
		"id": "q_faction_nova_30",
		"title": "新星同路人",
		"description": "任一组织贡献达到 2000（新星兵工同贺）。",
		"objective_type": "reach_reputation",
		"target": 2000,
		"company_id": "nova_arms",
		"rewards": {
			"nano_materials": 105,
			"faction_rep": {"nova_arms": 20},
		},
	},
	{
		"id": "q_faction_aether_30",
		"title": "以太之友",
		"description": "任一组织贡献达到 2000（以太动力同贺）。",
		"objective_type": "reach_reputation",
		"target": 2000,
		"company_id": "aether_dynamics",
		"rewards": {
			"nano_materials": 105,
			"faction_rep": {"aether_dynamics": 20},
		},
	},
	{
		"id": "q_faction_void_30",
		"title": "虚空探索者",
		"description": "任一组织贡献达到 2000（虚空相位同贺）。",
		"objective_type": "reach_reputation",
		"target": 2000,
		"company_id": "void_research",
		"rewards": {
			"nano_materials": 105,
			"faction_rep": {"void_research": 20},
		},
	},
	{
		"id": "q_faction_all_20",
		"title": "多方认可",
		"description": "任一组织贡献达到 1500，赢得多方协作认可。",
		"objective_type": "reach_reputation",
		"target": 1500,
		"company_id": "frontier_union",
		"rewards": {
			"nano_materials": 240,
			"faction_rep": {"frontier_union": 50, "iron_wall_corp": 15, "nova_arms": 15, "aether_dynamics": 15, "void_research": 15, "quantum_logistics": 15, "helix_recon": 15},
		},
	},
	{
		"id": "q_faction_max_50",
		"title": "全域信赖",
		"description": "任一组织贡献达到 6200（激活商店全域访问）。",
		"objective_type": "reach_reputation",
		"target": 6200,
		"company_id": "quantum_logistics",
		"rewards": {
			"nano_materials": 180,
			"faction_rep": {"quantum_logistics": 35},
		},
	},
	{
		"id": "q_faction_buy_10",
		"title": "军需采买",
		"description": "在补给舱完成 10 次购买。",
		"objective_type": "buy_items",
		"target": 10,
		"company_id": "quantum_logistics",
		"rewards": {
			"nano_materials": 75,
			"faction_rep": {"quantum_logistics": 18},
		},
	},

	# ==================== 新增：挑战任务 ====================

	{
		"id": "q_challenge_all_era_boss",
		"title": "攻克全部首领",
		"description": "击败全部 5 个时代的首领关卡（每时代第 20 关）。",
		"objective_type": "clear_boss_count",
		"target": 5,
		"company_id": "frontier_union",
		"rewards": {
			"nano_materials": 450,
			"faction_rep": {"frontier_union": 80},
		},
	},
	{
		"id": "q_challenge_perfect",
		"title": "完美战役",
		"description": "在一场战斗中获得 3 星评价。",
		"objective_type": "perfect_battle",
		"target": 1,
		"company_id": "iron_wall_corp",
		"rewards": {
			"nano_materials": 180,
			"faction_rep": {"iron_wall_corp": 40},
		},
	},
	{
		"id": "q_challenge_speed",
		"title": "闪电战",
		"description": "在 30 秒内取得一场战斗胜利。",
		"objective_type": "quick_win",
		"target": 30,
		"company_id": "aether_dynamics",
		"rewards": {
			"nano_materials": 195,
			"faction_rep": {"aether_dynamics": 42},
		},
	},
	{
		"id": "q_challenge_survival",
		"title": "波次坚守",
		"description": "在一场战斗中坚守 15 个波次。",
		"objective_type": "survive_waves",
		"target": 15,
		"company_id": "iron_wall_corp",
		"rewards": {
			"nano_materials": 210,
			"faction_rep": {"iron_wall_corp": 45},
		},
	},

	# ==================== v6.2 补充：螺旋侦察势力任务（原仅2个，补齐至8个） ====================

	{
		"id": "q_faction_helix_30",
		"title": "螺旋同路：信赖",
		"description": "任一组织贡献达到 2000（螺旋侦察同贺）。",
		"objective_type": "reach_reputation",
		"target": 2000,
		"company_id": "helix_recon",
		"rewards": {
			"nano_materials": 75,
			"faction_rep": {"helix_recon": 30},
		},
	},
	{
		"id": "q_helix_scout_50",
		"title": "侦察精英",
		"description": "累计击毁 50 个敌方单位。",
		"objective_type": "kill_enemies",
		"target": 50,
		"company_id": "helix_recon",
		"rewards": {
			"nano_materials": 120,
			"faction_rep": {"helix_recon": 25},
		},
	},
	{
		"id": "q_helix_intel_5",
		"title": "情报收集",
		"description": "胜利完成 5 场战斗，为螺旋侦察系统收集前线情报。",
		"objective_type": "win_battles",
		"target": 5,
		"company_id": "helix_recon",
		"rewards": {
			"nano_materials": 105,
			"faction_rep": {"helix_recon": 20},
		},
	},
	{
		"id": "q_helix_recon_raid",
		"title": "突袭行动",
		"description": "累计击毁 100 个敌方单位。",
		"objective_type": "kill_enemies",
		"target": 100,
		"company_id": "helix_recon",
		"rewards": {
			"nano_materials": 180,
			"faction_rep": {"helix_recon": 40},
		},
	},
	{
		"id": "q_helix_speed_clear",
		"title": "闪电突进",
		"description": "快速完成 10 场战斗（每场 90 秒内结束）。",
		"objective_type": "win_battles",
		"target": 10,
		"time_limit_sec": 90,
		"company_id": "helix_recon",
		"rewards": {
			"nano_materials": 150,
			"faction_rep": {"helix_recon": 35},
		},
	},
	{
		"id": "q_helix_collect_modern",
		"title": "现代侦察装备",
		"description": "收集 5 种现代时代的战斗卡。",
		"objective_type": "collect_cards",
		"target": 5,
		"card_era": 3,
		"company_id": "helix_recon",
		"rewards": {
			"nano_materials": 135,
			"faction_rep": {"helix_recon": 30},
		},
	},
]

static func get_by_id(quest_id: String) -> Dictionary:
	# v7.x 性能：优先查静态索引（O(1)），首次调用时懒构建
	if not _id_index_built:
		_id_index.clear()
		for q in QUESTS:
			var qid: String = String(q.get("id", ""))
			if not qid.is_empty() and not _id_index.has(qid):
				_id_index[qid] = q
		_id_index_built = true
	if _id_index.has(quest_id):
		return (_id_index[quest_id] as Dictionary).duplicate(true)
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
