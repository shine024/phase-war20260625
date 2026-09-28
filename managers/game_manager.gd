extends Node
## 游戏流程：战前准备 → 战斗 → 战后
const DEBUG_GAME_LOG := false
const PhaseMasterGarrison := preload("res://data/phase_master_garrison.gd")  # v7.x 相位师驻守映射
const NpcPhaseMasters := preload("res://data/npc_phase_masters.gd")  # NPC 相位师单一真理源
const EndlessBlackgateRef := preload("res://managers/endless_blackgate_manager.gd")  # v6.35 渗透/本体常量

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
var _cached_power_rating: int = 0  ## v6.6(剧情): 玩家战力评级缓存（补剧情.txt L41）
signal current_level_changed(level: int)

# 相位师对战相关
var _current_phase_master: Dictionary = {}  # 当前战斗的相位师配置
var _is_phase_master_battle: bool = false   # 是否在与相位师战斗
# v7.1 相位师遭遇软兜底：连续未触发计数器（≥5 则概率递增，避免长期不遇）
var _phase_master_drought_count: int = 0
# v7.1 新手保护期：前 10 关不触发随机相位师遭遇
const PHASE_MASTER_GRACE_LEVELS: int = 10
# v6.19 P1-T1.3 概率可见化：递增保底参数具名化（行为与旧内联值一致；情报舱 UI 读同一常量——宪法 C3）
const PHASE_MASTER_DROUGHT_TRIGGER: int = 5     ## 连续未触发达到该值后开始递增
const PHASE_MASTER_DROUGHT_STEP: float = 0.10   ## 每多连续未触发 1 关，概率增量
const PHASE_MASTER_ENCOUNTER_CAP: float = 0.5   ## 递增上限

var game_mode: GameMode = GameMode.FREE

## v27 黑门无限模式：当前战斗是否为黑门无尽 run（星冥族波次、永不判胜、专用结算链）
var _is_endless_battle: bool = false

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
##           ②连续 5 关未触发后概率递增（0.15→0.25→0.35→0.45，上限 0.5），
##             避免长期不遇（v6.19.1 勘误：旧注释"0.15→0.25→0.4"与常量不符）。
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
			_record_phase_master_encounter_milestone()
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
	if _phase_master_drought_count >= PHASE_MASTER_DROUGHT_TRIGGER:
		# 每多连续未触发 1 次，概率 +PHASE_MASTER_DROUGHT_STEP，上限 PHASE_MASTER_ENCOUNTER_CAP
		cur_chance = minf(PHASE_MASTER_ENCOUNTER_CAP, GC.PHASE_MASTER_ENCOUNTER_CHANCE \
			+ (_phase_master_drought_count - PHASE_MASTER_DROUGHT_TRIGGER + 1) * PHASE_MASTER_DROUGHT_STEP)
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
		_record_phase_master_encounter_milestone()
		return _current_phase_master

	_is_phase_master_battle = false
	_current_phase_master = {}
	return {}

## v6.19 P1-T1.3: 相位师遭遇规则查询（情报舱"相位师情报"分区显示用）。
## 数值与 check_phase_master_encounter 同一常量源——概率口径改这里，UI 自动跟随（宪法 C3）。
func get_phase_master_encounter_status() -> Dictionary:
	var next_chance: float = GC.PHASE_MASTER_ENCOUNTER_CHANCE
	if _phase_master_drought_count >= PHASE_MASTER_DROUGHT_TRIGGER:
		next_chance = minf(PHASE_MASTER_ENCOUNTER_CAP, GC.PHASE_MASTER_ENCOUNTER_CHANCE \
			+ (_phase_master_drought_count - PHASE_MASTER_DROUGHT_TRIGGER + 1) * PHASE_MASTER_DROUGHT_STEP)
	return {
		base_chance = GC.PHASE_MASTER_ENCOUNTER_CHANCE,
		grace_levels = PHASE_MASTER_GRACE_LEVELS,
		drought_count = _phase_master_drought_count,
		drought_trigger = PHASE_MASTER_DROUGHT_TRIGGER,
		drought_step = PHASE_MASTER_DROUGHT_STEP,
		chance_cap = PHASE_MASTER_ENCOUNTER_CAP,
		next_chance = next_chance,
	}

## v6.19 P2-T2.1/T2.2: 首次相位师遭遇埋点（驻守/随机两路共用；情报引导触达判据的数据面）
func _record_phase_master_encounter_milestone() -> void:
	var pm: Node = get_node_or_null("/root/PerformanceMetricsManager")
	if pm != null and pm.has_method("record_milestone"):
		pm.record_milestone("first_phase_master_encounter")

## v6.19.1 核验清单#1: 同帧多弹窗错峰——等当前 FeatureUnlockPopup（CanvasLayer 250）关闭后再弹。
## 场景：L10 是驻守关，通关时"首遇情报引导"与"保护期结束预告"同帧触发，两层叠放互相盖住。
## 最多等 ~6s 防悬挂；等待期玩家关掉前一个弹窗即放行。
func _show_notice_when_popup_free(key: String, title: String, desc: String) -> void:
	for i in 60:
		var busy := false
		for ch in get_tree().root.get_children():
			if ch is FeatureUnlockPopup:
				busy = true
				break
		if not busy:
			break
		await get_tree().create_timer(0.1).timeout
	FeatureUnlockPopup.show_once(key, title, desc)

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
# v9.x（P2-7范围B）：_ensure_plm/_plm 已随 PhaseLawManager 退役移除

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
	# 2. 卡牌战力加成：按拥有的卡牌实例数贡献（2026-08-22 蓝图副本记账移除后改绑实例数）
	var ir_node: Node = get_node_or_null("/root/InstanceRegistry")
	if ir_node != null and ir_node.has_method("get_all_instance_ids"):
		power += ir_node.get_all_instance_ids().size()
	# 3. 相位仪加成：每级相位场经验 +1
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	if pim and pim.has_method("get_phase_field_level"):
		var pf_level: int = int(pim.get_phase_field_level())
		power += pf_level * 2
	# 4. 法则加成：已随法则系统退役移除（v9.x P2-7范围B）
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
	## v22.4（P0-1 碎片可达性）：加"未收集优先"两级排序——原逻辑只按等级距离取
	## 唯一候选，等级居中的驻守师会系统性遮蔽边缘等级的非驻守相位师（30 位中
	## 10 位无驻守关，只能靠随机遭遇掉碎片），30/30 碎片在旧规则下大概率凑不齐，
	## 观星台终局被事实上锁死。现改为：未收集的候选优先，同级再比等级距离；
	## 全部已收集时退化为原行为。
	var collected_ids: Array = []
	var bunker_mgr: Node = Engine.get_main_loop().root.get_node_or_null("BunkerManager") \
		if Engine.get_main_loop() != null else null
	if bunker_mgr != null and bunker_mgr.has_method("get_hero_fragments"):
		collected_ids = bunker_mgr.get_hero_fragments()
	var best: Dictionary = _pick_master_candidate(candidates, target_level, collected_ids)

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

