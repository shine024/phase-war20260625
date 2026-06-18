extends RefCounted
## 势力商店子系统：管理商店库存、商品定义、购买流程
##
## 从 faction_system_manager.gd 拆分的职责：
## - 商店物品定义（StoreItem 内部类）
## - 根据势力类型和等级生成商品列表
## - 购买检查与执行（扣声望 / 给物品）
## - 物品发放逻辑

class_name FactionShop

## 商店物品类型
enum StoreItemType {
	CARD,
	MATERIAL,
	CARD_BUNDLE,  ## 随机卡牌包（经 CardDropGrants 发背包卡，非碎片）
	RUNE,         ## v6.2 符文（势力专属符文，声望解锁）
}

## 商店物品定义
class StoreItem:
	var item_id: String
	var item_type: StoreItemType
	var display_name: String
	var description: String
	var reputation_cost: int
	var required_level: int = 1
	var stock: int = -1  # -1 表示无限库存

	func _init(p_id: String, p_type: StoreItemType, p_name: String, p_cost: int, p_level: int = 1, p_stock: int = -1):
		item_id = p_id
		item_type = p_type
		display_name = p_name
		reputation_cost = p_cost
		required_level = p_level
		stock = p_stock

## 创建商店物品
static func create_store_item(id: String, type: StoreItemType, name: String, cost: int, level: int, stock: int = -1) -> StoreItem:
	return StoreItem.new(id, type, name, cost, level, stock)

