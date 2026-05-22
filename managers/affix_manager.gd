extends Node
## 词条管理器（AffixManager）
## 全局自动加载节点，负责：
##   - 词条获取：卡牌升级到特定等级（Lv5/10/15/20/25）时触发强化
##   - 词条升级：强化时随机升级已有词条
##   - 词条重随：消耗纳米重新随机
##   - 词条锁定：消耗锁定符锁定
##   - 词条存档/读档

signal affix_changed(card_id: String)
signal affix_acquired(card_id: String, affix: AffixResource)
signal affix_upgraded(card_id: String, affix: AffixResource)
signal affix_rerolled(card_id: String, slot_index: int)
signal affix_locked(card_id: String, slot_index: int)

const AffixDefs = preload("res://data/affix_definitions.gd")
const GC = preload("res://resources/game_constants.gd")

## affix_key → Array[AffixResource]（实例词条列表）
## key格式: "{card_id}_{affix_type}" (affix_type: 0=机体, 1=武器)
var _card_affixes: Dictionary = {}

## 说明：已移除“锁定符”资源，锁定改为仅消耗纳米（在批量重随时计费）

## 已解锁的头目（用于词条库解锁）
var _unlocked_bosses: Array = []

## 强化触发等级（旧系统，保留兼容）
const ENHANCE_TRIGGER_LEVELS: Array = [5, 10, 15, 20, 25]

func get_unlocked_bosses() -> Array:
	return _unlocked_bosses.duplicate()

func unlock_boss(boss_id: String) -> void:
	if not _unlocked_bosses.has(boss_id):
		_unlocked_bosses.append(boss_id)
		# 旧：击败头目奖励锁定符（已移除）


# ─────────────────────────────────────────────
#  查询接口
# ─────────────────────────────────────────────

## 获取某强化类型的词条key
func _get_affix_key(card_id: String, affix_type: int) -> String:
	return "%s_%d" % [card_id, affix_type]

## 安全获取词条数组（防止存档数据类型异常导致崩溃）
func _get_affix_array(affix_key: String) -> Array:
	var raw = _card_affixes.get(affix_key, null)
	if raw is Array:
		return raw as Array
	return []

## 获取某卡的所有词条列表（兼容旧接口）
func get_card_affixes(affix_key: String) -> Array:
	return _get_affix_array(affix_key).duplicate()

## 获取某卡当前词条数量
func get_affix_count(affix_key: String) -> int:
	return _get_affix_array(affix_key).size()

## 某卡是否还有空余词条槽
func has_empty_affix_slot(affix_key: String) -> bool:
	return get_affix_count(affix_key) < AffixDefs.MAX_AFFIX_SLOTS

## 某卡是否已拥有指定词条
func has_affix(affix_key: String, affix_id: String) -> bool:
	for a in get_card_affixes(affix_key):
		if (a as AffixResource).affix_id == affix_id:
			return true
	return false

## 获取某卡某词条的当前等级（不存在则返回 0）
func get_affix_level(affix_key: String, affix_id: String) -> int:
	for a in get_card_affixes(affix_key):
		var affix: AffixResource = a as AffixResource
		if affix.affix_id == affix_id:
			return affix.level
	return 0

# ─────────────────────────────────────────────
#  词条获取逻辑（核心改动）
# ─────────────────────────────────────────────

## 卡牌升级时调用此方法
## card_id: 卡牌ID
## new_level: 新的等级
## affix_type: 0=机体强化, 1=武器强化
func on_card_level_up(card_id: String, new_level: int, affix_type: int) -> void:
	var affix_key: String = _get_affix_key(card_id, affix_type)
	
	# 检查是否达到强化触发等级
	var enhance_count: int = _get_enhance_count_for_level(new_level)
	var current_count: int = get_affix_count(affix_key)
	
	# 如果达到了新的强化节点
	if enhance_count > current_count and has_empty_affix_slot(affix_key):
		# 执行强化：获得新词条
		_enhance_card(card_id, affix_type, new_level)
	
	# 每次升级都有概率随机升级已有词条（即使是同等级强化）
	_try_upgrade_existing_affixes(affix_key, affix_type)

