extends Node
## 游戏流程：战前准备 → 战斗 → 战后
const DEBUG_GAME_LOG := false
const StoryFlags := preload("res://data/story/story_flags.gd")
const QuestDefs := preload("res://data/quest_definitions.gd")  # v6.7(剧情任务): 关卡剧情查询

enum GamePhase {
	PRE_BATTLE,
	BATTLE,
	POST_BATTLE
}

# 游戏模式（v6.8: 删除剧情模式 STORY，仅保留自由模式 + 二周目）
enum GameMode {
	FREE,            ## 自由模式（自由选关 + v6.7 关卡剧情任务）
	NEW_GAME_PLUS,   ## 二周目（敌人属性×1.2）
}

# v6.6(剧情): 二周目难度配置（补剧情.txt L186: 关卡进度重置，但难度提升×1.2）
const NG_PLUS_ENEMY_MULT: float = 1.2  ## NG+ 敌人属性倍率（HP/攻击/防御）
var ng_plus_active: bool = false       ## 当前是否处于二周目（与 DayClock.total_loops > 0 同义，但独立标志便于查询）

var current_phase: GamePhase = GamePhase.PRE_BATTLE
var battle_scene: Node = null
var main_scene: Node = null
var current_level: int = 1
var last_battle_reward_summary: Dictionary = {}
var _blueprint_copies_before_battle: Dictionary = {}
var _knowledge_before_battle: Dictionary = {}
var _plm: Node = null  ## 安全引用：PhaseLawManager 本地缓存
var _cached_power_rating: int = 0  ## v6.6(剧情): 玩家战力评级缓存（补剧情.txt L41）
signal current_level_changed(level: int)

# 相位师对战相关
var _current_phase_master: Dictionary = {}  # 当前战斗的相位师配置
var _is_phase_master_battle: bool = false   # 是否在与相位师战斗
# v7.1 相位师遭遇软兜底：连续未触发计数器（≥5 则概率递增，避免长期不遇）
var _phase_master_drought_count: int = 0
# v7.1 新手保护期：前 10 关不触发随机相位师遭遇
const PHASE_MASTER_GRACE_LEVELS: int = 10

var game_mode: GameMode = GameMode.FREE

# v6.7(剧情任务): 自由模式关卡剧情任务触发状态
# 进关时收集本关所有应触发的剧情（tutorial 自动 + story 已接取），形成队列依次播放
# _story_mission_queue: 本次战斗待播放战前对话的 quest_id 列表（tutorial 在前，story 在后）
# _story_mission_played: 本关实际播放过战前对话的 quest_id（过关后用于触发对应战后对话）
var _story_mission_queue: Array = []
var _story_mission_played: Array = []
# v7.3 修复 BUG-1: 记录"本次战斗实际打的关卡号"，避免 battle_ended 时序错位。
# 原 bug：battle_ended emit 后 GameManager 先于 QuestManager 执行（autoload 顺序），
#   GameManager 在 _on_battle_ended 里 set_current_level(max_unlocked) 把 current_level 更新成下一关，
#   之后 QuestManager 读 gm.current_level 得到的是下一关号 → cleared_levels 写入错误 →
#   首次通关第N关时 target=N 的剧情任务无法完成判定。
# 修复：go_to_battle 时记录刚要打的关号，QuestManager 优先读它。
var _pending_battle_level: int = 0

# v6.6(剧情): 必败战机制 — 序章噩梦/守护者失败重试等场景
# 开启后 BattleManager 会启动倒计时，到时强制判负；玩家正常胜利路径被禁用
var _is_force_defeat_battle: bool = false   ## 当前战斗是否为必败战
var _force_defeat_duration: float = 0.0     ## 必败战持续时长（秒），到时强制判负
var _force_defeat_reason: String = ""       ## 必败战的剧情标识（如 "prologue"/"guardian_20_attempt1"）

# v6.6(剧情): 最终战标记（补剧情.txt 第十幕 第100关/相位之主/噬时者）
var _is_final_battle: bool = false          ## 当前战斗是否为最终战（触发记忆场景视觉+专属Boss）

## 检查是否遭遇相位师（基础15%概率 + 软兜底）
## v7.1 软兜底：①前 PHASE_MASTER_GRACE_LEVELS(10) 关新手保护期不触发；
##              ②连续 5 关未触发后概率递增（0.15→0.25→0.4），避免长期不遇。
## 逻辑：优先遭遇当前关卡所属势力的相位师（用于防守任务）
func check_phase_master_encounter() -> Dictionary:
	# 第49关固定为相位师战斗；其余关卡使用常量概率
	var force_phase_master_battle: bool = (current_level == 49)
	if not force_phase_master_battle:
		# v7.1 新手保护期：前 N 关不触发随机遭遇（第49关固定战不受影响）
		if current_level <= PHASE_MASTER_GRACE_LEVELS:
			_is_phase_master_battle = false
			_current_phase_master = {}
			# 仍累计 drought（保护期内未触发也算，保证出保护期后递增生效）
			_phase_master_drought_count += 1
			return {}
		# v7.1 递增保底：连续未触发次数越多，遭遇概率越高
		var cur_chance: float = GC.PHASE_MASTER_ENCOUNTER_CHANCE
		if _phase_master_drought_count >= 5:
			# 每多连续未触发 1 次，概率 +0.10，上限 0.5
			cur_chance = minf(0.5, GC.PHASE_MASTER_ENCOUNTER_CHANCE + (_phase_master_drought_count - 4) * 0.10)
		if randf() > cur_chance:
			_is_phase_master_battle = false
			_current_phase_master = {}
			_phase_master_drought_count += 1
			return {}
	if force_phase_master_battle:
		if DEBUG_GAME_LOG:
			pass  # LOG: 第49关固定触发相位师战斗

	# 获取当前关卡的势力
	var LIC = preload("res://data/level_information.gd")
	var LevelInfo = LIC.new()
	var current_faction: String = LevelInfo.get_level_faction(current_level)
	if DEBUG_GAME_LOG:
		pass  # LOG: 当前关卡势力

	# 从排行榜获取活跃相位师（按优先级尝试多条路径）
	var lp = get_node_or_null("/root/Main/PopupLayer/LeaderboardPanel")
	if lp == null:
		lp = get_node_or_null("/root/Main/LeaderboardOverlay/CenterContainer/LeaderboardPanel")
	if lp == null:
		lp = get_node_or_null("/root/Main/Margin/VBox/LeaderboardPanel")
	if lp == null:
		lp = get_node_or_null("/root/LeaderboardPanel")

	# 获取相位师数据：优先从节点获取，节点不存在时使用内嵌兜底数据
	var all_masters: Array = []
	if lp and lp.has_method("get_active_phase_masters"):
		all_masters = lp.get_active_phase_masters()
	if all_masters.is_empty():
		# 兜底：内嵌 NPC 相位师数据（与 leaderboard_panel.gd 保持同步）
		all_masters = [
			{"name": "终焉之镰",   "faction": "void_research",     "era": "future",   "platform": "platform_future_heavy"},
			{"name": "炽焰星痕",   "faction": "nova_arms",         "era": "future",   "platform": "platform_future_medium"},
			{"name": "雷霆判官",   "faction": "aether_dynamics",   "era": "cold",     "platform": "platform_cold_medium"},
			{"name": "寒霜壁垒",   "faction": "iron_wall_corp",    "era": "ww2",      "platform": "platform_ww2_heavy"},
			{"name": "量子幽灵",   "faction": "quantum_logistics", "era": "modern",   "platform": "platform_modern_medium"},
			{"name": "虚空低语",   "faction": "helix_recon",       "era": "future",   "platform": "platform_future_light"},
			{"name": "边境开拓者", "faction": "frontier_union",    "era": "ww2",      "platform": "platform_ww2_light"},
		]
		if DEBUG_GAME_LOG:
			pass  # LOG: LeaderboardPanel 节点未找到，使用内嵌相位师数据

	if not all_masters.is_empty():
		var selected_master: Dictionary = {}

		# 优先尝试抽取当前关卡势力的相位师（防守任务需要）
		if not current_faction.is_empty():
			var faction_masters: Array = []
			for master in all_masters:
				if master.get("faction", "") == current_faction:
					faction_masters.append(master)
			if not faction_masters.is_empty():
				var idx = randi() % faction_masters.size()
				selected_master = faction_masters[idx]
				if DEBUG_GAME_LOG:
					pass  # LOG: 遭遇防守方相位师

		# 如果没有找到对应势力的相位师（或没拿到），则随机抽取
		if selected_master.is_empty():
			var idx = randi() % all_masters.size()
			selected_master = all_masters[idx]
			if DEBUG_GAME_LOG:
				pass  # LOG: 遭遇随机相位师

		## 尝试从 EnemyPhaseMasters 获取完整装备数据
		var enriched_config = _enrich_master_config(selected_master)
		_current_phase_master = enriched_config
		_is_phase_master_battle = true
		# v7.1: 成功触发，重置连续未触发计数
		_phase_master_drought_count = 0
		return _current_phase_master

	_is_phase_master_battle = false
	_current_phase_master = {}
	return {}