## v22.4（P0-1）：遭遇相位师候选两级择优——①碎片未收集者优先（0<已收集 1），
## ②同级比 |level - target_level|。collected_ids 为空/候选未命中时退化为例原行为。
## 静态纯函数便于冒烟测试直接断言。
## v6.32.3: 未收集优先加等级容差带（±_PICK_LEVEL_BAND）——原实现任何未收集候选
## 无条件压倒已收集，高关卡随机遭遇会因低级师碎片未收集而抽到新手档相位师
## （99 关实证：era4 满级段抽出 Lv5/2900 血相位师，基地被秒 → 98 关"杀4个就过关"
## 同根源：低配相位师产兵弱+基地脆，玩家杀 3 小兵+拆基地快速判胜）。
## 带内维持 v22.4 语义（未收集优先→距离）；带外只按距离且只与带外比；
## 带内无候选时退化全池纯距离（保底不空转）。
const _PICK_LEVEL_BAND: int = 8

static func _pick_master_candidate(candidates: Array, target_level: int, collected_ids: Array = []) -> Dictionary:
	var best_in: Dictionary = {}              # 带内最佳（未收集优先→距离）
	var best_in_collected: int = 2            # 哨兵：任何带内候选的 collected(0/1) 都优于 2
	var best_in_diff: int = 999
	var best_any: Dictionary = {}             # 全池纯距离最佳（带内空时保底）
	var best_any_diff: int = 999
	for c in candidates:
		if not (c is Dictionary):
			continue
		var diff: int = absi(int(c.get("level", 1)) - target_level)
		var collected: int = 1 if collected_ids.has(String(c.get("id", ""))) else 0
		if diff < best_any_diff:
			best_any_diff = diff
			best_any = c
		if diff <= _PICK_LEVEL_BAND:
			if collected < best_in_collected or (collected == best_in_collected and diff < best_in_diff):
				best_in_collected = collected
				best_in_diff = diff
				best_in = c
	return best_in if not best_in.is_empty() else best_any

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

## v27 黑门无限模式：是否处于无尽 run
func is_endless_battle() -> bool:
	return _is_endless_battle

## v27 黑门无限模式：从大地图黑门节点进入。
## 只挂起标记（_is_endless_battle=true）——真正 begin_run 在 go_to_battle 生效瞬间执行，
## 确保战场/刷新系统已就位（与"开始战斗"按钮链路一致，见 main_battle_setup）。
## current_level 维持 100 关口径（档位/难度链以近未来满档为基准），
## 波次构成/敌池由 battle_spawn_system 的 endless 分支接管。
func start_endless_battle() -> void:
	_is_endless_battle = true

## ── v6.35 异族渗透战（大地图随机星冥散兵,收益很小口径）──────────────
## 单波 xeno 编队,敌灭判胜,专用轻结算(不推关卡/星级/势力反应/相位师遭遇)。
var pending_incursion_loadout: Array = []
var _is_incursion_battle: bool = false
var _pending_incursion: Dictionary = {}

func is_incursion_battle() -> bool:
	return _is_incursion_battle

## 由 world_map 热区/进战链调用(inc = EBM.incursions 成员)。强度锚定宿主关
## (set_current_level → make_default_context 读 current_level 走档位/时代递进)。
func start_incursion_battle(inc: Dictionary) -> void:
	var ebm: Node = get_node_or_null("/root/EndlessBlackgateManager")
	if ebm == null or not ebm.has_method("get_incursion_loadout"):
		return
	var loadout: Dictionary = ebm.call("get_incursion_loadout", inc)
	var ids: Array = loadout.get("ids", [])
	if ids.is_empty():
		return
	pending_incursion_loadout = ids.duplicate()
	_pending_incursion = inc.duplicate(true)
	_is_incursion_battle = true
	if loadout.get("host_level", 0) is int and int(loadout.get("host_level", 0)) > 0:
		set_current_level(int(loadout.get("host_level")))
	# v6.35 复查修复:此处不直接 go_to_battle——渗透战必须走 main 的标准开战管线
	# (run_start_battle_sequence: show_battle/界面切换/战备收尾),否则战斗在 UI 停留
	# 整备态时后台开打。调用方(main._consume_incursion_meta)备态后调
	# _auto_battle_from_truck_sortie() 走与「进关即开战」同一条管线。

