extends Node
## 新系统集成脚本：自动连接所有新系统信号

const _LawDefs = preload("res://data/phase_laws.gd")
const _DmgNum = preload("res://scenes/effects/damage_number_display.gd")
const _ScreenShake = preload("res://scenes/effects/screen_shake.gd")
const _LawFx = preload("res://scenes/effects/phase_law_cast_effect.gd")

const _FAMILY_MAP := {
	"STEEL": "钢铁", "FLAME": "烈焰", "THUNDER": "雷霆", "VOID": "虚空"
}

func _ready() -> void:
	await get_tree().process_frame
	_connect_signals()
	print("[NewSystemsIntegration] 新系统集成完成")

func _connect_signals() -> void:
	if not SignalBus:
		return
	if SignalBus.has_signal("unit_damaged") and not SignalBus.unit_damaged.is_connected(_on_unit_damaged):
		SignalBus.unit_damaged.connect(_on_unit_damaged)
	if SignalBus.has_signal("unit_died") and not SignalBus.unit_died.is_connected(_on_unit_died):
		SignalBus.unit_died.connect(_on_unit_died)
	if SignalBus.has_signal("phase_law_cast") and not SignalBus.phase_law_cast.is_connected(_on_phase_law_cast):
		SignalBus.phase_law_cast.connect(_on_phase_law_cast)
	if SignalBus.has_signal("battle_ended"):
		if not SignalBus.battle_ended.is_connected(_on_battle_ended_daily):
			SignalBus.battle_ended.connect(_on_battle_ended_daily)
		if not SignalBus.battle_ended.is_connected(_on_battle_ended_achievement):
			SignalBus.battle_ended.connect(_on_battle_ended_achievement)
	if SignalBus.has_signal("blueprint_unlocked") and not SignalBus.blueprint_unlocked.is_connected(_on_blueprint_unlocked):
		SignalBus.blueprint_unlocked.connect(_on_blueprint_unlocked)
	print("[NewSystemsIntegration] 信号已连接")

## 单位受伤 → 伤害数字 + 暴击屏幕震动（委托给 BattleFeedbackManager）
func _on_unit_damaged(unit: Node, _is_player: bool, damage: float, _position: Vector2) -> void:
	var bfm = get_node_or_null("/root/BattleFeedbackManager")
	if bfm and is_instance_valid(bfm):
		bfm.on_unit_damaged(unit, damage, false)
	else:
		# 兜底：如果 BattleFeedbackManager 不可用，直接调用效果脚本
		if not unit or not is_instance_valid(unit):
			return
		var bf = unit.get_parent()
		if bf:
			_DmgNum.create_damage_number(bf, unit.global_position, int(damage), false)

## 相位法则施放 → 特效（委托给 BattleFeedbackManager）
func _on_phase_law_cast(law_id: String, position: Vector2, _family: String) -> void:
	var bfm = get_node_or_null("/root/BattleFeedbackManager")
	var bf = _find_battlefield(get_tree().current_scene if get_tree() else null)
	if bfm and is_instance_valid(bfm) and bf:
		bfm.on_phase_law_cast(law_id, position, bf)
	else:
		# 兜底：如果 BattleFeedbackManager 不可用，直接调用效果脚本
		var law: Dictionary = _LawDefs.get_by_id(law_id)
		if law.is_empty():
			return
		var fam_raw := String(law.get("family", "")).to_upper()
		var fx_key: String = _FAMILY_MAP.get(fam_raw, fam_raw)
		if bf:
			match fx_key:
				"钢铁": _LawFx.create_steel_effect(bf, position)
				"烈焰": _LawFx.create_flame_effect(bf, position)
				"雷霆": _LawFx.create_thunder_effect(bf, position)
				"虚空": _LawFx.create_void_effect(bf, position)
				_:     _LawFx.create_phase_law_effect(bf, position, Color.CYAN)

## 战斗胜利 → 更新日常任务
func _on_battle_ended_daily(player_won: bool) -> void:
	if not player_won:
		return
	var tm = get_node_or_null("/root/DailyTaskManager")
	if tm and tm.has_method("update_task_progress"):
		tm.update_task_progress("BATTLE_VICTORY", 1)

## 战斗胜利 → 检查成就
func _on_battle_ended_achievement(player_won: bool) -> void:
	if not player_won:
		return
	var am = get_node_or_null("/root/AchievementManager")
	if am and am.has_method("check_achievement"):
		am.check_achievement("first_victory")

## 蓝图解锁 → 更新收集
func _on_blueprint_unlocked(card_id: String) -> void:
	var cm = get_node_or_null("/root/CardCollectionManager")
	if cm and cm.has_method("update_card_status"):
		cm.update_card_status(card_id)

## 单位死亡 → 委托给 BattleFeedbackManager
func _on_unit_died(unit: Node, _is_player: bool) -> void:
	var bfm = get_node_or_null("/root/BattleFeedbackManager")
	if bfm and is_instance_valid(bfm):
		bfm.on_unit_death(unit)

func _find_battlefield(node: Node) -> Node:
	if not node:
		return null
	if node.name == "Battlefield":
		return node
	for child in node.get_children():
		var result = _find_battlefield(child)
		if result:
			return result
	return null
