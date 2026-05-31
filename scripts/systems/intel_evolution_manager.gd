extends Node
class_name IntelEvolutionManager
## v6.0: 情报进化管理器
## 负责：
##   - 检查情报进化分支是否可发现
##   - 管理已发现/已领取的分支状态
##   - 提供查询接口
##
## 依赖：
##   - IntelManual（情报数据）
##   - IntelEvolutionBranches（分支定义）

const IntelEvolutionBranches = preload("res://data/intel_evolution_branches.gd")
const IntelDimensions = preload("res://data/intel_dimensions.gd")

# ── 信号 ──────────────────────────────────────────────────────────

## 分支被发现 signal(branch_id, branch_data)
signal intel_branch_discovered(branch_id: String, branch_data: Dictionary)
## 分支可领取 signal(card_id, branch_id)
signal intel_branch_available(card_id: String, branch_id: String)
## 分支已领取 signal(card_id, branch_id)
signal intel_branch_claimed(card_id: String, branch_id: String)

# ── 内部状态 ──────────────────────────────────────────────────────

## 已发现的分支: branch_id -> true
var _discovered: Dictionary = {}

## 已领取的分支: branch_id -> {card_id: str, timestamp: float}
var _claimed: Dictionary = {}

# ── 生命周期 ──────────────────────────────────────────────────────

func _ready() -> void:
	_load_state()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_state()

# ── 存档 ───────────────────────────────────────────────────────────

const SaveUtils = preload("res://scripts/save_utils.gd")
const STATE_SAVE_NAME: String = "intel_evolution_state"

func _save_state() -> void:
	var data: Dictionary = {
		"discovered": _discovered.duplicate(),
		"claimed": _claimed.duplicate(),
	}
	SaveUtils.save_data_to_file(data, STATE_SAVE_NAME)

func _load_state() -> void:
	var data: Dictionary = SaveUtils.load_data_from_file(STATE_SAVE_NAME)
	_discovered = data.get("discovered", {})
	_claimed = data.get("claimed", {})
	print("[IntelEvolutionManager] 加载完成，已发现 %d 条分支，已领取 %d 条" % [
		_discovered.size(), _claimed.size()
	])

# ── 核心接口 ───────────────────────────────────────────────────────

## 检查并发现新的情报进化分支
## 返回新发现的分支列表
func check_and_discover_branches() -> Array:
	var new_discoveries: Array = []
	var im: Node = get_node_or_null("/root/IntelManual")
	if im == null:
		return new_discoveries

	for bid in IntelEvolutionBranches.get_all_branch_ids():
		if _discovered.has(bid):
			continue
		if _check_branch_requirements(bid, im):
			_discovered[bid] = true
			var branch_data: Dictionary = IntelEvolutionBranches.get_branch(bid)
			new_discoveries.append(branch_data)
			intel_branch_discovered.emit(bid, branch_data)
			print("[IntelEvolutionManager] 🗺️ 发现隐藏进化分支: %s" % branch_data.get("name", bid))

	if not new_discoveries.is_empty():
		_save_state()
	return new_discoveries

## 获取某张卡的所有进化选项（含情报分支）
func get_evolution_options_for_card(card_id: String, bpm_ref: Node) -> Array[Dictionary]:
	var branches: Array[Dictionary] = []
	for bid in _discovered:
		var b: Dictionary = IntelEvolutionBranches.get_branch(bid)
		if b.is_empty():
			continue
		var sources: Array = b.get("source_card_ids", [])
		if card_id in sources:
			branches.append(b.duplicate(true))
			branches[-1]["_branch_id"] = bid
			branches[-1]["_discovered"] = true
			branches[-1]["_claimed"] = _claimed.has(bid)
	return branches

## 领取情报进化分支
func claim_branch(card_id: String, branch_id: String) -> bool:
	if not _discovered.has(branch_id):
		return false
	if _claimed.has(branch_id):
		return false
	_claimed[branch_id] = {"card_id": card_id, "timestamp": Time.get_ticks_msec() / 1000.0}
	intel_branch_claimed.emit(card_id, branch_id)
	_save_state()
	return true

## 检查分支是否已发现
func is_branch_discovered(branch_id: String) -> bool:
	return _discovered.has(branch_id)

## 检查分支是否已领取
func is_branch_claimed(branch_id: String) -> bool:
	return _claimed.has(branch_id)

## 获取已发现的分支列表
func get_discovered_branches() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for bid in _discovered:
		var b: Dictionary = IntelEvolutionBranches.get_branch(bid)
		if not b.is_empty():
			b["_branch_id"] = bid
			b["_claimed"] = _claimed.has(bid)
			result.append(b)
	return result

# ── 内部工具 ──────────────────────────────────────────────────────

## 检查分支的所有情报条件是否满足
func _check_branch_requirements(branch_id: String, im: Node) -> bool:
	var reqs: Dictionary = IntelEvolutionBranches.get_intel_requirements(branch_id)
	if reqs.is_empty():
		return false

	for enemy_type in reqs:
		var req: Dictionary = reqs[enemy_type]
		if not req is Dictionary:
			continue
		var dimension: String = req.get("dimension", "")
		var threshold: float = float(req.get("threshold", 0.0))
		if dimension.is_empty() or threshold <= 0.0:
			continue
		## 查找该敌人类型的最高情报
		var best_progress: float = _get_best_dimension_progress_for_type(im, enemy_type, dimension)
		if best_progress < threshold:
			return false
	return true

## 获取某敌人类型某维度的最高情报进度
func _get_best_dimension_progress_for_type(im: Node, enemy_type: String, dimension: String) -> float:
	var best: float = 0.0
	for card_id in im.get_known_card_ids():
		var et: String = im.get_enemy_type(card_id)
		if et == enemy_type:
			var val: float = im.get_dimension_progress(card_id, dimension)
			best = maxf(best, val)
	return best
