extends RefCounted
## 势力商店子系统：管理商店库存、商品定义、购买流程
## v6.22 批3: 货单按贡献驱动背景重排——每组织增设「特供改造图纸包」（功勋定价，
## 发放按 CompanyDefinitions.FACTION_MOD_BIAS 出该组织对口改造图纸，时代随当前关卡）；
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
	var stock: int = -1  # -1 表示无限库存

	func _init(p_id: String, p_type: StoreItemType, p_name: String, p_cost: int, p_stock: int = -1):
		item_id = p_id
		item_type = p_type
		display_name = p_name
		reputation_cost = p_cost
		stock = p_stock

## 创建商店物品
static func create_store_item(id: String, type: StoreItemType, name: String, cost: int, stock: int = -1) -> StoreItem:
	return StoreItem.new(id, type, name, cost, stock)

## 获取势力可购买物品列表
## @param faction_id: String 势力ID
## @return Array[StoreItem]
## v6.23: 删 level 形参与 required_level 门槛——原 level 取调用时玩家当前势力等级，
## can_purchase_item 同源比对恒真（不构成门槛的假字段）。功勋是唯一购买门槛。
static func get_faction_store_items(faction_id: String) -> Array[StoreItem]:
	var items: Array[StoreItem] = []

	match faction_id:
		"iron_wall_corp":
			items.append(create_store_item("platform_ww1_fort", StoreItemType.CARD, "要塞固定炮", 300))
			items.append(create_store_item("platform_ww2_heavy", StoreItemType.CARD, "虎式坦克", 400))
			items.append(create_store_item("platform_cold_medium", StoreItemType.CARD, "T-72主战坦克", 350))
			items.append(create_store_item("platform_modern_medium", StoreItemType.CARD, "艾布拉姆斯坦克", 500))
			items.append(create_store_item("platform_future_heavy", StoreItemType.CARD, "机甲步行者", 600))
			items.append(create_store_item("weapon_ww1_mg", StoreItemType.CARD, "马克沁机枪", 150))
			items.append(create_store_item("weapon_ww2_mg", StoreItemType.CARD, "MG42机枪", 200))
			items.append(create_store_item("weapon_cold_lmg", StoreItemType.CARD, "M60通用机枪", 250))
			items.append(create_store_item("weapon_modern_minigun", StoreItemType.CARD, "M134加特林", 300))
			items.append(create_store_item("alloy", StoreItemType.MATERIAL, "合金x80", 80))
			items.append(create_store_item("mod_blueprint_pack_iron_wall_corp", StoreItemType.MATERIAL, "特供图纸包·装甲堡垒", 350))

		"nova_arms":
			items.append(create_store_item("weapon_ww2_at", StoreItemType.CARD, "巴祖卡火箭筒", 250))
			items.append(create_store_item("weapon_cold_missile", StoreItemType.CARD, "陶式反坦克导弹", 350))
			items.append(create_store_item("weapon_modern_grenade", StoreItemType.CARD, "榴弹发射器", 300))
			items.append(create_store_item("weapon_future_laser", StoreItemType.CARD, "光束步枪", 400))
			items.append(create_store_item("weapon_future_rail", StoreItemType.CARD, "电磁炮", 500))
			items.append(create_store_item("weapon_future_plasma", StoreItemType.CARD, "等离子枪", 450))
			items.append(create_store_item("platform_ww2_medium", StoreItemType.CARD, "谢尔曼坦克", 300))
			items.append(create_store_item("platform_future_medium", StoreItemType.CARD, "悬浮坦克", 400))
			items.append(create_store_item("mod_blueprint_pack_nova_arms", StoreItemType.MATERIAL, "特供图纸包·火力支援", 300))
			items.append(create_store_item("nano_materials", StoreItemType.MATERIAL, "纳米材料x100", 100))

		"aether_dynamics":
			items.append(create_store_item("platform_ww1_medium", StoreItemType.CARD, "马克V型坦克", 250))
			items.append(create_store_item("platform_cold_light", StoreItemType.CARD, "悍马侦察车", 200))
			items.append(create_store_item("platform_modern_light", StoreItemType.CARD, "北极星全地形车", 250))
			items.append(create_store_item("platform_future_light", StoreItemType.CARD, "光学侦察车", 300))
			items.append(create_store_item("weapon_cold_sniper", StoreItemType.CARD, "德拉贡诺夫狙击枪", 350))
			items.append(create_store_item("weapon_modern_dmr", StoreItemType.CARD, "MK14射手步枪", 300))
			items.append(create_store_item("weapon_future_pulse", StoreItemType.CARD, "脉冲步枪", 350))
			items.append(create_store_item("bp_ww1_012", StoreItemType.CARD, "缴获卡", 250))
			items.append(create_store_item("mod_blueprint_pack_aether_dynamics", StoreItemType.MATERIAL, "特供图纸包·机动协同", 320))

		"quantum_logistics":
			items.append(create_store_item("platform_cold_ifv", StoreItemType.CARD, "布雷德利步战车", 300))
			items.append(create_store_item("platform_modern_spg", StoreItemType.CARD, "帕拉丁自行火炮", 350))
			items.append(create_store_item("weapon_ww1_rifle", StoreItemType.CARD, "李-恩菲尔德步枪", 150))
			items.append(create_store_item("weapon_cold_assault", StoreItemType.CARD, "AK-47突击步枪", 200))
			items.append(create_store_item("weapon_modern_carbine", StoreItemType.CARD, "M4卡宾枪", 250))
			items.append(create_store_item("nano_materials", StoreItemType.MATERIAL, "纳米材料x100", 100))
			items.append(create_store_item("alloy", StoreItemType.MATERIAL, "合金x80", 80))
			items.append(create_store_item("alloy", StoreItemType.MATERIAL, "合金x160", 160))
			items.append(create_store_item("bp_ww2_016", StoreItemType.CARD, "缴获卡·精选", 300))
			items.append(create_store_item("stat_boost_hp", StoreItemType.MATERIAL, "生命强化", 400))
			items.append(create_store_item("mod_blueprint_pack_quantum_logistics", StoreItemType.MATERIAL, "特供图纸包·工程后勤", 280))

		"helix_recon":
			items.append(create_store_item("platform_ww1_light", StoreItemType.CARD, "威克斯侦察车", 180))
			items.append(create_store_item("platform_ww2_light", StoreItemType.CARD, "M8灰狗装甲车", 220))
			items.append(create_store_item("platform_cold_light", StoreItemType.CARD, "悍马侦察车", 250))
			items.append(create_store_item("platform_modern_light", StoreItemType.CARD, "北极星全地形车", 280))
			items.append(create_store_item("platform_future_light", StoreItemType.CARD, "光学侦察车", 350))
			items.append(create_store_item("weapon_ww1_smg", StoreItemType.CARD, "MP18冲锋枪", 150))
			items.append(create_store_item("weapon_ww2_smg", StoreItemType.CARD, "汤普森冲锋枪", 200))
			items.append(create_store_item("weapon_modern_carbine", StoreItemType.CARD, "M4卡宾枪", 250))
			items.append(create_store_item("weapon_future_pulse", StoreItemType.CARD, "脉冲步枪", 300))
			items.append(create_store_item("lore_page", StoreItemType.MATERIAL, "情报资料包x1", 200))
			items.append(create_store_item("lore_page", StoreItemType.MATERIAL, "情报资料包x3", 500))
			items.append(create_store_item("bp_ww1_018", StoreItemType.CARD, "缴获卡", 220))
			items.append(create_store_item("mod_blueprint_pack_helix_recon", StoreItemType.MATERIAL, "特供图纸包·侦察情报", 300))

		"void_research":
			items.append(create_store_item("platform_future_heavy", StoreItemType.CARD, "机甲步行者", 550))
			items.append(create_store_item("weapon_future_rail", StoreItemType.CARD, "电磁炮", 500))
			items.append(create_store_item("weapon_future_plasma", StoreItemType.CARD, "等离子枪", 450))
			items.append(create_store_item("omega_platform", StoreItemType.CARD, "全装型机动舱", 800))
			items.append(create_store_item("omega_cannon", StoreItemType.CARD, "米加粒子炮", 900))
			items.append(create_store_item("stat_boost_hp", StoreItemType.MATERIAL, "生命强化", 450))
			items.append(create_store_item("stat_boost_atk", StoreItemType.MATERIAL, "攻击强化", 450))
			items.append(create_store_item("mod_blueprint_pack_void_research", StoreItemType.MATERIAL, "特供图纸包·相位通用", 450))

		"frontier_union":
			items.append(create_store_item("platform_ww2_light", StoreItemType.CARD, "M8灰狗装甲车", 200))
			items.append(create_store_item("platform_ww2_medium", StoreItemType.CARD, "谢尔曼坦克", 280))
			items.append(create_store_item("platform_cold_medium", StoreItemType.CARD, "T-72主战坦克", 320))
			items.append(create_store_item("platform_modern_medium", StoreItemType.CARD, "艾布拉姆斯坦克", 450))
			items.append(create_store_item("weapon_ww2_smg", StoreItemType.CARD, "汤普森冲锋枪", 180))
			items.append(create_store_item("weapon_cold_assault", StoreItemType.CARD, "AK-47突击步枪", 220))
			items.append(create_store_item("weapon_modern_carbine", StoreItemType.CARD, "M4卡宾枪", 280))
			items.append(create_store_item("weapon_modern_dmr", StoreItemType.CARD, "MK14射手步枪", 320))
			items.append(create_store_item("weapon_future_laser", StoreItemType.CARD, "光束步枪", 380))
			items.append(create_store_item("nano_materials", StoreItemType.MATERIAL, "纳米材料x100", 100))
			items.append(create_store_item("alloy", StoreItemType.MATERIAL, "合金x80", 80))
			items.append(create_store_item("bp_ww2_009", StoreItemType.CARD, "缴获卡", 210))
			items.append(create_store_item("mod_blueprint_pack_frontier_union", StoreItemType.MATERIAL, "特供图纸包·护路维稳", 260))

	# v6.2: 未知势力警告（防御性检查）
	const _VALID_FACTION_IDS: Array[String] = [
		"iron_wall_corp", "nova_arms", "aether_dynamics",
		"quantum_logistics", "helix_recon", "void_research", "frontier_union",
	]
	if not _VALID_FACTION_IDS.has(faction_id):
		push_warning("[FactionShop] 未知势力ID: %s — 商店可能为空" % faction_id)

	# v6.2: 所有势力商店都卖基础通用符文（常见+稀有）
	_append_basic_rune_items(items)
	# v6.2: 追加势力专属符文商品（每个势力上架其专属符文）
	_append_faction_rune_items(items, faction_id)

	return _filter_invalid_card_items(items)