## 蓝图升星时调用（新系统）
## 每升1星获得1个新词条
func on_blueprint_star_up(card_id: String, old_star: int, new_star: int) -> void:
	if card_id.is_empty():
		return
	var bm: Node = _get_root_node_or_null("BlueprintManager")
	if bm == null:
		return
	var card: CardResource = null
	var DefaultCards = preload("res://data/default_cards.gd")
	if DefaultCards:
		card = DefaultCards.get_card_by_id(card_id)
	if card == null:
		return
	if card.card_type == GC.CardType.LAW:
		return  # 法则卡不走词条系统
	# 双轨统一：机体强化和武器强化均按总星级增长，词条数量口径一致
	for affix_type in [0, 1]:
		var affix_key: String = _get_affix_key(card_id, affix_type)
		for star in range(old_star + 1, new_star + 1):
			if not has_empty_affix_slot(affix_key):
				break
			var star_rarity: String = bm.get_card_rarity(card_id)
			_enhance_card_for_star(card_id, affix_type, star, star_rarity)
	emit_signal("affix_changed", card_id)

## 根据等级获取强化次数
func _get_enhance_count_for_level(level: int) -> int:
	for i in range(ENHANCE_TRIGGER_LEVELS.size() - 1, -1, -1):
		if level >= ENHANCE_TRIGGER_LEVELS[i]:
			return i + 1
	return 0

## 蓝图升星用的强化（基于星级和品质）
func _enhance_card_for_star(card_id: String, affix_type: int, star: int, rarity: String) -> void:
	var rolled_rarity: String = AffixDefs.roll_rarity_by_level(star)
	var affix_id: String = AffixDefs.roll_unlocked_affix_id(affix_type, rolled_rarity, _unlocked_bosses)
	if affix_id.is_empty():
		affix_id = AffixDefs.roll_random_affix_id(affix_type, "")
	if affix_id.is_empty():
		return
	var affix_key: String = _get_affix_key(card_id, affix_type)
	_add_affix(affix_key, affix_id, rolled_rarity, 1)

## 执行强化：获取新词条
func _enhance_card(card_id: String, affix_type: int, card_level: int) -> void:
	# 计算稀有度（基于等级）
	var rarity: String = AffixDefs.roll_rarity_by_level(card_level)
	
	# 随机抽取词条ID（考虑已解锁的头目）
	var affix_id: String = AffixDefs.roll_unlocked_affix_id(affix_type, rarity, _unlocked_bosses)
	
	# 如果随机失败，尝试从所有可用词条中抽取
	if affix_id.is_empty():
		affix_id = AffixDefs.roll_random_affix_id(affix_type, "")
	
	if affix_id.is_empty():
		return
	
	# 添加新词条
	var affix_key: String = _get_affix_key(card_id, affix_type)
	_add_affix(affix_key, affix_id, rarity, 1)

## 尝试升级已有词条
func _try_upgrade_existing_affixes(affix_key: String, affix_type: int) -> void:
	var affixes: Array = _get_affix_array(affix_key)
	if affixes.is_empty():
		return

	# 随机选择一个未锁定的词条尝试升级
	var upgradeable: Array = []
	for i in range(affixes.size()):
		var affix: AffixResource = affixes[i] as AffixResource
		if not affix.is_locked and affix.level < AffixDefs.MAX_AFFIX_LEVEL:
			upgradeable.append(i)
	
	if upgradeable.is_empty():
		return
	
	# 按概率升级
	if randf() < AffixDefs.AFFIX_UPGRADE_CHANCE:
		var idx: int = upgradeable[randi() % upgradeable.size()]
		_upgrade_affix_by_index(affix_key, idx)

## 根据索引升级词条
func _upgrade_affix_by_index(affix_key: String, slot_index: int) -> void:
	var affixes: Array = _get_affix_array(affix_key)
	if slot_index < 0 or slot_index >= affixes.size():
		return
	
	var affix: AffixResource = affixes[slot_index] as AffixResource
	if affix.is_locked or affix.level >= AffixDefs.MAX_AFFIX_LEVEL:
		return
	
	affix.level += 1
	affix.recalculate()
	
	# 检查变异
	if affix.level >= 5 and not affix.is_mutated:
		if randf() < AffixDefs.MUTATION_CHANCE:
			var mut: String = AffixDefs.get_mutation_description(affix.affix_id)
			if not mut.is_empty():
				affix.is_mutated = true
				affix.mutation_description = mut
	
	emit_signal("affix_upgraded", affix_key, affix)
	emit_signal("affix_changed", affix_key)

