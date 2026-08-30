extends RefCounted
class_name PairSynergyEngine
## v21 P2: 搭档协同执行引擎（P2-2）
##
## 生命周期：由 combo_engine 托管（setup 时创建，update 由 combo_engine 每帧转发，
## reset 时清理）；刷新触发走"事件驱动 + 节流兜底"——battle_manager 的
## unit_spawned/unit_died 回调调 combo_engine.on_units_changed()（立即 refresh），
## combo_engine 1s 全队机制刷新时顺带 refresh（防事件漏网）。无每帧扫描。
##
## 机制分型（见 combo_tactics.PAIR_SYNERGIES.kind）：
##   mark       — 侦察标记：命中侧写目标 meta（unit_status_collector 范式），消费点读取，无需记账
##   onetime    — 一次性战地增益：首次共存时改写存活单位 stats（战斗内持续不撤销，注释声明）
##   numeric    — 数值增益：对称 apply/revoke（H11 记账范式，meta _pair_buff_applied 存原值）
##   aura_range — 声明型：消费点（card_ability_manager）直接查询 is_pair_active，引擎只管激活态
##
## 静态查询：消费点经 query_pair_active(pair_id)（Engine.get_main_loop 找 BattleManager，
## --script 模式无 BattleManager 安全返回 false）。

const ComboTacticsRef = preload("res://data/combo_tactics.gd")
const UnitRolesRef = preload("res://data/unit_roles.gd")

## 记账 meta 键（挂 stats 上，值: {pair_id: {field: 原值, ...}, "_ws": {槽位idx: 原攻速}}）
const META_PAIR_BUFF := "_pair_buff_applied"
## onetime 守卫 meta（挂 stats 上，防重复叠加）
const META_PAIR_ONETIME := "_pair_onetime_applied"

var _battlefield: Node = null
var _active_pairs: Array = []          # 当前激活的 pair_id 列表


func setup(battlefield: Node) -> void:
	_battlefield = battlefield
	_active_pairs.clear()


func reset() -> void:
	# 对称撤销所有 numeric 增益（单位多半已释放，仅清理仍有效的）
	var previously: Array = _active_pairs.duplicate()
	_active_pairs.clear()
	for pid in previously:
		_revoke_numeric_pair(String(pid))


func get_active_pairs() -> Array:
	return _active_pairs.duplicate()


func is_pair_active(pair_id: String) -> bool:
	return _active_pairs.has(pair_id)


## 每帧转发（预留：当前无逐帧机制，保留接口与 combo_engine.update 对齐）
func update(_delta: float) -> void:
	pass


## 刷新激活态（事件驱动 / 1s 兜底调用）
func refresh(battlefield: Node) -> void:
	if battlefield != null and is_instance_valid(battlefield):
		_battlefield = battlefield
	var role_counts: Dictionary = _count_roles()
	var newly_active: Array = []
	var newly_inactive: Array = []
	for pid in ComboTacticsRef.PAIR_SYNERGIES.keys():
		var def: Dictionary = ComboTacticsRef.PAIR_SYNERGIES[pid]
		var roles: Array = def.get("pair", [-1, -1])
		var should: bool = int(role_counts.get(int(roles[0]), 0)) > 0 and int(role_counts.get(int(roles[1]), 0)) > 0
		var was: bool = _active_pairs.has(String(pid))
		if should and not was:
			_active_pairs.append(String(pid))
			newly_active.append(String(pid))
		elif not should and was:
			_active_pairs.erase(String(pid))
			newly_inactive.append(String(pid))
	# 激活：numeric 立即 apply；onetime 补发给缺守卫的单位（后到场步兵也吃增益，战斗内持续）
	for pid in newly_active:
		var def2: Dictionary = ComboTacticsRef.PAIR_SYNERGIES[pid]
		match String(def2.get("kind", "")):
			"numeric":
				_apply_numeric_pair(pid, def2)
			"onetime":
				_apply_onetime_pair(pid, def2)
	# 失活：numeric 对称 revoke
	for pid2 in newly_inactive:
		_revoke_numeric_pair(pid2)
	# onetime 已激活时补发（后到的步兵单位）
	if _active_pairs.has("pair_engineer_infantry"):
		_apply_onetime_pair("pair_engineer_infantry", ComboTacticsRef.PAIR_SYNERGIES["pair_engineer_infantry"])


## ─── 角色扫描 ───

## 统计场上我方单位的角色分布 {role: count}
func _count_roles() -> Dictionary:
	var counts: Dictionary = {}
	for u in _get_player_units():
		if u == null or not is_instance_valid(u):
			continue
		var st: Variant = u.get("stats") if "stats" in u else null
		if st == null:
			continue
		var role: int = UnitRolesRef.resolve_role_cached(st)
		counts[role] = int(counts.get(role, 0)) + 1
	return counts


