extends RefCounted
## 成就奖励发放器：负责发放成就奖励
##
## 从 achievement_manager.gd 拆分的职责：
## - 根据奖励类型（basic_nano / energy_block / phase_field_xp / card）发放资源
## - 通过依赖注入的资源管理器节点操作，不硬编码单例路径
## - 提供奖励可领取状态查询

class_name AchievementRewards

static func _get_autoload(root_path: String) -> Node:
	var loop_obj := Engine.get_main_loop()
	if not (loop_obj is SceneTree):
		return null
	var tree := loop_obj as SceneTree
	if tree == null or tree.get_root() == null:
		return null
	return tree.get_root().get_node_or_null(root_path)

## 尝试发放成就奖励
## @param reward: 成就定义中的 reward 字典
##   新格式（推荐）: { type, amount, card_id?, mod_blueprint_id? }
##     type: "basic_nano" / "energy_block" / "phase_xp" / "card" / "mod_blueprint"
##   旧格式（兼容）: { nano_materials: N, energy_block: N, company_rep: {fid: N}, rare_card: N, mythic_card: N }
##     v8 批次5: 兼容旧格式——无 type 字段时按资源键直填发放
## @param resource_managers: 资源管理器字典，可选键：
##   "BasicResourceManager" -> Node
##   "PhaseInstrumentManager" -> Node
##   "DropManager" -> Node
## @return bool 是否成功发放
static func grant(reward: Dictionary, resource_managers: Dictionary = {}) -> bool:
	if reward.is_empty():
		return false

	var reward_type: String = reward.get("type", "")
	var reward_amount: int = reward.get("amount", 0)

	# v8 批次5: 旧格式兼容——无 type 字段时按资源键直填发放
	# 现有成就定义用 {nano_materials: N} 格式，此前因 grant 只读 type 导致全部空转
	if reward_type.is_empty():
		return _grant_legacy_format(reward, resource_managers)

	match reward_type:
		"basic_nano":
			var brm: Node = resource_managers.get("BasicResourceManager")
			if brm == null:
				brm = _get_autoload("/root/BasicResourceManager")
			if brm != null and brm.has_method("add_resource"):
				brm.add_resource("nano_materials", reward_amount)
				return true
			return false

		"energy_block":
			var brm: Node = resource_managers.get("BasicResourceManager")
			if brm == null:
				brm = _get_autoload("/root/BasicResourceManager")
			if brm != null and brm.has_method("add_resource"):
				brm.add_resource("energy_block", reward_amount)
				return true
			return false

		"phase_xp", "phase_field_xp":
			var pm: Node = resource_managers.get("PhaseInstrumentManager")
			if pm == null:
				pm = _get_autoload("/root/PhaseInstrumentManager")
			if pm != null and pm.has_method("grant_phase_field_xp"):
				pm.grant_phase_field_xp("achievement", reward_amount)
				return true
			return false

		"card":
			ManagerLazyLoader.ensure_loaded("drop")  # DropManager 为 autoload+别名双层（ensure_loaded 幂等）
			var dm: Node = resource_managers.get("DropManager")
			if dm == null:
				dm = _get_autoload("/root/DropManager")
			var card_id: String = reward.get("card_id", "")
			var card_count: int = maxi(1, int(reward.get("amount", 1)))
			if dm != null and dm.has_method("grant_dropped_cards_by_id") and not card_id.is_empty():
				dm.grant_dropped_cards_by_id(card_id, card_count)
				return true
			return false

		# v8 批次5: 改造蓝图奖励（独占改造）
		"mod_blueprint":
			var bag: Node = _get_autoload("/root/IntelItemBag")
			var mod_id: String = reward.get("mod_blueprint_id", "")
			var mod_count: int = maxi(1, int(reward.get("amount", 1)))
			if bag != null and bag.has_method("add_item") and not mod_id.is_empty():
				var bp_id: String = "blueprint_" + mod_id
				for _i in range(mod_count):
					bag.add_item(bp_id, 1)
				return true
			return false

	return false