## 获取势力可购买物品列表
## @param faction_id: String 势力ID
## @param level: int 当前势力等级（用于筛选可购买物品）
## @return Array[StoreItem]
static func get_faction_store_items(faction_id: String, level: int) -> Array[StoreItem]:
	var items: Array[StoreItem] = []

	match faction_id:
		"iron_wall_corp":
			items.append(create_store_item("platform_ww1_fort", StoreItemType.CARD, "要塞固定炮", 300, level))
			items.append(create_store_item("platform_ww2_heavy", StoreItemType.CARD, "虎式坦克", 400, level))
			items.append(create_store_item("platform_cold_medium", StoreItemType.CARD, "T-72主战坦克", 350, level))
			items.append(create_store_item("platform_modern_medium", StoreItemType.CARD, "艾布拉姆斯坦克", 500, level))
			items.append(create_store_item("platform_future_heavy", StoreItemType.CARD, "机甲步行者", 600, level))
			items.append(create_store_item("weapon_ww1_mg", StoreItemType.CARD, "马克沁机枪", 150, level))
			items.append(create_store_item("weapon_ww2_mg", StoreItemType.CARD, "MG42机枪", 200, level))
			items.append(create_store_item("weapon_cold_lmg", StoreItemType.CARD, "M60通用机枪", 250, level))
			items.append(create_store_item("weapon_modern_minigun", StoreItemType.CARD, "M134加特林", 300, level))
			items.append(create_store_item("steel_phase_armor", StoreItemType.CARD, "钢铁·相位装甲", 350, level))
			items.append(create_store_item("steel_quick_repair", StoreItemType.CARD, "钢铁·快速维修", 400, level))
			items.append(create_store_item("steel_bastion_wall", StoreItemType.CARD, "钢铁·堡垒之墙", 600, level))
			items.append(create_store_item("energy_start_2", StoreItemType.CARD, "战前能量 II", 180, level))
			items.append(create_store_item("energy_start_5", StoreItemType.CARD, "战前能量 V", 200, level))
			items.append(create_store_item("alloy", StoreItemType.MATERIAL, "合金x50", 150, level))

		"nova_arms":
			items.append(create_store_item("weapon_ww2_at", StoreItemType.CARD, "巴祖卡火箭筒", 250, level))
			items.append(create_store_item("weapon_cold_missile", StoreItemType.CARD, "陶式反坦克导弹", 350, level))
			items.append(create_store_item("weapon_modern_grenade", StoreItemType.CARD, "榴弹发射器", 300, level))
			items.append(create_store_item("weapon_future_laser", StoreItemType.CARD, "光束步枪", 400, level))
			items.append(create_store_item("weapon_future_rail", StoreItemType.CARD, "电磁炮", 500, level))
			items.append(create_store_item("weapon_future_plasma", StoreItemType.CARD, "等离子枪", 450, level))
			items.append(create_store_item("platform_ww2_medium", StoreItemType.CARD, "谢尔曼坦克", 300, level))
			items.append(create_store_item("platform_future_medium", StoreItemType.CARD, "悬浮坦克", 400, level))
			items.append(create_store_item("flame_heat_overload", StoreItemType.CARD, "烈焰·热能过载", 350, level))
			items.append(create_store_item("flame_afterburn", StoreItemType.CARD, "烈焰·余烬加燃", 400, level))
			items.append(create_store_item("flame_front_bombard", StoreItemType.CARD, "烈焰·前线火力压制", 650, level))
			items.append(create_store_item("energy_start_3", StoreItemType.CARD, "战前能量 III", 250, level))
			items.append(create_store_item("energy_start_6", StoreItemType.CARD, "战前能量 VI", 200, level))
			items.append(create_store_item("nano_materials", StoreItemType.MATERIAL, "纳米材料x50", 180, level))
			items.append(create_store_item("bp_cold_014", StoreItemType.CARD, "稀有缴获卡", 400, level))

		"aether_dynamics":
			items.append(create_store_item("platform_ww1_medium", StoreItemType.CARD, "马克V型坦克", 250, level))
			items.append(create_store_item("platform_cold_light", StoreItemType.CARD, "悍马侦察车", 200, level))
			items.append(create_store_item("platform_modern_light", StoreItemType.CARD, "北极星全地形车", 250, level))
			items.append(create_store_item("platform_future_light", StoreItemType.CARD, "光学侦察车", 300, level))
			items.append(create_store_item("weapon_cold_sniper", StoreItemType.CARD, "德拉贡诺夫狙击枪", 350, level))
			items.append(create_store_item("weapon_modern_dmr", StoreItemType.CARD, "MK14射手步枪", 300, level))
			items.append(create_store_item("weapon_future_pulse", StoreItemType.CARD, "脉冲步枪", 350, level))
			items.append(create_store_item("energy_start_1", StoreItemType.CARD, "战前能量 I", 120, level))
			items.append(create_store_item("energy_start_2", StoreItemType.CARD, "战前能量 II", 200, level))
			items.append(create_store_item("energy_start_3", StoreItemType.CARD, "战前能量 III", 300, level))
			items.append(create_store_item("energy_start_4", StoreItemType.CARD, "战前能量 IV", 220, level))
			items.append(create_store_item("energy_start_5", StoreItemType.CARD, "战前能量 V", 280, level))
			items.append(create_store_item("energy_start_6", StoreItemType.CARD, "战前能量 VI", 360, level))
			items.append(create_store_item("energy_start_7", StoreItemType.CARD, "战前能量 VII", 400, level))
			items.append(create_store_item("thunder_arc_beacon", StoreItemType.CARD, "雷霆·弧光信标", 350, level))
			items.append(create_store_item("bp_ww1_012", StoreItemType.CARD, "缴获卡", 250, level))

		"quantum_logistics":
			items.append(create_store_item("platform_cold_ifv", StoreItemType.CARD, "布雷德利步战车", 300, level))
			items.append(create_store_item("platform_modern_spg", StoreItemType.CARD, "帕拉丁自行火炮", 350, level))
			items.append(create_store_item("weapon_ww1_rifle", StoreItemType.CARD, "李-恩菲尔德步枪", 150, level))
			items.append(create_store_item("weapon_cold_assault", StoreItemType.CARD, "AK-47突击步枪", 200, level))
			items.append(create_store_item("weapon_modern_carbine", StoreItemType.CARD, "M4卡宾枪", 250, level))
			items.append(create_store_item("energy_start_4", StoreItemType.CARD, "战前能量 IV", 100, level))
			items.append(create_store_item("energy_start_5", StoreItemType.CARD, "战前能量 V", 180, level))
			items.append(create_store_item("energy_start_6", StoreItemType.CARD, "战前能量 VI", 280, level))
			items.append(create_store_item("steel_quick_repair", StoreItemType.CARD, "钢铁·快速维修", 380, level))
			items.append(create_store_item("nano_materials", StoreItemType.MATERIAL, "纳米材料x100", 200, level))
			items.append(create_store_item("alloy", StoreItemType.MATERIAL, "合金x50", 150, level))
			items.append(create_store_item("alloy", StoreItemType.MATERIAL, "合金x100", 280, level))
			items.append(create_store_item("bp_ww2_016", StoreItemType.CARD, "缴获卡·精选", 300, level))
			items.append(create_store_item("bp_modern_011", StoreItemType.CARD, "稀有缴获卡", 450, level))
			items.append(create_store_item("stat_boost_hp", StoreItemType.MATERIAL, "生命强化", 400, level))

		"helix_recon":
			items.append(create_store_item("platform_ww1_light", StoreItemType.CARD, "威克斯侦察车", 180, level))
			items.append(create_store_item("platform_ww2_light", StoreItemType.CARD, "M8灰狗装甲车", 220, level))
			items.append(create_store_item("platform_cold_light", StoreItemType.CARD, "悍马侦察车", 250, level))
			items.append(create_store_item("platform_modern_light", StoreItemType.CARD, "北极星全地形车", 280, level))
			items.append(create_store_item("platform_future_light", StoreItemType.CARD, "光学侦察车", 350, level))
			items.append(create_store_item("weapon_ww1_smg", StoreItemType.CARD, "MP18冲锋枪", 150, level))
			items.append(create_store_item("weapon_ww2_smg", StoreItemType.CARD, "汤普森冲锋枪", 200, level))
			items.append(create_store_item("weapon_modern_carbine", StoreItemType.CARD, "M4卡宾枪", 250, level))
			items.append(create_store_item("weapon_future_pulse", StoreItemType.CARD, "脉冲步枪", 300, level))
			items.append(create_store_item("void_entropy_lens", StoreItemType.CARD, "虚空·熵镜", 350, level))
			items.append(create_store_item("void_phase_cloak", StoreItemType.CARD, "虚空·相位披幕", 400, level))
			items.append(create_store_item("void_time_ripple", StoreItemType.CARD, "虚空·时空涟漪", 700, level))
			items.append(create_store_item("lore_page", StoreItemType.MATERIAL, "情报资料包x1", 200, level))
			items.append(create_store_item("lore_page", StoreItemType.MATERIAL, "情报资料包x3", 500, level))
			items.append(create_store_item("bp_ww1_018", StoreItemType.CARD, "缴获卡", 220, level))
			items.append(create_store_item("bp_cold_020", StoreItemType.CARD, "稀有缴获卡", 420, level))

		"void_research":
			items.append(create_store_item("platform_future_heavy", StoreItemType.CARD, "机甲步行者", 550, level))
			items.append(create_store_item("weapon_future_rail", StoreItemType.CARD, "电磁炮", 500, level))
			items.append(create_store_item("weapon_future_plasma", StoreItemType.CARD, "等离子枪", 450, level))
			items.append(create_store_item("void_entropy_lens", StoreItemType.CARD, "虚空·熵镜", 350, level))
			items.append(create_store_item("void_gravity_well", StoreItemType.CARD, "虚空·引力井", 400, level))
			items.append(create_store_item("void_time_ripple", StoreItemType.CARD, "虚空·时空涟漪", 700, level))
			items.append(create_store_item("thunder_arc_beacon", StoreItemType.CARD, "雷霆·弧光信标", 350, level))
			items.append(create_store_item("thunder_chain_discharge", StoreItemType.CARD, "雷霆·链式放电", 400, level))
			items.append(create_store_item("thunder_emp_storm", StoreItemType.CARD, "雷霆·电磁风暴", 650, level))
			items.append(create_store_item("omega_platform", StoreItemType.CARD, "全装型机动舱", 800, level))
			items.append(create_store_item("omega_cannon", StoreItemType.CARD, "米加粒子炮", 900, level))
			items.append(create_store_item("energy_start_7", StoreItemType.CARD, "战前能量 VII", 420, level))
			items.append(create_store_item("stat_boost_hp", StoreItemType.MATERIAL, "生命强化", 450, level))
			items.append(create_store_item("stat_boost_atk", StoreItemType.MATERIAL, "攻击强化", 450, level))
			items.append(create_store_item("bp_near_012", StoreItemType.CARD, "高阶稀有缴获卡", 500, level))

		"frontier_union":
			items.append(create_store_item("platform_ww2_light", StoreItemType.CARD, "M8灰狗装甲车", 200, level))
			items.append(create_store_item("platform_ww2_medium", StoreItemType.CARD, "谢尔曼坦克", 280, level))
			items.append(create_store_item("platform_cold_medium", StoreItemType.CARD, "T-72主战坦克", 320, level))
			items.append(create_store_item("platform_modern_medium", StoreItemType.CARD, "艾布拉姆斯坦克", 450, level))
			items.append(create_store_item("weapon_ww2_smg", StoreItemType.CARD, "汤普森冲锋枪", 180, level))
			items.append(create_store_item("weapon_cold_assault", StoreItemType.CARD, "AK-47突击步枪", 220, level))
			items.append(create_store_item("weapon_modern_carbine", StoreItemType.CARD, "M4卡宾枪", 280, level))
			items.append(create_store_item("weapon_modern_dmr", StoreItemType.CARD, "MK14射手步枪", 320, level))
			items.append(create_store_item("weapon_future_laser", StoreItemType.CARD, "光束步枪", 380, level))
			items.append(create_store_item("steel_phase_armor", StoreItemType.CARD, "钢铁·相位装甲", 330, level))
			items.append(create_store_item("flame_heat_overload", StoreItemType.CARD, "烈焰·热能过载", 330, level))
			items.append(create_store_item("thunder_arc_beacon", StoreItemType.CARD, "雷霆·弧光信标", 330, level))
			items.append(create_store_item("energy_start_2", StoreItemType.CARD, "战前能量 II", 190, level))
			items.append(create_store_item("energy_start_5", StoreItemType.CARD, "战前能量 V", 230, level))
			items.append(create_store_item("nano_materials", StoreItemType.MATERIAL, "纳米材料x50", 170, level))
			items.append(create_store_item("alloy", StoreItemType.MATERIAL, "合金x50", 140, level))
			items.append(create_store_item("bp_ww2_009", StoreItemType.CARD, "缴获卡", 210, level))

	# v6.2: 未知势力警告（防御性检查）
	const _VALID_FACTION_IDS: Array[String] = [
		"iron_wall_corp", "nova_arms", "aether_dynamics",
		"quantum_logistics", "helix_recon", "void_research", "frontier_union",
	]
	if not _VALID_FACTION_IDS.has(faction_id):
		push_warning("[FactionShop] 未知势力ID: %s — 商店可能为空" % faction_id)

	# v6.2: 所有势力商店都卖基础通用符文（常见+稀有）
	_append_basic_rune_items(items, level)
	# v6.2: 追加势力专属符文商品（每个势力上架其专属符文）
	_append_faction_rune_items(items, faction_id, level)

	return _filter_invalid_card_items(items)