## 渗透战轻结算:胜=小额资源+低概率缴获+节点清除;败=节点消失(异族转移)。
## 不弹结算面板(收益很小定位,Toast 承载),直接回整备。
func _settle_incursion_battle(player_won: bool) -> void:
	_is_incursion_battle = false
	var inc: Dictionary = _pending_incursion
	_pending_incursion = {}
	pending_incursion_loadout = []
	var ebm: Node = get_node_or_null("/root/EndlessBlackgateManager")
	if ebm != null and ebm.has_method("erase_incursion"):
		ebm.erase_incursion(inc)
	if player_won:
		if BasicResourceManager != null:
			BasicResourceManager.add_resource("basic_nano", EndlessBlackgateRef.INCURSION_NANO)
			BasicResourceManager.add_resource("energy_block", EndlessBlackgateRef.INCURSION_ENERGY)
		# 低概率缴获:从编队随机一只掉 captured_xeno_*(直接入包;收集器不消费,渗透战不弹面板)
		var captured_note: String = ""
		if randf() < EndlessBlackgateRef.INCURSION_CAPTURE_CHANCE:
			var ebm2: Node = get_node_or_null("/root/EndlessBlackgateManager")
			var ids: Array = ebm2.call("get_incursion_loadout", inc).get("ids", []) if ebm2 != null else []
			if not ids.is_empty():
				var arch: String = String(ids[randi() % ids.size()])
				var card_id: String = "captured_" + arch
				var bp := get_node_or_null("/root/SaveManager")
				if bp != null and bp.has_method("enqueue_backpack_card_id"):
					bp.enqueue_backpack_card_id(card_id)
				captured_note = " · 🎖 缴获 %s" % arch
		if SignalBus != null and SignalBus.has_signal("show_toast"):
			SignalBus.show_toast.emit("异族渗透已清除 · 纳米 +%d 能量块 +%d%s" % [
				EndlessBlackgateRef.INCURSION_NANO, EndlessBlackgateRef.INCURSION_ENERGY, captured_note])
	else:
		if SignalBus != null and SignalBus.has_signal("show_toast"):
			SignalBus.show_toast.emit("渗透的异族散兵转移了……")
	return_to_prep()

func go_to_battle() -> void:
	if DEBUG_GAME_LOG:
		pass  # LOG: go_to_battle 被调用
	# v27 黑门无尽 run：生效瞬间 roll 裂隙环境（BattleManager.start_battle 随后读取）
	if _is_endless_battle:
		ManagerLazyLoader.ensure_loaded("endless")
		var endless_pre: Node = get_node_or_null("/root/EndlessBlackgateManager")
		if endless_pre != null and endless_pre.has_method("begin_run"):
			endless_pre.call("begin_run")
	current_phase = GamePhase.BATTLE
	# v7.3 修复 BUG-1: 记录本次战斗实际打的关号（set_current_level 切关前）
	_pending_battle_level = current_level

	last_battle_reward_summary = {}
	clear_battle_reward_collector()  # v7.x 胜利面板漏显修复：战斗开始时清空本局收集器
	_snapshot_battle_reward_baselines()
	# 检查是否遭遇相位师（v27 黑门无尽 run 不遭遇相位师；v6.35 渗透战同样排除）
	if not _is_endless_battle and not _is_incursion_battle:
		check_phase_master_encounter()
	if battle_scene == null:
		push_error("battle_scene 为空，请检查 Main 是否调用了 GameManager.set_battle_scene")
		return
	if DEBUG_GAME_LOG:
		pass  # LOG: 调用 BattleManager.start_battle
	BattleManager.start_battle(battle_scene)

const FirstClearRewards = preload("res://data/first_clear_rewards.gd")

## v32.0 B3-S1: 推图首通奖励（三层收入模型——主动游玩核心回报）
## 时序契约：必须在 LevelProgressManager.complete_level 记账**之前**调用（stars==0 判首通）；
## 本函数在 _on_battle_ended 的 player_won 分支头部位执行，结算链后续才落星。
func _grant_first_clear_if_eligible() -> void:
	var lvl := int(current_level)
	if lvl < 1:
		return
	var lpm := get_node_or_null("/root/LevelProgressManager")
	if lpm == null or int(lpm.get_level_stars(lvl)) != 0:
		return  # 已通关过 = 非首通（信号重入/重复结算同此守卫）
	var reward: Dictionary = FirstClearRewards.get_first_clear_reward(lvl)
	if reward.is_empty() or BasicResourceManager == null:
		return
	for id in reward:
		BasicResourceManager.add_resource(String(id), int(reward[id]))
	SignalBus.show_toast.emit("★ 首通奖励已发放：" + FirstClearRewards.format_reward_text(reward))
	# v34 B3：首通奖励入结算摘要——缴获页「首次通关奖励」区块消费（Toast 保留双通道）
	last_battle_reward_summary["first_clear"] = {"level": lvl, "reward": reward.duplicate()}

