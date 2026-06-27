extends Node
## 单张卡片强化系统 v6.0：强化 = 选择词条
##
## 核心机制：
## - 强化等级 1-10
## - 奇数级(Lv2/4/6/8/10) = 获得新词条槽，从池中选一个词条
## - 偶数级(Lv3/5/7/9) = 升级已有词条(Lv1→Lv2→Lv3)
## - Lv10 额外获得 +10% 全属性加成
## - 最终满配：5个词条(最高Lv3) + +10% 全属性
## - 能量卡和法则卡不可强化
## - 100% 成功率，消耗纳米材料
##
## 词条数据由 ModuleDefinitions 定义（16个词条，3层池）
## 词条槽位数据存储在 card.module_slots (Array[ModuleSlot])
## enhance_level 存储在 card.enhance_level

signal enhancement_started(card_id: String, target_level: int)
signal enhancement_completed(success: bool, card_id: String, action: String, message: String)
signal enhancement_failed(card_id: String, reason: String)
signal module_chosen(card_id: String, slot_index: int, module_id: String, level: int)
signal module_upgraded(card_id: String, slot_index: int, old_level: int, new_level: int)
signal module_reset(card_id: String, slot_index: int)

const GC = preload("res://resources/game_constants.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const ModuleDefinitions = preload("res://data/module_definitions.gd")

# 强化消耗配置（保留v5.0公式）
var enhancement_config: Dictionary = {
	1:  {"level_cost_multiplier": 0.5},
	2:  {"level_cost_multiplier": 1.0},
	3:  {"level_cost_multiplier": 1.5},
	4:  {"level_cost_multiplier": 2.0},
	5:  {"level_cost_multiplier": 2.5},
	6:  {"level_cost_multiplier": 3.0},
	7:  {"level_cost_multiplier": 3.5},
	8:  {"level_cost_multiplier": 4.0},
	9:  {"level_cost_multiplier": 5.0},
	10: {"level_cost_multiplier": 6.0},
}

## 固定基数
const ENHANCE_BASE_COST: int = 50

## 时代系数
const ERA_MULTIPLIER: Dictionary = {
	0: 0.5,   # WWI
	1: 1.0,   # WWII
	2: 2.0,   # 冷战
	3: 3.0,   # 现代
	4: 4.0,   # 近未来
}

## v6.0: 词条数据存储 — { card_id: Array[ModuleSlot] }
## 独立于 CardResource，因为 DefaultCards 返回的是模板数据，
## 实际强化状态需要持久化在单独字典中
var card_module_slots: Dictionary = {}

# ─────────────────────────────────────────────
#  生命周期
# ─────────────────────────────────────────────

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# v5.1: _load_state() removed, state loaded on demand

# ─────────────────────────────────────────────
#  查询接口
# ─────────────────────────────────────────────

## 获取卡牌当前强化等级
## v7.0: 参数改为 instance_id（实例化养成）；无 instance_id 时按 card_id 回退单例（兼容旧路径）
func get_card_enhancement_level(card_id_or_instance: String) -> int:
	var inst = _get_instance_card(card_id_or_instance)
	if inst != null:
		return maxi(inst.enhance_level, 0)
	# 回退：按 card_id 查模板（兼容未实例化场景）
	var template = DefaultCards.get_card_by_id(card_id_or_instance)
	if template != null:
		return maxi(template.enhance_level, 0)
	return 0

## v7.0: 按 instance_id 取实例对象（找不到返回 null）
## v7.4: 修复"强化面板词条槽显示空"——成长面板/情报中心可能传裸 card_id（无 #序号）进来，
## 此时 ir.get_instance(裸card_id) 必返回 null，导致 get_module_slots/get_card_enhancement_level
## 全部回退到空模板，已强化的卡词条槽全部显示"空"。
## 修复：裸 card_id 时回退取该 card_id 的第一个实例（养成数据挂在实例上）。
func _get_instance_card(id_str: String) -> CardResource:
	if id_str.is_empty():
		return null
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	if ir == null:
		return null
	# 1) 直接按 instance_id 查（含 #序号，正常路径）
	if ir.has_method("get_instance"):
		var inst: CardResource = ir.get_instance(id_str)
		if inst != null:
			return inst
	# 2) 兜底：id_str 是裸 card_id（无 #序号）时，取该 card_id 的第一个实例
	#    仅当 id_str 不含 #（避免把真实 instance_id 误当 card_id 反复回退）
	var hash_idx: int = id_str.rfind("#")
	if hash_idx < 0 and ir.has_method("get_instances_by_card_id"):
		var insts: Array = ir.get_instances_by_card_id(id_str)
		if not insts.is_empty():
			var first_id: String = String(insts[0])
			if not first_id.is_empty() and ir.has_method("get_instance"):
				var fallback_inst: CardResource = ir.get_instance(first_id)
				if fallback_inst != null:
					return fallback_inst
	return null

## 获取卡牌的词条槽位数组
## v7.0: 参数改为 instance_id；无实例时回退 card_module_slots[card_id]（兼容）
func get_module_slots(card_id_or_instance: String) -> Array:
	# 优先从实例对象读 module_slots
	var inst = _get_instance_card(card_id_or_instance)
	if inst != null:
		return inst.module_slots
	return card_module_slots.get(card_id_or_instance, [])

## 获取卡牌的当前有效词条（合并 BlueprintManager 中的）
func get_effective_module_slots(card_id: String) -> Array:
	return get_module_slots(card_id)

## 获取强化信息（UI用）
func get_enhancement_info(card_id: String) -> Dictionary:
	var current_level = get_card_enhancement_level(card_id)
	var slots = get_module_slots(card_id)

	var info: Dictionary = {
		"card_id": card_id,
		"current_level": current_level,
		"max_level": 10,
		"can_enhance": current_level < 10 and _is_combat_card(card_id),
		"max_slots": ModuleDefinitions.get_max_slots_for_level(current_level),
		"current_slots": slots,
		"level_action": ModuleDefinitions.get_level_action(current_level + 1) if current_level < 10 else "none",
	}

	if current_level < 10 and _is_combat_card(card_id):
		var target_level = current_level + 1
		info["next_level"] = target_level
		info["nano_cost"] = get_enhance_nano_cost(card_id, target_level)
		info["available_modules"] = ModuleDefinitions.get_available_modules(target_level)

	return info

## 获取词条效果摘要（用于UI属性预览）
func get_module_summary(card_id: String) -> Dictionary:
	var slots = get_module_slots(card_id)
	var level = get_card_enhancement_level(card_id)
	var slots_data: Array = []
	for s in slots:
		if s is ModuleSlot:
			slots_data.append(s.to_dict())
		elif s is Dictionary:
			slots_data.append(s)
	return ModuleDefinitions.get_module_summary(slots_data, level)

## 获取词条效果文本行（用于 info panel）
func get_module_effect_lines(card_id: String) -> Array:
	var summary = get_module_summary(card_id)
	return ModuleDefinitions.build_effect_lines(summary)

# ─────────────────────────────────────────────
#  判断工具
# ─────────────────────────────────────────────

## 是否为可强化的战斗卡
## v7.1: 参数可能是 instance_id（如 "cold_t72#1"），需先解析为 card_id 再查模板
func _is_combat_card(card_id_or_instance: String) -> bool:
	var base_id: String = card_id_or_instance
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	if ir != null and ir.has_method("get_card_id_of"):
		base_id = ir.get_card_id_of(card_id_or_instance)
	var card = DefaultCards.get_card_by_id(base_id)
	if card == null:
		return false
	return card.card_type == GC.CardType.COMBAT_UNIT

## 获取时代系数
func get_era_multiplier(era: int) -> float:
	return float(ERA_MULTIPLIER.get(clampi(era, 0, 4), 1.0))

## 计算强化消耗（纳米材料）
## v7.1: 参数可能是 instance_id，需先解析为 card_id 再查模板获取 era
func get_enhance_nano_cost(card_id_or_instance: String, target_level: int) -> int:
	var config = enhancement_config.get(target_level, {})
	var level_mult = float(config.get("level_cost_multiplier", 1.0))
	var base_id: String = card_id_or_instance
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	if ir != null and ir.has_method("get_card_id_of"):
		base_id = ir.get_card_id_of(card_id_or_instance)
	var card = DefaultCards.get_card_by_id(base_id)
	var era: int = 0
	if card != null:
		era = card.era
	var era_mult = get_era_multiplier(era)
	return int(ENHANCE_BASE_COST * level_mult * era_mult)

## 获取战力倍率
func get_power_multiplier(level: int) -> float:
	if level >= 9:
		return 1.50 if level == 9 else 1.60
	return 1.0 + level * 0.05

# ─────────────────────────────────────────────
#  强化操作
# ─────────────────────────────────────────────

## 检查能否强化
func can_enhance(card_id: String, nano_available: int) -> bool:
	if not _is_combat_card(card_id):
		return false
	var current_level = get_card_enhancement_level(card_id)
	if current_level >= 10:
		return false
	var target_level = current_level + 1
	return nano_available >= get_enhance_nano_cost(card_id, target_level)

## 执行强化升级（消耗纳米，提升等级）
## 返回 action: "new_slot" / "upgrade_slot" / "none"
## v7.0: 参数改为 instance_id；强化等级写到实例对象（不再污染 DefaultCards 单例）
## v7.3: 杜绝污染模板——_get_instance_card 返回 null 时不再回退到 DefaultCards 模板，
##   而是返回失败。原因：回退到模板后 card.enhance_level = target_level 会污染单例，
##   导致背包/装备读的实例（空）与强化的模板（有值）脱节，表现为"强化没生效"。
func do_enhance(card_id_or_instance: String, nano_available: int) -> Dictionary:
	if not can_enhance(card_id_or_instance, nano_available):
		return {"ok": false, "action": "none", "reason": "无法强化"}

	# v7.3: 强制要求实例——养成数据必须写到实例对象，禁止回退模板污染单例
	var card = _get_instance_card(card_id_or_instance)
	if card == null:
		push_warning("[CardEnhancementManager] do_enhance 找不到实例 '%s'，拒绝强化（避免污染模板）" % card_id_or_instance)
		return {"ok": false, "action": "none", "reason": "找不到卡牌实例，无法强化"}

	var current_level = get_card_enhancement_level(card_id_or_instance)
	var target_level = current_level + 1
	var nano_cost = get_enhance_nano_cost(card_id_or_instance, target_level)

	# 纳米消耗在调用方处理（UI统一扣费）
	card.enhance_level = target_level

	var action = ModuleDefinitions.get_level_action(target_level)

	emit_signal("enhancement_completed", true, card_id_or_instance, action,
		"强化成功！等级提升至 Lv.%d" % target_level)

	return {"ok": true, "action": action, "level": target_level}

## 选择词条（新槽位时调用）
## v7.0: 参数 card_id 实际是 instance_id；词条写到实例对象（不再污染单例）
## v6.13: 修复"吸血等进阶池(Lv6+)词条点了没反应" —— 原版重新读等级校验池，
## 但实例解析一旦出问题(时序/存档)会读到旧等级(0)，导致进阶池词条被误判"不在可用池中"。
## 弹窗 _show_module_selection_popup 已用 do_enhance 返回的正确等级拉取并展示词条，
## 数据层信任该池，不再重读等级校验（仅校验 module_id 合法性）。
func choose_module(card_id: String, module_id: String) -> Dictionary:
	var slots = get_module_slots(card_id)
	var level = get_card_enhancement_level(card_id)
	var max_slots = ModuleDefinitions.get_max_slots_for_level(level)

	# v6.13: 仅校验 module_id 是合法词条定义（不再重读等级做池校验）
	# —— 池校验已在弹窗层完成，避免实例解析时序问题导致进阶池词条被误拒
	if not ModuleDefinitions.is_valid_module(module_id):
		return {"ok": false, "reason": "无效词条"}

	# 找到第一个空槽位
	var slot_index: int = -1
	for i in range(max_slots):
		if i >= slots.size():
			slot_index = i
			break
		elif slots[i] == null or (slots[i] is Dictionary and slots[i].get("module_id", "") == ""):
			slot_index = i
			break
		elif slots[i] is ModuleSlot and slots[i].module_id.is_empty():
			slot_index = i
			break

	if slot_index < 0:
		slot_index = slots.size()

	# 确保数组够大
	while slots.size() <= slot_index:
		slots.append(null)

	var slot := ModuleSlot.new()
	slot.module_id = module_id
	slot.level = 1
	slot.slot_index = slot_index
	slots[slot_index] = slot
	_set_module_slots(card_id, slots)

	emit_signal("module_chosen", card_id, slot_index, module_id, 1)
	return {"ok": true, "slot_index": slot_index, "module_id": module_id, "level": 1}

## 升级已有词条（偶数级时调用）
func upgrade_module(card_id: String, slot_index: int) -> Dictionary:
	var slots = get_module_slots(card_id)
	if slot_index < 0 or slot_index >= slots.size():
		return {"ok": false, "reason": "无效槽位"}

	var slot = slots[slot_index]
	var old_level: int = 1
	if slot is ModuleSlot:
		if slot.module_id.is_empty():
			return {"ok": false, "reason": "空槽位"}
		if slot.level >= 3:
			return {"ok": false, "reason": "词条已满级"}
		old_level = slot.level
		slot.level += 1
		_set_module_slots(card_id, slots)  # v7.0: 同步到实例
		var new_level = slot.level
		emit_signal("module_upgraded", card_id, slot_index, old_level, new_level)
		return {"ok": true, "slot_index": slot_index, "module_id": slot.module_id,
			"old_level": old_level, "new_level": new_level}
	elif slot is Dictionary:
		var mid: String = slot.get("module_id", "")
		if mid.is_empty():
			return {"ok": false, "reason": "空槽位"}
		old_level = int(slot.get("level", 1))
		if old_level >= 3:
			return {"ok": false, "reason": "词条已满级"}
		slot["level"] = old_level + 1
		_set_module_slots(card_id, slots)  # v7.0: 同步到实例
		emit_signal("module_upgraded", card_id, slot_index, old_level, old_level + 1)
		return {"ok": true, "slot_index": slot_index, "module_id": mid,
			"old_level": old_level, "new_level": old_level + 1}

	return {"ok": false, "reason": "未知槽位格式"}

## 重置单个词条槽位
func reset_module(card_id: String, slot_index: int) -> Dictionary:
	var slots = get_module_slots(card_id)
	if slot_index < 0 or slot_index >= slots.size():
		return {"ok": false, "reason": "无效槽位"}

	slots[slot_index] = null
	# 清理尾部空槽位
	while slots.size() > 0 and slots[slots.size() - 1] == null:
		slots.pop_back()
	_set_module_slots(card_id, slots)  # v7.0: 同步到实例
	emit_signal("module_reset", card_id, slot_index)
	return {"ok": true}

## 全部重置（清空所有词条，保持强化等级）
func reset_all_modules(card_id: String) -> Dictionary:
	_set_module_slots(card_id, [])  # v7.0: 同步到实例
	emit_signal("module_reset", card_id, -1)
	return {"ok": true}

## v7.0: 统一写入词条槽位——有实例写实例对象，无实例写 card_module_slots 字典（兼容）
func _set_module_slots(card_id_or_instance: String, slots: Array) -> void:
	var inst = _get_instance_card(card_id_or_instance)
	if inst != null:
		inst.module_slots = slots
	else:
		card_module_slots[card_id_or_instance] = slots

# ─────────────────────────────────────────────
#  存档
# ─────────────────────────────────────────────

const SaveUtils = preload("res://scripts/save_utils.gd")

func save_state() -> Dictionary:
	var data: Dictionary = {}
	for card_id in card_module_slots:
		var slots: Array = []
		for s in card_module_slots[card_id]:
			if s is ModuleSlot:
				slots.append(s.to_dict())
			elif s is Dictionary:
				slots.append(s)
		if slots.size() > 0:
			data[card_id] = slots
	return data

func load_state(data: Dictionary) -> void:
	card_module_slots.clear()
	if data.is_empty():
		return
	# save_state() 返回扁平结构 {card_id: [slots]}，直接遍历顶层键。
	# 兼容历史格式：若存在 "module_slots" 包裹键则取其内层字典。
	var slots_data: Dictionary = data
	if data.has("module_slots") and data["module_slots"] is Dictionary:
		slots_data = data["module_slots"]
	for card_id in slots_data:
		var arr: Array = slots_data[card_id] if slots_data[card_id] is Array else []
		var slots: Array = []
		for entry in arr:
			if entry is Dictionary:
				slots.append(ModuleSlot.from_dict(entry))
		if slots.size() > 0:
			card_module_slots[card_id] = slots

## v6.11: 清除单张卡牌的强化数据（进化后调用，确保源卡强化彻底清零）
## 清空 card_module_slots[card_id]（词条槽）+ 重置 CardResource.enhance_level=0
## 注：之前 card_evolution_manager 注释声称"强化重置"但从未实现，源卡强化残留内存
func clear_card_enhancement(card_id: String) -> void:
	card_module_slots.erase(card_id)
	var card = DefaultCards.get_card_by_id(card_id)
	if card != null:
		card.enhance_level = 0
		card.module_slots = []

func reset_to_defaults() -> void:
	card_module_slots.clear()
	var all_ids = DefaultCards.get_all_blueprint_ids()
	for card_id in all_ids:
		if not card_id.is_empty():
			var card = DefaultCards.get_card_by_id(card_id)
			if card != null:
				card.enhance_level = 0
