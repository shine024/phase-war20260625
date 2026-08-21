extends RefCounted
class_name AttackCalculator
## v5.0: 攻速分离计算 + 伤害公式

const GC = preload("res://resources/game_constants.gd")
const DamageAttenuation = preload("res://scripts/battle/damage_attenuation.gd")
const CombatTargeting = preload("res://scripts/combat_targeting.gd")

## 默认攻速值（当攻速为0或负数时使用）
const DEFAULT_ATTACK_SPEED: float = 1.0

## 根据目标类型获取攻击值
## 目标轻甲→attack_light, 装甲→attack_armor, 空中→attack_air
## v6.6: FORT 目标额外叠加 attack_fort_bonus（对堡垒特攻改造，如温压弹/爆破装置）
## v8: LIGHT/AIR 目标叠加兵种固定机制加成（装甲碾压/防空空域封锁）
## v8.x: 三维攻防系统保持封闭（LIGHT/ARMOR/AIR），新兵种差异化加成走 TAG_COUNTER_RULES 标签层
##       （由 bullet.gd 调用 compute_tag_counter_multiplier），不在此处扩展。
static func get_attack_vs(attacker_stats: UnitStats, target_combat_kind: int) -> float:
	match target_combat_kind:
		GC.CombatKind.LIGHT: return attacker_stats.attack_light * (1.0 + attacker_stats.attack_light_bonus)  # 轻装 + 装甲碾压
		GC.CombatKind.ARMOR: return attacker_stats.attack_armor
		GC.CombatKind.AIR: return attacker_stats.attack_air * (1.0 + attacker_stats.attack_air_bonus)  # 空中 + 防空封锁
		GC.CombatKind.SUPPORT: return attacker_stats.attack_light * (1.0 + attacker_stats.attack_light_bonus)  # 支援按轻装算 + 装甲碾压
		GC.CombatKind.FORT: return attacker_stats.attack_armor * (1.0 + attacker_stats.attack_fort_bonus)  # 堡垒按装甲 + 对堡垒特攻
		_: return attacker_stats.attack_light

## 根据攻击者单位类型获取目标对应防御值（v6.2: 攻防维度对齐）
## 防御维度与攻击维度对齐——按"攻击者的单位类型"选目标防御值：
## defense_light = 防轻装单位(LIGHT/SUPPORT)攻击
## defense_armor = 防装甲单位(ARMOR/FORT)攻击
## defense_air   = 防空中单位(AIR)攻击
## v8.x: 三维攻防系统保持封闭，不新增 ENGINEER/SNIPER 分支
static func get_defense_vs(target_stats: UnitStats, attacker_combat_kind: int) -> float:
	match attacker_combat_kind:
		GC.CombatKind.LIGHT, GC.CombatKind.SUPPORT: return target_stats.defense_light
		GC.CombatKind.ARMOR, GC.CombatKind.FORT: return target_stats.defense_armor
		GC.CombatKind.AIR: return target_stats.defense_air
		_: return target_stats.defense_light  # 默认防轻装

## 完整伤害计算
## @deprecated v6.2: 简化版伤害计算，仅用于测试/验证器。
## 战斗主路径使用 calculate_damage_with_weapon（含穿透/词缀/武器系统）。
## 注意：本函数不应用直射穿透(piercing_shot)、词缀等战斗加成，
## 测试断言需知晓此差异。
static func calculate_damage(
	attacker_stats: UnitStats,
	target_stats: UnitStats,
	distance: float,  # 格
	weapon_type: int,
	attacker_enhance_level: int = 0,
	attacker_mods: Array = []
) -> float:
	# 1. 攻击值 = 根据目标类型选（目标轻甲→attack_light, 装甲→attack_armor, 空中→attack_air）
	var base_damage = get_attack_vs(attacker_stats, target_stats.combat_kind)

	# 2. 防御值 = 根据攻击者单位类型选（v6.2: 攻防维度对齐）
	var def = get_defense_vs(target_stats, attacker_stats.combat_kind)

	# 3. 射程衰减(仅直射) — v6.2: 直射已删除衰减设定，本块停用
