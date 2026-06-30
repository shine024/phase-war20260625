extends Node
## v6.0: 情报发现管理器
## 负责：
##   - 战斗结束时计算各维情报增长
##   - 检测并触发揭示事件
##   - 检测敌源MOD解锁条件
##   - 检测情报进化分支发现条件
##   - 生成战斗结算UI所需的情报收获数据
##
## 依赖：
##   - IntelManual（情报数据）
##   - IntelDimensions（维度定义）
##   - IntelRevealEvents（揭示事件表）
##   - EnemyOriginMods（敌源MOD定义）
##   - EnemyArchetypes（敌人类型映射）

const IntelDimensions = preload("res://data/intel_dimensions.gd")
const IntelRevealEvents = preload("res://data/intel_reveal_events.gd")

# ── 信号 ──────────────────────────────────────────────────────────

## 🆕 情报维度变化 signal(card_id, dimension, old_val, new_val, source)
signal intel_harvest_generated(harvest_data: Dictionary)
## 🆕 揭示事件触发 signal(card_id, enemy_type, dimension, tier, event_data)
signal intel_reveal_triggered(card_id: String, enemy_type: String, dimension: String, tier: int, event_data: Dictionary)
## 🆕 敌源MOD碎片掉落 signal(mod_id, amount, total_fragments)
signal eom_fragment_dropped(mod_id: String, amount: int, total: int)
## 🆕 敌源MOD解锁 signal(mod_id)
signal eom_unlocked(mod_id: String)

# ── 内部状态 ──────────────────────────────────────────────────────

## 已触发的揭示事件缓存: event_key -> true
var _triggered_reveals: Dictionary = {}

## 已解锁的敌源MOD缓存: mod_id -> true
var _unlocked_eom: Dictionary = {}

## 敌源MOD碎片进度: mod_id -> int
var _eom_fragments: Dictionary = {}

## v6.6: 揭示事件奖励状态（持久化）
## 属性可见性等级: enemy_type -> 最高可见性 value (name_and_type/full_stats/hidden_stats/behavior_summary/skill_list/equipment_type)
var _stat_visibility: Dictionary = {}
## 已解锁的世界观页面ID集合: page_id -> true
var _unlocked_lore_pages: Dictionary = {}

## v6.6: 脏标记，避免结算帧内同步写磁盘
var _state_dirty: bool = false
var _save_pending: bool = false

# ── 生命周期 ──────────────────────────────────────────────────────

func _ready() -> void:
	# v6.6: 移除自加载，由 SaveManager 统一加载
	## 连接IntelManual信号
	var im: Node = get_node_or_null("/root/IntelManual")
	if im:
		if im.has_signal("intel_dimension_changed"):
			im.intel_dimension_changed.connect(_on_intel_dimension_changed)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_state_dirty = true  ## 确保退出时强制保存
		_save_state()

# ── 存档 ───────────────────────────────────────────────────────────

const SaveUtils = preload("res://scripts/save_utils.gd")
const STATE_SAVE_NAME: String = "intel_discovery_state"
const PowerTiers = preload("res://data/power_tiers.gd")
const FactionConquestBuffs = preload("res://data/faction_conquest_buffs.gd")

## v6.6: 统一存档接口（供 SaveManager 调用，无视脏标记——SaveManager 调用即权威保存点）
func save_state() -> Dictionary:
	return {
		"triggered_reveals": _triggered_reveals.duplicate(),
		"unlocked_eom": _unlocked_eom.duplicate(),
		"eom_fragments": _eom_fragments.duplicate(),
		"stat_visibility": _stat_visibility.duplicate(),
		"unlocked_lore_pages": _unlocked_lore_pages.duplicate(),
	}

## v6.6: 统一存档加载接口。data 为空时尝试兼容读取旧独立文件
func load_state(data: Dictionary) -> void:
	var src: Dictionary = data
	if src.is_empty():
		src = SaveUtils.load_data_from_file(STATE_SAVE_NAME)
		if src.is_empty():
			return
	_triggered_reveals = src.get("triggered_reveals", {})
	_unlocked_eom = src.get("unlocked_eom", {})
	_eom_fragments = src.get("eom_fragments", {})
	_stat_visibility = src.get("stat_visibility", {})
	_unlocked_lore_pages = src.get("unlocked_lore_pages", {})

