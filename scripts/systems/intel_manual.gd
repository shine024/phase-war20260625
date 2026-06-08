extends Node
## 情报手册核心逻辑
## 管理所有敌方单位的情报数据：遭遇、击败、侦察、分解等情报获取，
## 情报奖励阶梯判定，存档/读档。
##
## v6.0: 扩展为4维情报系统
##   basic    — 基础侦察：HP/攻击/防御等数值属性
##   tactical — 战术分析：行为模式/技能/弱点
##   material — 素材研究：可掉落的专属材料信息
##   secret   — 机密档案：隐藏进化线索/传奇配方
##
## 依赖：
##   - SaveUtils（存档/读档）
##   - SignalBus（信号通知）
##   - IntelDimensions（情报维度定义，v6.0新增）

const SaveUtils = preload("res://scripts/save_utils.gd")
const IntelDimensions = preload("res://data/intel_dimensions.gd")
const GC = preload("res://resources/game_constants.gd")

# ── 常量 ──────────────────────────────────────────────────────────

## 情报获取量（总量，会被按维度分配）
const FIRST_ENCOUNTER_INTEL: float = 0.20
const DEFEAT_NORMAL_MIN: float = 0.05
const DEFEAT_NORMAL_MAX: float = 0.10
const DEFEAT_ELITE_MIN: float = 0.15
const DEFEAT_ELITE_MAX: float = 0.25
const DEFEAT_BOSS_MIN: float = 0.25
const DEFEAT_BOSS_MAX: float = 0.40
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
const SAVE_VERSION: int = 2  # v1=旧单一情报, v2=4维情报

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
	var intel_progress: float = 0.0          ## 总情报（4维加权平均，向后兼容）
	var intel_dimensions: Dictionary = {}    ## 🆕 4维情报 {"basic": 0.0, "tactical": 0.0, ...}
	var revealed_tiers: Dictionary = {}     ## 🆕 已触发的揭示等级 {"basic": 0, "tactical": -1, ...}
	var is_unlocked: bool = false
	var first_encounter: bool = false
	var defeat_count: int = 0
	var recon_bonus: float = 0.0
	var decompose_bonus: float = 0.0
	var migrated: bool = false               ## 🆕 是否已从旧格式迁移

	func _init(id: String) -> void:
		card_id = id
		## 初始化4维情报为0
		for dim in IntelDimensions.ALL_DIMENSIONS:
			intel_dimensions[dim] = 0.0
			revealed_tiers[dim] = -1  ## -1表示未触发任何揭示

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
		## 🆕 加载4维情报
		if data.has("intel_dimensions") and data["intel_dimensions"] is Dictionary:
			for dim in IntelDimensions.ALL_DIMENSIONS:
				if data["intel_dimensions"].has(dim):
					entry.intel_dimensions[dim] = clampf(float(data["intel_dimensions"][dim]), 0.0, 1.0)
		else:
			## 无4维数据：全部置零，等待迁移
			for dim in IntelDimensions.ALL_DIMENSIONS:
				entry.intel_dimensions[dim] = 0.0
		## 🆕 加载揭示等级
		if data.has("revealed_tiers") and data["revealed_tiers"] is Dictionary:
			for dim in IntelDimensions.ALL_DIMENSIONS:
				if data["revealed_tiers"].has(dim):
					entry.revealed_tiers[dim] = int(data["revealed_tiers"][dim])
				else:
					entry.revealed_tiers[dim] = -1
		else:
			for dim in IntelDimensions.ALL_DIMENSIONS:
				entry.revealed_tiers[dim] = -1
		return entry

# ── 生命周期 ──────────────────────────────────────────────────────

func _ready() -> void:
	load_data()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_data()

# ── 存档 / 读档 ───────────────────────────────────────────────────

## 将情报数据保存到本地
func save_data() -> void:
	var raw: Dictionary = {"_version": SAVE_VERSION}
	for card_id in _entries:
		var entry: IntelEntry = _entries[card_id]
		raw[card_id] = entry.to_dict()
	SaveUtils.save_data_to_file(raw, SAVE_FILE_NAME)

## 从本地加载情报数据
func load_data() -> void:
	var raw: Dictionary = SaveUtils.load_data_from_file(SAVE_FILE_NAME)
	_entries.clear()
	_completed_cache.clear()
	for card_id in raw:
		if card_id == "_version":
			continue  ## 跳过版本标记
		if raw[card_id] is Dictionary:
			var entry: IntelEntry = IntelEntry.from_dict(raw[card_id])
			## 旧存档迁移：如果尚未迁移且有旧intel_progress
			if not entry.migrated and entry.intel_progress > 0.0:
				_migrate_single_entry(entry)
			_entries[card_id] = entry
			if entry.is_unlocked:
				_completed_cache.append(card_id)

