extends Node
## 模块化词条管理器（代码内部沿用 AffixManager 类名以避免大面积重命名）
## 设计文档中称为"模块化词条"，代码中 affix = 模块化词条（同义词）
## 全局自动加载节点，负责：
##   - 词条获取：卡牌升级到特定等级（Lv5/10/15/20/25/30）时触发强化
##   - 词条升级：强化时随机升级已有词条
##   - 词条重随：消耗纳米重新随机
##   - 词条锁定：消耗锁定符锁定
##   - 词条存档/读档

## [术语] affix = 模块化词条（同义词，设计文档用"模块化词条"）
signal affix_changed(card_id: String)
signal affix_acquired(card_id: String, affix: AffixResource)
signal affix_upgraded(card_id: String, affix: AffixResource)
signal affix_rerolled(card_id: String, slot_index: int)
signal affix_locked(card_id: String, slot_index: int)

## [术语] AffixDefs = 模块化词条定义表
const AffixDefs = preload("res://data/affix_definitions.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const GC = preload("res://resources/game_constants.gd")
const CardGrowthConfig = preload("res://data/card_growth_config.gd")

## affix_key → Array[AffixResource]（模块化词条实例列表）
## key格式: "{card_id}_{affix_type}" (affix_type: 0=机体, 1=武器)
var _card_affixes: Dictionary = {}

## 说明：已移除“锁定符”资源，锁定改为仅消耗纳米（在批量重随时计费）

## 已解锁的头目（用于词条库解锁）
var _unlocked_bosses: Array = []

## 强化触发等级（v18.c：30 级制 6 节点，旧 5 节点系统扩到 30）
const ENHANCE_TRIGGER_LEVELS: Array = [5, 10, 15, 20, 25, 30]

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
## identity 可为 instance_id（如 "cold_t72#1"，v7.x 实例化）或裸 card_id（旧卡兼容）。
## key 格式恒为 "{identity}_{type}"。调用方应优先传 instance_id。
func _get_affix_key(identity: String, affix_type: int) -> String:
	return "%s_%d" % [identity, affix_type]

## v7.x：统一身份解析——优先 instance_id（实例化养成隔离），空则回退 card_id（兼容旧卡/模板）。
## 所有"收 CardResource"的入口都用它派生 affix_key，确保同名卡（cold_t72#1/#2）词条各自独立。
func _card_identity(card: CardResource) -> String:
	if card == null:
		return ""
	if "instance_id" in card and not String(card.instance_id).is_empty():
		return String(card.instance_id)
	return String(card.card_id)

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
	# v7.x: 卡牌升级触发词条变化，刷新玩家相位师战力缓存避免面板陈旧
	_refresh_player_master_eval_safe()

## 蓝图升星时调用（新系统）
## 每升1星获得1个新词条
func on_blueprint_star_up(card_id: String, old_star: int, new_star: int) -> void:
	# v8.x: affix 改技能树赋予——升星不再随机获得词条，而是由技能树节点（intelligence 分支
	# 的 affix 解锁节点）统一赋予。本函数保留供旧调用方不崩，但不再主动随机 roll。
	# 具体赋予逻辑见 grant_skill_tree_affix_pool / on_card_level_up_instance。
	# 升星仍刷新玩家相位师战力缓存。
	_refresh_player_master_eval_safe()

## v18.c: 实例卡等级提升回调（InstanceRegistry._on_card_level_up 调用）
## 每 5 级一个词条节点（Lv5/10/15/20/25/30，共 6 个）：
## 空槽→roll 新词条（机体槽优先，满则落武器槽）；两类槽都满→尝试升级已有词条。
## 幂等守卫：已拥有词条数 ≥ 该等级应有个数（new_lv/5）时节点不再 roll——
## 防重复回调/越级重放（old_lv 失真）叠加出超额词条。
func on_card_level_up_instance(instance_id: String, old_lv: int, new_lv: int) -> void:
	if instance_id.is_empty() or new_lv <= old_lv:
		return
	# v19: 取兵种/档位上下文——兵种专属词条 roll 过滤用
	var ctx: Array = _combat_context_for_identity(instance_id)
	var combat_kind: int = int(ctx[0])
	var card_tier: int = int(ctx[1])
	var key_body: String = _get_affix_key(instance_id, 0)
	var key_weapon: String = _get_affix_key(instance_id, 1)
	var expected: int = clampi(new_lv / 5, 0, ENHANCE_TRIGGER_LEVELS.size())
	var allow_roll: bool = get_affix_count(key_body) + get_affix_count(key_weapon) < expected
	var changed: bool = false
	var _toast_msg: String = ""
	for lv in range(old_lv + 1, new_lv + 1):
		if not CardGrowthConfig.is_affix_milestone(lv):
			continue
		if allow_roll:
			if _roll_milestone_affix(key_body, 0, lv, combat_kind, card_tier):
				changed = true
				# v20: toast 通知——词条首次获得
				var _rarity: String = AffixDefs.roll_rarity_by_level(lv)
				var _aid: String = AffixDefs.roll_unlocked_affix_id(0, _rarity, _unlocked_bosses, combat_kind, card_tier)
				if _aid.is_empty():
					_aid = AffixDefs.roll_random_affix_id(0, _rarity, combat_kind, card_tier)
				var _def: Dictionary = AffixDefs.get_definition(_aid)
				if not _def.is_empty():
					_toast_msg = "获得词条：%s" % _def.get("affix_name", _aid)
				continue
			if _roll_milestone_affix(key_weapon, 1, lv, combat_kind, card_tier):
				changed = true
				var _rarity2: String = AffixDefs.roll_rarity_by_level(lv)
				var _aid2: String = AffixDefs.roll_unlocked_affix_id(1, _rarity2, _unlocked_bosses, combat_kind, card_tier)
				if _aid2.is_empty():
					_aid2 = AffixDefs.roll_random_affix_id(1, _rarity2, combat_kind, card_tier)
				var _def2: Dictionary = AffixDefs.get_definition(_aid2)
				if not _def2.is_empty():
					_toast_msg = "获得词条：%s" % _def2.get("affix_name", _aid2)
				continue
			allow_roll = false  # 两类槽都满：后续节点转升级
		# 槽满（或已达应有数）：节点转为升级已有词条的机会
		_try_upgrade_existing_affixes(key_body, 0)
		_try_upgrade_existing_affixes(key_weapon, 1)
		changed = true
	if changed:
		emit_signal("affix_changed", instance_id)
		_refresh_player_master_eval_safe()
		# v20: toast 通知（仅首次 roll 成功，upgrade 不 toast）
		if not _toast_msg.is_empty() and SignalBus:
			SignalBus.show_toast.emit(_toast_msg)

## v19: 按身份取实例卡（instance_id 优先；裸 card_id 回退首个实例；再回退只读模板）
## 供兵种/档位过滤读 combat_kind/tier——模板卡只读访问，不构成污染
func _get_instance_card_by_identity(identity: String) -> CardResource:
	if identity.is_empty():
		return null
	var ir: Node = _get_root_node_or_null("InstanceRegistry")
	if ir != null and ir.has_method("get_instance"):
		var inst: CardResource = ir.get_instance(identity) as CardResource
		if inst != null:
			return inst
	if ir != null and not identity.contains("#") and ir.has_method("get_instances_by_card_id"):
		var iids: Array = ir.get_instances_by_card_id(identity)
		if not iids.is_empty():
			var fallback: CardResource = ir.get_instance(String(iids[0])) as CardResource
			if fallback != null:
				return fallback
	return DefaultCards.get_card_by_id(identity)

## 从 affix_key/identity 解析兵种上下文（roll 过滤用；查不到卡回退 -1/0 = 通用池）
func _combat_context_for_identity(identity: String) -> Array:
	var ctx_card: CardResource = _get_instance_card_by_identity(identity)
	if ctx_card == null:
		return [-1, 0]
	return [int(ctx_card.combat_kind), int(ctx_card.tier)]

## v18.c: 词条节点 roll 新词条（返回是否成功放入空槽）
## v19: 新增 combat_kind/card_tier 参数——兵种专属词条按兵种分池、独特词条按档位门槛
func _roll_milestone_affix(affix_key: String, affix_type: int, level: int, combat_kind: int = -1, card_tier: int = 0) -> bool:
	if not has_empty_affix_slot(affix_key):
		return false
	var rarity: String = AffixDefs.roll_rarity_by_level(level)
	var affix_id: String = AffixDefs.roll_unlocked_affix_id(affix_type, rarity, _unlocked_bosses, combat_kind, card_tier)
	if affix_id.is_empty():
		affix_id = AffixDefs.roll_random_affix_id(affix_type, rarity, combat_kind, card_tier)
	if affix_id.is_empty():
		return false
	return _add_affix(affix_key, affix_id, rarity, 1)

## v8.x: 技能树解锁 affix 节点时调用，赋予固定词条池
## pool: 词条 ID 数组；target_identity: 可选，指定赋予给某实例，空则赋予给所有战斗卡
func grant_skill_tree_affix_pool(pool: Array, target_identity: String = "") -> void:
	if pool.is_empty():
		return
	# 若指定实例，只赋予该实例；否则赋予所有战斗卡实例（技能树全局解锁时）
	if not target_identity.is_empty():
		_grant_affix_to_identity(target_identity, pool)
	else:
		var ir: Node = _get_root_node_or_null("InstanceRegistry")
		if ir == null or not ir.has_method("get_all_instance_ids"):
			return
		for iid in ir.get_all_instance_ids():
			_grant_affix_to_identity(String(iid), pool)

## 内部：给单个 identity 赋予词条池中的一个（取第一个空槽能放的）
func _grant_affix_to_identity(identity: String, pool: Array) -> void:
	for affix_type in [0, 1]:
		var affix_key: String = _get_affix_key(identity, affix_type)
		if not has_empty_affix_slot(affix_key):
			continue
		# 从池中取一个尚未拥有的词条
		for affix_id in pool:
			if not _has_affix_id(affix_key, String(affix_id)):
				var affix: AffixResource = AffixDefs.build_affix(String(affix_id), "common", 1)
				if affix != null:
					if not _card_affixes.has(affix_key):
						_card_affixes[affix_key] = []
					(_card_affixes[affix_key] as Array).append(affix)
					emit_signal("affix_acquired", identity, affix)
				break
		break  # 每次 grant 只填一个类型的一个槽

## 检查某卡是否已拥有指定 affix_id
func _has_affix_id(affix_key: String, affix_id: String) -> bool:
	for a in _get_affix_array(affix_key):
		if a is AffixResource and a.affix_id == affix_id:
			return true
	return false

## 根据等级获取强化次数
func _get_enhance_count_for_level(level: int) -> int:
	for i in range(ENHANCE_TRIGGER_LEVELS.size() - 1, -1, -1):
		if level >= ENHANCE_TRIGGER_LEVELS[i]:
			return i + 1
	return 0

## 蓝图升星用的强化（基于星级和品质）
func _enhance_card_for_star(card_id: String, affix_type: int, star: int, rarity: String) -> void:
	var rolled_rarity: String = AffixDefs.roll_rarity_by_level(star)
	var ectx: Array = _combat_context_for_identity(card_id)
	var affix_id: String = AffixDefs.roll_unlocked_affix_id(affix_type, rolled_rarity, _unlocked_bosses, int(ectx[0]), int(ectx[1]))
	if affix_id.is_empty():
		affix_id = AffixDefs.roll_random_affix_id(affix_type, "", int(ectx[0]), int(ectx[1]))
	if affix_id.is_empty():
		return
	var affix_key: String = _get_affix_key(card_id, affix_type)
	_add_affix(affix_key, affix_id, rolled_rarity, 1)

## 执行强化：获取新词条
func _enhance_card(card_id: String, affix_type: int, card_level: int) -> void:
	# 计算稀有度（基于等级）
	var rarity: String = AffixDefs.roll_rarity_by_level(card_level)
	# v19: 兵种上下文（遗留入口对齐新分池逻辑）
	var ectx2: Array = _combat_context_for_identity(card_id)

	# 随机抽取词条ID（考虑已解锁的头目）
	var affix_id: String = AffixDefs.roll_unlocked_affix_id(affix_type, rarity, _unlocked_bosses, int(ectx2[0]), int(ectx2[1]))

	# 如果随机失败，尝试从所有可用词条中抽取
	if affix_id.is_empty():
		affix_id = AffixDefs.roll_random_affix_id(affix_type, "", int(ectx2[0]), int(ectx2[1]))

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

	# 从 affix_key 解析 affix_type（key 格式 "{identity}_{type}"，identity 可能含 _，故用 rfind）
	var sep_idx: int = affix_key.rfind("_")
	if sep_idx < 0:
		return false
	var affix_type: int = int(affix_key.substr(sep_idx + 1))
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
	# v19: 兵种上下文——重随也按本卡兵种分池（key 前段为 identity）
	var rctx: Array = _combat_context_for_identity(affix_key.substr(0, sep_idx))
	var new_affix_id: String = AffixDefs.roll_unlocked_affix_id(affix_type, rarity, _unlocked_bosses, int(rctx[0]), int(rctx[1]))

	if new_affix_id.is_empty():
		new_affix_id = AffixDefs.roll_random_affix_id(affix_type, rarity, int(rctx[0]), int(rctx[1]))

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
	# v7.x: 词条变化影响第 4 层加成，刷新玩家相位师战力缓存
	_refresh_player_master_eval_safe()
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

	# 从 affix_key 解析 affix_type（0=机体, 1=武器）。identity 可能含 _，故用 rfind
	var sep_idx: int = affix_key.rfind("_")
	if sep_idx < 0:
		return false
	var affix_type: int = int(affix_key.substr(sep_idx + 1))
	# v19: 兵种上下文——批量重随同样按本卡兵种分池
	var bctx: Array = _combat_context_for_identity(affix_key.substr(0, sep_idx))

	for i in range(affixes.size()):
		var affix: AffixResource = affixes[i] as AffixResource
		if affix.is_locked:
			continue
		var rarity: String = affix.rarity  # 同层池：保持不变
		var new_affix_id: String = AffixDefs.roll_unlocked_affix_id(affix_type, rarity, _unlocked_bosses, int(bctx[0]), int(bctx[1]))
		if new_affix_id.is_empty():
			new_affix_id = AffixDefs.roll_random_affix_id(affix_type, rarity, int(bctx[0]), int(bctx[1]))
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
	# v7.x: 批量词条变化影响第 4 层加成，刷新玩家相位师战力缓存
	_refresh_player_master_eval_safe()
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

func _get_card_level_from_card_id(_card_id: String) -> int:
	# 2026-08-22：原 BlueprintManager.get_blueprint_level（星级废弃后恒 1）已移除；词条构建按等级 1 处理
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

func _seed_initial_affixes(card_id: String, affix_type: int, _rarity: String) -> void:
	_seed_affixes_by_star(card_id, affix_type, 1)

func _seed_affixes_by_star(card_id: String, affix_type: int, star: int) -> void:
	var affix_key: String = _get_affix_key(card_id, affix_type)
	var current_count: int = get_affix_count(affix_key)
	var target_count: int = star
	# v19: 兵种上下文——初始播种词条同样按本卡兵种分池
	var sctx: Array = _combat_context_for_identity(card_id)
	for i in range(target_count - current_count):
		if not has_empty_affix_slot(affix_key):
			break
		var rarity: String = AffixDefs.roll_rarity_by_level(star)
		var affix_id: String = AffixDefs.roll_unlocked_affix_id(affix_type, rarity, _unlocked_bosses, int(sctx[0]), int(sctx[1]))
		if affix_id.is_empty():
			affix_id = AffixDefs.roll_random_affix_id(affix_type, rarity, int(sctx[0]), int(sctx[1]))
		if affix_id.is_empty():
			continue
		_add_affix(affix_key, affix_id, rarity, 1)

func grant_initial_affixes_for_card(card: CardResource) -> void:
	if card == null or card.card_id.is_empty():
		return
	# v5.1: star_level deprecated, use fixed star=1
	var star: int = 1
	# v7.x: 词条按实例隔离——用 instance_id 作 identity（空回退 card_id）
	var identity: String = _card_identity(card)
	# 双轨统一：所有可强化卡都具有机体/武器两套词条槽，数量按总星级一致
	_seed_affixes_by_star(identity, 0, star)
	_seed_affixes_by_star(identity, 1, star)

func _get_root_node_or_null(node_name: String) -> Node:
	if node_name.is_empty():
		return null
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var tree: SceneTree = loop as SceneTree
		if tree.root != null:
			return tree.root.get_node_or_null(node_name)
	return null

# v7.x: 安全刷新玩家相位师战力缓存（词条变化影响第 4 层加成，避免面板显示陈旧缓存）
func _refresh_player_master_eval_safe() -> void:
	var pm: Node = _get_root_node_or_null("PhaseInstrumentManager")
	if pm != null and pm.has_method("refresh_player_master_eval"):
		pm.refresh_player_master_eval()

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
	# v7.x 存档守卫：旧档/损坏档 unlocked_bosses 类型异常（非 Array）时回退空数组，
	# 防止 .duplicate() 在 null 上崩溃导致整个 load_state 抛错丢失该 manager 状态。
	var ub = data.get("unlocked_bosses", [])
	_unlocked_bosses = ub.duplicate() if ub is Array else []

	# v7.x 迁移：旧存档 affix_key = "{card_id}_{type}"（按 card_id 共享）。
	# 实例化后应为 "{instance_id}_{type}"。检测 identity 不含 # 的旧 key，
	# 按 card_id 查 InstanceRegistry 取首个实例重写 key；无实例则保留原 key 兜底（不丢数据）。
	var ir: Node = _get_root_node_or_null("InstanceRegistry")

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
		if affixes.is_empty():
			continue

		# 解析 key 的 identity 与 type（用 rfind 防 identity 含 _）
		var sep_idx: int = affix_key.rfind("_")
		if sep_idx < 0:
			_card_affixes[affix_key] = affixes
			continue
		var old_identity: String = affix_key.substr(0, sep_idx)
		var type_str: String = affix_key.substr(sep_idx + 1)

		# identity 已含 #（已是实例化格式）→ 直接用
		# identity 不含 #（旧格式）→ 查 InstanceRegistry 取首个实例重写
		var new_identity: String = old_identity
		if not old_identity.find("#") >= 0 and ir != null and ir.has_method("get_instances_by_card_id"):
			var iids: Array = ir.get_instances_by_card_id(old_identity)
			if not iids.is_empty():
				new_identity = str(iids[0])
		# 无实例时 new_identity 保持 old_identity（裸 card_id 兜底，词条不丢）

		var new_key: String = "%s_%s" % [new_identity, type_str]
		_card_affixes[new_key] = affixes

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
		"lifesteal":  # 词条 id（存档键）不改；效果已改为击杀修复
			stats.has_kill_repair_mutation = true
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
		var platform_key: String = _get_affix_key(_card_identity(platform_card), 0)
		_apply_card_affixes(stats, platform_key)

	# 武器卡词条 (affix_type = 1)
	for wc_raw in weapon_cards:
		if not wc_raw is CardResource:
			continue
		var wc: CardResource = wc_raw
		if wc.card_id.is_empty():
			continue
		var weapon_key: String = _get_affix_key(_card_identity(wc), 1)
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
					if w == null:
						continue
					if w.has("damage"):
						w["damage"] = float(w["damage"]) * (1.0 + val)
						stats.weapons[i] = w
			"attack_range":
				stats.attack_range *= (1.0 + val)
				for i in range(stats.weapons.size()):
					var w: Dictionary = stats.weapons[i] as Dictionary
					if w == null:
						continue
					if w.has("range"):
						w["range"] = float(w["range"]) * (1.0 + val)
						stats.weapons[i] = w
			"attack_interval":
				# val 表示缩短比例，攻击间隔 * (1 - val)
				var factor: float = maxf(0.1, 1.0 - val)
				stats.attack_interval *= factor
				for i in range(stats.weapons.size()):
					var w: Dictionary = stats.weapons[i] as Dictionary
					if w == null:
						continue
					if w.has("interval"):
						w["interval"] = float(w["interval"]) * factor
						stats.weapons[i] = w
			"damage_reduction":
				stats.damage_reduction = minf(0.75, stats.damage_reduction + val)
			"crit_chance":
				stats.crit_chance = minf(0.75, stats.crit_chance + val)
			"kill_repair":
				stats.kill_repair = minf(0.60, stats.kill_repair + val)
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
			"defense":
				# v19 修复：原 AFFIX_TABLE 有 defense 词条（复合装甲）但 apply 无分支，roll 到不生效。
				# 写法对齐 CardGrowthConfig.apply_to_stats：主防御 + 三维防御同加。
				stats.defense += val
				stats.defense_light += val
				stats.defense_armor += val
				stats.defense_air += val
			"dodge_chance":
				# v19 修复：闪避词条空转（UnitStats.dodge_chance 已被战斗侧消费，air_08 等 mod 同字段在写）
				stats.dodge_chance = minf(0.60, stats.dodge_chance + val)
			"crit_damage_bonus":
				# v19 修复：暴伤词条空转（stat_boost_manager 同字段已在写，暴击结算读此值）
				stats.crit_damage_bonus += val
			"intercept_chance":
				# v21 P3-B（计划 C3）：相位格挡词条——拦截/格挡字段此前无词条分支。
				# 消费点已有：module_effect_handler 拦截判定（stats.intercept_chance 概率格挡），
				# 与 APS 拦截改造同字段；上限 0.75 对齐 ModificationRegistry 同字段钳制。
				stats.intercept_chance = minf(0.75, stats.intercept_chance + val)

		# 标记变异词条
		if affix.is_mutated:
			_mark_mutation_on_stats(stats, affix.affix_id)
