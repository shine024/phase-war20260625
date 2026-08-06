extends RefCounted
class_name CardPeriodicSkillEngine
## ═══════════════════════════════════════════════════════════
##  v8.x 卡片定时技能引擎
##
##  特定平台卡部署后，按固定周期自动施放技能。
##  完全复用 PhaseInstrumentAbilities 的 periodic 触发模式，但数据源不同：
##    - PhaseInstrumentAbilities：读 PhaseInstrument.active_ability（玩家/敌方相位仪）
##    - CardPeriodicSkillEngine：读 PhaseMasterSkillManager 已解锁的 card_skill 列表
##      + 场上存在对应 source_tag 单位时触发
##
##  接入点：battle_manager._process(delta) 中调用 update(delta)
##  依赖：
##    - CardPeriodicSkills（技能数据）
##    - PhaseMasterSkillManager（查询已解锁 card_skill）
##    - battle_manager.player_units_node / enemy_units_node
##
##  设计原则：
##    1. 每 0.5s 检查一次（避免每帧扫描开销）
##    2. 每个技能独立计时器
##    3. 触发前检查 source_tag 单位是否在场
##    4. 复用现有引擎能力（damage/mark/shield/slow_aura 等）
## ═══════════════════════════════════════════════════════════

const CPS = preload("res://data/card_periodic_skills.gd")
const GC = preload("res://resources/game_constants.gd")
const VfxImpactFactory = preload("res://scripts/battle/vfx_impact_factory.gd")
const PhaseLawCastEffect = preload("res://scenes/effects/phase_law_cast_effect.gd")

const CHECK_INTERVAL: float = 0.5  # 每 0.5s 检查一次计时器

## 外部依赖
var _player_units_node: Node = null
var _enemy_units_node: Node = null
var _skill_manager: Node = null  # PhaseMasterSkillManager autoload
var _battlefield: Node = null

## 已激活的技能计时器  skill_id → elapsed
var _timers: Dictionary = {}
## 已解锁的技能列表（战斗开始时从 skill_manager 读取一次）
var _unlocked_skills: Array = []
## 战斗是否激活
var _battle_active: bool = false
## 计时累加器
var _check_acc: float = 0.0

func setup(deps: Dictionary) -> void:
	_player_units_node = deps.get("player_units_node", null)
	_enemy_units_node = deps.get("enemy_units_node", null)
	_skill_manager = deps.get("skill_manager", null)
	_battlefield = deps.get("battlefield", null)

## 战斗开始时调用：从 skill_manager 读取已解锁的 card_skill 列表
func on_battle_start() -> void:
	_unlocked_skills.clear()
	_timers.clear()
	_battle_active = true
	_check_acc = 0.0
	if _skill_manager == null or not _skill_manager.has_method("is_content_unlocked"):
		return
	# 遍历所有卡片技能，检查是否已解锁
	for skill_id in CPS.get_all_skill_ids():
		if _skill_manager.is_content_unlocked("card_skill", skill_id):
			_unlocked_skills.append(skill_id)
			_timers[skill_id] = 0.0  # 初始化计时器

## 每帧调用（由 battle_manager._process 调用）
func update(delta: float) -> void:
	if not _battle_active or _unlocked_skills.is_empty():
		return
	_check_acc += delta
	if _check_acc < CHECK_INTERVAL:
		return
	_check_acc = 0.0
	# 推进每个技能的计时器
	for skill_id in _unlocked_skills:
		var skill: Dictionary = CPS.get_skill(skill_id)
		if skill.is_empty():
			continue
		if String(skill.get("trigger", "")) != "periodic":
			continue
		_timers[skill_id] = float(_timers.get(skill_id, 0.0)) + CHECK_INTERVAL
		var interval: float = float(skill.get("interval", 30.0))
		if _timers[skill_id] >= interval:
			_timers[skill_id] = 0.0
			_try_trigger(skill)

## 战斗结束时重置
func reset() -> void:
	_unlocked_skills.clear()
	_timers.clear()
	_battle_active = false
	_check_acc = 0.0

