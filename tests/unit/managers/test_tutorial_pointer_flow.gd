extends GdUnitTestSuite
## v6.39（2026-10-03）回归锁：朝露式指路标（点播段挂起等待的「下一步去哪」）。
## 参考原型《朝露：境界旅程》被好评的"路线指引"模式——教程点播段 overlay 收起后，
## 玩家要在基地自己摸目标工位，此前零指向（本项目对照朝露差评"第一个任务不知道去哪"
## 的同款缺陷）。本锁覆盖 TPM 侧的挂起态生命周期：
##   complete→进等待=请求亮标；打开任意面板=收标；关闭面板=重亮；
##   命中本步=放行 overlay 并清挂起；skip/reset=收标。
## UI 侧（tutorial_spotlight.show_step_pointer / truck_base._maybe_spawn_tutorial_pointer）
## 由真机探针目检验证，本文件锁数据与信号契约。
## 测试直接操纵 autoload 内存态，测毕全量还原（含 chain_paused/pending_close_surface）。

const TpmScript = preload("res://managers/tutorial_progression_manager.gd")
const TruckBaseScript = preload("res://scenes/bunker/truck_base.gd")

var _tpm: Node = null
var _orig_step: int = -1
var _orig_completed: Array = []
var _orig_chain_paused: bool = false
var _orig_pending_close: String = ""
var _ptr_events: Array = []
var _overlay_requests: int = 0


func before_test() -> void:
	_tpm = get_node_or_null("/root/TutorialProgressionManager")
	assert_bool(_tpm != null).is_true()
	_orig_step = int(_tpm.current_step)
	_orig_completed = (_tpm.completed_steps as Array).duplicate()
	_orig_chain_paused = bool(_tpm.chain_paused)
	_orig_pending_close = String(_tpm.pending_close_surface)
	_ptr_events = []
	_overlay_requests = 0
	if not _tpm.tutorial_pointer_requested.is_connected(_collect_ptr):
		_tpm.tutorial_pointer_requested.connect(_collect_ptr)
	if not _tpm.overlay_requested.is_connected(_collect_overlay):
		_tpm.overlay_requested.connect(_collect_overlay)


func after_test() -> void:
	if _tpm.tutorial_pointer_requested.is_connected(_collect_ptr):
		_tpm.tutorial_pointer_requested.disconnect(_collect_ptr)
	if _tpm.overlay_requested.is_connected(_collect_overlay):
		_tpm.overlay_requested.disconnect(_collect_overlay)
	_tpm.current_step = _orig_step
	_tpm.completed_steps = _orig_completed
	_tpm.chain_paused = _orig_chain_paused
	_tpm.pending_close_surface = _orig_pending_close


func _collect_ptr(show_ptr: bool) -> void:
	_ptr_events.append(show_ptr)


func _collect_overlay() -> void:
	_overlay_requests += 1


func _goto_waiting(step: int) -> void:
	_tpm.current_step = step
	_tpm.completed_steps = []
	_tpm.chain_paused = true
	_tpm.pending_close_surface = ""


func test_complete_into_pause_requests_pointer() -> void:
	# TRUCK_BASE 步完成 → 进 ENHANCEMENT 点播等待 → 请求亮标 + 挂起面=技能树
	_tpm.current_step = TpmScript.TutorialStep.TRUCK_BASE
	_tpm.completed_steps = []
	_tpm.chain_paused = false
	_tpm.pending_close_surface = ""
	_tpm.complete_current_step()
	assert_int(int(_tpm.current_step)).is_equal(int(TpmScript.TutorialStep.ENHANCEMENT))
	assert_bool(bool(_tpm.chain_paused)).is_true()
	assert_bool(_ptr_events.has(true)).is_true()
	assert_str(String(_tpm.get_pending_surface())).is_equal("growth")


func test_pending_surface_empty_when_not_waiting() -> void:
	# 连讲段（chain_paused=false）与教程结束（FREEDOM_MODE）都不等待
	_tpm.current_step = TpmScript.TutorialStep.ENHANCEMENT
	_tpm.chain_paused = false
	assert_str(String(_tpm.get_pending_surface())).is_empty()
	_tpm.chain_paused = true
	_tpm.current_step = TpmScript.TutorialStep.FREEDOM_MODE
	assert_str(String(_tpm.get_pending_surface())).is_empty()


func test_close_wait_suppresses_pointer() -> void:
	# v38.3 面板体验步（close-wait）自有 toast 提示，不走指路标
	_tpm.current_step = TpmScript.TutorialStep.CARD_COLLECTION
	_tpm.chain_paused = false
	_tpm.pending_close_surface = "backpack"
	assert_str(String(_tpm.get_pending_surface())).is_empty()


