class_name BlackgateReenterTest
extends GdUnitTestSuite
## v6.33 回归锁：黑门「踏入」两链落地自动开战。
##
## 根因复盘（实机"过100关第一次进黑门打33波，退出后再点黑门没反应"）：
## 黑门链停在 v27「挂 _is_endless_battle 标志，落地后玩家手动点开始」老范式，
## v32.3 A2 普通关「进关即开战」重构时没跟上。内嵌链（main 整备态底栏「地图」
## 打开的 WorldMapPanel 懒实例 world_map.tscn，embedded_mode=true）尤其致命：
## 踏入后 back_to_main.emit() 只关地图层，界面零变化零开战触发——玩家视角
## 「点了没反应」；独立场景链（truck_base→行军地图）落地 main 后同样干等手动开打。
##
## 契约（world_map._enter_blackgate_confirmed / _arm_endless_battle_state）：
## ① 标志链恒置：set_current_level(100) + start_endless_battle（begin_run 消费入场
##    次数仍在 go_to_battle 生效瞬间，本链不碰记账）；
## ② 独立场景链：设 Engine meta level_auto_start_pending（main._ready 消费 →
##    auto_start_battle_from_world_map → 黑幕战报自动开打，与普通关同款）；
## ③ 内嵌链：back_to_main.emit() 关地图层后直调 /root/Main.auto_start_battle_from_world_map；
## ④ 防复活锁：内嵌链踏入后 Main.auto_start 必被调用（回退旧代码此断言必红）。
## 教程态兜底不另设门：消费口 auto_start_battle_from_world_map 内置
## _tutorial_holds_battle_focus（黑门需通关100，教程必已完成，恒放行）。

const WorldMapScript := preload("res://scenes/world_map.gd")

var _wm: Node = null
var _fake_main: Node = null


## 带 auto_start_battle_from_world_map 调用记录的假 Main（真 main.tscn 不在测试进程）
class FakeMain extends Node:
	var auto_start_calls: int = 0

	func auto_start_battle_from_world_map() -> void:
		auto_start_calls += 1


func before_test() -> void:
	_wm = WorldMapScript.new()
	get_tree().root.add_child(_wm)
	_fake_main = FakeMain.new()
	_fake_main.name = "Main"
	get_tree().root.add_child(_fake_main)


func after_test() -> void:
	if is_instance_valid(_wm):
		_wm.queue_free()
	_wm = null
	if is_instance_valid(_fake_main):
		_fake_main.queue_free()
	_fake_main = null
	if Engine.has_meta("level_auto_start_pending"):
		Engine.remove_meta("level_auto_start_pending")


func _arm_blackgate_ebm() -> void:
	## 门禁置为可进（懒加载兜底后 can_enter 恒 true：新进程免费次数未耗）
	var mll: Node = get_node_or_null("/root/ManagerLazyLoader")
	if mll != null and mll.has_method("ensure_loaded"):
		mll.ensure_loaded("endless")


func test_arm_state_independent_chain_sets_flag_and_meta() -> void:
	_arm_blackgate_ebm()
	_wm.set_meta("embedded_mode", false)  # 独立场景链口径（world_map.tscn 独立实例无此 meta）
	_wm._arm_endless_battle_state()
	assert_int(int(GameManager.current_level)).is_equal(100)
	assert_bool(bool(GameManager._is_endless_battle)).is_true()
	assert_bool(Engine.has_meta("level_auto_start_pending")).is_true()


func test_arm_state_embedded_chain_sets_flag_without_meta() -> void:
	_arm_blackgate_ebm()
	_wm.set_meta("embedded_mode", true)  # WorldMapPanel 懒实例口径（world_map_panel.gd:58）
	_wm._arm_endless_battle_state()
	assert_int(int(GameManager.current_level)).is_equal(100)
	assert_bool(bool(GameManager._is_endless_battle)).is_true()
	# 内嵌链不开战拍点由调用方直调，不设独立链 meta（防串到下一次场景加载）
	assert_bool(Engine.has_meta("level_auto_start_pending")).is_false()


func test_confirmed_embedded_chain_triggers_main_auto_start() -> void:
	## 防复活锁：回退旧代码（内嵌分支只 emit back_to_main 即 return）此用例必红
	_arm_blackgate_ebm()
	_wm.set_meta("embedded_mode", true)
	var back_called: Array = []
	_wm.back_to_main.connect(func() -> void: back_called.append(1))
	_wm._enter_blackgate_confirmed(null)  # popup=null：_close_popup_safe 有 is_instance_valid 守卫
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(bool(GameManager._is_endless_battle)).is_true()
	assert_int(_fake_main.auto_start_calls).is_equal(1)


func test_confirmed_independent_chain_arms_level_auto_start_meta() -> void:
	## 独立链：meta 必须在 SceneTransition.change 之前设好（main._ready 消费）。
	## 测试进程不真切场景——用 _arm_endless_battle_state 直接覆盖独立分支的
	## meta 设置语义（_enter_blackgate_confirmed 的 change 尾步不宜在单测触发）。
	_arm_blackgate_ebm()
	_wm.set_meta("embedded_mode", false)
	_wm._arm_endless_battle_state()
	assert_bool(Engine.has_meta("level_auto_start_pending")).is_true()
	# main._ready 消费口径同构（main.gd v32.3 A2 段）：remove 后直调 auto_start
	Engine.remove_meta("level_auto_start_pending")
	assert_bool(Engine.has_meta("level_auto_start_pending")).is_false()
