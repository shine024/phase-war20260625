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
static func get_target_find_interval(u: CharacterBody2D) -> float:
	var n: int = 0
	if BattleManager and BattleManager.has_method("get_enemy_unit_count"):
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

	# 卡牌网格战斗：使用槽位系统快速查找
	if GameManager and GameManager.is_card_grid_battle():
		var slot_target = _find_target_by_card_grid(u, targeting_mode)
		if slot_target != null:
			u.target = slot_target
			return

	# 传统战场：使用空间分区系统
	if BattleManager and BattleManager.spatial_grid:
		var spatial_grid = BattleManager.spatial_grid
		if spatial_grid:
			# 限制查询范围，避免过大范围导致性能问题
			var max_range: float = mini(acquisition_range(u), 250.0)
			var nearest_target = spatial_grid.query_nearest_target_with_mode(
				u.global_position,
				u.is_player,
				max_range,
				targeting_mode
			)
			if nearest_target != null:
				u.target = nearest_target
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
	var is_indirect: bool = false
	if u.stats != null:
		if u.stats.weapon_type in [GC.WeaponType.INDIRECT, GC.WeaponType.AERIAL]:
			is_indirect = true
		else:
			for _ws in u.stats.weapon_slots:
				if _ws is WeaponResource and _ws.enabled and _ws.weapon_type in [GC.WeaponType.INDIRECT, GC.WeaponType.AERIAL]:
					is_indirect = true
					break
	if is_indirect:
		return _scan_slot_targets(u, gr)

	# 直射：射程内距离筛选 + select_target
	var origin: Vector2 = u.global_position
	var acq_range: float = acquisition_range(u)
	var acq_range_sq: float = acq_range * acq_range
	var candidates: Array = []
	for n in gr:
		if not CombatTargeting.is_attackable_combat_unit(n):
			continue
		var n2d: Node2D = n as Node2D
		if origin.distance_squared_to(n2d.global_position) <= acq_range_sq:
			candidates.append(n)
	if candidates.is_empty():
		return null
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


## 槽位编号扫描索敌（曲射/空射用）
## 布局：玩家7槽(左带, slot0最左→slot6靠中线) | 中间空带 | 敌方7槽(右带, slot0靠中线→slot6最右)
## 玩家方扫敌方 slot 6→0（远→近）；敌方方扫玩家 slot 0→6（远→近）
## 第一个有存活单位的槽位即目标（纯顺序，不考虑克制）
static func _scan_slot_targets(u: CharacterBody2D, gr: Array) -> Node2D:
	var slot_units: Dictionary = {}  # slot -> Array
	for n in gr:
		if not CombatTargeting.is_attackable_combat_unit(n):
			continue
		var s: int = _get_unit_slot_index(n)
		if s < 0:
			continue
		if not slot_units.has(s):
			slot_units[s] = []
		(slot_units[s] as Array).append(n)
	if slot_units.is_empty():
		return null

	var slots: Array = slot_units.keys()
	if u.is_player:
		slots.sort_custom(func(a, b): return int(a) > int(b))  # 敌方 slot 6→0（远→近）
	else:
		slots.sort()  # 玩家 slot 0→6（远→近）

	for s in slots:
		for unit in slot_units[s]:
			if is_instance_valid(unit):
				print("[ScanSlot] ", u.name, " slot=", _get_unit_slot_index(u), " wt=", (u.stats.weapon_type if u.stats != null else -1), " → 敌slot=", s, " target=", unit.name)
				return unit
	print("[ScanSlot] ", u.name, " 无目标(空槽) slots=", slots)
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
		var is_card_grid = GameManager and GameManager.has_method("is_card_grid_battle") and GameManager.is_card_grid_battle()
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

	# 回退：用攻击值获取攻击值（配对防御）
	var damage: float = u.stats.attack_damage if u.stats else 0.0
	do_attack_with_damage(u, damage, u.stats.weapon_type if u.stats else 0, "")

