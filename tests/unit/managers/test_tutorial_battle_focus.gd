extends GdUnitTestSuite
## v6.30（2026-09-27）回归锁：教程拦"落地自动开战/结算直通键"的门槛语义。
## main._tutorial_holds_battle_focus()（launch_from_bunker 与 level_auto_start_pending
## 两链共用）= should_show_tutorial() 且未过首战步——本文件锁这两个原语在关键步的
## 取值；mvp_panel 侧直通键只看 is_past_first_battle（见 test_settlement_next_level.gd
## test_first_victory_direct_keys_at_truck_base_step）。
## 前身 test_tutorial_truck_gate.gd 锁的 v6.28「移动基地」引导门已按用户拍板撤销删除。
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


func test_truck_base_pending_releases_battle_focus() -> void:
	# 首胜后停在 TRUCK_BASE（未完成）→ 已过首战步：进关自动开战放行、直通键放行
	_tpm.current_step = TpmScript.TutorialStep.TRUCK_BASE
	_tpm.completed_steps = []
	assert_bool(_tpm.should_show_tutorial()).is_true()
	assert_bool(_tpm.is_past_first_battle()).is_true()


func test_pre_first_battle_steps_hold_battle_focus() -> void:
	# 教程进行中且未过首战步（NONE=未启动 / 首战前步 / 首战步本身）→ 让路
	# （NONE 与旧 should_show_tutorial 口径行为一致；首战链 tutorial_first_battle 自管）
	for step in [TpmScript.TutorialStep.NONE,
			TpmScript.TutorialStep.CARD_COLLECTION,
			TpmScript.TutorialStep.PHASE_INSTRUMENT,
			TpmScript.TutorialStep.FIRST_BATTLE]:
		_tpm.current_step = step
		_tpm.completed_steps = []
		assert_bool(_tpm.should_show_tutorial()).is_true()
		assert_bool(_tpm.is_past_first_battle()).is_false()


func test_freedom_mode_releases_battle_focus() -> void:
	# 教程完成（FREEDOM_MODE）→ 不拦
	_tpm.current_step = TpmScript.TutorialStep.FREEDOM_MODE
	_tpm.completed_steps = []
	assert_bool(_tpm.should_show_tutorial()).is_false()
	assert_bool(_tpm.is_past_first_battle()).is_true()


func test_skip_tutorial_releases_battle_focus() -> void:
	# 教程进行中 skip_tutorial() → FREEDOM_MODE → 放行
	_tpm.current_step = TpmScript.TutorialStep.FIRST_BATTLE
	_tpm.completed_steps = []
	_tpm.skip_tutorial()
	assert_bool(_tpm.should_show_tutorial()).is_false()


func test_truck_gate_revoked() -> void:
	# v6.28「移动基地」引导门已删除——防止回归复活（复活即回到
	# "首胜结算没有下一关/基地出击不自动开战"的用户主诉）
	assert_bool(_tpm.has_method("is_pending_truck_base_intro")).is_false()
