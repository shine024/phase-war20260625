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
##   - EnemyArchetypes（敌人类型映射）

const IntelDimensions = preload("res://data/intel_dimensions.gd")
const IntelRevealEvents = preload("res://data/intel_reveal_events.gd")
# v21.0: 通知链用（卡名/阈值常量/mod名）
const DefaultCards = preload("res://data/default_cards.gd")
const IntelManualScript = preload("res://scripts/systems/intel_manual.gd")
const ModRegistry = preload("res://scripts/systems/modification_registry.gd")
const LevelEras = preload("res://data/level_eras.gd")   # v6.14: 改造图纸掉落的时代过滤
const EnemyFixedLoadouts = preload("res://data/enemy_fixed_loadouts.gd")   # v6.14.2: 缴获语义

# ── 信号 ──────────────────────────────────────────────────────────

## 🆕 情报维度变化 signal(card_id, dimension, old_val, new_val, source)
signal intel_harvest_generated(harvest_data: Dictionary)
## 🆕 揭示事件触发 signal(card_id, enemy_type, dimension, tier, event_data)
signal intel_reveal_triggered(card_id: String, enemy_type: String, dimension: String, tier: int, event_data: Dictionary)
## 🆕 敌源MOD碎片掉落 signal(mod_id, amount, total_fragments)
## 🆕 敌源MOD解锁 signal(mod_id)

# ── 内部状态 ──────────────────────────────────────────────────────

## 已触发的揭示事件缓存: event_key -> true
var _triggered_reveals: Dictionary = {}

## 已解锁的敌源MOD缓存: mod_id -> true

## 敌源MOD碎片进度: mod_id -> int

## v6.6: 揭示事件奖励状态（持久化）
## 属性可见性等级: enemy_type -> 最高可见性 value (name_and_type/full_stats/hidden_stats/behavior_summary/skill_list/equipment_type)
var _stat_visibility: Dictionary = {}
## 已解锁的世界观页面ID集合: page_id -> true
var _unlocked_lore_pages: Dictionary = {}

## v21.0: 战斗中收集的改造解锁列表（结算时统一展示）
var _pending_mod_unlocks: Array = []

## v33: 击杀瞬间主腿已掷出的情报道具掉落（战后 generate_battle_intel_harvest 收编发放）。
## 只挪掷骰时机不改为账条件：相位师战击杀不预掷（战后 disable 口径不变），
## 败北未消费的 pending 由 battle_started 清空（发放链只在胜利帧 B' 跑，语义与旧版一致）。
var _kill_prerolled_drops: Array = []

## v6.6: 脏标记，避免结算帧内同步写磁盘
var _state_dirty: bool = false
var _save_pending: bool = false

# ── 生命周期 ──────────────────────────────────────────────────────

func _ready() -> void:
	# v6.6: 移除自加载，由 SaveManager 统一加载
	## v33: 击杀预掷池按场清空（败北未消费的 pending 不带到下一场）
	if SignalBus != null and SignalBus.has_signal("battle_started"):
		SignalBus.battle_started.connect(_on_battle_started_clear_prerolls)
	## 连接IntelManual信号
	var im: Node = get_node_or_null("/root/IntelManual")
	if im:
		if im.has_signal("intel_dimension_changed"):
			im.intel_dimension_changed.connect(_on_intel_dimension_changed)
		## v21.0: base 进度跨档（低进化可用）/ mod 解锁 通知链
		if im.has_signal("base_progress_changed"):
			im.base_progress_changed.connect(_on_base_progress_changed)
		if im.has_signal("mod_unlocked"):
			im.mod_unlocked.connect(_on_mod_unlocked)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_state_dirty = true  ## 确保退出时强制保存
		_save_state()


func _on_battle_started_clear_prerolls() -> void:
	_kill_prerolled_drops.clear()

# ── 存档 ───────────────────────────────────────────────────────────

const SaveUtils = preload("res://scripts/save_utils.gd")
const STATE_SAVE_NAME: String = "intel_discovery_state"
const PowerTiers = preload("res://data/power_tiers.gd")
const FactionConquestBuffs = preload("res://data/faction_conquest_buffs.gd")

