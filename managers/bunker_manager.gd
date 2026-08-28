extends Node
## 余烬要塞全局状态管理器 v21 P1
## 设计文档：docs/design_ember_bunker.md
## 挂载方式：ManagerLazyLoader.ensure_loaded("bunker")（非 autoload），
## 实例化后常驻 /root/BunkerManager，跨场景存活——战斗结束时仍能推进修复进度。
##
## 职责：房间状态机 / 天数 / 精神值 / 修复经济；P2 接存档段，P3 接英雄碎片。

const BunkerRoomDefs = preload("res://data/bunker_room_defs.gd")

## 运行期状态
var _day: int = 1
var _sanity: float = 100.0
var _rooms: Dictionary = {}        # room_id -> {"state": int, "level": int, "progress": float(0-1)}
var _hero_fragments: Array = []    # 已解锁英雄 master id（P3：遗物碎片，击败相位师掉落）
var _narrative_stage: int = 1
var _announced_stage: int = 1      # 已播报过切换字幕的情感阶段
var _completed_today: Array = []    # 今日（自上次睡觉起）完成修复的房间 id
var _bootstrap_granted := false    # 首次进基地应急储备是否已发放（存档持久化）

## 荣誉陈列室解锁所需碎片数（P3 定 10：让中期玩家够得着；30 全收集是观星台条件）
const HONOR_HALL_FRAGMENT_GATE := 10

## ───────────────────────── 生命周期 ─────────────────────────

## 数据初始化放 _init（而非 _ready）：ManagerLazyLoader 在 root 未就绪时会
## call_deferred 挂载，实例先被 get_manager() 返回但尚未进树——_ready 未跑、
## _rooms 为空的窗口期任何查询/修复调用都会踩空。
func _init() -> void:
	_init_rooms_from_defs()

func _ready() -> void:
	# 战斗结束 → 扣精神值 + 推进修复进度（本节点常驻 root，跨场景存活）
	if SignalBus and not SignalBus.battle_ended.is_connected(_on_battle_ended):
		SignalBus.battle_ended.connect(_on_battle_ended)

func _init_rooms_from_defs() -> void:
	_rooms.clear()
	for def in BunkerRoomDefs.get_all_rooms():
		_rooms[def["id"]] = {
			"state": int(def.get("initial", BunkerRoomDefs.STATE_LOCKED)),
			"level": 1,
			"progress": 0.0,
		}
	# 存档恢复（P2 接 SaveManager 前的会话内兜底）：bunker_main 切场景时写 Engine meta
	if Engine.has_meta("bunker_runtime_state"):
		load_state_dict(Engine.get_meta("bunker_runtime_state"))
		Engine.remove_meta("bunker_runtime_state")

## 场景卸载前由 bunker_main 调用：把状态寄存到 Engine meta，跨 change_scene 存活
func stash_runtime_state() -> void:
	Engine.set_meta("bunker_runtime_state", get_state_dict())

## ───────────────────────── 查询 ─────────────────────────

func get_day() -> int:
	return _day

func get_sanity() -> float:
	return _sanity

func get_narrative_stage() -> int:
	return _narrative_stage

func get_room_state(room_id: String) -> int:
	return int(_rooms.get(room_id, {}).get("state", BunkerRoomDefs.STATE_LOCKED))

func get_room_progress(room_id: String) -> float:
	return float(_rooms.get(room_id, {}).get("progress", 0.0))

func get_room_level(room_id: String) -> int:
	return int(_rooms.get(room_id, {}).get("level", 1))

func is_reactor_online() -> bool:
	return get_room_state("reactor") == BunkerRoomDefs.STATE_ACTIVE

## 反应堆未上线时，深层设施（needs_power：通讯室/荣誉室）修复进度冻结；
## 上层房间靠基地备用电池供电，不受影响。反应堆自身当然不冻结。
func is_repair_frozen(room_id: String) -> bool:
	if room_id == "reactor" or is_reactor_online():
		return false
	var def := BunkerRoomDefs.get_room(room_id)
	return bool(def.get("needs_power", false))

## ───────────────────────── 修复经济 ─────────────────────────

