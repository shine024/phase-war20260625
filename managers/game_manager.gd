extends Node
## 游戏流程：战前准备 → 战斗 → 战后
const DEBUG_GAME_LOG := false
const PhaseMasterGarrison := preload("res://data/phase_master_garrison.gd")  # v7.x 相位师驻守映射
const NpcPhaseMasters := preload("res://data/npc_phase_masters.gd")  # NPC 相位师单一真理源

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
# v7.x 胜利面板漏显修复：本局掉落收集器。
# 收集所有绕过 DropManager.pending_drops 直接入背包/库存的奖励（战中击杀卡/符文/相位师全部奖励），
# 供 mvp_panel 新增"本局缴获与战利品"分区逐项显示。每项形如
# {category:"card|rune|mod_blueprint|instrument|resource", id, name, count, rarity, star, source}
var _battle_reward_collector: Array = []
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

# v7.3 修复 BUG-1: 记录"本次战斗实际打的关卡号"，避免 battle_ended 时序错位。
# 原 bug：battle_ended emit 后 GameManager 先于 QuestManager 执行（autoload 顺序），
#   GameManager 在 _on_battle_ended 里 set_current_level(max_unlocked) 把 current_level 更新成下一关，
#   之后 QuestManager 读 gm.current_level 得到的是下一关号 → cleared_levels 写入错误 →
#   首次通关第N关时 target=N 的剧情任务无法完成判定。
# 修复：go_to_battle 时记录刚要打的关号，QuestManager 优先读它。
var _pending_battle_level: int = 0

# v6.6(剧情): 最终战标记（补剧情.txt 第十幕 第100关/相位之主/噬时者）
var _is_final_battle: bool = false          ## 当前战斗是否为最终战（触发记忆场景视觉+专属Boss）

## 检查是否遭遇相位师（驻守关100%优先 → 非驻守关走概率门）
## 驻守相位师：20个关卡100%遭遇固定相位师（PhaseMasterGarrison 表，含原第49关硬编码，已驻守化）。
## 非驻守关：基础15%概率 + v7.1 软兜底
##           ①前 PHASE_MASTER_GRACE_LEVELS(10) 关新手保护期不触发；
##           ②连续 5 关未触发后概率递增（0.15→0.25→0.4），避免长期不遇。
## 逻辑：优先遭遇当前关卡所属势力的相位师（用于防守任务）
func check_phase_master_encounter() -> Dictionary:
	# v7.x 驻守相位师：20个关卡100%遭遇固定相位师（绕过随机机制）
	var garrison_master_id: String = PhaseMasterGarrison.get_garrison_master_id(current_level)
	if not garrison_master_id.is_empty():
		var garrison_config: Dictionary = _build_garrison_config(garrison_master_id)
		if not garrison_config.is_empty():
			_current_phase_master = garrison_config
			_is_phase_master_battle = true
			_phase_master_drought_count = 0
			return _current_phase_master
	# 非驻守关走概率门（第49关已并入驻守表，不再需要硬编码 force 分支）
	# v7.1 新手保护期：前 N 关不触发随机遭遇
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

	# 获取当前关卡的势力
	var LIC = preload("res://data/level_information.gd")
	var LevelInfo = LIC.new()
	var current_faction: String = LevelInfo.get_level_faction(current_level)
	if DEBUG_GAME_LOG:
		pass  # LOG: 当前关卡势力

	# NPC 相位师数据 —— 单一真理源 data/npc_phase_masters.gd（原 4 路径节点查找 + 内嵌副本已统一）
	var all_masters: Array = NpcPhaseMasters.get_all()

	if not all_masters.is_empty():
		# v7.x 时代筛选：低级关不应抽到高时代相位师（否则产兵跨时代，如一战关出近未来堡垒）。
		# 三层回退：①era ≤ 关卡era 的子池（严格同代）→ ②相邻下一时代(era+1)子池 → ③全池（最终兜底）。
		# 每层池内仍优先匹配 current_faction（势力防守逻辑保留），faction 匹配不到再池内随机。
		var level_era_ceiling: int = GC.get_era_for_level(current_level)
		var same_era_pool: Array = _filter_masters_by_era_ceiling(all_masters, level_era_ceiling)
		var selected_master: Dictionary = _pick_master_with_faction_priority(same_era_pool, current_faction)

		# 同代池为空 → 退到相邻下一时代（保证前 20 关也能刷出相位师，不至于因补的 NPC 未命中而空转）
		if selected_master.is_empty():
			var next_era_ceiling: int = mini(level_era_ceiling + 1, 4)
			if next_era_ceiling != level_era_ceiling:
				var adjacent_pool: Array = _filter_masters_by_era_ceiling(all_masters, next_era_ceiling)
				selected_master = _pick_master_with_faction_priority(adjacent_pool, current_faction)

		# 最终兜底：全池随机（含 faction 优先），永不破坏游戏
		if selected_master.is_empty():
			selected_master = _pick_master_with_faction_priority(all_masters, current_faction)

		if DEBUG_GAME_LOG and not selected_master.is_empty():
			pass  # LOG: 遭遇相位师（时代=%s）

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

