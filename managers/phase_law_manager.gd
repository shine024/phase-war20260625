extends Node
## 相位法则管理：研究 / 装备 / 战中状态
##
## 说明：
## - 目前只提供数据层与流程的骨架，不直接做具体战斗效果。
## - 其他系统可以通过本管理器查询本局环境、已装备的法则、以及是否可以施放某个主动法则。

const PhaseLaws = preload("res://data/phase_laws.gd")
const BattleEnvironments = preload("res://data/battle_environments.gd")
const BasicResources = preload("res://data/basic_resources.gd")
const _LevelInfoScript = preload("res://data/level_information.gd")

## 缓存的关卡信息实例（避免每次查询都 new）
var _level_info: RefCounted = null

## 知识值：决定可研究法则上限
var defense_knowledge: int = 0
var energy_knowledge: int = 0
var mobility_knowledge: int = 0
var mystic_knowledge: int = 0

## 已解锁法则 id 列表
var unlocked_law_ids: Array[String] = []

## 战前装配：被动 / 主动法则
var equipped_passive_laws: Array[String] = []
var equipped_active_laws: Array[String] = []

## 战前设置的本局可用纳米总量 & 战中实时纳米
var battle_nano_budget: int = 0
var current_battle_nano: int = 0

## 当前关卡ID（用于法则家族限制查询）
var current_level: int = 1

## 当前关卡环境（战前）与战中运行时环境（可能被法则修改）
var current_env: Dictionary = {}
var runtime_env: Dictionary = {}

## 主动法则战中状态：law_id -> { casts_used:int, casts_limit:int }
var active_law_states: Dictionary = {}

## 获取关卡信息实例（懒加载）
func _get_level_info() -> RefCounted:
	if _level_info == null:
		_level_info = _LevelInfoScript.new()
	return _level_info

func _agent_log(message: String, data: Dictionary, hypothesis_id: String = "") -> void:
	var DebugLog = get_node_or_null("/root/DebugLog")
	if DebugLog:
		DebugLog.agent_log("phase_law_manager.gd", message, data, hypothesis_id, "95dad8")

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if SignalBus:
		SignalBus.battle_started.connect(_on_battle_started)
		SignalBus.battle_ended.connect(_on_battle_ended)
	# 若当前环境未初始化，则从 GameManager 获取一次，避免法则面板里环境全为 ? 导致无法装配
	if current_env.is_empty():
		var level := 1
		if "current_level" in GameManager:
			level = int(GameManager.current_level)
		update_env_for_level(level)
	# 法则解锁仅由四维知识值驱动（v3 ADR-002）。

## ---- 战外：知识与研究 ----

const KNOWLEDGE_KEYS: Array[String] = [
	"defense_knowledge",
	"energy_knowledge",
	"mobility_knowledge",
	"mystic_knowledge",
]

func add_knowledge(kind: String, amount: int) -> void:
	var a: int = max(0, amount)
	match kind:
		"defense_knowledge":
			defense_knowledge += a
		"energy_knowledge":
			energy_knowledge += a
		"mobility_knowledge":
			mobility_knowledge += a
		"mystic_knowledge":
			mystic_knowledge += a

func get_knowledge(kind: String) -> int:
	match kind:
		"defense_knowledge":
			return defense_knowledge
		"energy_knowledge":
			return energy_knowledge
		"mobility_knowledge":
			return mobility_knowledge
		"mystic_knowledge":
			return mystic_knowledge
		_:
			return 0

func get_knowledge_snapshot() -> Dictionary:
	return {
		"defense_knowledge": defense_knowledge,
		"energy_knowledge": energy_knowledge,
		"mobility_knowledge": mobility_knowledge,
		"mystic_knowledge": mystic_knowledge,
	}

