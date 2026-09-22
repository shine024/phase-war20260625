extends Node
## 势力系统管理器（委托层）：管理7个组织的贡献、商品库存、技能树、事件等
##
## 本文件作为 Autoload 入口，保持对外公共 API 不变。
## 声望计算逻辑已拆分到 managers/faction/faction_reputation.gd
## 商店逻辑已拆分到 managers/faction/faction_shop.gd
##
## v6.22 贡献驱动改版：背景设定改为"集体穿越、人皆迷失"——
## 势力不再占领领地、不互相进攻。删除：FACTION_RELATIONS 关系矩阵、
## level_occupation 占领状态机、攻克势力反应、势力变体卡死链。
## 关卡归属只保留 level_information.gd 静态表作"曾属于"风味标注。

const DEBUG_LOG := false
##
## 所有外部调用者（faction_panel / store_panel / quest_manager / save_manager 等）
## 通过 /root/FactionSystemManager 访问，接口保持 100% 兼容。

const CompanyDefinitions = preload("res://data/company_definitions.gd")
const LevelInformation = preload("res://data/level_information.gd")
const BasicResources = preload("res://data/basic_resources.gd")
const FactionSkillManager = preload("res://managers/faction/faction_skill_manager.gd")
const FactionEventManager = preload("res://managers/faction/faction_event_manager.gd")

# ─────────────────────────────────────────────
#  信号与运行时状态
# ─────────────────────────────────────────────

signal faction_reputation_changed(faction_id: String, delta: int, new_value: int)
signal faction_level_up(faction_id: String, new_level: int)
signal faction_store_updated(faction_id: String)
signal active_faction_changed(faction_id: String)
signal faction_skill_unlocked(faction_id: String, skill_id: String)
signal faction_event_generated(event: Dictionary)

## 全局声望数据：faction_id -> 声望值（0-10000）
var faction_reputation: Dictionary = {}

## 势力等级：faction_id -> 等级（1-10）
var faction_level: Dictionary = {}

## 势力商店库存：faction_id -> [card_ids...]
var faction_store_inventory: Dictionary = {}

## 当前激活势力（空字符串=未激活）
var active_faction: String = ""

## v6.6: 已发放的势力独占卡ID列表（避免升级时重复发放）
var exclusive_cards_granted: Array = []

## v30 R2b（设计审查 F-04 根治，2026-09-13）：功勋——势力商店/符文的消费货币。
## 语义分离：声望=等级进度轴（只反映立场变化，不再被消费拉低）；功勋=全局可花货币，
## 与正声望增量 1:1 镜像获取（相位师战/关卡反应/任务/事件）。购买扣功勋不扣声望。
const DEFAULT_STARTING_MERIT := 500
var merit_points: int = DEFAULT_STARTING_MERIT

## 关卡信息实例
var level_info: LevelInformation

## 势力定义：faction_id -> { name, desc, color }
var _faction_definitions: Dictionary = {}

## 缓存所有势力ID列表
var _all_faction_ids: Array = []

## 势力技能树状态：faction_id -> {"unlocked_skills": [], "spent_points": 0, "bonus_points": 0}
var faction_skill_states: Dictionary = {}

## 势力事件管理器实例
var _event_manager: Node = null

# v9.x（P2-7范围C）：合成管理器实例字段已随合成系统删除移除

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	level_info = LevelInformation.get_shared()
	_init_faction_data()
	# 监听战斗结束信号（触发势力事件检查）
	var sb: Node = get_node_or_null("/root/SignalBus")
	if sb != null and not sb.battle_ended.is_connected(_on_battle_ended):
		sb.battle_ended.connect(_on_battle_ended)
	# 将势力信号转发到 SignalBus（UI 层统一监听）
	if sb != null:
		faction_reputation_changed.connect(sb.faction_reputation_changed.emit)
		faction_level_up.connect(sb.faction_level_up.emit)
		faction_store_updated.connect(sb.faction_store_updated.emit)
		active_faction_changed.connect(sb.active_faction_changed.emit)
		faction_skill_unlocked.connect(sb.faction_skill_unlocked.emit)
		faction_event_generated.connect(sb.faction_event_generated.emit)

