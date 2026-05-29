extends Node
class_name IntelManualUI
## 情报手册 UI 数据层（简化版）
## 纯数据层，不依赖具体 UI 场景节点。
## 提供格式化查询接口供任意 UI 场景调用。
## 缓存已解锁/未解锁列表，支持快速过滤。
##
## 使用方式（自动加载）：
##   1. 在项目设置 Autoload 中注册 IntelManual 和 IntelManualUI
##   2. UI 场景中通过 IntelManualUI.get_card_summary() 等接口获取展示数据
##
## 依赖：
##   - IntelManual（核心数据层）

# ── 常量 ──────────────────────────────────────────────────────────

## 阶梯描述（与 IntelManual 对齐）
const TIER_LABELS: Dictionary = {
	0: "???",
	1: "基础情报",
	2: "详细情报",
	3: "弱点分析",
	4: "完全解析",
}

## 阶梯对应颜色名（供 UI 主题映射）
const TIER_COLOR_KEYS: Dictionary = {
	0: "locked",
	1: "common",
	2: "uncommon",
	3: "rare",
	4: "legendary",
}

## 阶梯解锁条件描述
const TIER_UNLOCK_DESC: Dictionary = {
	0: "",
	1: "情报 ≥ 25%",
	2: "情报 ≥ 50%",
	3: "情报 ≥ 75%",
	4: "情报 ≥ 100%",
}

# ── 缓存 ──────────────────────────────────────────────────────────

## 已完全解锁列表（card_id -> bool）
var _unlocked_cache: Dictionary = {}
## 未解锁列表（card_id -> bool）
var _locked_cache: Dictionary = {}
## 缓存是否需要刷新
var _cache_dirty: bool = true

## 引用核心数据层
var _manual: IntelManual = null

# ── 生命周期 ──────────────────────────────────────────────────────

func _ready() -> void:
	# 等待 IntelManual 就绪
	call_deferred("_setup")

func _setup() -> void:
	_manual = get_node_or_null("/root/IntelManual")
	if _manual == null:
		push_warning("[IntelManualUI] 未找到 IntelManual 自动加载节点")
		return
	# 监听信号以标记缓存脏
	if _manual.intel_progress_changed.is_connected(_on_intel_changed):
		_manual.intel_progress_changed.disconnect(_on_intel_changed)
	_manual.intel_progress_changed.connect(_on_intel_changed)
	if _manual.intel_completed.is_connected(_on_intel_completed):
		_manual.intel_completed.disconnect(_on_intel_completed)
	_manual.intel_completed.connect(_on_intel_completed)
	_refresh_cache()

# ── 信号回调 ──────────────────────────────────────────────────────

func _on_intel_changed(_card_id: String, _old: float, _new: float, _source: String) -> void:
	_cache_dirty = true

func _on_intel_completed(card_id: String) -> void:
	_unlocked_cache[card_id] = true
	if _locked_cache.has(card_id):
		_locked_cache.erase(card_id)

# ── 缓存管理 ──────────────────────────────────────────────────────

## 强制刷新缓存
func _refresh_cache() -> void:
	if _manual == null:
		return
	_unlocked_cache.clear()
	_locked_cache.clear()
	var all_ids: Array = _manual.get_known_card_ids()
	for cid in all_ids:
		if _manual.is_complete(cid):
			_unlocked_cache[cid] = true
		else:
			_locked_cache[cid] = true
	_cache_dirty = false

## 确保缓存最新
func _ensure_cache() -> void:
	if _cache_dirty:
		_refresh_cache()

# ── 公开接口：查询 ────────────────────────────────────────────────

