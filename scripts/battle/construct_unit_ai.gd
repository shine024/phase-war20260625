## ConstructUnit AI / Attack / Targeting logic
## 提取自 construct_unit.gd，class_name 用于跨文件引用
class_name ConstructUnitAI
extends RefCounted

const GC = preload("res://resources/game_constants.gd")
const BulletScene = preload("res://scenes/units/bullet.tscn")
const ModuleEffectHandler = preload("res://scripts/battle/module_effect_handler.gd")
const CombatFeedback = preload("res://scripts/combat_feedback.gd")
const CombatTargeting = preload("res://scripts/combat_targeting.gd")
const TargetSelection = preload("res://scripts/battle/target_selection.gd")
const DamageAttenuation = preload("res://scripts/battle/damage_attenuation.gd")
const AttackCalculator = preload("res://scripts/battle/attack_calculator.gd")
const VfxImpactFactory = preload("res://scripts/battle/vfx_impact_factory.gd")
const WeaponVisuals = preload("res://data/weapon_visual_profiles.gd")  # v17: 武器视觉档案（名字优先解析）
const DT = preload("res://resources/design_tokens.gd")
const CardGridLayout = preload("res://scripts/card_grid_battle_layout.gd")  # v9.2: 分行索敌行判定
const AttackPoseAnim = preload("res://scripts/battle/attack_pose_anim.gd")  # v9.x: 按武器分化的攻击姿态/攻击帧
const CardGridUnitVisuals = preload("res://scripts/card_grid_unit_visuals.gd")  # v8.x: 战场卡图视觉数据（头脚锚点）
const MuzzleAnchors = preload("res://data/muzzle_anchors.gd")  # 弹道/枪口锚点（独立二维）
const PlayerMuzzleAnchors = preload("res://data/player_muzzle_anchors.gd")  # 我方卡头脚+开火点（117条，fireX已按我方朝左转换）

## v7.x: 光环/指挥单位的 platform_type 集合（与 construct_unit.gd 光环注册对齐）
## FORTRESS=3, RADAR=4, SCOUT=5, CARRIER=8, MEDIC=9, STEALTH=10, COMMAND=12
const AURA_PLATFORM_TYPES := [3, 4, 5, 8, 9, 10, 12]

## v10(M1): 格子战模式判定。本作格子战是唯一战斗模式（AGENTS H-2 硬约束），恒为 true。
## 原各处写 `GameManager != null and BattleManager != null`（autoload 恒非 null，判定恒真），
## 对应"传统战场"分支均为死分支；如未来恢复传统战场模式，只需改本函数一处。
static func is_card_grid_battle() -> bool:
	return true

## 主循环攻击处理：由 construct_unit._physics_process 调用
## 返回值暂未使用，保留以备扩展
static func process_attack(u: CharacterBody2D, delta: float) -> void:
	# 多武器处理
	if u._weapon_cfgs.size() > 0:
		_process_multi_weapons(u, delta)
	else:
		if u._hit_stun_left <= 0.0:
			_process_single_weapon_attack(u, delta)

## 获取目标查找间隔
## P1 性能优化：has_method 反射结果缓存——BattleManager 单例方法集运行期不变，
## 原每轮索敌（每单位 ~0.3s 一次）都做一次 has_method 反射查询
static var _bm_has_unit_count_method: int = -1  # -1 未检测 / 0 无 / 1 有
static func get_target_find_interval(u: CharacterBody2D) -> float:
	var n: int = 0
	if BattleManager != null:
		if _bm_has_unit_count_method < 0:
			_bm_has_unit_count_method = 1 if BattleManager.has_method("get_enemy_unit_count") else 0
		if _bm_has_unit_count_method == 1:
			n = BattleManager.get_enemy_unit_count()
	if n > 55:
		return 0.55
	if n > 35:
		return 0.42
	return 0.3

## 查找攻击目标（性能优化：卡牌网格只检查附近槽位）
static func find_target(u: CharacterBody2D, _delta: float) -> void:
	if should_retain_current_target(u):
		return
	u.target = null

	## 获取索敌方式（三攻三防系统）
	var targeting_mode: int = GC.TargetingMode.NEAREST_FIRST
	if u.stats != null:
		targeting_mode = GC.get_targeting_mode_for_combat_kind(u.stats.combat_kind)

	# 卡牌网格战斗：曲射/空射单位用槽位扫描（从远到近的语义需要槽位系统）
	# v7.3 性能优化：直射单位优先走 spatial_grid（O(覆盖格数)，比 card_grid 全组 O(N) 遍历快），
	# card_grid 作 fallback。原实现无论直射曲射都恒走 card_grid，spatial_grid 形同虚设，
	# 每0.3s 全组遍历+select_target 子遍历造成同步尖峰（20+20单位时每秒~1300次反射+距离比较）。
	var is_indirect_unit: bool = _fires_indirect(u)

	# 直射单位：优先 spatial_grid
	if not is_indirect_unit and BattleManager and BattleManager.spatial_grid:
		var spatial_grid = BattleManager.spatial_grid
		if spatial_grid:
			var max_range: float = mini(acquisition_range(u), 250.0)
			# v9.2: 分行索敌——先查同行最近目标，无则回退全行最近。
			# spatial_grid.query_nearest_target_with_mode 不支持行过滤，故采用两步：
			# ① 查射程内最近（同行/跨行都有）；② 若该目标与攻击者不同行，再查一次"最近同行目标"优先。
			var nearest_target = spatial_grid.query_nearest_target_with_mode(
				u.global_position,
				u.is_player,
				max_range,
				targeting_mode
			)
			# v9.2: 若最近目标不在同行，尝试在同行找一个；同行无则接受原最近目标（跨行回退）。
			if nearest_target != null and not CardGridLayout.units_in_same_row(u, nearest_target):
				var same_row_target: Node2D = _query_nearest_same_row_spatial(u, spatial_grid, max_range, targeting_mode)
				if same_row_target != null:
					nearest_target = same_row_target
			if nearest_target != null:
				u.target = nearest_target
				return

	# 曲射/空射单位，或 spatial_grid 未命中时：用卡牌网格槽位系统
	if is_card_grid_battle():
		var slot_target = _find_target_by_card_grid(u, targeting_mode)
		if slot_target != null:
			u.target = slot_target
			return

	# 传统战场回退：空间分区系统（直射单位且上面 spatial_grid 未命中时的二次尝试）
	if is_indirect_unit and BattleManager and BattleManager.spatial_grid:
		var spatial_grid2 = BattleManager.spatial_grid
		if spatial_grid2:
			var max_range2: float = mini(acquisition_range(u), 250.0)
			var nearest_target2 = spatial_grid2.query_nearest_target_with_mode(
				u.global_position,
				u.is_player,
				max_range2,
				targeting_mode
			)
			# v9.x: 曲射/空射全场索敌——本分支仅曲射/空射单位进入，不再做同行收敛
			if nearest_target2 != null:
				u.target = nearest_target2
				return

	# 回退到传统方法（使用新索敌函数）
	var candidates = CombatTargeting.find_targets_with_mode(
		u.global_position,
		u.is_player,
		BattleManager,
		acquisition_range(u),
		targeting_mode
	)

	if not candidates.is_empty():
		var candidate_nodes: Array = []
		var final_candidates: Array = []
		# v9.2: 分行索敌——候选按"同行优先"筛选（空则跨行回退）
		# v9.x: 仅直射单位收敛同行；曲射/空射全场选目标
		if not is_indirect_unit:
			candidates = _prefer_same_row(u, candidates)
		# 限制候选数量到最多10个
		var limit: int = mini(candidates.size(), 10)
		for i in range(limit):
			candidate_nodes.append(candidates[i].node)

		if u.stats != null:
			var selected: Node2D = TargetSelection.select_target(
				u, candidate_nodes, u.stats.weapon_type
			)
			if selected != null:
				u.target = selected
				return

		if not candidate_nodes.is_empty():
			u.target = candidate_nodes[0] as Node2D
			return

	# 无对方战斗单位时，攻击对方相位场
	if targeting_opponent_phase_field_only(u):
		var phase_field: Node2D = CombatTargeting.find_opponent_phase_field(
			u.global_position, u.is_player, BattleManager, -1.0
		)
		if phase_field != null:
			u.target = phase_field
			return