func _init_faction_data() -> void:
	var factions = CompanyDefinitions.get_all()
	_all_faction_ids.clear()
	var start_rep: int = FactionReputation.DEFAULT_STARTING_REPUTATION
	var start_lv: int = FactionReputation.get_level_from_reputation(start_rep)

	for faction_data in factions:
		var faction_id = faction_data.get("id", "")
		if faction_id.is_empty():
			continue

		faction_reputation[faction_id] = start_rep
		faction_level[faction_id] = start_lv
		faction_store_inventory[faction_id] = FactionShop.get_default_store_inventory(faction_id)
		_faction_definitions[faction_id] = faction_data
		_all_faction_ids.append(faction_id)

# ─────────────────────────────────────────────
#  声望操作（委托给 FactionReputation）
# ─────────────────────────────────────────────

## 增加或减少某个势力的声望
func add_faction_reputation(faction_id: String, delta: int) -> int:
	if not faction_reputation.has(faction_id):
		return 0

	# v26.15b: 声望获取加成消费（resource 桶 reputation_bonus 此前零消费）。
	# 只对正增益生效（购买扣减不走加成）；按该势力自己的技能状态计。
	if delta > 0 and faction_skill_states.has(faction_id):
		var rep_bonus: float = FactionSkillManager.get_resource_value(faction_skill_states[faction_id], faction_id, "reputation_bonus")
		if rep_bonus > 0.0:
			delta = int(round(float(delta) * (1.0 + rep_bonus)))

	var old_rep: int = faction_reputation[faction_id]
	var result: Dictionary = FactionReputation.apply_delta(old_rep, delta)
	faction_reputation[faction_id] = result["new_rep"]

	# v30 R2b：正声望增量 1:1 镜像为功勋（含 reputation_bonus 加成后的最终值）。
	# 购买扣减（delta<0）不镜像——功勋只赚不亏，消费走 merit_points 直扣。
	if delta > 0:
		merit_points += delta
		FeatureUnlockPopup.show_once("merit_intro", "获得功勋",
			"战斗胜利、攻克关卡与完成任务都会积累功勋——势力补给与符文现在用功勋支付，不再占用声望等级。")

	if result["leveled_up"]:
		faction_level[faction_id] = result["new_level"]
		_update_faction_store_for_level_up(faction_id)
		# v6.2: 声望升级奖励 — 每3级赠送1个该势力专属符文
		_grant_reputation_level_reward(faction_id, result["new_level"])
		# v6.6: 检查并发放达到等级门槛的势力独占卡
		_grant_exclusive_cards_on_level_up(faction_id, result["new_rep"])
		emit_signal("faction_level_up", faction_id, result["new_level"])
		# 批次三 B4：首次声望升级一句话说明（之后升级靠面板自身反馈）
		FeatureUnlockPopup.show_once("faction_level_up", "势力声望提升",
			"%s 声望达到 %d 级——更高声望解锁更多商店商品与专属奖励；达到 6200（8级）可激活商店全域访问。" % [get_faction_display_name(faction_id), int(result["new_level"])])

	emit_signal("faction_reputation_changed", faction_id, delta, result["new_rep"])
	return result["new_rep"]

## v6.2: 声望等级奖励 — 每3级（Lv3/6/9）赠送1个该势力专属符文
func _grant_reputation_level_reward(faction_id: String, new_level: int) -> void:
	if new_level % 3 != 0:
		return  # 仅在 Lv3/6/9 触发
	var RuneDefs = preload("res://data/runes.gd")
	# 按等级选择符文稀有度：Lv3→稀有, Lv6→史诗, Lv9→传说
	var target_rarity: String = RuneDefs.RARITY_RARE
	match new_level:
		3: target_rarity = RuneDefs.RARITY_RARE
		6: target_rarity = RuneDefs.RARITY_EPIC
		9: target_rarity = RuneDefs.RARITY_LEGENDARY
		_: return
	# 查找该势力对应稀有度的专属符文
	var faction_runes: Array[Dictionary] = RuneDefs.get_runes_by_faction(faction_id)
	var candidates: Array[Dictionary] = []
	for r in faction_runes:
		if r.get("rarity", "") == target_rarity:
			candidates.append(r)
	if candidates.is_empty():
		return
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	if pim and pim.has_method("add_owned_rune"):
		# 选第一个（避免随机导致玩家错过关键符文）
		pim.add_owned_rune(candidates[0]["id"])