func _save_state() -> void:
	if not _state_dirty:
		return
	SaveUtils.save_data_to_file(save_state(), STATE_SAVE_NAME)
	_state_dirty = false

## 延迟保存：通过 call_deferred 避免在结算链内同步 I/O
func _deferred_save_if_dirty() -> void:
	if not _state_dirty:
		return
	if _save_pending:
		return
	_save_pending = true
	var tree := get_tree()
	if tree == null:
		_save_pending = false
		_save_state()
		return
	var t := tree.create_timer(0.3)
	t.timeout.connect(func() -> void:
		_save_pending = false
		_save_state()
	)

## 兼容旧调用（部分内部逻辑仍调用 _load_state）
func _load_state() -> void:
	load_state({})

## v6.6: 新游戏重置——清空所有字段，不读旧文件（区别于 load_state({}) 的兼容读取）
func reset_progress() -> void:
	_triggered_reveals.clear()
	_unlocked_eom.clear()
	_eom_fragments.clear()
	_stat_visibility.clear()
	_unlocked_lore_pages.clear()
	_state_dirty = false

# ── 核心接口：战斗情报收获生成 ───────────────────────────────────

## 战斗结束时调用，生成完整的情报收获数据
## defeated_enemies: [{"archetype_id": str, "rank": str, "enemy_type": str}]
## victory_stars: 0-3
## has_recon_unit: bool
## Returns: 完整的情报收获数据字典（用于UI展示）
func generate_battle_intel_harvest(
	defeated_enemies: Array,
	victory_stars: int,
	has_recon_unit: bool,
	wave_env: Dictionary
) -> Dictionary:
	var harvests: Array = []         ## 情报维度增长列表
	var reveal_events: Array = []    ## 触发的揭示事件
	var eom_drops: Array = []        ## 敌源MOD碎片掉落
	var intel_item_drops: Array = []  ## v6.0: 情报道具掉落

	var im: Node = get_node_or_null("/root/IntelManual")
	if im == null:
		return {"harvests": [], "reveal_events": [], "eom_drops": [], "intel_item_drops": []}

	## 收集本次击败的敌人ID（用于检测首次遭遇和避免重复）
	var defeated_ids: Dictionary = {}
	for enemy_info in defeated_enemies:
		if enemy_info is Dictionary:
			var aid: String = enemy_info.get("archetype_id", "")
			if not aid.is_empty():
				defeated_ids[aid] = true

	## 处理每个击败的敌人
	for enemy_info in defeated_enemies:
		if not enemy_info is Dictionary:
			continue
		var archetype_id: String = enemy_info.get("archetype_id", "")
		var rank: String = enemy_info.get("rank", "normal")
		var enemy_type: String = enemy_info.get("enemy_type", _guess_enemy_type(archetype_id))
		if enemy_type.is_empty():
			enemy_type = "infantry"  ## 兜底

		## 1. 注册首次遭遇
		if im.has_method("register_first_encounter"):
			var enc_delta: float = im.register_first_encounter(archetype_id, enemy_type)
			if enc_delta > 0.001:
				_harvest_first_encounter(harvests, archetype_id, enemy_type, enc_delta)

		## 2. 注册击败情报
		if im.has_method("register_defeat"):
			var deltas: Dictionary = im.register_defeat(archetype_id, rank, enemy_type, victory_stars)
			_harvest_defeat(harvests, archetype_id, enemy_type, rank, deltas)

		## 3. 侦察加成
		if has_recon_unit and im.has_method("register_recon"):
			var recon_deltas: Dictionary = im.register_recon(archetype_id, 0.1, enemy_type)
			_harvest_recon(harvests, archetype_id, recon_deltas)

		## 4. 检查揭示事件
		var new_reveals: Array = _check_reveals(archetype_id, enemy_type, im)
		reveal_events.append_array(new_reveals)

		## 5. 检查敌源MOD碎片掉落
		var new_eom_drops: Array = _check_eom_drops(enemy_type, rank)
		eom_drops.append_array(new_eom_drops)

	## 按card_id合并harvests
	var merged: Dictionary = _merge_harvests(harvests)

	## v6.0: 情报道具掉落
	intel_item_drops = _roll_intel_item_drops(defeated_enemies, victory_stars, im)
	## 发放到IntelItemBag
	for item in intel_item_drops:
		if item is Dictionary:
			var item_type: String = item.get("item_type", "")
			var bag: Node = get_node_or_null("/root/IntelItemBag")
			if bag and bag.has_method("add_item") and not item_type.is_empty():
				bag.add_item(item_type, 1)

	## v6.6: 结算敌源MOD碎片 → 写入计数，碎片满额时自动解锁
	## EOM 碎片由 EnemyOriginModManager 统一管理（避免双计数）
	if not eom_drops.is_empty():
		var eom_mgr: Node = get_node_or_null("/root/EnemyOriginModManager")
		if eom_mgr and eom_mgr.has_method("settle_battle_eom_drops"):
			var settle_result: Dictionary = eom_mgr.settle_battle_eom_drops(eom_drops)
			var unlocked_now: Array = settle_result.get("unlocked_now", [])
			for mod_id in unlocked_now:
				## 同步本管理器的 _unlocked_eom 缓存（供揭示事件去重）
				_unlocked_eom[String(mod_id)] = true
				eom_unlocked.emit(String(mod_id))

	## v6.6: 情报更新后检查情报进化分支发现（分支依赖情报进度）
	var iem: Node = get_node_or_null("/root/IntelEvolutionManager")
	if iem and iem.has_method("check_and_discover_branches"):
		iem.check_and_discover_branches()

	var result: Dictionary = {
		"harvests": merged.get("items", []),
		"reveal_events": reveal_events,
		"eom_drops": eom_drops,
		"intel_item_drops": intel_item_drops,  ## v6.0
	}
	intel_harvest_generated.emit(result)
	# v6.6 性能优化：不再同步写磁盘，改为标记脏位由 battle_ended 信号链延迟保存
	_state_dirty = true
	call_deferred("_deferred_save_if_dirty")
	return result

