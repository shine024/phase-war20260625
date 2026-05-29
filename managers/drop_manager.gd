extends Node

## 掉落管理器 - 处理战斗奖励和掉落逻辑

signal drops_generated(drops: Array)
signal drops_claimed(drop_results: Array)
signal drop_completed(drop_id: String)

## 性能优化：预加载常用资源
const DefaultCards = preload("res://data/default_cards.gd")
const PhaseLaws = preload("res://data/phase_laws.gd")
const GameConstants = preload("res://resources/game_constants.gd")
const CardDropGrants = preload("res://scripts/card_drop_grants.gd")
const DropTables = preload("res://resources/drop_tables.gd")

var drop_tables: DropTables
var pending_drops: Array = []  # 待处理的掉落物

func _ready():
	drop_tables = DropTables.new()

## 生成战斗掉落
func generate_battle_drops(era: int, level: int, player_won: bool, victory_stars: int = 0) -> Array:
	var drops = drop_tables.generate_drops(era, level, player_won, victory_stars)
	pending_drops = drops
	drops_generated.emit(drops)
	return drops

## 生成Boss战掉落
func generate_boss_drops(era: int, boss_id: String) -> Array:
	var drops = drop_tables.generate_boss_drops(era, boss_id)
	pending_drops = drops
	drops_generated.emit(drops)
	return drops

## 获取待处理掉落物（供外部访问）
func get_pending_drops() -> Array:
	return pending_drops.duplicate()

## DefaultCards 教学池中的平台/武器 id（platform_* / weapon_*）及同源终局默认载具：禁止经掉落/任务等写入背包
func _is_default_pool_platform_or_weapon_card_id(card_id: String) -> bool:
	var id := String(card_id).strip_edges()
	if id.is_empty():
		return false
	if id.begins_with("platform_") or id.begins_with("weapon_"):
		return true
	if id == "omega_platform":
		return true
	return false


## 玩家领取掉落
func claim_drops() -> void:
	for drop in pending_drops:
		_process_single_drop(drop)
	drops_claimed.emit(pending_drops)
	pending_drops.clear()

## 处理单个掉落物
func _process_single_drop(drop: DropTables.DropResult) -> void:
	match drop.drop.type:
		DropTables.DropType.MATERIAL:
			_add_material(drop.drop.item_id, drop.count)
		DropTables.DropType.CARD_DATA, DropTables.DropType.BLUEPRINT_FRAGMENT:
			_add_blueprint_copy(drop.drop.item_id, drop.count)
		DropTables.DropType.DROPPED_CARD:
			_add_dropped_card(drop.drop.item_id, drop.count)
		DropTables.DropType.LORE_PAGE:
			_unlock_lore(drop.drop.item_id)
		DropTables.DropType.CARD_REWARD:
			_add_card_to_backpack(drop.drop.item_id)
		DropTables.DropType.ENERGY_CARD:
			_add_card_to_backpack(drop.drop.item_id)
		DropTables.DropType.STAT_BOOST:
			_apply_stat_boost(drop.drop.item_id)
		DropTables.DropType.LAW_DATA, DropTables.DropType.LAW_BLUEPRINT:
			_add_law_blueprint(drop.drop.item_id, drop.count)
		DropTables.DropType.LAW_CARD:
			_add_law_card(drop.drop.item_id, drop.count)
		DropTables.DropType.ENERGY_DATA, DropTables.DropType.ENERGY_BLUEPRINT:
			_add_energy_blueprint(drop.drop.item_id, drop.count)

## 添加基础素材
func _add_material(material_id: String, count: int) -> void:
	match material_id:
		"nano_materials":
			BasicResourceManager.add_resource("nano_materials", count)
		"alloy":
			BasicResourceManager.add_resource("alloy", count)
		"crystal":
			BasicResourceManager.add_resource("crystal", count)
		"basic_nano":  # 兼容旧ID，映射到nano_materials
			BasicResourceManager.add_resource("nano_materials", count)
		"energy_block":
			BasicResourceManager.add_resource("energy_block", count)
		_:
			# 兜底：允许新资源ID（如各类改造许可函）直接入账
			BasicResourceManager.add_resource(material_id, count)

## 敌方/时代随机卡 id：解析后发放为背包「成品掉落卡」（不再只加蓝图副本）
func _add_blueprint_copy(item_id: String, count: int) -> void:
	if not BlueprintManager:
		return
	var era: int = 0
	if "current_level" in GameManager:
		if GameConstants:
			era = GameConstants.get_era_for_level(int(GameManager.current_level))
	var resolved_id: String = drop_tables.resolve_blueprint_id(item_id, era)
	CardDropGrants.grant_enemy_style_card(BlueprintManager, resolved_id, era, maxi(1, count))


