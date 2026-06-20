extends Node
## 游戏流程：战前准备 → 战斗 → 战后
const DEBUG_GAME_LOG := false

enum GamePhase {
	PRE_BATTLE,
	BATTLE,
	POST_BATTLE
}

# v6.3: 游戏模式
enum GameMode {
	FREE,    ## 自由模式（原有玩法，自由选关）
	STORY,   ## 剧情模式（线性章节，含对话+Boss战）
}

var current_phase: GamePhase = GamePhase.PRE_BATTLE
var battle_scene: Node = null
var main_scene: Node = null
var current_level: int = 1
var last_battle_reward_summary: Dictionary = {}
var _blueprint_copies_before_battle: Dictionary = {}
var _knowledge_before_battle: Dictionary = {}
var _plm: Node = null  ## 安全引用：PhaseLawManager 本地缓存
signal current_level_changed(level: int)

# 相位师对战相关
var _current_phase_master: Dictionary = {}  # 当前战斗的相位师配置
var _is_phase_master_battle: bool = false   # 是否在与相位师战斗

# v6.3: 剧情模式状态
var game_mode: GameMode = GameMode.FREE
var current_chapter_id: String = ""         ## 当前进行中的章节ID
var _story_custom_battle: Dictionary = {}   ## 剧情Boss章的自定义战斗配置（覆盖普通相位师检测）

## 检查是否遭遇相位师（每场战斗15%概率）
## 逻辑：优先遭遇当前关卡所属势力的相位师（用于防守任务）
func check_phase_master_encounter() -> Dictionary:
	# 第49关固定为相位师战斗；其余关卡使用常量概率
	var force_phase_master_battle: bool = (current_level == 49)
	if not force_phase_master_battle and randf() > GC.PHASE_MASTER_ENCOUNTER_CHANCE:
		_is_phase_master_battle = false
		_current_phase_master = {}
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

	last_battle_reward_summary = {}
	_snapshot_battle_reward_baselines()
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

	# v6.3: 剧情模式 — 战斗结束后走剧情专用流程
	if game_mode == GameMode.STORY:
		_story_handle_battle_end(player_won)
		return

	# v6.5: 战斗结束后同步战力星级到所有卡牌实例（防御性，确保存档前数据一致）
	if BlueprintManager and BlueprintManager.has_method("sync_battle_stars_to_cards"):
		BlueprintManager.sync_battle_stars_to_cards()

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
		# 与已解锁关卡的「最前沿」对齐，否则 save.json 里 game.current_level 会永远停在 1（读档像没进度）
		if level_progress and level_progress.has_method("get_max_unlocked_level"):
			set_current_level(level_progress.get_max_unlocked_level())

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
	if main_scene and main_scene.has_method("show_battle_result"):
		main_scene.show_battle_result(player_won)
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
				# 许可类：作为通用许可资源发放（permit_card_* 和 permit_type_* 均映射到 permit_general）
				if res.drop.item_id.begins_with("permit_"):
					if BasicResourceManager.has_method("add_resource"):
						BasicResourceManager.add_resource(BasicResources.ID_PERMIT_GENERAL, res.count)
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
	# 新逻辑：必掉1个稀有符文，30%概率额外掉1个史诗符文
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	if pim and pim.has_method("add_owned_rune"):
		var RuneDefs = preload("res://data/runes.gd")
		# 必掉稀有符文
		var rare_runes: Array[Dictionary] = RuneDefs.get_runes_by_rarity(RuneDefs.RARITY_RARE)
		var generic_rare: Array[Dictionary] = []
		for r in rare_runes:
			if r.get("faction_id", "") == RuneDefs.FACTION_GENERIC:
				generic_rare.append(r)
		if not generic_rare.is_empty():
			var picked = generic_rare[randi() % generic_rare.size()]
			pim.add_owned_rune(picked["id"])
		# 30%概率额外掉史诗符文
		if randf() < 0.30:
			var epic_runes: Array[Dictionary] = RuneDefs.get_runes_by_rarity(RuneDefs.RARITY_EPIC)
			var generic_epic: Array[Dictionary] = []
			for r in epic_runes:
				if r.get("faction_id", "") == RuneDefs.FACTION_GENERIC:
					generic_epic.append(r)
			if not generic_epic.is_empty():
				var picked_e = generic_epic[randi() % generic_epic.size()]
				pim.add_owned_rune(picked_e["id"])
		# 5%概率掉传说符文（极稀有）
		if randf() < 0.05:
			var leg_runes: Array[Dictionary] = RuneDefs.get_runes_by_rarity(RuneDefs.RARITY_LEGENDARY)
			var generic_leg: Array[Dictionary] = []
			for r in leg_runes:
				if r.get("faction_id", "") == RuneDefs.FACTION_GENERIC:
					generic_leg.append(r)
			if not generic_leg.is_empty():
				var picked_l = generic_leg[randi() % generic_leg.size()]
				pim.add_owned_rune(picked_l["id"])

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
		if platform.platform_type == 5 or platform.platform_type == 10:  # SCOUT, STEALTH (旧枚举值，存档兼容)
			# v3: 应使用 platform.combat_kind，SCOUT(5)=轻装(0)，STEALTH(10)=轻装(0)
			# 为保持存档兼容，暂时保留 platform_type 检查
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
# v6.3: 剧情模式流程
# ═══════════════════════════════════════════════════════════════════

