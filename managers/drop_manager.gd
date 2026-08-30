extends Node

## 掉落管理器 - 处理战斗奖励和掉落逻辑

signal drops_generated(drops: Array)
signal drops_claimed(drop_results: Array)
signal drop_completed(drop_id: String)
## v23.6(归仓)：战利品归仓暂存变化（存入/收取均会 emit；UI 据此刷基地气泡）
signal escrow_changed()

## 性能优化：预加载常用资源
const DefaultCards = preload("res://data/default_cards.gd")
const GameConstants = preload("res://resources/game_constants.gd")
const CardDropGrants = preload("res://scripts/card_drop_grants.gd")
const DropTables = preload("res://resources/drop_tables.gd")

var drop_tables: DropTables
var pending_drops: Array = []  # 待处理的掉落物
## v23.6(归仓)：战利品归仓暂存池。挂机期间的掉落不再即时入账钱包，而是聚合
## 存到这里，由基地（余烬要塞）房间头顶的收取气泡/一键全收/挂机结算"全部入账"
## 三条路径消费。条目按 (drop_type, item_id) 聚合，量级只随物品种类增长（有界）。
## 池容量天然受精神值约束（挂机每场胜 -10，归零即停机收工），不设硬上限。
var _escrow: Dictionary = {}  # key "type:item_id" -> {"item_id": String, "type": int, "count": int, "source": String}
# v6.6(剧情): 剧情奖励倍率（补剧情.txt L123 海伦宣告倒计时×3）
# 默认 1.0，由 city_map 在 city_emergency 信号触发时调用 set_multiplier 设置
# 仅作用于基础素材产出（_add_material），不影响卡牌掉落和能量蓝图
var _story_reward_multiplier: float = 1.0

func _ready():
	drop_tables = DropTables.new()

## v6.6(剧情): 设置剧情奖励倍率（补剧情.txt 第340天倒计时奖励×3）
## multiplier <= 0 时重置为 1.0（防御性）
func set_multiplier(multiplier: float) -> void:
	_story_reward_multiplier = maxf(0.0, multiplier)
	if _story_reward_multiplier == 0.0:
		_story_reward_multiplier = 1.0

## v6.6(剧情): 获取当前剧情奖励倍率
func get_multiplier() -> float:
	return _story_reward_multiplier

## v6.6(剧情): 重置剧情奖励倍率为 1.0（新周目/正常时段）
func reset_multiplier() -> void:
	_story_reward_multiplier = 1.0

## v6.6 修复: 新游戏重置。清空未领取掉落（避免新游戏继承上一局 pending_drops）。
## 注意：刻意不清 _story_reward_multiplier —— 倒计时×3 剧情倍率设计为跨周目持续生效。
func reset_to_defaults() -> void:
	pending_drops.clear()
	_escrow.clear()

## v7.3 修复 B3: 生成新掉落前，若仍有未领取的 pending_drops，先处理掉，避免覆盖丢失。
## 原 bug：generate_battle_drops 直接 pending_drops = drops 覆盖，上一场未领取的掉落永久丢失。
## v23.6(归仓)：残留掉落改送归仓暂存（原为直接自动入账）——玩家没点结算面板"继续"
## 就离场的战利品不再被静默吞进钱包，而是变成基地房间头顶的收取气泡，可见可追溯。
func _auto_claim_pending_if_any() -> void:
	if not pending_drops.is_empty():
		deposit_pending_to_escrow()


# ───────────────────── v23.6(归仓)：战利品暂存池 ─────────────────────

## 掉落类型 → 归仓类别（决定基地内挂哪个房间的气泡）。
## 退役类型（ENERGY_*/LAW_* 等 claim 时静默跳过的）返回空串：不入仓，deposit 时直接丢弃。
static func escrow_category_for_type(drop_type: int) -> String:
	match drop_type:
		DropTables.DropType.MATERIAL:
			return "material"
		DropTables.DropType.CARD_DATA, DropTables.DropType.BLUEPRINT_FRAGMENT, \
		DropTables.DropType.DROPPED_CARD, DropTables.DropType.CARD_REWARD:
			return "card"
		DropTables.DropType.LORE_PAGE:
			return "lore"
		DropTables.DropType.STAT_BOOST:
			return "stat_boost"
		DropTables.DropType.MOD_BLUEPRINT:
			return "mod_blueprint"
		_:
			return ""