## 获取当前战斗的相位师配置
func get_current_phase_master() -> Dictionary:
	return _current_phase_master

## 是否在和相位师战斗
func is_phase_master_battle() -> bool:
	return _is_phase_master_battle

## 将排行榜的简单相位师配置与 EnemyPhaseMasters 的完整装备数据合并
## 排行榜提供 {name, faction, era}，EnemyPhaseMasters 提供 {equipment, stats, traits, active_spells, ...}

func _ensure_plm() -> void:
	if _plm != null and is_instance_valid(_plm):
		return
	_plm = get_node_or_null("/root/PhaseLawManager")

# ═══════════════════════════════════════════════════════════════════
# v6.6(剧情): 玩家战力评级（补剧情.txt 第二/三/七/八幕的"战力N"数值锚点）
# 设计：战力 = 关卡进度主轴 + 卡牌星级加成 + 相位仪加成 + 法则加成
# 参考曲线：第1天≈2 / 第12天≈12 / 第60天≈40+ / 第100天≈162 / 第360天≈500+
# ═══════════════════════════════════════════════════════════════════

## 计算玩家当前战力评级（整数，用于剧情节点和 UI 显示）
func calculate_power_rating() -> int:
	var power: int = 0
	# 1. 关卡进度主轴：每解锁 1 关 +3 基础战力（1关≈3，100关≈300）
	var lp: Node = get_node_or_null("/root/LevelProgressManager")
	var max_level: int = 1
	if lp and lp.has_method("get_max_unlocked_level"):
		max_level = lp.get_max_unlocked_level()
	power += max_level * 3
	# 2. 卡牌战力加成：按拥有的卡牌副本数贡献（v6.11: 原 battle_star 已移除）
	if BlueprintManager and BlueprintManager.has_method("get_all_blueprint_ids_with_copies"):
		var card_map: Dictionary = BlueprintManager.get_all_blueprint_ids_with_copies()
		for card_id in card_map:
			var copies: int = int(card_map[card_id])
			power += copies
	# 3. 相位仪加成：每级相位场经验 +1
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	if pim and pim.has_method("get_phase_field_level"):
		var pf_level: int = int(pim.get_phase_field_level())
		power += pf_level * 2
	# 4. 法则加成：每解锁 1 条法则 +5
	if _plm == null:
		_ensure_plm()
	if _plm != null and "unlocked_law_ids" in _plm:
		power += int(_plm.unlocked_law_ids.size()) * 5
	_cached_power_rating = power
	return power

## 获取缓存的战力评级（不重算，供 UI 高频调用）
func get_power_rating() -> int:
	return _cached_power_rating

## 强制刷新战力缓存（战斗结束/解锁内容后调用）
func refresh_power_rating() -> void:
	_cached_power_rating = calculate_power_rating()

# ═══════════════════════════════════════════════════════════════════
# v6.6(剧情): 二周目（NG+）查询接口（补剧情.txt 第十二幕）
# ═══════════════════════════════════════════════════════════════════

## 当前是否处于二周目（敌人属性×1.2 等专属规则生效判定）
func is_ng_plus_active() -> bool:
	return ng_plus_active or game_mode == GameMode.NEW_GAME_PLUS

## 获取 NG+ 敌人属性倍率（非 NG+ 时返回 1.0）
func get_ng_plus_enemy_mult() -> float:
	return NG_PLUS_ENEMY_MULT if is_ng_plus_active() else 1.0

