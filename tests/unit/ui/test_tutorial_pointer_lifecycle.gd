extends GdUnitTestSuite
## v6.41.1（2026-10-04）回归锁：教程指路标生命周期——跨步单标流转 + 按名消散。
##
## 实机主诉（截图）：基地同时挂 3 条「下一步」指路标（符文/制造/势力），且点了指向的
## 工位按钮提示也不自动关。根因（tests/_tmp_v642_pointer_probe.gd 转储实证）：
## show_step_pointer 同帧"queue_free 旧宿主 + add_child 同名新宿主"，旧宿主帧末才消失，
## 新宿主撞名被 Godot 静默改名为 @Control@N——此后精确名 dismiss_step_pointer 永远
## 找不到它（found=0），旧标跨步堆积、点目标按钮也不消散。
##
## 修复契约（本锁；计数一律 await 帧后取稳定态——queue_free 帧末才摘除）：
##   唯一命名 —— 新宿主名 TutorialStepPointer_<serial>，杜绝撞名改名（名字可被按名追踪）
##   通配消散 —— dismiss 按 "TutorialStepPointer*" 匹配：唯一名/旧精确名宿主全清
##   跨步流转 —— 连续亮标（跨帧稳定态）恒 1 宿主；显式 dismiss 后 0 宿主
## 真机目检（单标+金环+点按钮后消散）由探针承载：res://tests/_tmp_v642_pointer_probe.tscn
## 注："目标不可见不亮标"守卫在调用方（truck_base/main _maybe_spawn_tutorial_pointer），
## 不在静态工厂——工厂对不可见目标照常建宿主（spotlight _process 自行暂停显示）。

const TutorialSpotlight = preload("res://scripts/ui/tutorial_spotlight.gd")

var _root: Control = null
var _btn_a: Button = null
var _btn_b: Button = null


func before_test() -> void:
	_root = Control.new()
	_root.name = "PointerLifecycleRoot"
	add_child(_root)
	_btn_a = Button.new()
	_btn_a.text = "工位A"
	_root.add_child(_btn_a)
	_btn_b = Button.new()
	_btn_b.text = "工位B"
	_root.add_child(_btn_b)


func after_test() -> void:
	# 清场：先消散标再摘根（防孤儿节点=exit 101 噪音）
	TutorialSpotlight.dismiss_step_pointer(_root)
	await get_tree().process_frame
	remove_child(_root)
	_root.free()


func _host_count() -> int:
	return _root.find_children("TutorialStepPointer*", "Control", true, false).size()


func _settle() -> void:
	# queue_free 帧末才摘除：两帧后计数才是稳定态（与真机流转同口径）
	await get_tree().process_frame
	await get_tree().process_frame


## 跨步流转：连续两次亮标（跨帧稳定态），旧标消散、恒 1 宿主（回归=堆积成 2+）。
func test_respawn_collapses_to_single_host() -> void:
	TutorialSpotlight.show_step_pointer(_root, _btn_a, "去工位A")
	await _settle()
	assert_int(_host_count()).is_equal(1)
	TutorialSpotlight.show_step_pointer(_root, _btn_b, "去工位B")
	await _settle()
	assert_int(_host_count()).is_equal(1)


## 唯一命名：宿主名恒以 TutorialStepPointer 开头——撞名被改成 @Control@N 的宿主
## 就是"按名消散永远找不到"的元凶，名字可追踪是消散链成立的前提。
func test_host_name_stays_discoverable() -> void:
	TutorialSpotlight.show_step_pointer(_root, _btn_a, "去工位A")
	await _settle()
	var hosts := _root.find_children("TutorialStepPointer*", "Control", true, false)
	assert_int(hosts.size()).is_equal(1)
	assert_bool(String(hosts[0].name).begins_with("TutorialStepPointer")).is_true()
	# 二次亮标（同帧 queue_free 旧宿主后再 add）后名字仍可追踪——撞名改名不复现
	TutorialSpotlight.show_step_pointer(_root, _btn_b, "去工位B")
	await _settle()
	hosts = _root.find_children("TutorialStepPointer*", "Control", true, false)
	assert_int(hosts.size()).is_equal(1)
	assert_bool(String(hosts[0].name).begins_with("TutorialStepPointer")).is_true()


## 消散覆盖面：唯一名宿主与 v6.41.1 前的旧精确名宿主都要清得掉。
func test_dismiss_clears_unique_and_legacy_hosts() -> void:
	TutorialSpotlight.show_step_pointer(_root, _btn_a, "去工位A")
	var legacy := Control.new()
	legacy.name = "TutorialStepPointer"   # v6.41.1 前的精确名宿主形态
	_root.add_child(legacy)
	TutorialSpotlight.dismiss_step_pointer(_root)
	await _settle()
	assert_int(_host_count()).is_equal(0)
