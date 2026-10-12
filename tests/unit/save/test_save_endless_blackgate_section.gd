extends GdUnitTestSuite
## v6.65 记录6#3 回归锁：黑门/渗透存档段写侧收集 + 新档重置。
##
## 根因：v27 起 EndlessBlackgateManager 只登记了读侧（DEFERRED_MANAGER_LOADS），
## save_game 写侧从未收集——best_score/周星髓封顶/入场次数/gate_cleared_once/
## incursions/cp_* 分段进度全部"会话内正常、重启清零"（玩家感知"无法存档"）。
## 且 EBM 不在重置名单，同会话游玩后开新档会残留上一局黑门状态。

const SaveManagerScript = preload("res://managers/save_manager.gd")
const SaveConstantsRef = preload("res://scripts/systems/save_constants.gd")
const EBM = preload("res://managers/endless_blackgate_manager.gd")


## 读侧登记存在且与写侧键同源（SaveConstants 单一真理源）
func test_endless_blackgate_registered_for_load_with_shared_key() -> void:
	var found := false
	for entry in SaveManagerScript.DEFERRED_MANAGER_LOADS:
		if String(entry[0]) == "/root/EndlessBlackgateManager":
			found = true
			assert_str(String(entry[1])).is_equal(SaveConstantsRef.SK_ENDLESS_BLACKGATE)
			assert_str(String(entry[1])).is_equal("endless_blackgate")
	assert_bool(found).is_true()


## 写侧收集调用在册（防再次被删——v27 起的缺失正是无回归锁导致）
func test_save_game_collects_endless_blackgate_section() -> void:
	var src: Script = load("res://managers/save_manager.gd")
	assert_bool(src.source_code.contains(
		'_collect_manager_state(data, "/root/EndlessBlackgateManager"')).is_true()


## 新档重置名单在册（读档后开新档不得残留黑门进度）
func test_endless_blackgate_in_new_game_reset_list() -> void:
	assert_bool(SaveManagerScript.CRITICAL_RESETTABLE_MANAGERS.has("EndlessBlackgateManager")).is_true()


## save_state/load_state 往返一致 + reset_state 全清（_reset_manager_by_name
## 的 reset_state 兜底分支消费——其 load_state({}) 对空档早退保内存态，不可作重置口）
func test_ebm_save_roundtrip_and_reset_state() -> void:
	var ebm1 = auto_free(EBM.new())
	ebm1.set("best_score", 321)
	ebm1.set("best_waves", 44)
	ebm1.set("gate_cleared_once", true)
	ebm1.set("incursions", [{"host_level": 90, "seed": 7, "spawned_day": 2}])
	ebm1.set("cp_wave", 55)
	var data: Dictionary = ebm1.save_state()
	var ebm2 = auto_free(EBM.new())
	ebm2.load_state(data)
	assert_int(int(ebm2.get("best_score"))).is_equal(321)
	assert_int(int(ebm2.get("best_waves"))).is_equal(44)
	assert_bool(bool(ebm2.get("gate_cleared_once"))).is_true()
	assert_int((ebm2.get("incursions") as Array).size()).is_equal(1)
	assert_int(int(ebm2.get("cp_wave"))).is_equal(55)
	ebm2.reset_state()
	assert_int(int(ebm2.get("best_score"))).is_equal(0)
	assert_bool(bool(ebm2.get("gate_cleared_once"))).is_false()
	assert_int((ebm2.get("incursions") as Array).size()).is_equal(0)
	assert_int(int(ebm2.get("cp_wave"))).is_equal(0)


## 重置链兜底顺序：reset_state 必须排在 load_state 之前（EBM load_state({}) 早退）
func test_reset_manager_by_name_prefers_reset_state_for_ebm() -> void:
	var mll := get_node_or_null("/root/ManagerLazyLoader")
	if mll != null and mll.has_method("ensure_loaded"):
		mll.ensure_loaded("endless")
	var ebm := get_node_or_null("/root/EndlessBlackgateManager")
	assert_object(ebm).is_not_null()
	ebm.set("best_score", 999)
	ebm.set("gate_cleared_once", true)
	# 真实 SaveManager 的重置口直接打在真 EBM 上（真 autoload 环境）
	var sm := get_node_or_null("/root/SaveManager")
	assert_object(sm).is_not_null()
	sm.call("_reset_manager_by_name", "EndlessBlackgateManager")
	assert_int(int(ebm.get("best_score"))).is_equal(0)
	assert_bool(bool(ebm.get("gate_cleared_once"))).is_false()
