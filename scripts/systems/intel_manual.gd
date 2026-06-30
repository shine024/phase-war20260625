extends Node
## 情报手册核心逻辑
## 管理所有敌方单位的情报数据：遭遇、击败、侦察、分解等情报获取，
## 情报奖励阶梯判定，存档/读档。
##
## v6.7: 单维度化
##   原 v6.0 的 4 维（basic/tactical/material/secret）已合并为单一 intel_progress。
##   击败给进度，按次数递减（首杀 12%，每次 ×0.8，下限 1%）。
##   进度跨 25%/50%/75%/100% 阈值触发揭示事件（由 IntelDiscoveryManager 统一检查）。
##   原 4 维字段（intel_dimensions/revealed_tiers）在 IntelEntry 中保留以兼容旧存档，
##   但运行时不再读写。
##
## 依赖：
##   - SaveUtils（存档/读档）
##   - SignalBus（信号通知）
##   - IntelDimensions（情报维度定义，单维度化后仅用于 get_reveal_tier）

const SaveUtils = preload("res://scripts/save_utils.gd")
const IntelDimensions = preload("res://data/intel_dimensions.gd")
const GC = preload("res://resources/game_constants.gd")

# ── 常量 ──────────────────────────────────────────────────────────

## v6.7: 单维度化后的击败递减加成曲线
## amount = BASE[rank] × DEFEAT_DECAY_FACTOR^(defeat_count-1)，下限 DEFEAT_MIN_AMOUNT
## 首杀 12%/20%/30%，每次 ×0.8 衰减，约 12-15 次击败打满 100%
const DEFEAT_BASE_NORMAL: float = 0.12
const DEFEAT_BASE_ELITE: float = 0.20
const DEFEAT_BASE_BOSS: float = 0.30
const DEFEAT_DECAY_FACTOR: float = 0.8
const DEFEAT_MIN_AMOUNT: float = 0.01

## 首次遭遇固定加成（与第1次击败叠加，使首战收益显著）
const FIRST_ENCOUNTER_INTEL: float = 0.12

## 侦察/分解加成（保留，单维度下直接累加到 intel_progress）
const RECON_MIN: float = 0.05
const RECON_MAX: float = 0.15
const DECOMPOSE_INTEL: float = 0.10

## 3星胜利额外情报加成
const PERFECT_VICTORY_INTEL_BONUS: float = 0.10

## 情报奖励阶梯（保持向后兼容）
const TIER_NONE: int = 0
const TIER_BASIC_STATS: int = 1     # 25%
const TIER_DETAIL_STATS: int = 2    # 50%
const TIER_WEAKNESS: int = 3        # 75%
const TIER_EVOLUTION: int = 4       # 100%

## 存档文件名
const SAVE_FILE_NAME: String = "intel_manual"
const SAVE_VERSION: int = 3  # v1=旧单一情报, v2=4维情报, v3=单维度化（合并4维回单标量）

# ── 信号 ──────────────────────────────────────────────────────────

## 情报进度变化 signal(card_id, old_progress, new_progress, source)
signal intel_progress_changed(card_id: String, old_progress: float, new_progress: float, source: String)
## 🆕 情报维度变化 signal(card_id, dimension, old_val, new_val, source)
signal intel_dimension_changed(card_id: String, dimension: String, old_val: float, new_val: float, source: String)
## 情报奖励阶梯提升 signal(card_id, old_tier, new_tier)
signal intel_tier_up(card_id: String, old_tier: int, new_tier: int)
## 完全解锁（100%） signal(card_id)
signal intel_completed(card_id: String)

# ── 数据 ──────────────────────────────────────────────────────────

## card_id -> IntelEntry
var _entries: Dictionary = {}

## 缓存：已完全解锁的卡片 ID 列表
var _completed_cache: Array[String] = []

## 敌人类型映射缓存：card_id -> enemy_type标签
var _card_to_enemy_type: Dictionary = {}

# ── IntelEntry 内部类 ─────────────────────────────────────────────