## 法则家族 → 知识类型（战斗掉落/补偿用）
static func knowledge_key_for_law_family(family: String) -> String:
	match String(family).to_upper():
		"STEEL":
			return "defense_knowledge"
		"FLAME":
			return "energy_knowledge"
		"THUNDER":
			return "mobility_knowledge"
		"VOID":
			return "mystic_knowledge"
		_:
			return "defense_knowledge"

static func knowledge_key_for_law_id(law_id: String) -> String:
	var law: Dictionary = PhaseLaws.get_by_id(law_id)
	if law.is_empty():
		return "defense_knowledge"
	return knowledge_key_for_law_family(String(law.get("family", "")))

func get_law_research_requirements(law_id: String) -> Dictionary:
	var law: Dictionary = PhaseLaws.get_by_id(law_id)
	return (law.get("research_req", {}) as Dictionary).duplicate(true)

func try_consume_knowledge(req: Dictionary) -> bool:
	if req.is_empty():
		return true
	for key in KNOWLEDGE_KEYS:
		if not req.has(key):
			continue
		if get_knowledge(key) < int(req[key]):
			return false
	for key in KNOWLEDGE_KEYS:
		if not req.has(key):
			continue
		match key:
			"defense_knowledge":
				defense_knowledge -= int(req[key])
			"energy_knowledge":
				energy_knowledge -= int(req[key])
			"mobility_knowledge":
				mobility_knowledge -= int(req[key])
			"mystic_knowledge":
				mystic_knowledge -= int(req[key])
	return true

func can_research_law(law_id: String) -> bool:
	var law := PhaseLaws.get_by_id(law_id)
	if law.is_empty():
		return false
	if unlocked_law_ids.has(law_id):
		return false
	var req: Dictionary = law.get("research_req", {})
	for key in KNOWLEDGE_KEYS:
		if req.has(key) and get_knowledge(key) < int(req[key]):
			return false
	return true

func ensure_law_unlocked(law_id: String) -> void:
	var lid: String = String(law_id)
	if lid.is_empty():
		return
	var law := PhaseLaws.get_by_id(lid)
	if law.is_empty():
		return
	if unlocked_law_ids.has(lid):
		return
	var req: Dictionary = law.get("research_req", {})
	if not req.is_empty() and not try_consume_knowledge(req):
		return
	unlocked_law_ids.append(lid)

func research_law(law_id: String) -> bool:
	var law := PhaseLaws.get_by_id(law_id)
	if law.is_empty():
		return false
	if unlocked_law_ids.has(law_id):
		return false
	if not can_research_law(law_id):
		return false
	var req: Dictionary = law.get("research_req", {})
	if not try_consume_knowledge(req):
		return false
	unlocked_law_ids.append(law_id)
	ManagerLazyLoader.ensure_loaded("quest")
	var qm = get_node_or_null("/root/QuestManager")
	if qm and qm.has_method("notify_law_researched"):
		qm.notify_law_researched(law_id)
	return true

## ---- 战前：环境与装配 ----

func update_env_for_level(level: int) -> void:
	current_level = level
	current_env = BattleEnvironments.get_for_level(level)
	runtime_env = current_env.duplicate(true)

func get_current_env() -> Dictionary:
	return current_env.duplicate(true)

## 检查法则家族是否在当前关卡被允许
func is_law_family_allowed(law_family: String) -> bool:
	var allowed_families: Array = _get_level_info().get_available_law_families_for_level(current_level)
	if allowed_families.is_empty():
		return true  # 空限制 = 全部可用
	return allowed_families.has(law_family)

## 获取当前关卡允许的法则家族列表
func get_allowed_families_for_current_level() -> Array:
	return _get_level_info().get_available_law_families_for_level(current_level)