## 获取当前已激活的技能 family 统计（供 TacticDetector 战法条件查询）
func get_active_families() -> Dictionary:
	var families: Dictionary = {}
	for skill_id in _unlocked_skills:
		var skill: Dictionary = CPS.get_skill(skill_id)
		var fam: String = skill.get("family", "")
		if not fam.is_empty():
			families[fam] = int(families.get(fam, 0)) + 1
	return families

## 获取已激活的终极技能数量（供 tactic_ragnarok 条件查询）
func get_ultimate_count() -> int:
	var count: int = 0
	for skill_id in _unlocked_skills:
		if CPS.is_ultimate(skill_id):
			count += 1
	return count

# ─────────────────────────────────────────────
#  内部：触发逻辑
# ─────────────────────────────────────────────

## 尝试触发技能（检查 source_tag 单位是否在场）
func _try_trigger(skill: Dictionary) -> void:
	var source_tag: String = skill.get("source_tag", "")
	var min_count: int = int(skill.get("min_source_count", 0))
	if not source_tag.is_empty() and min_count > 0:
		var allies: Array = _collect_player_units()
		var tag_count: int = 0
		for u in allies:
			var tags: Array = u.get("_behavior_tags_cached") if u.get("_behavior_tags_cached") != null else []
			if source_tag in tags:
				tag_count += 1
		if tag_count < min_count:
			return  # source 不足，不触发
	# 触发技能
	_execute_effect(skill)

## 执行技能效果
func _execute_effect(skill: Dictionary) -> void:
	var effect: Dictionary = skill.get("effect", {})
	if effect.is_empty():
		return
	# v8.x 视觉反馈：所有技能触发都弹 Toast（普通技金色轻量提示，终极技红色+震屏）。
	# 终极技仍额外触发震屏；普通技 cooldown 短（10-18s）故 Toast 用短持续时间避免刷屏。
	var skill_id: String = String(skill.get("id", ""))
	var is_ult: bool = CPS.is_ultimate(skill_id)
	_emit_skill_toast(skill, is_ult)
	if is_ult:
		_play_ultimate_shake()
	var effect_type: String = effect.get("type", "")
	match effect_type:
		"area_damage": _exec_area_damage(effect)
		"single_target_damage": _exec_single_target_damage(effect)
		"global_damage": _exec_global_damage(effect)
		"chain_damage": _exec_chain_damage(effect)
		"debuff_target": _exec_debuff_target(effect)
		"debuff_area": _exec_debuff_area(effect)
		"debuff_global": _exec_debuff_global(effect)
		"debuff_spread": _exec_debuff_spread(effect)
		"buff_allies": _exec_buff_allies(effect)
		"summon_temp_unit": _exec_summon_temp_unit(effect)
		"execute": _exec_execute(effect)
		_:
			pass  # 未知类型忽略

## 收集场上友军单位
func _collect_player_units() -> Array:
	var result: Array = []
	if _player_units_node == null:
		return result
	for u in _player_units_node.get_children():
		if u != null and is_instance_valid(u) and "hp" in u and float(u.hp) > 0.0:
			result.append(u)
	return result

## 收集场上敌方单位
func _collect_enemy_units() -> Array:
	var result: Array = []
	if _enemy_units_node == null:
		return result
	for u in _enemy_units_node.get_children():
		if u != null and is_instance_valid(u) and "hp" in u and float(u.hp) > 0.0:
			result.append(u)
	return result

## 计算平均友军 ATK（用于百分比伤害技能）
func _get_avg_ally_atk(allies: Array) -> float:
	if allies.is_empty():
		return 50.0
	var total: float = 0.0
	var count: int = 0
	for u in allies:
		var s = u.get("stats") as UnitStats
		if s != null:
			total += (float(s.attack_light) + float(s.attack_armor) + float(s.attack_air)) / 3.0
			count += 1
	return (total / count) if count > 0 else 50.0

# ─────────────────────────────────────────────
#  效果实现（复用现有引擎能力）
# ─────────────────────────────────────────────

