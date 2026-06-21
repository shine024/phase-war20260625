extends Node
## 新系统集成脚本：自动连接所有新系统信号

const _LawDefs = preload("res://data/phase_laws.gd")
const _ScreenShake = preload("res://scenes/effects/screen_shake.gd")
const _LawFx = preload("res://scenes/effects/phase_law_cast_effect.gd")

const _FAMILY_MAP := {
	"STEEL": "钢铁", "FLAME": "烈焰", "THUNDER": "雷霆", "VOID": "虚空"
}

func _ready() -> void:
	await get_tree().process_frame
	_connect_signals()

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

## 单位受伤 → 暴击屏幕震动（伤害数字已由 BattleManager._on_unit_damaged_combat_feedback
## 统一通过 CombatFeedback.show_damage 创建，含 80ms 节流；此处不再重复创建数字，
## 否则会双数字 + 无节流刷屏。仅保留暴击屏幕震动反馈。）
func _on_unit_damaged(unit: Node, _is_player: bool, damage: float, _position: Vector2) -> void:
	var bfm = get_node_or_null("/root/BattleFeedbackManager")
	# 暴击判定：由攻击弹道打的 _vfx_crit_pending meta 决定（与 CombatFeedback 口径一致）
	var is_crit: bool = unit != null and is_instance_valid(unit) and unit.has_meta("_vfx_crit_pending")
	if bfm and is_instance_valid(bfm) and is_crit:
		# 暴击屏幕震动（数字由 combat_feedback 负责，这里不重复创建）
		var bf = unit.get_parent()
		if bf:
			var camera = bf.get_node_or_null("Camera2D")
			if camera:
				bfm.shake_screen(camera, 5.0, 0.3)

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
		# 注意：update_task_progress 的参数是 TaskType 枚举，必须传枚举值而非字符串
		tm.update_task_progress(DailyTaskManager.TaskType.BATTLE_VICTORY, 1)

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
