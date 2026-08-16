extends RefCounted
class_name ComboEngine
## v9.1 我方组合技套路系统 — 套路引擎
##
## 职责（每帧/事件驱动）：
## 1. update(delta)：衰减战场浓度 + 周期检测全队兵种组合（解锁新机制 flag）
## 2. 新机制执行（被 module_effect_handler / bullet.gd 调用）：化学爆发扩散、电磁脉冲反射、
##    纳米感染扩散、光束反射/多重攻击、集火链式弱点暴露、化学腐蚀降防
## 3. 提供查询 API：get_active_mechanisms() 供战斗侧读取当前激活的新机制
##
## 生命周期：由 BattleManager 持有实例，start_battle 时创建并 setup()，每帧 update(delta)，
##           end_battle 时 reset()。field_state 是 ComboFieldState 实例（共享）。
##
## 设计决策：
## 1. 单卡改造组合检测在建卡时（unit_stats_table._apply_mod_stat_effects）一次性写入 stats meta，
##    引擎不重复检测单卡——引擎只管"全队新机制 flag"的周期刷新。
## 2. 新机制执行函数做成 static（不依赖引擎实例状态），供 module_effect_handler/bullet 直接调用，
##    通过传入 field_state + mechanisms 参数解耦。
## 3. 全队机制 flag 每 1s 刷新一次（仿 tactic_detector 节流），避免每帧扫描全场。

const ComboTactics = preload("res://data/combo_tactics.gd")
const ComboFieldState = preload("res://scripts/battle/combo_field_state.gd")
const ModuleEffectHandler = preload("res://scripts/battle/module_effect_handler.gd")
const VfxImpactFactory = preload("res://scripts/battle/vfx_impact_factory.gd")

const TEAM_REFRESH_INTERVAL: float = 1.0   # 全队机制刷新节流

var _field_state: ComboFieldState = null
var _battlefield: Node = null
## 全队激活的新机制 flag 列表（每 1s 刷新，供战斗侧查询）
var _active_mechanisms: Array = []
var _team_refresh_acc: float = 0.0
## 是否已激活（战斗开始后才有数据）
var _active: bool = false
## v9.1 上一次横幅展示的 combo_id 集合（防止同一组合反复弹横幅）
var _last_banner_combos: Array = []

func setup(battlefield: Node, field_state: ComboFieldState) -> void:
	_battlefield = battlefield
	_field_state = field_state
	_active_mechanisms.clear()
	_team_refresh_acc = 0.0
	_active = true

func stop() -> void:
	_active = false

func reset() -> void:
	_active_mechanisms.clear()
	_team_refresh_acc = 0.0
	_active = false
	_last_banner_combos.clear()
	if _field_state != null:
		_field_state.reset()

## 每帧驱动（由 battle_manager._process 调用）
func update(delta: float) -> void:
	if not _active:
		return
	# 1. 战场浓度自然衰减
	if _field_state != null:
		_field_state.update(delta)
	# 2. 全队机制 flag 节流刷新
	_team_refresh_acc += delta
	if _team_refresh_acc >= TEAM_REFRESH_INTERVAL:
		_team_refresh_acc = 0.0
		_refresh_team_mechanisms()

## 周期刷新全队激活的新机制 flag（基于场上我方兵种组合）
func _refresh_team_mechanisms() -> void:
	if _battlefield == null or not is_instance_valid(_battlefield):
		return
	var allies: Array = _get_player_units()
	if allies.is_empty():
		_active_mechanisms.clear()
		_last_banner_combos.clear()
		return
	var team_combos: Array = ComboTactics.detect_team_combos(allies)
	_active_mechanisms = ComboTactics.get_active_mechanisms(team_combos)
	# v9.1 横幅触发：新激活的 combo（对比上次）→ 弹全队激活横幅
	if not team_combos.is_empty():
		var new_ones: Array = []
		for cid in team_combos:
			if not _last_banner_combos.has(cid):
				new_ones.append(cid)
		if not new_ones.is_empty():
			_emit_team_activate_banner(new_ones)
		_last_banner_combos = team_combos.duplicate()
	else:
		_last_banner_combos.clear()


## v9.1 弹全队激活横幅
func _emit_team_activate_banner(new_combo_ids: Array) -> void:
	var names: Array = []
	for cid in new_combo_ids:
		var def: Dictionary = ComboTactics.get_combo_def(String(cid))
		if not def.is_empty():
			names.append(String(def.get("name", cid)))
	if names.is_empty():
		return
	VfxImpactFactory.show_combo_activate_banner(
		"「%s」全队激活！" % ", ".join(names), 2.0, true
	)

## 获取当前全队激活的新机制 flag 列表（供战斗侧查询）
func get_active_mechanisms() -> Array:
	return _active_mechanisms.duplicate()

