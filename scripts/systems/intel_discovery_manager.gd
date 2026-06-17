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

# ── 生命周期 ──────────────────────────────────────────────────────

func _ready() -> void:
	_load_state()
	## 连接IntelManual信号
	var im: Node = get_node_or_null("/root/IntelManual")
	if im:
		if im.has_signal("intel_dimension_changed"):
			im.intel_dimension_changed.connect(_on_intel_dimension_changed)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_state()

# ── 存档 ───────────────────────────────────────────────────────────

const SaveUtils = preload("res://scripts/save_utils.gd")
const STATE_SAVE_NAME: String = "intel_discovery_state"

func _save_state() -> void:
	var data: Dictionary = {
		"triggered_reveals": _triggered_reveals.duplicate(),
		"unlocked_eom": _unlocked_eom.duplicate(),
		"eom_fragments": _eom_fragments.duplicate(),
	}
	SaveUtils.save_data_to_file(data, STATE_SAVE_NAME)

func _load_state() -> void:
	var data: Dictionary = SaveUtils.load_data_from_file(STATE_SAVE_NAME)
	_triggered_reveals = data.get("triggered_reveals", {})
	_unlocked_eom = data.get("unlocked_eom", {})
	_eom_fragments = data.get("eom_fragments", {})
	# [DEBUG] print("[IntelDiscoveryManager] 加载完成，已触发揭示 %d，已解锁敌源MOD %d" % [_triggered_reveals.size(), _unlocked_eom.size()])

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

	var result: Dictionary = {
		"harvests": merged.get("items", []),
		"reveal_events": reveal_events,
		"eom_drops": eom_drops,
		"intel_item_drops": intel_item_drops,  ## v6.0
	}
	intel_harvest_generated.emit(result)
	_save_state()
	return result

# ── 揭示事件检测 ──────────────────────────────────────────────────

## 检查某卡是否触发了新的揭示事件
func _check_reveals(card_id: String, enemy_type: String, im: Node) -> Array:
	var new_events: Array = []
	for dim in IntelDimensions.ALL_DIMENSIONS:
		var dim_progress: float = im.get_dimension_progress(card_id, dim) if im.has_method("get_dimension_progress") else 0.0
		var current_tier: int = IntelDimensions.get_reveal_tier(dim_progress)
		if current_tier < 0:
			continue
		## 检查tier 0到current_tier的所有揭示
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
			## 处理奖励：敌源MOD解锁
			_process_reveal_rewards(event_data, enemy_type)
	return new_events

## 处理揭示事件的奖励
func _process_reveal_rewards(event_data: Dictionary, enemy_type: String) -> void:
	var rewards: Array = event_data.get("rewards", [])
	for reward in rewards:
		if not reward is Dictionary:
			continue
		match reward.get("type", ""):
			"eom_unlock":
				var mod_id: String = reward.get("mod_id", "")
				if not mod_id.is_empty() and not _unlocked_eom.has(mod_id):
					_unlocked_eom[mod_id] = true
					eom_unlocked.emit(mod_id)

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
		var mod_data: Dictionary = EnemyOriginModsRef.get_mod_data(mod_id)
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
	_save_state()
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
func _harvest_first_encounter(harvests: Array, card_id: String, enemy_type: String, total_delta: float) -> void:
	var dims: Dictionary = {}
	for dim in IntelDimensions.ALL_DIMENSIONS:
		dims[dim] = total_delta  ## 简化：首次遭遇全部加到basic
	## 首次遭遇实际只加basic
	dims.clear()
	dims[IntelDimensions.DIM_BASIC] = total_delta
	harvests.append({
		"card_id": card_id,
		"enemy_type": enemy_type,
		"first_encounter": true,
		"dimensions": dims,
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

		if randf() > base_chance * rank_mult:
			continue

		## 随机选择掉落改造蓝图或进化蓝图
		var is_evolution = randf() < 0.2  ## 20%概率进化蓝图
		var item: Dictionary = {}

		if is_evolution and rank != "normal":
			## 进化蓝图（仅精英/Boss）
			item = IntelManualItems.roll_random_evolution_blueprint(rank)
		else:
			## 改造蓝图（基于敌人类型）
			item = IntelManualItems.roll_random_mod_blueprint(enemy_type, rank)

		if not item.is_empty():
			drops.append(item)

	return drops