## 区域伤害：对敌方最密集区范围伤害
func _exec_area_damage(effect: Dictionary) -> void:
	var enemies: Array = _collect_enemy_units()
	if enemies.is_empty():
		return
	var allies: Array = _collect_player_units()
	var avg_atk: float = _get_avg_ally_atk(allies)
	var radius: float = float(effect.get("radius", 120))
	var dmg_mult: float = float(effect.get("damage_pct_atk", 1.0))
	var damage: float = avg_atk * dmg_mult
	# 找最密集区域（简化：以最高 HP 敌方为中心）
	var center: Node2D = _find_densest_enemy(enemies)
	if center == null:
		return
	# v8.x VFX：炮击警告标记 → 延迟爆炸（纯视觉，伤害即时结算）
	if String(effect.get("vfx", "")) == "artillery_barrage":
		_play_area_damage_vfx(center.global_position, radius)
	# 对范围内所有敌方造成伤害
	for e in enemies:
		if e == null or not is_instance_valid(e):
			continue
		if center.global_position.distance_to(e.global_position) <= radius:
			if e.has_method("take_damage"):
				e.take_damage(damage, null)

## 单体伤害
func _exec_single_target_damage(effect: Dictionary) -> void:
	var enemies: Array = _collect_enemy_units()
	if enemies.is_empty():
		return
	var allies: Array = _collect_player_units()
	var avg_atk: float = _get_avg_ally_atk(allies)
	var target_sel: String = effect.get("target", "highest_threat")
	var target: Node2D = _select_target(enemies, target_sel)
	if target == null:
		return
	var damage: float = avg_atk * float(effect.get("damage_pct_atk", 2.0))
	# 穿透比例（降低目标有效防御）
	if target.has_method("take_damage"):
		target.take_damage(damage, null)

## 全图伤害
func _exec_global_damage(effect: Dictionary) -> void:
	var enemies: Array = _collect_enemy_units()
	if enemies.is_empty():
		return
	# v8.x VFX：核爆全屏演出（仅 nuclear_bombardment；heaven_thunder/annihilate 走大招震屏）
	if String(effect.get("vfx", "")) == "nuclear_bombardment":
		_play_global_damage_vfx((enemies[0] as Node2D).global_position)
	var allies: Array = _collect_player_units()
	var avg_atk: float = _get_avg_ally_atk(allies)
	var damage: float = float(effect.get("damage_flat", 0.0))
	if damage == 0.0:
		damage = avg_atk * float(effect.get("damage_pct_atk", 1.0))
	# 机械单位额外伤害
	var mech_mult: float = float(effect.get("mechanical_mult", 1.0))
	for e in enemies:
		if e == null or not is_instance_valid(e):
			continue
		var final_dmg: float = damage
		var tags: Array = e.get("_behavior_tags_cached") if e.get("_behavior_tags_cached") != null else []
		if "mechanical" in tags and mech_mult != 1.0:
			final_dmg *= mech_mult
		if e.has_method("take_damage"):
			e.take_damage(final_dmg, null)
	# 斩杀检查
	var exec_threshold: float = float(effect.get("execute_threshold", 0.0))
	if exec_threshold > 0.0:
		_apply_execute(enemies, exec_threshold)

## 闪电链伤害
func _exec_chain_damage(effect: Dictionary) -> void:
	var enemies: Array = _collect_enemy_units()
	if enemies.is_empty():
		return
	var allies: Array = _collect_player_units()
	var avg_atk: float = _get_avg_ally_atk(allies)
	var bounces: int = int(effect.get("bounces", 3))
	var dmg_pct: float = float(effect.get("damage_pct_atk", 0.70))
	var armor_bonus: float = float(effect.get("armor_bonus_mult", 0.0))
	var available: Array = enemies.duplicate()
	var last_pos: Vector2 = Vector2.ZERO
	var has_last: bool = false
	for i in range(bounces):
		if available.is_empty():
			break
		# 找最近的目标
		var nearest: Node2D = null
		var nearest_dist: float = INF
		for e in available:
			if e == null or not is_instance_valid(e):
				continue
			if has_last:
				var d: float = last_pos.distance_squared_to(e.global_position)
				if d < nearest_dist:
					nearest_dist = d
					nearest = e
			else:
				nearest = e
				break
		if nearest == null:
			break
		var damage: float = avg_atk * dmg_pct
		var s = nearest.get("stats") as UnitStats
		if s != null and s.combat_kind == GC.CombatKind.ARMOR and armor_bonus > 0.0:
			damage *= (1.0 + armor_bonus)
		if nearest.has_method("take_damage"):
			nearest.take_damage(damage, null)
		last_pos = nearest.global_position
		has_last = true
		available.erase(nearest)