## 供战斗击杀碎片、战后奖励等调用：按 id 发放多张掉落卡（每张独立随机星级与词条）
func grant_dropped_cards_by_id(card_id: String, count: int) -> void:
	var id: String = String(card_id).strip_edges()
	if id.is_empty():
		return
	_add_dropped_card(id, maxi(1, int(count)))


## 添加掉落成品卡（带星级和强化）
func _add_dropped_card(card_id: String, count: int) -> void:
	if _is_default_pool_platform_or_weapon_card_id(card_id):
		push_warning("[DropManager] 已拦截默认平台/武器成品卡掉落: %s" % card_id)
		return
	var card = DefaultCards.get_card_by_id(card_id)
	if card == null:
		push_error("无法找到掉落卡牌: " + card_id)
		return
	# v3 后所有战斗卡都是 COMBAT_UNIT，无需拦截 WEAPON 类型（该类型已废弃）
	# 原错误代码拦截了 COMBAT_UNIT 导致所有战斗卡掉落被拦，现已移除
	var n: int = maxi(1, int(count))
	for _i in range(n):
		var dropped_card: CardResource = card.clone()
		dropped_card.is_dropped_card = true
		var star: int = randi_range(1, 9)
		dropped_card.star_level = star
		if BlueprintManager and BlueprintManager.has_method("get_default_enhancements"):
			var enhancements: Array = BlueprintManager.get_default_enhancements(card_id, star)
			dropped_card.affix_slot_ids = []  # @deprecated v5.0: 词条系统将删除
			for e in enhancements:
				if e is Dictionary and e.has("id"):
					dropped_card.affix_slot_ids.append(String(e["id"]))  # @deprecated v5.0
		if SignalBus:
			SignalBus.card_added_to_backpack.emit(dropped_card)

## 解锁情报
func _unlock_lore(lore_id: String) -> void:
	ManagerLazyLoader.ensure_loaded("lore")
	var lm = get_node_or_null("/root/LoreManager")
	if lm and lm.has_method("unlock_lore"):
		lm.unlock_lore(lore_id)
	else:
		# 兼容模式：如果没有 LoreManager，记录到 GameManager
		if not GameManager.has_method("add_unlocked_lore"):
			# 在运行时动态添加记录
			if not GameManager.has_meta("unlocked_lore"):
				GameManager.set_meta("unlocked_lore", [])
			var lore_list = GameManager.get_meta("unlocked_lore")
			if not lore_list.has(lore_id):
				lore_list.append(lore_id)
				print("[DropManager] 解锁情报: ", lore_id, " - ", _get_lore_display_name(lore_id))
		else:
			GameManager.add_unlocked_lore(lore_id)

## 获取情报显示名称
func _get_lore_display_name(lore_id: String) -> String:
	match lore_id:
		"lore_ww1_trench": return "堑壕战术手册"
		"lore_ww2_blitzkrieg": return "闪电战档案"
		_: return "情报资料"

## 添加卡牌到背包
func _add_card_to_backpack(card_id: String) -> void:
	if _is_default_pool_platform_or_weapon_card_id(card_id):
		push_warning("[DropManager] 已拦截默认平台/武器卡背包奖励: %s" % card_id)
		return
	# 将card_id转换为CardResource对象后再发送信号
	var card = DefaultCards.get_card_by_id(card_id)
	if card:
		SignalBus.card_added_to_backpack.emit(card)
	else:
		push_error("无法找到卡牌: " + card_id)

## 应用属性提升
func _apply_stat_boost(boost_id: String) -> void:
	ManagerLazyLoader.ensure_loaded("stat_boost")
	var sbm = get_node_or_null("/root/StatBoostManager")
	if sbm and sbm.has_method("apply_boost"):
		sbm.apply_boost(boost_id)
	else:
		# 兼容模式：如果没有 StatBoostManager，记录到 GameManager
		if not GameManager.has_method("add_stat_boost"):
			# 在运行时动态添加记录
			if not GameManager.has_meta("stat_boosts"):
				GameManager.set_meta("stat_boosts", {})
			var boosts = GameManager.get_meta("stat_boosts")
			if not boosts.has(boost_id):
				boosts[boost_id] = boosts.get(boost_id, 0) + 1
				print("[DropManager] 应用属性提升: ", boost_id, " - ", _get_boost_display_name(boost_id))
		else:
			GameManager.add_stat_boost(boost_id)

## 获取属性提升显示名称
func _get_boost_display_name(boost_id: String) -> String:
	match boost_id:
		"stat_boost_hp": return "生命强化"
		"stat_boost_damage": return "攻击强化"
		"stat_boost_speed": return "速度强化"
		_: return "属性提升"