## v6.2: 所有势力商店通用的基础符文商品（常见+稀有，不含史诗/传说）
## 价格按稀有度递增：常见100-150，稀有200-350
static func _append_basic_rune_items(items: Array[StoreItem], level: int) -> void:
	const RuneDefs = preload("res://data/runes.gd")
	# 基础符文价格表（按稀有度）
	const RUNE_PRICES: Dictionary = {
		"common": 120,    # 常见：120声望
		"rare": 250,      # 稀有：250声望
	}
	for rune in RuneDefs.ALL_RUNES:
		# 仅通用符文（faction_id=generic）
		if rune.get("faction_id", "") != RuneDefs.FACTION_GENERIC:
			continue
		var rarity: String = rune.get("rarity", "common")
		# 仅卖常见和稀有（史诗/传说通过掉落和声望奖励获取）
		if not RUNE_PRICES.has(rarity):
			continue
		var rune_id: String = rune.get("id", "")
		var price: int = int(RUNE_PRICES[rarity])
		var display_name: String = "符文·%s" % RuneDefs.get_rune_name(rune_id)
		var rarity_name: String = RuneDefs.RARITY_NAMES.get(rarity, "")
		if not rarity_name.is_empty():
			display_name += "(%s)" % rarity_name
		items.append(create_store_item(rune_id, StoreItemType.RUNE, display_name, price, level))