## 获取单张卡片的情报摘要（供 UI 显示）
## 返回结构化字典：
## {
##   "card_id": String,
##   "progress": float,         # 0.0 - 1.0
##   "progress_pct": String,     # "45%"
##   "tier": int,                # 0-4
##   "tier_label": String,       # "基础情报"
##   "tier_color_key": String,   # "common"
##   "tier_unlock_desc": String, # "情报 ≥ 50%"
##   "is_complete": bool,
##   "first_encountered": bool,
##   "defeat_count": int,
##   "drop_bonus": float,        # 1.0 或 1.5
##   "is_new": bool,             # 进度 > 0 且首次遭遇后尚未查看过
## }
func get_card_summary(card_id: String) -> Dictionary:
	_ensure_cache()
	if _manual == null:
		return _empty_summary(card_id)
	var entry: Dictionary = _manual.get_intel_entry(card_id)
	var progress: float = entry.get("intel_progress", 0.0)
	var tier: int = _manual.get_intel_reward_tier(card_id)
	return {
		"card_id": card_id,
		"progress": progress,
		"progress_pct": "%d%%" % int(progress * 100),
		"tier": tier,
		"tier_label": TIER_LABELS.get(tier, "???"),
		"tier_color_key": TIER_COLOR_KEYS.get(tier, "locked"),
		"tier_unlock_desc": TIER_UNLOCK_DESC.get(tier, ""),
		"is_complete": _manual.is_complete(card_id),
		"first_encountered": entry.get("first_encounter", false),
		"defeat_count": entry.get("defeat_count", 0),
		"drop_bonus": _manual.get_drop_bonus_multiplier(card_id),
		"is_new": entry.get("first_encounter", false) and progress < 1.0,
	}

## 获取所有卡片的情报摘要列表（按 card_id 排序）
func get_all_summaries(sort_by: String = "card_id", ascending: bool = true) -> Array:
	_ensure_cache()
	if _manual == null:
		return []
	var ids: Array = _manual.get_known_card_ids()
	var summaries: Array = []
	for cid in ids:
		summaries.append(get_card_summary(cid))
	# 排序
	match sort_by:
		"progress":
			summaries.sort_custom(func(a, b): return a["progress"] < b["progress"] if ascending else a["progress"] > b["progress"])
		"tier":
			summaries.sort_custom(func(a, b): return a["tier"] < b["tier"] if ascending else a["tier"] > b["tier"])
		"defeat_count":
			summaries.sort_custom(func(a, b): return a["defeat_count"] < b["defeat_count"] if ascending else a["defeat_count"] > b["defeat_count"])
		_:  # card_id
			summaries.sort_custom(func(a, b): return a["card_id"] < b["card_id"] if ascending else a["card_id"] > b["card_id"])
	return summaries

## 获取已解锁列表的卡片 ID 数组
func get_unlocked_ids() -> Array:
	_ensure_cache()
	return _unlocked_cache.keys()

## 获取未解锁列表的卡片 ID 数组
func get_locked_ids() -> Array:
	_ensure_cache()
	return _locked_cache.keys()

## 获取统计概览
func get_overview() -> Dictionary:
	_ensure_cache()
	if _manual == null:
		return {"total": 0, "completed": 0, "in_progress": 0, "completion_rate": "0%"}
	var total: int = _manual.get_total_entries()
	var completed: int = _manual.get_total_completed()
	return {
		"total": total,
		"completed": completed,
		"in_progress": total - completed,
		"completion_rate": "%d%%" % int(float(completed) / maxf(1, float(total)) * 100.0),
	}

## 获取阶梯分布统计
## 返回 { 0: count, 1: count, 2: count, 3: count, 4: count }
func get_tier_distribution() -> Dictionary:
	_ensure_cache()
	if _manual == null:
		return {0: 0, 1: 0, 2: 0, 3: 0, 4: 0}
	var dist: Dictionary = {0: 0, 1: 0, 2: 0, 3: 0, 4: 0}
	var ids: Array = _manual.get_known_card_ids()
	for cid in ids:
		var tier: int = _manual.get_intel_reward_tier(cid)
		dist[tier] = dist.get(tier, 0) + 1
	return dist

## 格式化阶梯名称
func format_tier_label(tier: int) -> String:
	return TIER_LABELS.get(tier, "???")

## 格式化阶梯颜色键
func format_tier_color_key(tier: int) -> String:
	return TIER_COLOR_KEYS.get(tier, "locked")

## 获取阶梯解锁条件描述
func format_tier_unlock_desc(tier: int) -> String:
	return TIER_UNLOCK_DESC.get(tier, "")

# ── 内部工具 ──────────────────────────────────────────────────────

func _empty_summary(card_id: String) -> Dictionary:
	return {
		"card_id": card_id,
		"progress": 0.0,
		"progress_pct": "0%",
		"tier": 0,
		"tier_label": "???",
		"tier_color_key": "locked",
		"tier_unlock_desc": "",
		"is_complete": false,
		"first_encountered": false,
		"defeat_count": 0,
		"drop_bonus": 1.0,
		"is_new": false,
	}
