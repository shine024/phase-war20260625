extends GdUnitTestSuite
## v6.37 回归锁：挂机"正在进发"显示链 + 部署受阻可见化 + PM 战僵持兜底。
## 三组不变式：
## ① TRAVELING 态有剩余秒数查询（面板倒计时数据源）且战斗开始时复位 RUNNING
##    （原状态机停在 TRAVELING 整场，面板显示陈旧"行进中"）。
## ② 部署持久态拒绝（power_cap 等）立即弃卡并 emit deploy_hint 人话提示——
##    此前 reason 走 /root/BattleSpawnSystem（不存在的 autoload 路径）恒空串，
##    第10关实机单卡连败 20 次×58s 死磕且玩家零感知。
## ③ PM 战 _process 内僵持计时必须累加（原累加写在 PM early return 之后=死代码，
##    敌方产兵枯竭+玩家够不着基地时战斗永久挂起，第10关实机挂 20 分钟根因）。

const AFKModeManagerScript = preload("res://scripts/systems/afk_mode_manager.gd")
const BattleManagerScript = preload("res://managers/battle/battle_manager.gd")


# ── 桩：AFK manager 的 _main 需在树内（绝对路径解析 autoload），并提供战场链 ──

class _StubMain extends Node:
	var bf: Node2D = null
	func _get_battlefield() -> Node2D:
		return bf


class _StubBattlefield extends Node2D:
	var grid: Node = null
	func ensure_battle_slot_grid_ready() -> Node:
		return grid
	func get_card_grid_player_slot_global(_si: int) -> Vector2:
		return Vector2.ZERO


class _StubGrid extends Node:
	func is_player_slot_occupied(_si: int, _pu: Node) -> bool:
		return false


## 换入真实 BattleManager._spawn_system 槽位的假 spawn 系统：恒拒绝并留存 reason
class _StubSpawnSystem extends RefCounted:
	var last_deploy_fail_reason: String = ""
	func request_player_deploy_silent(_id: String, _pos: Vector2, _era: int) -> bool:
		return false


class _StubPlatform extends RefCounted:
	var instance_id := ""
	var card_id := ""


func _make_manager(main: Node) -> AFKModeManager:
	var m: AFKModeManager = AFKModeManagerScript.new()
	m.init(main, null)
	return m


func _make_stub_world() -> _StubMain:
	var main := _StubMain.new()
	var bf := _StubBattlefield.new()
	bf.grid = _StubGrid.new()
	main.bf = bf
	# 挂成子树：main.free() 时随根逐级释放，不留孤儿节点（GdUnit 孤儿警告会挂 CI 退出码）
	bf.add_child(bf.grid)
	main.add_child(bf)
	get_tree().root.add_child(main)
	return main


# ── ① 行进态 ──

func test_travel_state_has_countdown_and_current_level() -> void:
	var main := _make_stub_world()
	var m := _make_manager(main)
	m.is_running = true
	m.mode = AFKModeManagerScript.Mode.PUSH
	m._pending_level = 7
	m._travel_then_enter()
	assert_int(m.state).is_equal(AFKModeManagerScript.State.TRAVELING)
	var remain := m.get_travel_remaining_seconds()
	assert_float(remain).is_greater(0.0)
	assert_float(remain).is_less_equal(AFKModeManagerScript.TRAVEL_SECONDS)
	assert_int(m.get_current_level()).is_equal(7)
	# 非行进态恒 0（RESTING 查询口互不串扰）
	m.stop_afk("manual")
	assert_float(m.get_travel_remaining_seconds()).is_equal(0.0)
	m.shutdown()
	main.free()


func test_battle_start_resets_traveling_to_running() -> void:
	var main := _make_stub_world()
	var m := _make_manager(main)
	m.is_running = true
	m._pending_level = 8
	m._travel_then_enter()
	assert_int(m.state).is_equal(AFKModeManagerScript.State.TRAVELING)
	var states: Array[int] = []
	m.state_changed.connect(func(s: int) -> void: states.append(s))
	m._on_battle_started_from_bus()
	assert_int(m.state).is_equal(AFKModeManagerScript.State.RUNNING)
	assert_int(states.size()).is_equal(1)
	assert_int(states[0]).is_equal(AFKModeManagerScript.State.RUNNING)
	m.stop_afk("manual")
	m.shutdown()
	main.free()


# ── ② 部署受阻可见化 ──

func test_persistent_reason_lists() -> void:
	var persistent: Array[String] = AFKModeManagerScript._PERSISTENT_DEPLOY_FAIL_REASONS
	assert_bool("power_cap" in persistent).is_true()
	assert_bool("deploy_uses_exhausted" in persistent).is_true()
	assert_bool("restricted_unit" in persistent).is_true()
	# 能量不足是暂时态（回能自愈），必须留在轮转重试通道
	assert_bool("insufficient_energy" in persistent).is_false()