## 执行攻击（指定伤害值）
static func do_attack_with_damage(u: CharacterBody2D, damage: float, weapon_type_override: int = -1, weapon_name: String = "", weapon_resource: Variant = null, p_pre_calculated: bool = false) -> void:
	if u.is_deploy_ghost:
		return
	if u._hit_stun_left > 0.0:
		return
	if u.target == null or not is_instance_valid(u.target):
		return
	var dist_t := u.global_position.distance_to(u.target.global_position)
	var miss := false
	var wt: int = weapon_type_override if weapon_type_override >= 0 else (u.stats.weapon_type if u.stats else 0)

	# 射程检查：优先使用 WeaponResource 字段
	var range_val: float = 0.0
	if weapon_resource and weapon_resource is WeaponResource:
		range_val = AttackCalculator.get_weapon_range(weapon_resource)
	elif u.stats:
		range_val = u.stats.attack_range

	if range_val > 0 and dist_t > range_val:
		# 格子战：允许超射程继续攻击，伤害由 calculate_damage_with_weapon 的 range_falloff 衰减处理
		var _is_card_grid_here: bool = GameManager != null and GameManager.has_method("is_card_grid_battle") and GameManager.is_card_grid_battle()
		if _is_card_grid_here:
			pass  # 不拦截，继续发射（伤害在 do_attack/do_attack_with_multiple_weapons 阶段已含衰减）
		# 武器资源射程超限：直接 Miss（不依赖旧 stats.attack_range 判断）
		elif weapon_resource and weapon_resource is WeaponResource:
			CombatFeedback.show_miss(u.target.global_position, u.target)
			return
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
				var falloff: Dictionary = CombatTargeting.range_falloff(dist_t, u.stats.attack_range if u.stats else 120.0)
				if randf() > float(falloff.get("p_hit", 1.0)):
					miss = true
					CombatFeedback.show_miss(u.target.global_position, u.target)
				else:
					damage *= float(falloff.get("damage_mult", 1.0))
	# 卡牌特殊能力：平台攻击修改
	if u._has_titan_mk2:
		damage *= CardAbilityManager.get_titan_mk2_damage_multiplier(u)
	if u._has_storm_rider:
		damage *= CardAbilityManager.get_storm_rider_damage_multiplier(u)
	if u._presentation_card_grid:
		_play_card_attack_nudge(u)
	var w_name: String = weapon_name
	if w_name.is_empty() and weapon_resource and weapon_resource is WeaponResource:
		w_name = weapon_resource.display_name if weapon_resource.display_name else ""

	# 获取武器射速（用于弹道路由决策）
	var weapon_speed: float = AttackCalculator.get_weapon_speed(u.stats, weapon_resource if weapon_resource is WeaponResource else null)

	# ── 弹道路由规则 ──
	# 曲射/空射 → 批处理（MultiMesh 抛物线弹道）
	# 直射 + 射速 > 2发/秒 → MultiMesh 批处理
	# 直射 + 射速 ≤ 2发/秒 → 独立子弹节点（对象池）

	# 优先路由：曲射/空射武器
	if wt in [GC.WeaponType.INDIRECT, GC.WeaponType.AERIAL]:
		if u.is_player and BattleManager and is_instance_valid(BattleManager.player_indirect_batch):
			if BattleManager.player_indirect_batch.has_method("fire"):
				BattleManager.player_indirect_batch.fire(u.global_position, u.target, damage, wt, u, u.stats, miss, w_name)
				return
		elif not u.is_player and BattleManager and is_instance_valid(BattleManager.enemy_indirect_batch):
			if BattleManager.enemy_indirect_batch.has_method("fire"):
				BattleManager.enemy_indirect_batch.fire(u.global_position, u.target, damage, wt, u, u.stats, miss, w_name)
				return
		# 批处理不可用时回退到独立子弹

	# 高速直射 → 批处理
	if wt == GC.WeaponType.DIRECT and weapon_speed > 2.0:
		var batch = BattleManager.player_projectile_batch if u.is_player else BattleManager.enemy_projectile_batch
		if batch and is_instance_valid(batch) and batch.has_method("fire"):
			batch.fire(u.global_position, u.target, damage, wt, u, u.stats, miss)
			return

	# 低速直射 或 曲射/空射回退 → 独立子弹节点（对象池）
	# 霰弹（weapon_type 5）：创建多枚子弹，每枚均分伤害并独立散布
	var pellet_n := 6 if wt == 5 else 1
	var pellet_dmg := damage / float(pellet_n)
	var root_2d = u.get_parent().get_parent() if u.get_parent() else u

	for _p in range(pellet_n):
		var bullet: Node2D = ObjectPoolManager.get_object("bullets")
		if bullet == null:
			bullet = BulletScene.instantiate()
		bullet.global_position = u.global_position
		bullet.setup(u.target, pellet_dmg, u.is_player, wt, u, u.stats, miss, w_name, p_pre_calculated)
		var current_parent: Node = bullet.get_parent()
		if current_parent != root_2d:
			if current_parent != null:
				current_parent.remove_child(bullet)
			root_2d.add_child(bullet)