## v7.x: 构建驻守相位师配置（直接从 EnemyPhaseMasters 取完整数据，绕过 _enrich_master_config 随机选择）
## 驻守关100%遭遇指定相位师，机配卡(platforms)+相位仪(phase_instrument)已在数据中配好。
func _build_garrison_config(master_id: String) -> Dictionary:
	var EPMC = preload("res://data/enemy_phase_masters.gd")
	var master: Dictionary = EPMC.get_master_by_id(master_id)
	if master.is_empty():
		push_warning("[GameManager] 驻守相位师未找到: %s" % master_id)
		return {}
	# 取 enriched equipment（含程序化派生的 runes/spawn_sequence）
	var pm_id: String = String(master.get("id", ""))
	var eq: Dictionary = master.get("equipment", {})
	if not pm_id.is_empty():
		var enriched_eq: Dictionary = EPMC.get_enriched_equipment(pm_id)
		if not enriched_eq.is_empty():
			eq = enriched_eq
	# 构建完整配置（与 _enrich_master_config 输出结构一致）
	return {
		"id": pm_id,
		"name": String(master.get("name", "")),
		"title": String(master.get("title", "")),
		"faction": String(master.get("faction", "")),
		"enemy_faction": String(master.get("faction", "")),
		"level": int(master.get("level", 15)),
		"difficulty": String(master.get("difficulty", "medium")),
		"equipment": eq,
		"stats": master.get("stats", {}),
		"traits": master.get("traits", []),
		"active_spells": master.get("active_spells", []),
		"passive_spells": master.get("passive_spells", []),
		"era": _era_string_from_level(int(master.get("level", 15))),
		# v7.x: 透传当前游戏关卡号，供 driver 按关卡难度递进产兵 tier
		"game_level": current_level,
	}

## v7.x: level → era 字符串（供 _build_garrison_config 填 era 字段）
func _era_string_from_level(level: int) -> String:
	# 驻守师的 level 是相位师等级(5-30)，用 level/6 近似映射时代
	var era: int = clampi(int(level / 6.0), 0, 4)
	match era:
		0: return "ww1"
		1: return "ww2"
		2: return "cold"
		3: return "modern"
		_: return "future"

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
	# v7.x: 透传当前游戏关卡号，供 driver 按关卡难度递进产兵 tier（与 _build_garrison_config 对齐）
	enriched["game_level"] = current_level

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

## v7.x 时代筛选：从相位师池筛出 era ≤ era_ceiling 的子集。
## 用于 check_phase_master_encounter——防止低级关抽到高时代相位师导致产兵跨时代
## （如一战关卡抽到 future 相位师 → 产近未来堡垒）。
## era 缺省按 future(4) 处理（保守归入高时代，不污染低时代子池）。
static func _filter_masters_by_era_ceiling(masters: Array, era_ceiling: int) -> Array:
	var out: Array = []
	for master in masters:
		if not (master is Dictionary):
			continue
		var era_str: String = String(master.get("era", ""))
		var master_era: int = _era_string_to_int(era_str) if not era_str.is_empty() else 4
		if master_era <= era_ceiling:
			out.append(master)
	return out