func _on_battle_ended(player_won: bool) -> void:
	current_phase = GamePhase.POST_BATTLE

	# v6.6(剧情): 清理最终战标记（防跨战斗残留）
	clear_final_battle_state()

	# v27 黑门无限模式：专用结算链（分数/星髓/排行榜提交），跳过关卡进度/
	# 势力反应/星级/基础资源等胜利结算（无尽 run 恒以"驱动器被毁"收场 = 玩家视角
	# 的"打完一轮"，不是失败语义）。缴获掉落在 BattleManager.end_battle 链已生成。
	if _is_endless_battle:
		_settle_endless_battle()
		return

	# v6.35 异族渗透战:专用轻结算(Toast+回整备,不弹面板不推进度)
	if _is_incursion_battle:
		_settle_incursion_battle(player_won)
		return

	# v6.19 P2-T2.1: 首次相位师遭遇后的情报引导（胜败皆弹——败给相位师正是最需要情报的时刻；
	# 弹窗挂 CanvasLayer 250 高于结算面板，时序安全；show_once 随档只弹一次）。
	# v6.19.1：文案升级为"遭遇→打开情报→使用对策"三步链（核验清单#1），数值读常量（宪法 C3）。
	if _is_phase_master_battle:
		FeatureUnlockPopup.show_once("phase_master_intel_guide", "遭遇相位师——随机可情报化",
			"① 遭遇：驻守关 100%% 固定遭遇；野外关基础 %d%%，连续未遭遇会逐关递增（上限 %d%%）——概率全部公开。\n② 打开情报：回基地点档案区「情报舱」工位 →「敌方情报」页顶部「相位师情报」分区，实时显示遭遇率与递增进度。\n③ 使用对策：下次出击前看世界地图战前建议，按情报预配克制阵容——随机可准备，不再靠运气。" % [
				int(GC.PHASE_MASTER_ENCOUNTER_CHANCE * 100.0), int(PHASE_MASTER_ENCOUNTER_CAP * 100.0)])

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
		# v32.0 B3-S1: 首通判定须先于 complete_level 记账
		_grant_first_clear_if_eligible()
		_grant_basic_resources_for_current_level()
		_grant_phase_field_xp_for_victory()
		# v6.22: 攻克关卡势力反应链已删——势力不再占领领地，贡献只由任务/事件/相位师战驱动
		# v27.15（TODO#10 复活，用户裁决）：普通战斗相位仪掉落链——"战场缴获"通道。
		# 通用系列开局全解锁（_init_unlocked_instruments 白送）、特殊仪走相位师战利品，
		# 故掉落池 = 未解锁的势力专属仪（常态渠道=商店声望/势力技能，掉落是幸运捷径，
		# 低星为主、6-7★招牌不进池保持商店稀缺）。相位师战自身另有特殊仪掉落，跳过防双掉。
		if not _is_phase_master_battle:
			var _drop_inst_id: String = _maybe_roll_regular_instrument_drop()
			if not _drop_inst_id.is_empty():
				if PhaseInstrumentManager and PhaseInstrumentManager.has_method("unlock_instrument"):
					PhaseInstrumentManager.unlock_instrument(_drop_inst_id)
				last_battle_reward_summary["instrument_drop"] = _drop_inst_id
				var _drop_inst_cfg: Dictionary = PhaseInstrumentsData.get_by_id(_drop_inst_id)
				collect_battle_instrument(_drop_inst_id, String(_drop_inst_cfg.get("name", _drop_inst_id)), victory_stars, "战场缴获")
	else:
		# v26.13(gameplay)：败局也给相位场经验（胜利值 30%，与下方战斗卡失败 30% 同口径）
		#——失败也有成长进尺，回收"白打一场"的挫败感。
		_grant_phase_field_xp_for_defeat()
	# v8.x: 战斗经验平分给上场存活卡（胜负都给，失败按 30% 比例），达阈值自动升 star_level
	_grant_battle_experience(player_won)

	# 计算原有奖励增益
	var after_basic_nano: int = BasicResourceManager.get_total(BasicResources.ID_NANO_MATERIALS) if BasicResourceManager.has_method("get_total") else before_basic_nano
	var after_energy_block: int = BasicResourceManager.get_total(BasicResources.ID_ENERGY_BLOCK) if BasicResourceManager.has_method("get_total") else before_energy_block
	var after_blueprint_nano: int = BlueprintManager.get_nano_materials() if BlueprintManager.has_method("get_nano_materials") else before_blueprint_nano

	# v26 批次4：荣誉室 Lv3 出征仪式——敬礼武装后本场掉落收益 +10%（结算即消耗）。
	# 口径与低精神惩罚同链：对战后货币收益差值补成 10%（纳米+能量块）。
	var salute_bonus_data := {}
	var bunker_salute: Node = get_node_or_null("/root/BunkerManager")
	if player_won and bunker_salute != null and bunker_salute.has_method("consume_salute"):
		var salute_mult: float = bunker_salute.consume_salute()
		if salute_mult > 1.0 and BasicResourceManager != null and BasicResourceManager.has_method("add_resource"):
			var nano_gain: int = maxi(0, after_basic_nano - before_basic_nano)
			var energy_gain: int = maxi(0, after_energy_block - before_energy_block)
			var nano_bonus: int = int(round(float(nano_gain) * (salute_mult - 1.0)))
			var energy_bonus: int = int(round(float(energy_gain) * (salute_mult - 1.0)))
			if nano_bonus > 0:
				BasicResourceManager.add_resource(BasicResources.ID_NANO_MATERIALS, nano_bonus)
				after_basic_nano += nano_bonus
			if energy_bonus > 0:
				BasicResourceManager.add_resource(BasicResources.ID_ENERGY_BLOCK, energy_bonus)
				after_energy_block += energy_bonus
			if nano_bonus > 0 or energy_bonus > 0:
				salute_bonus_data = {"nano": nano_bonus, "energy": energy_bonus}

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
			# v6.19 P2-T2.2 流派成型埋点：首次通关相位师驻守关
			if PhaseMasterGarrison.is_garrison_level(current_level):
				var _pm_gar: Node = get_node_or_null("/root/PerformanceMetricsManager")
				if _pm_gar != null and _pm_gar.has_method("record_milestone"):
					_pm_gar.record_milestone("first_garrison_clear")
			# v6.19 P2-T2.1: 新手保护期结束预告（前 N 关无随机相位师；通关第 N 关时一次性提示）。
			# v6.19.1 核验清单#1/#6：走错峰助手（L10 驻守关首遇引导同帧双弹）+ 说明保护期计入递增计数。
			if current_level == PHASE_MASTER_GRACE_LEVELS:
				_show_notice_when_popup_free("grace_end_notice", "新手保护期结束",
					"下一关起，野外关卡可能遭遇敌方相位师。\n• 基础遭遇率 %d%%；新手保护期也计入连续未遭遇计数——初期实际概率会高于基础值，情报舱「相位师情报」可查当前确切概率。\n• 出击前看世界地图战前建议，按情报预配克制阵容。" % int(GC.PHASE_MASTER_ENCOUNTER_CHANCE * 100.0))
			if DEBUG_GAME_LOG:
				pass  # LOG: 关卡进度已更新
			# v7.x 修复 B3：记录关卡进度成就统计（progress 类成就，如 max_level/perfect_levels）
			# v7.x 性能：AchievementManager 延迟加载，访问前确保已实例化（否则成就进度丢失）
			ManagerLazyLoader.ensure_loaded("achievement")
			var _am_evo = get_node_or_null("/root/AchievementManager")
			if _am_evo and _am_evo.has_method("record_level_progress"):
				_am_evo.record_level_progress(current_level, victory_stars)
			# v26.13(gameplay)：战斗类成就统计接线（此前 record_battle_victory 零调用，
			# battle 类 8 成就全部不可解锁）。数据源=BattleInfoDisplay 战况统计。
			var _bid: Node = get_tree().root.find_child("BattleInfoDisplay", true, false)
			var _battle_data: Dictionary = {}
			if _bid != null and _bid.has_method("get_battle_stats"):
				var _bs: Dictionary = _bid.get_battle_stats()
				_battle_data = {
					"kills": int(_bs.get("player_kills", 0)),
					"damage_dealt": int(_bs.get("damage_dealt", 0)),
					"battle_time": float(_bs.get("battle_time", 999.0)),
					"no_damage": int(_bs.get("damage_taken", 0)) <= 0,
				}
			if _is_phase_master_battle and _current_phase_master != null:
				_battle_data["defeated_master"] = str(_current_phase_master.get("id", ""))
			var _am_bat = get_node_or_null("/root/AchievementManager")
			if _am_bat and _am_bat.has_method("record_battle_victory"):
				_am_bat.record_battle_victory(_battle_data)
			# v26.13(gameplay)：时代完成成就接线（此前 record_era_completion 零调用）
			if current_level % 20 == 0:
				if _am_evo and _am_evo.has_method("record_era_completion"):
					_am_evo.record_era_completion("era%d" % (current_level / 20 - 1))
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
	# 收集卡种数（2026-08-22：原蓝图解锁计数已随蓝图体系移除，改数拥有过的卡种）
	if lb != null and lb.has_method("update_blueprint_count"):
		var am_lb: Node = get_node_or_null("/root/AchievementManager")
		var bp_count: int = am_lb.collection_stats["unique_blueprints"].size() 			if (am_lb != null and am_lb.get("collection_stats") is Dictionary and (am_lb.get("collection_stats") as Dictionary).has("unique_blueprints")) else 0
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
	# v26 批次4：出征仪式加成记入摘要（summary 字面量构建后追加，避免被覆盖）
	if not salute_bonus_data.is_empty():
		last_battle_reward_summary["salute_bonus"] = salute_bonus_data
	# v22.4（P1-4）：低精神掉落惩罚——精神值从装饰数值变真资源。
	# 按基地精神档位（<50 → ×0.9 / <30 → ×0.75）对本次战后货币收益折算扣回，
	# 惩罚额记入 summary 供结算面板"要塞"行展示。口径说明：只折算本函数内同步
	# 入账的收益快照差值，结算面板"继续"时才领取的 DropManager 待领掉落不追溯
	# （惩罚的意义在信号传递，不在精确到个位）。
	var bunker_pen: Node = get_node_or_null("/root/BunkerManager")
	var sanity_mult: float = 1.0
	if bunker_pen != null and bunker_pen.has_method("get_drop_reward_multiplier"):
		sanity_mult = bunker_pen.get_drop_reward_multiplier()
	if player_won and sanity_mult < 1.0 and BasicResourceManager != null:
		var pen_ratio: float = 1.0 - sanity_mult
		var nano_pen: int = int(round(int(last_battle_reward_summary.get("basic_nano_gain", 0)) * pen_ratio))
		var energy_pen: int = int(round(int(last_battle_reward_summary.get("energy_block_gain", 0)) * pen_ratio))
		if nano_pen > 0 and BasicResourceManager.has_method("consume") \
				and BasicResourceManager.has_method("get_total"):
			var nano_have: int = BasicResourceManager.get_total(BasicResources.ID_NANO_MATERIALS)
			nano_pen = mini(nano_pen, nano_have)
			if nano_pen > 0:
				BasicResourceManager.consume(BasicResources.ID_NANO_MATERIALS, nano_pen)
		if energy_pen > 0 and BasicResourceManager.has_method("consume") \
				and BasicResourceManager.has_method("get_total"):
			var energy_have: int = BasicResourceManager.get_total(BasicResources.ID_ENERGY_BLOCK)
			energy_pen = mini(energy_pen, energy_have)
			if energy_pen > 0:
				BasicResourceManager.consume(BasicResources.ID_ENERGY_BLOCK, energy_pen)
		if nano_pen > 0 or energy_pen > 0:
			last_battle_reward_summary["sanity_penalty"] = {
				"nano": nano_pen, "energy": energy_pen, "multiplier": sanity_mult,
			}
	# v9.x（P2-7范围B）：知识收益延迟计算已随法则系统退役移除（原 call_deferred 补
	# knowledge_gain_* 字段，无面板消费方）。

	# HUD 重构：结算入口由主场景 `show_battle_result` 弹出 battle_result_dialog（OK 时 claim_drops）。
	# 若主场景未实现该方法（历史场景/测试），胜利后须仍领取 DropManager 待领掉落，否则会永久卡在 pending。
	#
	# v6.6(挂机): 挂机模式下跳过结算弹窗，自动处理掉落 + 重置到 PRE_BATTLE，
	# 让 AFKModeManager 的 call_deferred 下一关启动时战场已清理、phase 已重置。
	# 必须在处理掉落之前调用 accumulate_pending_drops()，把掉落计入累计奖励总账。
	# v23.6(归仓): 挂机掉落改为送入 DropManager 归仓暂存池（不再即时入账钱包）——
	# 玩家回基地在房间头顶气泡收取 / HUD 一键全收 / 挂机结算弹窗"全部入账"，
	# 把"回来收菜"做成可见的收集时刻。钱包入账延后，数额口径不变（同乘区同管线）。
	if _is_afk_running():
		# AFKModeManager 是 RefCounted（非 Node），故 afk_mgr 用 Variant 不标 Node 类型。
		var afk_mgr = main_scene._afk_manager if (main_scene != null and "_afk_manager" in main_scene) else null
		if afk_mgr != null and afk_mgr.has_method("accumulate_pending_drops"):
			afk_mgr.accumulate_pending_drops()
		ManagerLazyLoader.ensure_loaded("drop")  # DropManager 为 autoload+别名双层（ensure_loaded 幂等）
		var dm_afk: Node = get_node_or_null("/root/DropManager")
		if dm_afk != null and dm_afk.has_method("deposit_pending_to_escrow"):
			dm_afk.deposit_pending_to_escrow()
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


