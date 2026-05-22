extends Node
## 势力系统管理器（委托层）：管理7个势力的声望、控制区域、商品库存等
##
## 本文件作为 Autoload 入口，保持对外公共 API 不变。
## 声望计算逻辑已拆分到 managers/faction/faction_reputation.gd
## 商店逻辑已拆分到 managers/faction/faction_shop.gd
##
## 所有外部调用者（faction_panel / store_panel / quest_manager / save_manager 等）
## 通过 /root/FactionSystemManager 访问，接口保持 100% 兼容。

const CompanyDefinitions = preload("res://data/company_definitions.gd")
const LevelInformation = preload("res://data/level_information.gd")
const PhaseInstruments = preload("res://data/phase_instruments.gd")
const BasicResources = preload("res://data/basic_resources.gd")

## 势力关系矩阵：faction_id -> {关系势力ID: 关系类型}
## 关系类型：allied(同盟), rival(竞争), enemy(敌对), neutral(中立)
const FACTION_RELATIONS: Dictionary = {
	"iron_wall_corp": {
		"nova_arms": "rival",
		"frontier_union": "enemy",
		"aether_dynamics": "neutral",
		"quantum_logistics": "neutral",
		"helix_recon": "neutral",
		"void_research": "neutral",
	},
	"nova_arms": {
		"iron_wall_corp": "rival",
		"aether_dynamics": "rival",
		"helix_recon": "neutral",
		"void_research": "neutral",
		"quantum_logistics": "neutral",
		"frontier_union": "neutral",
	},
	"aether_dynamics": {
		"nova_arms": "rival",
		"quantum_logistics": "allied",
		"void_research": "neutral",
		"helix_recon": "neutral",
		"iron_wall_corp": "neutral",
		"frontier_union": "neutral",
	},
	"quantum_logistics": {
		"aether_dynamics": "allied",
		"helix_recon": "neutral",
		"void_research": "neutral",
		"nova_arms": "neutral",
		"iron_wall_corp": "neutral",
		"frontier_union": "neutral",
	},
	"helix_recon": {
		"void_research": "rival",
		"frontier_union": "allied",
		"iron_wall_corp": "neutral",
		"nova_arms": "neutral",
		"aether_dynamics": "neutral",
		"quantum_logistics": "neutral",
	},
	"void_research": {
		"helix_recon": "rival",
		"frontier_union": "neutral",
		"iron_wall_corp": "neutral",
		"nova_arms": "neutral",
		"aether_dynamics": "neutral",
		"quantum_logistics": "neutral",
	},
	"frontier_union": {
		"helix_recon": "allied",
		"iron_wall_corp": "enemy",
		"nova_arms": "neutral",
		"aether_dynamics": "neutral",
		"quantum_logistics": "neutral",
		"void_research": "neutral",
	},
}

# ─────────────────────────────────────────────
#  显示名称映射（静态工具方法）
# ─────────────────────────────────────────────

## 关系类型中文名称映射
static func get_relationship_name(rel_type: String) -> String:
	match rel_type:
		"allied":  return "同盟"
		"rival":   return "竞争"
		"enemy":   return "敌对"
		"neutral": return "中立"
		_:         return "未知"

## 关系类型对应的颜色（用于UI显示）
static func get_relationship_color(rel_type: String) -> Color:
	match rel_type:
		"allied":  return Color(0.3, 0.8, 0.5, 1.0)
		"rival":   return Color(0.9, 0.7, 0.2, 1.0)
		"enemy":   return Color(0.9, 0.3, 0.3, 1.0)
		"neutral": return Color(0.6, 0.6, 0.7, 1.0)
		_:         return Color(0.7, 0.7, 0.7)

## 获取两个势力之间的关系类型
static func get_relationship_between(faction_a: String, faction_b: String) -> String:
	if FACTION_RELATIONS.has(faction_a):
		var relations: Dictionary = FACTION_RELATIONS[faction_a]
		if relations.has(faction_b):
			return relations[faction_b]
	return "neutral"

# ─────────────────────────────────────────────
#  信号与运行时状态
# ─────────────────────────────────────────────

signal faction_reputation_changed(faction_id: String, delta: int, new_value: int)
signal faction_level_up(faction_id: String, new_level: int)
signal faction_store_updated(faction_id: String)

## 全局声望数据：faction_id -> 声望值（0-10000）
var faction_reputation: Dictionary = {}

## 势力等级：faction_id -> 等级（1-10）
var faction_level: Dictionary = {}

## 势力商店库存：faction_id -> [card_ids...]
var faction_store_inventory: Dictionary = {}
var unlocked_faction_instruments: Dictionary = {}

## 关卡信息实例
var level_info: LevelInformation

## 势力定义：faction_id -> { name, desc, color }
var _faction_definitions: Dictionary = {}