#	if weapon_type == GC.WeaponType.DIRECT:
#		var max_range = distance  # 调用方需传入正确的max_range
#		var sub_type = DamageAttenuation.infer_weapon_sub_type(
#			attacker_stats.combat_kind, int(max_range),
#			attacker_stats.attack_light, attacker_stats.attack_armor, attacker_stats.attack_air
#		)
#		# Note: caller should pass max_range separately; using a helper
#		base_damage *= DamageAttenuation.calculate_attenuation(distance, max_range, sub_type)

	# 4. 防御减免: damage × 100/(100+def)
	var final_damage = base_damage * (100.0 / (100.0 + def))

	# 5. 强化加成(百分比)
	# Lv1-8: 1.0 + level × 0.05; Lv9: 1.50; Lv10: 1.60
	if attacker_enhance_level > 0:
		var enhance_mult: float
		if attacker_enhance_level >= 10:
			enhance_mult = 1.60  # Lv10
		elif attacker_enhance_level >= 9:
			enhance_mult = 1.50  # Lv9
		else:
			enhance_mult = 1.0 + float(attacker_enhance_level) * 0.05
		final_damage *= enhance_mult

	# v6.4: 改造伤害加成已由 ModificationRegistry.apply_with_level 在 UnitStats 构建阶段
	# 直接叠加到 attack_light/armor/air，此处无需再乘倍率。

	# v18 元素伤害维度：攻击方带元素亲和时乘元素乘区（防叠加超模，上限 2.0）
	if attacker_stats != null and attacker_stats.element_affinity != 0:
		final_damage *= minf(attacker_stats.element_damage_mult, 2.0)

	return final_damage

## @deprecated v6.2: 完整伤害计算（带max_range版），仅用于测试/验证器。
## 战斗主路径使用 calculate_damage_with_weapon。本函数不应用直射穿透等加成。
static func calculate_damage_with_range(
	attacker_stats: UnitStats,
	target_stats: UnitStats,
	distance: float,
	max_range: float,
	weapon_type: int,
	attacker_enhance_level: int = 0,
	attacker_mods: Array = []
) -> float:
	# 1. 攻击值 = 根据目标类型选
	var base_damage = get_attack_vs(attacker_stats, target_stats.combat_kind)

	# 2. 击穿检查 — 防御值 = 根据攻击者单位类型选（v6.2: 攻防维度对齐）
	var def = get_defense_vs(target_stats, attacker_stats.combat_kind)
	if base_damage <= def:
		return 0.0

	# 3. 射程衰减(仅直射) — v6.2: 直射已删除衰减设定，本块停用
#	if weapon_type == GC.WeaponType.DIRECT:
#		var sub_type = DamageAttenuation.infer_weapon_sub_type(
#			attacker_stats.combat_kind, int(max_range),
#			attacker_stats.attack_light, attacker_stats.attack_armor, attacker_stats.attack_air
#		)
#		base_damage *= DamageAttenuation.calculate_attenuation(distance, max_range, sub_type)

	# 4. 防御减免
	var final_damage = base_damage * (100.0 / (100.0 + def))

	# 5. 强化加成
	if attacker_enhance_level > 0:
		var enhance_mult: float
		if attacker_enhance_level >= 10:
			enhance_mult = 1.60
		elif attacker_enhance_level >= 9:
			enhance_mult = 1.50
		else:
			enhance_mult = 1.0 + float(attacker_enhance_level) * 0.05
		final_damage *= enhance_mult

	# v6.4: 改造伤害加成已由 ModificationRegistry.apply_with_level 在 UnitStats 构建阶段
	# 直接叠加到 attack_light/armor/air，此处无需再乘倍率。

	# v18 元素伤害维度：攻击方带元素亲和时乘元素乘区（防叠加超模，上限 2.0）
	if attacker_stats != null and attacker_stats.element_affinity != 0:
		final_damage *= minf(attacker_stats.element_damage_mult, 2.0)

	return final_damage

