extends Node
class_name TutorialManager
## 新手引导管理器：控制引导流程和显示

const TutorialDefs = preload("res://data/tutorial_definitions.gd")

signal tutorial_started(tutorial_id: String)
## tutorial_completed 已迁移至 SignalBus: SignalBus.tutorial_completed(tutorial_id)
signal tutorial_skipped(tutorial_id: String)
signal show_tutorial_requested(tutorial_id: String, step: Dictionary)

var _current_tutorial: String = ""
var _current_step_index: int = 0
var _completed_tutorials: Array = []

## 初始化
func _init() -> void:
	_load_completed_tutorials()

## 开始引导
func start_tutorial(tutorial_id: String) -> void:
	if _completed_tutorials.has(tutorial_id):
		return

	var tutorial = TutorialDefs.get_tutorial(tutorial_id)
	if tutorial.is_empty():
		return

	_current_tutorial = tutorial_id
	_current_step_index = 0

	tutorial_started.emit(tutorial_id)
	_show_current_step()

## 显示当前步骤
func _show_current_step() -> void:
	if _current_tutorial.is_empty():
		return

	var tutorial = TutorialDefs.get_tutorial(_current_tutorial)
	var steps = tutorial.get("steps", [])

	if _current_step_index >= steps.size():
		_complete_tutorial()
		return

	var step = steps[_current_step_index]
	_show_tutorial_overlay(step)

## 显示引导覆盖层
func _show_tutorial_overlay(step: Dictionary) -> void:
	show_tutorial_requested.emit(_current_tutorial, step)

## 下一步
func next_step() -> void:
	_current_step_index += 1
	_show_current_step()

## 跳过引导
func skip_tutorial() -> void:
	if _current_tutorial.is_empty():
		return

	tutorial_skipped.emit(_current_tutorial)
	_current_tutorial = ""
	_current_step_index = 0

## 完成引导
func _complete_tutorial() -> void:
	if _current_tutorial.is_empty():
		return

	if not _completed_tutorials.has(_current_tutorial):
		_completed_tutorials.append(_current_tutorial)
		_save_completed_tutorials()

	var tutorial = TutorialDefs.get_tutorial(_current_tutorial)
	var rewards = tutorial.get("reward", {})
	_grant_rewards(rewards)

	SignalBus.tutorial_completed.emit(_current_tutorial)
	_current_tutorial = ""
	_current_step_index = 0

## 发放奖励
func _grant_rewards(rewards: Dictionary) -> void:
	if rewards.is_empty():
		return

	# 发放纳米材料
	if rewards.has("nano_materials"):
		var amount = rewards["nano_materials"]
		var brm = get_node_or_null("/root/BasicResourceManager")
		if brm and brm.has_method("add_resource"):
			brm.add_resource("nano_materials", amount)

	# 发放蓝图碎片
	if rewards.has("blueprint_fragments"):
		var fragments = rewards["blueprint_fragments"]
		var bpm = get_node_or_null("/root/BlueprintManager")
		if bpm:
			for fragment_id in fragments:
				var count = fragments[fragment_id]
			if bpm.has_method("add_blueprint_copy"):
				bpm.add_blueprint_copy(fragment_id, count)

## 检查引导是否完成
func is_tutorial_completed(tutorial_id: String) -> bool:
	return _completed_tutorials.has(tutorial_id)

## 获取引导进度
func get_progress() -> Dictionary:
	return TutorialDefs.get_tutorial_progress()

## 保存完成的引导
func _save_completed_tutorials() -> void:
		# SaveManager会自动保存TutorialProgressionManager的状态

## 加载完成的引导
func _load_completed_tutorials() -> void:
		# SaveManager会自动加载TutorialProgressionManager的状态

## 获取下一个待完成的引导
func get_next_tutorial() -> Dictionary:
	for tutorial_id in TutorialDefs.TUTORIALS.keys():
		if not _completed_tutorials.has(tutorial_id):
			return TutorialDefs.get_tutorial(tutorial_id)
	return {}

## 重置引导进度（用于测试）
func reset_progress() -> void:
	_completed_tutorials.clear()
	_save_completed_tutorials()