## v6.2: 所有势力商店通用的基础符文商品（常见+稀有，不含史诗/传说）
## 价格按稀有度递增：常见100-150，稀有200-350
static func _append_basic_rune_items(items: Array[StoreItem]) -> void:
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
		items.append(create_store_item(rune_id, StoreItemType.RUNE, display_name, price))

## v6.2: 追加势力专属符文到商店商品列表
## 符文按 unlock_requirement 中的声望需求定价
static func _append_faction_rune_items(items: Array[StoreItem], faction_id: String) -> void:
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
		items.append(create_store_item(rune_id, StoreItemType.RUNE, display_name, price))

static func _filter_invalid_card_items(items: Array[StoreItem]) -> Array[StoreItem]:
	const DefaultCardsData = preload("res://data/default_cards.gd")
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
			# 缴获卡：查 EnemyBlueprints
			if cid.begins_with("bp_"):
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
## @param current_rep: int 当前功勋余额
## @param item: StoreItem
## @return Dictionary { "ok": bool, "reason": String }
## v6.23: 删 current_level 形参与 level_too_low 分支（required_level 是恒真假门槛，已删除）
static func can_purchase_item(current_rep: int, item: StoreItem) -> Dictionary:
	if current_rep < item.reputation_cost:
		return {"ok": false, "reason": "reputation_insufficient", "required_rep": item.reputation_cost, "current_rep": current_rep}

	if item.stock == 0:
		return {"ok": false, "reason": "out_of_stock"}

	return {"ok": true}

