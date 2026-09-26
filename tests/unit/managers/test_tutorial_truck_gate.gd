extends GdUnitTestSuite
## v6.28（记录2#4）回归锁：首胜后「移动基地」教程门。
## is_pending_truck_base_intro()=true 时 mvp_panel 两直通键隐藏（返回 0），
## 强制首胜后回基地看 TRUCK_BASE 引导——修"都胜利好几次了才提示首战打通"。
## 门解除条件：TRUCK_BASE 步完成 / 教程跳过或已完成（FREEDOM_MODE）。
## 测试直接操纵 autoload 内存态（current_step/completed_steps），测毕还原。

const TpmScript = preload("res://managers/tutorial_progression_manager.gd")

var _tpm: Node = null
var _orig_step: int = -1
var _orig_completed: Array = []


func before_test() -> void:
	_tpm = get_node_or_null("/root/TutorialProgressionManager")
	assert_bool(_tpm != null).is_true()
	_orig_step = int(_tpm.current_step)
	_orig_completed = (_tpm.completed_steps as Array).duplicate()


func after_test() -> void:
	_tpm.current_step = _orig_step
	_tpm.completed_steps = _orig_completed


func test_gate_open_at_truck_base_pending() -> void:
	# 首胜后停在 TRUCK_BASE、未完成 → 门开（直通键隐藏）
	_tpm.current_step = TpmScript.TutorialStep.TRUCK_BASE
	_tpm.completed_steps = []
	assert_bool(_tpm.is_pending_truck_base_intro()).is_true()


func test_gate_closed_after_truck_base_completed() -> void:
	# TRUCK_BASE 步完成 → 门解除
	_tpm.current_step = TpmScript.TutorialStep.TRUCK_BASE
	_tpm.completed_steps = [TpmScript.TutorialStep.TRUCK_BASE]
	assert_bool(_tpm.is_pending_truck_base_intro()).is_false()


func test_gate_closed_in_freedom_mode() -> void:
	# 跳过/已完成教程（FREEDOM_MODE，老档兜底）→ 永不设门
	_tpm.current_step = TpmScript.TutorialStep.FREEDOM_MODE
	_tpm.completed_steps = []
	assert_bool(_tpm.is_pending_truck_base_intro()).is_false()


func test_gate_closed_at_other_steps() -> void:
	# 其他任何步（含首战步、后续面板步）都不设门
	for step in [TpmScript.TutorialStep.NONE,
			TpmScript.TutorialStep.FIRST_BATTLE,
			TpmScript.TutorialStep.MODIFICATION]:
		_tpm.current_step = step
		_tpm.completed_steps = []
		assert_bool(_tpm.is_pending_truck_base_intro()).is_false()


func test_gate_releases_via_skip() -> void:
	# 首胜门开着时 skip_tutorial() → FREEDOM_MODE → 门解除
	_tpm.current_step = TpmScript.TutorialStep.TRUCK_BASE
	_tpm.completed_steps = []
	assert_bool(_tpm.is_pending_truck_base_intro()).is_true()
	_tpm.skip_tutorial()
	assert_bool(_tpm.is_pending_truck_base_intro()).is_false()