# ── 揭示事件检测 ──────────────────────────────────────────────────

## 检查某卡是否触发了新的揭示事件
## v6.7: 单维度化，去掉4维迭代，直接用 intel_progress 查 {enemy_type}_{tier} 事件
func _check_reveals(card_id: String, enemy_type: String, im: Node) -> Array:
	var new_events: Array = []
	var dim: String = "intel"  ## 单维度固定标识
	var progress: float = im.get_intel_progress(card_id) if im.has_method("get_intel_progress") else 0.0
	var current_tier: int = IntelDimensions.get_reveal_tier(progress)
	if current_tier < 0:
		return new_events
	## 检查 tier 0 到 current_tier 的所有揭示
	for t in range(current_tier + 1):
		var event_key: String = IntelRevealEvents.make_event_key(enemy_type, dim, t)
		if _triggered_reveals.has(event_key):
			continue
		if not IntelRevealEvents.has_event(enemy_type, dim, t):
			continue
		var event_data: Dictionary = IntelRevealEvents.get_event(enemy_type, dim, t)
		_triggered_reveals[event_key] = true
		new_events.append({
			"event_key": event_key,
			"card_id": card_id,
			"enemy_type": enemy_type,
			"dimension": dim,
			"tier": t,
			"title": event_data.get("title", ""),
			"desc": event_data.get("desc", ""),
			"icon": event_data.get("icon", "⭐"),
			"rewards": event_data.get("rewards", []),
		})
		intel_reveal_triggered.emit(card_id, enemy_type, dim, t, event_data)
		## 处理奖励：敌源MOD解锁、弱点加成、掉落率等
		_process_reveal_rewards(event_data, enemy_type)
	return new_events