## v6.6: 势力升级时，检查并发放达到 min_reputation 门槛的独占卡
## 每张独占卡仅在首次达到门槛时发放一次（exclusive_cards_granted 去重）
func _grant_exclusive_cards_on_level_up(faction_id: String, new_rep: int) -> void:
	var ExclusiveCards = preload("res://data/faction_exclusive_cards.gd")
	var exclusives: Array = ExclusiveCards.get_exclusives_for_faction(faction_id)
	if exclusives.is_empty():
		return
	var sm: Node = get_node_or_null("/root/SaveManager")
	var granted_any := false
	for cfg in exclusives:
		var card_id: String = cfg.get("id", "")
		var min_rep: int = int(cfg.get("min_reputation", 99999))
		if card_id.is_empty():
			continue
		# 声望达标且未发放过
		if new_rep >= min_rep and not exclusive_cards_granted.has(card_id):
			# 注册到 DefaultCards 动态缓存（使 get_card_by_id 可用）
			var DefaultCards = preload("res://data/default_cards.gd")
			var card: CardResource = ExclusiveCards.create_card(cfg)
			if card:
				DefaultCards.register_dynamic_card(card)
			# 发放到玩家背包
			if sm and sm.has_method("enqueue_backpack_card_id"):
				# v7.x 修复（Bug1）：势力专属卡必须实例化后用 instance_id 入队（原对齐 synthesis_manager，该系统已删）。
				# 原版传裸 card_id，导致该卡在 InstanceRegistry 不存在，背包显示/强化/装配全部走重建兜底路径。
				var ir: Node = get_node_or_null("/root/InstanceRegistry")
				var enqueue_id: String = card_id
				if ir != null and ir.has_method("create_instance_from_template") and card != null:
					var inst: CardResource = ir.create_instance_from_template(card)
					if inst != null and not inst.instance_id.is_empty():
						enqueue_id = inst.instance_id
				sm.enqueue_backpack_card_id(enqueue_id)
			exclusive_cards_granted.append(card_id)
			# v7.x 战报一致性修复：势力专属卡实际已入包，但原路径不调 collect_battle_card，
			# 导致战报"本局缴获"区不显示这些卡（玩家得到了但战报没写）。
			# 时序安全：声望升级由任务/事件/相位师战奖励触发（同步链），面板弹出在 call_deferred
			#（下一帧），本局收集器此时仍存活，补记的条目会被面板读到。
			var _gm_collector: Node = get_node_or_null("/root/GameManager")
			if _gm_collector != null and _gm_collector.has_method("collect_battle_card"):
				var _DefaultCardsForName = preload("res://data/default_cards.gd")
				var _fe_display_name: String = _DefaultCardsForName.get_safe_display_name(card_id)
				_gm_collector.collect_battle_card(card_id, _fe_display_name, 1, "势力专属卡")
			granted_any = true
	if granted_any and sm and sm.has_method("save_game"):
		sm.call_deferred("save_game")

# ─────────────────────────────────────────────
#  v6.22: 关卡历史归属（纯风味标注，无数值影响）
# ─────────────────────────────────────────────

## 查询关卡历史归属势力（静态表，"曾属于"风味标注）
## [return] faction_id；无主之地（如1-20关教学区）返回空字符串
func get_level_historical_faction(level: int) -> String:
	if level_info:
		return level_info.get_level_faction(level)
	return ""

## 查询某组织历史辖区覆盖的所有关卡（静态表）
## [return] 关卡号数组（int，升序）；无辖区返回空数组
func get_historical_levels(faction_id: String) -> Array:
	if faction_id.is_empty():
		return []
	var result: Array = []
	for level in range(1, 101):
		if get_level_historical_faction(level) == faction_id:
			result.append(level)
	return result

func get_faction_reputation(faction_id: String) -> int:
	return faction_reputation.get(faction_id, 0)

func get_faction_level(faction_id: String) -> int:
	return faction_level.get(faction_id, 1)

func get_faction_progress_to_next_level(faction_id: String) -> Dictionary:
	var current_rep: int = get_faction_reputation(faction_id)
	var current_level: int = get_faction_level(faction_id)
	return FactionReputation.get_progress_to_next_level(current_rep, current_level)