## 对单体施加 debuff
func _exec_debuff_target(effect: Dictionary) -> void:
	var enemies: Array = _collect_enemy_units()
	if enemies.is_empty():
		return
	var target_sel: String = effect.get("target", "highest_threat")
	var target: Node2D = _select_target(enemies, target_sel)
	if target == null:
		return
	# v8.x VFX：EMP 紫波 / 其它 debuff 轻警告
	_play_debuff_vfx(target.global_position, String(effect.get("vfx", "")))
	_apply_debuff_to_unit(target, effect)

## 对区域施加 debuff
func _exec_debuff_area(effect: Dictionary) -> void:
	var enemies: Array = _collect_enemy_units()
	if enemies.is_empty():
		return
	var radius: float = float(effect.get("radius", 120))
	var center: Node2D = _find_densest_enemy(enemies)
	if center == null:
		return
	for e in enemies:
		if e == null or not is_instance_valid(e):
			continue
		if center.global_position.distance_to(e.global_position) <= radius:
			_apply_debuff_to_unit(e, effect)

## 全图 debuff
func _exec_debuff_global(effect: Dictionary) -> void:
	var enemies: Array = _collect_enemy_units()
	for e in enemies:
		if e == null or not is_instance_valid(e):
			continue
		_apply_debuff_to_unit(e, effect)

## debuff 传染
func _exec_debuff_spread(effect: Dictionary) -> void:
	var enemies: Array = _collect_enemy_units()
	if enemies.is_empty():
		return
	# 找到燃烧中的敌方
	var burning: Array = []
	for e in enemies:
		if e != null and is_instance_valid(e) and e.has_meta("_marked_until"):
			burning.append(e)
	if burning.is_empty():
		return
	# 传染给邻近敌方
	var source: Node2D = burning[0]
	var max_targets: int = int(effect.get("max_targets", 5))
	var count: int = 0
	for e in enemies:
		if count >= max_targets:
			break
		if e == source:
			continue
		if source.global_position.distance_to(e.global_position) <= 200:
			_apply_debuff_to_unit(e, effect)
			count += 1

## 全体友军 buff
func _exec_buff_allies(effect: Dictionary) -> void:
	var allies: Array = _collect_player_units()
	if allies.is_empty():
		return
	var target_filter: String = effect.get("target", "all_allies")
	var shield: float = float(effect.get("shield", 0.0))
	var shield_dur: float = float(effect.get("shield_duration", 6.0))
	var heal_pct: float = float(effect.get("heal_pct_max_hp", 0.0))
	var cleanse: bool = bool(effect.get("cleanse_debuffs", false))
	var stat_bonus: Dictionary = effect.get("stat_bonus", {})
	var stat_dur: float = float(effect.get("stat_bonus_duration", 8.0))
	for u in allies:
		if not _matches_target_filter(u, target_filter):
			continue
		# 护盾
		if shield > 0.0 and u.has_method("add_shield"):
			u.add_shield(shield)
		# 治疗
		if heal_pct > 0.0 and u.has_method("heal"):
			var s = u.get("stats") as UnitStats
			var max_hp: float = float(s.max_hp) if s != null else 100.0
			u.heal(max_hp * heal_pct)
		# 清除 debuff
		if cleanse and u.has_method("cleanse_all_debuffs"):
			u.cleanse_all_debuffs()
		# stat_bonus（写入 meta，由 construct_unit 读取）
		if not stat_bonus.is_empty():
			_apply_temporary_stat_bonus(u, stat_bonus, stat_dur)

## 召唤临时单位
func _exec_summon_temp_unit(effect: Dictionary) -> void:
	# P1 占位：实际召唤需 battle_spawn_system 支持
	# 此处通过 battlefield 或 SignalBus 通知 spawn system
	if _battlefield != null and _battlefield.has_method("summon_temp_unit"):
		_battlefield.summon_temp_unit(effect)
	else:
		# 兜底：通过 SignalBus 发射事件（防御性访问，兼容 --script 测试模式）
		var sb = Engine.get_main_loop().root.get_node_or_null("/root/SignalBus")
		if sb != null and sb.has_signal("card_skill_summon_unit"):
			sb.card_skill_summon_unit.emit(effect)