func get_law_env_match(law_id: String, env: Dictionary = {}) -> bool:
	var law := PhaseLaws.get_by_id(law_id)
	if law.is_empty():
		return false
	var req: Dictionary = law.get("env_req", {})
	if req.is_empty():
		return true
	if env.is_empty():
		env = current_env
	if env.is_empty():
		return false
	# 简单匹配：若 law 要求的某个维度有配置，则该维度必须包含当前环境值
	if req.has("weather"):
		var ws: Array = req["weather"]
		if not ws.has(env.get("weather", "")):
			return false
	if req.has("terrain"):
		var ts: Array = req["terrain"]
		if not ts.has(env.get("terrain", "")):
			return false
	if req.has("energy_field"):
		var es: Array = req["energy_field"]
		if not es.has(env.get("energy_field", "")):
			return false
	if req.has("time_of_day"):
		var ts2: Array = req["time_of_day"]
		if not ts2.has(env.get("time_of_day", "")):
			return false
	return true

## 计算法则与当前环境的匹配维度数量（用于威力衰减计算）
func get_law_env_match_count(law_id: String, env: Dictionary = {}) -> int:
	var law := PhaseLaws.get_by_id(law_id)
	if law.is_empty():
		return 0
	var req: Dictionary = law.get("env_req", {})
	if req.is_empty():
		return 4  # 无环境要求 = 视为全匹配
	if env.is_empty():
		env = current_env
	if env.is_empty():
		return 0

	var match_count: int = 0
	var total_dims: int = 0

	if req.has("weather"):
		total_dims += 1
		var ws: Array = req["weather"]
		if ws.has(env.get("weather", "")):
			match_count += 1

	if req.has("terrain"):
		total_dims += 1
		var ts: Array = req["terrain"]
		if ts.has(env.get("terrain", "")):
			match_count += 1

	if req.has("energy_field"):
		total_dims += 1
		var es: Array = req["energy_field"]
		if es.has(env.get("energy_field", "")):
			match_count += 1

	if req.has("time_of_day"):
		total_dims += 1
		var ts2: Array = req["time_of_day"]
		if ts2.has(env.get("time_of_day", "")):
			match_count += 1

	if total_dims == 0:
		return 4  # 无要求 = 全匹配

	return match_count

## 获取法则的总环境要求维度数
func get_law_env_requirement_count(law_id: String) -> int:
	var law := PhaseLaws.get_by_id(law_id)
	if law.is_empty():
		return 0
	var req: Dictionary = law.get("env_req", {})
	var count: int = 0
	if req.has("weather"):
		count += 1
	if req.has("terrain"):
		count += 1
	if req.has("energy_field"):
		count += 1
	if req.has("time_of_day"):
		count += 1
	return count

## 计算主动法则的威力系数（基于环境匹配度）
## 匹配 0 项 = 50% 威力，匹配部分 = 50% + (匹配数/总维度数) * 50%，全匹配 = 100%
func get_active_law_power_multiplier(law_id: String, env: Dictionary = {}) -> float:
	var law := PhaseLaws.get_by_id(law_id)
	if law.is_empty():
		return 1.0
	if String(law.get("kind", "")) != "active":
		return 1.0  # 被动法则不受影响

	var match_count: int = get_law_env_match_count(law_id, env)
	var total_dims: int = get_law_env_requirement_count(law_id)

	if total_dims == 0:
		return 1.0  # 无环境要求 = 100%威力

	# 计算威力系数：最低50%，最高100%
	var power_ratio: float = float(match_count) / float(total_dims)
	return 0.5 + power_ratio * 0.5

## 获取环境匹配度描述文本（用于UI显示）
func get_env_match_description(law_id: String) -> Dictionary:
	var match_count: int = get_law_env_match_count(law_id, current_env)
	var total_dims: int = get_law_env_requirement_count(law_id)
	var power_mult: float = get_active_law_power_multiplier(law_id, current_env)

	var match_percent: int
	if total_dims == 0:
		match_percent = 100
	else:
		match_percent = int((float(match_count) / float(total_dims)) * 100)

	var power_percent: int = int(power_mult * 100)

	return {
		"match_count": match_count,
		"total_dims": total_dims,
		"match_percent": match_percent,
		"power_percent": power_percent,
		"power_multiplier": power_mult,
	}