## 缓存所有势力ID列表
var _all_faction_ids: Array = []

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	level_info = LevelInformation.new()
	_init_faction_data()

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
		unlocked_faction_instruments[faction_id] = []
		_faction_definitions[faction_id] = faction_data
		_all_faction_ids.append(faction_id)

# ─────────────────────────────────────────────
#  声望操作（委托给 FactionReputation）
# ─────────────────────────────────────────────

## 增加或减少某个势力的声望
func add_faction_reputation(faction_id: String, delta: int) -> int:
	if not faction_reputation.has(faction_id):
		return 0

	var old_rep: int = faction_reputation[faction_id]
	var result: Dictionary = FactionReputation.apply_delta(old_rep, delta)
	faction_reputation[faction_id] = result["new_rep"]

	if result["leveled_up"]:
		faction_level[faction_id] = result["new_level"]
		_update_faction_store_for_level_up(faction_id)
		emit_signal("faction_level_up", faction_id, result["new_level"])

	emit_signal("faction_reputation_changed", faction_id, delta, result["new_rep"])
	return result["new_rep"]

## 主角攻克关卡后的势力反应计算
func on_level_conquered(level_conquered: int) -> Dictionary:
	var result: Dictionary = {}

	var conquered_faction: String = ""
	if level_info:
		conquered_faction = level_info.get_level_faction(level_conquered)

	if conquered_faction.is_empty():
		return result

	# 计算所有势力反应
	var reactions: Dictionary = FactionReputation.calculate_conquest_reaction(
		conquered_faction, FACTION_RELATIONS, _all_faction_ids
	)

	for faction_id in reactions:
		var delta: int = reactions[faction_id]
		if faction_reputation.has(faction_id):
			result[faction_id] = add_faction_reputation(faction_id, delta)
			if delta != 0:
				var rel_type: String = get_relationship_between(conquered_faction, faction_id)
				print("[FactionSystem] 势力 %s（与 %s 为 %s）声望 %+d" % [faction_id, conquered_faction, rel_type, delta])

	return result

func get_faction_reputation(faction_id: String) -> int:
	return faction_reputation.get(faction_id, 0)

func get_faction_level(faction_id: String) -> int:
	return faction_level.get(faction_id, 1)

func _get_level_from_reputation(rep: int) -> int:
	return FactionReputation.get_level_from_reputation(rep)

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

## 创建商店物品（保留兼容，内部委托）
func _create_store_item(id: String, type: FactionShop.StoreItemType, item_name: String, cost: int, level: int, stock: int = -1) -> FactionShop.StoreItem:
	return FactionShop.create_store_item(id, type, item_name, cost, level, stock)

## 检查是否可以购买
func can_purchase_item(faction_id: String, item: FactionShop.StoreItem) -> Dictionary:
	return FactionShop.can_purchase_item(get_faction_reputation(faction_id), get_faction_level(faction_id), item)

## 购买物品
func purchase_item(faction_id: String, item: FactionShop.StoreItem) -> Dictionary:
	var can: Dictionary = can_purchase_item(faction_id, item)
	if not can.get("ok", false):
		return can

	# 扣除声望
	add_faction_reputation(faction_id, -item.reputation_cost)

	# 发放物品
	var delivered: bool = FactionShop.deliver_item(item)
	if not delivered:
		# 回退声望
		add_faction_reputation(faction_id, item.reputation_cost)
		return {"ok": false, "reason": "delivery_failed"}

	# 更新库存（如果有库存限制）
	if item.stock > 0:
		item.stock -= 1

	return {"ok": true, "item_id": item.item_id}

## 给予商店物品（向后兼容）
func _give_store_item(item: FactionShop.StoreItem) -> void:
	FactionShop.deliver_item(item)

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
		"controlled_levels": level_info.get_levels_for_faction(faction_id),
	}

## 获取所有势力的信息
func get_all_factions_info() -> Array:
	var result = []
	for faction_data in CompanyDefinitions.get_all():
		var faction_id = faction_data.get("id", "")
		if not faction_id.is_empty():
			result.append(get_faction_info(faction_id))
	return result

## 获取势力的相位仪列表
func get_faction_phase_instruments(faction_id: String) -> Array:
	var out: Array = []
	for d in PhaseInstruments.get_all():
		if not (d is Dictionary):
			continue
		if bool(d.get("is_generic", false)):
			continue
		if String(d.get("faction_id", "")) == faction_id:
			out.append(d)
	return out

func is_instrument_unlocked_for_faction(faction_id: String, instrument_id: String) -> bool:
	var arr: Array = unlocked_faction_instruments.get(faction_id, [])
	return arr.has(instrument_id)

func unlock_instrument_for_faction(faction_id: String, instrument_id: String) -> bool:
	if faction_id.is_empty() or instrument_id.is_empty():
		return false
	var arr: Array = unlocked_faction_instruments.get(faction_id, [])
	if not arr.has(instrument_id):
		arr.append(instrument_id)
	unlocked_faction_instruments[faction_id] = arr
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	if pim != null and pim.has_method("unlock_instrument"):
		pim.unlock_instrument(instrument_id)
	return true