func _update_faction_store_for_level_up(faction_id: String) -> void:
	emit_signal("faction_store_updated", faction_id)

## 检查是否启用全局访问
func has_global_access() -> bool:
	return FactionReputation.has_global_access(faction_reputation)

# ─────────────────────────────────────────────
#  商店操作（委托给 FactionShop）
# ─────────────────────────────────────────────

## 获取势力可购买物品列表
func get_faction_store_items(faction_id: String) -> Array[FactionShop.StoreItem]:
	var level: int = get_faction_level(faction_id)
	return FactionShop.get_faction_store_items(faction_id, level)

## 检查是否可以购买（v30 R2b：货币轴=功勋；等级门沿用声望等级）
func can_purchase_item(faction_id: String, item: FactionShop.StoreItem) -> Dictionary:
	return FactionShop.can_purchase_item(merit_points, get_faction_level(faction_id), item)

## 功勋余额（v30 R2b：商店/符文消费货币，UI 显示用）
func get_merit_points() -> int:
	return merit_points

## 扣功勋（v30 R2b：符文直购路径用；返回 false=余额不足，未扣款）
func spend_merit(amount: int) -> bool:
	if amount <= 0:
		return true
	if merit_points < amount:
		return false
	merit_points -= amount
	return true

## 加功勋（v6.22：成就奖励等直发路径用，不走声望镜像链）
func add_merit(amount: int) -> void:
	if amount <= 0:
		return
	merit_points += amount

## 购买物品
## v30 R2b：消费货币从声望改为功勋（声望等级不再因购买下跌）；等级门与库存检查不变。
func purchase_item(faction_id: String, item: FactionShop.StoreItem) -> Dictionary:
	var can: Dictionary = can_purchase_item(faction_id, item)
	if not can.get("ok", false):
		return can

	# v26.15b: 商店折扣消费（resource 桶 shop_discount 此前零消费）——按折扣价扣功勋
	var shop_discount: float = 0.0
	if faction_skill_states.has(faction_id):
		shop_discount = clampf(FactionSkillManager.get_resource_value(faction_skill_states[faction_id], faction_id, "shop_discount"), 0.0, 0.5)
	var eff_cost: int = int(ceil(float(item.reputation_cost) * (1.0 - shop_discount)))
	# 折扣后余额复核（can_purchase_item 用原价预检，可能原价不足而折扣价足够）
	if merit_points < eff_cost:
		return {"ok": false, "reason": "reputation_insufficient", "required_rep": eff_cost, "current_rep": merit_points}

	# 扣除功勋（折扣价）
	merit_points -= eff_cost

	# 发放物品
	var delivered: bool = FactionShop.deliver_item(item)
	if not delivered:
		# 回退功勋（按实付折扣价；旧代码按原价回退会白送差价，顺手修正）
		merit_points += eff_cost
		return {"ok": false, "reason": "delivery_failed"}

	# 更新库存（如果有库存限制）
	if item.stock > 0:
		item.stock -= 1

	return {"ok": true, "item_id": item.item_id}

## 获取势力商店的当前库存
func get_faction_store_inventory(faction_id: String) -> Array:
	return faction_store_inventory.get(faction_id, []).duplicate()

## 添加卡牌到势力商店
func add_item_to_store(faction_id: String, card_id: String) -> void:
	if not faction_store_inventory.has(faction_id):
		faction_store_inventory[faction_id] = []

	if not card_id in faction_store_inventory[faction_id]:
		faction_store_inventory[faction_id].append(card_id)
		emit_signal("faction_store_updated", faction_id)

## 从势力商店移除卡牌
func remove_item_from_store(faction_id: String, card_id: String) -> void:
	if faction_store_inventory.has(faction_id):
		if card_id in faction_store_inventory[faction_id]:
			faction_store_inventory[faction_id].erase(card_id)
			emit_signal("faction_store_updated", faction_id)

# ─────────────────────────────────────────────
#  信息查询
# ─────────────────────────────────────────────