## 判断某新机制是否激活
func is_mechanism_active(mech: String) -> bool:
	return _active_mechanisms.has(mech)

func get_field_state() -> ComboFieldState:
	return _field_state

# ─────────────────────────────────────────────
#  新机制执行（static，供 module_effect_handler / bullet.gd 直接调用）
#  所有函数都先检查 mech flag 是否激活，未激活直接 return（零成本）。
# ─────────────────────────────────────────────

## 套路1 化学爆发：目标燃烧层数 ≥8 时，燃烧 tick 引发范围扩散（感染相邻敌人 3 层燃烧）。
## 由 module_effect_handler._tick_dot_damage 在 burn 结算后调用。
static func try_chem_burst(mechanisms: Array, field_state: ComboFieldState, target: Node, source: Node) -> void:
	if not mechanisms.has("chem_burst"):
		return
	if target == null or not is_instance_valid(target):
		return
	# 读燃烧层数（module_effect_handler 维护的 _burn_stacks meta）
	if not target.has_meta("_burn_stacks"):
		return
	var stacks: int = int(target.get_meta("_burn_stacks", 0))
	if stacks < 8:
		return
	# 找相邻敌方单位（半径 80），感染 3 层燃烧
	var neighbors: Array = _get_nearby_enemies(target, 80.0, source)
	var infected: int = 0
	for n in neighbors:
		if infected >= 3:
			break
		if n == target:
			continue
		# 复用 burn 叠层（写 _burn_stacks + _burn_base_dps + _burn_until）
		_infect_burn(n, 3, 4.0)   # 3 层，4 秒
		infected += 1
	# v9.1 化学爆炸扩散波纹 VFX（在源单位位置播放）
	if infected > 0 and target is Node2D:
		var parent: Node2D = (target as Node2D).get_parent() as Node2D
		if parent != null:
			VfxImpactFactory.spawn_chem_burst_wave(parent, (target as Node2D).global_position)

## 套路6 污染扩散：化学污染浓度 ≥40 时，化学 dot tick 感染相邻敌人。
## 由 module_effect_handler._tick_dot_damage 在 chem 结算后调用。
static func try_chem_spread(mechanisms: Array, field_state: ComboFieldState, target: Node, source: Node) -> void:
	if not mechanisms.has("chem_spread"):
		return
	if field_state == null:
		return
	if not field_state.field_at_least(ComboFieldState.FIELD_CHEM, 40.0):
		return
	if target == null or not is_instance_valid(target):
		return
	# 找 1 个相邻敌方单位感染化学
	var neighbors: Array = _get_nearby_enemies(target, 90.0, source)
	for n in neighbors:
		if n == target:
			continue
		# 复用 chem dot meta（写 _chem_dps + _chem_until）
		_infect_chem(n, 8.0, 3.0)   # 8 dps，3 秒
		break   # 单次只扩散 1 个

## 套路2 电磁脉冲反射：目标石墨累积 ≥5 时，受 emp 攻击触发连锁反射（向 3 个相邻敌方释放弱化 emp）。
## 由 module_effect_handler._apply_emp_on_hit 在 emp 命中后调用。
static func try_emp_reflect(mechanisms: Array, field_state: ComboFieldState, target: Node, attacker: Node) -> void:
	if not mechanisms.has("emp_reflect"):
		return
	if target == null or not is_instance_valid(target):
		return
	var charge: int = ComboFieldState.get_target_stacks(target, ComboFieldState.META_GRAPHITE_CHARGE, ComboFieldState.META_GRAPHITE_UNTIL)
	if charge < 5:
		return
	# 找 3 个相邻敌方单位（敌方视角：相邻的是玩家单位）
	var neighbors: Array = _get_nearby_player_units(target, 150.0)
	var reflected: int = 0
	for n in neighbors:
		if reflected >= 3:
			break
		# 弱化 emp：写 _ecm_debuffed_until + 减益 meta（复用现有 ECM debuff 路径）
		# v10(C4) 统一：时间戳秒制（与其他 ECM 写入方一致）
		var now_sec: float = Time.get_ticks_msec() / 1000.0
		n.set_meta("_ecm_debuffed_until", now_sec + 1.5)
		n.set_meta("_ecm_attack_speed_penalty", 0.15)
		n.set_meta("_ecm_crit_penalty", 0.10)
		n.set_meta("_ecm_dodge_penalty", 0.05)
		reflected += 1
	# v9.1 EMP 反射 VFX：从被攻击敌方画电弧到各被反射单位
	if reflected > 0 and target is Node2D:
		var tparent: Node2D = (target as Node2D).get_parent() as Node2D
		if tparent != null:
			var tpos: Vector2 = (target as Node2D).global_position
			for n in neighbors:
				if n is Node2D:
					VfxImpactFactory.spawn_lightning_arc(tparent, tpos, (n as Node2D).global_position, Color(0.75, 0.35, 1.0))
	# v9.1b：反射后消耗 3 点石墨电荷（防持续命中全程触发 emp_reflect，平衡套路2）。
	# 目标需重新累积 graphite 才能再次触发反射，给玩家压制窗口。
	if reflected > 0 and target != null and is_instance_valid(target):
		var _cur_until: float = float(target.get_meta(ComboFieldState.META_GRAPHITE_UNTIL, 0.0))
		var _new_charge: int = maxi(0, charge - 3)
		target.set_meta(ComboFieldState.META_GRAPHITE_CHARGE, _new_charge)
		target.set_meta(ComboFieldState.META_GRAPHITE_UNTIL, _cur_until)   # 保留原过期时间