func get_all_law_status_for_current_env() -> Array:
	var out: Array = []
	var allowed_families: Array = _get_level_info().get_available_law_families_for_level(current_level)
	for law_id in PhaseLaws.get_all_ids():
		var unlocked := unlocked_law_ids.has(law_id)
		var can_research := can_research_law(law_id)
		var env_ok := get_law_env_match(String(law_id), current_env)
		var family_ok := true
		var law := PhaseLaws.get_by_id(law_id)
		if not law.is_empty() and not allowed_families.is_empty():
			family_ok = allowed_families.has(law.get("family", ""))
		out.append({
			"id": law_id,
			"unlocked": unlocked,
			"can_research": can_research,
			"env_ok": env_ok,
			"family_ok": family_ok,
		})
	return out

func unlock_all_laws() -> void:
	unlocked_law_ids.clear()
	for law_id in PhaseLaws.get_all_ids():
		unlocked_law_ids.append(String(law_id))

func _sum_activate_nano_cost(passives: Array[String], actives: Array[String]) -> int:
	var total: int = 0
	for law_id in passives:
		var law_p: Dictionary = PhaseLaws.get_by_id(law_id)
		if law_p.is_empty():
			continue
		var cost_p: Dictionary = law_p.get("activate_cost", {})
		total += int(cost_p.get("nano", 0))
	for law_id_a in actives:
		var law_a: Dictionary = PhaseLaws.get_by_id(law_id_a)
		if law_a.is_empty():
			continue
		var cost_a: Dictionary = law_a.get("activate_cost", {})
		total += int(cost_a.get("nano", 0))
	return max(0, total)

func set_equipped_laws(passives: Array, actives: Array, nano_budget: int) -> bool:
	var new_passives: Array[String] = []
	var new_actives: Array[String] = []
	var allowed_families: Array = _get_level_info().get_available_law_families_for_level(current_level)
	for id in passives:
		var pid: String = String(id)
		if pid.is_empty() or new_passives.has(pid):
			continue
		var law_p: Dictionary = PhaseLaws.get_by_id(pid)
		if law_p.is_empty() or String(law_p.get("kind", "")) != "passive":
			_agent_log("set_equipped_laws_reject_invalid_passive", {"law_id": pid}, "H_equip_guard")
			return false
		if not unlocked_law_ids.has(pid) or not get_law_env_match(pid, current_env):
			_agent_log("set_equipped_laws_reject_passive_guard", {"law_id": pid}, "H_equip_guard")
			return false
		# 法则家族限制检查
		if not allowed_families.is_empty() and not allowed_families.has(law_p.get("family", "")):
			_agent_log("set_equipped_laws_reject_passive_family", {"law_id": pid, "family": law_p.get("family", ""), "allowed": allowed_families}, "H_equip_family")
			return false
		new_passives.append(pid)
	for id_a in actives:
		var aid: String = String(id_a)
		if aid.is_empty() or new_actives.has(aid):
			continue
		var law_a: Dictionary = PhaseLaws.get_by_id(aid)
		if law_a.is_empty() or String(law_a.get("kind", "")) != "active":
			_agent_log("set_equipped_laws_reject_invalid_active", {"law_id": aid}, "H_equip_guard")
			return false
		# 主动法则：只检查解锁状态，不检查环境匹配（任何关卡都能装备）
		if not unlocked_law_ids.has(aid):
			_agent_log("set_equipped_laws_reject_active_not_unlocked", {"law_id": aid}, "H_equip_guard")
			return false
		# 法则家族限制检查
		if not allowed_families.is_empty() and not allowed_families.has(law_a.get("family", "")):
			_agent_log("set_equipped_laws_reject_active_family", {"law_id": aid, "family": law_a.get("family", ""), "allowed": allowed_families}, "H_equip_family")
			return false
		new_actives.append(aid)

	var old_cost: int = _sum_activate_nano_cost(equipped_passive_laws, equipped_active_laws)
	var new_cost: int = _sum_activate_nano_cost(new_passives, new_actives)
	var delta_cost: int = new_cost - old_cost
	if delta_cost > 0:
		if not BlueprintManager.has_method("get_nano_materials") or not BlueprintManager.has_method("add_nano_materials"):
			_agent_log("set_equipped_laws_reject_no_bm", {"delta_cost": delta_cost}, "H_equip_cost")
			return false
		if int(BlueprintManager.get_nano_materials()) < delta_cost:
			_agent_log("set_equipped_laws_reject_nano_insufficient", {"need": delta_cost, "have": int(BlueprintManager.get_nano_materials())}, "H_equip_cost")
			return false
	if BlueprintManager.has_method("add_nano_materials") and delta_cost != 0:
		BlueprintManager.add_nano_materials(-delta_cost)

	equipped_passive_laws = new_passives
	equipped_active_laws = new_actives
	battle_nano_budget = max(0, nano_budget)
	_agent_log("set_equipped_laws", {
		"equipped_passives": equipped_passive_laws,
		"equipped_actives": equipped_active_laws,
		"nano_budget": battle_nano_budget,
		"activate_cost_total": new_cost,
		"activate_cost_delta": delta_cost,
	}, "H_equip")
	if SignalBus and SignalBus.has_signal("phase_law_runtime_changed"):
		SignalBus.phase_law_runtime_changed.emit()
	return true


