class_name UltimateCastController
extends RefCounted
## v24.1 大招自动/手动双轨释放控制器（纯状态，无 UI）
##
## 设计（docs 决策 2026-08-31）：
##   - 默认自动（挂机零损失），手动是 opt-in；仅当次战斗生效，battle 开始/结束 reset() 复位为自动。
##   - 纯时机收益，零数值改动：手动模式只是把"CD 好了立即放"改成"攥住等点击"，
##     吞吐上限与自动一致，唯一收益是 boss 波攒爆发。
##   - 手动白名单控点击负担：相位仪只收核子轰炸（30s），兵种机制只收
##     战术核武(45s)/护盾投射(20s)/电子屏蔽(18s)；CD 短的高频技保持永远自动。
##   - 相位仪侧充能模型在 PhaseInstrumentAbilities（核子轰炸改充能制，上限 2）；
##     本类只管模式开关 + 兵种机制的 armed 统计与 FIFO 释放。
##
## 兵种机制 armed 协议（construct_unit 侧写入）：
##   - 单位 CD 就绪且 is_manual() 时置 meta "mech_armed_<mech_id>" = 首次 armed 的
##     Time.get_ticks_msec()（每帧不覆盖，保 FIFO 顺序），并不再自动触发；
##   - 单位实现 try_manual_fire_<mech_id>() -> bool：成功=清除 armed + 重置 CD + 开火返回 true；
##     无有效目标=不消耗返回 false（充能保留）。
##   - 单位死亡节点释放，armed 计数自然回落，无外部清理需求。
##
## ⚠️ 依赖方向：本类单向 preload 相位仪能力引擎（推入手动旗标）；
## 引擎侧绝不反向引用本类——4.5.1 实测给引擎新增跨脚本 preload 后其个别静态函数的
## 编译期绑定会静默失效（reset_state 整体不执行），引擎依赖集保持原样。

## 手动白名单：相位仪能力 id（PhaseInstrumentAbilities 侧有对应充能/释放实现）
const MANUAL_ABILITY_IDS: Array[String] = ["nuclear_bombardment"]
## 手动白名单：兵种机制 id（construct_unit 侧有 armed meta + try_manual_fire_ 方法）
const MANUAL_MECHANISM_IDS: Array[String] = ["nuclear_strike", "shield_projector", "jamming_field"]

## 单向依赖：推入手动旗标给相位仪能力引擎
const PhaseInstrumentAbilitiesScript = preload("res://managers/battle/phase_instrument_abilities.gd")

## 当前是否手动模式（仅玩家侧消费；敌方恒自动）
static var manual_mode: bool = false


## 战斗开始/结束时调用：复位为自动（与 AutoDeployController 仅当次生效同惯例）
static func reset() -> void:
	manual_mode = false
	PhaseInstrumentAbilitiesScript.player_manual_hold = false


static func set_manual_mode(enabled: bool) -> void:
	manual_mode = enabled
	PhaseInstrumentAbilitiesScript.player_manual_hold = enabled


static func is_manual() -> bool:
	return manual_mode


## 扫描场上我方单位，统计各白名单机制的 armed 情况。
## 返回 {mech_id: {"count": int, "first_at": int, "first_unit": Node}}——只含有 armed 单位的机制。
## 供 ultimate_cast_bar 低频轮询（0.2s，n≤30，开销可忽略）。
static func get_armed_mechanisms() -> Dictionary:
	var result: Dictionary = {}
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return result
	for u in tree.get_nodes_in_group("player_units"):
		if u == null or not is_instance_valid(u):
			continue
		for mech_id in MANUAL_MECHANISM_IDS:
			var meta_name: String = "mech_armed_" + mech_id
			if not u.has_meta(meta_name):
				continue
			var at: int = int(u.get_meta(meta_name))
			var entry: Dictionary = result.get(mech_id, {"count": 0, "first_at": at, "first_unit": u})
			entry["count"] = int(entry["count"]) + 1
			if at < int(entry["first_at"]):
				entry["first_at"] = at
				entry["first_unit"] = u
			result[mech_id] = entry
	return result


## 手动释放一个兵种机制：选最早 armed 的单位（FIFO）调其 try_manual_fire_<id>。
## 返回 "fired" / "none_armed" / "no_target"（UI 据此 toast）。
static func release_mechanism(mech_id: String) -> String:
	var armed := get_armed_mechanisms()
	if not armed.has(mech_id):
		return "none_armed"
	var unit: Node = armed[mech_id].get("first_unit")
	if unit == null or not is_instance_valid(unit):
		return "none_armed"
	var method: String = "try_manual_fire_" + mech_id
	if unit.has_method(method) and bool(unit.call(method)):
		return "fired"
	return "no_target"


## 场上是否存在持有指定机制的活单位（供按钮"有单位但未就绪"的暗显档）。
## 通过脚本布尔旗标 duck-typing 判断（construct_unit 的 _is_<id>_unit）。
static func has_fielded_mechanism(mech_id: String) -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	var flag: String = "_is_" + mech_id + "_unit"
	for u in tree.get_nodes_in_group("player_units"):
		if u == null or not is_instance_valid(u):
			continue
		# 注意：u.get() 对无此属性的节点返回 null，bool(null) 在 4.5 是运行时错误，须先判型
		var flag_val: Variant = u.get(flag)
		if flag_val != null and bool(flag_val):
			return true
	return false
