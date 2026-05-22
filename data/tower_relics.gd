class_name TowerRelics
## 爬塔遗物定义：被动增益效果

const RELICS := {
	"relic_energy_crystal": {
		"id": "relic_energy_crystal",
		"name": "能量水晶",
		"description": "每层战斗开始时额外获得 20 能量",
		"rarity": "common",
		"icon_color": Color(0.3, 0.8, 1.0),
		"effect": {"energy_start_bonus": 20},
	},
	"relic_iron_shield": {
		"id": "relic_iron_shield",
		"name": "铁壁护盾",
		"description": "基地最大生命值 +30",
		"rarity": "common",
		"icon_color": Color(0.7, 0.7, 0.8),
		"effect": {"max_hp_bonus": 30},
	},
	"relic_victory_banner": {
		"id": "relic_victory_banner",
		"name": "胜利旗帜",
		"description": "每层通关额外获得 50 分",
		"rarity": "common",
		"icon_color": Color(1.0, 0.85, 0.2),
		"effect": {"floor_clear_score_bonus": 50},
	},
	"relic_medicine_pouch": {
		"id": "relic_medicine_pouch",
		"name": "医疗包",
		"description": "休息层回复量 +15",
		"rarity": "common",
		"icon_color": Color(0.3, 1.0, 0.5),
		"effect": {"rest_heal_bonus": 15},
	},
	"relic_war_drums": {
		"id": "relic_war_drums",
		"name": "战鼓",
		"description": "单次击杀额外 +15 分",
		"rarity": "uncommon",
		"icon_color": Color(1.0, 0.5, 0.3),
		"effect": {"kill_score_bonus": 15},
	},
	"relic_tactical_map": {
		"id": "relic_tactical_map",
		"name": "战术地图",
		"description": "每层开始时显示敌人类型（功能预留）",
		"rarity": "uncommon",
		"icon_color": Color(0.6, 0.9, 0.6),
		"effect": {"reveal_enemies": true},
	},
	"relic_fortification": {
		"id": "relic_fortification",
		"name": "加固工事",
		"description": "基地最大生命值 +50",
		"rarity": "uncommon",
		"icon_color": Color(0.5, 0.5, 0.9),
		"effect": {"max_hp_bonus": 50},
	},
	"relic_spare_parts": {
		"id": "relic_spare_parts",
		"name": "备用零件",
		"description": "商店物品价格 -20%",
		"rarity": "uncommon",
		"icon_color": Color(0.8, 0.7, 0.3),
		"effect": {"shop_discount": 0.2},
	},
	"relic_phase_accelerator": {
		"id": "relic_phase_accelerator",
		"name": "相位加速器",
		"description": "单位部署时间缩短 20%",
		"rarity": "rare",
		"icon_color": Color(0.2, 0.6, 1.0),
		"effect": {"deploy_time_multiplier": 0.8},
	},
	"relic_energy_capacitor": {
		"id": "relic_energy_capacitor",
		"name": "能量电容",
		"description": "每层战斗开始时额外获得 40 能量",
		"rarity": "rare",
		"icon_color": Color(0.0, 0.9, 0.9),
		"effect": {"energy_start_bonus": 40},
	},
	"relic_berserker_mark": {
		"id": "relic_berserker_mark",
		"name": "狂战印记",
		"description": "击杀分数翻倍，但受伤增加 20%",
		"rarity": "rare",
		"icon_color": Color(0.9, 0.2, 0.2),
		"effect": {"kill_score_multiplier": 2.0, "damage_taken_multiplier": 1.2},
	},
	"relic_void_crystal": {
		"id": "relic_void_crystal",
		"name": "虚空结晶",
		"description": "所有法则冷却时间 -1",
		"rarity": "mythic",
		"icon_color": Color(0.7, 0.3, 1.0),
		"effect": {"law_cooldown_reduction": 1},
	},
	"relic_time_loop": {
		"id": "relic_time_loop",
		"name": "时间回环",
		"description": "每层第一次基地受伤减免 50%",
		"rarity": "mythic",
		"icon_color": Color(1.0, 0.9, 0.5),
		"effect": {"first_hit_damage_reduction": 0.5},
	},
}

const RARITY_ORDER := ["common", "uncommon", "rare", "mythic"]
const RARITY_WEIGHTS := {"common": 50, "uncommon": 30, "rare": 15, "mythic": 5}


## 根据 ID 获取遗物
static func get_relic(relic_id: String) -> Dictionary:
	if RELICS.has(relic_id):
		return RELICS[relic_id].duplicate(true)
	return {}


## 根据稀有度获取所有遗物
static func get_relics_by_rarity(rarity: String) -> Array:
	var result: Array = []
	for relic_id in RELICS:
		if RELICS[relic_id].get("rarity", "") == rarity:
			result.append(RELICS[relic_id].duplicate(true))
	return result


## 随机获取一个遗物（排除已拥有的）
static func get_random_relic(exclude_ids: Array, max_rarity: String = "mythic") -> Dictionary:
	var max_rarity_idx: int = RARITY_ORDER.find(max_rarity)
	if max_rarity_idx < 0:
		max_rarity_idx = RARITY_ORDER.size() - 1

	# 加权随机选择稀有度
	var available_rarities: Array = []
	var weights: Array = []
	for i in range(max_rarity_idx + 1):
		var rarity_name: String = RARITY_ORDER[i]
		var relics_in_rarity := get_relics_by_rarity(rarity_name)
		var non_excluded: Array = []
		for r in relics_in_rarity:
			if not exclude_ids.has(r["id"]):
				non_excluded.append(r)
		if not non_excluded.is_empty():
			available_rarities.append(non_excluded)
			weights.append(RARITY_WEIGHTS.get(rarity_name, 10))

	if available_rarities.is_empty():
		return {}

	# 加权选择稀有度池
	var total_weight: float = 0.0
	for w in weights:
		total_weight += float(w)
	var roll: float = randf() * total_weight
	var cumulative: float = 0.0
	var selected_pool: Array = available_rarities[0]
	for i in range(weights.size()):
		cumulative += float(weights[i])
		if roll <= cumulative:
			selected_pool = available_rarities[i]
			break

	# 从选中池随机选一个
	return selected_pool[randi() % selected_pool.size()] as Dictionary


## 获取所有遗物 ID
static func get_all_relic_ids() -> Array:
	return RELICS.keys()


## 获取稀有度颜色
static func get_rarity_color(rarity: String) -> Color:
	match rarity:
		"mythic": return Color(0.75, 0.35, 1.0)  # 神话塔遗物专用色
		_: return GameConstants.get_rarity_color(rarity)


## 获取稀有度显示名称
static func get_rarity_display_name(rarity: String) -> String:
	match rarity:
		"common": return "普通"
		"uncommon": return "稀有"
		"rare": return "精良"
		"mythic": return "传说"
		_: return "普通"