## 与相位仪红/蓝槽的卡一致，不扣纳米、不校验环境与解锁（槽位即玩家已持有的实体卡）
func force_sync_instrument_law_slots(passives: Array, actives: Array) -> void:
	var np: Array[String] = []
	for id in passives:
		var pid: String = String(id)
		if pid.is_empty() or np.has(pid):
			continue
		var law_p: Dictionary = PhaseLaws.get_by_id(pid)
		if law_p.is_empty() or String(law_p.get("kind", "")) != "passive":
			continue
		np.append(pid)
	var na: Array[String] = []
	for id_a in actives:
		var aid: String = String(id_a)
		if aid.is_empty() or na.has(aid):
			continue
		var law_a: Dictionary = PhaseLaws.get_by_id(aid)
		if law_a.is_empty() or String(law_a.get("kind", "")) != "active":
			continue
		na.append(aid)
	equipped_passive_laws = np
	equipped_active_laws = na
	_agent_log("force_sync_instrument_law_slots", {"passives": np, "actives": na}, "H_sync")
	if SignalBus and SignalBus.has_signal("phase_law_runtime_changed"):
		SignalBus.phase_law_runtime_changed.emit()

## ---- 战中：开始 / 结束 ----

func _on_battle_started() -> void:
	# 战中施法消耗的纳米与 BasicResourceManager「纳米材料」统一；开战时同步快照（budget 字段可为 0）
	current_battle_nano = _read_nano_materials_total()
	runtime_env = current_env.duplicate(true)
	active_law_states.clear()
	for id in equipped_active_laws:
		var law := PhaseLaws.get_by_id(id)
		if law.is_empty():
			continue
		var cond: Dictionary = law.get("cast_conditions", {})
		var limit: int = int(cond.get("max_cast_per_battle", 999999))
		active_law_states[id] = {
			"casts_used": 0,
			"casts_limit": limit,
		}

func _on_battle_ended(_player_won: bool) -> void:
	# 战斗结束后，本局临时状态清理，长期状态（知识/已解锁等）保持。
	current_battle_nano = 0
	active_law_states.clear()
	runtime_env = current_env.duplicate(true)

## ---- 战中：施放检查与记录（不直接做数值效果） ----

func _read_nano_materials_total() -> int:
	if BasicResourceManager.has_method("get_total"):
		return int(BasicResourceManager.get_total(BasicResources.ID_NANO_MATERIALS))
	return current_battle_nano