## 套路3 纳米感染扩散：纳米浓度 ≥50 时，nano dot 结算 30% 概率感染相邻敌人。
## 由 module_effect_handler._apply_nano_on_hit 或 _tick_dot_damage 在 nano 结算后调用。
static func try_nano_spread(mechanisms: Array, field_state: ComboFieldState, target: Node, source: Node) -> void:
	if not mechanisms.has("nano_spread"):
		return
	if field_state == null:
		return
	if not field_state.field_at_least(ComboFieldState.FIELD_NANO, 50.0):
		return
	if randf() > 0.3:   # 30% 概率
		return
	if target == null or not is_instance_valid(target):
		return
	var neighbors: Array = _get_nearby_enemies(target, 100.0, source)
	for n in neighbors:
		if n == target:
			continue
		# 感染纳米病毒（写 _nano_pct + _nano_until）
		_infect_nano(n, 0.02, 4.0)   # 2% max_hp/s，4 秒
		# v9.1 纳米传染波纹 VFX（在被感染者位置播放）
		if n is Node2D:
			var nparent: Node2D = (n as Node2D).get_parent() as Node2D
			if nparent != null:
				VfxImpactFactory.spawn_nano_spread_wave(nparent, (n as Node2D).global_position)
		break   # 单次只扩散 1 个

## 套路4 光束反射/多重攻击：在 bullet.gd 命中后调用。
## 光束武器命中带 laser_resonance 标记的目标 → 反射到相邻敌方 + 追加次级光束。
## 返回：是否触发了反射（供 bullet 做额外光束 VFX）
static func try_beam_resonance(mechanisms: Array, field_state: ComboFieldState, shooter: Node, target: Node, weapon_is_beam: bool) -> Dictionary:
	var result: Dictionary = {"reflect": false, "split": false}
	if not weapon_is_beam:
		return result
	if target == null or not is_instance_valid(target):
		return result
	var resonance: int = ComboFieldState.get_target_stacks(target, ComboFieldState.META_LASER_RESONANCE, ComboFieldState.META_LASER_UNTIL)
	if resonance <= 0:
		return result
	# 多重攻击：resonance ≥3 追加 2 道次级光束（每道 40% 伤害）
	if mechanisms.has("beam_split") and resonance >= 3:
		result["split"] = true
	# 光束反射：30% 概率反射到相邻敌方（衰减 60%）
	if mechanisms.has("beam_reflect") and randf() < 0.3:
		result["reflect"] = true
	return result

## 套路5 集火链式弱点暴露：狙击手命中同时有无人机标记+雷达锁定的目标 → 触发弱点暴露。
## 在 bullet.gd 命中后调用。弱点暴露写 _weakpoint_until + _weakpoint_bonus meta。
static func try_weakpoint_expose(mechanisms: Array, field_state: ComboFieldState, shooter: Node, target: Node) -> bool:
	if not mechanisms.has("weakpoint_expose"):
		return false
	if target == null or not is_instance_valid(target):
		return false
	# 检查目标是否同时有无人机标记 + 雷达锁定
	# v9.1 修复：META_RADAR_LOCKED 是 until_key（秒时间戳），直接判存在性+过期。
	# 无人机标记 _drone_marked_until 是毫秒时间戳，雷达锁定 META_RADAR_LOCKED 是秒时间戳（两者口径不同，历史遗留）。
	var has_drone_mark: bool = target.has_meta("_drone_marked_until") and Time.get_ticks_msec() < int(target.get_meta("_drone_marked_until", 0))
	var has_radar_lock: bool = target.has_meta(ComboFieldState.META_RADAR_LOCKED) and \
		Time.get_ticks_msec() / 1000.0 < float(target.get_meta(ComboFieldState.META_RADAR_LOCKED, 0.0))
	if not (has_drone_mark and has_radar_lock):
		return false
	# 写弱点暴露 meta（下次任意命中该目标 +50% 暴击伤害，持续 3s）
	ComboFieldState.set_target_meta(target, ComboFieldState.META_WEAKPOINT_BONUS, ComboFieldState.META_WEAKPOINT_UNTIL, 0.5, 3.0)
	return true