## 处理揭示事件的奖励
func _process_reveal_rewards(event_data: Dictionary, enemy_type: String) -> void:
	var rewards: Array = event_data.get("rewards", [])
	for reward in rewards:
		if not reward is Dictionary:
			continue
		var rtype: String = reward.get("type", "")
		match rtype:
			"eom_unlock":
				var mod_id: String = reward.get("mod_id", "")
				if not mod_id.is_empty() and not _unlocked_eom.has(mod_id):
					_unlocked_eom[mod_id] = true
					eom_unlocked.emit(mod_id)
					# 同步到 EnemyOriginModManager
					var eom_mgr: Node = get_node_or_null("/root/EnemyOriginModManager")
					if eom_mgr and eom_mgr.has_method("unlock_mod"):
						eom_mgr.unlock_mod(mod_id)
			"stat_visibility":
				# 记录属性可见性等级（取较高优先级）
				var vis: String = reward.get("value", "")
				if not vis.is_empty():
					_stat_visibility[enemy_type] = vis
			"intel_branch_unlock":
				# 直接解锁进化分支（标记为已发现）
				var branch_id: String = reward.get("branch_id", "")
				if not branch_id.is_empty():
					var iem: Node = get_node_or_null("/root/IntelEvolutionManager")
					if iem and iem.has_method("force_discover_branch"):
						iem.force_discover_branch(branch_id)
			"intel_branch_hint", "eom_unlock_hint":
				# 纯文字提示，仅通过揭示事件弹窗展示，无需存储
				pass
			"lore_page":
				# 解锁世界观页面
				var page_id: String = reward.get("page_id", "")
				if not page_id.is_empty():
					_unlocked_lore_pages[page_id] = true
					var lm: Node = get_node_or_null("/root/LoreManager")
					if lm and lm.has_method("unlock_lore"):
						lm.unlock_lore(page_id)
	# 奖励状态变更后标记脏位
	_state_dirty = true
	call_deferred("_deferred_save_if_dirty")

# ── 奖励查询接口（供战斗/掉落系统消费） ───────────────────────────

## 获取某敌人类型的属性可见性等级（空字符串=不可见）
func get_stat_visibility(enemy_type: String) -> String:
	return String(_stat_visibility.get(enemy_type, ""))

## 检查某世界观页面是否已解锁
func is_lore_page_unlocked(page_id: String) -> bool:
	return _unlocked_lore_pages.has(page_id)

# ── 敌源MOD碎片掉落 ──────────────────────────────────────────────

## 检查是否掉落敌源MOD碎片
## v6.4: 实现 TODO——按 enemy_type 匹配 EOM 的 source_enemy_type，精英/boss 掉落概率更高
func _check_eom_drops(enemy_type: String, rank: String) -> Array:
	var drops: Array = []
	const EnemyOriginModsRef = preload("res://data/enemy_origin_mods.gd")
	var all_ids: Array = EnemyOriginModsRef.get_all_mod_ids()
	if all_ids.is_empty():
		return drops
	# 掉落概率按敌人等级：normal 10%, elite 30%, boss 60%
	var drop_chance: float = 0.10
	if rank == "elite":
		drop_chance = 0.30
	elif rank == "boss":
		drop_chance = 0.60
	# 遍历所有 EOM，匹配 source_enemy_type
	for mod_id in all_ids:
		var mod_data: Dictionary = EnemyOriginModsRef.get_mod(mod_id)
		if mod_data.is_empty():
			continue
		var source_type: String = String(mod_data.get("source_enemy_type", ""))
		if source_type.is_empty() or source_type != enemy_type:
			continue
		# 已解锁的不再掉落碎片
		if _unlocked_eom.has(mod_id):
			continue
		if randf() <= drop_chance:
			drops.append({
				"type": "eom_fragment",
				"mod_id": mod_id,
				"source_enemy_type": enemy_type,
				"count": 1
			})
	return drops

# ── 敌源MOD查询接口 ──────────────────────────────────────────────

## 获取所有已解锁的敌源MOD ID列表
func get_unlocked_eom_ids() -> Array[String]:
	return _unlocked_eom.keys()

## 检查敌源MOD是否已解锁
func is_eom_unlocked(mod_id: String) -> bool:
	return _unlocked_eom.has(mod_id)

## 获取敌源MOD碎片数量
func get_eom_fragments(mod_id: String) -> int:
	return int(_eom_fragments.get(mod_id, 0))