## v7.x 从相位师池抽一个：优先匹配 current_faction（防守任务），匹配不到则池内随机。
## 空池返回空字典（调用方三层回退）。
static func _pick_master_with_faction_priority(pool: Array, current_faction: String) -> Dictionary:
	if pool.is_empty():
		return {}
	if not current_faction.is_empty():
		var faction_matches: Array = []
		for master in pool:
			if String(master.get("faction", "")) == current_faction:
				faction_matches.append(master)
		if not faction_matches.is_empty():
			return faction_matches[randi() % faction_matches.size()]
	return pool[randi() % pool.size()]

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
	clear_battle_reward_collector()  # v7.x 胜利面板漏显修复：战斗开始时清空本局收集器
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

	# v7.x 性能：相位师奖励（~160行，含Boss掉落表+符文抽取+改造蓝图+星级评估）延迟到下一帧。
	# 这样结算面板能立即弹出（不依赖相位师奖励字段），相位师额外nano/energy在面板弹出后追加。
	# 时序安全：_current_phase_master 在延迟函数中清除，它在 GameManager 上不受 BattleManager
	# 的 _phase_master_config 清零影响。
	# v7.x 胜利面板漏显修复：_pm_reward_queued 标志防止相位师奖励被重复入队（AFK/show_battle_result/末尾兜底三路径互斥）。
	var _pending_pm_battle: bool = _is_phase_master_battle and not _current_phase_master.is_empty() and player_won
	var _pending_pm_name: String = ""
	var _pm_reward_queued: bool = false
	if _pending_pm_battle:
		_pending_pm_name = String(_current_phase_master.get("name", "相位师"))
		# 暂不清除相位师状态——延迟函数需要 _current_phase_master

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
	# v8.x: 战斗经验平分给上场存活卡（胜负都给，失败按 30% 比例），达阈值自动升 star_level
	_grant_battle_experience(player_won)

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
			# v7.x 性能：AchievementManager 延迟加载，访问前确保已实例化（否则成就进度丢失）
			ManagerLazyLoader.ensure_loaded("achievement")
			var _am_evo = get_node_or_null("/root/AchievementManager")
			if _am_evo and _am_evo.has_method("record_level_progress"):
				_am_evo.record_level_progress(current_level, victory_stars)
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
		# v7.x 胜利面板漏显修复：本局收集器快照（战中击杀卡/符文/相位师全部奖励）。
		# 相位师战时此快照在 _deferred_pm_show_battle_result 中会刷新一次（相位师奖励已入收集器）。
		"collected_rewards": _battle_reward_collector.duplicate(true),
	}
	# v7.x 性能：蓝图片段/知识收益计算延后到本帧 idle 队列执行。
	# 根因：_calculate_blueprint_fragment_gain 遍历全部蓝图 ID（可达 133 个）做 copies 差值，
	# _calculate_knowledge_gain 遍历 KNOWLEDGE_KEYS 快照，_get_recon_fragment_bonus_multiplier
	# 遍历相位仪 loadouts——三项叠在 battle_ended 信号栈（帧C，与 20+ 监听者同帧）。
	# 延后后：本帧先组装 reward_summary 主体，渲染一帧（玩家看到胜利瞬间），idle 队列再补字段。
	# 时序安全：call_deferred 是 FIFO，本行入队早于下方 main_scene.call_deferred("show_battle_result")
	# （若进入该分支），故面板构造时 last_battle_reward_summary 已含这三组字段，无需面板内延迟刷新。
	call_deferred("_deferred_calculate_fragment_and_knowledge_gain")

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
		ManagerLazyLoader.ensure_loaded("drop")  # DropManager 为 autoload+别名双层（ensure_loaded 幂等）
		var dm_afk: Node = get_node_or_null("/root/DropManager")
		if dm_afk != null and dm_afk.has_method("claim_drops"):
			dm_afk.claim_drops()
		# AFK 也需要延迟相位师奖励
		if _pending_pm_battle:
			call_deferred("_deferred_phase_master_reward", _pending_pm_name)
			_pm_reward_queued = true
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
		# v7.x 胜利面板漏显修复：相位师战时，call_deferred 是 FIFO，必须让相位师奖励先入队、面板后入队，
		# 否则面板先弹时相位师全部奖励（Boss卡/缴获卡/符文/改造蓝图/特殊仪/额外材料）还没进收集器，面板读不到。
		# 相位师战面板比非相位师战晚 ~2 帧（1帧发奖励+1帧显示），相位师战为15%概率稀有事件，可接受。
		if _pending_pm_battle:
			call_deferred("_deferred_phase_master_reward", _pending_pm_name)
			call_deferred("_deferred_pm_show_battle_result", player_won)
			_pm_reward_queued = true
		else:
			main_scene.call_deferred("show_battle_result", player_won)
	elif player_won:
		ManagerLazyLoader.ensure_loaded("drop")  # DropManager 为 autoload+别名双层（ensure_loaded 幂等）
		var dm_fallback: Node = get_node_or_null("/root/DropManager")
		if dm_fallback != null and dm_fallback.has_method("get_pending_drops_count") and dm_fallback.has_method("claim_drops"):
			if dm_fallback.get_pending_drops_count() > 0:
				dm_fallback.claim_drops()

	# v7.x 性能：相位师奖励延迟到下一帧执行（Boss掉落表+符文抽取+改造蓝图+星级评估，~160行）
	# v7.x 胜利面板漏显修复：仅当上方分支（AFK / show_battle_result 相位师战）尚未入队时才在此兜底入队，
	# 避免相位师奖励被重复执行（双倍发卡/符文/材料）。
	if _pending_pm_battle and not _pm_reward_queued:
		call_deferred("_deferred_phase_master_reward", _pending_pm_name)
	elif not _pending_pm_battle:
		# 非相位师战或失败，直接清除状态
		_is_phase_master_battle = false
		_current_phase_master = {}


