class_name ModuleEffectHandler
extends RefCounted
## v6.0 统一条词效果处理器（替代旧 AffixCombatHandler）
## 在战斗中按触发点调用。
##
## 触发点：
##   - on_bullet_hit()    — 弹道命中时：暴击、穿甲、闪避、吸血、溅射、闪电链（@deprecated v7.5）
##   - apply_on_hit_side_effects() — 命中副作用：吸血/连锁/溅射/combo（活跃路径）
##   - on_kill()           — 击杀时：护盾
##   - on_tick()           — 持续：HP回复
##   - on_damage_taken()   — 受击时：怒气积累、反击标记、反伤（v7.x 新增活跃路径）

const GC = preload("res://resources/game_constants.gd")

# ─────────────────────────────────────────────
#  弹道命中处理
# ─────────────────────────────────────────────

## 弹道命中时综合处理
## 返回最终伤害值（0 表示被闪避）
##
## @deprecated v7.5: 本方法全项目零调用方（实际命中走 apply_on_hit_side_effects，
## 暴击/穿甲在 bullet.gd 计算，减伤/闪避在 take_damage→CardGridDamage.resolve_hit 计算）。
## 内部 _apply_target_reduction / _check_dodge 是 damage_reduction/dodge 的旧消费点，
## v7.5 起 damage_reduction 已统一接入 resolve_hit，此处逻辑仅作历史保留。
## 新代码不应调用本方法；如需命中副作用请用 apply_on_hit_side_effects。
static func on_bullet_hit(attacker: Node, target: Node, base_damage: float) -> float:
	var stats = _get_attacker_stats(attacker)
	var target_stats = _get_target_stats(target)
	if stats == null:
		return base_damage

	var final_damage := base_damage

	# 1. 穿甲
	if stats.armor_penetration > 0.0:
		final_damage = _apply_penetration(final_damage, stats)

	# 2. 暴击
	final_damage = _apply_crit(final_damage, stats)

	# 3. 目标减伤
	if target_stats != null:
		final_damage = _apply_target_reduction(final_damage, target_stats)
		# 4. 目标闪避
		if _check_dodge(target, target_stats):
			return 0.0

	# 5. 吸血
	_apply_lifesteal(attacker, final_damage, stats)

	# v6.6: 主目标伤害惩罚（子母弹等范围武器的单目标平衡项，值为负小数）
	# 默认 0 时 (1+0)=1 无影响；放在最终伤害确定后、溅射/连锁之前
	if stats.single_target_penalty != 0.0:
		final_damage = maxf(0.0, final_damage * (1.0 + stats.single_target_penalty))

	# 6. 溅射
	_apply_splash(attacker, target, final_damage, stats)

	# 7. 闪电链
	_apply_chain(attacker, target, final_damage, stats)

	return final_damage

# ─────────────────────────────────────────────
#  命中副作用（仅吸血/连锁/溅射，不含暴击/穿甲/减伤/闪避）
# ─────────────────────────────────────────────

## v6.6: 仅处理命中副作用（吸血/连锁/溅射），不重新计算伤害数值。
## 用于伤害已由 attack_calculator / 已有路径计算的批处理路径，
## 避免暴击/穿甲双重计算。deal_damage 为最终结算伤害。
static func apply_on_hit_side_effects(attacker: Node, target: Node, deal_damage: float) -> void:
	var stats = _get_attacker_stats(attacker)
	if stats == null or deal_damage <= 0.0:
		return
	# v7.x 修复：single_target_penalty（子母弹等范围武器的主目标减伤平衡项）此前仅在已废弃的
	# on_bullet_hit（零调用）中读取，活动命中路径完全不消费它 → 减伤空转。
	# 调用方在 take_damage(全额) 之后才调本函数，故对主目标做"减伤补偿"：
	# 恢复 多扣的血量 = deal_damage × |penalty|，使主目标净伤害 = deal_damage × (1+penalty)。
	if stats.single_target_penalty != 0.0:
		var penalty_abs: float = absf(stats.single_target_penalty)
		if penalty_abs > 0.0 and target != null and is_instance_valid(target):
			var heal_amount: float = deal_damage * penalty_abs
			_apply_main_target_compensation(target, heal_amount)
	_apply_lifesteal(attacker, deal_damage, stats)
	_apply_splash(attacker, target, deal_damage, stats)
	_apply_chain(attacker, target, deal_damage, stats)
	# v7.x: 新机制触发点（命中时）
	_tick_combo(attacker, target, deal_damage, stats)        # 连击成长
	_apply_armor_break(target, stats)                         # 破甲叠加
	_apply_mark(target, stats)                                # 标记系统
	_apply_crit_mark(target, stats)                    # 暴击标注（侦查集火眼）
	_apply_siege_bonus(attacker, target, stats)               # 工兵爆破（对堡垒百分比掉血）
	_apply_laser_mark(target, stats)                          # 激光指示器（命中100%标记）