## v8 批次5: 旧格式兼容发放（无 type 字段的 reward 字典）
## 处理 {nano_materials: N, energy_block: N, company_rep: {fid: N}, rare_card: N, mythic_card: N}
## 此前因 grant 只读 type 导致所有旧格式成就奖励空转——本方法修复该 bug
static func _grant_legacy_format(reward: Dictionary, resource_managers: Dictionary) -> bool:
	var brm: Node = resource_managers.get("BasicResourceManager")
	if brm == null:
		brm = _get_autoload("/root/BasicResourceManager")
	var granted: bool = false
	# 纳米材料
	var nano: int = int(reward.get("nano_materials", 0))
	if nano > 0 and brm != null and brm.has_method("add_resource"):
		brm.add_resource("nano_materials", nano)
		granted = true
	# 能量块
	var eblock: int = int(reward.get("energy_block", 0))
	if eblock > 0 and brm != null and brm.has_method("add_resource"):
		brm.add_resource("energy_block", eblock)
		granted = true
	# 势力声望
	var rep: Dictionary = reward.get("company_rep", {})
	if not rep.is_empty():
		var fsm: Node = _get_autoload("/root/FactionSystemManager")
		if fsm != null and fsm.has_method("add_reputation"):
			for fid in rep:
				fsm.add_reputation(String(fid), int(rep[fid]))
			granted = true
	# 稀有/神话卡（rare_card/mythic_card/legendary_card → 从对应池抽卡发放）
	ManagerLazyLoader.ensure_loaded("drop")  # DropManager 为 autoload+别名双层（ensure_loaded 幂等）
	var dm: Node = resource_managers.get("DropManager")
	if dm == null:
		dm = _get_autoload("/root/DropManager")
	if dm != null and dm.has_method("grant_dropped_cards_by_id"):
		for card_key in ["rare_card", "rare_cards", "legendary_card", "mythic_card"]:
			var cnt: int = int(reward.get(card_key, 0))
			if cnt > 0:
				# 从对应稀有度池抽一张卡发放（用 _pick_card_by_rarity 辅助）
				for _i in range(cnt):
					var picked_id: String = _pick_card_by_rarity(card_key)
					if not picked_id.is_empty():
						dm.grant_dropped_cards_by_id(picked_id, 1)
						granted = true
	return granted


## v8 批次5: 按稀有度关键词从 DefaultCards 抽一张卡 id（供旧格式 rare_card/mythic_card 发放）
static func _pick_card_by_rarity(key: String) -> String:
	var DefaultCards = preload("res://data/default_cards.gd")
	var all_ids: Array = DefaultCards.get_all_card_ids() if "get_all_card_ids" in DefaultCards else []
	if all_ids.is_empty():
		return ""
	# 按关键词粗筛稀有度（card_id 命名约定：ww1_/ww2_/cold_/mod_/fut_ + tier）
	var pool: Array = all_ids.duplicate()
	match key:
		"mythic_card":
			# 神话：近未来 ultimate 卡
			pool = pool.filter(func(id): return String(id).begins_with("fut_") and (String(id).find("boss") >= 0 or String(id).find("nexus") >= 0 or String(id).find("omega") >= 0))
		"legendary_card":
			pool = pool.filter(func(id): return String(id).begins_with("fut_"))
		"rare_card", "rare_cards":
			pool = pool.filter(func(id): return String(id).begins_with("cold_") or String(id).begins_with("mod_"))
	if pool.is_empty():
		pool = all_ids.duplicate()
	return String(pool[randi() % pool.size()]) if not pool.is_empty() else ""


## 检查奖励是否有实际内容
## @param reward: 成就定义中的 reward 字典
## @return bool
static func has_reward(reward: Dictionary) -> bool:
	if reward.is_empty():
		return false
	var reward_type: String = reward.get("type", "")
	if not reward_type.is_empty():
		return reward_type in ["basic_nano", "energy_block", "phase_xp", "phase_field_xp", "card", "mod_blueprint"]
	# v8 批次5: 旧格式兼容——有任意资源键即视为有奖励
	return reward.has("nano_materials") or reward.has("energy_block") or reward.has("company_rep") or reward.has("rare_card") or reward.has("rare_cards") or reward.has("mythic_card") or reward.has("legendary_card")