static func _get_autoload(root_path: String) -> Node:
	var loop_obj := Engine.get_main_loop()
	if not (loop_obj is SceneTree):
		return null
	var tree := loop_obj as SceneTree
	if tree == null or tree.get_root() == null:
		return null
	return tree.get_root().get_node_or_null(root_path)

## 发放商店物品
## @param item: StoreItem
## @return bool 是否成功发放
static func deliver_item(item: StoreItem) -> bool:
	# StoreItem 无 count 字段，材料数量按 item_id 用合理默认值（v6.4 修正：原固定 50/20 不区分商品）
	match item.item_type:
		StoreItemType.CARD:
			const DefaultCardsData = preload("res://data/default_cards.gd")
			const EnemyBlueprintsRef = preload("res://data/enemy_blueprints.gd")
			var cid: String = item.item_id
			# v7.0: 购买的卡牌全部实例化（独立养成身份）
			var ir := _get_autoload("/root/InstanceRegistry")
			# v6.4: 缴获卡通过 EnemyBlueprints 发放
			if cid.begins_with("bp_"):
				var bp_card: CardResource = EnemyBlueprintsRef.get_card_by_id(cid)
				if bp_card:
					var bp_inst: CardResource = bp_card
					if ir != null and ir.has_method("create_instance_from_template"):
						bp_inst = ir.create_instance_from_template(bp_card)
					SignalBus.card_added_to_backpack.emit(bp_inst)
					return true
				return false
			# 战斗卡
			var card: CardResource = DefaultCardsData.get_card_by_id(cid)
			if card:
				var card_inst: CardResource = card
				if ir != null and ir.has_method("create_instance"):
					card_inst = ir.create_instance(cid)
				# v26 批次3：缴获卡兑换时滚动稀有度（非 captured_ 卡不动）
				ManufacturePools.apply_captured_quality(card_inst)
				SignalBus.card_added_to_backpack.emit(card_inst)
				return true
			else:
				push_error("[FactionShop] 商店找不到卡牌: " + cid)
				return false
		StoreItemType.MATERIAL:
			# v6.22 批3: 组织特供改造图纸包——按 FACTION_MOD_BIAS 出对口图纸（时代随当前关卡）
			if String(item.item_id).begins_with("mod_blueprint_pack_"):
				return _deliver_mod_blueprint_pack(item)
			var brm := _get_autoload("/root/BasicResourceManager")
			if brm and brm.has_method("add_resource"):
				match item.item_id:
					# 记录1#9: 补 crystal/energy_block——原 match 只认 nano/alloy，
					# 商店上架的晶体/能量块购买时 deliver 落空 return false（不发货）
					"nano_materials", "alloy", "crystal", "energy_block":
						# 2026-09-19 经济修复：1 功勋 = 1 材料（原按价格阶梯猜测发放量，
						# "合金x50" 实发 20 品名错位，且功勋材料包定价是 trap choice）。
						# 商品定义三方自洽：品名数量 = 功勋价 = 发放量，永不漂移。
						brm.add_resource(item.item_id, maxi(1, item.reputation_cost))
						return true
					# v6.4: stat_boost 走 StatBoostManager
					"stat_boost_hp", "stat_boost_atk", "stat_boost_damage":
						var sbm := _get_autoload("/root/StatBoostManager")
						if sbm and sbm.has_method("apply_boost"):
							sbm.apply_boost(item.item_id)  # v26.6: 修复——签名单参(apply_boost(boost_id))，此前两参调用致商店强化购买报错
							return true
						return false
					# v6.4: lore_page 走 LoreManager
					"lore_page":
						var lm := _get_autoload("/root/LoreManager")
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
			var pim := _get_autoload("/root/PhaseInstrumentManager")
			if pim and pim.has_method("add_owned_rune"):
				pim.add_owned_rune(item.item_id)
				return true
			return false
	return false

