extends Node
## 游戏流程：战前准备 → 战斗 → 战后
const DEBUG_GAME_LOG := false

enum GamePhase {
	PRE_BATTLE,
	BATTLE,
	POST_BATTLE
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
	var target_level: int = clampi(era_int * 5 + 5, 5, 30)  # era 0->5, era 4->25

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

	# 获取战斗结果数据
	var victory_stars: int = 0
	var era: int = 0
	var phase_instrument_drop: Dictionary = {}
	if BattleManager.has_method("get_battle_result"):
		var result: Dictionary = BattleManager.get_battle_result()
		victory_stars = int(result.get("victory_stars", 0))
		era = int(result.get("era", 0))
		phase_instrument_drop = result.get("phase_instrument_drop", {}) as Dictionary

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

	# 保存战斗奖励摘要
	last_battle_reward_summary = {
		"player_won": player_won,
		"basic_nano_gain": max(0, after_basic_nano - before_basic_nano),
		"energy_block_gain": max(0, after_energy_block - before_energy_block),
		"nano_material_gain": max(0, after_blueprint_nano - before_blueprint_nano),
		"victory_stars": victory_stars,
		"era": era,
		"phase_instrument_drop": phase_instrument_drop.duplicate(true)
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

	# 1. 额外纳米材料奖励
	if BasicResourceManager.has_method("add_resource"):
		BasicResourceManager.add_resource(BasicResources.ID_NANO_MATERIALS, 50)
		if DEBUG_GAME_LOG:
			pass  # LOG: +50 基础纳米

	# 2. 额外能量块
	if BasicResourceManager.has_method("add_resource"):
		BasicResourceManager.add_resource(BasicResources.ID_ENERGY_BLOCK, 10)
		if DEBUG_GAME_LOG:
			pass  # LOG: +10 能量块

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
			var era_pm: int = GC.get_era_for_level(current_level)
			CardDropGrants.grant_enemy_style_card(BlueprintManager, String(pid), era_pm, 2)
			if DEBUG_GAME_LOG:
				pass  # LOG: 平台卡奖励
	# 4. 势力法则 → 背包法则卡（从相位师所属势力的法则家族中随机选取3条）
	if BlueprintManager:
		var master_faction: String = _current_phase_master.get("faction", "")
		var families: Array = _get_law_families_for_faction(master_faction)
		var law_ids: Array = _get_law_ids_for_families(families)
		if not law_ids.is_empty():
			## 随机选3条（不重复）
			var shuffled: Array = law_ids.duplicate()
			shuffled.shuffle()
			var pick_count: int = mini(3, shuffled.size())
			for i in range(pick_count):
				var law_id: String = String(shuffled[i])
				var law_data: Dictionary = PhaseLaws.get_by_id(law_id)
				var law_name: String = law_data.get("name", law_id)
				CardDropGrants.grant_law_cards_to_backpack(law_id, 2)
				if DEBUG_GAME_LOG:
					pass  # LOG: +2 法则卡

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

	# 记录到战斗奖励摘要
	last_battle_reward_summary["phase_master_victory"] = master_name
	last_battle_reward_summary["extra_nano"] = 50
	last_battle_reward_summary["extra_energy"] = 10

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
	if BasicResourceManager and BasicResourceManager.has_method("add_resource"):
		for id in drops.keys():
			var amount: int = int(drops[id])
			if amount > 0:
				BasicResourceManager.add_resource(String(id), amount)
	# 战后额外：纳米材料（用于解析蓝图）
	if BlueprintManager and BlueprintManager.has_method("add_nano_materials"):
		var nano_bonus: int = 10 + current_level * 3 + int(pow(float(current_level), 1.15))  # 经济平衡：指数增长
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
	PhaseInstrumentManager.grant_phase_field_xp("battle_victory", total_xp)

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