func _deferred_phase_master_reward(master_name: String) -> void:
	## 延迟执行的相位师战胜奖励——Boss掉落表+符文抽取+改造蓝图+星级评估
	## 在结算面板弹出后执行，不影响玩家感知的"面板出现速度"
	_grant_phase_master_victory_reward(master_name)
	_is_phase_master_battle = false
	_current_phase_master = {}

## v7.x 胜利面板漏显修复：相位师战专用面板显示包装。
## 在 _deferred_phase_master_reward（已把相位师奖励发入收集器）之后刷新 collected_rewards 快照，
## 再调用 main_scene.show_battle_result 弹出面板——此时收集器已含相位师全部奖励，面板读得到。
func _deferred_pm_show_battle_result(player_won: bool) -> void:
	last_battle_reward_summary["collected_rewards"] = _battle_reward_collector.duplicate(true)
	if main_scene and main_scene.has_method("show_battle_result"):
		main_scene.show_battle_result(player_won)

# =========================================================================
#  v7.x 胜利面板漏显修复：本局掉落收集器 API
#  收集所有绕过 DropManager.pending_drops 直接入背包/库存的奖励，
#  供 mvp_panel "本局缴获与战利品"分区逐项显示。
# =========================================================================

## 清空本局收集器（go_to_battle 时调用）
func clear_battle_reward_collector() -> void:
	_battle_reward_collector.clear()

## 记录一张缴获/掉落卡（战中击杀 / 相位师Boss掉落 / 缴获平台卡）
func collect_battle_card(card_id: String, display_name: String, count: int, source: String) -> void:
	if card_id.is_empty():
		return
	_battle_reward_collector.append({
		"category": "card",
		"id": card_id,
		"name": display_name if not display_name.is_empty() else card_id,
		"count": maxi(1, count),
		"source": source,
	})

## 记录一个符文（战中击杀 / 相位师击败掉落）
func collect_battle_rune(rune_id: String, display_name: String, rarity: String, source: String) -> void:
	if rune_id.is_empty():
		return
	_battle_reward_collector.append({
		"category": "rune",
		"id": rune_id,
		"name": display_name if not display_name.is_empty() else rune_id,
		"rarity": rarity,
		"source": source,
	})

## 记录一个改造蓝图（相位师击败掉落）
func collect_battle_mod_blueprint(item_type: String, display_name: String, rarity: String, source: String) -> void:
	if item_type.is_empty():
		return
	_battle_reward_collector.append({
		"category": "mod_blueprint",
		"id": item_type,
		"name": display_name if not display_name.is_empty() else item_type,
		"rarity": rarity,
		"source": source,
	})