## 把当前 pending_drops 聚合移入归仓池（挂机每场战后 / 残留掉落处理调用）。
## 返回移入的总件数。Yield 乘区（符文产出加成/剧情倍率）在收取时计算，与
## 即时 claim 口径一致，只是时点后移。
func deposit_pending_to_escrow() -> int:
	if pending_drops.is_empty():
		return 0
	var moved: int = 0
	for drop in pending_drops:
		if drop.drop == null:
			continue
		# 退役类型（能量卡/法则系等 claim 时静默跳过的）不入仓——占了气泡位也无事可做
		if escrow_category_for_type(int(drop.drop.type)).is_empty():
			continue
		var key := "%d:%s" % [int(drop.drop.type), String(drop.drop.item_id)]
		if not _escrow.has(key):
			_escrow[key] = {
				"item_id": String(drop.drop.item_id),
				"type": int(drop.drop.type),
				"count": 0,
				"source": String(drop.source),
			}
		_escrow[key]["count"] = int(_escrow[key]["count"]) + int(drop.count)
		moved += int(drop.count)
	pending_drops.clear()
	if moved > 0:
		escrow_changed.emit()
	return moved

## 当前归仓池里存货的类别列表（用于房间气泡布局）
func get_escrow_categories() -> Array[String]:
	var cats: Array[String] = []
	for key in _escrow:
		var cat := escrow_category_for_type(int(_escrow[key]["type"]))
		if not cat.is_empty() and not cats.has(cat):
			cats.append(cat)
	return cats

## 某类别暂存总件数
func get_escrow_category_count(cat: String) -> int:
	var total: int = 0
	for key in _escrow:
		if escrow_category_for_type(int(_escrow[key]["type"])) == cat:
			total += int(_escrow[key]["count"])
	return total

## 归仓池总件数（HUD"收取全部"按钮可见性 / 气泡计数用）
func get_escrow_total_count() -> int:
	var total: int = 0
	for key in _escrow:
		total += int(_escrow[key]["count"])
	return total

## 收取归仓：categories 为空数组 = 全部收取；否则只收指定类别（房间气泡按房收取）。
## 走与 claim_drops 相同的 _process_single_drop 管线（符文/剧情乘区、实例化掉落卡全一致）。
## 返回 [{name: String, count: int}] 领取明细（已解析显示名，供 toast/弹窗直接拼文案）。
func collect_escrow(categories: Array = []) -> Array:
	if _escrow.is_empty():
		return []
	var collect_all := categories.is_empty()
	var collected: Array = []
	var names: Dictionary = {}  # display_name -> count（同名合并）
	for key in _escrow.keys():
		var entry: Dictionary = _escrow[key]
		var cat := escrow_category_for_type(int(entry["type"]))
		if cat.is_empty():
			_escrow.erase(key)  # 退役类型残留：收取时顺手清掉
			continue
		if not collect_all and not categories.has(cat):
			continue
		var drop_entry = DropTables.DropEntry.new(
			String(entry["item_id"]), int(entry["type"]), 1.0,
			int(entry["count"]), int(entry["count"]))
		var result = DropTables.DropResult.new(drop_entry, int(entry["count"]), String(entry["source"]))
		_process_single_drop(result)
		var display: String = drop_tables.get_drop_display_name(drop_entry)
		names[display] = int(names.get(display, 0)) + int(entry["count"])
		_escrow.erase(key)
	if not names.is_empty():
		escrow_changed.emit()
	for display in names:
		collected.append({"name": String(display), "count": int(names[display])})
	collected.sort_custom(func(a, b): return int(a["count"]) > int(b["count"]))
	return collected

## 生成战斗掉落
func generate_battle_drops(era: int, level: int, player_won: bool, victory_stars: int = 0) -> Array:
	_auto_claim_pending_if_any()
	var drops = drop_tables.generate_drops(era, level, player_won, victory_stars)
	pending_drops = drops
	drops_generated.emit(drops)
	return drops