const StoryChaptersData = preload("res://data/story_chapters.gd")

## 开始剧情章节：设置关卡 → 触发战前对话
func start_story_chapter(chapter_id: String) -> void:
	var chapter: Dictionary = StoryChaptersData.get_chapter(chapter_id)
	if chapter.is_empty():
		push_warning("[GameManager] 未找到剧情章节: %s" % chapter_id)
		return
	current_chapter_id = chapter_id
	game_mode = GameMode.STORY
	# 设置关卡
	set_current_level(int(chapter.get("level_override", 1)))
	# Boss章节：设置自定义相位师配置
	if chapter.get("is_boss_chapter", false):
		var custom: Dictionary = chapter.get("custom_battle", {})
		_story_custom_battle = custom
		_is_phase_master_battle = true
		_current_phase_master = _build_story_master_config(custom)
	else:
		_story_custom_battle = {}
		_is_phase_master_battle = false
		_current_phase_master = {}
	# 触发战前对话信号
	if SignalBus.has_signal("story_show_pre_battle_dialogue"):
		SignalBus.story_show_pre_battle_dialogue.emit(chapter_id)

## 战前对话播放完毕后调用：正式进入战斗
func story_proceed_to_battle() -> void:
	if game_mode != GameMode.STORY or current_chapter_id.is_empty():
		return
	# 复用现有 go_to_battle 流程
	go_to_battle()

## 战斗结束后（剧情模式）：触发战后对话
func story_on_battle_won() -> void:
	if game_mode != GameMode.STORY or current_chapter_id.is_empty():
		return
	# 清理自定义Boss配置
	_story_custom_battle = {}
	_is_phase_master_battle = false
	# 标记章节完成
	var sm: Node = get_node_or_null("/root/StoryManager")
	if sm and sm.has_method("complete_chapter"):
		sm.complete_chapter(current_chapter_id)
	# 触发战后对话信号
	if SignalBus.has_signal("story_show_post_battle_dialogue"):
		SignalBus.story_show_post_battle_dialogue.emit(current_chapter_id)

## 战后对话播放完毕后调用：解锁下一章或完成剧情
func story_advance_to_next() -> void:
	if game_mode != GameMode.STORY:
		return
	var next_id: String = StoryChaptersData.get_next_chapter_id(current_chapter_id)
	if next_id.is_empty():
		# 剧情模式全部完成
		_on_story_completed()
		return
	# 解锁下一章
	var sm: Node = get_node_or_null("/root/StoryManager")
	if sm and sm.has_method("unlock_chapter"):
		sm.unlock_chapter(next_id)
	# 显示章节选择面板（让玩家继续）
	if SignalBus.has_signal("story_show_chapter_select"):
		SignalBus.story_show_chapter_select.emit()

## 剧情模式全部完成
func _on_story_completed() -> void:
	if SignalBus.has_signal("story_campaign_completed"):
		SignalBus.story_campaign_completed.emit()
	# 返回章节选择（玩家可重玩）
	if SignalBus.has_signal("story_show_chapter_select"):
		SignalBus.story_show_chapter_select.emit()

## 剧情模式战斗结束处理（仍发放奖励，然后触发战后对话）
func _story_handle_battle_end(player_won: bool) -> void:
	# 剧情模式仍发放正常奖励（资源/经验/符文等），复用现有逻辑但跳过选关流程
	if BlueprintManager and BlueprintManager.has_method("sync_battle_stars_to_cards"):
		BlueprintManager.sync_battle_stars_to_cards()
	# 发放基础资源
	_grant_basic_resources_for_current_level()
	# 发放相位场XP
	_grant_phase_field_xp_for_victory()
	# 保存 — v6.6: 使用延迟保存（0.3秒后），与自由模式一致，避免同步 I/O 卡顿
	var sm_save: Node = get_node_or_null("/root/SaveManager")
	if sm_save and sm_save.has_method("save_game"):
		var tree := get_tree()
		if tree:
			var t := tree.create_timer(0.3)
			t.timeout.connect(func() -> void:
				if sm_save and sm_save.has_method("save_game"):
					sm_save.save_game()
			)
	# 如果胜利，触发战后对话；失败则返回章节选择
	if player_won:
		story_on_battle_won()
	else:
		# 失败：返回章节选择让玩家重试
		if SignalBus.has_signal("story_show_chapter_select"):
			SignalBus.story_show_chapter_select.emit()

## 退出剧情模式，切换到自由模式
func exit_story_mode() -> void:
	game_mode = GameMode.FREE
	current_chapter_id = ""
	_story_custom_battle = {}
	_is_phase_master_battle = false

## 构建剧情Boss的相位师配置（复用现有PhaseMaster格式）
func _build_story_master_config(custom: Dictionary) -> Dictionary:
	var master_name: String = custom.get("master_name", "剧情Boss")
	var faction: String = custom.get("faction", "void")
	var era: int = int(custom.get("era", 0))
	var stats: Dictionary = custom.get("stats", {})
	# 复用 _enrich_master_config 的格式
	return {
		"name": master_name,
		"faction": faction,
		"era": era,
		"id": "story_boss_%s" % master_name,
		"level": current_level,
		"difficulty": 1.5,
		"stats": stats,
		"equipment": {},  # 使用默认装备
		"traits": [],
		"active_spells": [],
		"passive_spells": [],
		"enemy_faction": faction,
		"is_story_boss": true,
	}
