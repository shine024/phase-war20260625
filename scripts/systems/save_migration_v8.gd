class_name SaveMigrationV8
extends RefCounted
## v7 → v8 存档迁移：卡牌实例化养成
##
## 变更：养成数据从 card_id 单例迁移到卡牌实例（instance_id = card_id#序号）。
## 旧版养成数据（blueprint_mods/inherit_bonus/evolution_hp_floor 等按 card_id 存）与新机制不兼容。
## 按设计决策「旧存档不管」，v8 迁移清空这些旧养成字段，玩家从干净状态重新养成。
##
## 保留：蓝图解锁状态（blueprint_copies）、资源、关卡进度等非养成数据不动。

## v7 → v8 迁移：清空按 card_id 存储的旧养成数据
static func migrate_v7_to_v8(data: Dictionary, debug_log: bool = false) -> void:
	var cleared_fields: Array = []
	# 1. 清空 BlueprintManager 中按 card_id 存的养成字段（实例化后改用 instance_id）
	if data.has(SaveConstants.SK_BLUEPRINT) and data[SaveConstants.SK_BLUEPRINT] is Dictionary:
		var bp: Dictionary = data[SaveConstants.SK_BLUEPRINT]
		# 养成相关字段清空（实例化后会重建）
		for field in ["blueprint_mods", "blueprint_inherit_bonus", "blueprint_evolution_hp_floor",
						"blueprint_weapon_slots", "blueprint_enemy_origin_mod",
						"blueprint_intel_branch_bonus"]:
			if bp.has(field):
				bp[field] = {}
				cleared_fields.append("blueprint." + field)
		# blueprint_rank_cache 是冗余缓存，清空无影响（运行时重算）
		if bp.has("blueprint_rank_cache"):
			bp["blueprint_rank_cache"] = {}
			cleared_fields.append("blueprint.blueprint_rank_cache")

	# 2. 清空 CardEnhancementManager 的词条槽（实例化后挂在实例对象上）
	if data.has(SaveConstants.SK_CARD_ENHANCEMENT):
		data[SaveConstants.SK_CARD_ENHANCEMENT] = {}
		cleared_fields.append("card_enhancement")

	# 3. 清空相位仪槽位（旧存档槽位是 card_id，实例化后是 instance_id，旧值无效）
	# 新游戏会重新装初始卡；玩家需重新装配（旧卡牌身份已变）
	if data.has(SaveConstants.SK_PHASE_SLOTS):
		data[SaveConstants.SK_PHASE_SLOTS] = []
		cleared_fields.append("phase_slots")
	if data.has(SaveConstants.SK_PHASE_INSTRUMENT) and data[SaveConstants.SK_PHASE_INSTRUMENT] is Dictionary:
		var pi: Dictionary = data[SaveConstants.SK_PHASE_INSTRUMENT]
		if pi.has("slot_card_ids"):
			pi["slot_card_ids"] = []
			cleared_fields.append("phase_instrument.slot_card_ids")

	# 4. 清空背包额外卡（旧值是 card_id，实例化后是 instance_id）
	if data.has(SaveConstants.SK_BACKPACK_EXTRA_IDS):
		data[SaveConstants.SK_BACKPACK_EXTRA_IDS] = []
		cleared_fields.append("backpack_extra_ids")

	if debug_log and not cleared_fields.is_empty():
		push_warning("[SaveMigration] v7→v8: 清空旧养成数据（实例化重建）: %s" % ", ".join(cleared_fields))