func test_notify_surface_opened_mismatch_dismisses_and_holds() -> void:
	# 等技能树时玩家先开了卡仓 → 收标（false）+ 链保持暂停 + 不放行 overlay
	_goto_waiting(TpmScript.TutorialStep.ENHANCEMENT)
	_tpm.notify_surface_opened("backpack")
	assert_bool(_ptr_events.has(false)).is_true()
	assert_bool(bool(_tpm.chain_paused)).is_true()
	assert_int(_overlay_requests).is_equal(0)
	assert_str(String(_tpm.get_pending_surface())).is_equal("growth")


func test_notify_surface_opened_match_unpauses_and_clears() -> void:
	# 命中本步 → 放行 overlay（chain_paused 清零、挂起面清空）
	_goto_waiting(TpmScript.TutorialStep.ENHANCEMENT)
	_tpm.notify_surface_opened("growth")
	assert_bool(bool(_tpm.chain_paused)).is_false()
	assert_int(_overlay_requests).is_equal(1)
	assert_str(String(_tpm.get_pending_surface())).is_empty()


func test_notify_surface_closed_respawns_pointer() -> void:
	# 点播等待中任意面板关闭 → 重亮指路标（打开时收的那枚补回来）
	_goto_waiting(TpmScript.TutorialStep.ENHANCEMENT)
	_tpm.notify_surface_closed("store")
	assert_bool(_ptr_events.has(true)).is_true()


func test_skip_and_reset_dismiss_pointer() -> void:
	_goto_waiting(TpmScript.TutorialStep.ENHANCEMENT)
	_tpm.skip_tutorial()
	assert_bool(_ptr_events.has(false)).is_true()
	assert_str(String(_tpm.get_pending_surface())).is_empty()
	# reset 同样必须收标（设置面板重置路径）
	_goto_waiting(TpmScript.TutorialStep.SHOP)
	_tpm.reset_tutorial()
	assert_bool(_ptr_events.has(false)).is_true()


func test_step_play_position_follows_play_order() -> void:
	# 播放序 ≠ 枚举序：TRUCK_BASE 在第 5 位（首战后插入），总步数 14
	_tpm.current_step = TpmScript.TutorialStep.TRUCK_BASE
	var pos: Dictionary = _tpm.get_step_play_position()
	assert_int(int(pos.get("index", 0))).is_equal(5)
	assert_int(int(pos.get("total", 0))).is_equal(14)
	_tpm.current_step = TpmScript.TutorialStep.INTRO_WELCOME
	assert_int(int(_tpm.get_step_play_position().get("index", 0))).is_equal(1)


func test_pointer_tip_prefers_step_field_then_title_fallback() -> void:
	# 带 pointer_tip 的等待步指到具体工位；不带者回退「下一步：」+ 标题
	_goto_waiting(TpmScript.TutorialStep.ENHANCEMENT)
	assert_str(String(_tpm.get_pointer_tip())).contains("通讯架")
	_goto_waiting(TpmScript.TutorialStep.TRUCK_BASE)
	assert_str(String(_tpm.get_pointer_tip())).starts_with("下一步：")
	assert_str(String(_tpm.get_pointer_tip())).contains("车厢指南")


func test_march_hotspots_carry_world_map_key() -> void:
	# WORLD_MAP 步的指路标目标=尾门跳板热区——五时代 march 条目必须带 key=world_map
	#（get_hotspot_button_for_key 按 panel_key meta 匹配；world_map 不在节奏表=恒开，
	# 门控灰显行为不变）。缺 key → 该步指路标静默不亮（防复活锁）。
	var hotspots: Dictionary = TruckBaseScript.HOTSPOTS
	assert_int(hotspots.size()).is_equal(5)
	for era_id in hotspots:
		var march_count := 0
		for h in hotspots[era_id] as Array:
			if String(h.get("kind", "")) != "march":
				continue
			march_count += 1
			assert_str(String(h.get("key", ""))).is_equal("world_map")
		assert_int(march_count).is_equal(1)


func test_every_waiting_step_has_pointer_tip_or_resolvable_surface() -> void:
	# 点播段 9 步全部有挂起面；除 phase_instrument（基地无工位，纯文字兜底）与
	# truck_base（进基地即放行）外都应配 pointer_tip 指到具体工位（防再回到盲找）
	var waiting_steps: Array = TpmScript.SURFACE_FOR_STEP.keys()
	assert_int(waiting_steps.size()).is_equal(9)
	for step in waiting_steps:
		var surface := String(TpmScript.SURFACE_FOR_STEP.get(step, ""))
		assert_str(surface).is_not_empty()
		if surface in ["growth", "modification", "backpack", "evolution", "faction", "store", "world_map"]:
			var tip := String(_tpm.tutorial_data.get(step, {}).get("pointer_tip", ""))
			assert_str(tip).is_not_empty()