## 获取势力的完整信息
func get_faction_info(faction_id: String) -> Dictionary:
	var definition = _faction_definitions.get(faction_id, {})

	return {
		"id": faction_id,
		"name": definition.get("name", ""),
		"description": definition.get("desc", ""),
		"reputation": get_faction_reputation(faction_id),
		"level": get_faction_level(faction_id),
		"level_progress": get_faction_progress_to_next_level(faction_id),
		"store_inventory": get_faction_store_inventory(faction_id),
		# v6.22: 关卡历史归属（静态表，"曾属于"风味）——原动态占领 controlled_levels 已删
		"historical_levels": get_historical_levels(faction_id),
		"is_active": (faction_id == active_faction),
	}

# ─────────────────────────────────────────────
#  势力激活
# ─────────────────────────────────────────────

## 设置当前激活势力
func set_active_faction(faction_id: String) -> void:
	if faction_id == active_faction:
		return
	# 校验势力ID有效
	if not faction_id.is_empty():
		var found: bool = false
		for fid in _all_faction_ids:
			if String(fid) == faction_id:
				found = true
				break
		if not found:
			return
	active_faction = faction_id
	active_faction_changed.emit(active_faction)
	# v7.x: 激活势力改变第 3 层加成（势力技能 stat_bonus），刷新玩家相位师战力缓存避免面板陈旧
	var _pim_sa: Node = get_node_or_null("/root/PhaseInstrumentManager")
	if _pim_sa != null and _pim_sa.has_method("refresh_player_master_eval"):
		_pim_sa.refresh_player_master_eval()

## 获取当前激活势力ID（空字符串=未激活）
func get_active_faction() -> String:
	return active_faction

## 获取所有势力的信息
func get_all_factions_info() -> Array:
	var result = []
	for faction_data in CompanyDefinitions.get_all():
		var faction_id = faction_data.get("id", "")
		if not faction_id.is_empty():
			result.append(get_faction_info(faction_id))
	return result

# ─────────────────────────────────────────────
#  存档功能
# ─────────────────────────────────────────────

func save_state() -> Dictionary:
	var skill_states: Dictionary = {}
	for fid in faction_skill_states:
		skill_states[fid] = faction_skill_states[fid].duplicate(true)
	var event_state: Dictionary = {}
	if _event_manager != null:
		event_state = _event_manager.save_state()
	return {
		"faction_reputation": faction_reputation.duplicate(true),
		"faction_level": faction_level.duplicate(true),
		# v30 R2b：功勋（旧档缺 key = 起步值，免迁移）
		"faction_merit": merit_points,
		"faction_store_inventory": faction_store_inventory.duplicate(true),
		"faction_active": active_faction,
		"faction_skill_states": skill_states,
		"faction_event_state": event_state,
		"exclusive_cards_granted": exclusive_cards_granted.duplicate(),
		# v6.22: faction_variants_unlocked / level_occupation 死键停写（旧档读档静默忽略）
	}

func load_state(data: Dictionary) -> void:
	# v9.x 复查修复：事件/合成管理器统一在最前重建（幂等，见 _init_event_manager）。
	# 原实现仅非空档路径初始化 → 新游戏（空字典）整局 _event_manager==null，
	# 势力事件系统静默失效；且读档后再开新档会残留上一局事件/忠诚度状态。
	_init_event_manager()
	# 新游戏：SaveManager 传入空字典，必须整表重置（否则仍保留上一局的声望）
	if data.is_empty():
		_init_faction_data()
		merit_points = DEFAULT_STARTING_MERIT  # v30 R2b：功勋重置
		active_faction = ""
		exclusive_cards_granted.clear()
		return
	if data.has("faction_reputation") and data["faction_reputation"] is Dictionary:
		faction_reputation = (data["faction_reputation"] as Dictionary).duplicate(true)

	# v30 R2b：功勋（旧档缺 key = 起步值 500，免 schema 迁移）
	merit_points = int(data.get("faction_merit", DEFAULT_STARTING_MERIT))

	if data.has("faction_level") and data["faction_level"] is Dictionary:
		faction_level = (data["faction_level"] as Dictionary).duplicate(true)

	if data.has("faction_store_inventory") and data["faction_store_inventory"] is Dictionary:
		faction_store_inventory = (data["faction_store_inventory"] as Dictionary).duplicate(true)
	# v6.14 R6：unlocked_faction_instruments 残段已删——旧档该 key 静默跳过
	# 势力激活（向后兼容：旧存档无此字段→默认无势力激活）
	if data.has("faction_active"):
		active_faction = String(data["faction_active"])
	else:
		active_faction = ""
	# v6.22: 旧档 faction_variants_unlocked 死键静默忽略（变体卡链已删）
	# 技能树状态（向后兼容：旧存档无此字段→初始化默认值）
	if data.has("faction_skill_states") and data["faction_skill_states"] is Dictionary:
		faction_skill_states = (data["faction_skill_states"] as Dictionary).duplicate(true)
	else:
		_init_faction_skill_states()
	# 事件管理器状态（实例已在函数开头重建）
	if data.has("faction_event_state") and data["faction_event_state"] is Dictionary:
		_event_manager.load_state(data["faction_event_state"])
	# v9.x（P2-7范围C）：旧档 synthesis_state key 静默跳过（合成系统删除）
	# v6.6: 已发放独占卡（向后兼容）
	if data.has("exclusive_cards_granted") and data["exclusive_cards_granted"] is Array:
		exclusive_cards_granted = (data["exclusive_cards_granted"] as Array).duplicate()
	else:
		exclusive_cards_granted = []
	# v6.22: 旧档 level_occupation 死键静默忽略（占领状态机已删；关卡归属=静态历史表）
	# 重建已发放的独占卡到 DefaultCards 动态缓存（使背包/装备可用）
	call_deferred("_rebuild_exclusive_cards_cache")
	_ensure_faction_keys_after_load()