func _enrich_master_config(simple_config: Dictionary) -> Dictionary:
	var master_faction: String = simple_config.get("faction", "")
	var master_era: String = simple_config.get("era", "future")

	## 势力名称映射：排行榜用 7个玩家势力名，EnemyPhaseMasters 用 4个基础+混合势力
	var faction_map: Dictionary = {
		"aether_dynamics": "steel",
		"helix_recon": "thunder",
		"nova_arms": "flame",
		"iron_wall_corp": "steel",
		"void_research": "void",
		"quantum_logistics": "steel",
		"frontier_union": "thunder",
	}
	var enemy_faction: String = faction_map.get(master_faction, master_faction)

	## 从 EnemyPhaseMasters 查找匹配势力且适合当前关卡的相位师
	var EPMC = preload("res://data/enemy_phase_masters.gd")
	var candidates: Array = EPMC.get_masters_by_faction(enemy_faction)
	if candidates.is_empty():
		# 没找到匹配势力的，尝试所有相位师
		candidates = EPMC.ENEMY_MASTERS

	# 过滤掉“纯步兵相关平台”的相位师（只保留能产出 fortress/titan/raider/siege 等平台的相位师）
	var excluded_types: Array[String] = ["striker", "sniper", "stealth", "mage"]
	var allowed_candidates: Array = []
	for c in candidates:
		if not (c is Dictionary):
			continue
		var equipment: Dictionary = c.get("equipment", {})
		var platform_ids: Array = equipment.get("platforms", [])
		var has_allowed: bool = false
		for pid in platform_ids:
			var pdata: Dictionary = EnemyPhaseEquipment.get_war_platform(String(pid))
			if pdata.is_empty():
				continue
			var ptype: String = String(pdata.get("type", ""))
			if excluded_types.has(ptype):
				continue
			has_allowed = true
			break
		if has_allowed:
			allowed_candidates.append(c)
	if not allowed_candidates.is_empty():
		candidates = allowed_candidates
	else:
		# 如果该势力的相位师全部都由被剔除平台构成，则退回到全局“可用平台”相位师，避免相位师战斗空转
		var global_allowed: Array = []
		for c in EPMC.ENEMY_MASTERS:
			if not (c is Dictionary):
				continue
			var equipment: Dictionary = c.get("equipment", {})
			var platform_ids: Array = equipment.get("platforms", [])
			var has_allowed: bool = false
			for pid in platform_ids:
				var pdata: Dictionary = EnemyPhaseEquipment.get_war_platform(String(pid))
				if pdata.is_empty():
					continue
				var ptype: String = String(pdata.get("type", ""))
				if excluded_types.has(ptype):
					continue
				has_allowed = true
				break
			if has_allowed:
				global_allowed.append(c)
		if not global_allowed.is_empty():
			candidates = global_allowed

	## 按难度过滤（根据当前关卡等级）
	var era_int: int = _era_string_to_int(master_era)
	var target_level: int = clampi(
		era_int * PHASE_MASTER_ERA_TO_LEVEL_MULTIPLIER + PHASE_MASTER_ERA_TO_LEVEL_BASE,
		PHASE_MASTER_MIN_TARGET_LEVEL,
		PHASE_MASTER_MAX_TARGET_LEVEL
	)  # era 0->5, era 4->25

	## 找最接近目标等级的候选
	var best: Dictionary = {}
	var best_diff: int = 999
	for c in candidates:
		var c_level: int = int(c.get("level", 1))
		var diff: int = absi(c_level - target_level)
		if diff < best_diff:
			best_diff = diff
			best = c

	if best.is_empty():
		return simple_config

	## 合并：排行榜的基础信息 + EnemyPhaseMasters 的装备/属性/技能/特质
	var enriched: Dictionary = simple_config.duplicate(true)
	enriched["equipment"] = best.get("equipment", {})
	enriched["stats"] = best.get("stats", {})
	enriched["traits"] = best.get("traits", [])
	enriched["active_spells"] = best.get("active_spells", [])
	enriched["passive_spells"] = best.get("passive_spells", [])
	enriched["level"] = best.get("level", target_level)
	enriched["difficulty"] = best.get("difficulty", "medium")
	enriched["id"] = best.get("id", "")
	# 战场敌方相位场底座用：与排行榜「公司势力」不同，此为敌方模板 steel/flame/thunder/void
	enriched["enemy_faction"] = String(best.get("faction", enemy_faction))

	if DEBUG_GAME_LOG:
		pass  # LOG: 相位师配置已合并
	return enriched

static func _era_string_to_int(era_str: String) -> int:
	match era_str:
		"ww1": return 0
		"ww2": return 1
		"cold": return 2
		"modern": return 3
		"future", "near_future": return 4
		_: return 4

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if SignalBus:
		if not SignalBus.battle_ended.is_connected(_on_battle_ended):
			SignalBus.battle_ended.connect(_on_battle_ended)

## 战斗恒为卡牌格子战术；保留 API 供单位/UI 分支调用。
func is_card_grid_battle() -> bool:
	return true

func go_to_battle() -> void:
	if DEBUG_GAME_LOG:
		pass  # LOG: go_to_battle 被调用
	current_phase = GamePhase.BATTLE
	# v7.3 修复 BUG-1: 记录本次战斗实际打的关号（set_current_level 切关前）
	_pending_battle_level = current_level

	last_battle_reward_summary = {}
	_snapshot_battle_reward_baselines()
	# v6.7(剧情任务): 关卡剧情战前对话触发
	# 若该关有 active story quest，emit 战前对话信号，由 story_dialogue_panel 播放
	_check_story_mission_pre_battle()
	# 检查是否遭遇相位师
	check_phase_master_encounter()
	if battle_scene == null:
		push_error("battle_scene 为空，请检查 Main 是否调用了 GameManager.set_battle_scene")
		return
	if DEBUG_GAME_LOG:
		pass  # LOG: 调用 BattleManager.start_battle
	BattleManager.start_battle(battle_scene)