## 斩杀
func _exec_execute(effect: Dictionary) -> void:
	var enemies: Array = _collect_enemy_units()
	if enemies.is_empty():
		return
	var threshold: float = float(effect.get("hp_threshold", 0.15))
	_apply_execute(enemies, threshold)

## 内部：应用斩杀
func _apply_execute(enemies: Array, threshold: float) -> void:
	var clamp_ratio: float = threshold  # 精英/Boss 降至该比例而非斩杀
	for e in enemies:
		if e == null or not is_instance_valid(e):
			continue
		var s = e.get("stats") as UnitStats
		if s == null:
			continue
		var max_hp: float = float(s.max_hp)
		var cur_hp: float = float(e.hp) if "hp" in e else max_hp
		if max_hp <= 0.0:
			continue
		var hp_ratio: float = cur_hp / max_hp
		if hp_ratio < 0.001:
			continue  # 已死
		if hp_ratio <= threshold:
			# 判断是否精英/Boss（通过 meta 或 stats）
			var is_elite: bool = bool(e.get_meta("is_elite_boss", false))
			if is_elite:
				# 精英/Boss 降至阈值 HP 而非斩杀
				if "hp" in e:
					e.hp = max_hp * clamp_ratio
			else:
				# 普通单位直接斩杀
				if e.has_method("take_damage"):
					e.take_damage(cur_hp + 100.0, null)  # 造成致命伤害

# ─────────────────────────────────────────────
#  工具函数
# ─────────────────────────────────────────────

## 找最密集的敌方区域中心（简化：返回 HP 最高的敌方）
func _find_densest_enemy(enemies: Array) -> Node2D:
	var best: Node2D = null
	var best_hp: float = 0.0
	for e in enemies:
		if e == null or not is_instance_valid(e):
			continue
		var hp: float = float(e.hp) if "hp" in e else 0.0
		if hp > best_hp:
			best_hp = hp
			best = e
	return best

## 按选择策略选目标
func _select_target(enemies: Array, strategy: String) -> Node2D:
	if enemies.is_empty():
		return null
	match strategy:
		"highest_threat":
			# 最高威胁=最高 ATK 或 Boss 标签
			return _find_highest_threat(enemies)
		"highest_hp":
			return _find_densest_enemy(enemies)
		"lowest_hp":
			return _find_lowest_hp(enemies)
		_:
			return enemies[0]

func _find_highest_threat(enemies: Array) -> Node2D:
	var best: Node2D = null
	var best_threat: float = 0.0
	for e in enemies:
		if e == null or not is_instance_valid(e):
			continue
		# Boss/master/command 标签优先
		if e.has_meta("target_priority_tag"):
			var tag = String(e.get_meta("target_priority_tag", ""))
			if tag in ["boss", "master", "command"]:
				return e
		var s = e.get("stats") as UnitStats
		if s != null:
			var threat: float = float(s.attack_light) + float(s.attack_armor) + float(s.attack_air)
			if threat > best_threat:
				best_threat = threat
				best = e
	return best if best != null else enemies[0]

func _find_lowest_hp(enemies: Array) -> Node2D:
	var best: Node2D = null
	var best_hp: float = INF
	for e in enemies:
		if e == null or not is_instance_valid(e):
			continue
		var hp: float = float(e.hp) if "hp" in e else INF
		if hp < best_hp:
			best_hp = hp
			best = e
	return best