## v6.6: 统一存档接口（供 SaveManager 调用，无视脏标记——SaveManager 调用即权威保存点）
func save_state() -> Dictionary:
	return {
		"triggered_reveals": _triggered_reveals.duplicate(),
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
	_triggered_reveals = _coerce_dict(src.get("triggered_reveals", {}))
	_stat_visibility = _coerce_dict(src.get("stat_visibility", {}))
	_unlocked_lore_pages = _coerce_dict(src.get("unlocked_lore_pages", {}))

# v7.x 存档守卫：旧档/损坏档字段类型异常（非 Dictionary）时回退空字典，
# 防止破坏强类型成员变量导致整个 load_state 抛错丢失该 manager 状态。
static func _coerce_dict(value) -> Dictionary:
	return value if value is Dictionary else {}

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
	wave_env: Dictionary,
	p_disable_mod_blueprint: bool = false
) -> Dictionary:
	var harvests: Array = []         ## 情报维度增长列表
	var reveal_events: Array = []    ## 触发的揭示事件
	var intel_item_drops: Array = []  ## v6.0: 情报道具掉落
	var mod_points_by_card: Dictionary = {}  ## v21.0: card_id -> 本次击败获得的 mod 点数（结算展示用）

	var im: Node = get_node_or_null("/root/IntelManual")
	if im == null:
		return {"harvests": [], "reveal_events": [], "intel_item_drops": []}

	# v7.x 性能：下游 manager 延迟加载，此处一次性确保实例化（情报收获链路聚合点）。
	# 避免后续 EOM 碎片结算 / IEM 分支发现 / lore 页面解锁 / 揭示奖励因节点未实例化而静默丢失。
	var _mll: Node = get_node_or_null("/root/ManagerLazyLoader")
	if _mll and _mll.has_method("ensure_loaded"):
		_mll.ensure_loaded("intel_evolution")
		_mll.ensure_loaded("lore")

	## 收集本次击败的敌人ID（用于检测首次遭遇和避免重复）
	var defeated_ids: Dictionary = {}
	for enemy_info in defeated_enemies:
		if enemy_info is Dictionary:
			var aid: String = enemy_info.get("archetype_id", "")
			if not aid.is_empty():
				defeated_ids[aid] = true

	## v7.x 性能：结算循环期间临时断开 intel_dimension_changed 信号级联。
	## 根因：下面 for 循环对每个击败敌人调 register_first_encounter/register_defeat/
	## register_recon 共 3 次，每次内部 _add_intel 都 emit intel_dimension_changed →
	## 级联到 _on_intel_dimension_changed → 又调 _check_reveals（tier 循环+查表）。
	## 而循环内已主动调 _check_reveals（见下文 step 4），信号回调是纯重复工作。
	## N 个敌人 ≈ 5N+ 次 emit，每次都跑一遍揭示查表+_guess_enemy_type，是高波次关
	## 卡结算卡顿的最大放大器。这里临时断开，循环结束后重连，揭示功能无任何损失。
	var _intel_signal_was_connected: bool = false
	if im.has_signal("intel_dimension_changed") and im.intel_dimension_changed.is_connected(_on_intel_dimension_changed):
		im.intel_dimension_changed.disconnect(_on_intel_dimension_changed)
		_intel_signal_was_connected = true

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

		## 2a. v21.0: 击败 mod 点数（normal+1/elite+2/boss+3），汇入收获展示
		if im.has_method("add_defeat_mod_points"):
			var mp_gained: int = im.add_defeat_mod_points(archetype_id, rank)
			if mp_gained > 0:
				mod_points_by_card[archetype_id] = int(mod_points_by_card.get(archetype_id, 0)) + mp_gained

		## 3. 侦察加成
		if has_recon_unit and im.has_method("register_recon"):
			var recon_deltas: Dictionary = im.register_recon(archetype_id, 0.1, enemy_type)
			_harvest_recon(harvests, archetype_id, recon_deltas)

		## 4. 检查揭示事件
		var new_reveals: Array = _check_reveals(archetype_id, enemy_type, im)
		reveal_events.append_array(new_reveals)


	## v7.x 性能：结算循环结束，恢复 intel_dimension_changed 信号连接。
	## 后续 _roll_intel_item_drops/check_and_discover_branches 不再触发 _add_intel，
	## 信号恢复连接后正常的运行时情报变动（非结算期）继续正常级联到 _on_intel_dimension_changed。
	if _intel_signal_was_connected and not im.intel_dimension_changed.is_connected(_on_intel_dimension_changed):
		im.intel_dimension_changed.connect(_on_intel_dimension_changed)

	## 按card_id合并harvests
	var merged: Dictionary = _merge_harvests(harvests)
	## v21.0: 击败 mod 点数写进合并条目（结算界面展示"改造情报 +N 点"）
	if not mod_points_by_card.is_empty():
		var merged_items: Array = merged.get("items", [])
		for item in merged_items:
			if item is Dictionary:
				var mp: int = int(mod_points_by_card.get(String(item.get("card_id", "")), 0))
				if mp > 0:
					item["mod_points"] = mp

	## v6.0: 情报道具掉落
	## v7.x: p_disable_mod_blueprint=true 时（相位师战）跳过改造蓝图，避免与相位师专属掉落双爆
	intel_item_drops = _roll_intel_item_drops(defeated_enemies, victory_stars, im, p_disable_mod_blueprint)
	## 发放到IntelItemBag
	for item in intel_item_drops:
		if item is Dictionary:
			var item_type: String = item.get("item_type", "")
			var bag: Node = get_node_or_null("/root/IntelItemBag")
			if bag and bag.has_method("add_item") and not item_type.is_empty():
				bag.add_item(item_type, 1)


	## v6.6: 情报更新后检查情报进化分支发现（分支依赖情报进度）
	var iem: Node = get_node_or_null("/root/IntelEvolutionManager")
	if iem and iem.has_method("check_and_discover_branches"):
		iem.check_and_discover_branches()

	var result: Dictionary = {
		"harvests": merged.get("items", []),
		"reveal_events": reveal_events,
		"intel_item_drops": intel_item_drops,  ## v6.0
		"mod_unlock_events": _pending_mod_unlocks.duplicate(),  ## v21.0: 结算时清空并交给面板展示
	}
	_pending_mod_unlocks.clear()
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
			"stat_visibility":
				# 记录属性可见性等级（取较高优先级）
				var vis: String = reward.get("value", "")
				if not vis.is_empty():
					_stat_visibility[enemy_type] = vis
			"intel_branch_unlock":
				# 直接解锁进化分支（标记为已发现）
				# R1-5（2026-09-13）：reveal 表已无该类型奖励（进化系统退役，tier-3 改 hint），
				# 分支保留为防御性消费——若将来恢复分支玩法，数据侧加回 unlock 奖励即通。
				var branch_id: String = reward.get("branch_id", "")
				if not branch_id.is_empty():
					var iem: Node = get_node_or_null("/root/IntelEvolutionManager")
					if iem and iem.has_method("force_discover_branch"):
						iem.force_discover_branch(branch_id)
			"intel_branch_hint":
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
## 改造蓝图（基于敌人类型）
## v6.14: 注入占领势力掉落维度——当前关占领势力的 drop_mul 调整掉率，mod_pool_bias 调整改造类型偏好
## v33: 掷骰拆两腿（击杀预掷主腿 + 战后星级腿），合成分布与旧版单掷精确等价：
##   旧：P(掉) = base(stars) × rank_mult × occupation，base = 0.12/0.17/0.22（0/2/3 星档）
##   新：主腿（击杀瞬间，roll_kill_intel_drop）p1 = 0.12×rank×occ——命中当场见实物（开箱时刻）
##       星级腿（本函数，仅主腿未中者）p2 = (pt−p1)/(1−p1)，pt = base(stars)×rank×occ
##   合成：p1 + (1−p1)×p2 = pt ✔（1 星以下 p2=0 纯主腿；回归锁
##       tests/unit/battle/test_ground_loot_intel_preroll.gd）
func _roll_intel_item_drops(
	defeated_enemies: Array,
	victory_stars: int,
	im: Node,
	disable_mod_blueprint: bool = false
) -> Array:
	var drops: Array = []
	## v33 主腿收编：击杀时存 pending 的实物并入本批发放（相位师战击杀不预掷，pending 恒空）
	var prerolled: Array = _kill_prerolled_drops.duplicate()
	_kill_prerolled_drops.clear()
	if disable_mod_blueprint:
		return []   # 相位师战防双爆口径与旧版一致；万一有残留 pending 一并清空不发
	drops.append_array(prerolled)
	## 星级腿：主腿未中的敌人按条件概率补掷（同 rank 概率一致，按 rank 缓存）
	var occ := _occupation_drop_context()
	var occ_mul := float(occ.get("mul", 1.0))
	var occ_bias: Array = occ.get("bias", [])
	var cur_level := int(occ.get("level", 1))
	var star_p_by_rank := {}
	for enemy_info in defeated_enemies:
		if not enemy_info is Dictionary:
			continue
		if enemy_info.get("intel_main_hit", false):
			continue   # 主腿已出实物，不重复掷
		var rank := String(enemy_info.get("rank", "normal"))
		if not star_p_by_rank.has(rank):
			star_p_by_rank[rank] = intel_star_leg_chance(victory_stars, rank, occ_mul)
		if randf() > float(star_p_by_rank[rank]):
			continue
		var item := _roll_item_for_defeated(enemy_info, cur_level, occ_bias)
		if not item.is_empty():
			drops.append(item)

	return drops