func _resolve_equipped_active_key(law_id: String) -> String:
	var want: String = String(law_id).strip_edges()
	if want.is_empty():
		return ""
	if equipped_active_laws.has(want):
		return want
	for a in equipped_active_laws:
		var as_s: String = String(a).strip_edges()
		if as_s == want:
			return as_s
	return ""


func can_cast(law_id: String, current_energy: float, extra_ctx: Dictionary = {}) -> bool:
	var equipped_key: String = _resolve_equipped_active_key(law_id)
	if equipped_key.is_empty():
		return false
	var law := PhaseLaws.get_by_id(equipped_key)
	if law.is_empty():
		return false
	if active_law_states.has(equipped_key):
		var st: Dictionary = active_law_states[equipped_key]
		var used: int = int(st.get("casts_used", 0))
		var limit: int = int(st.get("casts_limit", 999999))
		if used >= limit:
			return false
	var cost: Dictionary = law.get("battle_cost", {})
	var need_energy: float = float(cost.get("energy", 0.0))
	var need_nano: int = int(cost.get("nano", 0))
	if current_energy < need_energy:
		return false
	if need_nano > 0 and _read_nano_materials_total() < need_nano:
		return false
	# 主动法则在任意环境/任意战场态势下均可施放：
	# 仅保留资源与次数约束，不再用友方单位数做硬门槛。
	# （环境匹配度影响威力系数，而非可施放性）
	return true

func record_cast(law_id: String) -> void:
	## 当外部系统确认已经真正施放了该法则后，应调用本函数进行资源扣除与环境更新。
	var equipped_key: String = _resolve_equipped_active_key(law_id)
	if equipped_key.is_empty():
		return
	var law := PhaseLaws.get_by_id(equipped_key)
	if law.is_empty():
		return
	var cost: Dictionary = law.get("battle_cost", {})
	var need_nano: int = int(cost.get("nano", 0))
	if need_nano > 0:
		if BasicResourceManager.has_method("add_basic_resource"):
			BasicResourceManager.add_basic_resource(BasicResources.ID_NANO_MATERIALS, -need_nano)
			current_battle_nano = max(0, _read_nano_materials_total())
		else:
			current_battle_nano = max(0, current_battle_nano - need_nano)
	if active_law_states.has(equipped_key):
		active_law_states[equipped_key]["casts_used"] = int(active_law_states[equipped_key].get("casts_used", 0)) + 1
	# 应用环境变化
	var envc: Dictionary = law.get("env_changes", {})
	if not envc.is_empty():
		var rt := runtime_env
		if envc.has("remove_tags"):
			for t in envc["remove_tags"]:
				# 这里简单约定：若 weather 等于某 tag，则清空；进一步的复杂逻辑可以后扩展
				if rt.get("weather", "") == t:
					rt["weather"] = "clear"
		if envc.has("add_tags"):
			for t2 in envc["add_tags"]:
				# 简单示例：electromagnetic_storm 直接写入 energy_field / weather
				if t2 == "electromagnetic_storm":
					rt["weather"] = "storm"
					rt["energy_field"] = "high_field"
				elif t2 == "time_slow_field":
					rt["time_of_day"] = rt.get("time_of_day", "day")
		runtime_env = rt
		if SignalBus and SignalBus.has_signal("phase_law_runtime_changed"):
			SignalBus.phase_law_runtime_changed.emit()

func get_runtime_env() -> Dictionary:
	return runtime_env.duplicate(true)