class IntelEntry:
	var card_id: String = ""
	var intel_progress: float = 0.0          ## v6.7: 唯一情报进度（单维度）
	## 以下4维字段保留以兼容旧存档读写，运行时不再使用
	var intel_dimensions: Dictionary = {}    ## [已废弃] 旧4维情报
	var revealed_tiers: Dictionary = {}      ## [已废弃] 旧4维揭示等级
	var is_unlocked: bool = false
	var first_encounter: bool = false
	var defeat_count: int = 0
	var recon_bonus: float = 0.0
	var decompose_bonus: float = 0.0
	var migrated: bool = false               ## 是否已迁移到当前版本

	func _init(id: String) -> void:
		card_id = id

	func to_dict() -> Dictionary:
		return {
			"card_id": card_id,
			"intel_progress": intel_progress,
			"intel_dimensions": intel_dimensions.duplicate(),
			"revealed_tiers": revealed_tiers.duplicate(),
			"is_unlocked": is_unlocked,
			"first_encounter": first_encounter,
			"defeat_count": defeat_count,
			"recon_bonus": recon_bonus,
			"decompose_bonus": decompose_bonus,
			"migrated": migrated,
		}

	static func from_dict(data: Dictionary) -> IntelEntry:
		var entry := IntelEntry.new(data.get("card_id", ""))
		entry.intel_progress = clampf(data.get("intel_progress", 0.0), 0.0, 1.0)
		entry.is_unlocked = data.get("is_unlocked", false)
		entry.first_encounter = data.get("first_encounter", false)
		entry.defeat_count = int(data.get("defeat_count", 0))
		entry.recon_bonus = clampf(data.get("recon_bonus", 0.0), 0.0, 1.0)
		entry.decompose_bonus = clampf(data.get("decompose_bonus", 0.0), 0.0, 1.0)
		entry.migrated = data.get("migrated", false)
		## 旧4维字段仅原样保留（存档兼容），运行时不读取
		if data.has("intel_dimensions") and data["intel_dimensions"] is Dictionary:
			entry.intel_dimensions = (data["intel_dimensions"] as Dictionary).duplicate()
		if data.has("revealed_tiers") and data["revealed_tiers"] is Dictionary:
			entry.revealed_tiers = (data["revealed_tiers"] as Dictionary).duplicate()
		return entry

# ── 生命周期 ──────────────────────────────────────────────────────

func _ready() -> void:
	# v6.6: 移除自加载，由 SaveManager 统一加载
	pass

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_data()

# ── 存档 / 读档 ───────────────────────────────────────────────────

## v6.6: 统一存档接口（供 SaveManager 调用）
## 序列化 _entries（每个 IntelEntry.to_dict）+ _completed_cache + _card_to_enemy_type
func save_state() -> Dictionary:
	var raw: Dictionary = {"_version": SAVE_VERSION}
	for card_id in _entries:
		var entry: IntelEntry = _entries[card_id]
		raw[card_id] = entry.to_dict()
	raw["_completed_cache"] = _completed_cache.duplicate()
	raw["_card_to_enemy_type"] = _card_to_enemy_type.duplicate()
	return raw

## v6.6: 统一存档加载接口。data 为空时尝试兼容读取旧独立文件
func load_state(data: Dictionary) -> void:
	var raw: Dictionary = data
	if raw.is_empty():
		raw = SaveUtils.load_data_from_file(SAVE_FILE_NAME)
		if raw.is_empty():
			return
	_apply_loaded_raw(raw)

## 将原始 raw 字典应用到内存状态（迁移 + 缓存重建）
func _apply_loaded_raw(raw: Dictionary) -> void:
	_entries.clear()
	_completed_cache.clear()
	var raw_version: int = int(raw.get("_version", 1))
	for card_id in raw:
		if card_id == "_version" or card_id == "_completed_cache" or card_id == "_card_to_enemy_type":
			continue  ## 跳过元数据键
		if raw[card_id] is Dictionary:
			var entry: IntelEntry = IntelEntry.from_dict(raw[card_id])
			## v2→v3 迁移：把旧4维情报合并回单标量 intel_progress
			## 判定条件：存档版本<3，或条目未迁移且4维数据非空
			if raw_version < 3 or (not entry.migrated and not entry.intel_dimensions.is_empty()):
				_migrate_v2_to_v3(entry)
			_entries[card_id] = entry
			if entry.is_unlocked:
				_completed_cache.append(card_id)
	## v6.6: 恢复缓存与映射（旧存档无此键时保持空）
	if raw.has("_completed_cache") and raw["_completed_cache"] is Array:
		for item in raw["_completed_cache"]:
			_completed_cache.append(str(item))
	if raw.has("_card_to_enemy_type") and raw["_card_to_enemy_type"] is Dictionary:
		_card_to_enemy_type = (raw["_card_to_enemy_type"] as Dictionary).duplicate()