## v6.2: 追加势力专属符文到商店商品列表
## 符文按 unlock_requirement 中的声望需求定价
static func _append_faction_rune_items(items: Array[StoreItem], faction_id: String, level: int) -> void:
	const RuneDefs = preload("res://data/runes.gd")
	# 势力ID → 专属符文ID前缀映射
	const FACTION_RUNE_PREFIX: Dictionary = {
		"aether_dynamics": "aether_",
		"helix_recon": "helix_",
		"nova_arms": "nova_",
		"iron_wall_corp": "iron_",
		"void_research": "void_",
		"quantum_logistics": "quantum_",
		"frontier_union": "frontier_",
	}
	if not FACTION_RUNE_PREFIX.has(faction_id):
		return
	var prefix: String = FACTION_RUNE_PREFIX[faction_id]
	for rune in RuneDefs.ALL_RUNES:
		var rune_id: String = rune.get("id", "")
		if not rune_id.begins_with(prefix):
			continue
		var unlock_req: Dictionary = rune.get("unlock_requirement", {})
		var required_rep: int = int(unlock_req.get("min_reputation", 800))
		# 商品价格 = 声望解锁要求的 60%（让商店比纯靠声望掉落更划算）
		var price: int = int(float(required_rep) * 0.6)
		var display_name: String = "符文·%s" % RuneDefs.get_rune_name(rune_id)
		var rarity_name: String = RuneDefs.RARITY_NAMES.get(rune.get("rarity", ""), "")
		if not rarity_name.is_empty():
			display_name += "(%s)" % rarity_name
		items.append(create_store_item(rune_id, StoreItemType.RUNE, display_name, price, level))