## 重建已发放独占卡的 CardResource 到 DefaultCards 动态缓存
func _rebuild_exclusive_cards_cache() -> void:
	if exclusive_cards_granted.is_empty():
		return
	var ExclusiveCards = preload("res://data/faction_exclusive_cards.gd")
	var DefaultCards = preload("res://data/default_cards.gd")
	for card_id in exclusive_cards_granted:
		var cid := String(card_id)
		if not ExclusiveCards.is_exclusive_card(cid):
			continue
		# 从 EXCLUSIVE_CARDS 表查找配置
		var cfg: Dictionary = {}
		for c in ExclusiveCards.EXCLUSIVE_CARDS:
			if c.get("id", "") == cid:
				cfg = c
				break
		if cfg.is_empty():
			continue
		var card: CardResource = ExclusiveCards.create_card(cfg)
		if card:
			DefaultCards.register_dynamic_card(card)

## 读档后补全各势力键
func _ensure_faction_keys_after_load() -> void:
	for faction_data in CompanyDefinitions.get_all():
		var fid: String = String(faction_data.get("id", ""))
		if fid.is_empty():
			continue
		if not faction_reputation.has(fid):
			faction_reputation[fid] = FactionReputation.DEFAULT_STARTING_REPUTATION
		else:
			faction_reputation[fid] = int(faction_reputation[fid])
		# M6 加固: faction_level 是 reputation 的派生值，消除双源不同步风险——
		# 存档里的 level 必须与从 reputation 派生的一致，否则以派生值为准。
		# （v6.10 设计原则：派生状态不存储。此处保留存储字段兼容旧存档，但强制以派生值为准）
		var derived_level: int = FactionReputation.get_level_from_reputation(int(faction_reputation[fid]))
		if not faction_level.has(fid) or int(faction_level[fid]) != derived_level:
			faction_level[fid] = derived_level
		else:
			faction_level[fid] = int(faction_level[fid])
		if not faction_store_inventory.has(fid):
			faction_store_inventory[fid] = FactionShop.get_default_store_inventory(fid)
		if not faction_skill_states.has(fid):
			faction_skill_states[fid] = FactionSkillManager.create_default_state(fid)

## 合并旧版 CompanyManager 存档中的 company_rep
func merge_legacy_company_rep(legacy: Dictionary) -> void:
	if legacy.is_empty():
		return
	_ensure_faction_keys_after_load()
	for k in legacy.keys():
		var fid: String = String(k)
		var v: int = int(legacy[k])
		var cur: int = int(faction_reputation.get(fid, 0))
		faction_reputation[fid] = max(cur, v)
	for fid2 in faction_reputation.keys():
		var r: int = int(faction_reputation[fid2])
		faction_level[fid2] = FactionReputation.get_level_from_reputation(r)

# ═══════════════════════════════════════════════════
#  势力技能树管理
# ═══════════════════════════════════════════════════