# ─────────────────────────────────────────────
#  词条重随
# ─────────────────────────────────────────────

## 重随指定槽位的词条
## 返回是否成功
func reroll_affix(affix_key: String, slot_index: int) -> bool:
	var affixes: Array = _get_affix_array(affix_key)
	if slot_index < 0 or slot_index >= affixes.size():
		return false
	
	var affix: AffixResource = affixes[slot_index] as AffixResource
	if affix.is_locked:
		return false
	
	# 从 affix_key 解析 card_id 和 affix_type
	var parts: Array = affix_key.split("_")
	if parts.size() < 2:
		return false
	var card_id: String = parts[0]
	var affix_type: int = int(parts[parts.size() - 1])
	# 旧实现会基于等级重新 roll 稀有度；新方案为“同层池”，保持该词条当前稀有度不变
	
	# 消耗纳米材料
	var cost: int = get_reroll_cost(slot_index)
	var bm: Node = _get_root_node_or_null("BlueprintManager")
	if bm == null or not bm.has_method("get_nano_materials"):
		return false
	if int(bm.get_nano_materials()) < cost:
		return false
	bm.add_nano_materials(-cost)
	
	# 重新随机词条
	var rarity: String = affix.rarity  # 同层池：保持不变
	var new_affix_id: String = AffixDefs.roll_unlocked_affix_id(affix_type, rarity, _unlocked_bosses)
	
	if new_affix_id.is_empty():
		new_affix_id = AffixDefs.roll_random_affix_id(affix_type, rarity)
	
	if new_affix_id.is_empty():
		return false
	
	# 替换词条
	affix.affix_id = new_affix_id
	var def: Dictionary = AffixDefs.get_definition(new_affix_id)
	if not def.is_empty():
		affix.affix_name = str(def.get("affix_name", new_affix_id))
		affix.description = str(def.get("description", ""))
		affix.affix_type = str(def.get("affix_type", "base_property"))
		affix.effect_key = str(def.get("effect_key", ""))
		affix.base_value = float(def.get("base_value", 0.0))
	affix.rarity = rarity
	affix.level = 1
	affix.is_mutated = false
	affix.mutation_description = ""
	affix.recalculate()
	
	emit_signal("affix_rerolled", affix_key, slot_index)
	emit_signal("affix_changed", affix_key)
	return true

## 获取重随消耗
func get_reroll_cost(slot_index: int) -> int:
	var idx: int = clampi(slot_index, 0, AffixDefs.REROLL_COSTS.size() - 1)
	return AffixDefs.REROLL_COSTS[idx]

## 能否重随
func can_reroll_affix(affix_key: String, slot_index: int) -> bool:
	var affixes: Array = _get_affix_array(affix_key)
	if slot_index < 0 or slot_index >= affixes.size():
		return false
	
	var affix: AffixResource = affixes[slot_index] as AffixResource
	if affix.is_locked:
		return false
	
	var cost: int = get_reroll_cost(slot_index)
	var bm: Node = _get_root_node_or_null("BlueprintManager")
	if bm and bm.has_method("get_nano_materials"):
		return int(bm.get_nano_materials()) >= cost
	return false

## 批量重随费用计算
## locked_count: 本次锁定的词条数量（按 is_locked=true 统计）
## base_cost: 本次将重随的槽位成本之和（使用 get_reroll_cost）
## extra_lock_cost: 额外锁定费用（纳米）
func get_batch_reroll_cost(affix_key: String) -> Dictionary:
	var affixes: Array = _get_affix_array(affix_key)
	if affixes.is_empty():
		return {"base_cost": 0, "extra_lock_cost": 0, "total_cost": 0, "locked_count": 0, "reroll_count": 0}
	var locked_count: int = 0
	var base_cost: int = 0
	for i in range(affixes.size()):
		var a: AffixResource = affixes[i] as AffixResource
		if a.is_locked:
			locked_count += 1
		else:
			base_cost += get_reroll_cost(i)
	var extra: int = 0
	if locked_count > 0 and base_cost > 0:
		var mult: float = AffixDefs.get_lock_multiplier(locked_count)
		extra = AffixDefs.round_to_10(float(base_cost) * mult)
	return {
		"base_cost": base_cost,
		"extra_lock_cost": extra,
		"total_cost": base_cost + extra,
		"locked_count": locked_count,
		"reroll_count": maxi(0, affixes.size() - locked_count),
	}