## 将情报数据保存到本地（退出兜底，委托给统一 save_state）
func save_data() -> void:
	SaveUtils.save_data_to_file(save_state(), SAVE_FILE_NAME)

## 从本地加载情报数据（委托给统一 load_state，向后兼容旧调用）
func load_data() -> void:
	load_state({})

## v6.6: 新游戏重置——清空所有字段，不读旧文件（区别于 load_state({}) 的兼容读取）
func reset_progress() -> void:
	_entries.clear()
	_completed_cache.clear()
	_card_to_enemy_type.clear()

## v6.7: v2→v3 迁移——把旧4维情报合并回单标量 intel_progress
## 采用最大值策略（取4维最大值），避免玩家进度因合并而降级。
## 若4维数据为空但 intel_progress 已有值（v1存档），则直接保留原 intel_progress。
func _migrate_v2_to_v3(entry: IntelEntry) -> void:
	if not entry.intel_dimensions.is_empty():
		var merged: float = IntelDimensions.merge_legacy_dimensions(entry.intel_dimensions)
		## 取较大值，避免迁移导致进度回退
		entry.intel_progress = maxf(entry.intel_progress, merged)
		## 清空旧4维字段（减少存档体积，保留也无害但更整洁）
		entry.intel_dimensions = {}
		entry.revealed_tiers = {}
	entry.migrated = true
	## 同步 is_unlocked 状态（合并后若满100%则标记解锁）
	if entry.intel_progress >= 1.0:
		entry.is_unlocked = true

# ── 内部工具 ──────────────────────────────────────────────────────

## 确保情报条目存在，不存在则创建
func _ensure_entry(card_id: String) -> IntelEntry:
	if not _entries.has(card_id):
		_entries[card_id] = IntelEntry.new(card_id)
	return _entries[card_id]

## 获取随机值 [min_val, max_val]
func _rand_range_float(min_val: float, max_val: float) -> float:
	return randf_range(min_val, min(max_val, min_val + 1.0))

## 判定奖励阶梯（基于总情报，向后兼容）
func _calc_tier(progress: float) -> int:
	if progress >= 1.0:  return TIER_EVOLUTION
	if progress >= 0.75: return TIER_WEAKNESS
	if progress >= 0.50: return TIER_DETAIL_STATS
	if progress >= 0.25: return TIER_BASIC_STATS
	return TIER_NONE

## v6.7: 单维度情报累加（替代旧的 _add_dimensional_intel + _add_intel_weighted）
## 直接把 amount 加到 intel_progress，触发阶梯/完成/维度变化信号。
## dimension 参数保留以兼容调用签名（单维度化后固定为 "intel"）。
## 返回实际增长量。
func _add_intel(card_id: String, amount: float, source: String, dimension: String = "intel") -> float:
	var entry := _ensure_entry(card_id)
	if entry.intel_progress >= 1.0:
		return 0.0  ## 已满
	var old_val: float = entry.intel_progress
	var old_tier: int = IntelDimensions.get_reveal_tier(old_val)
	entry.intel_progress = clampf(old_val + amount, 0.0, 1.0)
	var new_val: float = entry.intel_progress
	var new_tier: int = IntelDimensions.get_reveal_tier(new_val)
	## 检查完全解锁
	if entry.intel_progress >= 1.0 and not entry.is_unlocked:
		entry.is_unlocked = true
		if not card_id in _completed_cache:
			_completed_cache.append(card_id)
		intel_completed.emit(card_id)
	## 总阶梯检查（跨档触发）
	if new_tier > old_tier:
		intel_tier_up.emit(card_id, old_tier, new_tier)
	## 发射维度变化信号（dimension 固定为 "intel"，兼容旧监听者）
	if absf(new_val - old_val) > 0.001:
		intel_dimension_changed.emit(card_id, dimension, old_val, new_val, source)
		intel_progress_changed.emit(card_id, old_val, new_val, source)
	## v7.x 修复 W7：移除每条情报的同步写盘 save_data()——v6.6 起情报已并入统一存档（SaveManager
	## 调 save_state），此处重复写独立文件既冗余又造成战斗结算批量解锁时的 I/O 抖动。
	## 持久化由 SaveManager 自动存档（战斗结束+15s备份）统一负责。
	return new_val - old_val