## 生成Boss战掉落
func generate_boss_drops(era: int, boss_id: String) -> Array:
	_auto_claim_pending_if_any()
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
		# v9.x（P2-7范围C）：能量卡掉落补偿（原降级研究点）随科研点退役——旧档 pending 静默跳过
		DropTables.DropType.ENERGY_CARD:
			pass
		DropTables.DropType.STAT_BOOST:
			_apply_stat_boost(drop.drop.item_id)
		# v9.x（P2-7范围A）：法则卡掉落路径退役——旧存档 pending_drops 中的
		# LAW_CARD/LAW_DATA/LAW_BLUEPRINT 类型在 claim 时无匹配臂，静默跳过（key 级忽略先例）
		# v9.x（P2-7范围C）：能量掉落补偿（原降级研究点）随科研点退役——旧档 pending 静默跳过
		DropTables.DropType.ENERGY_DATA, DropTables.DropType.ENERGY_BLUEPRINT:
			pass
		DropTables.DropType.MOD_BLUEPRINT:
			_add_mod_blueprint(drop.drop.item_id, drop.count)

## 添加基础素材
func _add_material(material_id: String, count: int) -> void:
	# v6.2: 符文之语资源产出加成 × v6.6(剧情): 剧情奖励倍率（倒计时×3）
	var yield_mult: float = (1.0 + _get_rune_resource_yield_bonus()) * _story_reward_multiplier
	var final_count: int = int(float(count) * yield_mult)
	match material_id:
		"nano_materials":
			BasicResourceManager.add_resource("nano_materials", final_count)
		"alloy":
			BasicResourceManager.add_resource("alloy", final_count)
		"crystal":
			BasicResourceManager.add_resource("crystal", final_count)
		"basic_nano":  # 兼容旧ID，映射到nano_materials
			BasicResourceManager.add_resource("nano_materials", final_count)
		"energy_block":
			BasicResourceManager.add_resource("energy_block", final_count)
		_:
			# 兜底：允许新资源ID（如各类改造许可函）直接入账
			BasicResourceManager.add_resource(material_id, final_count)

## v6.2: 获取符文之语资源产出加成比例
func _get_rune_resource_yield_bonus() -> float:
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	if pim == null or not pim.has_method("get_rune_bonus"):
		return 0.0
	var bonus: Dictionary = pim.get_rune_bonus()
	var specials: Array = bonus.get("specials", [])
	var total: float = 0.0
	for sp in specials:
		if sp is Dictionary and sp.get("special", "") == "on_resource_yield":
			total += float(sp.get("value", 0)) / 100.0
	return total

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
	var template = DefaultCards.get_card_by_id(card_id)
	if template == null:
		push_error("无法找到掉落卡牌: " + card_id)
		return
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	# v3 后所有战斗卡都是 COMBAT_UNIT，无需拦截 WEAPON 类型（该类型已废弃）
	# 原错误代码拦截了 COMBAT_UNIT 导致所有战斗卡掉落被拦，现已移除
	var n: int = maxi(1, int(count))
	for _i in range(n):
		# v7.0: 实例化掉落卡（每张独立 instance_id + 养成数据）
		var dropped_card: CardResource = null
		if ir != null and ir.has_method("create_instance"):
			dropped_card = ir.create_instance(card_id)
		else:
			dropped_card = template.clone()
			dropped_card.instance_id = ""
		if dropped_card == null:
			continue
		dropped_card.is_dropped_card = true
		# v20.12 等级统一：高星掉落卡的属性优势改发为起始战斗经验（原映射 enhance_level 0/1/2
		# 已随强化①退役）。star 1-3 → 0（白板），4-6 → 60 经验（约Lv2），7-9 → 150 经验（约Lv3）。
		var star: int = randi_range(1, 9)
		var bonus_exp: int = 0
		if star >= 7:
			bonus_exp = 150
		elif star >= 4:
			bonus_exp = 60
		if bonus_exp > 0 and ir != null and ir.has_method("add_experience") and not dropped_card.instance_id.is_empty():
			ir.add_experience(dropped_card.instance_id, bonus_exp)
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
				# [LOG-v5.1] print("[DropManager] 解锁情报: ", lore_id, " - ", _get_lore_display_name(lore_id))
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
	# v7.0: 实例化卡牌（独立 instance_id + 养成数据）
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	var card: CardResource = null
	if ir != null and ir.has_method("create_instance"):
		card = ir.create_instance(card_id)
	else:
		card = DefaultCards.get_card_by_id(card_id)
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
				# [LOG-v5.1] print("[DropManager] 应用属性提升: ", boost_id, " - ", _get_boost_display_name(boost_id))
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
	# v23.6(归仓)：暂存池持久化（聚合条目，量级有界）
	var escrow_data: Array = []
	for key in _escrow:
		var entry: Dictionary = _escrow[key]
		escrow_data.append({
			"item_id": String(entry["item_id"]),
			"type": int(entry["type"]),
			"count": int(entry["count"]),
			"source": String(entry["source"]),
		})
	state["escrow_drops"] = escrow_data
	# v6.6(剧情): 持久化剧情奖励倍率（倒计时×3 在新周目前持续生效）
	state["story_reward_multiplier"] = _story_reward_multiplier
	return state