## 添加敌源MOD碎片
func add_eom_fragments(mod_id: String, amount: int) -> int:
	_eom_fragments[mod_id] = int(_eom_fragments.get(mod_id, 0)) + amount
	eom_fragment_dropped.emit(mod_id, amount, int(_eom_fragments[mod_id]))
	# v6.6: 延迟保存，避免结算帧同步 I/O
	_state_dirty = true
	if not _save_pending:
		call_deferred("_deferred_save_if_dirty")
	return int(_eom_fragments[mod_id])

# ── 揭示事件查询接口 ──────────────────────────────────────────────

## 检查揭示事件是否已触发
func is_reveal_triggered(enemy_type: String, dimension: String, tier: int) -> bool:
	var key: String = IntelRevealEvents.make_event_key(enemy_type, dimension, tier)
	return _triggered_reveals.has(key)

## 获取所有已触发的揭示事件key
func get_triggered_reveal_keys() -> Array[String]:
	return _triggered_reveals.keys()

# ── 内部工具 ──────────────────────────────────────────────────────

## 猜测敌人类型（基于archetype_id前缀）
func _guess_enemy_type(archetype_id: String) -> String:
	if archetype_id.is_empty():
		return "infantry"
	var lower: String = archetype_id.to_lower()
	if "flame" in lower or "fire" in lower:
		return "flame"
	if "armor" in lower or "tank" in lower or "pz" in lower or "tiger" in lower or "t72" in lower or "m1a" in lower or "ft17" in lower:
		return "heavy_armor"
	if "artillery" in lower or "howitzer" in lower or "m270" in lower or "mortar" in lower or "m81" in lower or "zsu" in lower:
		return "artillery"
	if "stealth" in lower or "spectre" in lower or "spy" in lower:
		return "stealth"
	if "air" in lower or "mig" in lower or "fighter" in lower or "drone" in lower or "heli" in lower or "ah64" in lower or "ah1" in lower:
		return "air"
	if "boss" in lower or "nano" in lower:
		return "boss_nano"
	if "phase_master" in lower:
		return "boss_phase"
	if "scout" in lower or "recon" in lower:
		return "scout"
	if "medic" in lower or "repair" in lower:
		return "medic"
	if "command" in lower or "hq" in lower:
		return "command"
	return "infantry"

## 合并情报收获数据（按card_id分组）
func _merge_harvests(harvests: Array) -> Dictionary:
	var by_card: Dictionary = {}
	for h in harvests:
		if not h is Dictionary:
			continue
		var cid: String = h.get("card_id", "")
		if cid.is_empty():
			continue
		if not by_card.has(cid):
			by_card[cid] = {
				"card_id": cid,
				"enemy_type": h.get("enemy_type", ""),
				"dimensions": {},
				"first_encounter": false,
			}
		var entry: Dictionary = by_card[cid]
		entry["enemy_type"] = h.get("enemy_type", entry.get("enemy_type", ""))
		if h.get("first_encounter", false):
			entry["first_encounter"] = true
		var dims: Dictionary = h.get("dimensions", {})
		var entry_dims: Dictionary = entry.get("dimensions", {})
		for dim in dims:
			if not entry_dims.has(dim):
				entry_dims[dim] = {"old_val": 0.0, "new_val": 0.0, "delta": 0.0}
			entry_dims[dim]["delta"] += float(dims[dim])
		entry["dimensions"] = entry_dims
	## 修正new_val = max(old_val + delta, 1.0)
	return {"items": by_card.values()}

## 构建首次遭遇情报收获条目
## v6.7: 单维度化，dimensions 固定为 {"intel": total_delta}
func _harvest_first_encounter(harvests: Array, card_id: String, enemy_type: String, total_delta: float) -> void:
	harvests.append({
		"card_id": card_id,
		"enemy_type": enemy_type,
		"first_encounter": true,
		"dimensions": {"intel": total_delta},
	})

## 构建击败情报收获条目
func _harvest_defeat(harvests: Array, card_id: String, enemy_type: String, rank: String, deltas: Dictionary) -> void:
	if deltas.is_empty():
		return
	harvests.append({
		"card_id": card_id,
		"enemy_type": enemy_type,
		"rank": rank,
		"first_encounter": false,
		"dimensions": deltas,
	})