## 卡牌网格战斗：索敌
## 曲射/空射 → 槽位编号扫描（从最远敌方槽位起，逐个向近，第一个有人的槽位即目标）
## 直射 → 射程内距离筛选 + select_target
## 注意：玩家单位槽位 meta 为 card_grid_slot，敌方单位为 card_grid_enemy_slot（见 battlefield.gd:474-480）
static func _find_target_by_card_grid(u: CharacterBody2D, targeting_mode: int = 0) -> Node2D:
	var my_slot: int = _get_unit_slot_index(u)
	if my_slot < 0:
		return null

	var tree = u.get_tree()
	if tree == null:
		return null

	var target_group: String = "enemy_units" if u.is_player else "player_units"
	var gr: Array = BattleManager.get_cached_nodes_in_group(target_group) if BattleManager else tree.get_nodes_in_group(target_group)

	# 曲射/空射：槽位编号扫描（全场，纯顺序，从远到近）
	# 判断：主武器 OR 任一武器槽为 INDIRECT/AERIAL
	# （多武器单位主武器可能为 DIRECT，但配有曲射副武器——之前漏判导致走直射索敌）
	if _fires_indirect(u):
		return _scan_slot_targets(u, gr)

	# 直射：射程内距离筛选 + select_target
	var origin: Vector2 = u.global_position
	var acq_range: float = acquisition_range(u)
	var acq_range_sq: float = acq_range * acq_range
	# v8: 兵种固定机制「防空空域封锁」——防空单位优先锁定射程内的 AIR 目标
	# is_anti_air_unit meta 由 apply_combat_kind_modifiers 在 ANTI_AIR 子类上设置
	if u.stats != null and u.stats.has_meta("is_anti_air_unit") and bool(u.stats.get_meta("is_anti_air_unit", false)):
		var air_tgt: Node2D = _pick_air_priority_target(u, gr, acq_range_sq)
		if air_tgt != null:
			return air_tgt
	var candidates: Array = []
	for n in gr:
		if not CombatTargeting.is_attackable_combat_unit(n):
			continue
		var n2d: Node2D = n as Node2D
		if origin.distance_squared_to(n2d.global_position) <= acq_range_sq:
			candidates.append(n)
	if candidates.is_empty():
		return null
	# v9.2: 分行索敌——同行优先，空则跨行回退（在 select_target 前过滤候选集）
	candidates = _prefer_same_row(u, candidates)
	if u.stats != null:
		return TargetSelection.select_target(u, candidates, u.stats.weapon_type)
	# 回退：取距离最近
	var best: Node2D = candidates[0]
	var best_d2: float = origin.distance_squared_to(best.global_position)
	for c in candidates:
		var d2: float = origin.distance_squared_to((c as Node2D).global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = c
	return best


## 统一读取单位槽位编号（玩家用 card_grid_slot，敌方用 card_grid_enemy_slot）
static func _get_unit_slot_index(n: Node) -> int:
	var s: int = int(n.get_meta("card_grid_slot", -1))
	if s >= 0:
		return s
	return int(n.get_meta("card_grid_enemy_slot", -1))


## v9.2: 分行索敌——同行优先，空则跨行回退。
## candidates 为已收集的候选数组，返回按"同行优先"筛过的数组：
## 若同行候选非空则只返回同行候选；否则原样返回全候选（避免单位空转）。
## 攻击者无 slot meta（异常情况）时原样返回，不参与行过滤。
static func _prefer_same_row(attacker: Node, candidates: Array) -> Array:
	if candidates.is_empty():
		return candidates
	if attacker == null or not is_instance_valid(attacker):
		return candidates
	if not attacker.has_meta("card_grid_slot") and not attacker.has_meta("card_grid_enemy_slot"):
		return candidates  # 无 slot meta，不参与行过滤
	var same_row: Array = []
	for c in candidates:
		if c == null or not is_instance_valid(c):
			continue
		if CardGridLayout.units_in_same_row(attacker, c):
			same_row.append(c)
	return same_row if not same_row.is_empty() else candidates


## v9.x: 单位是否曲射/空射（主武器或任一启用槽位，含 legacy 曲射值 MISSILE/ROCKET/FLAK）。
## 此类单位全场索敌、跨行射击全额伤害（直射才有跨行减伤，见 CardGridBattleLayout.cross_row_direct_multiplier）。
static func _fires_indirect(u: CharacterBody2D) -> bool:
	if u.stats == null:
		return false
	if GC.is_indirect_weapon_type(u.stats.weapon_type):
		return true
	for _ws in u.stats.weapon_slots:
		if _ws is WeaponResource and _ws.enabled and GC.is_indirect_weapon_type(_ws.weapon_type):
			return true
	return false


## v9.2: spatial_grid 行过滤辅助——在射程内找同行最近敌方目标。
## 复用 spatial_grid.query_enemies 拿到半径内所有敌方，按同行过滤后取最近；无同行则返回 null。
static func _query_nearest_same_row_spatial(u: CharacterBody2D, spatial_grid: Node, max_range: float, _targeting_mode: int) -> Node2D:
	var enemies: Array = spatial_grid.query_enemies(u.global_position, max_range, u.is_player)
	if enemies.is_empty():
		return null
	var origin: Vector2 = u.global_position
	var best: Node2D = null
	var best_d2: float = INF
	for e in enemies:
		if e == null or not is_instance_valid(e) or not (e is Node2D):
			continue
		if not CardGridLayout.units_in_same_row(u, e):
			continue
		var d2: float = origin.distance_squared_to((e as Node2D).global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = e
	return best


## v8: 防空单位优先索敌——射程内优先打 AIR 类目标（空域封锁语义）。
## 命中则返回最近的空中目标；射程内无空中目标时返回 null（回退常规直射）。
## 搬运 enemy_unit.gd _pick_antitank_priority_target 结构，目标改为 AIR。
static func _pick_air_priority_target(u: CharacterBody2D, gr: Array, acq_range_sq: float) -> Node2D:
	var origin: Vector2 = u.global_position
	var air_targets: Array = []
	for n in gr:
		if not CombatTargeting.is_attackable_combat_unit(n):
			continue
		var s: UnitStats = n.get("stats") as UnitStats
		if s == null:
			continue
		if s.combat_kind == GC.CombatKind.AIR:
			var dist_sq := origin.distance_squared_to((n as Node2D).global_position)
			if dist_sq <= acq_range_sq:
				air_targets.append(n)
	if not air_targets.is_empty():
		return _nearest_of(origin, air_targets)
	return null


## 槽位编号扫描索敌（曲射/空射用）
## v7.x: 四级优先级降级链（每级同级取距离最近）：
##   L0 反击标记目标（art_14_counter_battery：被谁打就反击谁，优先攻击挂 _counter_marked_by 的目标）
##   L1 指挥单位（platform_type==12）→ L2 光环单位（AURA_PLATFORM_TYPES）
##   → L3 输出最高单位（DPS 最高，并列取最近）→ L4 最后排单位（槽位远→近兜底）
## L3 在任意有存活敌方时总能选出一个，L4 为安全兜底
static func _scan_slot_targets(u: CharacterBody2D, gr: Array) -> Node2D:
	var valid: Array = []
	for n in gr:
		if CombatTargeting.is_attackable_combat_unit(n):
			valid.append(n)
	if valid.is_empty():
		return null

	# v9.x: 曲射/空射全场索敌——L0~L3 直接在全量候选上做优先级链，不再收敛同行
	#（曲射/空射跨行射击全额伤害；直射才有跨行减伤，见 CardGridBattleLayout.cross_row_direct_multiplier）。

	var origin: Vector2 = u.global_position

	# L0 反击标记目标（仅当本单位装了 art_14_counter_battery 等反击改造时生效）
	# _apply_counter_battery_mark 在本炮兵被攻击时给攻击者挂 _counter_marked_by meta（带 5s _marked_until）；
	# 此前该 meta 写入后战斗侧零读取，现复活：炮兵优先反击刚刚打自己的敌人。
	# 过期检查复用 _marked_until（与标记系统同源），避免攻击者死亡后 meta 残留被永久优先。
	# v8: 兵种固定机制「火炮反炮兵」加计数器——counter_battery_shots 限制优先射击次数，
	# 归零时清理标记回退常规索敌（炮兵反击不再无限优先）。
	# v9.2: 反击标记优先（反击是战术优先，非兜底）；v9.x: 曲射全场索敌后标记跨行也能反击。
	if u.stats != null and u.stats.has_counter_battery and u.stats.counter_battery_shots > 0:
		var _now_cb: float = Time.get_ticks_msec() / 1000.0
		var marked: Array = valid.filter(func(n):
			return n is Node and n.has_meta("_counter_marked_by") and n.has_meta("_marked_until") and _now_cb < float(n.get_meta("_marked_until", 0.0)))
		if not marked.is_empty():
			# v8: 递减反炮兵剩余次数；归零时清理所有标记目标的 _counter_marked_by（停止优先）
			u.stats.counter_battery_shots -= 1
			if u.stats.counter_battery_shots <= 0:
				for n in marked:
					if n is Node and n.has_meta("_counter_marked_by"):
						n.remove_meta("_counter_marked_by")
			return _nearest_of(origin, marked)

	# L1 指挥单位
	var commanders: Array = valid.filter(func(n):
		return _is_command_unit(n.get("stats") as UnitStats))
	if not commanders.is_empty():
		return _nearest_of(origin, commanders)

	# L2 光环单位
	var aura_units: Array = valid.filter(func(n):
		return _is_aura_unit(n.get("stats") as UnitStats))
	if not aura_units.is_empty():
		return _nearest_of(origin, aura_units)

	# L3 输出最高单位（DPS 最高，并列容差内取最近）
	var best: Node2D = _highest_dps_unit(origin, valid)
	if best != null:
		return best

	# L4 最后排单位（槽位远→近兜底）——跨行兜底（保证单位总能选到目标）
	return _farthest_slot_unit(u, valid)


## 是否为指挥单位（platform_type==12，legacy COMMAND 平台值）
static func _is_command_unit(stats: UnitStats) -> bool:
	return stats != null and stats.platform_type == 12


## 是否为光环单位（与 construct_unit.gd 光环注册集合对齐，含指挥）
static func _is_aura_unit(stats: UnitStats) -> bool:
	return stats != null and stats.platform_type in AURA_PLATFORM_TYPES


## 单位 DPS：三维攻击取最大 / 攻击间隔（与敌方 best_dps 口径一致，防除零）
static func _unit_dps(stats: UnitStats) -> float:
	if stats == null:
		return 0.0
	var best_atk: float = maxf(stats.attack_light, maxf(stats.attack_armor, stats.attack_air))
	var interval: float = maxf(stats.attack_interval, 0.01)
	return best_atk / interval


## 候选列表中距离最近的有效单位（distance_squared_to 单遍扫描）
static func _nearest_of(origin: Vector2, candidates: Array) -> Node2D:
	var best: Node2D = null
	var best_d2: float = INF
	for c in candidates:
		if c == null or not is_instance_valid(c):
			continue
		var d2: float = origin.distance_squared_to((c as Node2D).global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = c
	return best


## DPS 最高的单位；DPS 在 5% 容差内并列时取距离最近
static func _highest_dps_unit(origin: Vector2, candidates: Array) -> Node2D:
	var best: Node2D = null
	var best_dps: float = -1.0
	var best_d2: float = INF
	const DPS_TOL: float = 0.05  # 5% 容差
	for c in candidates:
		if c == null or not is_instance_valid(c):
			continue
		var dps: float = _unit_dps(c.get("stats") as UnitStats)
		var d2: float = origin.distance_squared_to((c as Node2D).global_position)
		if best == null or dps > best_dps * (1.0 + DPS_TOL):
			# 明显更高 DPS，直接选
			best = c
			best_dps = dps
			best_d2 = d2
		elif absf(dps - best_dps) <= best_dps * DPS_TOL:
			# DPS 并列（容差内），取距离最近
			if d2 < best_d2:
				best = c
				best_dps = dps
				best_d2 = d2
	return best


## 最后排单位（槽位远→近，第一个存活单位）
## 3行×3列布局：按列（col = slot % 3）排序，
## 玩家方扫敌方 col=0（最左/离玩家最远）→ col=2；敌方方扫玩家 col=2（最右/离敌方最远）→ col=0
static func _farthest_slot_unit(u: CharacterBody2D, candidates: Array) -> Node2D:
	var slot_units: Dictionary = {}  # slot -> Array
	for n in candidates:
		var s: int = _get_unit_slot_index(n)
		if s < 0:
			continue
		if not slot_units.has(s):
			slot_units[s] = []
		(slot_units[s] as Array).append(n)
	if slot_units.is_empty():
		return null

	var slots: Array = slot_units.keys()
	## 按列（col = slot % SLOTS_PER_SIDE）排序：
	## 玩家打敌方：col=0（最左/最远）优先 → col=2（最近）
	## 敌方打玩家：col=2（最右/最远）优先 → col=0（最近）
	slots.sort_custom(func(a, b):
		var cola: int = int(a) % CardGridLayout.SLOTS_PER_SIDE
		var colb: int = int(b) % CardGridLayout.SLOTS_PER_SIDE
		if u.is_player:
			return cola < colb  # 敌方 col 0→2（远→近）
		return cola > colb  # 玩家 col 2→0（远→近）
	)

	for s in slots:
		## 列内可能有多个单位（3行布局下每列3个），取距离最近的存活单位
		## 避免按场景树迭代顺序任意选择（旧逻辑在三行下结果不确定）
		var col_units: Array = slot_units[s]
		if col_units.size() == 1:
			if is_instance_valid(col_units[0]):
				return col_units[0]
			continue
		var nearest_in_col: Node2D = _nearest_of(u.global_position, col_units)
		if nearest_in_col != null:
			return nearest_in_col
	return null

## 执行攻击（使用 stats 计算伤害）
static func do_attack(u: CharacterBody2D) -> void:
	if u.target == null or u.stats == null:
		# 无目标时直接用直射攻击值（兼容旧逻辑）
		do_attack_with_damage(u, u.stats.attack_light if u.stats else 0.0, GC.WeaponType.DIRECT)
		return

	var target_stats = u.target.get("stats") as UnitStats
	var target_kind: int = target_stats.combat_kind if target_stats else 0
	var distance: float = u.global_position.distance_to(u.target.global_position)

	# 尝试使用槽位系统
	var weapon = AttackCalculator.get_weapon_for_target(u.stats, target_kind)
	if weapon != null and weapon.enabled:
		# 检测格子战模式：防御由 CardGridDamage 处理，跳过防御减免避免双重计算
		var is_card_grid := is_card_grid_battle()
		var damage = AttackCalculator.calculate_damage_with_weapon(
			u.stats, target_stats,
			distance, weapon,
			u.stats.enhance_level, _get_mod_array(u.stats),
			is_card_grid,  # 格子战模式跳过防御减免
			is_card_grid   # 格子战模式射程衰减保底 30%（传统战场超射程仍在此处拦截）
		)
		# 射程检查（仅传统战场：格子战允许超射程继续攻击，伤害已由衰减函数处理）
		if not is_card_grid and weapon.weapon_type == GC.WeaponType.DIRECT:
			var max_range = AttackCalculator.get_weapon_range(weapon)
			if distance > max_range:
				CombatFeedback.show_miss(u.target.global_position, u.target)
				return
		do_attack_with_damage(u, damage, weapon.weapon_type, weapon.display_name, weapon, true)
		return

	# 回退：无武器资源时用裸 attack_damage。v10(C7)：预计算标记 true——格子战（唯一模式）
	# 防御由受击侧 take_damage→resolve_hit 统一结算，强化曲线只在武器路径应用一次。
	# 平衡修复（2026-08-16 克制链审查）：对空武器槽缺失/禁用（attack_air=0）时不得回退
	# attack_damage 打空中单位——否则任何步兵都能用步枪伤害飞机，防空特化失去意义。
	if target_kind == GC.CombatKind.AIR:
		return
	var damage: float = u.stats.attack_damage if u.stats else 0.0
	do_attack_with_damage(u, damage, u.stats.weapon_type if u.stats else 0, "", null, true)

## 获取武器发射起点（v16 起直射与曲射共用）：优先用 MuzzleAnchors 标注的枪口位置
## （fireX/fireY 独立二维；锚点表标注的语义本就是"弹道起始点"），
## 无标注时回退到 entity_top_y * 0.5（实体垂直中点）。
static func _get_direct_fire_spawn_pos(u: CharacterBody2D) -> Vector2:
	var unit_spr: Sprite2D = null
	if u.is_player:
		unit_spr = u.get_node_or_null("Sprite") as Sprite2D
	else:
		unit_spr = u.get_node_or_null("Sprite2D") as Sprite2D
	# v9.x: 我方单位优先用 PlayerMuzzleAnchors（按 card_id 直查，fireX 已按我方朝左图转换）
	# 敌方仍走 MuzzleAnchors（按 archetype_id，敌原图朝右）
	if u.is_player and u.stats != null:
		var pcid: String = String(u.stats.platform_card_id)
		if pcid.is_empty() and "card_id" in u.stats:
			pcid = String(u.stats.card_id)
		if not pcid.is_empty() and PlayerMuzzleAnchors.has_anchor(pcid):
			var pm_offset: Vector2 = PlayerMuzzleAnchors.get_fire_offset(pcid, unit_spr)
			if pm_offset != Vector2.ZERO:
				return u.global_position + pm_offset
	# 回退链：MuzzleAnchors（敌方 / 我方无专属标注时经 _visual_archetype_id 或 PLAYER_MIRROR 反查）
	var aid: String = ""
	if "_visual_archetype_id" in u:
		aid = String(u.get("_visual_archetype_id"))
	if aid.is_empty() and u.stats != null:
		# 我方卡按 platform_type 映射到 archetype
		var pt: int = int(u.stats.platform_type)
		if "PLAYER_MIRROR_ARCHETYPE_BY_PLATFORM" in u:
			aid = String(u.get("PLAYER_MIRROR_ARCHETYPE_BY_PLATFORM").get(pt, ""))
		# platform_card_id 直接作 archetype_id（部分单位同名）
		if aid.is_empty() and not u.stats.platform_card_id.is_empty():
			aid = u.stats.platform_card_id
	if not aid.is_empty():
		var muzzle_offset: Vector2 = MuzzleAnchors.get_fire_offset(aid, unit_spr)
		if muzzle_offset != Vector2.ZERO:
			return u.global_position + muzzle_offset
	# 回退：无标注，用实体垂直中点
	var offsetY: float = 0.0
	if unit_spr != null:
		offsetY = CardGridUnitVisuals.entity_top_y(unit_spr) * 0.5
	return u.global_position + Vector2.UP * offsetY

## 执行攻击（指定伤害值）
static func do_attack_with_damage(u: CharacterBody2D, damage: float, weapon_type_override: int = -1, weapon_name: String = "", weapon_resource: Variant = null, p_pre_calculated: bool = false) -> void:
	if u.is_deploy_ghost:
		return
	if u._hit_stun_left > 0.0:
		return
	if u.target == null or not is_instance_valid(u.target):
		return
	# v8.5: 电子屏蔽机制——被屏蔽单位攻击失效（_jammed_until 未过期则跳过本次攻击）
	# v10(C4) 统一：秒制时间戳
	if u.has_meta("_jammed_until"):
		if Time.get_ticks_msec() / 1000.0 < float(u.get_meta("_jammed_until", 0.0)):
			return  # 攻击失效（屏蔽持续期内）
	# v8.x: 首击加成检测（SNIPER 必爆 / STALKER ×1.5）
	# 通过临时 meta 传递给 bullet.gd 的暴击判定路径
	var _is_first_attack: bool = false
	if not u._has_made_first_attack:
		u._has_made_first_attack = true
		_is_first_attack = true
	# STALKER 首击伤害 ×1.5
	if _is_first_attack and u._is_stalker_unit:
		damage = damage * 1.5
	# SNIPER 首击必爆：设置临时 meta，bullet.gd 读取并强制暴击
	if _is_first_attack and u._is_sniper_unit:
		u.set_meta("_first_attack_force_crit", true)
	# v8.5: 瞄准狙击机制消费（_sniper_aim_ready 时本次攻击必暴+50%伤，对Boss×2）
	if u.get("_sniper_aim_ready") == true:
		u._sniper_aim_ready = false
		damage = damage * 1.5
		u.set_meta("_first_attack_force_crit", true)
		# 对 Boss/相位师额外 ×2（总 ×3）：检查目标 meta 或 stats
		if u.target != null and is_instance_valid(u.target):
			var _is_boss_t: bool = false
			if u.target.get("stats") != null and u.target.stats != null:
				_is_boss_t = bool(u.target.stats.get_meta("is_boss", false)) if u.target.stats.has_meta("is_boss") else false
			if not _is_boss_t and u.target.has_meta("is_phase_master"):
				_is_boss_t = true
			if _is_boss_t:
				damage = damage * 2.0
		# VFX：狙击开火信号
		if SignalBus.has_signal("mechanism_sniper_fired"):
			SignalBus.mechanism_sniper_fired.emit(u.global_position, u.target.global_position)
	# v8.5: 闪电穿插机制消费（_blitz_pierce_ready 时本次攻击穿透+2，挂 meta 给 bullet 读取）
	if u.get("_blitz_pierce_ready") == true:
		u._blitz_pierce_ready = false
		u.set_meta("_blitz_pierce_bonus", 2)
		# VFX：穿透开火信号
		if SignalBus.has_signal("mechanism_blitz_fired"):
			SignalBus.mechanism_blitz_fired.emit(u.global_position, u.target.global_position)
	var dist_t := u.global_position.distance_to(u.target.global_position)
	var miss := false
	# v7.x: wt 优先读当前槽位 weapon_resource.weapon_type（按目标类型差异化的弹道），
	# 让对装甲/对空槽的穿甲/导弹弹道真正参与路由判定与子弹 VFX。
	# 回退链：槽位 weapon_type → 单位级 stats.weapon_type → 0(DIRECT)
	var _slot_wt: int = -1
	if weapon_resource and weapon_resource is WeaponResource and weapon_resource.weapon_type >= 0:
		_slot_wt = int(weapon_resource.weapon_type)
	var wt: int = weapon_type_override if weapon_type_override >= 0 else (_slot_wt if _slot_wt >= 0 else (u.stats.weapon_type if u.stats else 0))

	# 射程检查：优先使用 WeaponResource 字段
	var range_val: float = 0.0
	if weapon_resource and weapon_resource is WeaponResource:
		range_val = AttackCalculator.get_weapon_range(weapon_resource)
	elif u.stats:
		range_val = u.stats.attack_range

	if range_val > 0 and dist_t > range_val:
		# v10(M1): 格子战（唯一模式）超射程不拦截，伤害由 range_falloff 衰减处理。
		# 原"传统战场直射 Miss 拦截"死分支随 is_card_grid_battle() 常量化移除
		# 旧逻辑：无武器资源时按 stats.attack_range 衰减
		if wt == GC.WeaponType.DIRECT or wt == -1:
			if wt == 0 and u.stats and u.stats.attack_range > 0.5 and dist_t > u.stats.attack_range:
				var sub_type: String = DamageAttenuation.infer_weapon_sub_type(
					u.stats.combat_kind, int(u.stats.attack_range / 100.0),
					u.stats.attack_light, u.stats.attack_armor, u.stats.attack_air
				)
				var max_range_grids: float = u.stats.attack_range / 100.0
				var dist_grids: float = dist_t / 100.0
				var att_mult: float = DamageAttenuation.calculate_attenuation(dist_grids, max_range_grids, sub_type)
				if att_mult <= 0.0:
					miss = true
					CombatFeedback.show_miss(u.target.global_position, u.target)
				else:
					damage *= att_mult
			elif wt != 0:
				# v9.2: range_falloff 改返回 float（p_hit==damage_mult，合并消除字典分配）
				var falloff: float = CombatTargeting.range_falloff(dist_t, u.stats.attack_range if u.stats else 120.0)
				if randf() > falloff:
					miss = true
					CombatFeedback.show_miss(u.target.global_position, u.target)
				else:
					damage *= falloff
	# v9.x: 直射武器跨行射击减伤（同行全额；曲射/空射全场全额，不受行约束）
	damage *= CardGridLayout.cross_row_direct_multiplier(u, u.target, wt)
	# 卡牌特殊能力：平台攻击修改
	if u._has_titan_mk2:
		damage *= CardAbilityManager.get_titan_mk2_damage_multiplier(u)
	if u._has_storm_rider:
		damage *= CardAbilityManager.get_storm_rider_damage_multiplier(u)
	var w_name: String = weapon_name
	if w_name.is_empty() and weapon_resource and weapon_resource is WeaponResource:
		w_name = weapon_resource.display_name if weapon_resource.display_name else ""
	# 开火反馈：炮口闪光 + Sprite 缩放脉冲（所有武器/所有战斗模式统一生效）
	# 修复传统战场零开火反馈——nudge 仅格子战播，此处无条件补
	# v17: 火花类别键经 WeaponVisualProfiles 统一解析（武器名优先+域感知兜底），
	# 替代 v16 的"朝向猜域"启发式——那靠 facing 反推枚举域，玩家侧朝左/敌方持新枚举
	# 值时都会归一错。解析真身见 data/weapon_visual_profiles.gd。
	_play_muzzle_feedback(u, wt, w_name, u.is_player)
	AttackPoseAnim.play(u, wt)

	# 获取武器射速（用于弹道路由决策）
	var weapon_speed: float = AttackCalculator.get_weapon_speed(u.stats, weapon_resource if weapon_resource is WeaponResource else null)

	# ── 弹道路由规则 ──
	# 曲射/空射 → 批处理（MultiMesh 抛物线弹道）
	# 直射 + 射速 > 2发/秒 → MultiMesh 批处理
	# 直射 + 射速 ≤ 2发/秒 → 独立子弹节点（对象池）

	# v8.4: 从 weapon_resource._mod_effects 读出 vfx_variant（武器类改造专属视觉）
	# 在路由判定前提取，曲射 batch / 独立 bullet 两条路径共用
	var _vfx_variant: String = ""
	if weapon_resource and weapon_resource is WeaponResource:
		_vfx_variant = String(weapon_resource._mod_effects.get("vfx_variant", ""))

	# 优先路由：曲射/空射武器（v6.6: 统一曲射判定）
	if GC.is_indirect_weapon_type(wt):
		# v16: 曲射发射点改用炮口锚点（与直射同源，锚点表本就标注"弹道起始点"）。
		# 原传 u.global_position（单位原点=脚底地面），炮口火在炮管而炮弹从脚下钻出，视觉脱节。
		var _indirect_spawn_pos := _get_direct_fire_spawn_pos(u)
		if u.is_player and BattleManager and is_instance_valid(BattleManager.player_indirect_batch):
			if BattleManager.player_indirect_batch.has_method("fire"):
				BattleManager.player_indirect_batch.fire(_indirect_spawn_pos, u.target, damage, wt, u, u.stats, miss, w_name, _vfx_variant)
				return
		elif not u.is_player and BattleManager and is_instance_valid(BattleManager.enemy_indirect_batch):
			if BattleManager.enemy_indirect_batch.has_method("fire"):
				BattleManager.enemy_indirect_batch.fire(_indirect_spawn_pos, u.target, damage, wt, u, u.stats, miss, w_name, _vfx_variant)
				return
		# 批处理不可用时回退到独立子弹

	# 高速直射 → 批处理（v8.x: 发射点改为头脚中点，不再从脚部发射）
	if wt == GC.WeaponType.DIRECT and weapon_speed > 2.0:
		var _fire_spawn_pos = _get_direct_fire_spawn_pos(u)
		var batch = BattleManager.player_projectile_batch if u.is_player else BattleManager.enemy_projectile_batch
		if batch and is_instance_valid(batch) and batch.has_method("fire"):
			# v16: 透传 weapon_name/vfx_variant——高速直射路径此前丢失武器名亚类命中配方
			# （机枪/坦克炮/步枪）与武器类改造专属视觉（集束/温压等）
			batch.fire(_fire_spawn_pos, u.target, damage, wt, u, u.stats, miss, w_name, _vfx_variant)
			return

	# 低速直射 或 曲射/空射回退 → 独立子弹节点（对象池）
	# 霰弹（weapon_type 5）：创建多枚子弹，每枚均分伤害并独立散布
	var pellet_n := GC.SHOTGUN_PELLET_COUNT if wt == 5 else 1
	var pellet_dmg := damage / float(pellet_n)
	var root_2d = u.get_parent().get_parent() if u.get_parent() else u
	var _fire_spawn_pos = _get_direct_fire_spawn_pos(u)

	for _p in range(pellet_n):
		var bullet: Node2D = ObjectPoolManager.get_object("bullets")
		if bullet == null:
			bullet = BulletScene.instantiate()
		bullet.global_position = _fire_spawn_pos
		# v7.x: 子弹 VFX 弹道类型优先用槽位 weapon_resource.weapon_type（按目标类型差异化），
		# 回退单位级 legacy_weapon_type（effects.weapon_type 改造保留的单位级默认），
		# 再回退到 wt（路由判定值）。
		var _vfx_wt: int = wt
		if _slot_wt >= 0:
			_vfx_wt = _slot_wt
		elif u.stats and u.stats.legacy_weapon_type > 0:
			_vfx_wt = u.stats.legacy_weapon_type
		bullet.setup(u.target, pellet_dmg, u.is_player, _vfx_wt, u, u.stats, miss, w_name, p_pre_calculated, _vfx_variant)
		var current_parent: Node = bullet.get_parent()
		if current_parent != root_2d:
			if current_parent != null:
				current_parent.remove_child(bullet)
			root_2d.add_child(bullet)

## 应用持续效果（回血等），由 _physics_process 调用
static func apply_continuous_effects(u: CharacterBody2D, delta: float) -> void:
	if u.stats == null:
		return
	# v7.x 修复：on_tick 承载多个每帧机制（hp_regen / 怒气过期 / 区域光环 / 相位护盾回复），
	# 此前用 hp_regen>0 守卫包住整个调用，导致未装回血改造的单位其他 on_tick 机制空转
	# （反坦克壕减速 / 指挥地堡光环 / 相位护盾回复 / 怒气过期检查）。
	# 现改为每帧无条件调用——on_tick 内部各分支自带早退守卫（字段<=0 即返回），
	# 无相关改造的单位每帧仅做几次字段比较即返回，无性能负担。
	ModuleEffectHandler.on_tick(u, delta)

## v5.0 攻速分离: 单武器三阶段攻击状态机
## v10(C4/H1/H3/H4): 攻速类 debuff 的统一 delta 缩放系数（1.0=正常，<1.0=变慢）。
## 合并四条通道（时间戳全局统一秒制，见 v10 C4）：
##   ① ECM/EMP（_ecm_debuffed_until + _ecm_attack_speed_penalty；boss 削弱/EMP 命中/ECM 光环/EMP 反射）
##   ② 势力 on_hit_debuff（_faction_aspd_debuff.remaining>0 时按 factor 缩放；remaining 由
##      FactionSkillEffectHandler.process_debuff_expirations 递减——敌我两侧都会 tick）
##   ③ 卡片周期技能攻速惩罚（_atk_speed_penalty_until/_mult，此前只写不读=死通道）
##   ④ 区域减速光环（_slow_aura_until/_mult——UI 一直显示"攻速降低"，本次按同语义接通）
## 敌我共用：enemy_unit._process_attack_timing 也调本函数。①③④过期时顺带清理 meta。
const ECM_DEFAULT_ATK_SPEED_PENALTY: float = 0.25  ## ECM 攻速削弱缺省值（写入端 construct_unit 同源引用）

static func get_attack_delta_scale(u: Node) -> float:
	if u == null:
		return 1.0
	var now: float = Time.get_ticks_msec() / 1000.0
	var mult: float = 1.0
	# ① ECM/EMP
	if u.has_meta("_ecm_debuffed_until"):
		if now < float(u.get_meta("_ecm_debuffed_until", 0.0)):
			var penalty: float = float(u.get_meta("_ecm_attack_speed_penalty", ECM_DEFAULT_ATK_SPEED_PENALTY))
			mult *= maxf(0.1, 1.0 - penalty)
		else:
			u.remove_meta("_ecm_debuffed_until")
			u.remove_meta("_ecm_attack_speed_penalty")
			u.remove_meta("_ecm_crit_penalty")
			u.remove_meta("_ecm_dodge_penalty")
	# ② 势力攻速 debuff
	if u.has_meta("_faction_aspd_debuff"):
		var d: Variant = u.get_meta("_faction_aspd_debuff")
		if d is Dictionary and float(d.get("remaining", 0.0)) > 0.0:
			mult *= clampf(float(d.get("factor", 1.0)), 0.1, 1.0)
	# ③ 卡片周期技能攻速惩罚
	if u.has_meta("_atk_speed_penalty_until"):
		if now < float(u.get_meta("_atk_speed_penalty_until", 0.0)):
			mult *= clampf(float(u.get_meta("_atk_speed_penalty_mult", 1.0)), 0.1, 1.0)
		else:
			u.remove_meta("_atk_speed_penalty_until")
			u.remove_meta("_atk_speed_penalty_mult")
	# ④ 区域减速光环
	if u.has_meta("_slow_aura_until"):
		if now < float(u.get_meta("_slow_aura_until", 0.0)):
			mult *= clampf(float(u.get_meta("_slow_aura_mult", 1.0)), 0.1, 1.0)
		else:
			u.remove_meta("_slow_aura_until")
			u.remove_meta("_slow_aura_mult")
	return clampf(mult, 0.1, 1.0)


# TODO(v10/M2): 单武器路径当前不可达——construct_unit.setup 恒给 _weapon_cfgs 至少 1 个占位项，
# process_attack 恒走多武器分支。保留作无武器单位的防御性回退；重构删除时需连 do_attack 一并评估。
static func _process_single_weapon_attack(u: CharacterBody2D, delta: float) -> void:
	if u.target == null or not is_instance_valid(u.target):
		u._attack_phase = u.AttackPhase.IDLE
		u._attack_phase_timer = 0.0
		return
	# v8.6: ECM debuff（boss 削弱技能/电子战）——被削弱时攻速降低，计时累加变慢。
	# 修复：此前玩家侧零消费方，boss _exec_debuff_players 给玩家挂的 meta 完全空转。
	delta = delta * get_attack_delta_scale(u)
	var target_stats = u.target.get("stats") as UnitStats
	var target_kind: int = target_stats.combat_kind if target_stats else 0

	# v6.0: 从武器槽位获取武器并计算 timing
	# v9.2: 单武器路径加 target 缓存（与多武器路径 cached_timing、enemy_unit._cached_target_ref 同范式）。
	# 原每帧每单位调 get_weapon_attack_timing（new Dictionary）+ get_weapon_range（has_method 反射），
	# 现仅在目标变化时重算，timing/range/wt 缓存复用。
	var timing: Dictionary
	var fire_range: float
	var wt: int
	# 失效条件：目标变化，或首次进入（缓存为空）
	var need_recompute: bool = (u.target != u._cached_single_target_ref) or u._cached_single_timing.is_empty()
	if need_recompute:
		# 目标变了（或首次）→ 重算并更新缓存
		u._cached_single_target_ref = u.target
		var weapon = AttackCalculator.get_weapon_for_target(u.stats, target_kind)
		if weapon and weapon.enabled:
			u._cached_single_timing = AttackCalculator.get_weapon_attack_timing(weapon)
			u._cached_single_fire_range = AttackCalculator.get_weapon_range(weapon)
			u._cached_single_wt = weapon.weapon_type
		else:
			u._cached_single_timing = AttackCalculator.get_attack_timing(u.stats, target_kind)
			u._cached_single_fire_range = u.stats.attack_range if u.stats else 120.0
			u._cached_single_wt = u.stats.weapon_type if u.stats else 0
		u.set("attack_interval", u._cached_single_timing["cycle"])
	timing = u._cached_single_timing
	fire_range = u._cached_single_fire_range
	wt = u._cached_single_wt
	# 保持与原行为一致：每帧同步 attack_interval（set 已存在属性是廉价操作，比 new Dictionary 便宜）
	u.set("attack_interval", timing["cycle"])

	var dist: float = u.global_position.distance_to(u.target.global_position)
	var is_card_grid_active: bool = is_card_grid_battle()
	# v6.4 修复：格子战时攻击射程与索敌判定一致（×2.6），避免双方固定两端时射程不足永不攻击
	if is_card_grid_active:
		fire_range *= CombatTargeting.CARD_GRID_RANGE_MULT
	# 格子战：超射程不拦截（伤害由 calculate_damage_with_weapon 的 range_falloff 保底 30% 衰减）
	# 传统战场：直射超射程仍重置 IDLE
	if not is_card_grid_active and dist > fire_range and wt == GC.WeaponType.DIRECT:
		u._attack_phase = u.AttackPhase.IDLE
		u._attack_phase_timer = 0.0
		return
	match u._attack_phase:
		u.AttackPhase.IDLE:
			# 格子战：有目标即进入 WINDUP；传统战场：需在射程内
			if is_card_grid_active or dist <= fire_range:
				u._attack_phase = u.AttackPhase.WINDUP
				u._attack_phase_timer = 0.0
		u.AttackPhase.WINDUP:
			u._attack_phase_timer += delta
			if u._attack_phase_timer >= timing["windup"]:
				u._attack_phase = u.AttackPhase.ACTIVE
				u._attack_phase_timer = 0.0
		u.AttackPhase.ACTIVE:
			u._attack_phase_timer += delta
			if u._attack_phase_timer < delta * 1.1:
				do_attack(u)
			if u._attack_phase_timer >= timing["active"]:
				u._attack_phase = u.AttackPhase.COOLDOWN
				u._attack_phase_timer = 0.0
		u.AttackPhase.COOLDOWN:
			u._attack_phase_timer += delta
			if u._attack_phase_timer >= timing["cooldown"]:
				u._attack_phase = u.AttackPhase.IDLE
				u._attack_phase_timer = 0.0

## 多武器三阶段攻击状态机
static func _process_multi_weapons(u: CharacterBody2D, delta: float) -> void:
	if u.is_deploy_ghost or u.is_preview_mode:
		return
	if u.stats != null and u.stats.platform_type == 12:
		return
	if u._hit_stun_left > 0.0:
		return
	if u.target == null or not is_instance_valid(u.target):
		for w in u._weapon_cfgs:
			w["phase"] = u.AttackPhase.IDLE
			w["phase_timer"] = 0.0
		return
	# v8.6: ECM debuff 攻速降低（同单武器路径）
	delta = delta * get_attack_delta_scale(u)
	var target_stats = u.target.get("stats") as UnitStats
	var target_kind: int = target_stats.combat_kind if target_stats else 0
	var eff_rng: float = effective_fire_range(u)
	var is_card_grid_multi: bool = is_card_grid_battle()
	for i in range(u._weapon_cfgs.size()):
		var w = u._weapon_cfgs[i]
		var phase: int = int(w.get("phase", u.AttackPhase.IDLE))
		var phase_timer: float = float(w.get("phase_timer", 0.0))

		# v6.1 FIX: 统一从武器槽位获取 weapon_type / timing / range
		# v7.3 性能优化：timing/range/wt 缓存到 w 字典，武器引用不变时复用，避免每帧每武器
		# 调 get_weapon_attack_timing（新建Dictionary）+ get_weapon_range（has_method 反射）。
		# 20单位×2武器 = 每帧~40次字典分配+反射 → 改为武器变化时才算一次。
		var timing: Dictionary
		var w_range: float
		var w_weapon: WeaponResource
		var w_wt: int = GC.WeaponType.DIRECT
		var need_recompute: bool = true
		if i < u.stats.weapon_slots.size():
			w_weapon = u.stats.weapon_slots[i] as WeaponResource
			if w_weapon and w_weapon.enabled:
				# 检查武器引用是否变化（同一对象则复用缓存）
				# v10(M5): 复用条件加攻速比对——攻速类效果改写 weapon.attack_speed 后缓存必须失效
				if w.get("cached_weapon_ref", null) == w_weapon \
						and absf(float(w.get("cached_speed", -1.0)) - float(w_weapon.attack_speed)) < 0.0001:
					timing = w.get("cached_timing", {})
					w_range = float(w.get("cached_range", 0.0))
					w_wt = int(w.get("cached_wt", GC.WeaponType.DIRECT))
					if not timing.is_empty():
						need_recompute = false
				if need_recompute:
					timing = AttackCalculator.get_weapon_attack_timing(w_weapon)
					w_range = AttackCalculator.get_weapon_range(w_weapon)
					w_wt = w_weapon.weapon_type
					w["cached_weapon_ref"] = w_weapon
					w["cached_timing"] = timing
					w["cached_range"] = w_range
					w["cached_wt"] = w_wt
					w["cached_speed"] = float(w_weapon.attack_speed)
			else:
				timing = AttackCalculator.get_attack_timing(u.stats, target_kind)
				w_range = u.stats.attack_range
		else:
			timing = AttackCalculator.get_attack_timing(u.stats, target_kind)
			w_range = u.stats.attack_range

		# 曲射/空射武器最小攻击间隔限制（v6.6: 统一曲射判定）
		if GC.is_indirect_weapon_type(w_wt):
			timing["windup"] = maxf(timing.get("windup", 0.0), 0.15)
			timing["cooldown"] = maxf(timing.get("cooldown", 0.0), 0.25)

		var dist: float = u.global_position.distance_to(u.target.global_position)
		# v6.4 修复：格子战时多武器攻击射程同步×2.6（与索敌判定一致）
		if is_card_grid_multi:
			w_range *= CombatTargeting.CARD_GRID_RANGE_MULT
		# 格子战：超射程不拦截（伤害由 calculate_damage_with_weapon 的 range_falloff 保底 30%）
		# 传统战场：直射超射程仍重置 IDLE
		if not is_card_grid_multi and dist > w_range and w_wt == GC.WeaponType.DIRECT:
			phase = u.AttackPhase.IDLE
			phase_timer = 0.0
		match phase:
			u.AttackPhase.IDLE:
				# 格子战：有目标即进入 WINDUP；传统战场：需在有效射程内
				if is_card_grid_multi or dist <= eff_rng:
					phase = u.AttackPhase.WINDUP
					phase_timer = 0.0
			u.AttackPhase.WINDUP:
				phase_timer += delta
				if phase_timer >= timing["windup"]:
					phase = u.AttackPhase.ACTIVE
					phase_timer = 0.0
			u.AttackPhase.ACTIVE:
				phase_timer += delta
				if phase_timer < delta * 1.1:
					# v6.1 FIX: 伤害从 weapon_slots[i] 的 WeaponResource 重算
					# 原 _weapon_cfgs["damage"] 对无 multi_weapons 的卡为占位 0 → 不掉血
					var dmg: float = 0.0
					var w_name: String = ""
					if w_weapon and w_weapon is WeaponResource and w_weapon.enabled:
						w_name = w_weapon.display_name if w_weapon.display_name else ""
						var is_card_grid: bool = is_card_grid_battle()
						dmg = AttackCalculator.calculate_damage_with_weapon(
							u.stats, target_stats, dist, w_weapon,
							u.stats.enhance_level, _get_mod_array(u.stats),
							is_card_grid,
							is_card_grid
						)
					else:
						# 平衡修复（2026-08-16 克制链审查）：武器槽禁用时若目标是空中单位
						# （对空槽 damage=0），不得回退裸 attack_damage 开火——无防空不能打飞机。
						if target_kind == GC.CombatKind.AIR:
							w["phase"] = u.AttackPhase.COOLDOWN
							w["phase_timer"] = 0.0
							continue
						dmg = u.stats.attack_damage if u.stats else 0.0
					# v10(C6/C7): dmg 已含 calculate_damage_with_weapon 的强化曲线 → 必须标记预计算，
					# 否则 bullet/indirect batch 再乘一遍 0.05 旧曲线（强化双乘）+ bullet 再乘防御（双曲线）
					do_attack_with_damage(u, dmg, w_wt, w_name, w_weapon, true)
				if phase_timer >= timing["active"]:
					phase = u.AttackPhase.COOLDOWN
					phase_timer = 0.0
			u.AttackPhase.COOLDOWN:
				phase_timer += delta
				if phase_timer >= timing["cooldown"]:
					phase = u.AttackPhase.IDLE
					phase_timer = 0.0
		w["phase"] = phase
		w["phase_timer"] = phase_timer

## ===== 辅助函数 =====

static func acquisition_range(u: CharacterBody2D) -> float:
	if u.stats == null:
		return 120.0
	var combat_started: bool = is_card_grid_battle()
	if not u.is_player:
		return CombatTargeting.card_grid_enemy_acquisition_range(u.stats.attack_range, combat_started)
	var r: float = u.stats.attack_range
	if combat_started:
		r *= CombatTargeting.CARD_GRID_RANGE_MULT
	# v6.2: 玩家单位格子战索敌范围保底（与敌方对称），确保后排短射程单位也能索到战场另一端
	if combat_started:
		r = maxf(r, CombatTargeting.CARD_GRID_PLAYER_ACQUISITION_MIN)
	return r

static func effective_fire_range(u: CharacterBody2D) -> float:
	if u.stats == null:
		return 120.0
	var rng: float = u.stats.attack_range
	if is_card_grid_battle():
		rng *= CombatTargeting.CARD_GRID_RANGE_MULT
	if u.target != null and is_instance_valid(u.target) and CombatTargeting.is_phase_field_node(u.target):
		if targeting_opponent_phase_field_only(u):
			return maxf(rng, acquisition_range(u) * 1.5)
	return rng

static func targeting_opponent_phase_field_only(u: CharacterBody2D) -> bool:
	if u.is_player:
		return not CombatTargeting.has_alive_enemy_units(BattleManager)
	return not CombatTargeting.has_alive_player_units(BattleManager)

static func should_retain_current_target(u: CharacterBody2D) -> bool:
	if u.target == null or not is_instance_valid(u.target):
		return false
	if CombatTargeting.should_drop_phase_field_target(u.target, u.is_player, BattleManager):
		return false
	if CombatTargeting.is_phase_field_node(u.target):
		return targeting_opponent_phase_field_only(u)
	var d: float = u.global_position.distance_to(u.target.global_position)
	return d <= acquisition_range(u)

## 格子战术卡面攻击姿态（v9.x 由 AttackPoseAnim 取代——按武器类型分化前冲/后坐/上扬 + 攻击帧）

## 开火反馈：炮口闪光（池化 CPUParticles2D）+ Sprite 缩放脉冲。
## 所有武器类型、所有战斗模式统一生效——修复传统战场零开火反馈。
## 调用方：玩家 do_attack_with_damage 顶部（弹道路由前，霰弹只触发一次）。
## 敌方 enemy_unit._do_attack 也调用本静态方法（复用同一套逻辑）。
## v17: 火花类别键 = 当前开火武器（多武器单位槽位武器与单位级默认不同时，火花形态
## 跟武器走），经 WeaponVisualProfiles.resolve_visual_wt 统一解析——武器名优先，
## 域感知兜底（我方新枚举 1/2=曲射/空射保持重型；敌方 legacy 1/2=步枪/机枪归一轻档）。
## 缺省 firing_wt=-1 回退单位级 stats.weapon_type。
static func _play_muzzle_feedback(u: Node2D, firing_wt: int = -1, weapon_name: String = "", shooter_is_player: bool = true) -> void:
	if u == null or not is_instance_valid(u):
		return
	var facing_right: bool = bool(u.get("is_player"))
	# v9.2: 枪口火位置对齐弹道起点——优先用 MuzzleAnchors（与 _get_direct_fire_spawn_pos 同源），
	# 无标注时回退 entity_top_y * 0.5。
	var muzzle_offset: Vector2 = Vector2.ZERO
	var unit_spr: Sprite2D = null
	if u.get("is_player"):
		unit_spr = u.get_node_or_null("Sprite") as Sprite2D
	else:
		unit_spr = u.get_node_or_null("Sprite2D") as Sprite2D
	# 取 archetype_id（敌方裸字段 / 我方 _visual_archetype_id 或 platform 映射）
	# v9.x: 我方单位优先用 PlayerMuzzleAnchors（按 card_id 直查，fireX 已按我方朝左图转换）
	var is_player_unit: bool = bool(u.get("is_player"))
	if is_player_unit and u.get("stats") != null:
		var st_p = u.get("stats")
		var pcid: String = String(st_p.platform_card_id) if "platform_card_id" in st_p else ""
		if pcid.is_empty() and "card_id" in st_p:
			pcid = String(st_p.card_id)
		if not pcid.is_empty() and PlayerMuzzleAnchors.has_anchor(pcid):
			muzzle_offset = PlayerMuzzleAnchors.get_fire_offset(pcid, unit_spr)
	# 我方未命中 或 敌方：走 MuzzleAnchors
	if muzzle_offset == Vector2.ZERO:
		var aid: String = ""
		if "archetype_id" in u:
			aid = String(u.get("archetype_id"))
		if aid.is_empty() and "_visual_archetype_id" in u:
			aid = String(u.get("_visual_archetype_id"))
		if aid.is_empty() and u.get("stats") != null:
			var st = u.get("stats")
			if st != null and "platform_card_id" in st:
				aid = String(st.platform_card_id)
		if not aid.is_empty():
			muzzle_offset = MuzzleAnchors.get_fire_offset(aid, unit_spr)
	if muzzle_offset == Vector2.ZERO:
		# 回退：实体垂直中点
		var fallback_y: float = 0.0
		if unit_spr != null:
			fallback_y = CardGridUnitVisuals.entity_top_y(unit_spr) * 0.5
		muzzle_offset = Vector2(0.0, -fallback_y)
	# v17: 火花类别键——WeaponVisualProfiles 统一解析（武器名优先，域感知兜底）。
	# 替代 v16 的"朝向猜域"（not facing_right 才归一）——朝向不是枚举域的数据事实。
	var flash_wt: int = firing_wt
	if flash_wt < 0:
		var _st = u.get("stats")
		flash_wt = int(_st.weapon_type) if _st != null else 0
	flash_wt = WeaponVisuals.resolve_visual_wt(weapon_name, flash_wt, shooter_is_player)
	VfxImpactFactory.spawn_muzzle_flash(u, muzzle_offset, facing_right, flash_wt)
	# 开火缩放脉冲：交给单位实例方法处理（避开根 scale.x 翻转，只动 Sprite 子节点）
	# reduce motion 时跳过脉冲（保留炮口火——静态闪烁非抖动）
	var reduce_motion: bool = false
	if DT != null:
		reduce_motion = DT.is_motion_reduce()
	if reduce_motion:
		return
	if u.has_method("_play_fire_scale_pulse"):
		u._play_fire_scale_pulse()

## v6.4: 改造伤害加成已由 ModificationRegistry.apply_with_level 在 UnitStats 构建阶段
## 直接叠加到 attack_light/armor/air。此函数保留仅为兼容 AttackCalculator 的旧参数签名，
## 始终返回空数组（改造效果已在 stats 数值中体现，无需在此重复乘倍率）。
static func _get_mod_array(_stats: Variant) -> Array:
	return []