## 记录一个特殊相位仪（相位师击败掉落）
func collect_battle_instrument(instrument_id: String, display_name: String, star: int, source: String) -> void:
	if instrument_id.is_empty():
		return
	_battle_reward_collector.append({
		"category": "instrument",
		"id": instrument_id,
		"name": display_name if not display_name.is_empty() else instrument_id,
		"star": star,
		"source": source,
	})

## 记录相位师额外材料（Boss掉落表的纳米/能量/许可补偿）
func collect_battle_extra_resource(res_id: String, amount: int) -> void:
	if amount <= 0:
		return
	_battle_reward_collector.append({
		"category": "resource",
		"id": res_id,
		"amount": amount,
		"source": "相位师战利品",
	})

## 获取本局收集器（供面板读取）
func get_battle_reward_collector() -> Array:
	return _battle_reward_collector.duplicate(true)

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
						# v7.x 胜利面板漏显修复：相位师额外材料记入收集器
						collect_battle_extra_resource("nano_materials", res.count * 50)
				else:
					# 材料类：直接加资源（item_id 与 BasicResources ID 字符串一致）
					if BasicResourceManager.has_method("add_resource"):
						BasicResourceManager.add_resource(res.drop.item_id, res.count)
						if res.drop.item_id == "nano_materials":
							extra_nano_total += res.count
							# v7.x 胜利面板漏显修复：相位师额外材料记入收集器
							collect_battle_extra_resource("nano_materials", res.count)
						elif res.drop.item_id == "energy_block":
							extra_energy_total += res.count
							# v7.x 胜利面板漏显修复：相位师额外材料记入收集器
							collect_battle_extra_resource("energy_block", res.count)
			DropTables.DropType.CARD_DATA, DropTables.DropType.BLUEPRINT_FRAGMENT:
				# Boss 卡牌数据 → 成品卡发放
				if not res.drop.item_id.is_empty() and BlueprintManager:
					# v7.x 胜利面板漏显修复：source 非空时记录到本局收集器
					CardDropGrants.grant_enemy_style_card(BlueprintManager, res.drop.item_id, era_pm, 2, "相位师战利品")
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
			# v8.2 B2修复：WAR_PLATFORMS 查不到的平台（如 fut_boss_nexus 等真实 archetype），
			# 不是可缴获的正规平台卡（不在 DefaultCards），跳过避免静默失败。
			# boss 单位是特殊设计，其强度通过改造蓝图/符文/特殊仪掉落体现，不直接缴获。
			if pdata.is_empty():
				continue
			var ptype: String = String(pdata.get("type", ""))
			if excluded_types.has(ptype):
				continue
			var pname: String = pdata.get("name", pid)
			# v7.x 胜利面板漏显修复：source 非空时记录到本局收集器
			CardDropGrants.grant_enemy_style_card(BlueprintManager, String(pid), era_pm, 2, "相位师缴获")
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
			# v7.x 胜利面板漏显修复：相位师符文记入本局收集器
			collect_battle_rune(_granted_rune, RuneDefs.get_rune_name(_granted_rune), "rare", "相位师战利品")
		# 30%概率额外掉史诗符文
		if randf() < 0.30:
			var _granted_e: String = _pick_rune_from_pool_or_generic(_master_runes_pool, RuneDefs, RuneDefs.RARITY_EPIC)
			if not _granted_e.is_empty():
				pim.add_owned_rune(_granted_e)
				# v7.x 胜利面板漏显修复
				collect_battle_rune(_granted_e, RuneDefs.get_rune_name(_granted_e), "epic", "相位师战利品")
		# 5%概率掉传说符文（极稀有）
		if randf() < 0.05:
			var _granted_l: String = _pick_rune_from_pool_or_generic(_master_runes_pool, RuneDefs, RuneDefs.RARITY_LEGENDARY)
			if not _granted_l.is_empty():
				pim.add_owned_rune(_granted_l)
				# v7.x 胜利面板漏显修复
				collect_battle_rune(_granted_l, RuneDefs.get_rune_name(_granted_l), "legendary", "相位师战利品")

	# v6.14: 相位师击败 → 改造蓝图掉落（此前相位师无保底改造掉落，只有通用击杀概率）。
	# v7.x: 改用 MasterPowerEvaluator 星级映射 Tier（替代原 level*40 的 ad-hoc 换算），
	#       让掉落真正跟随相位师战力——高战力相位师掉高稀有度改造。
	# v7.x 修复:
	#   ① enemy_type 按相位师所属势力偏好派生（原硬编码"infantry"，非步兵玩家拿不到对口改造）
	#   ② 掉落数量按星级梯度（原1★和7★都只掉1个，数量梯度为0与"7倍强度"预期不符）
	var IntelManualItems = preload("res://data/intel_manual_items.gd")
	var _MPE = preload("res://scripts/master_power_evaluator.gd")
	var _PT = preload("res://data/power_tiers.gd")
	var _FCB = preload("res://data/faction_conquest_buffs.gd")
	var _stars: int = int(_MPE.evaluate(_current_phase_master).get("stars", 3))
	var _drop_bag: Node = get_node_or_null("/root/IntelItemBag")
	# enemy_type 按相位师所属势力的改造偏好派生；势力无偏好/查不到时回退 infantry
	# v8.2 B1修复：敌方 faction(steel/flame/...) 需映射到玩家势力 ID 才能匹配 FACTION_MOD_BIAS
	var _pm_faction: String = String(_current_phase_master.get("faction", ""))
	var _pm_player_faction: String = _enemy_faction_to_player_faction(_pm_faction)
	var _pm_enemy_type: String = "infantry"
	var _bias: Array = _FCB.FACTION_MOD_BIAS.get(_pm_player_faction, [])
	if not _bias.is_empty():
		_pm_enemy_type = String(_bias[0])
	var _pm_power_tier: int = _PT.get_tier_by_stars(_stars)
	# 必掉数量按星级梯度：基础1 + 3★+1 + 5★+2 + 7★+3
	var _pm_guaranteed: int = 1
	if _stars >= 7:
		_pm_guaranteed = 4
	elif _stars >= 5:
		_pm_guaranteed = 3
	elif _stars >= 3:
		_pm_guaranteed = 2
	# 发放必掉
	for _i in range(_pm_guaranteed):
		var _mod_drop: Dictionary = IntelManualItems.roll_random_mod_blueprint(_pm_enemy_type, "boss", _pm_power_tier, _bias)
		if not _mod_drop.is_empty() and _drop_bag and _drop_bag.has_method("add_item"):
			_drop_bag.add_item(String(_mod_drop.get("item_type", "")), 1)
			# v7.x 胜利面板漏显修复：相位师改造蓝图记入本局收集器（_mod_drop dict 已含 name/rarity 字段）
			collect_battle_mod_blueprint(String(_mod_drop.get("item_type", "")), String(_mod_drop.get("name", "")), String(_mod_drop.get("rarity", "")), "相位师战利品")
	# 30% 额外1个
	if randf() < 0.30:
		var _mod_drop2: Dictionary = IntelManualItems.roll_random_mod_blueprint(_pm_enemy_type, "boss", _pm_power_tier, _bias)
		if not _mod_drop2.is_empty() and _drop_bag and _drop_bag.has_method("add_item"):
			_drop_bag.add_item(String(_mod_drop2.get("item_type", "")), 1)
			# v7.x 胜利面板漏显修复
			collect_battle_mod_blueprint(String(_mod_drop2.get("item_type", "")), String(_mod_drop2.get("name", "")), String(_mod_drop2.get("rarity", "")), "相位师战利品")

	# v7.x: 特殊相位仪掉落（仅相位师掉落，不在商店出售）
	# 6★相位师 20% 掉对应特殊仪 / 7★相位师 40% 掉对应特殊仪
	# 低星级（5★及以下）不掉特殊相位仪（保留追求感）
		var _special_drop_id: String = _maybe_roll_special_instrument_drop(_stars, _pm_faction)
		if not _special_drop_id.is_empty() and PhaseInstrumentManager and PhaseInstrumentManager.has_method("unlock_instrument"):
			if not PhaseInstrumentManager.has_method("has_unlocked_instrument") or not PhaseInstrumentManager.has_unlocked_instrument(_special_drop_id):
				PhaseInstrumentManager.unlock_instrument(_special_drop_id)
				last_battle_reward_summary["special_instrument"] = _special_drop_id
				# v7.x 胜利面板漏显修复：特殊相位仪记入本局收集器（显示名从 PhaseInstruments 数据表取）
				var _spec_inst_cfg: Dictionary = PhaseInstrumentsData.get_by_id(_special_drop_id)
				var _spec_inst_name: String = String(_spec_inst_cfg.get("name", _special_drop_id))
				collect_battle_instrument(_special_drop_id, _spec_inst_name, _stars, "相位师掉落")
				if DEBUG_GAME_LOG:
					push_warning("[v7.x] 特殊相位仪掉落: %s" % _special_drop_id)

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