func _on_battle_ended(player_won: bool) -> void:
	current_phase = GamePhase.POST_BATTLE

	# v6.6(剧情): 必败战处理 — 记录 story_flag 并清理状态
	# 必败战通常 player_won=false（计时到强制判负），但即使因故 player_won=true 也走标记逻辑
	if _is_force_defeat_battle:
		var sm: Node = get_node_or_null("/root/StoryManager")
		if sm and sm.has_method("set_story_flag") and not _force_defeat_reason.is_empty():
			match _force_defeat_reason:
				"prologue":
					sm.set_story_flag(StoryFlags.PROLOGUE_COMPLETED, true)
				"guardian_20_attempt1":
					sm.set_story_flag(StoryFlags.GUARDIAN_20_ATTEMPT_1, true)
				"guardian_20_attempt2":
					sm.set_story_flag(StoryFlags.GUARDIAN_20_ATTEMPT_2, true)
				_:
					sm.set_story_flag("force_defeat_" + _force_defeat_reason, true)
			clear_force_defeat_state()
	# v6.6(剧情): 清理最终战标记（防跨战斗残留）
	clear_final_battle_state()

	# v6.11: sync_battle_stars_to_cards 调用已移除（战力星级系统②已删）

	# 获取战斗结果数据
	var victory_stars: int = 0
	var era: int = 0
	var phase_instrument_drop: Dictionary = {}
	var intel_harvest: Dictionary = {}
	if BattleManager.has_method("get_battle_result"):
		var result: Dictionary = BattleManager.get_battle_result()
		victory_stars = int(result.get("victory_stars", 0))
		era = int(result.get("era", 0))
		phase_instrument_drop = result.get("phase_instrument_drop", {}) as Dictionary
		# v7.1: 提取情报掉落（含改造图纸/进化蓝图），传给结算界面显示
		intel_harvest = result.get("intel_harvest", {}) as Dictionary

	# 处理相位师对战结果
	if _is_phase_master_battle and not _current_phase_master.is_empty():
		var master_name: String = _current_phase_master.get("name", "相位师")
		if player_won:
			_grant_phase_master_victory_reward(master_name)
		else:
			if DEBUG_GAME_LOG:
				pass  # LOG: 败给相位师
		# 清除相位师战斗状态
		_is_phase_master_battle = false
		_current_phase_master = {}

	# 记录战斗前资源
	var before_basic_nano: int = BasicResourceManager.get_total(BasicResources.ID_NANO_MATERIALS) if BasicResourceManager.has_method("get_total") else 0
	var before_energy_block: int = BasicResourceManager.get_total(BasicResources.ID_ENERGY_BLOCK) if BasicResourceManager.has_method("get_total") else 0
	var before_blueprint_nano: int = BlueprintManager.get_nano_materials() if BlueprintManager.has_method("get_nano_materials") else 0

	# 发放原有奖励
	if player_won:
		_grant_basic_resources_for_current_level()
		_grant_phase_field_xp_for_victory()
		# 攻克关卡后触发势力反应
		_apply_faction_reaction_for_conquest()

	# 计算原有奖励增益
	var after_basic_nano: int = BasicResourceManager.get_total(BasicResources.ID_NANO_MATERIALS) if BasicResourceManager.has_method("get_total") else before_basic_nano
	var after_energy_block: int = BasicResourceManager.get_total(BasicResources.ID_ENERGY_BLOCK) if BasicResourceManager.has_method("get_total") else before_energy_block
	var after_blueprint_nano: int = BlueprintManager.get_nano_materials() if BlueprintManager.has_method("get_nano_materials") else before_blueprint_nano

	# ========== 掉落系统由 BattleManager.end_battle 直接触发，此处不重复调用 ==========
	# BattleManager._generate_battle_completion_drops 已在 end_battle 时执行
	if DEBUG_GAME_LOG:
		pass  # LOG: DropManager 已就绪，掉落由 BattleManager 负责生成

	# ========== 新增：更新关卡进度 ==========
	if player_won:
		ManagerLazyLoader.ensure_loaded("level_progress")
		var level_progress: Node = get_node_or_null("/root/LevelProgressManager")
		if level_progress and level_progress.has_method("complete_level"):
			level_progress.complete_level(current_level, victory_stars)
			if DEBUG_GAME_LOG:
				pass  # LOG: 关卡进度已更新
			# v7.x 修复 B3：记录关卡进度成就统计（progress 类成就，如 max_level/perfect_levels）
			var _am_evo = get_node_or_null("/root/AchievementManager")
			if _am_evo and _am_evo.has_method("record_level_progress"):
				_am_evo.record_level_progress(current_level, victory_stars)
		# 与已解锁关卡的「最前沿」对齐，否则 save.json 里 game.current_level 会永远停在 1（读档像没进度）
		if level_progress and level_progress.has_method("get_max_unlocked_level"):
			set_current_level(level_progress.get_max_unlocked_level())
		# v6.7(剧情任务): 自由模式关卡剧情战后对话触发（在关卡进度更新后，任务进度已刷新）
		# 用 _story_mission_pending_level 记录刚通关的关卡号，避免 set_current_level 切换后丢失
		_check_story_mission_post_battle()

	# v6.6: 接线排行榜 — 战斗结束时更新统计（之前 update_* 方法零调用，排行榜永远为空）
	ManagerLazyLoader.ensure_loaded("leaderboard")
	var lb: Node = get_node_or_null("/root/LeaderboardManager")
	if lb != null and lb.has_method("update_battle_stats"):
		var elapsed_sec: float = 0.0
		if BattleManager and "battle_elapsed_time" in BattleManager:
			elapsed_sec = float(BattleManager.battle_elapsed_time)
		var dmg: int = 0
		if last_battle_reward_summary.has("total_damage_dealt"):
			dmg = int(last_battle_reward_summary["total_damage_dealt"])
		lb.update_battle_stats(player_won, dmg, elapsed_sec)
	if lb != null and lb.has_method("update_level_progress") and player_won:
		lb.update_level_progress(current_level, victory_stars)
	if lb != null and lb.has_method("update_blueprint_count") and BlueprintManager:
		var bp_count: int = 0
		if BlueprintManager.has_method("get_unlocked_blueprint_count"):
			bp_count = BlueprintManager.get_unlocked_blueprint_count()
		elif "blueprint_stars" in BlueprintManager:
			bp_count = (BlueprintManager.blueprint_stars as Dictionary).size()
		lb.update_blueprint_count(bp_count)

	# 保存战斗奖励摘要
	last_battle_reward_summary = {
		"player_won": player_won,
		"basic_nano_gain": max(0, after_basic_nano - before_basic_nano),
		"energy_block_gain": max(0, after_energy_block - before_energy_block),
		"nano_material_gain": max(0, after_blueprint_nano - before_blueprint_nano),
		"victory_stars": victory_stars,
		"era": era,
		"phase_instrument_drop": phase_instrument_drop.duplicate(true),
		"intel_harvest": intel_harvest.duplicate(true) if not intel_harvest.is_empty() else {},
	}
	var battle_fragment_gain: Dictionary = _calculate_blueprint_fragment_gain()
	var battle_knowledge_gain: Dictionary = _calculate_knowledge_gain()
	last_battle_reward_summary["fragment_gain_total"] = int(battle_fragment_gain.get("total", 0))
	last_battle_reward_summary["fragment_gain_items"] = battle_fragment_gain.get("items", [])
	last_battle_reward_summary["knowledge_gain_total"] = int(battle_knowledge_gain.get("total", 0))
	last_battle_reward_summary["knowledge_gain_items"] = battle_knowledge_gain.get("items", [])
	var recon_bonus: float = _get_recon_fragment_bonus_multiplier()
	last_battle_reward_summary["recon_fragment_bonus_percent"] = int(round(recon_bonus * 100.0))
	last_battle_reward_summary["recon_fragment_multiplier"] = 1.0 + recon_bonus

	# HUD 重构：结算入口由主场景 `show_battle_result` 弹出 battle_result_dialog（OK 时 claim_drops）。
	# 若主场景未实现该方法（历史场景/测试），胜利后须仍领取 DropManager 待领掉落，否则会永久卡在 pending。
	#
	# v6.6(挂机): 挂机模式下跳过结算弹窗，自动领取掉落 + 重置到 PRE_BATTLE，
	# 让 AFKModeManager 的 call_deferred 下一关启动时战场已清理、phase 已重置。
	# 必须在 claim_drops() 之前调用 accumulate_pending_drops()，把掉落计入累计奖励总账。
	if _is_afk_running():
		# AFKModeManager 是 RefCounted（非 Node），故 afk_mgr 用 Variant 不标 Node 类型。
		var afk_mgr = main_scene._afk_manager if (main_scene != null and "_afk_manager" in main_scene) else null
		if afk_mgr != null and afk_mgr.has_method("accumulate_pending_drops"):
			afk_mgr.accumulate_pending_drops()
		var dm_afk: Node = get_node_or_null("/root/DropManager")
		if dm_afk != null and dm_afk.has_method("claim_drops"):
			dm_afk.claim_drops()
		return_to_prep()
	elif main_scene and main_scene.has_method("show_battle_result"):
		# v7.x 性能：延迟到下一帧再构建结算面板。
		# 根因：_on_battle_ended 是 battle_ended 信号第一个监听者，原在其回调栈内同步
		# instantiate BattleResultDialog + 构建 UI（掉落列表逐行 Label.new() +
		# IntelHarvestDisplay 按击败敌人数建节点 + 海量 theme override），与后续 8+ 监听者
		# （Audio/Faction/Quest/Achievement/SaveManager/HUD...）挤同一帧，渲染线程要等整条链
		# 结束才能画下一帧——这是"面板出来前卡一下"的主因。
		# call_deferred 让奖励计算先在本帧完成，剩余监听者处理完，渲染一帧（玩家看到胜利瞬间），
		# 再在下一帧构建面板并淡入。reward_summary 已在上方 488-506 组装完毕，延迟安全。
		main_scene.call_deferred("show_battle_result", player_won)
	elif player_won:
		var dm_fallback: Node = get_node_or_null("/root/DropManager")
		if dm_fallback != null and dm_fallback.has_method("get_pending_drops_count") and dm_fallback.has_method("claim_drops"):
			if dm_fallback.get_pending_drops_count() > 0:
				dm_fallback.claim_drops()

func set_battle_scene(node: Node) -> void:
	battle_scene = node

func set_main_scene(node: Node) -> void:
	main_scene = node