static func _filter_invalid_card_items(items: Array[StoreItem]) -> Array[StoreItem]:
	const DefaultCardsData = preload("res://data/default_cards.gd")
	const PhaseLawsRef = preload("res://data/phase_laws.gd")
	const EnemyBlueprintsRef = preload("res://data/enemy_blueprints.gd")
	const MigrationMap = preload("res://data/unit_id_migration_config.gd").UNIT_ID_MIGRATION_MAP
	var filtered: Array[StoreItem] = []
	for it in items:
		if it == null:
			continue
		# v6.2: RUNE 类型直接保留（符文ID在 RuneDefs 中定义，无需卡牌验证）
		if it.item_type == StoreItemType.RUNE:
			filtered.append(it)
			continue
		# MATERIAL 类型直接保留
		if it.item_type == StoreItemType.MATERIAL:
			filtered.append(it)
			continue
		if it.item_type == StoreItemType.CARD:
			var cid: String = it.item_id
			# v6.4: platform_* 旧ID → 新ID 迁移
			if MigrationMap.has(cid):
				cid = MigrationMap[cid]
				it.item_id = cid
			# weapon_* 旧武器卡已废弃（v6.2 武器并入战斗卡武器槽），直接过滤
			if cid.begins_with("weapon_"):
				continue
			# 法则卡：查 PhaseLaws
			if cid.begins_with("steel_") or cid.begins_with("flame_") \
				or cid.begins_with("thunder_") or cid.begins_with("void_"):
				if PhaseLawsRef.get_by_id(cid).is_empty():
					continue
			# 缴获卡：查 EnemyBlueprints
			elif cid.begins_with("bp_"):
				if EnemyBlueprintsRef.get_card_by_id(cid) == null:
					continue
			# 战斗卡：查 DefaultCards
			else:
				var card: CardResource = DefaultCardsData.get_card_by_id(cid)
				if card == null:
					continue
		filtered.append(it)
	return filtered

## 检查是否可以购买
## @param current_rep: int 当前声望
## @param current_level: int 当前等级
## @param item: StoreItem
## @return Dictionary { "ok": bool, "reason": String }
static func can_purchase_item(current_rep: int, current_level: int, item: StoreItem) -> Dictionary:
	if current_level < item.required_level:
		return {"ok": false, "reason": "level_too_low", "required_level": item.required_level, "current_level": current_level}

	if current_rep < item.reputation_cost:
		return {"ok": false, "reason": "reputation_insufficient", "required_rep": item.reputation_cost, "current_rep": current_rep}

	if item.stock == 0:
		return {"ok": false, "reason": "out_of_stock"}

	return {"ok": true}

static func _get_autoload(root_path: String, run_id: String, hypothesis_id: String) -> Node:
	var loop_obj := Engine.get_main_loop()
	if not (loop_obj is SceneTree):
		return null
	var tree := loop_obj as SceneTree
	if tree == null or tree.get_root() == null:
		return null
	var node := tree.get_root().get_node_or_null(root_path)
	return node
	# #endregion

