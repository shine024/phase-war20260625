extends Node
class_name IntelManual
## 情报手册核心逻辑
## 管理所有敌方单位的情报数据：遭遇、击败、侦察、分解等情报获取，
## 情报奖励阶梯判定，存档/读档。
##
## 依赖：
##   - SaveUtils（存档/读档）
##   - SignalBus（信号通知）

const SaveUtils = preload("res://scripts/save_utils.gd")

# ── 常量 ──────────────────────────────────────────────────────────

## 情报获取量
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

## 情报奖励阶梯
const TIER_NONE: int = 0
const TIER_BASIC_STATS: int = 1     # 25%
const TIER_DETAIL_STATS: int = 2    # 50%
const TIER_WEAKNESS: int = 3        # 75%
const TIER_EVOLUTION: int = 4       # 100%

## 存档文件名
const SAVE_FILE_NAME: String = "intel_manual"

# ── 信号 ──────────────────────────────────────────────────────────

## 情报进度变化 signal(card_id, old_progress, new_progress, source)
signal intel_progress_changed(card_id: String, old_progress: float, new_progress: float, source: String)
## 情报奖励阶梯提升 signal(card_id, old_tier, new_tier)
signal intel_tier_up(card_id: String, old_tier: int, new_tier: int)
## 完全解锁（100%） signal(card_id)
signal intel_completed(card_id: String)

# ── 数据 ──────────────────────────────────────────────────────────

## card_id -> IntelEntry
var _entries: Dictionary = {}

## 缓存：已完全解锁的卡片 ID 列表
var _completed_cache: Array[String] = []

# ── IntelEntry 内部类 ─────────────────────────────────────────────

class IntelEntry:
	var card_id: String = ""
	var intel_progress: float = 0.0
	var is_unlocked: bool = false
	var first_encounter: bool = false
	var defeat_count: int = 0
	var recon_bonus: float = 0.0
	var decompose_bonus: float = 0.0

	func _init(id: String) -> void:
		card_id = id

	func to_dict() -> Dictionary:
		return {
			"card_id": card_id,
			"intel_progress": intel_progress,
			"is_unlocked": is_unlocked,
			"first_encounter": first_encounter,
			"defeat_count": defeat_count,
			"recon_bonus": recon_bonus,
			"decompose_bonus": decompose_bonus,
		}

	static func from_dict(data: Dictionary) -> IntelEntry:
		var entry := IntelEntry.new(data.get("card_id", ""))
		entry.intel_progress = clampf(data.get("intel_progress", 0.0), 0.0, 1.0)
		entry.is_unlocked = data.get("is_unlocked", false)
		entry.first_encounter = data.get("first_encounter", false)
		entry.defeat_count = int(data.get("defeat_count", 0))
		entry.recon_bonus = clampf(data.get("recon_bonus", 0.0), 0.0, 1.0)
		entry.decompose_bonus = clampf(data.get("decompose_bonus", 0.0), 0.0, 1.0)
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
	var raw: Dictionary = {}
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
		if raw[card_id] is Dictionary:
			_entries[card_id] = IntelEntry.from_dict(raw[card_id])
			if _entries[card_id].is_unlocked:
				_completed_cache.append(card_id)
	print("[IntelManual] 加载完成，共 %d 条情报记录" % _entries.size())

# ── 内部工具 ──────────────────────────────────────────────────────

## 确保情报条目存在，不存在则创建
func _ensure_entry(card_id: String) -> IntelEntry:
	if not _entries.has(card_id):
		_entries[card_id] = IntelEntry.new(card_id)
	return _entries[card_id]

## 获取随机值 [min_val, max_val]
func _rand_range_float(min_val: float, max_val: float) -> float:
	return randf_range(min_val, min(max_val, min_val + 1.0))

## 判定奖励阶梯
func _calc_tier(progress: float) -> int:
	if progress >= 1.0:  return TIER_EVOLUTION
	if progress >= 0.75: return TIER_WEAKNESS
	if progress >= 0.50: return TIER_DETAIL_STATS
	if progress >= 0.25: return TIER_BASIC_STATS
	return TIER_NONE

## 添加情报量并触发信号
func _add_intel(card_id: String, amount: float, source: String) -> void:
	var entry := _ensure_entry(card_id)
	if entry.intel_progress >= 1.0:
		return  # 已满
	var old_progress := entry.intel_progress
	var old_tier := _calc_tier(old_progress)
	entry.intel_progress = clampf(entry.intel_progress + amount, 0.0, 1.0)
	var new_progress := entry.intel_progress
	var new_tier := _calc_tier(new_progress)
	# 检查是否完全解锁
	if new_progress >= 1.0 and not entry.is_unlocked:
		entry.is_unlocked = true
		if not card_id in _completed_cache:
			_completed_cache.append(card_id)
		intel_completed.emit(card_id)
	# 阶梯提升
	if new_tier > old_tier:
		intel_tier_up.emit(card_id, old_tier, new_tier)
	intel_progress_changed.emit(card_id, old_progress, new_progress, source)
	save_data()

# ── 公开接口：情报获取 ─────────────────────────────────────────────

## 首次遭遇：+20% 情报
## 只在第一次遭遇时触发，返回实际获得的情报量
func register_first_encounter(card_id: String) -> float:
	var entry := _ensure_entry(card_id)
	if entry.first_encounter:
		return 0.0
	entry.first_encounter = true
	_add_intel(card_id, FIRST_ENCOUNTER_INTEL, "first_encounter")
	return FIRST_ENCOUNTER_INTEL

## 击败单位获得情报
## unit_rank: "normal" | "elite" | "boss"
## 返回实际获得的情报量
func register_defeat(card_id: String, unit_rank: String = "normal") -> float:
	var entry := _ensure_entry(card_id)
	entry.defeat_count += 1
	var amount: float = 0.0
	match unit_rank:
		"boss":
			amount = _rand_range_float(DEFEAT_BOSS_MIN, DEFEAT_BOSS_MAX)
		"elite":
			amount = _rand_range_float(DEFEAT_ELITE_MIN, DEFEAT_ELITE_MAX)
		_:
			amount = _rand_range_float(DEFEAT_NORMAL_MIN, DEFEAT_NORMAL_MAX)
	_add_intel(card_id, amount, "defeat_" + unit_rank)
	return amount

## 侦察激活获得情报
## recon_bonus_pct: 侦察加成百分比 (0.0-1.0)
## 返回实际获得的情报量
func register_recon(card_id: String, recon_bonus_pct: float = 0.0) -> float:
	var entry := _ensure_entry(card_id)
	var amount := _rand_range_float(RECON_MIN, RECON_MAX)
	# 应用侦察加成
	entry.recon_bonus = recon_bonus_pct
	amount += amount * recon_bonus_pct
	_add_intel(card_id, amount, "recon")
	return amount

## 分解重复卡获得情报
## 返回实际获得的情报量
func register_decompose(card_id: String) -> float:
	var entry := _ensure_entry(card_id)
	entry.decompose_bonus += DECOMPOSE_INTEL
	_add_intel(card_id, DECOMPOSE_INTEL, "decompose")
	return DECOMPOSE_INTEL

# ── 公开接口：查询 ────────────────────────────────────────────────

## 获取某卡的情报进度 (0.0-1.0)
func get_intel_progress(card_id: String) -> float:
	if _entries.has(card_id):
		return _entries[card_id].intel_progress
	return 0.0

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

## 获取某卡情报奖励阶梯
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
	return _entries.keys()

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