# ─────────────────────────────────────────────
#  辅助：单位收集 + 感染函数（复用现有 meta 范式）
# ─────────────────────────────────────────────

## 取目标周围（半径内）的"敌方单位"（从 target 视角：target 是敌方，周围是玩家单位；target 是玩家，周围是敌方）。
## source 是攻击者（用于判断阵营）。这里简化：取与 source 同阵营的单位（source 的友军，即 target 的敌人）。
## 实际用于"扩散感染 target 的相邻敌人"——所以返回 target 附近的敌方单位（source 同阵营）。
static func _get_nearby_enemies(target: Node, radius: float, source: Node) -> Array:
	if target == null or not is_instance_valid(target):
		return []
	var tpos: Vector2 = (target as Node2D).global_position if target is Node2D else Vector2.ZERO
	# source 的友军 = target 的敌人
	var group_name: String = "player_units" if _is_player_side(source) else "enemy_units"
	var tree: SceneTree = target.get_tree() if target != null else null
	if tree == null:
		return []
	# 优先用 BattleManager 的节流缓存，避免每次扩散全树遍历
	var result: Array = []
	var cached: Array = []
	var _bm = tree.root.get_node_or_null("BattleManager")
	if _bm != null and _bm.has_method("get_cached_nodes_in_group"):
		cached = _bm.get_cached_nodes_in_group(group_name)
	else:
		cached = tree.get_nodes_in_group(group_name)
	for n in cached:
		if n == null or not is_instance_valid(n) or not (n is Node2D):
			continue
		if n == target:
			continue
		if tpos.distance_to((n as Node2D).global_position) <= radius:
			result.append(n)
	return result

## 取目标周围的玩家单位（emp_reflect 专用：target 是敌方，反射目标是玩家单位）
static func _get_nearby_player_units(target: Node, radius: float) -> Array:
	if target == null or not is_instance_valid(target):
		return []
	var tpos: Vector2 = (target as Node2D).global_position if target is Node2D else Vector2.ZERO
	var tree: SceneTree = target.get_tree() if target != null else null
	if tree == null:
		return []
	# 优先用 BattleManager 的节流缓存
	var result: Array = []
	var cached: Array = []
	var _bm = tree.root.get_node_or_null("BattleManager")
	if _bm != null and _bm.has_method("get_cached_nodes_in_group"):
		cached = _bm.get_cached_nodes_in_group("player_units")
	else:
		cached = tree.get_nodes_in_group("player_units")
	for n in cached:
		if n == null or not is_instance_valid(n) or not (n is Node2D):
			continue
		if tpos.distance_to((n as Node2D).global_position) <= radius:
			result.append(n)
	return result

## 判断单位是否玩家方（简化：玩家单位在 player_units 组）
static func _is_player_side(unit: Node) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false
	return unit.is_in_group("player_units")

## 感染燃烧（复用 module_effect_handler 的 burn meta 范式）
static func _infect_burn(target: Node, stacks: int, duration: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var now_sec: float = Time.get_ticks_msec() / 1000.0
	var cur_stacks: int = int(target.get_meta("_burn_stacks", 0))
	cur_stacks = mini(cur_stacks + stacks, 10)   # 套路激活时上限放宽到 10
	target.set_meta("_burn_stacks", cur_stacks)
	target.set_meta("_burn_base_dps", float(target.get_meta("_burn_base_dps", 0.0)) + 5.0)   # 每层 5 dps
	target.set_meta("_burn_until", now_sec + duration)

## 感染化学（复用 module_effect_handler 的 chem meta 范式）
static func _infect_chem(target: Node, dps: float, duration: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var now_sec: float = Time.get_ticks_msec() / 1000.0
	target.set_meta("_chem_dps", float(target.get_meta("_chem_dps", 0.0)) + dps)
	target.set_meta("_chem_until", now_sec + duration)

## 感染纳米（复用 module_effect_handler 的 nano meta 范式）
static func _infect_nano(target: Node, pct: float, duration: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var now_sec: float = Time.get_ticks_msec() / 1000.0
	target.set_meta("_nano_pct", float(target.get_meta("_nano_pct", 0.0)) + pct)
	target.set_meta("_nano_until", now_sec + duration)

## 取玩家单位列表
func _get_player_units() -> Array:
	if _battlefield == null or not is_instance_valid(_battlefield):
		return []
	var tree: SceneTree = _battlefield.get_tree() if _battlefield != null else null
	if tree == null:
		return []
	# 优先用 BattleManager 的节流缓存
	var _bm = tree.root.get_node_or_null("BattleManager")
	if _bm != null and _bm.has_method("get_cached_nodes_in_group"):
		return _bm.get_cached_nodes_in_group("player_units")
	return tree.get_nodes_in_group("player_units")