## 🆕 迁移旧格式条目：将单一intel_progress分配到4维度
func _migrate_single_entry(entry: IntelEntry) -> void:
	if entry.intel_progress <= 0.0:
		return
	## 按照权重分配：basic略高，secret最低
	var old: float = entry.intel_progress
	entry.intel_dimensions[IntelDimensions.DIM_BASIC] = clampf(old * 1.1, 0.0, 1.0)
	entry.intel_dimensions[IntelDimensions.DIM_TACTICAL] = clampf(old * 0.85, 0.0, 1.0)
	entry.intel_dimensions[IntelDimensions.DIM_MATERIAL] = clampf(old * 0.75, 0.0, 1.0)
	entry.intel_dimensions[IntelDimensions.DIM_SECRET] = clampf(old * 0.3, 0.0, 1.0)
	## 重新计算揭示等级
	for dim in IntelDimensions.ALL_DIMENSIONS:
		entry.revealed_tiers[dim] = IntelDimensions.get_reveal_tier(entry.intel_dimensions[dim])
	entry.migrated = true

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

## 🆕 添加单维度情报量并触发信号
func _add_dimensional_intel(card_id: String, dimension: String, amount: float, source: String) -> float:
	var entry := _ensure_entry(card_id)
	if entry.intel_dimensions.get(dimension, 0.0) >= 1.0:
		return 0.0  ## 该维度已满
	var old_val: float = entry.intel_dimensions.get(dimension, 0.0)
	var old_tier: int = entry.revealed_tiers.get(dimension, -1)
	entry.intel_dimensions[dimension] = clampf(old_val + amount, 0.0, 1.0)
	var new_val: float = entry.intel_dimensions[dimension]
	var new_tier: int = IntelDimensions.get_reveal_tier(new_val)
	## 更新揭示等级
	if new_tier >= 0 and new_tier != old_tier:
		entry.revealed_tiers[dimension] = new_tier
	## 更新总情报（加权平均）
	var old_total: float = entry.intel_progress
	entry.intel_progress = IntelDimensions.calc_weighted_average(entry.intel_dimensions)
	## 检查完全解锁
	if entry.intel_progress >= 1.0 and not entry.is_unlocked:
		entry.is_unlocked = true
		if not card_id in _completed_cache:
			_completed_cache.append(card_id)
		intel_completed.emit(card_id)
	## 总阶梯检查
	var old_total_tier := _calc_tier(old_total)
	var new_total_tier := _calc_tier(entry.intel_progress)
	if new_total_tier > old_total_tier:
		intel_tier_up.emit(card_id, old_total_tier, new_total_tier)
	## 发射维度信号
	if absf(new_val - old_val) > 0.001:
		intel_dimension_changed.emit(card_id, dimension, old_val, new_val, source)
	if absf(entry.intel_progress - old_total) > 0.001:
		intel_progress_changed.emit(card_id, old_total, entry.intel_progress, source)
	save_data()
	return new_val - old_val

## 🆕 按维度权重分配并添加情报
## total_amount: 总情报量
## source: 来源描述
## enemy_type: 敌人类型（用于权重分配）
## victory_stars: 胜利星级(0-3)
## 返回各维度实际增长的字典
func _add_intel_weighted(
	card_id: String,
	total_amount: float,
	source: String,
	enemy_type: String,
	victory_stars: int = 0
) -> Dictionary:
	var weights: Dictionary = IntelDimensions.calc_dimension_weights(source, enemy_type, victory_stars)
	var result: Dictionary = {}
	var entry := _ensure_entry(card_id)
	## 如果总情报已满，跳过
	if entry.intel_progress >= 1.0:
		return result
	for dim in IntelDimensions.ALL_DIMENSIONS:
		var w: float = float(weights.get(dim, 0.0))
		if w <= 0.0:
			continue
		var dim_amount: float = total_amount * w
		if dim_amount <= 0.001:
			continue
		var actual: float = _add_dimensional_intel(card_id, dim, dim_amount, source)
		if actual > 0.001:
			result[dim] = actual
	return result

# ── 公开接口：情报获取 ─────────────────────────────────────────────

## 首次遭遇：+20% 情报（分配到基础侦察维度为主）
## 只在第一次遭遇时触发，返回实际获得的情报量
func register_first_encounter(card_id: String, enemy_type: String = "") -> float:
	var entry := _ensure_entry(card_id)
	if entry.first_encounter:
		return 0.0
	entry.first_encounter = true
	## 缓存敌人类型映射
	if not enemy_type.is_empty():
		_card_to_enemy_type[card_id] = enemy_type
	var result: Dictionary = _add_intel_weighted(
		card_id, FIRST_ENCOUNTER_INTEL, "first_encounter",
		enemy_type
	)
	var total: float = 0.0
	for v in result.values():
		total += float(v)
	return total