# ── v33 掷骰拆腿：击杀预掷 + 战后补掷 ────────────────────────────────

const INTEL_MAIN_BASE_CHANCE := 0.12

static func intel_star_base_chance(victory_stars: int) -> float:
	if victory_stars >= 3:
		return 0.22
	elif victory_stars >= 2:
		return 0.17
	return INTEL_MAIN_BASE_CHANCE

static func intel_rank_mult(rank: String) -> float:
	match rank:
		"boss":
			return 2.5
		"elite":
			return 1.8
	return 1.0

## 主腿命中概率（击杀瞬间全部因子已知）
static func intel_main_leg_chance(rank: String, occupation_drop_mul: float = 1.0) -> float:
	return INTEL_MAIN_BASE_CHANCE * intel_rank_mult(rank) * occupation_drop_mul

## 星级腿条件概率（战后补掷；主腿已中者不进此腿）
static func intel_star_leg_chance(victory_stars: int, rank: String, occupation_drop_mul: float = 1.0) -> float:
	var p1 := intel_main_leg_chance(rank, occupation_drop_mul)
	var pt := intel_star_base_chance(victory_stars) * intel_rank_mult(rank) * occupation_drop_mul
	if p1 >= 1.0:
		return 0.0
	return clampf((pt - p1) / (1.0 - p1), 0.0, 1.0)