## 首次进入基地发放一次性应急储备（P2）：新档 0 资源无法修复兵棋室（200 纳米），
## "进基地→无钱修→出不去"是死局。250 纳米够开工首间，80 合金留作小目标。
## bootstrap_granted 随存档持久化，新游戏重置后重发。
func maybe_grant_bootstrap() -> void:
	if _bootstrap_granted:
		return
	_bootstrap_granted = true
	if BasicResourceManager == null:
		return
	BasicResourceManager.add_resource(BunkerRoomDefs.res_full_id("nano"), 250)
	BasicResourceManager.add_resource(BunkerRoomDefs.res_full_id("alloy"), 80)

## 启动修复。返回 {"ok": bool, "reason": String}；成功即扣资源并入修复中状态。
func start_repair(room_id: String) -> Dictionary:
	var def := BunkerRoomDefs.get_room(room_id)
	if def.is_empty():
		return {"ok": false, "reason": "未知房间"}
	if def.get("is_terminal", false):
		return {"ok": false, "reason": "终局房间：需满足特定条件才能开启"}
	if get_room_state(room_id) != BunkerRoomDefs.STATE_LOCKED:
		return {"ok": false, "reason": "该房间不在可修复状态"}
	if not _rooms.has(room_id):
		return {"ok": false, "reason": "房间状态未初始化"}
	# P3：荣誉陈列室碎片门槛（10 位英雄遗物）
	if room_id == "honor_hall" and _hero_fragments.size() < HONOR_HALL_FRAGMENT_GATE:
		return {"ok": false, "reason": "需要 %d 份英雄遗物（当前 %d）——去击败驻守的相位师" % [
			HONOR_HALL_FRAGMENT_GATE, _hero_fragments.size()]}
	# 成本校验与扣除（BasicResourceManager 为 autoload）
	var cost: Dictionary = def.get("cost", {})
	if not cost.is_empty():
		if BasicResourceManager == null:
			return {"ok": false, "reason": "资源系统未就绪"}
		for short_id in cost:
			var full_id: String = BunkerRoomDefs.res_full_id(short_id)
			var amount: int = int(cost[short_id])
			if not BasicResourceManager.can_afford(full_id, amount):
				return {"ok": false, "reason": "资源不足（需 %s）" % BunkerRoomDefs.cost_text(cost)}
		for short_id in cost:
			BasicResourceManager.consume(
				BunkerRoomDefs.res_full_id(short_id), int(cost[short_id]))
	_rooms[room_id]["state"] = BunkerRoomDefs.STATE_REPAIRING
	_rooms[room_id]["progress"] = 0.0
	_emit_room_changed(room_id)
	return {"ok": true, "reason": "开始修复"}

## 战斗结束回调：每场推进所有"修复中"房间一格；胜利 -10 / 失败 -20 精神值。
## P3：胜利 + 相位师战斗 → 掉落英雄遗物碎片（ GameManager 在同一信号链上先跑且
## 延迟清除 _current_phase_master，此处读取安全）。
func _on_battle_ended(player_won: bool) -> void:
	advance_after_battle(player_won)
	if player_won and GameManager != null and GameManager.has_method("is_phase_master_battle") \
			and GameManager.is_phase_master_battle():
		var master: Dictionary = GameManager.get_current_phase_master()
		var master_id := str(master.get("id", ""))
		if not master_id.is_empty():
			record_hero_fragment(master_id)

func advance_after_battle(player_won: bool) -> Array:
	adjust_sanity(-10.0 if player_won else -20.0)
	var completed: Array = []
	for room_id in _rooms:
		if int(_rooms[room_id]["state"]) != BunkerRoomDefs.STATE_REPAIRING:
			continue
		if is_repair_frozen(room_id):
			continue  # 反应堆未上线：进度冻结
		var def := BunkerRoomDefs.get_room(room_id)
		var battles_needed: int = max(1, int(def.get("battles", 1)))
		_rooms[room_id]["progress"] = float(_rooms[room_id]["progress"]) + 1.0 / battles_needed
		if float(_rooms[room_id]["progress"]) >= 1.0:
			_rooms[room_id]["progress"] = 1.0
			_rooms[room_id]["state"] = BunkerRoomDefs.STATE_ACTIVE
			completed.append(room_id)
			_completed_today.append(room_id)
			_emit_room_changed(room_id)
	return completed