## v27 黑门无限模式结算：波次/击杀 → 分数 + 星髓（周封顶）+ survival_highscore 提交。
## 结算面板复用 show_battle_result（战报读 last_battle_reward_summary.endless 段）；
## Toast 播报分数/纪录/星髓，避免"战败"文案误导（无尽 run 无败局语义）。
func _settle_endless_battle() -> void:
	_is_endless_battle = false
	_is_phase_master_battle = false
	_current_phase_master = {}

	var waves: int = 0
	var kills: int = 0
	if BattleManager and BattleManager.has_method("get_battle_result"):
		var endless_r: Dictionary = (BattleManager.get_battle_result() as Dictionary).get("endless", {}) as Dictionary
		waves = int(endless_r.get("waves", 0))
		kills = int(endless_r.get("kills", 0))

	# 战斗经验照常平分（失败口径 30%——卡牌成长不因模式中断）
	_grant_battle_experience(false)
	# v34 B2 修复：card_growth 写在旧摘要字典里，下方整字典重建会抹掉——备份后回填
	var growth_bak: Array = last_battle_reward_summary.get("card_growth", [])

	ManagerLazyLoader.ensure_loaded("endless")
	var endless: Node = get_node_or_null("/root/EndlessBlackgateManager")
	var summary: Dictionary = {}
	if endless != null and endless.has_method("settle_run"):
		summary = endless.call("settle_run", waves, kills)

	last_battle_reward_summary = {
		"player_won": false,
		"victory_stars": 0,
		"era": 5,
		"endless": summary.duplicate(true) if not summary.is_empty() else {"waves": waves, "kills": kills},
		# v7.x 本局收集器快照（缴获卡等战中奖励照常展示）
		"collected_rewards": _battle_reward_collector.duplicate(true),
	}
	# v34 B2：回填战斗卡成长（结算面板缴获页消费）
	if not growth_bak.is_empty():
		last_battle_reward_summary["card_growth"] = growth_bak

	# Toast 播报（分层反馈：Toast=即时，面板=明细）
	var toast_lines: PackedStringArray = []
	# v6.35 黑门 2.0: 通关时刻优先播报
	if not summary.is_empty() and bool(summary.get("gate_cleared", false)):
		toast_lines.append("✦ 黑门本体已击碎！")
		if bool(summary.get("gate_first_clear", false)):
			toast_lines.append("★ 首次通关 · 黑门已平息")
	toast_lines.append("黑门征程结束：第 %d 波 · 击杀 %d" % [waves, kills])
	if not summary.is_empty():
		toast_lines.append("分数 %d" % int(summary.get("score", 0)))
		if bool(summary.get("is_best", false)):
			toast_lines.append("★ 新纪录！")
		var marrow: int = int(summary.get("marrow", 0))
		if marrow > 0:
			var cap_note: String = "（本周封顶）" if bool(summary.get("marrow_capped", false)) else ""
			toast_lines.append("星髓 +%d%s" % [marrow, cap_note])
	if SignalBus != null and SignalBus.has_signal("show_toast"):
		SignalBus.show_toast.emit(" · ".join(toast_lines))

	if _is_afk_running():
		return_to_prep()
	elif main_scene and main_scene.has_method("show_battle_result"):
		main_scene.call_deferred("show_battle_result", false)


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
	# v27: 显式选关 = 放弃挂起的黑门无尽 run（防串场：点黑门后改打普通关）
	if _is_endless_battle and current_phase != GamePhase.BATTLE:
		_is_endless_battle = false
	if current_level == new_level:
		return
	current_level = new_level
	if DEBUG_GAME_LOG:
		pass  # LOG: 当前关卡设为
	current_level_changed.emit(current_level)
	# v6.9: 进入势力领地关卡时，刷新该势力的动态委托
	_maybe_refresh_faction_quests_for_level(current_level)