## v7.x: 主目标减伤补偿（single_target_penalty 的落地）。对目标恢复 heal_amount 血量。
## 直接操作 hp 字段并 clamp 到 max_hp，避免触发 take_damage 的反击/信号链路。
static func _apply_main_target_compensation(target: Node, heal_amount: float) -> void:
	if heal_amount <= 0.0:
		return
	if "hp" in target and "max_hp" in target:
		target.hp = minf(float(target.hp) + heal_amount, float(target.max_hp))

# ─────────────────────────────────────────────
#  击杀处理
# ─────────────────────────────────────────────

## 击杀时处理护盾
static func on_kill(attacker: Node) -> void:
	var stats = _get_attacker_stats(attacker)
	if stats == null:
		return
	if stats.shield_on_kill > 0.0:
		var max_hp = _get_unit_max_hp(attacker)
		if max_hp > 0.0:
			var shield_amount = max_hp * stats.shield_on_kill
			_apply_shield(attacker, shield_amount)

# ─────────────────────────────────────────────
#  持续效果
# ─────────────────────────────────────────────

## 每帧持续效果（HP回复）
static func on_tick(unit: Node, delta: float) -> void:
	var stats = _get_unit_stats(unit)
	if stats == null:
		return
	if stats.hp_regen > 0.0:
		var max_hp = _get_unit_max_hp(unit)
		if max_hp > 0.0:
			var regen_amount = max_hp * stats.hp_regen * delta
			_heal_unit(unit, regen_amount)
	# v7.x: 检查怒气状态过期（成长型机制的持续时间管理）
	_check_rage_expiry(unit, stats, delta)
	# v7.x 第二批：堡垒区域控制（每帧刷新范围内的 meta）
	_apply_slow_aura(unit, stats)       # 区域减速光环
	_apply_command_aura(unit, stats)    # 指挥光环
	# v8: 堡垒阵地坚守光环（地面友军减伤）
	_apply_fort_shelter_aura(unit, stats)
	# v8.x: 雷场范围伤害（for_11_advanced_minefield 等的读取端复活）
	# minefield_damage 此前写入 stats 但战斗侧零读取；现每 0.5s 对范围内敌方造成持续真实伤害
	_apply_minefield_damage(unit, stats, delta)
	# v7.x 第二批：相位护盾回复
	_regen_phase_shield(unit, stats, delta)

# ─────────────────────────────────────────────
#  受击处理（v7.x 新增活跃路径）
# ─────────────────────────────────────────────