# ── 公开接口：情报获取 ─────────────────────────────────────────────
## v6.7: 所有 register_* 返回 {"intel": delta}，保持与下游 _harvest_* 的 Dictionary 契约。
## 单维度化后只有一个 key "intel"。

## 首次遭遇：固定 +12% 情报（一次性）
func register_first_encounter(card_id: String, enemy_type: String = "") -> float:
	var entry := _ensure_entry(card_id)
	if entry.first_encounter:
		return 0.0
	entry.first_encounter = true
	## 缓存敌人类型映射
	if not enemy_type.is_empty():
		_card_to_enemy_type[card_id] = enemy_type
	return _add_intel(card_id, FIRST_ENCOUNTER_INTEL, "first_encounter")

## 击败单位获得情报（按击败次数递减）
## amount = BASE[rank] × DEFEAT_DECAY_FACTOR^(defeat_count-1)，下限 DEFEAT_MIN_AMOUNT
## 3星胜利额外 +10%
## 返回 {"intel": delta}（兼容下游 _harvest_defeat 的 Dictionary 契约）
func register_defeat(
	card_id: String,
	unit_rank: String = "normal",
	enemy_type: String = "",
	victory_stars: int = 0
) -> Dictionary:
	var entry := _ensure_entry(card_id)
	entry.defeat_count += 1
	## 缓存敌人类型映射
	if not enemy_type.is_empty():
		_card_to_enemy_type[card_id] = enemy_type
	## 基础量按 rank
	var base_amount: float = DEFEAT_BASE_NORMAL
	match unit_rank:
		"boss":
			base_amount = DEFEAT_BASE_BOSS
		"elite":
			base_amount = DEFEAT_BASE_ELITE
		_:
			base_amount = DEFEAT_BASE_NORMAL
	## 递减：×0.8^(defeat_count-1)，下限 DEFEAT_MIN_AMOUNT
	var decayed: float = base_amount * pow(DEFEAT_DECAY_FACTOR, entry.defeat_count - 1)
	var total_amount: float = maxf(decayed, DEFEAT_MIN_AMOUNT)
	## 3星胜利额外 +10%
	if victory_stars >= 3:
		total_amount += PERFECT_VICTORY_INTEL_BONUS
	var source: String = "defeat_" + unit_rank
	var actual: float = _add_intel(card_id, total_amount, source)
	var result: Dictionary = {}
	if actual > 0.001:
		result["intel"] = actual
	return result

## 侦察激活获得情报
## recon_bonus_pct: 侦察加成百分比 (0.0-1.0)
## 返回 {"intel": delta}
func register_recon(card_id: String, recon_bonus_pct: float = 0.0, enemy_type: String = "") -> Dictionary:
	var entry := _ensure_entry(card_id)
	var amount := _rand_range_float(RECON_MIN, RECON_MAX)
	entry.recon_bonus = recon_bonus_pct
	amount += amount * recon_bonus_pct
	if not enemy_type.is_empty():
		_card_to_enemy_type[card_id] = enemy_type
	var actual: float = _add_intel(card_id, amount, "recon")
	var result: Dictionary = {}
	if actual > 0.001:
		result["intel"] = actual
	return result

## 分解重复卡获得情报
## 返回 {"intel": delta}
func register_decompose(card_id: String, enemy_type: String = "") -> Dictionary:
	var entry := _ensure_entry(card_id)
	entry.decompose_bonus += DECOMPOSE_INTEL
	if not enemy_type.is_empty():
		_card_to_enemy_type[card_id] = enemy_type
	var actual: float = _add_intel(card_id, DECOMPOSE_INTEL, "decompose")
	var result: Dictionary = {}
	if actual > 0.001:
		result["intel"] = actual
	return result