## 获取攻击计时参数（根据目标类型）
## 返回 { cycle, windup, active, cooldown }
static func get_attack_timing(attacker_stats: UnitStats, target_combat_kind: int) -> Dictionary:
	var speed: float = 1.0
	var windup: float = 0.2
	var active: float = 0.1

	match target_combat_kind:
		GC.CombatKind.LIGHT, GC.CombatKind.SUPPORT:
			speed = attacker_stats.attack_light_speed
			windup = attacker_stats.attack_light_windup
			active = attacker_stats.attack_light_active
		GC.CombatKind.ARMOR, GC.CombatKind.FORT:
			speed = attacker_stats.attack_armor_speed
			windup = attacker_stats.attack_armor_windup
			active = attacker_stats.attack_armor_active
		GC.CombatKind.AIR:
			speed = attacker_stats.attack_air_speed
			windup = attacker_stats.attack_air_windup
			active = attacker_stats.attack_air_active
		_:
			speed = attacker_stats.attack_light_speed
			windup = attacker_stats.attack_light_windup
			active = attacker_stats.attack_light_active

	if speed <= 0.0:
		speed = DEFAULT_ATTACK_SPEED

	# v7.x: 限制最高攻速倍率（防止过快导致卡顿和数值崩坏）
	var MAX_ATTACK_SPEED: float = 3.0
	if speed > MAX_ATTACK_SPEED:
		speed = MAX_ATTACK_SPEED

	var cycle = 1.0 / speed
	return {
		"cycle": cycle,
		"windup": windup,
		"active": active,
		"cooldown": maxf(0.0, cycle - windup - active),
		"speed": speed,
	}

## ─── 武器槽位系统支持 ───

## 根据目标类型获取对应武器
static func get_weapon_for_target(attacker_stats: UnitStats, target_combat_kind: int) -> WeaponResource:
	if attacker_stats == null or attacker_stats.weapon_slots.is_empty():
		return null

	# 优先使用新槽位系统
	if attacker_stats.has_method("get_weapon_for_target"):
		return attacker_stats.get_weapon_for_target(target_combat_kind)

	# 回退到旧系统（按索引映射）
	match target_combat_kind:
		GC.CombatKind.LIGHT, GC.CombatKind.SUPPORT:
			return attacker_stats.weapon_slots[0] if attacker_stats.weapon_slots.size() > 0 else null
		GC.CombatKind.ARMOR, GC.CombatKind.FORT:
			return attacker_stats.weapon_slots[1] if attacker_stats.weapon_slots.size() > 1 else null
		GC.CombatKind.AIR:
			return attacker_stats.weapon_slots[2] if attacker_stats.weapon_slots.size() > 2 else null
		_:
			return attacker_stats.weapon_slots[0] if attacker_stats.weapon_slots.size() > 0 else null

## 使用槽位武器计算伤害
## skip_defense_reduction: 跳过防御减免（格子战模式下，防御由CardGridDamage处理）
## is_card_grid: 格子战模式标识。格子战下射程衰减改用 range_falloff（保底30%，永不归零），
##   max_range 基准用 attacker_stats.attack_range（已含 era 缩放，与索敌判定一致）；
##   传统战场保持原 calculate_attenuation（按武器子类型衰减，可能归零）。
static func calculate_damage_with_weapon(
	attacker_stats: UnitStats,
	target_stats: UnitStats,
	distance: float,
	weapon: WeaponResource,
	attacker_enhance_level: int = 0,
	attacker_mods: Array = [],
	skip_defense_reduction: bool = false,
	is_card_grid: bool = false
) -> float:
	if weapon == null or not weapon.enabled:
		return 0.0

	var base_damage = weapon.damage

	# v6.2: 直射武器已删除攻击力衰减设定（格子战 range_falloff + 传统战场 DamageAttenuation 均不再生效）
	# 以下原衰减逻辑保留为注释，如需恢复可解开。
