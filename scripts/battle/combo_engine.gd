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
const AuraDataRef = preload("res://data/aura_data.gd")  # v21 P1: 化学跨列蔓延读槽位列（只读）
const PairSynergyEngineScript = preload("res://scripts/battle/pair_synergy_engine.gd")  # v21 P2

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
## v21 P1: 满档套路 id 集合（任一友军卡集齐 mod_combo_full 即计入；每 1s 随全队刷新）
var _full_tier_combos: Array = []
## v21 P2: 搭档协同引擎（事件驱动刷新 + 数值对称记账 + 激活态查询）
var _pair_engine: RefCounted = null

func setup(battlefield: Node, field_state: ComboFieldState) -> void:
	_battlefield = battlefield
	_field_state = field_state
	_active_mechanisms.clear()
	_team_refresh_acc = 0.0
	_active = true
	# v21 P2: 搭档引擎随战斗创建
	_pair_engine = PairSynergyEngineScript.new()
	_pair_engine.setup(battlefield)

func stop() -> void:
	_active = false

func reset() -> void:
	_active_mechanisms.clear()
	_team_refresh_acc = 0.0
	_active = false
	_last_banner_combos.clear()
	_full_tier_combos.clear()
	if _pair_engine != null:
		_pair_engine.reset()
		_pair_engine = null
	if _field_state != null:
		_field_state.reset()

## 每帧驱动（由 battle_manager._process 调用）
func update(delta: float) -> void:
	if not _active:
		return
	# 1. 战场浓度自然衰减
	# v21 P1: 纳米浓度场满档（nano_decay_half）→ 衰减减半（机制升级：浓度保持更久）
	if _field_state != null:
		var decay_scale: float = 0.5 if _active_mechanisms.has("nano_decay_half") else 1.0
		_field_state.update(delta, decay_scale)
	# 2. 全队机制 flag 节流刷新
	_team_refresh_acc += delta
	if _team_refresh_acc >= TEAM_REFRESH_INTERVAL:
		_team_refresh_acc = 0.0
		_refresh_team_mechanisms()
	# 3. v21 P2: 搭档引擎逐帧转发（当前无逐帧机制，预留接口）
	if _pair_engine != null:
		_pair_engine.update(delta)

## v21 P1/P2: 单位生成/死亡事件驱动立即刷新（battle_manager 的 SignalBus 回调调用，
## 不加每帧扫描——事件触发 + 1s 节流兜底，避免新部署的满档卡/搭档最长 1s 才生效）。
func on_units_changed() -> void:
	if not _active:
		return
	_refresh_team_mechanisms()
	# v21 P2: 搭档激活态事件刷新
	if _pair_engine != null:
		_pair_engine.refresh(_battlefield)

## v21 P2: 查询搭档激活态（消费点经 PairSynergyEngine.query_pair_active 间接调用）
func is_pair_active(pair_id: String) -> bool:
	return _pair_engine != null and bool(_pair_engine.is_pair_active(pair_id))

## 周期刷新全队激活的新机制 flag（基于场上我方兵种组合）
func _refresh_team_mechanisms() -> void:
	if _battlefield == null or not is_instance_valid(_battlefield):
		return
	var allies: Array = _get_player_units()
	if allies.is_empty():
		_active_mechanisms.clear()
		_last_banner_combos.clear()
		_full_tier_combos.clear()
		return
	var team_combos: Array = ComboTactics.detect_team_combos(allies)
	_active_mechanisms = ComboTactics.get_active_mechanisms(team_combos)
	# v21 P1: 满档扫描——读取场上单位 stats meta "combo_tiers"（建卡时
	# unit_stats_table._apply_mod_stat_effects 写入），任一卡满档即全队共享该满档机制。
	# 复用本次全组遍历，无额外扫描；执行端与既有 mechanisms flag 同管道（_active_mechanisms）。
	_full_tier_combos = _scan_full_tiers(allies)
	for fm in ComboTactics.get_full_mechanisms(_full_tier_combos):
		var fms: String = String(fm)
		if not _active_mechanisms.has(fms):
			_active_mechanisms.append(fms)
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

## v21 P1: 扫描场上单位的满档套路 id（stats meta combo_tiers 值 == "full"）
static func _scan_full_tiers(allies: Array) -> Array:
	var full: Array = []
	for u in allies:
		if u == null or not is_instance_valid(u):
			continue
		var st: Variant = u.get("stats") if "stats" in u else null
		if st == null or not (st is Resource) or not (st as Resource).has_meta("combo_tiers"):
			continue
		var tiers: Variant = (st as Resource).get_meta("combo_tiers", {})
		if not (tiers is Dictionary):
			continue
		for cid in (tiers as Dictionary).keys():
			if String((tiers as Dictionary).get(cid, "")) == ComboTactics.TIER_FULL and not full.has(String(cid)):
				full.append(String(cid))
	return full