## v7.x: 按相位师星级/势力判定是否掉落特殊相位仪
## 6★相位师 20% 概率掉对应特殊仪 / 7★相位师 40% 概率掉对应特殊仪
## 5★及以下不掉（保留追求感，让高星相位师战更有价值）
## [param stars] 相位师星级（1-7）
## [param faction] 相位师势力 id（决定掉哪个特殊仪）
## [return] 特殊相位仪 id，未命中返回 ""
func _maybe_roll_special_instrument_drop(stars: int, faction: String) -> String:
	if stars < 6:
		return ""
	var drop_chance: float = 0.40 if stars >= 7 else 0.20
	if randf() >= drop_chance:
		return ""
	# 按势力映射特殊相位仪（势力-相位仪对应表）
	var faction_to_special: Dictionary = {
		"iron_wall_corp": "pi_special_rage",      # 钢铁势力 → 铁血元帅权杖
		"void_research": "pi_special_void",       # 虚空势力 → 虚空吞噬者
		"aether_dynamics": "pi_special_aegis",    # 神盾势力 → 神盾·壁垒之心
		"nova_arms": "pi_special_nova",           # 新星势力 → 终焉核芯
	}
	# v8.2 B1修复：敌方 faction 用 steel/flame/thunder/void，需映射到玩家势力 ID。
	var player_faction: String = _enemy_faction_to_player_faction(faction)
	# 势力命中：直接返回对应的特殊仪
	if faction_to_special.has(player_faction):
		return String(faction_to_special[player_faction])
	# 势力未命中（all/未知）：随机抽一个
	var all_specials: Array = faction_to_special.values()
	return String(all_specials[randi() % all_specials.size()])

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