## 击败单位获得情报（4维分配）
## unit_rank: "normal" | "elite" | "boss"
## enemy_type: 敌人类型标签
## victory_stars: 胜利星级(0-3)
## 返回各维度实际增长的字典
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
	var total_amount: float = 0.0
	match unit_rank:
		"boss":
			total_amount = _rand_range_float(DEFEAT_BOSS_MIN, DEFEAT_BOSS_MAX)
		"elite":
			total_amount = _rand_range_float(DEFEAT_ELITE_MIN, DEFEAT_ELITE_MAX)
		_:
			total_amount = _rand_range_float(DEFEAT_NORMAL_MIN, DEFEAT_NORMAL_MAX)
	var source: String = "defeat_" + unit_rank
	return _add_intel_weighted(card_id, total_amount, source, enemy_type, victory_stars)

## 侦察激活获得情报
## recon_bonus_pct: 侦察加成百分比 (0.0-1.0)
## 返回各维度实际增长的字典
func register_recon(card_id: String, recon_bonus_pct: float = 0.0, enemy_type: String = "") -> Dictionary:
	var entry := _ensure_entry(card_id)
	var amount := _rand_range_float(RECON_MIN, RECON_MAX)
	entry.recon_bonus = recon_bonus_pct
	amount += amount * recon_bonus_pct
	if not enemy_type.is_empty():
		_card_to_enemy_type[card_id] = enemy_type
	return _add_intel_weighted(card_id, amount, "recon", enemy_type)

## 分解重复卡获得情报
## 返回各维度实际增长的字典
func register_decompose(card_id: String, enemy_type: String = "") -> Dictionary:
	var entry := _ensure_entry(card_id)
	entry.decompose_bonus += DECOMPOSE_INTEL
	if not enemy_type.is_empty():
		_card_to_enemy_type[card_id] = enemy_type
	return _add_intel_weighted(card_id, DECOMPOSE_INTEL, "decompose", enemy_type)

# ── 公开接口：查询 ────────────────────────────────────────────────

## 获取某卡的情报进度 (0.0-1.0)，加权平均（向后兼容）
func get_intel_progress(card_id: String) -> float:
	if _entries.has(card_id):
		return _entries[card_id].intel_progress
	return 0.0

## 🆕 获取某卡特定维度的情报进度
func get_dimension_progress(card_id: String, dimension: String) -> float:
	if _entries.has(card_id):
		var entry: IntelEntry = _entries[card_id]
		return float(entry.intel_dimensions.get(dimension, 0.0))
	return 0.0

## 🆕 获取某卡全部4维情报
func get_all_dimensions(card_id: String) -> Dictionary:
	if _entries.has(card_id):
		var entry: IntelEntry = _entries[card_id]
		return entry.intel_dimensions.duplicate()
	var empty: Dictionary = {}
	for dim in IntelDimensions.ALL_DIMENSIONS:
		empty[dim] = 0.0
	return empty

## 🆕 获取某卡某维度的揭示等级 (-1=未触发, 0-3)
func get_revealed_tier(card_id: String, dimension: String) -> int:
	if _entries.has(card_id):
		var entry: IntelEntry = _entries[card_id]
		return int(entry.revealed_tiers.get(dimension, -1))
	return -1

## 🆕 获取某卡所有维度的揭示等级
func get_all_revealed_tiers(card_id: String) -> Dictionary:
	if _entries.has(card_id):
		return _entries[card_id].revealed_tiers.duplicate()
	var empty: Dictionary = {}
	for dim in IntelDimensions.ALL_DIMENSIONS:
		empty[dim] = -1
	return empty

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

# ── 掉落率加成 ────────────────────────────────────────────────────

## 获取某卡的掉落率加成倍率
## 情报100%时掉落率+50%，即返回 1.5；否则返回 1.0
func get_drop_bonus_multiplier(card_id: String) -> float:
	return 1.5 if is_complete(card_id) else 1.0

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
			# 所有4维情报设为100%
			for dim in IntelDimensions.ALL_DIMENSIONS:
				entry.intel_dimensions[dim] = 1.0
				entry.revealed_tiers[dim] = 4  # 最高等级
			if not _completed_cache.has(card.card_id):
				_completed_cache.append(card.card_id)
	_completed_cache = _completed_cache.duplicate()  # 触发更新