## 对单位施加 debuff（复用现有标记机制）
func _apply_debuff_to_unit(unit: Node2D, effect: Dictionary) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	var debuff: String = effect.get("debuff", "")
	var duration: float = float(effect.get("duration", 5.0))
	var dps: float = float(effect.get("dps", 0.0))
	var vuln: float = float(effect.get("vulnerability_bonus", 0.0))
	var slow_move: float = float(effect.get("move_speed_mult", 1.0))
	var slow_atk: float = float(effect.get("attack_speed_mult", 1.0))
	var atk_pen: float = float(effect.get("value", 0.0))
	var crit_bonus: float = float(effect.get("crit_mark_bonus", 0.0))
	match debuff:
		"mark":
			# 易伤标记（复用 _marked_until）
			if vuln > 0.0:
				unit.set_meta("_marked_until", Time.get_ticks_msec() + int(duration * 1000))
				unit.set_meta("_mark_vuln_bonus", vuln)
		"crit_mark":
			# 暴击标记
			if crit_bonus > 0.0:
				unit.set_meta("_crit_marked_until", Time.get_ticks_msec() + int(duration * 1000))
				unit.set_meta("_crit_mark_bonus", crit_bonus)
		"burn_mark":
			# 燃烧标记（持续伤害+减速）
			unit.set_meta("_marked_until", Time.get_ticks_msec() + int(duration * 1000))
			unit.set_meta("_mark_vuln_bonus", vuln)
			unit.set_meta("_burn_dps", dps)
			unit.set_meta("_burn_until", Time.get_ticks_msec() + int(duration * 1000))
		"minefield_damage":
			# 矿场伤害（通过 _incoming_damage_mul 机制）
			if dps > 0.0 and unit.has_method("take_damage"):
				unit.take_damage(dps * 0.5, null)  # 单次伤害（持续由调用方周期触发）
		"slow_aura":
			# 慢速光环
			unit.set_meta("_slow_aura_until", Time.get_ticks_msec() + int(duration * 1000))
			unit.set_meta("_slow_aura_mult", slow_move)
		"attack_speed_penalty":
			# 攻速惩罚（用于 EMP）
			unit.set_meta("_atk_speed_penalty_until", Time.get_ticks_msec() + int(duration * 1000))
			unit.set_meta("_atk_speed_penalty_mult", 1.0 + atk_pen)  # atk_pen 为负值
		"armor_break":
			# 破甲
			unit.set_meta("_armor_break_until", Time.get_ticks_msec() + int(duration * 1000))
			unit.set_meta("_armor_break_ratio", 0.25)
		_:
			pass

## 判断单位是否匹配目标过滤器
func _matches_target_filter(unit: Node2D, filter: String) -> bool:
	match filter:
		"all_allies":
			return true
		"fort_kind":
			var s = unit.get("stats") as UnitStats
			return s != null and int(s.combat_kind) == GC.CombatKind.FORT
		"mechanical_tag":
			var tags: Array = unit.get("_behavior_tags_cached") if unit.get("_behavior_tags_cached") != null else []
			return "mechanical" in tags
		_:
			return true

## 应用临时 stat_bonus（写入 meta，由 construct_unit 读取并定期清除）
func _apply_temporary_stat_bonus(unit: Node2D, stat_bonus: Dictionary, duration: float) -> void:
	if stat_bonus.is_empty():
		return
	unit.set_meta("_card_skill_stat_bonus", stat_bonus.duplicate(true))
	unit.set_meta("_card_skill_stat_bonus_until", Time.get_ticks_msec() + int(duration * 1000))

## v8.x 视觉反馈：技能触发时弹 Toast（防御性访问，兼容 --script 测试）
## ultimate=true → 红色 + 2.0s（大招醒目）；false → 金色 + 1.2s（普通技轻量，避免刷屏）
## 直接调 ToastManager.show_toast(message, duration, color) 而非 emit 信号——
## SignalBus.show_toast 只声明 1 参（message），不支持传颜色/时长；ToastManager 预加载后战斗时存活。
func _emit_skill_toast(skill: Dictionary, ultimate: bool = true) -> void:
	var UnlockLabelsRef = preload("res://data/unlock_labels.gd")
	var skill_id: String = String(skill.get("id", ""))
	var label: Dictionary = UnlockLabelsRef.get_unlock_label("card_skill", skill_id)
	var name: String = String(label.get("name", skill_id))
	var icon: String = String(label.get("icon", "💥"))
	var toast_msg: String = "%s 触发：%s" % [icon, name]
	var dur: float = 2.0 if ultimate else 1.2
	var color: Color = Color(0.9, 0.2, 0.2) if ultimate else Color(0.95, 0.75, 0.2)
	# 优先直接调 ToastManager（支持 duration/color 参数）
	var tree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var tm = tree.root.get_node_or_null("/root/ToastManager")
		if tm != null and tm.has_method("show_toast"):
			tm.show_toast(toast_msg, dur, color)
			return
	# 兜底：ToastManager 未就绪时降级走 SignalBus（单参 message，颜色用默认）
	var sb = tree.root.get_node_or_null("/root/SignalBus") if tree != null else null
	if sb != null and sb.has_signal("show_toast"):
		sb.show_toast.emit(toast_msg)