## v33 击杀瞬间主腿掷骰（battle_damage_system.roll_kill_intel_drop 调用）。
## 命中：当场 roll 物件存 pending、enemy_info 打 intel_main_hit 标记（战后跳过星级腿），
## 返回掉落字典供地面战利品展示；未命中返回 {}。主腿 RNG 只此一处，勿在别处复掷。
func roll_kill_intel_drop(enemy_info: Dictionary) -> Dictionary:
	var rank := String(enemy_info.get("rank", "normal"))
	var occ := _occupation_drop_context()
	var p1 := intel_main_leg_chance(rank, float(occ.get("mul", 1.0)))
	if randf() > p1:
		return {}
	var item := _roll_item_for_defeated(enemy_info, int(occ.get("level", 1)), occ.get("bias", []))
	if item.is_empty():
		return {}
	enemy_info["intel_main_hit"] = true
	_kill_prerolled_drops.append(item)
	return item


## v6.14 占领势力掉落 buff（drop_mul + mod_pool_bias）——击杀预掷/战后补掷共用
func _occupation_drop_context() -> Dictionary:
	var out := {"mul": 1.0, "bias": [], "level": 1}
	var cur_level: int = 1
	var fsm: Node = get_node_or_null("/root/FactionSystemManager")
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null:
		cur_level = int(gm.get("current_level")) if "current_level" in gm else 1
		out["level"] = cur_level
	if fsm != null and fsm.has_method("get_level_occupation") and gm != null:
		var occ_fid: String = String(fsm.get_level_occupation(cur_level))
		if not occ_fid.is_empty() and fsm.has_method("get_faction_level"):
			var flvl: int = int(fsm.get_faction_level(occ_fid))
			var buff: Dictionary = FactionConquestBuffs.get_buff(occ_fid, flvl)
			out["mul"] = float(buff.get("drop_mul", 1.0))
			out["bias"] = buff.get("mod_pool_bias", [])
	return out