## 批量重随：重随所有未锁定词条（同层池：保持原词条 rarity 不变）
func batch_reroll_affixes(affix_key: String) -> bool:
	var affixes: Array = _get_affix_array(affix_key)
	if affixes.is_empty():
		return false

	var cost_info: Dictionary = get_batch_reroll_cost(affix_key)
	var total_cost: int = int(cost_info.get("total_cost", 0))
	var reroll_count: int = int(cost_info.get("reroll_count", 0))
	if reroll_count <= 0 or total_cost <= 0:
		return false

	var bm: Node = _get_root_node_or_null("BlueprintManager")
	if bm == null or not bm.has_method("get_nano_materials"):
		return false
	if int(bm.get_nano_materials()) < total_cost:
		return false
	bm.add_nano_materials(-total_cost)

	# 从 affix_key 解析 affix_type（0=机体, 1=武器）
	var parts: Array = affix_key.split("_")
	if parts.size() < 2:
		return false
	var affix_type: int = int(parts[parts.size() - 1])

	for i in range(affixes.size()):
		var affix: AffixResource = affixes[i] as AffixResource
		if affix.is_locked:
			continue
		var rarity: String = affix.rarity  # 同层池：保持不变
		var new_affix_id: String = AffixDefs.roll_unlocked_affix_id(affix_type, rarity, _unlocked_bosses)
		if new_affix_id.is_empty():
			new_affix_id = AffixDefs.roll_random_affix_id(affix_type, rarity)
		if new_affix_id.is_empty():
			continue

		affix.affix_id = new_affix_id
		var def: Dictionary = AffixDefs.get_definition(new_affix_id)
		if not def.is_empty():
			affix.affix_name = str(def.get("affix_name", new_affix_id))
			affix.description = str(def.get("description", ""))
			affix.affix_type = str(def.get("affix_type", "base_property"))
			affix.effect_key = str(def.get("effect_key", ""))
			affix.base_value = float(def.get("base_value", 0.0))
		affix.rarity = rarity
		affix.level = 1
		affix.is_mutated = false
		affix.mutation_description = ""
		affix.recalculate()
		emit_signal("affix_rerolled", affix_key, i)

	emit_signal("affix_changed", affix_key)
	return true

# ─────────────────────────────────────────────
#  词条锁定
# ─────────────────────────────────────────────

## 锁定指定槽位的词条
func lock_affix(affix_key: String, slot_index: int) -> bool:
	var affixes: Array = _get_affix_array(affix_key)
	if slot_index < 0 or slot_index >= affixes.size():
		return false
	
	var affix: AffixResource = affixes[slot_index] as AffixResource
	if affix.is_locked:
		return true  # 已经锁定就算成功

	affix.is_locked = true
	emit_signal("affix_locked", affix_key, slot_index)
	emit_signal("affix_changed", affix_key)
	return true

## 解锁指定槽位的词条（不消耗任何东西）
func unlock_affix(affix_key: String, slot_index: int) -> bool:
	var affixes: Array = _get_affix_array(affix_key)
	if slot_index < 0 or slot_index >= affixes.size():
		return false
	
	var affix: AffixResource = affixes[slot_index] as AffixResource
	affix.is_locked = false
	emit_signal("affix_changed", affix_key)
	return true

## 能否锁定
func can_lock_affix() -> bool:
	return true

# ─────────────────────────────────────────────
#  内部辅助
# ─────────────────────────────────────────────

func _add_affix(affix_key: String, affix_id: String, rarity: String, level: int) -> bool:
	var affix: AffixResource = AffixDefs.build_affix(affix_id, rarity, level)
	if affix == null:
		return false
	if not _card_affixes.has(affix_key):
		_card_affixes[affix_key] = []
	(_card_affixes[affix_key] as Array).append(affix)
	emit_signal("affix_acquired", affix_key, affix)
	emit_signal("affix_changed", affix_key)
	return true