## v21 P1: 查询某套路是否满档（供外部消费点查询）
func is_combo_full(combo_id: String) -> bool:
	return _full_tier_combos.has(combo_id)


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
	# v21 P1: 化学满档（chem_cross_column）——污染跨列蔓延：额外感染 1 个"带内列不同"
	# 的敌方单位（原扩散限邻接半径 90）。列判定读槽位 meta（card_grid_slot /
	# card_grid_enemy_slot，AuraData 单一真身换算），无槽位 meta 的实体（相位场）跳过。
	if mechanisms.has("chem_cross_column"):
		var t_col: int = _unit_column(target)
		if t_col >= 0:
			var cross_targets: Array = _get_nearby_enemies(target, 100000.0, source)   # 全场敌方
			for cn in cross_targets:
				if cn == target:
					continue
				var c_col: int = _unit_column(cn)
				if c_col >= 0 and c_col != t_col:
					_infect_chem(cn, 8.0, 3.0)
					break   # 单次只跨列蔓延 1 个（与邻接扩散同节奏）

## v21 P1: 读单位带内列（-1 = 无槽位 meta，跳过判定）
static func _unit_column(unit: Node) -> int:
	if unit == null or not is_instance_valid(unit):
		return -1
	var slot: int = AuraDataRef.unit_slot_index(unit)
	if slot < 0:
		return -1
	return AuraDataRef.slot_grid_coords(slot).x

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
	# v21 P1 评审修正：v9.1 头注释承诺"向 3 个相邻敌方释放弱化 emp"，实现却取了
	# 玩家单位（参照系写反，交火时玩家贴脸单位被自伤）。改回设计语义——
	# 链式放电到与被命中目标同阵营的邻近敌人（enemy_units 组）。
	var neighbors: Array = _get_nearby_enemy_units(target, 150.0)
	var reflected: int = 0
	# v21 P1: EMP 满档（emp_reflect_stun）——脉冲反射附带 0.5s 瘫痪。
	# 瘫痪复用战场既有 _hit_stun_left（construct_unit/enemy_unit 的硬直状态机，
	# >0 时本回合停止攻击），与重击瘫痪同管道，不新增弹道路由。
	var is_full: bool = mechanisms.has("emp_reflect_stun")
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
		# v21 P1: 满档附带瘫痪（0.5s，与重击硬直同源，取 max 不叠加）
		if is_full and "_hit_stun_left" in n:
			n._hit_stun_left = maxf(float(n._hit_stun_left), 0.5)
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

## v21 P1 套路1 满档（incendiary_death_seed）：燃烧目标死亡时留火种——
## 继承目标 50% 燃烧层数，作为范围 DOT 感染死者周围的敌方单位（上限 3 个，4 秒）。
## 由 module_effect_handler.on_unit_killed 在击杀结算时调用（victim 死亡时 meta 尚可读）。
## static 与其他机制执行函数同风格：mechanisms 未含满档 flag 直接 return（零成本）。
static func try_incendiary_death_seed(mechanisms: Array, target: Node, source: Node) -> void:
	if not mechanisms.has("incendiary_death_seed"):
		return
	if target == null or not is_instance_valid(target):
		return
	# 读死者燃烧层数（module_effect_handler/_infect_burn 维护的 _burn_stacks meta）
	var stacks: int = int(target.get_meta("_burn_stacks", 0))
	if stacks <= 0:
		return
	# 继承 50% 层数（至少 1 层），上限对齐满档燃烧 10 层
	var inherit: int = clampi(int(ceil(float(stacks) * 0.5)), 1, 10)
	# 找死者周围的敌方单位（source 的友军 = 死者的敌人），感染继承层数
	var neighbors: Array = _get_nearby_enemies(target, 100.0, source)
	var seeded: int = 0
	for n in neighbors:
		if seeded >= 3:
			break
		if n == target:
			continue
		_infect_burn(n, inherit, 4.0)
		seeded += 1
	# 火种 VFX：死者位置播放化学爆炸扩散波纹（复用既有 VFX，不新增资源）
	if seeded > 0 and target is Node2D:
		var parent: Node2D = (target as Node2D).get_parent() as Node2D
		if parent != null:
			VfxImpactFactory.spawn_chem_burst_wave(parent, (target as Node2D).global_position)

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

## 取目标周围的敌方单位（emp_reflect 专用：链式放电，target 是被命中敌人，
## 反射目标为其邻近同阵营敌人——v21 P1 评审修正，原 v9.1 误取玩家单位）
static func _get_nearby_enemy_units(target: Node, radius: float) -> Array:
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
		cached = _bm.get_cached_nodes_in_group("enemy_units")
	else:
		cached = tree.get_nodes_in_group("enemy_units")
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
