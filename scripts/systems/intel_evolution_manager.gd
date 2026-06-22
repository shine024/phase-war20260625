extends Node
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
	# v6.6: 移除自加载，由 SaveManager 统一加载
	pass

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_state()

# ── 存档 ───────────────────────────────────────────────────────────

const SaveUtils = preload("res://scripts/save_utils.gd")
const STATE_SAVE_NAME: String = "intel_evolution_state"

## v6.6: 统一存档接口（供 SaveManager 调用）
func save_state() -> Dictionary:
	return {
		"discovered": _discovered.duplicate(),
		"claimed": _claimed.duplicate(),
	}

## v6.6: 统一存档加载接口。data 为空时尝试兼容读取旧独立文件
func load_state(data: Dictionary) -> void:
	if data.is_empty():
		var legacy: Dictionary = SaveUtils.load_data_from_file(STATE_SAVE_NAME)
		if not legacy.is_empty():
			_discovered = legacy.get("discovered", {})
			_claimed = legacy.get("claimed", {})
		return
	_discovered = data.get("discovered", {})
	_claimed = data.get("claimed", {})

func _save_state() -> void:
	SaveUtils.save_data_to_file(save_state(), STATE_SAVE_NAME)

func _load_state() -> void:
	var legacy: Dictionary = SaveUtils.load_data_from_file(STATE_SAVE_NAME)
	load_state(legacy)

## v6.6: 新游戏重置——清空所有字段，不读旧文件
func reset_progress() -> void:
	_discovered.clear()
	_claimed.clear()

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
			_force_discover_internal(bid, new_discoveries)

	if not new_discoveries.is_empty():
		_save_state()
	return new_discoveries

## v6.6: 强制发现某条进化分支（由揭示事件 intel_branch_unlock 奖励触发，跳过情报条件检查）
func force_discover_branch(branch_id: String) -> bool:
	if _discovered.has(branch_id):
		return false
	if not IntelEvolutionBranches.get_branch(branch_id).has("branch_id"):
		return false  # 分支不存在
	var dummy: Array = []
	_force_discover_internal(branch_id, dummy)
	_save_state()
	return true

## 内部：将分支标记为已发现并 emit 信号
func _force_discover_internal(branch_id: String, out_new: Array) -> void:
	_discovered[branch_id] = true
	var branch_data: Dictionary = IntelEvolutionBranches.get_branch(branch_id)
	out_new.append(branch_data)
	intel_branch_discovered.emit(branch_id, branch_data)

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
## v6.7: 单维度化，去掉 dimension 读取，直接用该 enemy_type 的最高 intel_progress 对比 threshold
func _check_branch_requirements(branch_id: String, im: Node) -> bool:
	var reqs: Dictionary = IntelEvolutionBranches.get_intel_requirements(branch_id)
	if reqs.is_empty():
		return false

	for enemy_type in reqs:
		var req: Dictionary = reqs[enemy_type]
		if not req is Dictionary:
			continue
		var threshold: float = float(req.get("threshold", 0.0))
		if threshold <= 0.0:
			continue
		## 查找该敌人类型的最高情报进度（单维度）
		var best_progress: float = _get_best_progress_for_type(im, enemy_type)
		if best_progress < threshold:
			return false
	return true

## 获取某敌人类型的最高情报进度（单维度）
func _get_best_progress_for_type(im: Node, enemy_type: String) -> float:
	var best: float = 0.0
	for card_id in im.get_known_card_ids():
		var et: String = im.get_enemy_type(card_id)
		if et == enemy_type:
			var val: float = im.get_intel_progress(card_id)
			best = maxf(best, val)
	return best