## 获取待处理掉落数量
func get_pending_drops_count() -> int:
	return pending_drops.size()

## 清空待处理掉落
func clear_pending_drops() -> void:
	pending_drops.clear()

## 获取掉落物显示信息
func get_drop_info(drop: DropTables.DropResult) -> Dictionary:
	return {
		"name": drop_tables.get_drop_display_name(drop.drop),
		"count": drop.count,
		"source": drop.source,
		"type": drop.drop.type,
		"color": drop_tables.get_drop_rarity_color(drop.drop),
		"icon": drop_tables.get_drop_icon_path(drop.drop)
	}

## 保存掉落状态
func save_state() -> Dictionary:
	var state = {}
	var drops_data = []
	for drop in pending_drops:
		drops_data.append({
			"item_id": drop.drop.item_id,
			"type": drop.drop.type,
			"count": drop.count,
			"source": drop.source
		})
	state["pending_drops"] = drops_data
	return state

## 加载掉落状态
func load_state(state: Dictionary) -> void:
	if state.has("pending_drops"):
		pending_drops.clear()
		for drop_data in state["pending_drops"]:
			var entry = DropTables.DropEntry.new(
				drop_data["item_id"],
				drop_data["type"],
				1.0,
				drop_data["count"],
				drop_data["count"]
			)
			var result = DropTables.DropResult.new(entry, drop_data["count"], drop_data["source"])
			pending_drops.append(result)

## 添加法则蓝图碎片
func _add_law_blueprint(law_id: String, count: int) -> void:
	# 处理随机法则蓝图
	if law_id == "random_law_blueprint" or law_id == "random_law_passive" or law_id == "random_law_active":
		law_id = _pick_random_law_blueprint()
		if law_id.is_empty():
			return

	# 新规则：法则作为普通卡牌掉落，不再走蓝图碎片
	for i in range(maxi(1, count)):
		var law_card: CardResource = DefaultCards.create_law_card_resource(law_id)
		if law_card and SignalBus:
			SignalBus.card_added_to_backpack.emit(law_card)
	print("[DropManager] 获得法则卡: ", law_id, " x", count)

## 随机选择一个法则蓝图ID
func _pick_random_law_blueprint() -> String:
	var all_ids: Array = PhaseLaws.get_all_ids()
	if not all_ids.is_empty():
		return String(all_ids[randi() % all_ids.size()])
	return ""

## 添加完整法则卡
func _add_law_card(law_id: String, count: int) -> void:
	# 处理随机法则卡
	if law_id.begins_with("law_random"):
		var all_laws: Array = []
		var ids: Array = PhaseLaws.get_all_ids()
		for id in ids:
			var law: Dictionary = PhaseLaws.get_by_id(String(id))
			if law_id == "law_random_passive" and str(law.get("kind", "")) == "passive":
				all_laws.append(String(id))
			elif law_id == "law_random_active" and str(law.get("kind", "")) == "active":
				all_laws.append(String(id))
			elif law_id == "law_random":
				all_laws.append(String(id))
		if not all_laws.is_empty():
			law_id = all_laws[randi() % all_laws.size()]
		else:
			return

	var card: CardResource = DefaultCards.create_law_card_resource(law_id)
	if card:
		card.star_level = 1
		for i in range(maxi(1, count)):
			if SignalBus:
				SignalBus.card_added_to_backpack.emit(card.clone() if card.has_method("clone") else card)
		print("[DropManager] 获得法则卡: ", card.display_name, " x", count)
	else:
		push_error("[DropManager] 无法创建法则卡: " + law_id)

## 能量卡数据条目：直接发对应时代的能量卡到背包（并保证可制造），附带少量研究点
func _add_energy_blueprint(_item_id: String, count: int) -> void:
	if not BlueprintManager or not SignalBus:
		return
	var energy_id: String = ""
	var era: int = 0
	if "current_level" in GameManager:
		if GameConstants:
			era = GameConstants.get_era_for_level(int(GameManager.current_level))

	match era:
		0: energy_id = "energy_start_1"
		1: energy_id = "energy_start_2"
		2: energy_id = "energy_start_3"
		3: energy_id = "energy_start_5"
		4: energy_id = "energy_start_7"
		_: energy_id = "energy_start_1"

	var n: int = maxi(1, count)
	for _i in range(n):
		_add_card_to_backpack(energy_id)
	if BlueprintManager and BlueprintManager.has_method("apply_card_drop_first_copy"):
		BlueprintManager.apply_card_drop_first_copy(energy_id)
	if BlueprintManager.has_method("add_research_points"):
		BlueprintManager.add_research_points(12 * n)
	print("[DropManager] 获得能量卡: ", energy_id, " x", n)