extends Node
## 卡牌收集管理器：管理卡牌图鉴和收集进度

const DefaultCards = preload("res://data/default_cards.gd")

## 稀有度卡牌映射
const RARITY_CARD_MAP = {
	"普通": [
		"platform_ww1_light", "platform_ww1_medium",
		"platform_ww2_light", "platform_ww2_medium",
		"platform_cold_light", "platform_cold_medium",
		"platform_modern_light",
		"energy_start_1", "energy_start_2", "energy_start_3",
	],
	"稀有": [
		"platform_ww1_fort", "platform_ww2_heavy",
		"platform_cold_ifv",
		"platform_future_light",
		"energy_start_4", "energy_start_5",
	],
	"史诗": [
		"platform_modern_medium", "platform_modern_spg",
		"platform_future_medium", "platform_future_heavy",
		"energy_start_6", "energy_start_7", "law_passive_test"
	],
	"传说": [
		"omega_platform", "law_active_test"
	],
	"神话": [
		# 神话卡牌暂未实现
	]
}

## 卡牌获得状态
enum CardStatus {
	LOCKED,       # 未获得
	OWNED,        # 已获得
	MAX_LEVEL     # 已满级
}

var _collection_data: Dictionary = {}

signal card_obtained(card_id: String)
signal card_max_level(card_id: String)
signal collection_milestone_reached(milestone: Dictionary)

## 是否已完成延迟初始化
var _deferred_initialized: bool = false

func _ready() -> void:
	# 基础初始化已在变量声明处完成
	# 如有未来需要延迟加载的逻辑，放在 _deferred_init() 中
	call_deferred("_deferred_init")

## 延迟初始化：在主循环空闲时执行额外初始化
func _deferred_init() -> void:
	if _deferred_initialized:
		return
	_deferred_initialized = true
	# 当前无额外初始化逻辑，保留此方法供后续扩展

## 更新卡牌收集状态
func update_card_status(card_id: String) -> void:
	var card = DefaultCards.get_card_by_id(card_id) if DefaultCards else null
	if card == null:
		return

	if not _collection_data.has(card_id):
		_collection_data[card_id] = {
			"status": CardStatus.LOCKED,
			"obtain_time": 0,
			"level": 0,
			"breakthrough": 0
		}

	var was_new = _collection_data[card_id]["status"] == CardStatus.LOCKED

	# 更新状态
	var card_data = _collection_data[card_id]
	var prog = {}

	if BlueprintManager and BlueprintManager.has_method("get_card_xp_progress"):
		prog = BlueprintManager.get_card_xp_progress(card_id)
		card_data["level"] = prog.get("level", 1)

	if BlueprintManager and BlueprintManager.has_method("get_card_breakthroughs"):
		card_data["breakthrough"] = BlueprintManager.get_card_breakthroughs(card_id)

	# 更新状态
	if card_data["level"] >= 9:
		if card_data["status"] != CardStatus.MAX_LEVEL:
			card_data["status"] = CardStatus.MAX_LEVEL
			card_max_level.emit(card_id)
	else:
		card_data["status"] = CardStatus.OWNED

	if was_new:
		card_data["obtain_time"] = Time.get_unix_time_from_system()
		card_obtained.emit(card_id)

	_check_collection_milestones()

## 获取收集完成度
func get_collection_progress() -> Dictionary:
	var total_cards = 0
	if DefaultCards:
		total_cards = DefaultCards.get_all_blueprint_ids().size()

	var owned_cards = 0
	var max_level_cards = 0

	for card_id in _collection_data:
		var status = _collection_data[card_id]["status"]
		if status >= CardStatus.OWNED:
			owned_cards += 1
		if status == CardStatus.MAX_LEVEL:
			max_level_cards += 1

	return {
		"total": total_cards,
		"owned": owned_cards,
		"max_level": max_level_cards,
		"completion_rate": float(owned_cards) / total_cards if total_cards > 0 else 0.0,
		"perfection_rate": float(max_level_cards) / total_cards if total_cards > 0 else 0.0
	}

## 获取稀有度收集统计
func get_rarity_collection_stats() -> Dictionary:
	var stats = {}
	var rarities = ["普通", "稀有", "史诗", "传说", "神话"]

	for rarity in rarities:
		var card_ids = RARITY_CARD_MAP.get(rarity, [])
		var total = card_ids.size()

		var owned = 0
		for card_id in card_ids:
			if _collection_data.has(card_id):
				if _collection_data[card_id]["status"] >= CardStatus.OWNED:
					owned += 1

		stats[rarity] = {
			"total": total,
			"owned": owned,
			"rate": float(owned) / total if total > 0 else 0.0
		}

	return stats

## 获取卡牌状态
func get_card_status(card_id: String) -> CardStatus:
	if _collection_data.has(card_id):
		return _collection_data[card_id]["status"]
	return CardStatus.LOCKED

## 检查收集里程碑
func _check_collection_milestones() -> void:
	var progress = get_collection_progress()
	var completion_rate = progress.get("completion_rate", 0.0)

	var milestones = [
		{"rate": 0.1, "name": "入门收藏家", "reward": {"nanomaterial": 100}},
		{"rate": 0.25, "name": "进阶收藏家", "reward": {"nanomaterial": 300, "rare_fragment": 2}},
		{"rate": 0.5, "name": "资深收藏家", "reward": {"nanomaterial": 1000, "epic_fragment": 2}},
		{"rate": 0.75, "name": "专家收藏家", "reward": {"nanomaterial": 3000, "legendary_fragment": 1}},
		{"rate": 1.0, "name": "完美收藏家", "reward": {"nanomaterial": 10000, "legendary_fragment": 5}}
	]

	for milestone in milestones:
		if completion_rate >= milestone["rate"]:
			collection_milestone_reached.emit(milestone)


## 保存状态（给SaveManager用）
func save_state() -> Dictionary:
	return _collection_data.duplicate(true)

## 加载状态（给SaveManager用）
func load_state(data: Dictionary) -> void:
	if not data.is_empty():
		_collection_data = data.duplicate(true)
