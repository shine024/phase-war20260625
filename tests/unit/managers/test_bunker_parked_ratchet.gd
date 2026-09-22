class_name BunkerParkedRatchetTest
extends GdUnitTestSuite
## v38.x 胜绩随行棘轮回归锁：胜利且 fought > 停靠关时 parked 跟进（只升不降）。
## 修复场景：结算「出击下一关」直通链只推 current_level 不移卡车 → 回基地出击
## 退回旧停靠关（用户实机"推到第9关回基地打第1关"）。

const MANAGER_ID := "bunker"

var _bm: Node = null
var _saved: Dictionary = {}
var _orig_current_level: int = 0


func before_test() -> void:
	_bm = get_tree().root.get_node_or_null("BunkerManager")
	if _bm == null:
		var mll := get_tree().root.get_node_or_null("ManagerLazyLoader")
		assert_that(mll).is_not_null()
		_bm = mll.call("get_manager", MANAGER_ID)
	assert_that(_bm).is_not_null()
	_saved = {
		"parked": _bm._parked_level,
		"pending_level": _bm._pending_battle_level,
		"pending_endless": _bm._pending_battle_endless,
		"travel_dest": _bm._travel_dest,
		"travel_total": _bm._travel_days_total,
		"travel_started": _bm._travel_started_unix,
		"travel_ends": _bm._travel_ends_unix,
		"sanity": _bm._sanity,
		"win_streak": _bm._win_streak,
		"log_n": _bm._battle_log.size(),
	}
	if GameManager != null:
		_orig_current_level = int(GameManager.current_level)


func after_test() -> void:
	if _bm == null:
		return
	_bm._parked_level = int(_saved["parked"])
	_bm._pending_battle_level = int(_saved["pending_level"])
	_bm._pending_battle_endless = bool(_saved["pending_endless"])
	_bm._travel_dest = int(_saved["travel_dest"])
	_bm._travel_days_total = int(_saved["travel_total"])
	_bm._travel_started_unix = float(_saved["travel_started"])
	_bm._travel_ends_unix = float(_saved["travel_ends"])
	_bm._sanity = float(_saved["sanity"])
	_bm._win_streak = int(_saved["win_streak"])
	# 战斗日志尾部清理（_on_battle_ended 最多 append 1 条）
	var log_n := int(_saved.get("log_n", _bm._battle_log.size()))
	while _bm._battle_log.size() > log_n:
		_bm._battle_log.pop_back()
	# deferred _sync_current_level_to_park 会写 GameManager.current_level——恢复
	await get_tree().process_frame
	if GameManager != null:
		GameManager.set_current_level(_orig_current_level)


func test_win_forward_ratchets_parked() -> void:
	_bm._parked_level = 1
	_bm._pending_battle_level = 9
	_bm._pending_battle_endless = false
	_bm._on_battle_ended(true)
	assert_int(_bm.get_parked_level()).is_equal(9)


func test_loss_does_not_move_parked() -> void:
	_bm._parked_level = 5
	_bm._pending_battle_level = 9
	_bm._pending_battle_endless = false
	_bm._on_battle_ended(false)
	assert_int(_bm.get_parked_level()).is_equal(5)


func test_replay_lower_level_does_not_move_parked() -> void:
	_bm._parked_level = 9
	_bm._pending_battle_level = 3
	_bm._pending_battle_endless = false
	_bm._on_battle_ended(true)
	assert_int(_bm.get_parked_level()).is_equal(9)


func test_endless_run_does_not_ratchet() -> void:
	# 黑门把 current_level 对齐 100，fought 抓到 100——无尽 run 不得把 parked 顶满
	_bm._parked_level = 4
	_bm._pending_battle_level = 100
	_bm._pending_battle_endless = true
	_bm._on_battle_ended(true)
	assert_int(_bm.get_parked_level()).is_equal(4)


func test_traveling_does_not_ratchet() -> void:
	# 行军中到站以物理位置覆写（_check_travel_arrival），棘轮不介入
	_bm._parked_level = 2
	_bm._travel_dest = 3
	_bm._travel_days_total = 2
	_bm._travel_started_unix = Time.get_unix_time_from_system()
	_bm._travel_ends_unix = _bm._travel_started_unix + 9999.0
	_bm._pending_battle_level = 9
	_bm._pending_battle_endless = false
	_bm._on_battle_ended(true)
	assert_int(_bm.get_parked_level()).is_equal(2)


func test_sync_pulls_current_level_to_new_park() -> void:
	# 棘轮推进后 deferred 同步把 current_level 拉到新停靠关（v26.19 语义保持）
	var orig := int(GameManager.current_level)
	_bm._parked_level = 1
	_bm._pending_battle_level = 7
	_bm._pending_battle_endless = false
	_bm._on_battle_ended(true)
	await get_tree().process_frame
	assert_int(int(GameManager.current_level)).is_equal(7)
	GameManager.set_current_level(orig)