## ---- 提供给战斗单位的被动效果查询 ----
## 返回当前已装备、环境匹配的被动法则的 runtime_tags 列表，
## 会根据目标阵营过滤 target_side（ALLY/ENEMY/BOTH）
func get_passive_runtime_tags_for_side(is_player: bool) -> Array:
	var out: Array = []
	for law_id in equipped_passive_laws:
		var law := PhaseLaws.get_by_id(law_id)
		if law.is_empty():
			continue
		var env_ok_runtime := get_law_env_match(law_id, runtime_env)
		var rt: Dictionary = law.get("runtime_tags", {}).duplicate(true)
		if rt.is_empty():
			continue
		var law_lv: int = 1
		if BlueprintManager.has_method("get_law_blueprint_level"):
			law_lv = int(BlueprintManager.get_law_blueprint_level(law_id))
		if rt.has("value") and (typeof(rt["value"]) == TYPE_FLOAT or typeof(rt["value"]) == TYPE_INT):
			var mul: float = 1.0 + float(max(0, law_lv - 1)) * 0.02
			rt["value"] = float(rt["value"]) * mul
		var side: String = String(rt.get("target_side", "ALLY"))
		var side_ok := true
		if side == "ALLY" and not is_player:
			side_ok = false
		if side == "ENEMY" and is_player:
			side_ok = false
		_agent_log("passive_law_checked", {
			"law_id": law_id,
			"env_ok_runtime": env_ok_runtime,
			"side": side,
			"is_player": is_player,
			"side_ok": side_ok,
		}, "H_passive_env")
		if not env_ok_runtime or not side_ok:
			continue
		out.append(rt)
	return out

func reset_to_defaults() -> void:
	defense_knowledge = 0
	energy_knowledge = 0
	mobility_knowledge = 0
	mystic_knowledge = 0
	unlocked_law_ids.clear()
	equipped_passive_laws.clear()
	equipped_active_laws.clear()
	battle_nano_budget = 0
	current_battle_nano = 0
	active_law_states.clear()
	_grant_new_game_starter_knowledge()

func _grant_new_game_starter_knowledge() -> void:
	const GameConstants = preload("res://resources/game_constants.gd")
	## [deprecated] LawShard 机制已废弃，下面读取的 NEW_GAME_STARTER_LAW_SHARD_AMOUNT
	## 仅作为「新游戏初始知识值倍率」的兼容来源，未来应改为独立常量。
	var amount: int = GameConstants.NEW_GAME_STARTER_LAW_SHARD_AMOUNT  ## legacy — LawShard 已废弃，此处仅借用其数值作为知识值倍率
	for law_id in GameConstants.get_all_new_game_starter_law_ids():
		var law: Dictionary = PhaseLaws.get_by_id(law_id)
		if law.is_empty():
			continue
		add_knowledge(knowledge_key_for_law_id(law_id), amount * 3)

## ---- 存档 ----

func save_state() -> Dictionary:
	return {
		"knowledge": get_knowledge_snapshot(),
		"unlocked_law_ids": unlocked_law_ids.duplicate(),
		"equipped_passive_laws": equipped_passive_laws.duplicate(),
		"equipped_active_laws": equipped_active_laws.duplicate(),
		"battle_nano_budget": battle_nano_budget,
	}

func load_state(data: Dictionary) -> void:
	var k: Dictionary = data.get("knowledge", {})
	defense_knowledge = int(k.get("defense_knowledge", 0))
	energy_knowledge = int(k.get("energy_knowledge", 0))
	mobility_knowledge = int(k.get("mobility_knowledge", 0))
	mystic_knowledge = int(k.get("mystic_knowledge", 0))
	unlocked_law_ids = []
	for id in data.get("unlocked_law_ids", []):
		var sid: String = String(id).strip_edges()
		if not sid.is_empty() and not unlocked_law_ids.has(sid):
			unlocked_law_ids.append(sid)
	equipped_passive_laws = []
	for pid in data.get("equipped_passive_laws", []):
		var sp: String = String(pid).strip_edges()
		if not sp.is_empty():
			equipped_passive_laws.append(sp)
	equipped_active_laws = []
	for aid in data.get("equipped_active_laws", []):
		var sa: String = String(aid).strip_edges()
		if not sa.is_empty():
			equipped_active_laws.append(sa)
	battle_nano_budget = int(data.get("battle_nano_budget", 0))