## IntelManual情报维度变化回调
func _on_intel_dimension_changed(card_id: String, dimension: String, old_val: float, new_val: float, source: String) -> void:
	_check_and_fire_reveals(card_id)

## 触发揭示检查（被动回调用）
func _check_and_fire_reveals(card_id: String) -> void:
	var im: Node = get_node_or_null("/root/IntelManual")
	if im == null:
		return
	var enemy_type: String = _guess_enemy_type(card_id)
	_check_reveals(card_id, enemy_type, im)

## 构建侦察情报收获条目
func _harvest_recon(harvests: Array, card_id: String, deltas: Dictionary) -> void:
	if deltas.is_empty():
		return
	harvests.append({
		"card_id": card_id,
		"enemy_type": "",
		"rank": "",
		"first_encounter": false,
		"dimensions": deltas,
		"source": "recon",
	})

# ── v7.0: 蓝图掉落 ───────────────────────────────────────

const IntelManualItems = preload("res://data/intel_manual_items.gd")

## 根据击败敌人和星级，随机掉落蓝图
## 改造蓝图（基于敌人类型）/ 进化蓝图（精英/Boss）
## v6.14: 注入占领势力掉落维度——当前关占领势力的 drop_mul 调整掉率，mod_pool_bias 调整改造类型偏好
func _roll_intel_item_drops(
	defeated_enemies: Array,
	victory_stars: int,
	im: Node
) -> Array:
	var drops: Array = []
	## 基础掉落率：每个敌人独立判定
	var base_chance: float = 0.12  ## 12%
	if victory_stars >= 3:
		base_chance = 0.22
	elif victory_stars >= 2:
		base_chance = 0.17

	# v6.14: 查当前关占领势力掉落 buff（drop_mul + mod_pool_bias）
	var occupation_drop_mul: float = 1.0
	var occupation_mod_bias: Array = []
	var fsm: Node = get_node_or_null("/root/FactionSystemManager")
	var gm: Node = get_node_or_null("/root/GameManager")
	if fsm != null and fsm.has_method("get_level_occupation") and gm != null:
		var cur_level: int = int(gm.get("current_level")) if "current_level" in gm else 1
		var occ_fid: String = String(fsm.get_level_occupation(cur_level))
		if not occ_fid.is_empty() and fsm.has_method("get_faction_level"):
			var flvl: int = int(fsm.get_faction_level(occ_fid))
			var buff: Dictionary = FactionConquestBuffs.get_buff(occ_fid, flvl)
			occupation_drop_mul = float(buff.get("drop_mul", 1.0))
			occupation_mod_bias = buff.get("mod_pool_bias", [])

	for enemy_info in defeated_enemies:
		if not enemy_info is Dictionary:
			continue
		var rank: String = enemy_info.get("rank", "normal")
		var enemy_type: String = enemy_info.get("enemy_type", _guess_enemy_type(enemy_info.get("archetype_id", "")))

		var rank_mult: float = 1.0
		match rank:
			"boss":
				rank_mult = 2.5
			"elite":
				rank_mult = 1.8
			_:
				rank_mult = 1.0

		# v6.14: 占领势力 drop_mul 乘进掉率（≤1.5，与星级/势力等级共同作用）
		var effective_chance: float = base_chance * rank_mult * occupation_drop_mul
		if randf() > effective_chance:
			continue

		## 随机选择掉落改造蓝图或进化蓝图
		var is_evolution = randf() < 0.2  ## 20%概率进化蓝图
		var item: Dictionary = {}

		if is_evolution and rank != "normal":
			## 进化蓝图（仅精英/Boss）
			item = IntelManualItems.roll_random_evolution_blueprint(rank)
		else:
			## 改造蓝图（基于敌人类型）
			# v6.14: 传入 power_tier（rank 映射）和占领势力 mod_pool_bias
			var power_tier: int = PowerTiers.get_tier_by_rank(rank)
			item = IntelManualItems.roll_random_mod_blueprint(enemy_type, rank, power_tier, occupation_mod_bias)

		if not item.is_empty():
			drops.append(item)

	return drops