#	if weapon.weapon_type == GC.WeaponType.DIRECT:
#		if is_card_grid:
#			# 格子战：用 range_falloff 保底 30%，max_range 取 stats.attack_range
#			# （与索敌/状态机判定基准一致；weapon.range_value×100 对远端槽位 600~1200px 必归零）
#			var cg_max_range: float = attacker_stats.attack_range if attacker_stats != null else (float(weapon.range_value) * 100.0)
#			var falloff: Dictionary = CombatTargeting.range_falloff(distance, cg_max_range)
#			base_damage *= float(falloff.get("damage_mult", 1.0))
#		else:
#			# 传统战场：按武器子类型衰减（原逻辑）
#			var max_range = float(weapon.range_value) * 100.0
#			var sub_type = DamageAttenuation.infer_weapon_sub_type(
#				attacker_stats.combat_kind, weapon.range_value,
#				base_damage, base_damage, base_damage
#			)
#			base_damage *= DamageAttenuation.calculate_attenuation(distance, max_range, sub_type)

	# 防御减免（非格子战模式）
	var final_damage = base_damage
	# v10(C11): target_stats 可空（相位场/boss 等无 stats 目标）——不再依赖 skip 恒真掩盖
	if not skip_defense_reduction and target_stats != null:
		# 用攻击者单位类型决定穿透哪个防御值（v6.2: 攻防维度对齐）
		var def = get_defense_vs(target_stats, attacker_stats.combat_kind)
		# v7.x: 符文+相位仪穿透整合（使用统一上限 MAX_PENETRATION_RATIO）
		var pen_ratio: float = _get_rune_penetration_ratio(attacker_stats)
		# v6.6: 相位仪直射穿透能力（piercing_shot）— 追加穿透比例
		pen_ratio = clampf(pen_ratio + _get_instrument_piercing_ratio(attacker_stats), 0.0, MAX_PENETRATION_RATIO)
		if pen_ratio > 0.0:
			def = def * (1.0 - pen_ratio)
		final_damage = base_damage * (100.0 / (100.0 + def))

	# 强化加成（v7.x: 曲线优化，低等级回报提升，高等级更平滑）
	if attacker_enhance_level > 0:
		var enhance_mult: float
		if attacker_enhance_level >= 10:
			enhance_mult = 1.75  # v7.x: Lv10
		elif attacker_enhance_level >= 8:
			enhance_mult = 1.50  # v7.x: Lv8+
		else:
			enhance_mult = 1.0 + float(attacker_enhance_level) * 0.08  # v7.x: Lv1-7
		final_damage *= enhance_mult

	# v6.4: 改造伤害加成已由 ModificationRegistry.apply_with_level 在 UnitStats 构建阶段
	# 直接叠加到 attack_light/armor/air，此处无需再乘倍率。

	# v18 元素伤害维度：攻击方带元素亲和时乘元素乘区（防叠加超模，上限 2.0）
	# attacker_stats 可空（C11：相位场等无 stats 攻击者），守卫与上方 range 回退一致
	if attacker_stats != null and attacker_stats.element_affinity != 0:
		final_damage *= minf(attacker_stats.element_damage_mult, 2.0)

	return final_damage