# ─────────────────────────────────────────────
#  相位仪购买
# ─────────────────────────────────────────────

func can_buy_instrument(faction_id: String, instrument_cfg: Dictionary) -> Dictionary:
	if instrument_cfg.is_empty():
		return {"ok": false, "reason": "invalid"}
	var iid: String = String(instrument_cfg.get("id", ""))
	if iid.is_empty():
		return {"ok": false, "reason": "invalid"}
	if String(instrument_cfg.get("faction_id", "")) != faction_id:
		return {"ok": false, "reason": "faction_mismatch"}
	if is_instrument_unlocked_for_faction(faction_id, iid):
		return {"ok": false, "reason": "owned"}
	var rep_need: int = int(instrument_cfg.get("required_rep", 0))
	var rep_now: int = get_faction_reputation(faction_id)
	if rep_now < rep_need and not has_global_access():
		return {"ok": false, "reason": "rep", "required_rep": rep_need, "current_rep": rep_now}
	var price_eb: int = int(instrument_cfg.get("price_energy_block", 0))
	var brm: Node = get_node_or_null("/root/BasicResourceManager")
	var eb_now: int = brm.get_total(BasicResources.ID_ENERGY_BLOCK) if brm and brm.has_method("get_total") else 0
	if eb_now < price_eb:
		return {"ok": false, "reason": "energy_block", "required_energy_block": price_eb, "current_energy_block": eb_now}
	return {"ok": true}

func buy_instrument(faction_id: String, instrument_id: String) -> Dictionary:
	var cfg: Dictionary = PhaseInstruments.get_by_id(instrument_id)
	if cfg.is_empty():
		return {"ok": false, "reason": "invalid"}
	var can: Dictionary = can_buy_instrument(faction_id, cfg)
	if not bool(can.get("ok", false)):
		return can
	var price_eb: int = int(cfg.get("price_energy_block", 0))
	var brm: Node = get_node_or_null("/root/BasicResourceManager")
	if brm == null or not brm.has_method("add_resource"):
		return {"ok": false, "reason": "no_resource_manager"}
	brm.add_resource(BasicResources.ID_ENERGY_BLOCK, -price_eb)
	unlock_instrument_for_faction(faction_id, instrument_id)
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	if pim != null and pim.has_method("equip_instrument"):
		pim.equip_instrument(instrument_id)
	return {"ok": true, "price_energy_block": price_eb}

# ─────────────────────────────────────────────
#  相位仪奖励
# ─────────────────────────────────────────────

func grant_instrument_quest_reward(faction_id: String, instrument_id: String) -> bool:
	var cfg: Dictionary = PhaseInstruments.get_by_id(instrument_id)
	if cfg.is_empty():
		return false
	if String(cfg.get("faction_id", "")) != faction_id:
		return false
	return unlock_instrument_for_faction(faction_id, instrument_id)

# ─────────────────────────────────────────────
#  存档功能
# ─────────────────────────────────────────────

func save_state() -> Dictionary:
	return {
		"faction_reputation": faction_reputation.duplicate(true),
		"faction_level": faction_level.duplicate(true),
		"faction_store_inventory": faction_store_inventory.duplicate(true),
		"unlocked_faction_instruments": unlocked_faction_instruments.duplicate(true),
	}

func load_state(data: Dictionary) -> void:
	# 新游戏：SaveManager 传入空字典，必须整表重置（否则仍保留上一局的声望）
	if data.is_empty():
		_init_faction_data()
		return
	if data.has("faction_reputation") and data["faction_reputation"] is Dictionary:
		faction_reputation = (data["faction_reputation"] as Dictionary).duplicate(true)

	if data.has("faction_level") and data["faction_level"] is Dictionary:
		faction_level = (data["faction_level"] as Dictionary).duplicate(true)

	if data.has("faction_store_inventory") and data["faction_store_inventory"] is Dictionary:
		faction_store_inventory = (data["faction_store_inventory"] as Dictionary).duplicate(true)
	if data.has("unlocked_faction_instruments") and data["unlocked_faction_instruments"] is Dictionary:
		unlocked_faction_instruments = (data["unlocked_faction_instruments"] as Dictionary).duplicate(true)
	_ensure_faction_keys_after_load()

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
		if not faction_level.has(fid):
			faction_level[fid] = FactionReputation.get_level_from_reputation(int(faction_reputation[fid]))
		else:
			faction_level[fid] = int(faction_level[fid])
		if not faction_store_inventory.has(fid):
			faction_store_inventory[fid] = FactionShop.get_default_store_inventory(fid)
		if not unlocked_faction_instruments.has(fid):
			unlocked_faction_instruments[fid] = []

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
