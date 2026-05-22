class_name TowerEvents
## 爬塔层间事件定义

const EVENTS := {
	"event_merchant": {
		"id": "event_merchant",
		"name": "旅行商人",
		"description": "一个神秘的商人出现在你面前，愿意以金币交换稀有物资。",
		"icon": "merchant",
		"choices": [
			{
				"text": "花费 30 金币购买随机卡牌",
				"cost": {"gold": 30},
				"effect": {"type": "add_random_card"},
			},
			{
				"text": "花费 50 金币购买随机遗物",
				"cost": {"gold": 50},
				"effect": {"type": "add_random_relic", "max_rarity": "uncommon"},
			},
			{
				"text": "花费 40 金币恢复 30 点生命",
				"cost": {"gold": 40},
				"effect": {"type": "heal", "amount": 30},
			},
			{
				"text": "离开",
				"effect": {"type": "none"},
			},
		],
	},
	"event_altar": {
		"id": "event_altar",
		"name": "远古祭坛",
		"description": "一座散发微光的祭坛，据说献祭可以换取力量。",
		"icon": "altar",
		"choices": [
			{
				"text": "献祭一张卡牌，获得随机遗物",
				"effect": {"type": "sacrifice_card_for_relic"},
			},
			{
				"text": "献祭 20 点生命，获得传说遗物",
				"cost": {"hp": 20},
				"effect": {"type": "add_random_relic", "max_rarity": "mythic"},
			},
			{
				"text": "祈祷获得 15 点生命回复",
				"effect": {"type": "heal", "amount": 15},
			},
			{
				"text": "离开",
				"effect": {"type": "none"},
			},
		],
	},
	"event_oracle": {
		"id": "event_oracle",
		"name": "时间神谕",
		"description": "时间裂隙中出现一面镜子，映射着未来的景象。",
		"icon": "oracle",
		"choices": [
			{
				"text": "窥视未来（查看下一层敌人类型）",
				"effect": {"type": "reveal_next_floor"},
			},
			{
				"text": "获取 20 金币",
				"effect": {"type": "gold", "amount": 20},
			},
			{
				"text": "离开",
				"effect": {"type": "none"},
			},
		],
	},
	"event_blacksmith": {
		"id": "event_blacksmith",
		"name": "流浪铁匠",
		"description": "一位老铁匠在废墟中生火锻造，愿意免费为你升级装备。",
		"icon": "blacksmith",
		"choices": [
			{
				"text": "免费升级一张卡牌（属性 +20%）",
				"effect": {"type": "upgrade_random_card", "multiplier": 1.2},
			},
			{
				"text": "移除一张卡牌，获得 15 金币",
				"effect": {"type": "remove_card_for_gold", "gold_amount": 15},
			},
			{
				"text": "离开",
				"effect": {"type": "none"},
			},
		],
	},
	"event_calamity": {
		"id": "event_calamity",
		"name": "相位灾厄",
		"description": "空间不稳定！相位风暴正在逼近，你必须做出选择。",
		"icon": "calamity",
		"choices": [
			{
				"text": "承受风暴（失去 25 点生命），获得精良遗物",
				"cost": {"hp": 25},
				"effect": {"type": "add_random_relic", "max_rarity": "rare"},
			},
			{
				"text": "加固基地（获得 15 点最大生命，失去 10 点当前生命）",
				"cost": {"hp": 10},
				"effect": {"type": "max_hp_up", "amount": 15},
			},
			{
				"text": "紧急规避（无事发生，但无奖励）",
				"effect": {"type": "none"},
			},
		],
	},
	"event_treasure": {
		"id": "event_treasure",
		"name": "隐藏宝箱",
		"description": "你在废墟中发现了一个被遗忘的宝箱！",
		"icon": "treasure",
		"choices": [
			{
				"text": "打开宝箱",
				"effect": {"type": "random_reward"},
			},
		],
	},
	"event_training": {
		"id": "event_training",
		"name": "训练场",
		"description": "一个废弃的军事训练场，设施仍然可以使用。",
		"icon": "training",
		"choices": [
			{
				"text": "力量训练：击杀分数 +10",
				"effect": {"type": "stat_boost", "stat": "kill_score_bonus", "value": 10},
			},
			{
				"text": "体能训练：恢复 20 点生命",
				"effect": {"type": "heal", "amount": 20},
			},
			{
				"text": "能量训练：每层 +10 能量",
				"effect": {"type": "stat_boost", "stat": "energy_start_bonus", "value": 10},
			},
			{
				"text": "离开",
				"effect": {"type": "none"},
			},
		],
	},
	"event_portal": {
		"id": "event_portal",
		"name": "时空传送门",
		"description": "一扇闪烁的传送门出现了。穿过它可以跳过下一层，但敌人会更强。",
		"icon": "portal",
		"choices": [
			{
				"text": "穿过传送门（跳过一层，后续敌人 +15% 强度）",
				"effect": {"type": "skip_floor", "enemy_boost": 0.15},
			},
			{
				"text": "破坏传送门，获得 25 金币",
				"effect": {"type": "gold", "amount": 25},
			},
			{
				"text": "离开",
				"effect": {"type": "none"},
			},
		],
	},
}

# 每个事件的最大出现层数（防止后期出现弱事件）
const EVENT_FLOOR_LIMITS := {
	"event_treasure": 15,
	"event_training": 20,
}


## 根据 ID 获取事件
static func get_event(event_id: String) -> Dictionary:
	if EVENTS.has(event_id):
		return EVENTS[event_id].duplicate(true)
	return {}


## 获取指定层数的随机事件（排除低层不合适的事件）
static func get_random_event(floor_num: int) -> Dictionary:
	var available: Array = []
	for event_id in EVENTS:
		var max_floor: int = EVENT_FLOOR_LIMITS.get(event_id, 999)
		if floor_num <= max_floor:
			available.append(event_id)
	if available.is_empty():
		return EVENTS.values()[randi() % EVENTS.size()].duplicate(true) if not EVENTS.is_empty() else {}
	return EVENTS[available[randi() % available.size()]].duplicate(true)


## 获取所有事件 ID
static func get_all_event_ids() -> Array:
	return EVENTS.keys()