func set_current_level(level: int) -> void:
	var new_level: int = max(1, level)
	if current_level == new_level:
		return
	current_level = new_level
	if DEBUG_GAME_LOG:
		pass  # LOG: 当前关卡设为
	_ensure_plm()
	if _plm and _plm.has_method("update_env_for_level"):
		_plm.update_env_for_level(current_level)
	current_level_changed.emit(current_level)
	# v6.9: 进入势力领地关卡时，刷新该势力的动态委托
	_maybe_refresh_faction_quests_for_level(current_level)

## v6.9: 若当前关卡属于某势力领地（21关起），刷新该势力的动态委托
func _maybe_refresh_faction_quests_for_level(level: int) -> void:
	var qm: Node = get_node_or_null("/root/QuestManager")
	if qm == null or not qm.has_method("refresh_faction_quests"):
		return
	var LevelInfo = preload("res://data/level_information.gd").new()
	var faction_id: String = LevelInfo.get_level_faction(level)
	if faction_id.is_empty():
		return  # 1-20关无主之地，不生成动态任务
	qm.refresh_faction_quests(faction_id)

## 攻克关卡后触发势力反应
func _apply_faction_reaction_for_conquest() -> void:
	ManagerLazyLoader.ensure_loaded("faction")
	var fsm: Node = get_node_or_null("/root/FactionSystemManager")
	if fsm and fsm.has_method("on_level_conquered"):
		var faction_result: Dictionary = fsm.on_level_conquered(current_level)
		if DEBUG_GAME_LOG:
			pass  # LOG: 势力反应完成

## 相位师战胜奖励
func _grant_phase_master_victory_reward(master_name: String) -> void:
	if DEBUG_GAME_LOG:
		pass  # LOG: 战胜相位师

	var fsm: Node = get_node_or_null("/root/FactionSystemManager")
	var era_pm: int = GC.get_era_for_level(current_level)

	# 1. v6.4: Boss 掉落表（300-500纳米 + 专属许可 + 额外材料），替换原固定 +50 纳米
	var boss_id: String = String(_current_phase_master.get("faction", master_name.to_lower()))
	var _drop_tables_inst = DropTables.new()
	var boss_drops: Array = _drop_tables_inst.generate_boss_drops(era_pm, boss_id)
	var extra_nano_total: int = 0
	var extra_energy_total: int = 0
	for drop in boss_drops:
		if drop == null or not (drop is DropTables.DropResult):
			continue
		var res: DropTables.DropResult = drop
		match res.drop.type:
			DropTables.DropType.MATERIAL:
				# v7.3: 许可证资源系统已删除。permit_card_*（特殊卡掉落，原降级为通用许可）改为等价纳米材料补偿。
				# permit_general/permit_type_* 已从掉落表移除，不会进入此分支。
				if res.drop.item_id.begins_with("permit_"):
					if BasicResourceManager.has_method("add_resource"):
						BasicResourceManager.add_resource(BasicResources.ID_NANO_MATERIALS, res.count * 50)
						extra_nano_total += res.count * 50
				else:
					# 材料类：直接加资源（item_id 与 BasicResources ID 字符串一致）
					if BasicResourceManager.has_method("add_resource"):
						BasicResourceManager.add_resource(res.drop.item_id, res.count)
						if res.drop.item_id == "nano_materials":
							extra_nano_total += res.count
						elif res.drop.item_id == "energy_block":
							extra_energy_total += res.count
			DropTables.DropType.CARD_DATA, DropTables.DropType.BLUEPRINT_FRAGMENT:
				# Boss 卡牌数据 → 成品卡发放
				if not res.drop.item_id.is_empty() and BlueprintManager:
					CardDropGrants.grant_enemy_style_card(BlueprintManager, res.drop.item_id, era_pm, 2)
			DropTables.DropType.STAT_BOOST:
				# v7.x 修复：Boss/相位师的属性提升掉落此前被静默丢弃（match 缺此分支）。
				# 现 lazy-load StatBoostManager 并应用 boost（与 DropManager._apply_stat_boost 同口径）。
				if not res.drop.item_id.is_empty():
					ManagerLazyLoader.ensure_loaded("stat_boost")
					var sbm = get_node_or_null("/root/StatBoostManager")
					if sbm and sbm.has_method("apply_boost"):
						sbm.apply_boost(res.drop.item_id)

	# 2. v6.4: 固定 +10 能量块已由 Boss 掉落表（boss_drops 含 energy_block）提供，此处移除避免重复

	# 3. 敌方装备 → 背包缴获卡（无武器版：仅战斗平台）
	if BlueprintManager:
		var equipment: Dictionary = _current_phase_master.get("equipment", {})
		## 战斗平台碎片
		var platforms: Array = equipment.get("platforms", [])
		var excluded_types: Array[String] = ["striker", "sniper", "stealth", "mage"]
		for pid in platforms:
			var pdata: Dictionary = EnemyPhaseEquipment.get_war_platform(pid)
			var ptype: String = String(pdata.get("type", ""))
			if excluded_types.has(ptype):
				continue
			var pname: String = pdata.get("name", pid)
			CardDropGrants.grant_enemy_style_card(BlueprintManager, String(pid), era_pm, 2)
			if DEBUG_GAME_LOG:
				pass  # LOG: 平台卡奖励
	# 4. v6.2: 相位大师击败 → 符文掉落（替代废弃的法则卡奖励）
	# 原逻辑：从势力法则家族随机选3条法则卡 → 已废弃
	# v6.14 改进：优先从相位师"自带符文"池抽取（装什么掉什么），池空才回退 generic 池。
	# 仍保留：必掉1稀有，30%额外史诗，5%传说。
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	if pim and pim.has_method("add_owned_rune"):
		var RuneDefs = preload("res://data/runes.gd")
		# v6.14: 取相位师自带符文池（enriched equipment 的 runes）
		var _master_runes_pool: Array = []
		var _pm_id: String = String(_current_phase_master.get("id", ""))
		if not _pm_id.is_empty():
			var EnemyPhaseMasters = preload("res://data/enemy_phase_masters.gd")
			var _enriched_eq: Dictionary = EnemyPhaseMasters.get_enriched_equipment(_pm_id)
			_master_runes_pool = _enriched_eq.get("runes", [])
		# 必掉稀有符文（优先 master 自带池）
		var _granted_rune: String = _pick_rune_from_pool_or_generic(_master_runes_pool, RuneDefs, RuneDefs.RARITY_RARE)
		if not _granted_rune.is_empty():
			pim.add_owned_rune(_granted_rune)
		# 30%概率额外掉史诗符文
		if randf() < 0.30:
			var _granted_e: String = _pick_rune_from_pool_or_generic(_master_runes_pool, RuneDefs, RuneDefs.RARITY_EPIC)
			if not _granted_e.is_empty():
				pim.add_owned_rune(_granted_e)
		# 5%概率掉传说符文（极稀有）
		if randf() < 0.05:
			var _granted_l: String = _pick_rune_from_pool_or_generic(_master_runes_pool, RuneDefs, RuneDefs.RARITY_LEGENDARY)
			if not _granted_l.is_empty():
				pim.add_owned_rune(_granted_l)

	# v6.14: 相位师击败 → 改造蓝图掉落（此前相位师无保底改造掉落，只有通用击杀概率）。
	# 必掉1个改造蓝图（按相位师星级决定稀有度梯度），30%概率额外1个。
	# v7.x: 改用 MasterPowerEvaluator 星级映射 Tier（替代原 level*40 的 ad-hoc 换算），
	#       让掉落真正跟随相位师战力——高战力相位师掉高稀有度改造。
	var IntelManualItems = preload("res://data/intel_manual_items.gd")
	var _MPE = preload("res://scripts/master_power_evaluator.gd")
	var _PT = preload("res://data/power_tiers.gd")
	var _stars: int = int(_MPE.evaluate(_current_phase_master).get("stars", 3))
	var _drop_bag: Node = get_node_or_null("/root/IntelItemBag")
	var _pm_enemy_type: String = "infantry"  # 相位师无单一敌人类型，用通用兜底
	var _pm_power_tier: int = _PT.get_tier_by_stars(_stars)
	# 必掉
	var _mod_drop: Dictionary = IntelManualItems.roll_random_mod_blueprint(_pm_enemy_type, "boss", _pm_power_tier)
	if not _mod_drop.is_empty() and _drop_bag and _drop_bag.has_method("add_item"):
		_drop_bag.add_item(String(_mod_drop.get("item_type", "")), 1)
	# 30% 额外
	if randf() < 0.30:
		var _mod_drop2: Dictionary = IntelManualItems.roll_random_mod_blueprint(_pm_enemy_type, "boss", _pm_power_tier)
		if not _mod_drop2.is_empty() and _drop_bag and _drop_bag.has_method("add_item"):
			_drop_bag.add_item(String(_mod_drop2.get("item_type", "")), 1)

	# 5. 势力声望提升（战胜相位师，该势力获得声望）
	var faction_id: String = ""
	if fsm and fsm.has_method("add_faction_reputation"):
		faction_id = _current_phase_master.get("faction", "")
		if not faction_id.is_empty():
			fsm.add_faction_reputation(faction_id, 30)

	# 6. 检查并完成任务委托（进攻/防守任务）
	ManagerLazyLoader.ensure_loaded("quest")
	var qm: Node = get_node_or_null("/root/QuestManager")
	if qm and qm.has_method("notify_phase_master_defeated"):
		qm.notify_phase_master_defeated(master_name)

	if not faction_id.is_empty() and DEBUG_GAME_LOG:
		pass  # LOG: 势力声望 +30

	# 记录到战斗奖励摘要（v6.4: 使用 Boss 掉落表实际累计值，而非固定 50/10）
	last_battle_reward_summary["phase_master_victory"] = master_name
	last_battle_reward_summary["extra_nano"] = extra_nano_total if extra_nano_total > 0 else 50
	last_battle_reward_summary["extra_energy"] = extra_energy_total if extra_energy_total > 0 else 10