## v6.22 批3: 组织特供图纸包发放——roll 一张对口改造图纸入 IntelItemBag
static func _deliver_mod_blueprint_pack(item: StoreItem) -> bool:
	const IntelManualItemsRef = preload("res://data/intel_manual_items.gd")
	const CompanyDefsRef = preload("res://data/company_definitions.gd")
	const LevelErasRef = preload("res://data/level_eras.gd")
	var bag := _get_autoload("/root/IntelItemBag")
	if bag == null or not bag.has_method("add_item"):
		return false
	var fid: String = String(item.item_id).trim_prefix("mod_blueprint_pack_")
	var bias: Array = CompanyDefsRef.FACTION_MOD_BIAS.get(fid, [])
	var enemy_type: String = "infantry"
	if not bias.is_empty():
		enemy_type = String(bias[0])
	var cur_level: int = 1
	var gm := _get_autoload("/root/GameManager")
	if gm != null and "current_level" in gm:
		cur_level = int(gm.get("current_level"))
	var max_era: int = clampi(LevelErasRef.get_era(cur_level), 0, 4)
	var drop: Dictionary = IntelManualItemsRef.roll_random_mod_blueprint(enemy_type, "elite", 3, bias, max_era)
	if drop.is_empty():
		return false
	bag.add_item(String(drop.get("item_type", "")), 1)
	return true

## 获取默认商店库存（卡牌ID列表）
## @param faction_id: String
## @return Array
static func get_default_store_inventory(faction_id: String) -> Array:
	match faction_id:
		"iron_wall_corp":
			return ["platform_ww1_fort", "platform_ww2_heavy", "platform_cold_ifv"]
		"nova_arms":
			return ["weapon_ww1_mg", "weapon_ww2_mg", "weapon_cold_missile"]
		"aether_dynamics":
			return ["platform_cold_medium", "platform_modern_medium", "weapon_cold_sniper"]
		"quantum_logistics":
			# v7.x: 能量卡移除，替换为支援/资源类卡
			return ["platform_cold_ifv", "platform_modern_spg", "nano_materials"]
		"helix_recon":
			return ["platform_future_light", "weapon_future_laser"]
		"void_research":
			return ["weapon_future_rail", "weapon_future_plasma"]
		"frontier_union":
			return ["platform_future_medium", "weapon_modern_minigun", "weapon_modern_dmr"]
	return []