# ─────────────────────────────────────────────
#  v8.x VFX：大招专属视觉反馈
#  复用 VfxImpactFactory / PhaseLawCastEffect / BattleSpectacle（phase_instrument_ability_triggered 信号）
#  按 effect.vfx 字段精确分发（避免给 heaven_thunder/annihilate 误播核爆视觉）
# ─────────────────────────────────────────────

## 终极技能通用反馈：屏幕震动（所有大招至少有震屏+Toast）。Battlefield.gd:request_screen_shake 现成入口。
func _play_ultimate_shake() -> void:
	if _battlefield == null or not is_instance_valid(_battlefield):
		return
	if _battlefield.has_method("request_screen_shake"):
		_battlefield.request_screen_shake(8.0, 0.5)

## 范围伤害 VFX（artillery_barrage 范式：橙色警告标记 → 延迟 0.4s → 冲击波+爆炸）。
## 纯视觉，伤害即时结算不变。仿 phase_instrument_abilities._fire_artillery_shot_enemy 的 captured_pos+tween 范式。
func _play_area_damage_vfx(center_pos: Vector2, radius: float) -> void:
	if _battlefield == null or not is_instance_valid(_battlefield):
		return
	# 第一阶段：橙色警告标记
	PhaseLawCastEffect.create_phase_law_effect(_battlefield, center_pos, Color(1.0, 0.5, 0.2, 1.0))
	# 第二阶段：延迟爆炸（captured_pos 为值类型，延迟期间安全）
	var captured_pos: Vector2 = center_pos
	var captured_radius: float = radius
	var tw = _battlefield.create_tween()
	tw.tween_interval(0.4)
	tw.tween_callback(func():
		if _battlefield == null or not is_instance_valid(_battlefield):
			return
		VfxImpactFactory.spawn_shockwave(_battlefield, captured_pos, captured_radius, Color(1.0, 0.6, 0.2, 0.85))
		VfxImpactFactory.spawn_layered_impact(_battlefield, captured_pos, 3, true, -1)
	)

## 全图伤害 VFX（nuclear_bombardment：复用 BattleSpectacle 全屏红预警+白闪+极限震）。
## emit phase_instrument_ability_triggered 信号，warning 即时、impact 延迟 0.6s。
func _play_global_damage_vfx(first_pos: Vector2) -> void:
	var sb = Engine.get_main_loop().root.get_node_or_null("/root/SignalBus")
	if sb == null or not sb.has_signal("phase_instrument_ability_triggered"):
		return
	# warning 阶段 → BattleSpectacle._play_nuclear_warning（红屏+标题）
	sb.phase_instrument_ability_triggered.emit("nuclear_bombardment", "warning", {"position": first_pos, "is_enemy": false})
	# impact 阶段延迟 → _play_nuclear_impact（白闪+极限震）
	var captured_pos: Vector2 = first_pos
	if _battlefield == null or not is_instance_valid(_battlefield):
		return
	var tw = _battlefield.create_tween()
	tw.tween_interval(0.6)
	tw.tween_callback(func():
		var sb2 = Engine.get_main_loop().root.get_node_or_null("/root/SignalBus")
		if sb2 != null and sb2.has_signal("phase_instrument_ability_triggered"):
			sb2.phase_instrument_ability_triggered.emit("nuclear_bombardment", "impact", {"position": captured_pos, "is_enemy": false})
	)

## 单体减益 VFX：emp_blast 无现成特效，降级紫色冲击波（仿 battle_spectacle jamming_field）；其它 mark 类走橙色警告。
func _play_debuff_vfx(target_pos: Vector2, vfx_name: String) -> void:
	if _battlefield == null or not is_instance_valid(_battlefield):
		return
	match vfx_name:
		"emp_blast":
			VfxImpactFactory.spawn_shockwave(_battlefield, target_pos, 60.0, Color(0.6, 0.3, 0.9, 0.85))
		_:
			PhaseLawCastEffect.create_phase_law_effect(_battlefield, target_pos, Color(1.0, 0.5, 0.2, 1.0))