## v6.14: 从相位师自带符文池抽取，池空或不含目标稀有度时回退 generic 池。
## [param master_runes_pool] 相位师自带符文 id 列表（可能含各稀有度）
## [param rune_defs] RuneDefinitions 类引用
## [param target_rarity] 期望的稀有度（rare/epic/legendary）
## [return] 符文 id 字符串，无可用则返回 ""
func _pick_rune_from_pool_or_generic(master_runes_pool: Array, rune_defs, target_rarity: String) -> String:
	# 先尝试从 master 自带池筛目标稀有度的符文
	if not master_runes_pool.is_empty():
		var matched: Array = []
		for rid in master_runes_pool:
			var rd: Dictionary = rune_defs.get_rune(String(rid))
			if not rd.is_empty() and String(rd.get("rarity", "")) == target_rarity:
				matched.append(String(rid))
		if not matched.is_empty():
			return String(matched[randi() % matched.size()])
		# 自带池无目标稀有度，但有其他符文：50% 概率直接抽一个自带符文（装什么掉什么，即便稀有度不符）
		if randf() < 0.50:
			return String(master_runes_pool[randi() % master_runes_pool.size()])
	# 回退 generic 池（按目标稀有度）
	var pool: Array[Dictionary] = rune_defs.get_runes_by_rarity(target_rarity)
	var generic: Array[Dictionary] = []
	for r in pool:
		if r.get("faction_id", "") == rune_defs.FACTION_GENERIC:
			generic.append(r)
	if not generic.is_empty():
		return String(generic[randi() % generic.size()]["id"])
	return ""

## 敌方势力 -> 法则家族映射
static func _get_law_families_for_faction(enemy_faction: String) -> Array:
	match enemy_faction:
		"steel": return ["STEEL"]
		"flame": return ["FLAME"]
		"thunder": return ["THUNDER"]
		"void": return ["VOID"]
		"steel_flame": return ["STEEL", "FLAME"]
		"thunder_steel": return ["THUNDER", "STEEL"]
		"void_flame": return ["VOID", "FLAME"]
		"steel_thunder": return ["STEEL", "THUNDER"]
		"flame_void": return ["FLAME", "VOID"]
		"all": return ["STEEL", "FLAME", "THUNDER", "VOID"]
		_: return ["STEEL"]

## 根据法则家族获取所有法则ID
static func _get_law_ids_for_families(families: Array) -> Array:
	var result: Array = []
	var all_ids: Array = PhaseLaws.get_all_ids()
	for lid in all_ids:
		var family: String = PhaseLaws.get_family(String(lid))
		if family in families:
			result.append(lid)
	return result

func return_to_prep() -> void:
	current_phase = GamePhase.PRE_BATTLE
	# 保持相位仪槽位（平台/武器/法则/能量）不卸下；仅把槽位同步回 PhaseLawManager，避免战后装配列表为空导致法则无法施放
	if PhaseInstrumentManager and PhaseInstrumentManager.has_method("sync_law_cards_to_phase_law_manager"):
		PhaseInstrumentManager.sync_law_cards_to_phase_law_manager()
	if SignalBus:
		SignalBus.backpack_changed.emit()

## v6.6(挂机): 判断挂机是否正在运行（用于跳过结算弹窗等门控）。
## 防御性判空：main_scene 或 _afk_manager 不存在时返回 false，走正常流程。
func _is_afk_running() -> bool:
	if main_scene == null or not ("_afk_manager" in main_scene):
		return false
	var afk_mgr = main_scene._afk_manager
	if afk_mgr == null or not ("is_running" in afk_mgr):
		return false
	return bool(afk_mgr.is_running)

const LevelEras = preload("res://data/level_eras.gd")
const GC = preload("res://resources/game_constants.gd")
const RECON_FRAGMENT_BONUS_PER_PLATFORM: float = 0.20
const RECON_FRAGMENT_BONUS_CAP: float = 0.80

## 相位师难度计算常量
const PHASE_MASTER_ERA_TO_LEVEL_BASE: int = 5
const PHASE_MASTER_ERA_TO_LEVEL_MULTIPLIER: int = 5
const PHASE_MASTER_MIN_TARGET_LEVEL: int = 5
const PHASE_MASTER_MAX_TARGET_LEVEL: int = 30

func get_era(level: int) -> int:
	# 使用统一的时代划分逻辑
	return GC.get_era_for_level(level)

func get_enemy_wave_total_for_level(level: int) -> int:
	return LevelEras.get_wave_total_for_level(max(1, level))

func get_enemy_wave_interval_for_level(level: int) -> float:
	return LevelEras.get_wave_interval_for_level(max(1, level))