## 应用持续效果（回血等），由 _physics_process 调用
static func apply_continuous_effects(u: CharacterBody2D, delta: float) -> void:
	if u.stats == null:
		return
	# 应用回血效果（纳米自愈词条）
	if u.stats.hp_regen > 0.0:
		ModuleEffectHandler.on_tick(u, delta)

## v5.0 攻速分离: 单武器三阶段攻击状态机
static func _process_single_weapon_attack(u: CharacterBody2D, delta: float) -> void:
	if u.target == null or not is_instance_valid(u.target):
		u._attack_phase = u.AttackPhase.IDLE
		u._attack_phase_timer = 0.0
		return
	var target_stats = u.target.get("stats") as UnitStats
	var target_kind: int = target_stats.combat_kind if target_stats else 0

	# v6.0: 从武器槽位获取武器并计算 timing
	var weapon = AttackCalculator.get_weapon_for_target(u.stats, target_kind)
	var timing: Dictionary
	var fire_range: float
	var wt: int
	if weapon and weapon.enabled:
		timing = AttackCalculator.get_weapon_attack_timing(weapon)
		fire_range = AttackCalculator.get_weapon_range(weapon)
		wt = weapon.weapon_type
		u.set("attack_interval", timing["cycle"])
	else:
		timing = AttackCalculator.get_attack_timing(u.stats, target_kind)
		fire_range = u.stats.attack_range if u.stats else 120.0
		wt = u.stats.weapon_type if u.stats else 0

	var dist: float = u.global_position.distance_to(u.target.global_position)
	var is_card_grid_active: bool = (
		GameManager
		and GameManager.is_card_grid_battle()
		and BattleManager != null
		and BattleManager.has_method("is_card_grid_combat_started")
		and BattleManager.is_card_grid_combat_started()
	)
	# v6.4 修复：格子战时攻击射程与索敌判定一致（×2.6），避免双方固定两端时射程不足永不攻击
	if is_card_grid_active:
		fire_range *= 2.6
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
	var target_stats = u.target.get("stats") as UnitStats
	var target_kind: int = target_stats.combat_kind if target_stats else 0
	var eff_rng: float = effective_fire_range(u)
	var is_card_grid_multi: bool = (
		GameManager
		and GameManager.is_card_grid_battle()
		and BattleManager != null
		and BattleManager.has_method("is_card_grid_combat_started")
		and BattleManager.is_card_grid_combat_started()
	)
	for i in range(u._weapon_cfgs.size()):
		var w = u._weapon_cfgs[i]
		var phase: int = int(w.get("phase", u.AttackPhase.IDLE))
		var phase_timer: float = float(w.get("phase_timer", 0.0))

		# v6.1 FIX: 统一从武器槽位获取 weapon_type / timing / range
		var timing: Dictionary
		var w_range: float
		var w_weapon: WeaponResource
		var w_wt: int = GC.WeaponType.DIRECT
		if i < u.stats.weapon_slots.size():
			w_weapon = u.stats.weapon_slots[i] as WeaponResource
			if w_weapon and w_weapon.enabled:
				timing = AttackCalculator.get_weapon_attack_timing(w_weapon)
				w_range = AttackCalculator.get_weapon_range(w_weapon)
				w_wt = w_weapon.weapon_type
			else:
				timing = AttackCalculator.get_attack_timing(u.stats, target_kind)
				w_range = u.stats.attack_range
		else:
			timing = AttackCalculator.get_attack_timing(u.stats, target_kind)
			w_range = u.stats.attack_range

		# 曲射/空射武器最小攻击间隔限制
		if w_wt in [GC.WeaponType.INDIRECT, GC.WeaponType.AERIAL]:
			timing["windup"] = maxf(timing.get("windup", 0.0), 0.15)
			timing["cooldown"] = maxf(timing.get("cooldown", 0.0), 0.25)

		var dist: float = u.global_position.distance_to(u.target.global_position)
		# v6.4 修复：格子战时多武器攻击射程同步×2.6（与索敌判定一致）
		if is_card_grid_multi:
			w_range *= 2.6
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
						var is_card_grid: bool = GameManager and GameManager.has_method("is_card_grid_battle") and GameManager.is_card_grid_battle()
						dmg = AttackCalculator.calculate_damage_with_weapon(
							u.stats, target_stats, dist, w_weapon,
							u.stats.enhance_level, _get_mod_array(u.stats),
							is_card_grid,
							is_card_grid
						)
					else:
						dmg = u.stats.attack_damage if u.stats else 0.0
					do_attack_with_damage(u, dmg, w_wt, w_name, w_weapon)
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
	var combat_started: bool = (
		GameManager
		and GameManager.is_card_grid_battle()
		and BattleManager != null
		and BattleManager.has_method("is_card_grid_combat_started")
		and BattleManager.is_card_grid_combat_started()
	)
	if not u.is_player and GameManager and GameManager.is_card_grid_battle():
		return CombatTargeting.card_grid_enemy_acquisition_range(u.stats.attack_range, combat_started)
	var r: float = u.stats.attack_range
	if combat_started:
		r *= 2.6
	return r