func _get_card_level_from_card_id(card_id: String) -> int:
	# 从 BlueprintManager 获取卡牌等级
	var bm: Node = _get_root_node_or_null("BlueprintManager")
	if bm and bm.has_method("get_blueprint_level"):
		return int(bm.get_blueprint_level(card_id))
	return 1

func _initial_affix_target_count_by_rarity(rarity: String) -> int:
	match rarity:
		"uncommon":
			return 1
		"rare":
			return 2
		"legendary":
			return 3
		_:
			return 0

## 战斗胜利后为参战卡牌尝试奖励词条
func on_battle_won(card_ids: Array, level: int) -> void:
	for card_id in card_ids:
		if not card_id is String:
			continue
		var cid: String = card_id as String
		# 机体词条 (type 0)
		_seed_initial_affixes(cid, 0, "uncommon")
		# 武器词条 (type 1)
		_seed_initial_affixes(cid, 1, "uncommon")

func _seed_initial_affixes(card_id: String, affix_type: int, rarity: String) -> void:
	_seed_affixes_by_star(card_id, affix_type, 1)

func _seed_affixes_by_star(card_id: String, affix_type: int, star: int) -> void:
	var affix_key: String = _get_affix_key(card_id, affix_type)
	var current_count: int = get_affix_count(affix_key)
	var target_count: int = star
	for i in range(target_count - current_count):
		if not has_empty_affix_slot(affix_key):
			break
		var rarity: String = AffixDefs.roll_rarity_by_level(star)
		var affix_id: String = AffixDefs.roll_unlocked_affix_id(affix_type, rarity, _unlocked_bosses)
		if affix_id.is_empty():
			affix_id = AffixDefs.roll_random_affix_id(affix_type, rarity)
		if affix_id.is_empty():
			continue
		_add_affix(affix_key, affix_id, rarity, 1)

func grant_initial_affixes_for_card(card: CardResource) -> void:
	if card == null or card.card_id.is_empty():
		return
	var bm: Node = _get_root_node_or_null("BlueprintManager")
	var star: int = 1
	if bm and bm.has_method("get_blueprint_star"):
		star = bm.get_blueprint_star(card.card_id)
	# 双轨统一：所有可强化卡都具有机体/武器两套词条槽，数量按总星级一致
	_seed_affixes_by_star(card.card_id, 0, star)
	_seed_affixes_by_star(card.card_id, 1, star)

func _get_root_node_or_null(node_name: String) -> Node:
	if node_name.is_empty():
		return null
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var tree: SceneTree = loop as SceneTree
		if tree.root != null:
			return tree.root.get_node_or_null(node_name)
	return null

# ─────────────────────────────────────────────
#  存档接口
# ─────────────────────────────────────────────

func save_state() -> Dictionary:
	var result: Dictionary = {}
	for affix_key in _card_affixes.keys():
		var affixes: Array = _get_affix_array(affix_key)
		var arr: Array = []
		for a_raw in affixes:
			var a: AffixResource = a_raw as AffixResource
			arr.append(a.to_dict())
		result[affix_key] = arr
	result["unlocked_bosses"] = _unlocked_bosses.duplicate()
	return result

func load_state(data: Dictionary) -> void:
	_card_affixes.clear()
	_unlocked_bosses = data.get("unlocked_bosses", []).duplicate()
	
	for affix_key in data.keys():
		if affix_key == "unlocked_bosses":
			continue
		var raw_val = data[affix_key]
		if not raw_val is Array:
			continue
		var arr: Array = raw_val as Array
		var affixes: Array = []
		for raw in arr:
			if not raw is Dictionary:
				continue
			var d: Dictionary = raw as Dictionary
			var affix_id: String = str(d.get("affix_id", ""))
			var rarity: String = str(d.get("rarity", "common"))
			var lv: int = int(d.get("level", 1))
			var affix: AffixResource = AffixDefs.build_affix(affix_id, rarity, lv)
			if affix == null:
				continue
			affix.is_locked = bool(d.get("is_locked", false))
			if affix.is_mutated:
				affix.mutation_description = AffixDefs.get_mutation_description(affix_id)
			affixes.append(affix)
		if not affixes.is_empty():
			_card_affixes[affix_key] = affixes

