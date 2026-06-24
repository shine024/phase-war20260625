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
func get_card_enhancement_level(card_id: String) -> int:
	var card = DefaultCards.get_card_by_id(card_id)
	if card != null:
		return maxi(card.enhance_level, 0)
	return 0

## 获取卡牌的词条槽位数组
func get_module_slots(card_id: String) -> Array:
	return card_module_slots.get(card_id, [])

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
func _is_combat_card(card_id: String) -> bool:
	var card = DefaultCards.get_card_by_id(card_id)
	if card == null:
		return false
	return card.card_type == GC.CardType.COMBAT_UNIT

## 获取时代系数
func get_era_multiplier(era: int) -> float:
	return float(ERA_MULTIPLIER.get(clampi(era, 0, 4), 1.0))

## 计算强化消耗（纳米材料）
func get_enhance_nano_cost(card_id: String, target_level: int) -> int:
	var config = enhancement_config.get(target_level, {})
	var level_mult = float(config.get("level_cost_multiplier", 1.0))
	var card = DefaultCards.get_card_by_id(card_id)
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
func do_enhance(card_id: String, nano_available: int) -> Dictionary:
	if not can_enhance(card_id, nano_available):
		return {"ok": false, "action": "none", "reason": "无法强化"}

	var card = DefaultCards.get_card_by_id(card_id)
	if card == null:
		return {"ok": false, "action": "none", "reason": "卡牌不存在"}

	var current_level = get_card_enhancement_level(card_id)
	var target_level = current_level + 1
	var nano_cost = get_enhance_nano_cost(card_id, target_level)

	# 纳米消耗在调用方处理（UI统一扣费）
	card.enhance_level = target_level

	var action = ModuleDefinitions.get_level_action(target_level)

	emit_signal("enhancement_completed", true, card_id, action,
		"强化成功！等级提升至 Lv.%d" % target_level)

	return {"ok": true, "action": action, "level": target_level}

## 选择词条（新槽位时调用）
func choose_module(card_id: String, module_id: String) -> Dictionary:
	var slots = get_module_slots(card_id)
	var level = get_card_enhancement_level(card_id)
	var max_slots = ModuleDefinitions.get_max_slots_for_level(level)

	# 验证词条在当前池中可用
	var available = ModuleDefinitions.get_available_modules(level)
	if module_id not in available:
		return {"ok": false, "reason": "词条不在可用池中"}

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
	card_module_slots[card_id] = slots

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
		card_module_slots[card_id] = slots
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
	card_module_slots[card_id] = slots
	# 清理尾部空槽位
	while slots.size() > 0 and slots[slots.size() - 1] == null:
		slots.pop_back()
	emit_signal("module_reset", card_id, slot_index)
	return {"ok": true}

## 全部重置（清空所有词条，保持强化等级）
func reset_all_modules(card_id: String) -> Dictionary:
	card_module_slots[card_id] = []
	emit_signal("module_reset", card_id, -1)
	return {"ok": true}

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