func get_enemy_spawn_count_for_wave(level: int, wave_index: int) -> int:
	return LevelEras.get_spawn_count_for_wave(max(1, level), wave_index)


func get_enemy_spawn_count_for_wave_card_grid(level: int, wave_index: int) -> int:
	return LevelEras.get_spawn_count_for_wave_card_grid(max(1, level), wave_index)

func get_drop_rate_multiplier(level: int) -> float:
	return LevelEras.get_drop_rate_multiplier(max(1, level))

const BasicResources = preload("res://data/basic_resources.gd")
const EnemyPhaseEquipment = preload("res://data/enemy_phase_equipment.gd")
const PhaseLaws = preload("res://data/phase_laws.gd")
const CardDropGrants = preload("res://scripts/card_drop_grants.gd")

func _grant_basic_resources_for_current_level() -> void:
	var drops: Dictionary = BasicResources.get_drops_for_level(current_level)
	# v6.2: 符文之语资源产出加成
	var yield_mult: float = 1.0 + _get_rune_special_bonus("on_resource_yield")
	if BasicResourceManager and BasicResourceManager.has_method("add_resource"):
		for id in drops.keys():
			var amount: int = int(float(drops[id]) * yield_mult)
			if amount > 0:
				BasicResourceManager.add_resource(String(id), amount)
	# 战后额外：纳米材料（用于解析蓝图）
	if BlueprintManager and BlueprintManager.has_method("add_nano_materials"):
		var nano_bonus: int = 10 + current_level * 3 + int(pow(float(current_level), 1.15))  # 经济平衡：指数增长
		nano_bonus = int(float(nano_bonus) * yield_mult)  # v6.2: 资源产出加成
		BlueprintManager.add_nano_materials(nano_bonus)
	return


func _get_recon_fragment_bonus_multiplier() -> float:
	if not PhaseInstrumentManager or not PhaseInstrumentManager.has_method("get_loadouts"):
		return 0.0
	var loadouts: Array = PhaseInstrumentManager.get_loadouts()
	var slot_card_ids: Array = []
	if PhaseInstrumentManager.has_method("get_slot_card_ids"):
		slot_card_ids = PhaseInstrumentManager.get_slot_card_ids()
	var recon_platforms: int = 0
	var platform_types_seen: Array = []
	for l_raw in loadouts:
		if not (l_raw is Dictionary):
			continue
		var loadout: Dictionary = l_raw
		var platform: CardResource = loadout.get("platform", null)
		if platform == null:
			continue
		platform_types_seen.append(int(platform.platform_type))
		# v6.6: 侦察单位识别——旧 platform_type 检查 + card_id 命名匹配
		var is_recon := false
		if platform.platform_type == 5 or platform.platform_type == 10:
			is_recon = true
		elif "scout" in platform.card_id.to_lower() or "recon" in platform.card_id.to_lower() \
			or "stealth" in platform.card_id.to_lower() or "spectre" in platform.card_id.to_lower() \
			or "drone" in platform.card_id.to_lower():
			is_recon = true
		if is_recon:
			recon_platforms += 1
	var bonus: float = minf(RECON_FRAGMENT_BONUS_CAP, float(recon_platforms) * RECON_FRAGMENT_BONUS_PER_PLATFORM)
	return bonus

func _grant_phase_field_xp_for_victory() -> void:
	if not PhaseInstrumentManager:
		return
	if not PhaseInstrumentManager.has_method("grant_phase_field_xp"):
		return
	var total_xp: int = LevelEras.get_base_xp_for_level(current_level)
	# v6.2: 符文之语探索奖励加成
	total_xp = int(float(total_xp) * (1.0 + _get_rune_special_bonus("on_explore_bonus")))
	PhaseInstrumentManager.grant_phase_field_xp("battle_victory", total_xp)

## v6.2: 获取符文之语结算类特殊效果的加成比例（0.0-1.0+）
## 支持：on_explore_bonus（探索奖励）、on_resource_yield（资源产出）
func _get_rune_special_bonus(special_type: String) -> float:
	if not PhaseInstrumentManager or not PhaseInstrumentManager.has_method("get_rune_bonus"):
		return 0.0
	var bonus: Dictionary = PhaseInstrumentManager.get_rune_bonus()
	var specials: Array = bonus.get("specials", [])
	var total: float = 0.0
	for sp in specials:
		if sp is Dictionary and sp.get("special", "") == special_type:
			total += float(sp.get("value", 0)) / 100.0
	return total

func _snapshot_battle_reward_baselines() -> void:
	_blueprint_copies_before_battle.clear()
	_knowledge_before_battle.clear()
	_ensure_plm()
	if _plm and _plm.has_method("get_knowledge_snapshot"):
		_knowledge_before_battle = _plm.get_knowledge_snapshot()
	if BlueprintManager and BlueprintManager.has_method("get_all_blueprint_ids"):
		for id_raw in BlueprintManager.get_all_blueprint_ids():
			var card_id: String = String(id_raw)
			_blueprint_copies_before_battle[card_id] = int(BlueprintManager.get_blueprint_copies(card_id))

func _calculate_blueprint_fragment_gain() -> Dictionary:
	var total_gain: int = 0
	var items: Array = []
	if not BlueprintManager or not BlueprintManager.has_method("get_all_blueprint_ids"):
		return {"total": 0, "items": []}
	for id_raw in BlueprintManager.get_all_blueprint_ids():
		var card_id: String = String(id_raw)
		var before_count: int = int(_blueprint_copies_before_battle.get(card_id, 0))
		var after_count: int = int(BlueprintManager.get_blueprint_copies(card_id))
		var gain: int = after_count - before_count
		if gain > 0:
			total_gain += gain
			items.append({"id": card_id, "gain": gain})
	return {"total": total_gain, "items": items}

func _calculate_knowledge_gain() -> Dictionary:
	var total_gain: int = 0
	var items: Array = []
	_ensure_plm()
	if not _plm or not _plm.has_method("get_knowledge_snapshot"):
		return {"total": 0, "items": []}
	var after: Dictionary = _plm.get_knowledge_snapshot()
	for key in _plm.KNOWLEDGE_KEYS:
		var before_val: int = int(_knowledge_before_battle.get(key, 0))
		var after_val: int = int(after.get(key, 0))
		var gain: int = after_val - before_val
		if gain > 0:
			total_gain += gain
			items.append({"id": key, "gain": gain})
	return {"total": total_gain, "items": items}


# ═══════════════════════════════════════════════════════════════════
# v6.6(剧情): 必败战机制 — docs/补剧情.txt 序章噩梦/守护者失败重试
# ═══════════════════════════════════════════════════════════════════

## 启动一场必败战（到时长后强制判负，玩家无法正常获胜）
## duration_sec: 必败战持续秒数（玩家需"撑过"这段时间，如序章撑7分钟=420秒）
## level_override: 使用的关卡编号（决定敌人 era 和难度）
## reason: 剧情标识（如 "prologue"/"guardian_20_attempt1"），用于战结束后记录 story_flag
func start_force_defeat_battle(duration_sec: float, level_override: int, reason: String = "") -> void:
	_is_force_defeat_battle = true
	_force_defeat_duration = maxf(10.0, duration_sec)  # 至少10秒，防止误传0
	_force_defeat_reason = reason
	# 确保不是相位师战（必败战走普通波次流，让敌人持续刷出）
	_is_phase_master_battle = false
	_current_phase_master = {}
	set_current_level(clampi(level_override, 1, 100))
	go_to_battle()