## v8.2 B1: 敌方家族 faction（steel/flame/thunder/void/混合）→ 玩家势力 ID 映射。
## 修复 faction 命名空间不一致：FACTION_MOD_BIAS / 特殊仪表 的 key 是玩家势力 ID，
## 而相位师 faction 字段用敌方家族名，两者原先永不匹配导致改造偏好/特殊仪掉落失效。
## 混合势力取首段（steel_flame→iron_wall_corp）；all/未知返回空（走随机/默认）。
static func _enemy_faction_to_player_faction(enemy_faction: String) -> String:
	# 混合势力取首段
	var primary: String = enemy_faction.split("_")[0] if enemy_faction.find("_") >= 0 else enemy_faction
	match primary:
		"steel": return "iron_wall_corp"
		"flame": return "nova_arms"
		"thunder": return "aether_dynamics"
		"void": return "void_research"
		_: return ""  # all/未知 → 空，调用方走随机/默认

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
const BattleExperienceConfig = preload("res://data/battle_experience_config.gd")
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
# P3 性能优化：相位仪数据表改 preload（原胜利结算路径每次运行时 load）
const PhaseInstrumentsData = preload("res://data/phase_instruments.gd")

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

## v8.x: 战斗经验平分给上场存活卡，达阈值自动升 star_level
## 经验 = 基础经验(胜50/败15) + 击杀数×5，应用技能树经验加成后平分给上场卡
func _grant_battle_experience(player_won: bool) -> void:
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	if ir == null or not ir.has_method("add_experience"):
		return
	# 收集上场卡（green 槽战斗卡）的 instance_id
	var loadouts: Array = []
	if PhaseInstrumentManager and PhaseInstrumentManager.has_method("get_loadouts"):
		loadouts = PhaseInstrumentManager.get_loadouts()
	var instance_ids: Array = []
	for lo in loadouts:
		var platform: CardResource = lo.get("platform")
		if platform == null:
			continue
		var iid: String = String(platform.instance_id) if "instance_id" in platform else ""
		if not iid.is_empty() and not (iid in instance_ids):
			instance_ids.append(iid)
	if instance_ids.is_empty():
		return
	# 计算总经验
	var base_exp: int = BattleExperienceConfig.BATTLE_WIN_EXP_BASE if player_won else int(float(BattleExperienceConfig.BATTLE_WIN_EXP_BASE) * BattleExperienceConfig.BATTLE_LOSE_EXP_RATIO)
	# 击杀数：从 BattleManager 获取（如可用）
	var kill_count: int = 0
	if BattleManager and BattleManager.has_method("get_player_kill_count"):
		kill_count = int(BattleManager.get_player_kill_count())
	var total_exp: int = base_exp + kill_count * BattleExperienceConfig.BATTLE_KILL_EXP
	# 技能树经验加成
	var pmsm: Node = get_node_or_null("/root/PhaseMasterSkillManager")
	if pmsm != null and pmsm.has_method("get_active_effects"):
		var effects: Dictionary = pmsm.get_active_effects()
		var exp_bonus: float = float(effects.get("experience_bonus", 0.0))
		if exp_bonus > 0.0:
			total_exp = int(float(total_exp) * (1.0 + exp_bonus))
	# 平分给上场卡
	var per_card: int = int(total_exp / instance_ids.size())
	if per_card <= 0:
		return
	for iid in instance_ids:
		ir.add_experience(iid, per_card)