## 加载掉落状态
func load_state(state: Dictionary) -> void:
	# v6.6(剧情): 恢复剧情奖励倍率（旧存档无此字段时兜底为 1.0）
	_story_reward_multiplier = float(state.get("story_reward_multiplier", 1.0))
	if _story_reward_multiplier <= 0.0:
		_story_reward_multiplier = 1.0
	# v23.6(归仓)：恢复暂存池（旧档无此 key → 空池，行为同旧版）
	_escrow.clear()
	for entry_data in state.get("escrow_drops", []):
		if not (entry_data is Dictionary):
			continue
		var item_id: String = str(entry_data.get("item_id", ""))
		if item_id.is_empty():
			continue
		var count: int = int(entry_data.get("count", 0))
		if count <= 0:
			continue
		var raw_type = entry_data.get("type", DropTables.DropType.MATERIAL)
		var drop_type: int = DropTables.DropType.MATERIAL
		if raw_type is int:
			drop_type = raw_type
		elif raw_type is String:
			drop_type = int(DropTables.DropType.get(raw_type, DropTables.DropType.MATERIAL))
		_escrow["%d:%s" % [drop_type, item_id]] = {
			"item_id": item_id,
			"type": drop_type,
			"count": count,
			"source": str(entry_data.get("source", "")),
		}
	if state.has("pending_drops"):
		pending_drops.clear()
		for drop_data in state["pending_drops"]:
			if not (drop_data is Dictionary):
				continue
			# 防御性访问：缺键或类型错误的条目跳过，避免中断整个加载链
			var item_id: String = str(drop_data.get("item_id", ""))
			if item_id.is_empty():
				continue
			var count: int = int(drop_data.get("count", 0))
			if count <= 0:
				continue
			# type 存为枚举值（int）；兼容字符串名
			var raw_type = drop_data.get("type", DropTables.DropType.MATERIAL)
			var drop_type: int = DropTables.DropType.MATERIAL
			if raw_type is int:
				drop_type = raw_type
			elif raw_type is String:
				drop_type = int(DropTables.DropType.get(raw_type, DropTables.DropType.MATERIAL))
			var entry = DropTables.DropEntry.new(
				item_id,
				drop_type,
				1.0,
				count,
				count
			)
			var source: String = str(drop_data.get("source", ""))
			var result = DropTables.DropResult.new(entry, count, source)
			pending_drops.append(result)

## v6.14: 改造蓝图掉落 → 写入 IntelItemBag（与 intel_discovery_manager 路径一致）
## item_id 为 blueprint_<mod_id> 形式，count 为数量（蓝图永久持有，多次获得无害）
## ⚠️ v7.x 审计澄清：本 claim 分支为预留扩展位，drop_tables.generate_drops 当前【不产出】
##    DropType.MOD_BLUEPRINT；改造蓝图实际走 intel_discovery_manager._roll_intel_item_drops
##    和 game_manager 相位师掉落两条独立路径（直接调 IntelItemBag.add_item）。保留分支以兼容
##    存档 load_state 或未来接入统一 DropManager 流。详见 v7.x 掉落链路审查报告。
func _add_mod_blueprint(item_id: String, count: int) -> void:
	var bag: Node = get_node_or_null("/root/IntelItemBag")
	if bag == null or not bag.has_method("add_item"):
		return
	var n: int = maxi(1, count)
	for _i in range(n):
		bag.add_item(item_id, 1)