func reset_to_defaults() -> void:
	_card_affixes.clear()
	_unlocked_bosses.clear()

# ─────────────────────────────────────────────
#  战斗效果应用
# ─────────────────────────────────────────────

## 标记 stats 中的变异词条
func _mark_mutation_on_stats(stats: UnitStats, affix_id: String) -> void:
	match affix_id:
		"weapon_dmg_up":
			stats.has_weapon_dmg_mutation = true
		"weapon_atkspd_up":
			stats.has_weapon_atkspd_mutation = true
		"crit_chance":
			stats.has_crit_mutation = true
		"lifesteal":
			stats.has_lifesteal_mutation = true
		"nano_regen":
			stats.has_hp_regen_mutation = true
		"platform_hp_up":
			stats.has_platform_hp_mutation = true

# ─────────────────────────────────────────────
#  战斗效果应用
# ─────────────────────────────────────────────

## 将参战卡牌的所有词条效果叠加到 UnitStats 上
## 在 BlueprintManager.apply_growth_to_stats 之后调用
func apply_affixes_to_stats(stats: UnitStats, platform_card: CardResource, weapon_cards: Array) -> void:
	if stats == null:
		return

	# 机体词条 (affix_type = 0)
	if platform_card != null and not platform_card.card_id.is_empty():
		var platform_key: String = _get_affix_key(platform_card.card_id, 0)
		_apply_card_affixes(stats, platform_key)

	# 武器卡词条 (affix_type = 1)
	for wc_raw in weapon_cards:
		if not wc_raw is CardResource:
			continue
		var wc: CardResource = wc_raw
		if wc.card_id.is_empty():
			continue
		var weapon_key: String = _get_affix_key(wc.card_id, 1)
		_apply_card_affixes(stats, weapon_key)

## 应用单张卡牌的词条到 stats
func _apply_card_affixes(stats: UnitStats, affix_key: String) -> void:
	var affixes: Array = _get_affix_array(affix_key)
	for a_raw in affixes:
		var affix: AffixResource = a_raw as AffixResource
		var val: float = affix.current_value
		match affix.effect_key:
			"max_hp":
				stats.max_hp *= (1.0 + val)
			"move_speed":
				stats.move_speed *= (1.0 + val)
			"attack_damage":
				stats.attack_damage *= (1.0 + val)
				# 同步 weapons 列表中的伤害
				for i in range(stats.weapons.size()):
					var w: Dictionary = stats.weapons[i] as Dictionary
					if w.has("damage"):
						w["damage"] = float(w["damage"]) * (1.0 + val)
						stats.weapons[i] = w
			"attack_range":
				stats.attack_range *= (1.0 + val)
				for i in range(stats.weapons.size()):
					var w: Dictionary = stats.weapons[i] as Dictionary
					if w.has("range"):
						w["range"] = float(w["range"]) * (1.0 + val)
						stats.weapons[i] = w
			"attack_interval":
				# val 表示缩短比例，攻击间隔 * (1 - val)
				var factor: float = maxf(0.1, 1.0 - val)
				stats.attack_interval *= factor
				for i in range(stats.weapons.size()):
					var w: Dictionary = stats.weapons[i] as Dictionary
					if w.has("interval"):
						w["interval"] = float(w["interval"]) * factor
						stats.weapons[i] = w
			"damage_reduction":
				stats.damage_reduction = minf(0.75, stats.damage_reduction + val)
			"crit_chance":
				stats.crit_chance = minf(0.75, stats.crit_chance + val)
			"lifesteal":
				stats.lifesteal = minf(0.60, stats.lifesteal + val)
			"splash_damage":
				stats.splash_damage = minf(0.80, stats.splash_damage + val)
			"armor_penetration":
				stats.armor_penetration = minf(0.80, stats.armor_penetration + val)
			"chain_chance":
				stats.chain_chance = minf(0.60, stats.chain_chance + val)
			"shield_on_kill":
				stats.shield_on_kill += val
			"hp_regen":
				stats.hp_regen += val
		
		# 标记变异词条
		if affix.is_mutated:
			_mark_mutation_on_stats(stats, affix.affix_id)