## v6.9: 若当前关卡属于某组织历史辖区（21关起），刷新该组织的动态委托
func _maybe_refresh_faction_quests_for_level(level: int) -> void:
	var qm: Node = get_node_or_null("/root/QuestManager")
	if qm == null or not qm.has_method("refresh_faction_quests"):
		return
	var LevelInfo = preload("res://data/level_information.gd").new()
	var faction_id: String = LevelInfo.get_level_faction(level)
	if faction_id.is_empty():
		return  # 1-20关无主之地，不生成动态任务
	qm.refresh_faction_quests(faction_id)

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
	var _CompanyDefs = preload("res://data/company_definitions.gd")
	var _stars: int = int(_MPE.evaluate(_current_phase_master).get("stars", 3))
	var _drop_bag: Node = get_node_or_null("/root/IntelItemBag")
	# enemy_type 按相位师所属势力的改造偏好派生；势力无偏好/查不到时回退 infantry
	# v8.2 B1修复：敌方 faction(steel/flame/...) 需映射到玩家势力 ID 才能匹配 FACTION_MOD_BIAS
	# v6.22: 表已搬家至 CompanyDefinitions.FACTION_MOD_BIAS（faction_conquest_buffs.gd 已删）
	var _pm_faction: String = String(_current_phase_master.get("faction", ""))
	var _pm_player_faction: String = _enemy_faction_to_player_faction(_pm_faction)
	var _pm_enemy_type: String = "infantry"
	var _bias: Array = _CompanyDefs.FACTION_MOD_BIAS.get(_pm_player_faction, [])
	if not _bias.is_empty():
		_pm_enemy_type = String(_bias[0])
	var _pm_power_tier: int = _PT.get_tier_by_stars(_stars)
	# v6.14: 掉落时代过滤（对齐安装侧 era_band 硬门）——相位师战利品不再掉当前时代装不上的图纸
	var _pm_max_era: int = clampi(LevelEras.get_era(current_level), 0, 4)
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
		var _mod_drop: Dictionary = IntelManualItems.roll_random_mod_blueprint(_pm_enemy_type, "boss", _pm_power_tier, _bias, _pm_max_era)
		if not _mod_drop.is_empty() and _drop_bag and _drop_bag.has_method("add_item"):
			_drop_bag.add_item(String(_mod_drop.get("item_type", "")), 1)
			# v7.x 胜利面板漏显修复：相位师改造蓝图记入本局收集器（_mod_drop dict 已含 name/rarity 字段）
			collect_battle_mod_blueprint(String(_mod_drop.get("item_type", "")), String(_mod_drop.get("name", "")), String(_mod_drop.get("rarity", "")), "相位师战利品")
	# 30% 额外1个
	if randf() < 0.30:
		var _mod_drop2: Dictionary = IntelManualItems.roll_random_mod_blueprint(_pm_enemy_type, "boss", _pm_power_tier, _bias, _pm_max_era)
		if not _mod_drop2.is_empty() and _drop_bag and _drop_bag.has_method("add_item"):
			_drop_bag.add_item(String(_mod_drop2.get("item_type", "")), 1)
			# v7.x 胜利面板漏显修复
			collect_battle_mod_blueprint(String(_mod_drop2.get("item_type", "")), String(_mod_drop2.get("name", "")), String(_mod_drop2.get("rarity", "")), "相位师战利品")

	# v7.x: 特殊相位仪掉落（仅相位师掉落，不在商店出售）
	# 低星级（5★及以下）不掉特殊相位仪（保留追求感）
	# 2026-09-19 修复：此块原本缩进嵌进上方 `if randf() < 0.30:` 块，设计值被再乘 0.30（实际 6%/12%）
	# 2026-09-20 用户拍板"掉落再低点"：设计值 20%/40% 下调为 12%/24%（保持 6★:7★ = 1:2 梯度）
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

	# v6.22: 任务委托 attack/defend 战争框架已退役（原 notify_phase_master_defeated 挂钩删除）

	if not faction_id.is_empty() and DEBUG_GAME_LOG:
		pass  # LOG: 势力声望 +30

	# 记录到战斗奖励摘要（v6.4: 使用 Boss 掉落表实际累计值，而非固定 50/10）
	last_battle_reward_summary["phase_master_victory"] = master_name
	last_battle_reward_summary["extra_nano"] = extra_nano_total if extra_nano_total > 0 else 50
	last_battle_reward_summary["extra_energy"] = extra_energy_total if extra_energy_total > 0 else 10

	# v25.3 相位师首杀"解锁改造模块"已随账号解锁集退役（解锁集无 UI/门禁消费方，
	# 奖励是幻影——玩家收到一条哪都看不到的解锁；改造获取回归蓝图掉落单通道）

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
# 特殊相位仪掉率（v6.19.2 用户拍板 2026-09-20：设计值 20%/40% 下调至此；6★:7★ 恒 1:2）
const SPECIAL_INST_DROP_CHANCE_6STAR: float = 0.12
const SPECIAL_INST_DROP_CHANCE_7STAR: float = 0.24