## v8.x: 计算标签硬克制的伤害倍率（由 bullet.gd 在伤害结算时调用）
## attacker_tags: 攻击者标签数组（从 Node._behavior_tags_cached 或 stats meta 读取）
## target: 目标节点（用于读取 target_tags / target_priority_tag meta / casting meta）
## v9.2: 新增 out_result 按引用传入模式（消除每次 new Dictionary）；原无参重载保留向后兼容。
## 传 out_result 时清空并填充它（调用方复用成员字典），返回 out_result 本身；不传则内部 new（原行为）。
static func compute_tag_counter_multiplier(attacker_tags: Array, target: Node, out_result: Dictionary = {}) -> Dictionary:
	# v9.2: result 直接指向 out_result（调用方复用）或新建（向后兼容）
	var result: Dictionary = out_result if out_result != null else {}
	# 清空并填默认值（复用同一字典对象，避免 new）
	result.clear()
	result["mult"] = 1.0
	result["never_miss"] = false
	result["ignore_stealth"] = false
	result["bypass_damage_reduction"] = false
	# v10 解题式玩法：break_effect（打破型质变效果，由 bullet 结算点应用）+ accuracy_penalty
	result["break_effect"] = {}
	result["accuracy_penalty"] = 0.0
	if attacker_tags.is_empty() or target == null or not is_instance_valid(target):
		return result
	# 收集目标标签：优先 _behavior_tags_cached，其次 tags 属性，最后 meta target_priority_tag
	var target_tags: Array = []
	if "_behavior_tags_cached" in target:
		var t = target.get("_behavior_tags_cached")
		if t is Array:
			target_tags = t
	if target_tags.is_empty() and "tags" in target:
		var t2 = target.get("tags")
		if t2 is Array:
			target_tags = t2
	# v10 解题式玩法：巷战步兵派生 tag——装有巷战改造（urban_defense_bonus ≥ 0.5，
	# 如 inf_24_urban_warfare）的步兵视为"巷战步兵"，装甲对其命中率下降（打不中而非打不动）。
	# 天生 0.15 巷战掩蔽不算（巷战是改造选择的战法，不是免费 passive）。
	# 注意：target_tags 可能直接引用单位 _behavior_tags_cached（原逻辑只读安全），
	# 追加派生 tag 前必须复制，否则污染单位缓存数组。
	if "stats" in target and target.stats != null and "urban_defense_bonus" in target.stats:
		if float(target.stats.urban_defense_bonus) >= 0.5 and not target_tags.has("urban_infantry"):
			target_tags = target_tags.duplicate()
			target_tags.append("urban_infantry")
	# 高价值目标 meta（boss/master/command）
	var target_priority_tag: String = ""
	if target.has_meta("target_priority_tag"):
		target_priority_tag = String(target.get_meta("target_priority_tag", ""))
	# 遍历 TAG_COUNTER_RULES，匹配 attacker_tag
	# P1 性能优化：去掉 String() 强转（TAG_COUNTER_RULES 数据本就是 String 字面量，
	# 原每次命中每条规则做 3 次 Variant→String 转换），直接用 Variant 比较
	for rule in GC.TAG_COUNTER_RULES:
		var atk_tag = rule.get("attacker_tag", "")
		if not attacker_tags.has(atk_tag):
			continue
		# 检查目标条件
		var matched: bool = false
		# 条件1: target_tags 命中
		var rule_target_tags: Array = rule.get("target_tags", [])
		if not rule_target_tags.is_empty():
			for rtt in rule_target_tags:
				if target_tags.has(rtt) or target_priority_tag == rtt:
					matched = true
					break
		# 条件2: target_condition（is_casting 等）
		if not matched:
			var cond = rule.get("target_condition", "")
			if cond == "is_casting" and target.has_meta("_is_casting"):
				if bool(target.get_meta("_is_casting", false)):
					matched = true
		if not matched:
			continue
		# 应用效果
		var effect = rule.get("effect", "")
		var value: float = float(rule.get("value", 0.0))
		match effect:
			"damage_bonus":
				result["mult"] *= (1.0 + value)
			"splash_bonus":
				result["mult"] *= (1.0 + value)
			"bypass_front", "bypass_damage_reduction":
				result["bypass_damage_reduction"] = true
			"accuracy_penalty":
				# v10：巷战步兵被装甲攻击——命中率惩罚（打不中而非打不动，取最大值不叠加）
				result["accuracy_penalty"] = maxf(float(result["accuracy_penalty"]), value)
			_:
				pass
		# v10 打破型质变效果：同一轮结算可能命中多条规则，后命中不覆盖先命中（取首个非空）
		var break_fx: Dictionary = rule.get("break_effect", {})
		if break_fx is Dictionary and not break_fx.is_empty() and (result["break_effect"] is Dictionary) and (result["break_effect"] as Dictionary).is_empty():
			result["break_effect"] = break_fx
		# extra 标记
		var extra: Array = rule.get("extra", [])
		if extra.has("never_miss"):
			result["never_miss"] = true
		if extra.has("ignore_stealth"):
			result["ignore_stealth"] = true
	return result

