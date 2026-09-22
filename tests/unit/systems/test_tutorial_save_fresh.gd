class_name TutorialSaveFreshTest
extends GdUnitTestSuite
## v6.22.4 回归锁：教程进度保存保真（2026-09-22 教程回退 bug 的双修复）
##
## 根因（docs/CHANGELOG 2026-09-22 晚条目）：
## ① tutorial_progress 在 SaveManager._collect_noncritical_save_data 里吃 10s 节流缓存——
##    缓存窗内保存会把推进前的教程步写回盘（完成步→10s 内存档/退出→步数回退）；
## ② completed_steps 经 JSON 往返 float 化后 has() 去重失效，每次保存膨胀 +3。
## 修复：① TPM 采集绕过缓存（每次现场采集）；② load_state 规范化 completed_steps 为 int。
## ⚠️ 真实 autoload 环境（GdUnit 全量启动），测试前后恢复 TPM 原状态。

const SK := "tutorial_progress"


func _get_tpm() -> Node:
	return get_node_or_null("/root/TutorialProgressionManager")


func _get_sm() -> Node:
	return get_node_or_null("/root/SaveManager")


func _snapshot_tpm() -> Dictionary:
	var tpm := _get_tpm()
	return tpm.save_state()


func _restore_tpm(snap: Dictionary) -> void:
	_get_tpm().load_state(snap)


func test_completed_steps_normalized_to_int_no_dup_growth() -> void:
	var tpm := _get_tpm()
	var snap := _snapshot_tpm()
	# 模拟旧档：JSON 往返后的 float 步值
	tpm.load_state({"version": 4, "current_step": 1, "completed_steps": [1.0, 2.0, 3.0]})
	# 推进 3 步（INTRO→CARD_COLLECTION→PHASE_INSTRUMENT）——若去重失效会膨胀出 6+ 项
	for _i in 3:
		tpm.complete_current_step()
	var saved: Dictionary = tpm.save_state()
	var steps: Array = saved.get("completed_steps", [])
	assert_int(steps.size()).is_equal(3)
	for st in steps:
		assert_bool(st is int or (st is float and is_equal_approx(float(st), roundf(float(st))))).is_true()
	assert_int(int(saved.get("current_step", 0))).is_equal(int(3))  # PHASE_INSTRUMENT
	_restore_tpm(snap)


func test_tutorial_section_bypasses_noncritical_cache() -> void:
	var tpm := _get_tpm()
	var sm := _get_sm()
	var snap := _snapshot_tpm()
	# 第一帧采集：预热缓存（模拟读档后自动存档）
	var data1: Dictionary = {}
	sm._collect_noncritical_save_data(data1, Time.get_ticks_msec())
	assert_bool(data1.has(SK)).is_true()
	# 玩家推进教程（内存步前移）
	tpm.load_state({"version": 4, "current_step": 1, "completed_steps": [1.0, 2.0, 3.0]})
	tpm.complete_current_step()
	var expect_step: int = int(tpm.get("current_step"))
	# 10s 节流窗内的第二次保存（旧实现：整段复用缓存 → 步数回退）
	var data2: Dictionary = {}
	sm._collect_noncritical_save_data(data2, Time.get_ticks_msec())
	assert_bool(data2.has(SK)).is_true()
	var tut: Dictionary = data2.get(SK, {})
	assert_int(int(tut.get("current_step", -1))).is_equal(expect_step)
	# 且缓存本体不含 tutorial 键（旁路语义；否则下轮又会回退）
	assert_bool(sm.get("_noncritical_save_cache").has(SK)).is_false()
	_restore_tpm(snap)