func _maybe_roll_special_instrument_drop(stars: int, faction: String) -> String:
	if stars < 6:
		return ""
	var drop_chance: float = SPECIAL_INST_DROP_CHANCE_7STAR if stars >= 7 else SPECIAL_INST_DROP_CHANCE_6STAR
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

## v27.15（TODO#10 复活）：普通战斗相位仪掉落——胜利 8% 掉 1 台未解锁势力专属仪。
## 池 = is_generic=false 且 star ≤ 5 且未解锁；权重按 star 递减（32/16/8/4/2）——
## 低星常见、高星珍稀；6-7★（含主动大招招牌）不进池，保持商店声望渠道稀缺。
## 全解锁后返回空串，掉落链自然熄火；AFK 推图同样适用（自限性：池只减不增）。
func _maybe_roll_regular_instrument_drop() -> String:
	if randf() >= 0.08:
		return ""
	if PhaseInstrumentManager == null or not PhaseInstrumentManager.has_method("has_unlocked_instrument"):
		return ""
	var star_weights: Array[int] = [0, 32, 16, 8, 4, 2, 0, 0]  # index=star；6/7★=0 不进池
	var pool: Array[Dictionary] = []
	var weights: Array[int] = []
	for d in PhaseInstrumentsData.get_all():
		if not (d is Dictionary) or bool(d.get("is_generic", true)):
			continue
		var star: int = clampi(int(d.get("star", 1)), 1, 7)
		if star_weights[star] <= 0:
			continue
		var iid: String = String(d.get("id", ""))
		if iid.is_empty() or PhaseInstrumentManager.has_unlocked_instrument(iid):
			continue
		pool.append(d)
		weights.append(star_weights[star])
	if pool.is_empty():
		return ""
	var total: int = 0
	for w in weights:
		total += w
	var pick: int = randi() % maxi(total, 1)
	for i in pool.size():
		pick -= weights[i]
		if pick < 0:
			return String(pool[i].get("id", ""))
	return ""

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

# v9.x（P2-7范围B）：_get_law_ids_for_families（零调用方死代码）已随法则系统退役移除

func return_to_prep() -> void:
	current_phase = GamePhase.PRE_BATTLE
	# v9.x（P2-7范围B）：法则槽同步回 PLM 已随法则系统退役移除
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
	# v27 黑门无尽 run：波次恒"未耗尽"（_check_win_lose 的 endless 分支永不判胜，
	# 此值仅供 HUD 波次显示兜底；真实出兵由 spawn 系统 endless 分支驱动）
	if _is_endless_battle:
		return 999999
	return LevelEras.get_wave_total_for_level(max(1, level))

func get_enemy_wave_interval_for_level(level: int) -> float:
	if _is_endless_battle:
		# v6.35 黑门 2.0: 通关弹窗待选择期间暂停刷兵(选「继续深入」后恢复)
		var ebm: Node = get_node_or_null("/root/EndlessBlackgateManager")
		if ebm != null and bool(ebm.get("gate_choice_pending")):
			return 3600.0  # 1 小时=事实暂停;不用 tree.paused(会冻住演出/UI 链)
		return 7.0  # 星冥带节奏（设计 §5.2，与近未来同档）
	return LevelEras.get_wave_interval_for_level(max(1, level))