## 获取槽位武器的攻击计时参数
static func get_weapon_attack_timing(weapon: WeaponResource) -> Dictionary:
	if weapon == null or not weapon.enabled:
		return {"cycle": 1.0, "windup": 0.2, "active": 0.1, "cooldown": 0.7, "speed": 1.0}

	var speed = weapon.attack_speed if weapon.attack_speed > 0 else DEFAULT_ATTACK_SPEED
	var cycle = 1.0 / speed
	return {
		"cycle": cycle,
		"windup": weapon.windup,
		"active": weapon.active,
		"cooldown": maxf(0.0, cycle - weapon.windup - weapon.active),
		"speed": speed,
	}

## 获取槽位武器的射程（米）
static func get_weapon_range(weapon: WeaponResource) -> float:
	if weapon == null:
		return 120.0
	return float(weapon.range_value) * 100.0

## 获取武器每秒射速（用于弹道路由决策）
static func get_weapon_speed(attacker_stats: UnitStats, weapon_resource: WeaponResource) -> float:
	if weapon_resource and weapon_resource.enabled:
		return float(weapon_resource.attack_speed) if weapon_resource.attack_speed > 0 else DEFAULT_ATTACK_SPEED
	if attacker_stats == null:
		return 1.0
	var speed: float = attacker_stats.attack_light_speed
	match attacker_stats.combat_kind:
		GC.CombatKind.ARMOR, GC.CombatKind.FORT:
			speed = attacker_stats.attack_armor_speed
		GC.CombatKind.AIR:
			speed = attacker_stats.attack_air_speed
	return speed if speed > 0.0 else DEFAULT_ATTACK_SPEED


## v10(H1): 攻速乘区统一入口——同步全部 timing 真实来源。
## 攻击节奏的实际计算走 weapon_slots[].attack_speed（get_weapon_attack_timing）与
## stats.attack_*_speed（get_attack_timing 兜底），单独改 stats.attack_interval 对有武器槽的
## 单位无效（此前多个系统的攻速效果因此空转，且率字段方向曾是反的）。
## 生成期攻速调整（势力技能注入/战法/敌方符文/符文之语/改造"弹药"光环）一律走本函数。
## speed_mult 为攻速"率"倍率（1.2 = +20% 提速）；interval 自动反向。
static func scale_attack_speeds(stats: UnitStats, speed_mult: float) -> void:
	if stats == null or speed_mult <= 0.0 or absf(speed_mult - 1.0) < 0.0001:
		return
	stats.attack_light_speed *= speed_mult
	stats.attack_armor_speed *= speed_mult
	stats.attack_air_speed *= speed_mult
	stats.attack_interval /= speed_mult
	for w in stats.weapon_slots:
		if w is WeaponResource and w.enabled:
			w.attack_speed = maxf(0.05, float(w.attack_speed) * speed_mult)


## v6.2: 从攻击者 UnitStats 的符文特殊效果中读取攻击穿透比例（0.0-1.0）
## 返回所有 on_attack_penetration 效果中的最大值
const MAX_PENETRATION_RATIO: float = 0.95  ## 穿透比例上限（v7.x: 0.9→0.95，允许接近完全穿透）
static func _get_rune_penetration_ratio(attacker_stats: UnitStats) -> float:
	if attacker_stats == null:
		return 0.0
	if not attacker_stats.has_meta("rune_specials"):
		return 0.0
	var specials = attacker_stats.get_meta("rune_specials")
	if not specials is Array:
		return 0.0
	var max_ratio: float = 0.0
	for sp in specials:
		if sp is Dictionary and sp.get("special", "") == "on_attack_penetration":
			max_ratio = maxf(max_ratio, float(sp.get("value", 0)) / 100.0)
	return clampf(max_ratio, 0.0, MAX_PENETRATION_RATIO)

## v6.6: 获取相位仪直射穿透能力的穿透比例（piercing_shot）
## 从 PhaseInstrumentAbilities 静态查询当前激活能力
static func _get_instrument_piercing_ratio(_attacker_stats: UnitStats) -> float:
	var ability: Dictionary = PhaseInstrumentAbilities.get_active_ability(PhaseInstrumentAbilities.Owner.PLAYER)
	if ability.is_empty() or String(ability.get("id", "")) != "piercing_shot":
		return 0.0
	var params: Dictionary = ability.get("params", {})
	return float(params.get("pen_ratio", 0.0))