## 受击时处理：怒气积累、反击标记
## [param target] 被攻击的单位
## [param attacker] 攻击者（可能为 null）
## [param damage] 实际造成的伤害（经过防御/闪避/护盾扣减后的值）
static func on_damage_taken(target: Node, attacker: Variant, damage: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var stats = _get_unit_stats(target)
	if stats == null:
		return
	# v7.x: 怒气积累（成长型机制）
	_accumulate_rage(target, stats, damage)
	# v7.x: 反击标记（炮兵反击炮击——被攻击时标记攻击者）
	_apply_counter_battery_mark(target, attacker, stats)
	# v7.x 第二批：爆反装甲（受击反伤攻击者）
	_apply_reflect_damage(target, attacker, damage, stats)

# ─────────────────────────────────────────────
#  死亡处理（v7.x 第二批新增：复活 + 亡语治疗）
# ─────────────────────────────────────────────

## 死亡时处理：濒死复活 + 亡语治疗
## 返回 true 表示复活成功（阻止死亡流程）；false 表示继续死亡
## 复活成功时不触发亡语治疗（复活了就没死）
static func on_death(dying_unit: Node, killer: Variant) -> bool:
	if dying_unit == null or not is_instance_valid(dying_unit):
		return false
	var stats = _get_unit_stats(dying_unit)
	if stats == null:
		return false
	# 1. 濒死复活检查（每场战斗仅1次）
	if stats.revive_on_death and not stats.has_revived:
		_revive_unit(dying_unit, stats)
		return true  # 复活成功，中止死亡流程
	# 2. 亡语治疗（未复活才触发）
	_apply_death_heal_allies(dying_unit, stats)
	return false

## 获取 HP 回复倍率（兼容旧接口）
static func get_hp_regen_multiplier(unit: Node, stats: Resource) -> float:
	if stats == null:
		return 0.0
	if stats is UnitStats and stats.hp_regen > 0.0:
		return stats.hp_regen
	return 0.0

## 应用 HP 回复（兼容旧接口）
static func apply_hp_regen(unit: Node, stats: Resource, delta: float) -> void:
	on_tick(unit, delta)

# ─────────────────────────────────────────────
#  平台 HP 变异额外防御（兼容旧接口）
# ─────────────────────────────────────────────

static func check_platform_hp_mutation_extra_defense(unit: Node, stats: Resource) -> float:
	if stats == null or not (stats is UnitStats):
		return 0.0
	if stats.has_platform_hp_mutation:
		var hp_ratio = _get_unit_hp_ratio(unit)
		if hp_ratio > 0.7:
			return stats.defense * 0.3
	return 0.0

# ─────────────────────────────────────────────
#  内部实现
# ─────────────────────────────────────────────

static func _apply_penetration(damage: float, stats: UnitStats) -> float:
	# 穿甲降低目标有效防御
	return damage * (1.0 + stats.armor_penetration * 0.5)

static func _apply_crit(damage: float, stats: UnitStats) -> float:
	if stats.crit_chance <= 0.0:
		return damage
	if randf() > stats.crit_chance:
		return damage
	var crit_mult := 1.5 + stats.crit_damage_bonus
	return damage * crit_mult

static func _apply_target_reduction(damage: float, target_stats: UnitStats) -> float:
	if target_stats.damage_reduction <= 0.0:
		return damage
	return damage * (1.0 - minf(target_stats.damage_reduction, 0.60))

static func _check_dodge(target: Node, target_stats: UnitStats) -> bool:
	if target_stats.dodge_chance <= 0.0:
		return false
	return randf() < target_stats.dodge_chance

static func _apply_lifesteal(attacker: Node, damage: float, stats: UnitStats) -> void:
	if stats.lifesteal <= 0.0 or damage <= 0.0:
		return
	var heal = damage * stats.lifesteal
	_heal_unit(attacker, heal)

static func _apply_splash(attacker: Node, target: Node, damage: float, stats: UnitStats) -> void:
	if stats.splash_damage <= 0.0:
		return
	# 溅射逻辑：对目标周围其他敌人造成溅射伤害
	var splash_dmg = damage * clampf(stats.splash_damage, 0.10, 0.80)  # v7.x: 上限 60%→80%，下限 10%
	# v7.x: 半径支持改造加成（子母弹/近炸引信），改造加成 x2 使其更显著
	var radius: float = 80.0 * (1.0 + maxf(0.0, stats.splash_radius_bonus) * 2.0)
	# v8.1: 溅射冲击波环——在主目标位置 spawn 地面扩散环，半径=溅射范围
	if target != null and is_instance_valid(target) and target is Node2D:
		var parent: Node2D = _resolve_fx_parent_node(target)
		if parent != null:
			VfxImpactFactory.spawn_shockwave(parent, (target as Node2D).global_position, radius)
	var targets = _find_nearby_enemies(target, radius)
	for t in targets:
		if t != target and is_instance_valid(t):
			_deal_damage_to_unit(t, splash_dmg, attacker)

static func _apply_chain(attacker: Node, target: Node, damage: float, stats: UnitStats) -> void:
	if stats.chain_chance <= 0.0:
		return
	if randf() > stats.chain_chance:
		return
	var chain_dmg = damage * 0.5  # 闪电链伤害 = 50%
	# v7.x: 闪电链增加朝向判断——优先跳向攻击者方向的目标（更智能的目标选择）
	var targets = _find_nearby_enemies(target, 120.0)
	var best_target: Node = null
	if attacker != null and is_instance_valid(attacker) and target is Node2D and attacker is Node2D:
		var dir: Vector2 = (attacker as Node2D).global_position - (target as Node2D).global_position
		if dir.length_squared() > 0.01:
			dir = dir.normalized()
			# 在朝向范围内（±60°）优先选择最近的敌人
			var half_angle: float = deg_to_rad(60.0)
			for t in targets:
				if t == target or not is_instance_valid(t) or not (t is Node2D):
					continue
				var to_t: Vector2 = (t as Node2D).global_position - (target as Node2D).global_position
				if to_t.length_squared() > 0.01:
					var angle: float = absf(dir.angle_to(to_t.normalized()))
					if angle <= half_angle:
						best_target = t
						break  # 取第一个在朝向范围内的目标
	if best_target == null and not targets.is_empty():
		# 朝向范围内无目标，回退到距离最近的目标
		for t in targets:
			if t != target and is_instance_valid(t):
				best_target = t
				break
	if best_target != null and is_instance_valid(best_target):
		# v8.1: 闪电链电弧——主目标→次目标闪电线连接
		if target is Node2D and best_target is Node2D:
			var parent: Node2D = _resolve_fx_parent_node(target)
			if parent != null:
				VfxImpactFactory.spawn_lightning_arc(parent, (target as Node2D).global_position, (best_target as Node2D).global_position)
		_deal_damage_to_unit(best_target, chain_dmg, attacker)
		# 闪电链只跳一次

## v8.1: 解析特效挂载父节点（战场/单位容器），复用 CombatFeedback 的查找逻辑
static func _resolve_fx_parent_node(unit: Node) -> Node2D:
	if unit == null or not is_instance_valid(unit):
		return null
	var p: Node = unit.get_parent()
	while p != null:
		if p.name in ["Battlefield", "PlayerUnits", "EnemyUnits"]:
			return p as Node2D
		p = p.get_parent()
	return unit.get_parent() as Node2D

static func _apply_shield(unit: Node, amount: float) -> void:
	if is_instance_valid(unit) and unit.has_method("add_shield"):
		unit.add_shield(amount)

static func _heal_unit(unit: Node, amount: float) -> void:
	if is_instance_valid(unit):
		if unit.has_method("heal"):
			unit.heal(amount)
		elif "hp" in unit:
			unit.hp = minf(unit.hp + amount, _get_unit_max_hp(unit))

static func _deal_damage_to_unit(unit: Node, damage: float, source: Node = null) -> void:
	if not is_instance_valid(unit):
		return
	if unit.has_method("take_damage"):
		unit.take_damage(damage, source)
	elif "hp" in unit:
		unit.hp = maxi(0.0, unit.hp - damage)

## 动态解析 BattleManager autoload 节点。
## 直接引用全局标识符 BattleManager 在 --script 模式下会触发编译错误
## (autoload 未注册)，故用 SceneTree.root 动态查找。
## 运行时行为不变（autoload 仍挂在 root 下）；--script 模式下返回 null 走回退路径。
static func _get_battle_manager() -> Node:
	var ml = Engine.get_main_loop()
	if ml != null and ml is SceneTree:
		var tree := ml as SceneTree
		if tree.root != null:
			return tree.root.get_node_or_null("BattleManager")
	return null

static func _find_nearby_enemies(center: Node, radius: float) -> Array:
	if center == null or not is_instance_valid(center):
		return []
	# P3 性能优化: 优先用 spatial_grid.query_enemies（bounding-box 只遍历覆盖格子），
	# 替代原 get_nodes_in_group 全组遍历 + 逐个 distance_to。
	# center 的 is_player 决定找哪方（玩家找敌人 is_player=false）
	var is_player_center: bool = false
	if "is_player" in center:
		is_player_center = bool(center.is_player)
	var bm: Node = _get_battle_manager()
	if bm != null and bm.get("spatial_grid") != null and is_instance_valid(bm.get("spatial_grid")):
		var enemies = bm.get("spatial_grid").query_enemies(center.global_position, radius, is_player_center)
		# query_enemies 可能包含 center 自身（同阵营），过滤掉
		if center in enemies:
			enemies.erase(center)
		return enemies
	# 防御性回退: spatial_grid 不可用时用原全组遍历
	var targets: Array = []
	var tree = center.get_tree()
	if tree == null:
		return []
	# 找同组目标（玩家打敌人/敌人打玩家）
	if center.is_in_group("player_units"):
		targets = tree.get_nodes_in_group("enemy_units")
	elif center.is_in_group("enemy_units"):
		targets = tree.get_nodes_in_group("player_units")
	var result: Array = []
	for t in targets:
		if is_instance_valid(t) and t != center:
			var dist = center.global_position.distance_to(t.global_position)
			if dist <= radius:
				result.append(t)
	return result

# ─────────────────────────────────────────────
#  Stats 获取工具
# ─────────────────────────────────────────────

static func _get_unit_stats(unit: Node) -> UnitStats:
	if not is_instance_valid(unit):
		return null
	if unit.get("stats") is UnitStats:
		return unit.stats as UnitStats
	return null

static func _get_attacker_stats(attacker: Node) -> UnitStats:
	return _get_unit_stats(attacker)

static func _get_target_stats(target: Node) -> UnitStats:
	return _get_unit_stats(target)

static func _get_unit_max_hp(unit: Node) -> float:
	if not is_instance_valid(unit):
		return 0.0
	if unit.get("stats") is UnitStats:
		return (unit.stats as UnitStats).max_hp
	if "max_hp" in unit:
		return float(unit.max_hp)
	return 0.0

static func _get_unit_hp_ratio(unit: Node) -> float:
	var max_hp = _get_unit_max_hp(unit)
	if max_hp <= 0.0:
		return 0.0
	var current_hp: float = 0.0
	if "hp" in unit:
		current_hp = float(unit.hp)
	return current_hp / max_hp

# ═══════════════════════════════════════════════════════════════
#  v7.x 新机制实现
# ═══════════════════════════════════════════════════════════════

# ── 成长型：连击（每次命中计数，满后下次伤害爆发）──

## 连击计数：每次命中 +1，达 combo_max 后本次伤害触发爆发倍率并清零
## combo_bonus_mult 是爆发倍率（0.3 = +30%），爆发后计数清零
static func _tick_combo(attacker: Node, target: Node, deal_damage: float, stats: UnitStats) -> void:
	if stats.combo_max <= 0:
		return
	stats.combo_counter += 1
	if stats.combo_counter >= stats.combo_max:
		# 爆发：对目标造成额外爆发伤害
		var burst_dmg: float = deal_damage * stats.combo_bonus_mult
		if burst_dmg > 0.0 and target != null and is_instance_valid(target):
			_deal_damage_to_unit(target, burst_dmg, attacker)
		stats.combo_counter = 0  # 清零，开始新一轮积累

# ── 成长型：怒气（受击积累，满后临时增益）──

## 怒气积累：每次受击 +1，达 rage_max 后激活 rage_active 并计时
## rage_bonus_mult 是激活后的攻击加成（0.35 = +35%）
## 激活期间攻击力临时提升，持续到 _expire_rage 被调用（由 on_tick 驱动计时）
static func _accumulate_rage(target: Node, stats: UnitStats, damage: float) -> void:
	if stats.rage_max <= 0:
		return
	if stats.has_meta("_rage_active") and bool(stats.get_meta("_rage_active", false)):
		return  # 已激活，不再积累
	stats.rage_counter += 1
	if stats.rage_counter >= stats.rage_max:
		# 激活怒气：临时提升攻击力
		stats.rage_counter = 0
		_activate_rage_on_unit(target, stats)

## 激活怒气状态（给单位标记 + 临时 stats 提升）
static func _activate_rage_on_unit(unit: Node, stats: UnitStats) -> void:
	if not is_instance_valid(unit):
		return
	# 用 meta 标记激活状态 + 过期时间戳
	stats.set_meta("_rage_active", true)
	var duration: float = 5.0  # 怒气持续 5 秒
	var expire_at: float = Time.get_ticks_msec() / 1000.0 + duration
	stats.set_meta("_rage_expire_at", expire_at)
	# 临时提升攻击力（用乘法，过期时恢复）
	stats.attack_damage *= (1.0 + stats.rage_bonus_mult)
	# 红色光环视觉
	if unit is Node2D:
		_create_rage_vfx((unit as Node2D).global_position)

## 怒气过期检查（由 on_tick 驱动，每帧检查过期时间）
static func _check_rage_expiry(unit: Node, stats: UnitStats, delta: float) -> void:
	if not (stats.has_meta("_rage_active") and bool(stats.get_meta("_rage_active", false))):
		return
	var expire_at: float = float(stats.get_meta("_rage_expire_at", 0.0))
	var now: float = Time.get_ticks_msec() / 1000.0
	if now >= expire_at:
		# 过期：恢复攻击力
		stats.attack_damage /= (1.0 + stats.rage_bonus_mult)
		stats.set_meta("_rage_active", false)

## 怒气激活时的红色光环视觉（简化版）
static func _create_rage_vfx(pos: Vector2) -> void:
	# 简化实现：通过 SignalBus 请求伤害数字风格的视觉提示
	# 完整粒子特效留给 EnemyPhaseInstrumentAbilities 的 rage 机制
	pass

# ── debuff 型：破甲叠加（每次命中降低目标防御，可叠加）──

## 破甲叠加：给 target 挂 meta `_armor_break_stacks`，每次命中 +1（不超过 max_stacks）
## 目标在 take_damage 时读 meta 降低有效防御（construct_unit 已接入）
static func _apply_armor_break(target: Node, stats: UnitStats) -> void:
	if stats.armor_break_per_hit <= 0.0:
		return
	if target == null or not is_instance_valid(target):
		return
	var current_stacks: int = 0
	if target.has_meta("_armor_break_stacks"):
		current_stacks = int(target.get_meta("_armor_break_stacks", 0))
	if stats.armor_break_max_stacks > 0 and current_stacks >= stats.armor_break_max_stacks:
		return  # 已达上限
	current_stacks += 1
	target.set_meta("_armor_break_stacks", current_stacks)
	# 同时记录每层的减免比例和来源 stats（供 take_damage 读取）
	target.set_meta("_armor_break_ratio", stats.armor_break_per_hit)

# ── debuff 型：标记系统（命中概率标记，被标记目标受额外伤害）──

## 标记：按 mark_chance 概率给 target 挂标记 meta
## 被标记目标在 take_damage 时受额外 mark_vuln_bonus 伤害（construct_unit 已接入）
static func _apply_mark(target: Node, stats: UnitStats) -> void:
	if stats.mark_chance <= 0.0:
		return
	if target == null or not is_instance_valid(target):
		return
	if randf() > stats.mark_chance:
		return
	# 挂标记：记录过期时间戳 + 易伤比例
	var expire_at: float = Time.get_ticks_msec() / 1000.0 + stats.mark_duration
	target.set_meta("_marked_until", expire_at)
	target.set_meta("_mark_vuln_bonus", stats.mark_vuln_bonus)

# ── debuff 型：暴击标注系统（侦查命中概率标注，被标注目标受攻击暴击率提升）──

## 暴击标注：按 crit_mark_chance 概率给 target 挂暴击标注 meta
## 被标注目标在 bullet.gd 暴击结算时获得 crit_mark_bonus 暴击率加成
## 在 target_selection 索敌时被远程单位优先集火
static func _apply_crit_mark(target: Node, stats: UnitStats) -> void:
	if stats.crit_mark_chance <= 0.0:
		return
	if target == null or not is_instance_valid(target):
		return
	if randf() > stats.crit_mark_chance:
		return
	var expire_at: float = Time.get_ticks_msec() / 1000.0 + stats.crit_mark_duration
	target.set_meta("_crit_marked_until", expire_at)
	target.set_meta("_crit_mark_bonus", stats.crit_mark_bonus)

# ── 兵种专属：工兵爆破（对堡垒/装甲目标百分比掉血）──

## 工兵爆破：对 FORT/ARMOR 目标造成当前 HP 5% 的额外真实伤害（无视防御）
## siege_bonus_pct 是百分比（0.05 = 5%）
static func _apply_siege_bonus(attacker: Node, target: Node, stats: UnitStats) -> void:
	if stats.siege_bonus_pct <= 0.0:
		return
	if target == null or not is_instance_valid(target):
		return
	# 仅对堡垒/装甲目标生效
	var target_stats = _get_target_stats(target)
	if target_stats == null:
		return
	var ck: int = int(target_stats.combat_kind)
	# CombatKind: 1=ARMOR, 4=FORT
	if ck != 1 and ck != 4:
		return
	# 百分比掉血：目标当前 HP × siege_bonus_pct（真实伤害，绕过防御）
	var current_hp: float = 0.0
	if "hp" in target:
		current_hp = float(target.hp)
	elif target_stats != null:
		current_hp = float(target_stats.max_hp)
	if current_hp <= 0.0:
		return
	var siege_dmg: float = current_hp * stats.siege_bonus_pct
	if siege_dmg > 0.0:
		_deal_damage_to_unit(target, siege_dmg, attacker)

# ── 兵种专属：炮兵反击（被攻击时标记攻击者）──

## 反击标记：被攻击时，如果 stats.has_counter_battery，给 attacker 挂 mark meta
## 炮兵在 construct_unit_ai 选目标时优先攻击被 mark 的目标（AI 侧实现）
static func _apply_counter_battery_mark(target: Node, attacker: Variant, stats: UnitStats) -> void:
	if not stats.has_counter_battery:
		return
	if attacker == null or not is_instance_valid(attacker):
		return
	if not (attacker is Node):
		return
	# 给攻击者挂 mark（复用标记系统 meta，持续 5 秒）
	var expire_at: float = Time.get_ticks_msec() / 1000.0 + 5.0
	(attacker as Node).set_meta("_marked_until", expire_at)
	(attacker as Node).set_meta("_mark_vuln_bonus", 0.3)  # 反击标记附带 30% 易伤
	(attacker as Node).set_meta("_counter_marked_by", target)  # 记录标记来源（供 AI 优先选目标）

# ═══════════════════════════════════════════════════════════════
#  v7.x 第二批新机制实现
# ═══════════════════════════════════════════════════════════════

# ── 濒死复活 ──

## 复活单位：恢复 HP 到 max_hp × ratio，标记 has_revived 防重复
static func _revive_unit(unit: Node, stats: UnitStats) -> void:
	var max_hp: float = _get_unit_max_hp(unit)
	if max_hp <= 0.0:
		max_hp = float(stats.max_hp)
	var revive_hp: float = max_hp * stats.revive_hp_ratio
	if "hp" in unit:
		unit.hp = revive_hp
	if "max_hp" in unit:
		pass  # max_hp 不变
	stats.has_revived = true
	# 清除死亡标记（construct_unit._is_dying）
	if "_is_dying" in unit:
		unit._is_dying = false
	# 调用单位的 on_revived 钩子（可选，单位可重置状态）
	if unit.has_method("on_revived"):
		unit.on_revived()

# ── 爆反装甲（受击反伤）──

## 爆反：受击时按比例反弹伤害给攻击者，消耗层数
static func _apply_reflect_damage(target: Node, attacker: Variant, damage: float, stats: UnitStats) -> void:
	if stats.reflect_damage_pct <= 0.0 or damage <= 0.0:
		return
	# 检查层数（-1=无限）
	if stats.reflect_charges == 0:
		return  # 已耗尽
	# 层数消耗
	if stats.reflect_charges > 0:
		stats.reflect_charges -= 1
	# 反伤给攻击者
	var reflect_dmg: float = damage * stats.reflect_damage_pct
	if reflect_dmg > 0.0 and attacker != null and is_instance_valid(attacker) and attacker is Node:
		if (attacker as Node).has_method("take_damage"):
			(attacker as Node).take_damage(reflect_dmg, target)

# ── 拦截（伤害归零）──

## 拦截判定：在 take_damage 计算 hp_loss 之后、hp 扣减之前调用
## 返回 true 表示拦截成功（应跳过 hp 扣减），false 表示正常受伤
static func try_intercept(target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var stats = _get_unit_stats(target)
	if stats == null:
		return false
	if stats.intercept_chance <= 0.0:
		return false
	# 检查次数（-1=无限）
	if stats.intercept_charges == 0:
		return false  # 已耗尽
	# 概率判定
	if randf() > stats.intercept_chance:
		return false
	# 拦截成功：消耗次数
	if stats.intercept_charges > 0:
		stats.intercept_charges -= 1
	return true

# ── 亡语治疗（死亡时治疗周围友军）──

## 亡语治疗：死亡时治疗范围内的友军（按自身 max_hp 百分比）
static func _apply_death_heal_allies(dying_unit: Node, stats: UnitStats) -> void:
	if stats.death_heal_allies_pct <= 0.0:
		return
	var max_hp: float = _get_unit_max_hp(dying_unit)
	if max_hp <= 0.0:
		return
	var heal_amount: float = max_hp * stats.death_heal_allies_pct
	var radius: float = stats.death_heal_radius
	# 找周围友军（同阵营）
	var allies: Array = _find_nearby_allies(dying_unit, radius)
	for ally in allies:
		if ally != dying_unit and is_instance_valid(ally):
			_heal_unit(ally, heal_amount)

## 找周围友军（复用 _find_nearby_enemies 的 spatial_grid 模式，但阵营对调）
static func _find_nearby_allies(center: Node, radius: float) -> Array:
	if center == null or not is_instance_valid(center):
		return []
	var is_player_center: bool = false
	if "is_player" in center:
		is_player_center = bool(center.is_player)
	# 友军=同阵营（玩家找玩家，敌方找敌方）
	# spatial_grid.query_enemies 默认返回敌方，这里需要同阵营
	# 用全组遍历替代（友军数量通常不多）
	# 防御性：全组遍历找同阵营
	var targets: Array = []
	var tree = center.get_tree()
	if tree == null:
		return []
	var group_name: String = "player_units" if is_player_center else "enemy_units"
	targets = tree.get_nodes_in_group(group_name)
	var result: Array = []
	for t in targets:
		if is_instance_valid(t) and t != center:
			var dist = center.global_position.distance_to(t.global_position)
			if dist <= radius:
				result.append(t)
	return result

# ── 堡垒区域控制（on_tick 扩展）──

## 区域减速光环：范围内敌方移速降低（通过 meta 挂载，on_tick 刷新）
static func _apply_slow_aura(unit: Node, stats: UnitStats) -> void:
	if stats.slow_aura_pct <= 0.0:
		return
	var enemies: Array = _find_nearby_enemies(unit, stats.slow_aura_radius)
	var slow_mult: float = 1.0 - stats.slow_aura_pct
	for e in enemies:
		if e == null or not is_instance_valid(e):
			continue
		# 挂减速 meta（持续 1 秒，on_tick 每帧刷新）
		e.set_meta("_slow_aura_until", Time.get_ticks_msec() / 1000.0 + 1.0)
		e.set_meta("_slow_aura_mult", slow_mult)

## 指挥光环：范围内友军暴击加成（通过 meta 挂载）
static func _apply_command_aura(unit: Node, stats: UnitStats) -> void:
	if stats.command_aura_bonus <= 0.0:
		return
	var allies: Array = _find_nearby_allies(unit, 250.0)
	for ally in allies:
		if ally == null or not is_instance_valid(ally):
			continue
		# 挂指挥 meta（持续 1 秒，on_tick 每帧刷新）
		ally.set_meta("_command_aura_until", Time.get_ticks_msec() / 1000.0 + 1.0)
		ally.set_meta("_command_aura_bonus", stats.command_aura_bonus)

## v8: 堡垒阵地坚守光环——范围内地面友军（非空中）受伤减免
## 复用 _apply_command_aura 的扫描+meta 模式，区别：排除 AIR 友军、挂减伤 meta
static func _apply_fort_shelter_aura(unit: Node, stats: UnitStats) -> void:
	if stats.fort_shelter_aura <= 0.0:
		return
	var allies: Array = _find_nearby_allies(unit, stats.fort_shelter_radius)
	for ally in allies:
		if ally == null or not is_instance_valid(ally):
			continue
		# 排除空中单位（堡垒保护地面部队，不保护头顶目标）
		var ally_stats = _get_unit_stats(ally)
		if ally_stats != null and ally_stats.combat_kind == GC.CombatKind.AIR:
			continue
		# 挂堡垒庇护 meta（持续 1 秒，on_tick 每帧刷新）
		ally.set_meta("_fort_shelter_until", Time.get_ticks_msec() / 1000.0 + 1.0)
		ally.set_meta("_fort_shelter_bonus", stats.fort_shelter_aura)

## v8.x: 雷场范围伤害（minefield_damage 的读取端复活）
## for_11_advanced_minefield 等写入 stats.minefield_damage 后此前战斗侧零读取。
## 现每 0.5s 对范围内敌方造成 minefield_damage × TICK 的真实伤害（绕过防御）。
## 节流：用单位 meta 累积时间，避免每帧全组扫描。
const MINEFIELD_TICK_INTERVAL: float = 0.5
static func _apply_minefield_damage(unit: Node, stats: UnitStats, delta: float) -> void:
	if stats.minefield_damage <= 0.0:
		return
	# 累积计时（meta 挂在单位上，跨帧保留）
	var acc: float = 0.0
	if unit.has_meta("_minefield_acc"):
		acc = float(unit.get_meta("_minefield_acc", 0.0))
	acc += delta
	if acc < MINEFIELD_TICK_INTERVAL:
		unit.set_meta("_minefield_acc", acc)
		return
	# 到达节流阈值，重置计时并触发伤害
	unit.set_meta("_minefield_acc", 0.0)
	var dmg_per_tick: float = stats.minefield_damage * MINEFIELD_TICK_INTERVAL  # 每秒 = minefield_damage
	# 复用 splash 半径口径（80 × (1 + bonus)），让 for_11 改造数值与溅射机制视觉一致
	var radius: float = 80.0 * (1.0 + maxf(0.0, stats.splash_radius_bonus) * 2.0)
	var enemies: Array = _find_nearby_enemies(unit, radius)
	for e in enemies:
		if e == null or not is_instance_valid(e):
			continue
		_deal_damage_to_unit(e, dmg_per_tick, unit)

# ── 相位护盾 ──

## 相位护盾回复（on_tick 每帧）
static func _regen_phase_shield(unit: Node, stats: UnitStats, delta: float) -> void:
	if stats.phase_shield_pool <= 0.0:
		return
	if not ("_phase_shield_current" in unit):
		unit._phase_shield_current = stats.phase_shield_pool
	# 每秒回复
	unit._phase_shield_current = minf(stats.phase_shield_pool, unit._phase_shield_current + stats.phase_shield_regen * delta)

# ── 激光指示器（命中标记）──

## 激光标记：命中 100% 给目标挂 mark（复用标记系统 meta）
static func _apply_laser_mark(target: Node, stats: UnitStats) -> void:
	if not stats.laser_mark_on_hit:
		return
	if target == null or not is_instance_valid(target):
		return
	# 100% 标记，持续 5 秒，+20% 易伤
	var expire_at: float = Time.get_ticks_msec() / 1000.0 + 5.0
	target.set_meta("_marked_until", expire_at)
	target.set_meta("_mark_vuln_bonus", 0.20)