func _get_player_units() -> Array:
	# 经 combo_engine 同款路径：BattleManager 缓存组（无 BattleManager 时退回树遍历）。
	# v21 P2: 加 is_inside_tree 守卫——--script 模式下 autoload 节点存在但不在树内，
	# get_cached_nodes_in_group 内部 get_tree() 会断言；战斗外/异常时走组扫描兜底。
	var ml := Engine.get_main_loop()
	if ml == null or not (ml is SceneTree):
		return []
	var root: Node = (ml as SceneTree).root
	if root == null:
		return []
	var bm: Node = root.get_node_or_null("BattleManager")
	if bm != null and is_instance_valid(bm) and bm.is_inside_tree() and bm.has_method("get_cached_nodes_in_group"):
		return bm.get_cached_nodes_in_group("player_units")
	return (ml as SceneTree).get_nodes_in_group("player_units")


## ─── numeric 对称记账（H11 范式）───

func _apply_numeric_pair(pair_id: String, def: Dictionary) -> void:
	var eff: Dictionary = def.get("effect", {})
	# 防空×空中：target_role 的对空攻速 ×speed_mult（三维 attack_air_speed + AERIAL 武器槽）
	if eff.has("target_role") and eff.has("speed_mult"):
		var target_role: int = int(eff["target_role"])
		var mult: float = float(eff["speed_mult"])
		for u in _get_player_units():
			var st: Variant = u.get("stats") if "stats" in u else null
			if st == null or not (st is Resource):
				continue
			if UnitRolesRef.resolve_role_cached(st) != target_role:
				continue
			var stats := st as Resource
			var record: Dictionary = _get_record(stats, pair_id)
			if record.is_empty():
				# 首次 apply：记录原值再改写
				record["attack_air_speed"] = float(stats.get("attack_air_speed"))
				stats.set("attack_air_speed", float(stats.get("attack_air_speed")) * mult)
				# AERIAL(2) 型武器槽攻速同步（多武器 timing 缓存按 attack_speed 变化自动失效）
				var ws_record: Dictionary = {}
				var slots: Array = stats.get("weapon_slots") if "weapon_slots" in stats else []
				for i in range(slots.size()):
					var w = slots[i]
					if w != null and int(w.get("weapon_type")) == 2:   # WeaponType.AERIAL
						ws_record[i] = float(w.get("attack_speed"))
						w.set("attack_speed", float(w.get("attack_speed")) * mult)
				if not ws_record.is_empty():
					record["_ws"] = ws_record
				_set_record(stats, pair_id, record)
	# 装甲×轻装的部署延迟走消费点读取（calculate_deploy_delay 静态查询），无需记账
	# （部署延迟只在未来部署时结算，激活态查询即天然对称——激活生效/失活消失）


func _revoke_numeric_pair(pair_id: String) -> void:
	for u in _get_player_units():
		var st: Variant = u.get("stats") if "stats" in u else null
		if st == null or not (st is Resource):
			continue
		var stats := st as Resource
		if not stats.has_meta(META_PAIR_BUFF):
			continue
		var all_rec: Dictionary = stats.get_meta(META_PAIR_BUFF, {}) as Dictionary
		var record: Dictionary = all_rec.get(pair_id, {})
		if record.is_empty():
			continue
		# 恢复原值（幂等：attack_air_speed 回写原值）
		if record.has("attack_air_speed"):
			stats.set("attack_air_speed", float(record["attack_air_speed"]))
		var ws_record: Dictionary = record.get("_ws", {}) as Dictionary
		if not ws_record.is_empty():
			var slots: Array = stats.get("weapon_slots") if "weapon_slots" in stats else []
			for idx_s in ws_record.keys():
				var idx: int = int(idx_s)
				if idx >= 0 and idx < slots.size() and slots[idx] != null:
					slots[idx].set("attack_speed", float(ws_record[idx_s]))
		all_rec.erase(pair_id)
		if all_rec.is_empty():
			stats.remove_meta(META_PAIR_BUFF)
		else:
			stats.set_meta(META_PAIR_BUFF, all_rec)


func _get_record(stats: Resource, pair_id: String) -> Dictionary:
	if not stats.has_meta(META_PAIR_BUFF):
		return {}
	return ((stats.get_meta(META_PAIR_BUFF, {}) as Dictionary).get(pair_id, {})) as Dictionary


func _set_record(stats: Resource, pair_id: String, record: Dictionary) -> void:
	var all_rec: Dictionary = stats.get_meta(META_PAIR_BUFF, {}) as Dictionary if stats.has_meta(META_PAIR_BUFF) else {}
	all_rec[pair_id] = record
	stats.set_meta(META_PAIR_BUFF, all_rec)


## ─── onetime 一次性战地增益 ───