## 发放商店物品
## @param item: StoreItem
## @return bool 是否成功发放
static func deliver_item(item: StoreItem) -> bool:
	var run_id := "run-pre-fix"
	# StoreItem 无 count 字段，材料数量按 item_id 用合理默认值（v6.4 修正：原固定 50/20 不区分商品）
	match item.item_type:
		StoreItemType.CARD:
			const DefaultCardsData = preload("res://data/default_cards.gd")
			const PhaseLawsRef = preload("res://data/phase_laws.gd")
			const EnemyBlueprintsRef = preload("res://data/enemy_blueprints.gd")
			var cid: String = item.item_id
			# v6.4: 法则卡通过 PhaseLaws 生成
			if cid.begins_with("steel_") or cid.begins_with("flame_") \
				or cid.begins_with("thunder_") or cid.begins_with("void_"):
				if not PhaseLawsRef.get_by_id(cid).is_empty():
					var law_card: CardResource = DefaultCardsData.create_law_card_resource(cid)
					if law_card:
						SignalBus.card_added_to_backpack.emit(law_card)
						return true
				return false
			# v6.4: 缴获卡通过 EnemyBlueprints 发放
			if cid.begins_with("bp_"):
				var bp_card: CardResource = EnemyBlueprintsRef.get_card_by_id(cid)
				if bp_card:
					SignalBus.card_added_to_backpack.emit(bp_card)
					return true
				return false
			# 战斗卡
			var card: CardResource = DefaultCardsData.get_card_by_id(cid)
			if card:
				SignalBus.card_added_to_backpack.emit(card)
				return true
			else:
				push_error("[FactionShop] 商店找不到卡牌: " + cid)
				return false
		StoreItemType.MATERIAL:
			var brm := _get_autoload("/root/BasicResourceManager", run_id, "H1")
			if brm and brm.has_method("add_resource"):
				match item.item_id:
					"nano_materials":
						# v6.4: 按声望成本阶梯发纳米（高成本=大量），回退 50
						var nano_amt: int = 50 if item.reputation_cost < 300 else 100
						brm.add_resource("nano_materials", nano_amt)
						return true
					"alloy":
						var alloy_amt: int = 20 if item.reputation_cost < 300 else 50
						brm.add_resource("alloy", alloy_amt)
						return true
					"crystal", "energy_block":
						brm.add_resource(item.item_id, 10)
						return true
					# v6.4: stat_boost 走 StatBoostManager
					"stat_boost_hp", "stat_boost_atk", "stat_boost_damage":
						var sbm := _get_autoload("/root/StatBoostManager", run_id, "H2")
						if sbm and sbm.has_method("apply_boost"):
							sbm.apply_boost(item.item_id, 1)
							return true
						return false
					# v6.4: lore_page 走 LoreManager
					"lore_page":
						var lm := _get_autoload("/root/LoreManager", run_id, "H3")
						if lm and lm.has_method("grant_random_lore"):
							lm.grant_random_lore()
							return true
						return false
			return false
		StoreItemType.CARD_BUNDLE:
			const CardDropGrantsScript = preload("res://scripts/card_drop_grants.gd")
			var pool_key: String = "rare_fragment" if String(item.item_id).find("rare") >= 0 else "common_fragment"
			CardDropGrantsScript.grant_from_legacy_fragment_reward_pool(pool_key, 1)
			return true
		StoreItemType.RUNE:
			# v6.2: 符文发放到 PhaseInstrumentManager
			var pim := _get_autoload("/root/PhaseInstrumentManager", run_id, "RUNE")
			if pim and pim.has_method("add_owned_rune"):
				pim.add_owned_rune(item.item_id)
				return true
			return false
	return false

## 获取默认商店库存（卡牌ID列表）
## @param faction_id: String
## @return Array
static func get_default_store_inventory(faction_id: String) -> Array:
	match faction_id:
		"iron_wall_corp":
			return ["platform_ww1_fort", "platform_ww2_heavy", "platform_cold_ifv", "steel_phase_armor"]
		"nova_arms":
			return ["weapon_ww1_mg", "weapon_ww2_mg", "weapon_cold_missile", "flame_heat_overload"]
		"aether_dynamics":
			return ["platform_cold_medium", "platform_modern_medium", "weapon_cold_sniper", "thunder_emp_storm"]
		"quantum_logistics":
			return ["energy_start_1", "energy_start_2", "energy_start_7", "steel_quick_repair"]
		"helix_recon":
			return ["platform_future_light", "weapon_future_laser", "energy_start_5", "void_barrier_shift"]
		"void_research":
			return ["weapon_future_rail", "weapon_future_plasma", "void_time_ripple", "void_entropy_lens"]
		"frontier_union":
			return ["platform_future_medium", "weapon_modern_minigun", "energy_start_2", "flame_front_bombard"]
	return []
