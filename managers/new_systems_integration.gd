extends Node
## 新系统集成脚本：自动连接所有新系统信号

const _LawDefs = preload("res://data/phase_laws.gd")
const _ScreenShake = preload("res://scenes/effects/screen_shake.gd")
const _LawFx = preload("res://scenes/effects/phase_law_cast_effect.gd")
const _DefaultCards = preload("res://data/default_cards.gd")

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
	# v7.x 修复 B5：连接强化完成信号（CardEnhancementManager 是 lazy-load，延迟连接）
	_connect_enhancement_signal()

## v7.x: 延迟连接 CardEnhancementManager.enhancement_completed（lazy-load 安全）
func _connect_enhancement_signal() -> void:
	var cem = get_node_or_null("/root/CardEnhancementManager")
	if cem == null:
		# lazy-load 未就绪，下一帧重试
		call_deferred("_connect_enhancement_signal_retry")
		return
	if cem.has_signal("enhancement_completed") and not cem.enhancement_completed.is_connected(_on_enhancement_completed):
		cem.enhancement_completed.connect(_on_enhancement_completed)

func _connect_enhancement_signal_retry() -> void:
	# 给 lazy-loader 多一点时间，仍失败则放弃（强化任务推进降级，不崩）
	await get_tree().create_timer(2.0).timeout
	_connect_enhancement_signal()

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

## 相位法则施放 → 特效（委托给 BattleFeedbackManager）+ 日常任务计数
## v7.x 修复 B5：施放相位法则时推进 USE_PHASE_LAWS 日常任务
func _on_phase_law_cast(law_id: String, position: Vector2, _family: String) -> void:
	# 日常任务：使用相位法则
	var tm = get_node_or_null("/root/DailyTaskManager")
	if tm and tm.has_method("update_task_progress"):
		tm.update_task_progress(DailyTaskManager.TaskType.USE_PHASE_LAWS, 1)
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
## v7.x 修复 B5：原只推进 BATTLE_VICTORY 一类，其余6类无入口 → 接取的日常任务永远完不成。
## 现在战斗结算同时推进 BATTLE_VICTORY/COMPLETE_LEVELS，并从结算数据补 EARN_XP/KILL_ENEMIES。
func _on_battle_ended_daily(player_won: bool) -> void:
	var tm = get_node_or_null("/root/DailyTaskManager")
	if tm == null or not tm.has_method("update_task_progress"):
		return
	if not player_won:
		return
	# BATTLE_VICTORY
	tm.update_task_progress(DailyTaskManager.TaskType.BATTLE_VICTORY, 1)
	# COMPLETE_LEVELS（胜利即视为完成一关）
	tm.update_task_progress(DailyTaskManager.TaskType.COMPLETE_LEVELS, 1)
	# EARN_XP：从结算摘要取值（无则跳过）。注意：KILL_ENEMIES 已在 _on_unit_died 实时计数，
	# 此处不重复推进击杀任务，避免双计数。
	var data = _collect_battle_data_for_achievement()
	var xp = int(data.get("xp", 0))
	if xp > 0:
		tm.update_task_progress(DailyTaskManager.TaskType.EARN_XP, xp)

## 战斗胜利 → 记录统计并检查成就
## v7.x 修复 B2/B3：原调用了不存在的 check_achievement（has_method 恒 false 静默跳过），
## 且 record_battle_victory 等统计方法全项目无调用者 → 战斗/收集/进度类成就永远不解锁。
## 改为调用 record_battle_victory（累计胜利数 + 自动触发 _check_all_battle_achievements）。
func _on_battle_ended_achievement(player_won: bool) -> void:
	var am = get_node_or_null("/root/AchievementManager")
	if am == null or not am.has_method("record_battle_victory"):
		return
	if player_won:
		am.record_battle_victory(_collect_battle_data_for_achievement())
	else:
		if am.has_method("record_battle_defeat"):
			am.record_battle_defeat()

## v7.x: 从战场收集战斗数据（供成就统计用）。无战场数据时返回空字典（仅累计基础胜利数）。
func _collect_battle_data_for_achievement() -> Dictionary:
	var data: Dictionary = {}
	var gm = get_node_or_null("/root/GameManager")
	if gm == null:
		return data
	# 尝试从 GameManager 的战斗结算摘要取数据（字段名防御性 .get）
	if gm.get("last_battle_reward_summary") != null:
		var summary = gm.get("last_battle_reward_summary")
		if summary is Dictionary:
			data["kills"] = int(summary.get("kills", 0))
			data["damage_dealt"] = int(summary.get("damage_dealt", 0))
			data["battle_time"] = float(summary.get("battle_time", 999))
			if bool(summary.get("no_damage", false)):
				data["no_damage"] = true
			var pm_raw = gm.get("_current_phase_master_id")
			var pm: String = String(pm_raw) if pm_raw != null else ""
			if not pm.is_empty():
				data["defeated_master"] = pm
	return data

## 蓝图解锁 → 更新收集 + 记录收集成就统计
## v7.x 修复 B3：原只更新图鉴，未调用 record_collection → 收集类成就（unique_blueprints/legendary_blueprint 等）永远不解锁
func _on_blueprint_unlocked(card_id: String) -> void:
	var cm = get_node_or_null("/root/CardCollectionManager")
	if cm and cm.has_method("update_card_status"):
		cm.update_card_status(card_id)
	# v7.x: 记录收集成就统计（需要 rarity 供 legendary/rare 计数）
	var am = get_node_or_null("/root/AchievementManager")
	if am and am.has_method("record_collection"):
		var card = _DefaultCards.get_card_by_id(card_id)
		var rarity: String = card.rarity if card != null else "common"
		am.record_collection(card_id, rarity)
	# v7.x 修复 B5：收集卡牌推进 COLLECT_CARDS 日常任务
	var tm = get_node_or_null("/root/DailyTaskManager")
	if tm and tm.has_method("update_task_progress"):
		tm.update_task_progress(DailyTaskManager.TaskType.COLLECT_CARDS, 1)

## v7.x 修复 B5：强化/改造完成 → 推进 UPGRADE_CARDS 日常任务
## enhancement_completed(success, card_id, action, message)
func _on_enhancement_completed(success: bool, _card_id: String, _action: String, _message: String) -> void:
	if not success:
		return
	var tm = get_node_or_null("/root/DailyTaskManager")
	if tm and tm.has_method("update_task_progress"):
		tm.update_task_progress(DailyTaskManager.TaskType.UPGRADE_CARDS, 1)

## 单位死亡 → 委托给 BattleFeedbackManager + 日常任务击杀计数
## v7.x 修复 B5：敌方单位死亡时推进 KILL_ENEMIES 日常任务（实时计数，不依赖结算摘要）
func _on_unit_died(unit: Node, is_player_unit: bool) -> void:
	var bfm = get_node_or_null("/root/BattleFeedbackManager")
	if bfm and is_instance_valid(bfm):
		bfm.on_unit_death(unit)
	# 仅敌方单位死亡计入击杀任务（is_player 为 true 表示死者是我方）
	if is_player_unit:
		return
	var tm = get_node_or_null("/root/DailyTaskManager")
	if tm and tm.has_method("update_task_progress"):
		tm.update_task_progress(DailyTaskManager.TaskType.KILL_ENEMIES, 1)

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