func _apply_onetime_pair(pair_id: String, def: Dictionary) -> void:
	var eff: Dictionary = def.get("effect", {})
	var target_role: int = int(eff.get("target_role", -1))
	var field: String = String(eff.get("stat_field", ""))
	var bonus: float = float(eff.get("bonus", 0.0))
	if target_role < 0 or field.is_empty() or bonus <= 0.0:
		return
	for u in _get_player_units():
		var st: Variant = u.get("stats") if "stats" in u else null
		if st == null or not (st is Resource):
			continue
		var stats := st as Resource
		# 单位已死跳过（亡者不吃增益）
		if "hp" in u and is_instance_valid(u) and float(u.get("hp")) <= 0.0:
			continue
		if UnitRolesRef.resolve_role_cached(stats) != target_role:
			continue
		# 每单位一次性守卫（后到场单位在下一次 refresh 补发，战斗内持续不撤销）
		var applied: Dictionary = stats.get_meta(META_PAIR_ONETIME, {}) as Dictionary if stats.has_meta(META_PAIR_ONETIME) else {}
		if applied.has(pair_id):
			continue
		applied[pair_id] = true
		stats.set_meta(META_PAIR_ONETIME, applied)
		stats.set(field, float(stats.get(field)) * (1.0 + bonus))


## ─── 静态查询（消费点用）───

## 查询搭档激活态（--script 模式 / 战斗外安全返回 false）
static func query_pair_active(pair_id: String) -> bool:
	var ml := Engine.get_main_loop()
	if ml == null or not (ml is SceneTree):
		return false
	var root: Node = (ml as SceneTree).root
	if root == null:
		return false
	var bm: Node = root.get_node_or_null("BattleManager")
	if bm == null or not bm.has_method("get_combo_engine"):
		return false
	var eng: RefCounted = bm.get_combo_engine()
	if eng == null or not eng.has_method("is_pair_active"):
		return false
	return bool(eng.is_pair_active(pair_id))


## 装甲×轻装部署延迟加成（construct_unit_deploy.calculate_deploy_delay 消费）。
## 单位角色属于 [ARMOR, INFANTRY] 且搭档激活 → 返回 −0.15（更快），否则 0。
static func get_pair_deploy_delay_bonus(stats: Variant) -> float:
	if stats == null or not (stats is Resource):
		return 0.0
	if not query_pair_active("pair_armor_infantry"):
		return 0.0
	var role: int = UnitRolesRef.resolve_role_cached(stats)
	if role == UnitRolesRef.ROLE_ARMOR or role == UnitRolesRef.ROLE_INFANTRY:
		var eff: Dictionary = (ComboTacticsRef.PAIR_SYNERGIES["pair_armor_infantry"]["effect"] as Dictionary)
		return float(eff.get("deploy_delay_bonus", 0.0))
	return 0.0


## 侦察×火炮标记写入（命中侧调用）：侦察单位命中 → 目标挂 _pair_art_mark_until。
## 返回 true 表示本次写了标记（供测试/调用方感知）。
static func try_apply_recon_artillery_mark(attacker: Node, target: Node) -> bool:
	if attacker == null or target == null or not is_instance_valid(attacker) or not is_instance_valid(target):
		return false
	if not query_pair_active("pair_recon_artillery"):
		return false
	var st: Variant = attacker.get("stats") if "stats" in attacker else null
	if st == null or not (st is Resource):
		return false
	if UnitRolesRef.resolve_role_cached(st) != UnitRolesRef.ROLE_RECON:
		return false
	# 目标须是敌对单位（防自伤队误标记）——敌我异侧判定
	if bool(attacker.get("is_player")) == bool(target.get("is_player")):
		return false
	var duration: float = float(ComboTacticsRef.PAIR_SYNERGIES["pair_recon_artillery"]["effect"].get("mark_duration", 5.0))
	target.set_meta("_pair_art_mark_until", Time.get_ticks_msec() / 1000.0 + duration)
	return true


## 火炮对标记目标的暴击消费（bullet.gd 暴击块调用）：shooter 是火炮角色且目标带未过期
## _pair_art_mark_until → 返回 true（调用方 effective_crit = 1.0）
static func is_artillery_mark_crit(shooter: Node, target: Node) -> bool:
	if shooter == null or target == null or not is_instance_valid(shooter) or not is_instance_valid(target):
		return false
	if not query_pair_active("pair_recon_artillery"):
		return false
	var st: Variant = shooter.get("stats") if "stats" in shooter else null
	if st == null or not (st is Resource):
		return false
	if UnitRolesRef.resolve_role_cached(st) != UnitRolesRef.ROLE_ARTILLERY:
		return false
	if not target.has_meta("_pair_art_mark_until"):
		return false
	return Time.get_ticks_msec() / 1000.0 < float(target.get_meta("_pair_art_mark_until", 0.0))


## 火炮对标记目标的溅射乘数（_apply_splash / 曲射 batch 调用）：1.5 或 1.0
static func get_artillery_mark_splash_mult(shooter: Node, target: Node) -> float:
	if is_artillery_mark_crit(shooter, target):
		return float(ComboTacticsRef.PAIR_SYNERGIES["pair_recon_artillery"]["effect"].get("splash_mult", 1.5))
	return 1.0