## ───────────────────────── 日循环 / 精神值 ─────────────────────────

## 睡觉：天数 +1，精神值 +20（上限 100），推进情感阶段，产出日结算数据。
## 返回 {"day", "sanity_before", "sanity_after", "completed_today", "stage"}。
func sleep() -> Dictionary:
	_day += 1
	var before: float = _sanity
	adjust_sanity(20.0)
	var new_stage: int = BunkerRoomDefs.narrative_stage_for_day(_day)
	if new_stage != _narrative_stage:
		_narrative_stage = new_stage
	var summary := {
		"day": _day,
		"sanity_before": before,
		"sanity_after": _sanity,
		"completed_today": _completed_today.duplicate(),
		"stage": _narrative_stage,
	}
	_completed_today.clear()
	if SignalBus and SignalBus.has_signal("bunker_day_ended"):
		SignalBus.bunker_day_ended.emit(_day)
	return summary

## 医疗室治疗：消耗纳米50，精神 +40。返回 {"ok", "reason"}。
func medical_treatment() -> Dictionary:
	if _sanity >= 99.5:
		return {"ok": false, "reason": "精神状态良好，无需治疗"}
	if BasicResourceManager == null:
		return {"ok": false, "reason": "资源系统未就绪"}
	var nano_id: String = BunkerRoomDefs.res_full_id("nano")
	if not BasicResourceManager.can_afford(nano_id, 50):
		return {"ok": false, "reason": "纳米材料不足（需 50）"}
	BasicResourceManager.consume(nano_id, 50)
	adjust_sanity(40.0)
	return {"ok": true, "reason": "精神 +40"}

func adjust_sanity(delta: float) -> void:
	_sanity = clampf(_sanity + delta, 0.0, 100.0)

## 精神值档位（UI 光点表现/掉落惩罚用）：0 正常 / 1 偏低(<50) / 2 低(<30)
func sanity_tier() -> int:
	if _sanity < 30.0:
		return 2
	elif _sanity < 50.0:
		return 1
	return 0

# ───────────────────── P3：英雄遗物碎片 ─────────────────────

## 记录一位牺牲英雄的遗物碎片（去重）。返回是否为新解锁。
func record_hero_fragment(master_id: String) -> bool:
	if _hero_fragments.has(master_id):
		return false
	_hero_fragments.append(master_id)
	if SignalBus and SignalBus.has_signal("hero_archive_unlocked"):
		SignalBus.hero_archive_unlocked.emit(master_id)
	return true

func get_hero_fragments() -> Array:
	return _hero_fragments.duplicate()

func get_hero_fragment_count() -> int:
	return _hero_fragments.size()

func has_hero_fragment(master_id: String) -> bool:
	return _hero_fragments.has(master_id)

# ───────────────────── P3：情感阶段切换 ─────────────────────

## 消费一次未播报的阶段跃迁：返回新阶段号（无跃迁返回 0）。
## bunker_main 在 _ready / 日结算关闭后调用，命中即播全屏字幕。
func consume_stage_transition() -> int:
	if _narrative_stage > _announced_stage:
		_announced_stage = _narrative_stage
		return _announced_stage
	return 0

# ───────────────────── P4 预留：观星台解锁条件 ─────────────────────

## 返回 {"ok": bool, "reasons": Array[String]}（P4 消费；缺项为未满足原因）
func is_observatory_unlockable() -> Dictionary:
	var reasons: Array[String] = []
	for room_id in _rooms:
		if room_id == "observatory":
			continue
		if int(_rooms[room_id]["state"]) != BunkerRoomDefs.STATE_ACTIVE:
			var def := BunkerRoomDefs.get_room(room_id)
			reasons.append("房间未修复：%s" % def.get("name", room_id))
	if _hero_fragments.size() < 30:
		reasons.append("英雄档案 %d/30" % _hero_fragments.size())
	if LevelProgressManager != null and LevelProgressManager.has_method("get_max_unlocked_level") \
			and LevelProgressManager.get_max_unlocked_level() < 100:
		reasons.append("尚未通关第 100 关")
	if reasons.is_empty():
		return {"ok": true, "reasons": []}
	return {"ok": false, "reasons": reasons}