## 单敌人情报道具 roll（v6.14.4 缴获/发现 75/25 分流 + 时代过滤 + 兜底兵种池）
## ——击杀预掷/战后补掷共用，防双实现漂移
func _roll_item_for_defeated(enemy_info: Dictionary, cur_level: int, occupation_mod_bias: Array) -> Dictionary:
	var rank := String(enemy_info.get("rank", "normal"))
	var enemy_type: String = String(enemy_info.get("enemy_type", _guess_enemy_type(enemy_info.get("archetype_id", ""))))
	# v7.x: power_tier 改用 rank+level 混合档位，让高关杂兵也能掉更高稀有度改造
	var power_tier: int = PowerTiers.get_tier_by_rank_and_level(rank, cur_level)
	if rank != "normal":
		power_tier += 1   # 精英/Boss：原进化图纸份额并入此处（档位越界由 clamp 兜底）
	# v6.14: 掉落时代过滤——对齐安装侧 era_band 硬门，前期不再掉当前时代装不上的图纸
	var max_era: int = clampi(LevelEras.get_era(cur_level), 0, 4)
	# v6.14.2（用户拍板）：缴获语义——有配装的敌人只从它实际携带的模块中掉
	# （按档位切片：normal=新兵前 5 条 / elite=精英 9 条 / boss=传奇 9 条，与挂载同源）；
	# 无配装的敌人（缴获/星冥/未配卡）回退全池 roll（含时代过滤 + 史诗+跨一级前瞻）。
	var rank_tier: int = 1
	match rank:
		"boss":
			rank_tier = 4
		"elite":
			rank_tier = 3
	# 2026-09-19 修复：配装表键双形态（经典敌裸 id / 34 个生成敌带 foe_ 前缀）——
	# 原先恒 trim_prefix("foe_") 导致 foe_* 键恒 miss、缴获腿对生成敌全灭（挂载侧
	# enemy_unit._apply_loadout_modifications 用原 id 不 trim）。现原 id 优先、trim 兜底。
	var _kit_aid: String = String(enemy_info.get("archetype_id", ""))
	var kit: Array = EnemyFixedLoadouts.get_mods_for_tier(_kit_aid, rank_tier)
	if kit.is_empty():
		kit = EnemyFixedLoadouts.get_mods_for_tier(_kit_aid.trim_prefix("foe_"), rank_tier)
	# v6.14.4（用户拍板 75/25 分流）：缴获腿 vs 发现腿——75% 掉它携带的件（缴获语义
	# 主导），25% 走全注册表按稀有度比例 roll（发现语义：优先未见过的模块，保证
	# 全图鉴 249 件保持战斗可发现 → 见过集合 → 随机箱池/定向列表不断链）。
	# 无配装敌人直接走发现腿；两腿皆空时回退原兵种池 roll。两腿时代口径一致。
	var bag: Node = get_node_or_null("/root/IntelItemBag")
	var is_seen: Callable = func(mid: String) -> bool:
		return bag != null and bag.has_method("has_seen") \
			and bool(bag.has_seen("blueprint_" + mid))
	var use_kit: bool = not kit.is_empty() and randf() < 0.75
	if use_kit:
		var from_kit: Dictionary = IntelManualItems.roll_mod_blueprint_from_kit(kit, max_era)
		if not from_kit.is_empty():
			return from_kit
	var discovered: Dictionary = IntelManualItems.roll_discovery_mod_blueprint(rank, power_tier, max_era, is_seen)
	if not discovered.is_empty():
		return discovered
	return IntelManualItems.roll_random_mod_blueprint(enemy_type, rank, power_tier, occupation_mod_bias, max_era)

# ── v21.0: base 进度 / mod 解锁通知 ──────────────────────────────

## base 跨过 50% → 低进化可用一次性通知（FeatureUnlockPopup 按键去重，只弹一次）
func _on_base_progress_changed(card_id: String, old_val: float, new_val: float) -> void:
	if old_val < IntelManualScript.LOW_EVOLUTION_BASE \
			and new_val >= IntelManualScript.LOW_EVOLUTION_BASE \
			and EnemyCardModMap.can_low_evolve(card_id):
		FeatureUnlockPopup.show_once(
			"v21_low_evo_" + card_id,
			"低谱系可用",
			"「%s」情报过半——该敌方形态的缴获卡可在「成长」面板沿谱系进阶为对应我方卡。" % DefaultCards.get_safe_display_name(card_id))

## mod 解锁：静默记录到 _pending_mod_unlocks，由结算面板统一展示（不在战斗中弹窗）
func _on_mod_unlocked(card_id: String, mod_id: String) -> void:
	var mod_name: String = String(ModRegistry.get_data(mod_id).get("name", mod_id))
	_pending_mod_unlocks.append({
		"card_name": DefaultCards.get_safe_display_name(card_id),
		"mod_name": mod_name,
	})
