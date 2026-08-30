class_name UltimateCastTest
extends GdUnitTestSuite

## v24.1 大招自动/手动双轨——控制器状态机 + 核子轰炸充能模型 + armed FIFO 释放单测。
## 纯静态逻辑，headless 可跑；无战场时 _get_targets 恒空，正好覆盖"无目标不消耗"分支。

const UltimateCastControllerScript = preload("res://scripts/battle/ultimate_cast_controller.gd")
const PhaseInstrumentAbilitiesScript = preload("res://managers/battle/phase_instrument_abilities.gd")


## 兵种机制 armed 协议测试替身（同 group + try_manual_fire_ 方法签名）
class MechDummy extends Node:
	var fire_result := true
	var fired_count := 0
	var _is_jamming_field_unit := true

	func try_manual_fire_nuclear_strike() -> bool:
		fired_count += 1
		return fire_result


## 只追踪自己创建的替身——after_test 严禁遍历 get_children()（会误删 GdUnit 自身子节点，
## 报 "Attempted to free a locked object" 且清理中断 → 跨测试组污染）
var _dummies: Array = []


func before_test() -> void:
	PhaseInstrumentAbilitiesScript.reset_battle_state()
	UltimateCastControllerScript.reset()


func after_test() -> void:
	for d in _dummies:
		if is_instance_valid(d):
			d.remove_from_group("player_units")
			remove_child(d)
			d.free()
	_dummies.clear()


func _spawn_dummy(armed_at: int = -1) -> MechDummy:
	var d := MechDummy.new()
	add_child(d)
	d.add_to_group("player_units")
	if armed_at >= 0:
		d.set_meta("mech_armed_nuclear_strike", armed_at)
	_dummies.append(d)
	return d


func _charge() -> int:
	return PhaseInstrumentAbilitiesScript.get_nuclear_bombardment_charge()


# ── 控制器模式状态 ──

func test_reset_restores_auto_mode() -> void:
	UltimateCastControllerScript.set_manual_mode(true)
	assert_bool(UltimateCastControllerScript.is_manual()).is_true()
	# set_manual_mode 需同步推入引擎侧旗标
	assert_bool(PhaseInstrumentAbilitiesScript.player_manual_hold).is_true()
	UltimateCastControllerScript.reset()
	assert_bool(UltimateCastControllerScript.is_manual()).is_false()
	assert_bool(PhaseInstrumentAbilitiesScript.player_manual_hold).is_false()


# ── 核子轰炸充能模型 ──

func test_manual_mode_holds_charges_with_cap_two() -> void:
	UltimateCastControllerScript.set_manual_mode(true)
	var params := {"interval": 10.0}
	var P := PhaseInstrumentAbilitiesScript.Owner.PLAYER
	# 开局种子间隔（首次跳过等待）+ 一帧 → 首个充能
	PhaseInstrumentAbilitiesScript._tick_nuclear_bombardment(P, params, 0.016)
	assert_int(_charge()).is_equal(1)
	# 再攒满一个 interval → 满仓 2
	PhaseInstrumentAbilitiesScript._tick_nuclear_bombardment(P, params, 10.0)
	assert_int(_charge()).is_equal(2)
	# 满仓停涨：溢出不转为第三发
	PhaseInstrumentAbilitiesScript._tick_nuclear_bombardment(P, params, 10.0)
	assert_int(_charge()).is_equal(2)


func test_auto_mode_consumes_charge_immediately() -> void:
	# 默认自动模式：攒到即放（充能立即被消耗；无战场时 fire 内部早退，不影响记账断言）
	var params := {"interval": 10.0}
	var P := PhaseInstrumentAbilitiesScript.Owner.PLAYER
	PhaseInstrumentAbilitiesScript._tick_nuclear_bombardment(P, params, 0.016)
	assert_int(_charge()).is_equal(0)


func test_manual_release_paths() -> void:
	UltimateCastControllerScript.set_manual_mode(true)
	# 无充能
	assert_str(PhaseInstrumentAbilitiesScript.manual_release_nuclear_bombardment()).is_equal("no_charge")
	# 攒 1 充能后无目标（headless 无战场）→ 不消耗
	var params := {"interval": 10.0}
	PhaseInstrumentAbilitiesScript._tick_nuclear_bombardment(PhaseInstrumentAbilitiesScript.Owner.PLAYER, params, 0.016)
	assert_int(_charge()).is_equal(1)
	assert_str(PhaseInstrumentAbilitiesScript.manual_release_nuclear_bombardment()).is_equal("no_target")
	assert_int(_charge()).is_equal(1)


func test_enemy_side_never_holds() -> void:
	# 手动模式只影响玩家侧；敌方 owner 恒自动释放（充能不滞留）
	UltimateCastControllerScript.set_manual_mode(true)
	var params := {"interval": 10.0}
	var E := PhaseInstrumentAbilitiesScript.Owner.ENEMY
	PhaseInstrumentAbilitiesScript._tick_nuclear_bombardment(E, params, 0.016)
	assert_int(int(PhaseInstrumentAbilitiesScript._ability_charges.get("enemy:nuclear_bombardment", 0))).is_equal(0)


func test_reset_state_clears_charges() -> void:
	UltimateCastControllerScript.set_manual_mode(true)
	PhaseInstrumentAbilitiesScript._tick_nuclear_bombardment(PhaseInstrumentAbilitiesScript.Owner.PLAYER, {"interval": 10.0}, 0.016)
	assert_int(_charge()).is_equal(1)
	PhaseInstrumentAbilitiesScript.reset_battle_state()
	assert_int(_charge()).is_equal(0)


# ── 兵种机制 armed 统计 / FIFO 释放 ──

func test_armed_fifo_release() -> void:
	var a := _spawn_dummy(1000)
	var b := _spawn_dummy(2000)
	var armed := UltimateCastControllerScript.get_armed_mechanisms()
	assert_int(armed["nuclear_strike"]["count"]).is_equal(2)
	assert_bool(armed["nuclear_strike"]["first_unit"] == a).is_true()
	# FIFO：最早 armed 的 a 被选中
	var res: String = UltimateCastControllerScript.release_mechanism("nuclear_strike")
	assert_str(res).is_equal("fired")
	assert_int(a.fired_count).is_equal(1)
	assert_int(b.fired_count).is_equal(0)


func test_release_no_target_keeps_charge() -> void:
	var d := _spawn_dummy(1000)
	d.fire_result = false
	var res: String = UltimateCastControllerScript.release_mechanism("nuclear_strike")
	assert_str(res).is_equal("no_target")
	assert_int(d.fired_count).is_equal(1)  # 方法被调用但返回 false（未消耗）


func test_release_none_armed() -> void:
	assert_str(UltimateCastControllerScript.release_mechanism("nuclear_strike")).is_equal("none_armed")


func test_has_fielded_mechanism() -> void:
	assert_bool(UltimateCastControllerScript.has_fielded_mechanism("jamming_field")).is_false()
	_spawn_dummy()  # 替身自带 _is_jamming_field_unit = true
	assert_bool(UltimateCastControllerScript.has_fielded_mechanism("jamming_field")).is_true()
	assert_bool(UltimateCastControllerScript.has_fielded_mechanism("shield_projector")).is_false()