## ───────────────────────── 调试（P1 专用，P2 移除） ─────────────────────────

func debug_grant_resources() -> void:
	if BasicResourceManager == null:
		return
	BasicResourceManager.add_resource(BunkerRoomDefs.res_full_id("nano"), 500)
	BasicResourceManager.add_resource(BunkerRoomDefs.res_full_id("alloy"), 300)
	BasicResourceManager.add_resource(BunkerRoomDefs.res_full_id("crystal"), 50)
	BasicResourceManager.add_resource(BunkerRoomDefs.res_full_id("energy"), 100)

## ───────────────────────── 存档序列化（SaveManager 段） ─────────────────────────

## SaveManager 收集入口（_collect_manager_state 按此方法名收集）
func save_state() -> Dictionary:
	return {
		"day": _day,
		"sanity": _sanity,
		"rooms": _rooms.duplicate(true),
		"hero_fragments": _hero_fragments.duplicate(),
		"narrative_stage": _narrative_stage,
		"announced_stage": _announced_stage,
		"bootstrap_granted": _bootstrap_granted,
	}

## SaveManager 应用入口（_safe_load_manager 按此方法名加载）；空字典=新游戏全重置
func load_state(data: Dictionary) -> void:
	if data.is_empty():
		reset_to_defaults()
		return
	_day = int(data.get("day", 1))
	_sanity = float(data.get("sanity", 100.0))
	_narrative_stage = int(data.get("narrative_stage", BunkerRoomDefs.narrative_stage_for_day(_day)))
	_announced_stage = int(data.get("announced_stage", _narrative_stage))
	_bootstrap_granted = bool(data.get("bootstrap_granted", false))
	_hero_fragments = []
	for f in data.get("hero_fragments", []):
		_hero_fragments.append(str(f))
	_completed_today = []
	var saved_rooms: Dictionary = data.get("rooms", {})
	for room_id in _rooms:
		if saved_rooms.has(room_id):
			var sr: Dictionary = saved_rooms[room_id]
			_rooms[room_id]["state"] = int(sr.get("state", _rooms[room_id]["state"]))
			_rooms[room_id]["level"] = int(sr.get("level", 1))
			_rooms[room_id]["progress"] = float(sr.get("progress", 0.0))
	# v22.1：定义初始点亮的房间不被旧档的 LOCKED 覆盖——旧档在兵棋室改为
	# initial ACTIVE 之前存盘的，会把 LOCKED 一并存进 rooms 段，读回后玩家
	# 依然无法从基地出击。这里按 defs 抬底：仅 LOCKED→ACTIVE（修复中/已点亮
	# 等更高状态原样保留）。
	for room_id in _rooms:
		var def: Dictionary = BunkerRoomDefs.get_room(room_id)
		if def.is_empty():
			continue
		if int(def.get("initial", BunkerRoomDefs.STATE_LOCKED)) == BunkerRoomDefs.STATE_ACTIVE \
				and int(_rooms[room_id]["state"]) == BunkerRoomDefs.STATE_LOCKED:
			_rooms[room_id]["state"] = BunkerRoomDefs.STATE_ACTIVE

## 新游戏重置（_reset_manager_by_name 链第二优先命中）
func reset_to_defaults() -> void:
	_day = 1
	_sanity = 100.0
	_hero_fragments = []
	_completed_today = []
	_narrative_stage = 1
	_announced_stage = 1
	_bootstrap_granted = false
	for room_id in _rooms:
		var def := BunkerRoomDefs.get_room(room_id)
		_rooms[room_id]["state"] = int(def.get("initial", BunkerRoomDefs.STATE_LOCKED))
		_rooms[room_id]["level"] = 1
		_rooms[room_id]["progress"] = 0.0

## 兼容旧调用名（会话内快照/冒烟测试）
func get_state_dict() -> Dictionary:
	return save_state()

func load_state_dict(data: Dictionary) -> void:
	load_state(data)

func _emit_room_changed(room_id: String) -> void:
	if SignalBus and SignalBus.has_signal("bunker_room_state_changed"):
		SignalBus.bunker_room_state_changed.emit(room_id, get_room_state(room_id))
