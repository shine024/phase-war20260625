extends GdUnitTestSuite
## v6.41（2026-10-04）回归锁：教程框 z 序 × 符文步「针对已开窗口」对齐。
##
## 实机主诉（截图）：符文步提示框被卡仓面板整只吞掉——main 场景教程框宿主原为
## HudLayer(40)，在 PopupLayer(100) 之下：卡格切割框内文字、面板全屏 STOP 拦截框内
## 按钮点击；且框弹出时背包停在战斗卡页（current_tab=0），提示与眼前窗口脱节。
##
## 修复契约（本锁断言的三个维度；渲染级目检由 tests/_tmp_v641_tutorial_z_probe.gd
## 真机探针承载：框浮于面板上、符文页激活、文字无切割）：
##   Z 序   —— main 教程框宿主 TutorialLayer 层号必须 > PopupLayer(100)（现 105，
##             同时 < InfoPanelLayer(110) 点卡详情、< Toast(200)）
##   对齐口 —— TPM.is_backpack_surface_step()：SURFACE_FOR_STEP 中唯一 "backpack"
##             触达面=符文步；对齐语义不得被未来新增面劫持
##   守卫   —— 场景侧对齐/切页 helper：出树早退不炸（拆场守卫同律）、面板未开不切
##
## ⚠️ 回归=有人把 overlay 宿主改回 HudLayer/低层号，或删掉 _align_runes_step_with_open_backpack
## 调用点——本锁红即主诉复发。

const MainScript = preload("res://scenes/main.gd")
const TruckBaseScript = preload("res://scenes/bunker/truck_base.gd")
const MainScene = preload("res://scenes/main.tscn")

var _tpm: Node = null
var _orig_step: int = -1
var _orig_chain: bool = false
var _orig_pending: String = ""
var _orig_completed: Array = []


func before_test() -> void:
	_tpm = get_node_or_null("/root/TutorialProgressionManager")
	assert_bool(_tpm != null).is_true()
	_orig_step = int(_tpm.current_step)
	_orig_chain = bool(_tpm.chain_paused)
	_orig_pending = String(_tpm.pending_close_surface)
	_orig_completed = (_tpm.completed_steps as Array).duplicate()


func after_test() -> void:
	_tpm.current_step = _orig_step
	_tpm.chain_paused = _orig_chain
	_tpm.pending_close_surface = _orig_pending
	_tpm.completed_steps = _orig_completed


## ── Z 序维度 ──────────────────────────────────────────────────────
## 教程框宿主层 > PopupLayer：任何弹层面板打开时框不得被压住（主诉根因）。
func test_main_tutorial_layer_above_popup_layer() -> void:
	var main_inst: Node = MainScript.new()
	var layer: CanvasLayer = main_inst._tutorial_layer()
	assert_object(layer).is_not_null()
	var scene_inst: Node = MainScene.instantiate()
	var popup_layer: CanvasLayer = scene_inst.get_node("PopupLayer")
	assert_int(popup_layer.layer).is_equal(100)
	assert_int(layer.layer).is_greater(popup_layer.layer)
	# 层号上限契约：低于点卡详情层(110)与 Toast(200)，不反压玩家主动打开的详情/反馈
	assert_int(layer.layer).is_less(110)
	main_inst.free()
	scene_inst.free()


## overlay 落位在 TutorialLayer 下（防宿主改回 HudLayer 的回归）。
func test_main_overlay_hosted_in_tutorial_layer() -> void:
	var main_inst: Node = MainScript.new()
	main_inst._show_tutorial_overlay()
	var ov: Node = main_inst.get_node_or_null("TutorialLayer/TutorialOverlay")
	assert_object(ov).is_not_null()
	# 防重复挂：二次调用不产生第二个实例
	main_inst._show_tutorial_overlay()
	var found := 0
	for child in main_inst.get_node("TutorialLayer").get_children():
		if child.name == "TutorialOverlay":
			found += 1
	assert_int(found).is_equal(1)
	main_inst.free()


## ── 对齐口维度（TPM 契约）─────────────────────────────────────────
## 唯一 backpack 触达面=符文步；符文步命中、其它步不命中、教程外不命中。
func test_backpack_surface_step_is_runes_only() -> void:
	_tpm.current_step = _tpm.TutorialStep.RUNES
	assert_bool(_tpm.is_backpack_surface_step()).is_true()
	_tpm.current_step = _tpm.TutorialStep.MODIFICATION
	assert_bool(_tpm.is_backpack_surface_step()).is_false()
	_tpm.current_step = _tpm.TutorialStep.CARD_COLLECTION
	assert_bool(_tpm.is_backpack_surface_step()).is_false()
	_tpm.current_step = _tpm.TutorialStep.FREEDOM_MODE
	assert_bool(_tpm.is_backpack_surface_step()).is_false()
	_tpm.current_step = _tpm.TutorialStep.NONE
	assert_bool(_tpm.is_backpack_surface_step()).is_false()


## SURFACE_FOR_STEP 里 "backpack" 只允许出现一次——出现第二个面会劫持对齐语义
##（非符文步开背包也被强切符文页）。
func test_backpack_surface_unique_in_surface_table() -> void:
	var hits := 0
	for key in _tpm.SURFACE_FOR_STEP:
		if String(_tpm.SURFACE_FOR_STEP[key]) == "backpack":
			hits += 1
	assert_int(hits).is_equal(1)


## ── 守卫维度（场景侧 helper）──────────────────────────────────────
## main 对齐 helper 出树早退（deferred 回调落在已出树场景上不得报错）。
func test_main_align_helper_out_of_tree_safe() -> void:
	var main_inst: Node = MainScript.new()
	main_inst._align_runes_step_with_open_backpack()
	main_inst.free()


## truck 切页 helper：面板开着才切；未开/缺面板零开销不炸。
func test_truck_switch_helper_guards() -> void:
	var tb: Node = TruckBaseScript.new()
	# 空表：无面板不炸
	tb._switch_embedded_backpack_to_runes_tab()
	# 面板开 → 切；面板关 → 不切
	var open_wrapper: Control = Control.new()
	var closed_wrapper: Control = Control.new()
	var open_stub = _make_runes_tab_stub()
	open_stub.visible = true
	var closed_stub = _make_runes_tab_stub()
	closed_stub.visible = false
	tb._embed_wrappers = {
		"backpack": {"wrapper": open_wrapper, "panel": open_stub},
	}
	tb._switch_embedded_backpack_to_runes_tab()
	assert_bool(open_stub.called).is_true()
	tb._embed_wrappers = {
		"backpack": {"wrapper": closed_wrapper, "panel": closed_stub},
	}
	tb._switch_embedded_backpack_to_runes_tab()
	assert_bool(closed_stub.called).is_false()
	tb.free()
	open_stub.free()
	closed_stub.free()
	open_wrapper.free()
	closed_wrapper.free()


## truck 对齐 helper 出树早退（守卫与 main 侧同律）。
func test_truck_align_helper_out_of_tree_safe() -> void:
	var tb: Node = TruckBaseScript.new()
	tb._align_runes_step_with_open_backpack()
	tb.free()


func _make_runes_tab_stub() -> Control:
	var s := GDScript.new()
	s.source_code = "extends Control\nvar called := false\nfunc switch_to_runes_tab() -> void:\n\tcalled = true\n"
	s.reload()
	return s.new()