func test_power_cap_reject_drops_card_and_emits_hint() -> void:
	var main := _make_stub_world()
	var m := _make_manager(main)
	m.is_running = true
	var bm := get_node_or_null("/root/BattleManager")
	assert_object(bm).is_not_null()
	var stub_spawn := _StubSpawnSystem.new()
	stub_spawn.last_deploy_fail_reason = "power_cap"
	var original_spawn: Variant = bm.get("_spawn_system")
	var original_active: bool = bm.battle_active
	bm.set("_spawn_system", stub_spawn)
	bm.battle_active = true
	var card := _StubPlatform.new()
	card.instance_id = "ww1_vickers#1"
	card.card_id = "ww1_vickers"
	m._auto_deploy_pending.append(card)
	var hints: Array[String] = []
	m.deploy_hint.connect(func(t: String) -> void: hints.append(t))
	m._deploy_next_from_queue()
	# 持久态：立即弃卡（不再 20 次轮转死磕）+ 人话提示
	assert_int(m._auto_deploy_pending.size()).is_equal(0)
	assert_int(hints.size()).is_equal(1)
	assert_str(hints[0]).contains("战力")
	bm.set("_spawn_system", original_spawn)
	bm.battle_active = original_active
	m.stop_afk("manual")
	m.shutdown()
	main.free()


func test_energy_fail_rotates_queue_without_drop() -> void:
	var main := _make_stub_world()
	var m := _make_manager(main)
	m.is_running = true
	var bm := get_node_or_null("/root/BattleManager")
	var stub_spawn := _StubSpawnSystem.new()
	stub_spawn.last_deploy_fail_reason = "insufficient_energy"
	var original_spawn: Variant = bm.get("_spawn_system")
	var original_active: bool = bm.battle_active
	bm.set("_spawn_system", stub_spawn)
	bm.battle_active = true
	var card_a := _StubPlatform.new()
	card_a.instance_id = "ww1_vickers#1"
	card_a.card_id = "ww1_vickers"
	var card_b := _StubPlatform.new()
	card_b.instance_id = "ww1_37mm#1"
	card_b.card_id = "ww1_37mm"
	m._auto_deploy_pending.append(card_a)
	m._auto_deploy_pending.append(card_b)
	var hints: Array[String] = []
	m.deploy_hint.connect(func(t: String) -> void: hints.append(t))
	m._deploy_next_from_queue()
	# 暂时态：轮转到队尾继续等回能，不弃卡不提示
	assert_int(m._auto_deploy_pending.size()).is_equal(2)
	if m._auto_deploy_pending.size() == 2:
		var rotated: _StubPlatform = m._auto_deploy_pending[1]
		assert_str(rotated.instance_id).is_equal("ww1_vickers#1")
	assert_int(hints.size()).is_equal(0)
	bm.set("_spawn_system", original_spawn)
	bm.battle_active = original_active
	m.stop_afk("manual")
	m.shutdown()
	main.free()


# ── ③ PM 战僵持兜底（battle_manager._process 死代码回归锁）──

func test_pm_stalemate_timer_accumulates_in_process() -> void:
	var bm := get_node_or_null("/root/BattleManager")
	assert_object(bm).is_not_null()
	var original_active: bool = bm.battle_active
	var original_bf: Variant = bm.get("battlefield")
	var original_pm: bool = bm._is_phase_master_battle
	var original_sec: float = bm._pm_stalemate_sec
	bm.battle_active = true
	var probe_bf := Node2D.new()
	bm.set("battlefield", probe_bf)
	bm._is_phase_master_battle = true
	bm._pm_stalemate_sec = 100.0
	bm._process(0.5)
	# 原 bug：累加写在 PM early return 之后，PM 战计时恒 0 → 僵持判负永不触发
	assert_float(bm._pm_stalemate_sec).is_equal(100.5)
	bm.battle_active = original_active
	bm.set("battlefield", original_bf)
	bm._is_phase_master_battle = original_pm
	bm._pm_stalemate_sec = original_sec
	probe_bf.free()


## ④ v6.38（记录5#12）：battle_ended 到达时若挂机已停（is_running=false，实机"战斗中
## 退回基地"链），在场标志必须先清再退——残留 true 会让下次启动首个 enter_next_battle
## 被守卫 SKIP，挂机看似在跑实则永不进场。
func test_battle_ended_clears_wait_flag_even_when_stopped() -> void:
	var main := _make_stub_world()
	var m := _make_manager(main)
	m.is_running = true
	m._waiting_for_battle_end = true
	m.stop_afk("manual")
	assert_bool(m.is_running).is_false()
	m._on_battle_ended_from_bus(false)
	assert_bool(m._waiting_for_battle_end).is_false()
	m.shutdown()
	main.free()