## 启动序章噩梦必败战（docs/补剧情.txt 序章：陈末梦境中的一战虫群入侵）
## 默认撑7分钟（420秒）后强制判负，关卡使用第1关（一战）
func start_prologue_battle(duration_sec: float = 420.0) -> void:
	start_force_defeat_battle(duration_sec, 1, "prologue")

## 查询当前是否为必败战
func is_force_defeat_battle() -> bool:
	return _is_force_defeat_battle

## 获取必败战剩余时长（BattleManager 读取）
func get_force_defeat_duration() -> float:
	return _force_defeat_duration

## 获取必败战剧情标识
func get_force_defeat_reason() -> String:
	return _force_defeat_reason

## 清除必败战状态（BattleManager.end_battle 末尾调用，防跨战斗残留）
func clear_force_defeat_state() -> void:
	_is_force_defeat_battle = false
	_force_defeat_duration = 0.0
	_force_defeat_reason = ""


# ═══════════════════════════════════════════════════════════════════
# v6.6(剧情): 最终战机制（补剧情.txt 第十幕 第100关/相位之主）
# ═══════════════════════════════════════════════════════════════════

## 设置最终战标记（city_map 第100关节点触发时调用）
## 触发 Battlefield.gd 的记忆场景视觉 + 专属Boss配置
func set_final_battle(enabled: bool = true) -> void:
	_is_final_battle = enabled

## 当前是否为最终战
func is_final_battle() -> bool:
	return _is_final_battle

## 清除最终战状态（end_battle 时调用防残留）
func clear_final_battle_state() -> void:
		_is_final_battle = false


# ════════════════════════════════════════════════════════════════════
# v6.7(剧情任务): 自由模式关卡剧情任务触发（docs/补剧情.txt 关卡映射）
# ════════════════════════════════════════════════════════════════════

## 进关前检查：收集本关所有应触发的剧情任务，依次 emit 战前对话信号
## tutorial 类：自动触发（无需接取），用 StoryManager 标记防重复，每个只播一次
## story 类：只查已接取、未完成的任务
## 同关多剧情：tutorial 先于 story，依次入队，由 story_dialogue_panel 队列播放
func _check_story_mission_pre_battle() -> void:
	_story_mission_queue.clear()
	_story_mission_played.clear()
	var quests_at_level: Array = QuestDefs.get_all_triggerable_at_level(current_level)
	if quests_at_level.is_empty():
		return
	# 分离 tutorial 和 story
	var tutorial_ids: Array = []
	var story_ids: Array = []
	var qm: Node = get_node_or_null("/root/QuestManager")
	for q in quests_at_level:
		var qid: String = q.get("id", "")
		var cat: String = q.get("category", "commission")
		if cat == "tutorial":
			# tutorial：未触发过的才入队
			if not _is_tutorial_triggered(qid):
				tutorial_ids.append(qid)
		elif cat == "story":
			# v6.7: 进关时自动揭示该关的 story 任务（让玩家在面板看到并接取）
			# 自由模式无 city_map/NPC，NPC 支线任务必须靠关卡触发才能揭示
			if qm and qm.has_method("reveal_quest"):
				qm.reveal_quest(qid)
			# v7.3 修复 BUG-3.5: 主线 story 任务首次进关时自动接取（让战前对话能播放）。
			# 原 bug：story 任务进关只 reveal（揭示≠接取），_is_story_quest_active 要求已接取，
			# 导致玩家首次进入触发关时任务未接取 → 战前对话不播放，主线剧情演出缺失。
			# 修复：对有 pre_battle_dialogues 的 story 任务，已揭示且未接取则自动接取（仅当 is_quest_available）。
			if not q.get("pre_battle_dialogues", []).is_empty():
				if qm and qm.has_method("is_accepted") and not qm.is_accepted(qid):
					if qm.has_method("is_quest_available") and qm.is_quest_available(qid):
						if qm.has_method("accept_quest"):
							qm.accept_quest(qid)
				# 只有已接取、未完成、且有战前对话的才入播放队列
				if _is_story_quest_active(qid):
					story_ids.append(qid)
	# tutorial 在前，story 在后
	_story_mission_queue = tutorial_ids + story_ids
	if _story_mission_queue.is_empty():
		return
	# tutorial 任务：立即标记已触发（防重播）+ 发放一次性奖励
	for qid in tutorial_ids:
		_mark_tutorial_triggered(qid)
		_grant_tutorial_reward(qid)
	# 依次 emit（story_dialogue_panel 监听后排队播放）
	for qid in _story_mission_queue:
		if SignalBus and SignalBus.has_signal("story_mission_dialogue"):
			SignalBus.story_mission_dialogue.emit(qid, "pre")

## v6.7(剧情任务): 发放 tutorial 引导奖励（一次性纳米材料）
func _grant_tutorial_reward(quest_id: String) -> void:
	var def: Dictionary = QuestDefs.get_by_id(quest_id)
	if def.is_empty():
		return
	var rewards: Dictionary = def.get("rewards", {})
	var nano: int = int(rewards.get("nano_materials", 0))
	if nano > 0 and BasicResourceManager and BasicResourceManager.has_method("add_resource"):
		BasicResourceManager.add_resource("nano_materials", nano)

## 过关后检查：对本关已接取的 story 任务，emit 战后对话信号
## tutorial 无战后对话（引导只在战前）；story 有战前+战后
func _check_story_mission_post_battle() -> void:
	# 注意：此时 current_level 可能已被 set_current_level 切换，用 _story_mission_queue 里记录的 story 任务
	for qid in _story_mission_queue:
		var def: Dictionary = QuestDefs.get_by_id(qid)
		if def.is_empty():
			continue
		# 只对 story 类（有 post_battle_dialogues 的）触发战后对话
		if def.get("category", "commission") != "story":
			continue
		if not def.get("post_battle_dialogues", []).is_empty():
			if SignalBus and SignalBus.has_signal("story_mission_dialogue"):
				SignalBus.story_mission_dialogue.emit(qid, "post")
	_story_mission_queue.clear()
	_story_mission_played.clear()

## v6.7(剧情任务): tutorial 是否已触发过（用 StoryManager 节点标记防重复）
func _is_tutorial_triggered(quest_id: String) -> bool:
	var sm: Node = get_node_or_null("/root/StoryManager")
	if sm == null or not sm.has_method("is_node_triggered"):
		return false
	return sm.is_node_triggered("tutorial_" + quest_id)

## v6.7(剧情任务): 标记 tutorial 已触发（对话开始播放时调用，防重复）
func _mark_tutorial_triggered(quest_id: String) -> void:
	var sm: Node = get_node_or_null("/root/StoryManager")
	if sm != null and sm.has_method("mark_node_triggered"):
		sm.mark_node_triggered("tutorial_" + quest_id)

## v6.7(剧情任务): story 任务是否已接取且未完成
func _is_story_quest_active(quest_id: String) -> bool:
	var qm: Node = get_node_or_null("/root/QuestManager")
	if qm == null:
		return false
	if not qm.has_method("is_accepted") or not qm.has_method("is_quest_done"):
		return false
	return qm.is_accepted(quest_id) and not qm.is_quest_done(quest_id)