# ── 公开接口：查询 ────────────────────────────────────────────────

## 获取某卡的情报进度 (0.0-1.0)，加权平均（向后兼容）
func get_intel_progress(card_id: String) -> float:
	if _entries.has(card_id):
		return _entries[card_id].intel_progress
	return 0.0

## v6.7: 兼容别名——单维度下等价于 get_intel_progress
func get_dimension_progress(card_id: String, dimension: String = "intel") -> float:
	if _entries.has(card_id):
		return _entries[card_id].intel_progress
	return 0.0

## v6.7: 单维度下返回 {"intel": progress}（兼容旧调用）
func get_all_dimensions(card_id: String) -> Dictionary:
	var progress: float = get_intel_progress(card_id)
	return {"intel": progress}

## v6.7: 兼容别名——返回基于 intel_progress 的揭示等级
func get_revealed_tier(card_id: String, dimension: String = "intel") -> int:
	return IntelDimensions.get_reveal_tier(get_intel_progress(card_id))

## v6.7: 单维度下返回 {"intel": tier}
func get_all_revealed_tiers(card_id: String) -> Dictionary:
	return {"intel": get_revealed_tier(card_id)}

## 🆕 获取某卡关联的敌人类型
func get_enemy_type(card_id: String) -> String:
	return _card_to_enemy_type.get(card_id, "")

## 获取某卡的完整情报条目（字典形式）
func get_intel_entry(card_id: String) -> Dictionary:
	var entry := _ensure_entry(card_id)
	return entry.to_dict()

## 获取所有已记录的情报条目
func get_all_entries() -> Dictionary:
	var result: Dictionary = {}
	for card_id in _entries:
		result[card_id] = _entries[card_id].to_dict()
	return result

## 判断某卡情报是否已完成
func is_complete(card_id: String) -> bool:
	if _entries.has(card_id):
		return _entries[card_id].is_unlocked
	return false

## 获取某卡情报奖励阶梯（向后兼容，基于总情报）
func get_intel_reward_tier(card_id: String) -> int:
	return _calc_tier(get_intel_progress(card_id))

## 获取某卡的阶梯描述文本
func get_tier_description(card_id: String) -> String:
	match get_intel_reward_tier(card_id):
		TIER_NONE:         return "未解锁"
		TIER_BASIC_STATS:  return "基础属性可见"
		TIER_DETAIL_STATS: return "详细属性可见"
		TIER_WEAKNESS:     return "弱点/抗性提示"
		TIER_EVOLUTION:    return "进化资格已解锁 + 掉落率+50%"
	return "未知"

## 是否首次遭遇过
func has_encountered(card_id: String) -> bool:
	if _entries.has(card_id):
		return _entries[card_id].first_encounter
	return false

## 获取击败次数
func get_defeat_count(card_id: String) -> int:
	if _entries.has(card_id):
		return _entries[card_id].defeat_count
	return 0

## 获取已完全解锁的卡片 ID 列表
func get_completed_list() -> Array[String]:
	return _completed_cache.duplicate()

## 获取所有已记录的卡片 ID 列表
func get_known_card_ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(_entries.keys())
	return result

## 获取已记录情报的总数
func get_total_entries() -> int:
	return _entries.size()

## 获取已完成情报的总数
func get_total_completed() -> int:
	return _completed_cache.size()

## 解锁所有情报（用于新游戏初始资源）
func unlock_all_intel() -> void:
	var dc: GDScript = load("res://data/default_cards.gd")
	var all_cards = dc.create_all() if dc else []
	for card in all_cards:
		if card is CardResource and card.card_type == GC.CardType.COMBAT_UNIT:
			_ensure_entry(card.card_id)
			var entry = _entries[card.card_id]
			entry.intel_progress = 1.0
			entry.is_unlocked = true
			if not _completed_cache.has(card.card_id):
				_completed_cache.append(card.card_id)
	_completed_cache = _completed_cache.duplicate()  # 触发更新