func _snapshot_battle_reward_baselines() -> void:
	_knowledge_before_battle.clear()
	_ensure_plm()
	if _plm and _plm.has_method("get_knowledge_snapshot"):
		_knowledge_before_battle = _plm.get_knowledge_snapshot()
	# v7.x 性能：蓝图片段改用 BlueprintManager 脏集增量计算（见 _calculate_blueprint_fragment_gain），
	# 不再开战时全量快照 ~133 蓝图。此处清空脏集，确保只统计本场战斗的增量。
	if BlueprintManager and BlueprintManager.has_method("take_blueprint_copy_delta"):
		BlueprintManager.take_blueprint_copy_delta()

func _calculate_blueprint_fragment_gain() -> Dictionary:
	# v7.x 性能：改读 BlueprintManager 脏集增量（仅变动过的卡，通常 0-5 张），
	# 替代旧的全量 ~133 蓝图 before/after diff。
	if not BlueprintManager or not BlueprintManager.has_method("take_blueprint_copy_delta"):
		return {"total": 0, "items": []}
	var deltas: Dictionary = BlueprintManager.take_blueprint_copy_delta()
	var total_gain: int = 0
	var items: Array = []
	for card_id in deltas:
		var gain: int = int(deltas[card_id])
		if gain > 0:
			total_gain += gain
			items.append({"id": String(card_id), "gain": gain})
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


## v7.x 性能：蓝图片段/知识收益/侦查加成的延迟计算（原在 _on_battle_ended 帧C同步执行）。
## 由 _on_battle_ended 末尾 call_deferred 触发，在 idle 队列里补齐 last_battle_reward_summary
## 的 fragment/knowledge/recon 字段。FIFO 保证此函数在 show_battle_result 之前执行，
## 面板构造时字段已就绪。
func _deferred_calculate_fragment_and_knowledge_gain() -> void:
	var battle_fragment_gain: Dictionary = _calculate_blueprint_fragment_gain()
	var battle_knowledge_gain: Dictionary = _calculate_knowledge_gain()
	last_battle_reward_summary["fragment_gain_total"] = int(battle_fragment_gain.get("total", 0))
	last_battle_reward_summary["fragment_gain_items"] = battle_fragment_gain.get("items", [])
	last_battle_reward_summary["knowledge_gain_total"] = int(battle_knowledge_gain.get("total", 0))
	last_battle_reward_summary["knowledge_gain_items"] = battle_knowledge_gain.get("items", [])
	var recon_bonus: float = _get_recon_fragment_bonus_multiplier()
	last_battle_reward_summary["recon_fragment_bonus_percent"] = int(round(recon_bonus * 100.0))
	last_battle_reward_summary["recon_fragment_multiplier"] = 1.0 + recon_bonus


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