func get_enemy_spawn_count_for_wave(level: int, wave_index: int) -> int:
	return LevelEras.get_spawn_count_for_wave(max(1, level), wave_index)


func get_enemy_spawn_count_for_wave_card_grid(level: int, wave_index: int) -> int:
	return LevelEras.get_spawn_count_for_wave_card_grid(max(1, level), wave_index)

func get_drop_rate_multiplier(level: int) -> float:
	return LevelEras.get_drop_rate_multiplier(max(1, level))

const BasicResources = preload("res://data/basic_resources.gd")
const EnemyPhaseEquipment = preload("res://data/enemy_phase_equipment.gd")
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



func _grant_phase_field_xp_for_victory() -> void:
	if not PhaseInstrumentManager:
		return
	if not PhaseInstrumentManager.has_method("grant_phase_field_xp"):
		return
	var total_xp: int = LevelEras.get_base_xp_for_level(current_level)
	# v6.2: 符文之语探索奖励加成
	total_xp = int(float(total_xp) * (1.0 + _get_rune_special_bonus("on_explore_bonus")))
	PhaseInstrumentManager.grant_phase_field_xp("battle_victory", total_xp)

## v26.13(gameplay)：败局相位场经验——胜利值的 30%（与战斗卡失败比例同口径）
func _grant_phase_field_xp_for_defeat() -> void:
	if not PhaseInstrumentManager:
		return
	if not PhaseInstrumentManager.has_method("grant_phase_field_xp"):
		return
	var total_xp: int = LevelEras.get_base_xp_for_level(current_level)
	total_xp = int(float(total_xp) * 0.3 * (1.0 + _get_rune_special_bonus("on_explore_bonus")))
	if total_xp <= 0:
		return
	PhaseInstrumentManager.grant_phase_field_xp("battle_defeat", total_xp)

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
		# v21.x 修复：检查 instance_id 是否有效（非空且在 Registry 中存在）
		var iid: String = String(platform.instance_id) if "instance_id" in platform else ""
		if iid.is_empty():
			# instance_id 为空说明是模板卡，无法获得经验
			continue
		if not ir.has_method("has_instance") or not ir.has_instance(iid):
			# instance_id 不在 Registry 中，可能是数据不一致
			continue
		if not (iid in instance_ids):
			instance_ids.append(iid)
	if instance_ids.is_empty():
		return
	# v21.x 重写：经验按关卡数计算（关卡越高经验越多），除以上场卡数
	# 设计基准（用户定稿 2026-08-26）：9 张卡上场，一个时代 40 场次升到 Lv20+
	# 公式：胜利 = 关卡数×130，每击杀 = 关卡数；失败按 30% 给
	var lvl: int = clampi(current_level, 1, 100)
	var base_exp: int = lvl * 130 if player_won else int(float(lvl) * 130.0 * BattleExperienceConfig.BATTLE_LOSE_EXP_RATIO)
	# 击杀数：从 BattleManager 获取（如可用）
	var kill_count: int = 0
	if BattleManager and BattleManager.has_method("get_player_kill_count"):
		kill_count = int(BattleManager.get_player_kill_count())
	var total_exp: int = base_exp + kill_count * lvl
	# 技能树经验加成
	var pmsm: Node = get_node_or_null("/root/PhaseMasterSkillManager")
	if pmsm != null and pmsm.has_method("get_active_effects"):
		var effects: Dictionary = pmsm.get_active_effects()
		var exp_bonus: float = float(effects.get("experience_bonus", 0.0))
		if exp_bonus > 0.0:
			total_exp = int(float(total_exp) * (1.0 + exp_bonus))
	# v26.15b: 势力 xp_bonus（resource 桶此前零消费）——叠加在技能树加成之后
	var fsm_xp: Node = get_node_or_null("/root/FactionSystemManager")
	if fsm_xp != null and fsm_xp.has_method("get_active_faction_skill_effects"):
		var xp_bonus: float = float(fsm_xp.get_active_faction_skill_effects().get("resource", {}).get("xp_bonus", 0.0))
		if xp_bonus > 0.0:
			total_exp = int(float(total_exp) * (1.0 + xp_bonus))
	# 平分给上场卡（设计以 9 卡为基准；少卡时每张更多，升级更快）
	var per_card: int = int(total_exp / instance_ids.size())
	if per_card <= 0:
		return
	# v34 B2 卡牌经验结算可见：收集每张上阵卡的 +XP 与升级事件，入结算摘要供
	# mvp_panel 缴获页「战斗卡成长」区块展示（发钱逻辑不变，纯展示层附带数据）
	var growth_rows: Array = []
	for iid in instance_ids:
		var leveled: bool = ir.add_experience(iid, per_card)
		var lv_after: int = ir.get_card_level(iid) if ir.has_method("get_card_level") else 0
		var disp_name: String = iid
		if ir.has_method("get_instance"):
			var inst_card: CardResource = ir.get_instance(iid)
			if inst_card != null:
				disp_name = String(inst_card.display_name)
		growth_rows.append({
			"iid": iid,
			"name": disp_name,
			"xp": per_card,
			"lv": lv_after,
			"leveled": leveled,
		})
	last_battle_reward_summary["card_growth"] = growth_rows
	# v26 批次4：兵棋室 Lv3 沙盘演武——1 张未上阵卡后台吃 50% 单卡经验
	var bunker_gm: Node = get_node_or_null("/root/BunkerManager")
	if bunker_gm != null and bunker_gm.has_method("grant_sandbox_exp"):
		var sb_exp: int = bunker_gm.grant_sandbox_exp(per_card)
		if sb_exp > 0 and DEBUG_GAME_LOG:
			pass  # 沙盘经验静默入账（UI 在兵棋室面板展示在盘卡）

func _snapshot_battle_reward_baselines() -> void:
	# v9.x（P2-7范围B）：知识值基线快照已随法则系统退役移除（本函数保留为空操作，
	# 战斗结束链路的调用点 :413 无需改动）
	pass


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