static func effective_fire_range(u: CharacterBody2D) -> float:
	if u.stats == null:
		return 120.0
	var rng: float = u.stats.attack_range
	if (
		GameManager
		and GameManager.is_card_grid_battle()
		and BattleManager != null
		and BattleManager.has_method("is_card_grid_combat_started")
		and BattleManager.is_card_grid_combat_started()
	):
		rng *= 2.6
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

## 格子战术卡面攻击前推动画
static func _play_card_attack_nudge(u: CharacterBody2D) -> void:
	if not u._presentation_card_grid:
		return
	if is_nan(u._card_grid_rest_x):
		u._card_grid_rest_x = u.position.x
	if u._card_nudge_tween != null and u._card_nudge_tween.is_valid():
		u._card_nudge_tween.kill()
		u.position.x = u._card_grid_rest_x
	u._card_nudge_tween = u.create_tween()
	var dir: float = 1.0 if u.is_player else -1.0
	var rest_x: float = u._card_grid_rest_x
	u._card_nudge_tween.tween_property(u, "position:x", rest_x + dir * 22.0, 0.07)
	u._card_nudge_tween.tween_property(u, "position:x", rest_x, 0.09)

## v6.4: 改造伤害加成已由 ModificationRegistry.apply_with_level 在 UnitStats 构建阶段
## 直接叠加到 attack_light/armor/air。此函数保留仅为兼容 AttackCalculator 的旧参数签名，
## 始终返回空数组（改造效果已在 stats 数值中体现，无需在此重复乘倍率）。
static func _get_mod_array(_stats: Variant) -> Array:
	return []