## 初始化所有势力技能状态
func _init_faction_skill_states() -> void:
	faction_skill_states.clear()
	for faction_data in CompanyDefinitions.get_all():
		var fid: String = faction_data.get("id", "")
		if not fid.is_empty():
			faction_skill_states[fid] = FactionSkillManager.create_default_state(fid)

## 解锁势力技能
func unlock_faction_skill(faction_id: String, skill_id: String) -> bool:
	if not faction_skill_states.has(faction_id):
		return false
	var fl: int = get_faction_level(faction_id)
	var state: Dictionary = faction_skill_states[faction_id]
	if FactionSkillManager.unlock_skill(state, faction_id, skill_id, fl):
		faction_skill_unlocked.emit(faction_id, skill_id)
		# v7.x: 解锁势力技能可能改变第 3 层加成（get_active_faction_skill_effects），刷新玩家相位师战力缓存
		var _pim_us: Node = get_node_or_null("/root/PhaseInstrumentManager")
		if _pim_us != null and _pim_us.has_method("refresh_player_master_eval"):
			_pim_us.refresh_player_master_eval()
		return true
	return false

## 检查能否解锁技能
func can_unlock_faction_skill(faction_id: String, skill_id: String) -> Dictionary:
	if not faction_skill_states.has(faction_id):
		return {"ok": false, "reason": "faction_not_found"}
	return FactionSkillManager.can_unlock_skill(
		faction_skill_states[faction_id], faction_id, skill_id, get_faction_level(faction_id))

## 获取当前势力激活技能效果（用于战斗注入）
func get_active_faction_skill_effects() -> Dictionary:
	if active_faction.is_empty():
		return {}
	if not faction_skill_states.has(active_faction):
		return {}
	return FactionSkillManager.get_active_effects(faction_skill_states[active_faction], active_faction)

## 添加额外技能点（任务/事件奖励）
func add_faction_skill_bonus_points(faction_id: String, amount: int) -> void:
	if not faction_skill_states.has(faction_id):
		faction_skill_states[faction_id] = FactionSkillManager.create_default_state(faction_id)
	FactionSkillManager.add_bonus_points(faction_skill_states[faction_id], amount)

## 重置指定等级层的分支技能（返还点数）
func reset_faction_skill_branch(faction_id: String, tier: int, branch: String) -> Array:
	if not faction_skill_states.has(faction_id):
		return []
	return FactionSkillManager.reset_branch(faction_skill_states[faction_id], faction_id, tier, branch)

## 重置整个势力技能树（返还所有点数）
func reset_all_faction_skills(faction_id: String) -> int:
	if not faction_skill_states.has(faction_id):
		return 0
	return FactionSkillManager.reset_all(faction_skill_states[faction_id])

# ═══════════════════════════════════════════════════
#  势力事件管理
# ═══════════════════════════════════════════════════

## 初始化事件管理器
func _init_event_manager() -> void:
	# 幂等：reset→读档可能连续两次 load_state，先释放旧实例防止子节点堆积
	if _event_manager != null and is_instance_valid(_event_manager):
		_event_manager.queue_free()
	_event_manager = FactionEventManager.new()
	# 必须挂进场景树：FactionEventManager 内部用 get_node_or_null("/root/...")
	# 访问 FactionSystemManager/LevelProgressManager，不在树内会全部失败（势力事件永不触发）
	add_child(_event_manager)
	_event_manager.event_generated.connect(func(evt): faction_event_generated.emit(evt))

## SignalBus.battle_ended 信号处理（触发势力事件检查）
func _on_battle_ended(_player_won: bool) -> void:
	on_battle_ended_for_events()

## 每场战斗结束后调用（触发事件检查）
func on_battle_ended_for_events() -> void:
	if _event_manager != null:
		_event_manager.on_battle_ended()

## 获取活跃事件
func get_active_event() -> Dictionary:
	if _event_manager != null:
		return _event_manager.active_event.duplicate(true)
	return {}

## 解决事件
func resolve_faction_event(choice: String) -> Dictionary:
	if _event_manager != null:
		return _event_manager.resolve_event(choice)
	return {}

## 获取势力显示名称
func get_faction_display_name(faction_id: String) -> String:
	var cd: Dictionary = CompanyDefinitions.get_by_id(faction_id)
	return cd.get("name", faction_id)
