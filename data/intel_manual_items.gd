extends RefCounted
class_name IntelManualItems
## v6.0: 情报道具系统
##
## 情报道具是战斗掉落和商店可购买的一次性消耗品。
## 每种道具对应一个操作：强化/升星/改装/进化。
## 使用后消耗一个对应道具，不必再额外花费其他资源。
##
## 道具类型：
##   - enhance_manual:  强化手册（强化一次）
##   - star_upgrade_manual: 升星指南（升星一次）
##   - mod_manual_a: 改装指南·基础（A槽改装一次）
##   - mod_manual_b: 改装指南·进阶（B槽改装一次）
##   - mod_manual_c: 改装指南·高级（C槽改装一次）
##   - evolve_blueprint: 进化图纸（进化一次）

## ── 道具类型枚举 ──────────────────────────────────────────

const TYPE_ENHANCE := "enhance_manual"           ## 强化手册
const TYPE_STAR_UPGRADE := "star_upgrade_manual"   ## 升星指南
const TYPE_MOD_A := "mod_manual_a"                 ## 改装指南·基础
const TYPE_MOD_B := "mod_manual_b"                 ## 改装指南·进阶
const TYPE_MOD_C := "mod_manual_c"                 ## 改装指南·高级
const TYPE_EVOLVE := "evolve_blueprint"             ## 进化图纸

## 所有道具类型
const ALL_TYPES: Array[String] = [
	TYPE_ENHANCE, TYPE_STAR_UPGRADE,
	TYPE_MOD_A, TYPE_MOD_B, TYPE_MOD_C,
	TYPE_EVOLVE,
]

## ── 道具定义 ──────────────────────────────────────────────

const DEFINITIONS: Dictionary = {
	TYPE_ENHANCE: {
		"id": TYPE_ENHANCE,
		"name": "强化手册",
		"desc": "允许进行一次强化操作",
		"icon": "res://assets/icons/intel_enhance.png",
		"rarity": "common",
		"drop_weight_normal": 40,   ## 普通敌人掉落权重
		"drop_weight_elite": 25,
		"drop_weight_boss": 15,
	},
	TYPE_STAR_UPGRADE: {
		"id": TYPE_STAR_UPGRADE,
		"name": "升星指南",
		"desc": "允许进行一次升星操作",
		"icon": "res://assets/icons/intel_star.png",
		"rarity": "uncommon",
		"drop_weight_normal": 20,
		"drop_weight_elite": 25,
		"drop_weight_boss": 20,
	},
	TYPE_MOD_A: {
		"id": TYPE_MOD_A,
		"name": "改装指南·基础",
		"desc": "允许进行一次A槽改装",
		"icon": "res://assets/icons/intel_mod_a.png",
		"rarity": "uncommon",
		"drop_weight_normal": 15,
		"drop_weight_elite": 20,
		"drop_weight_boss": 18,
	},
	TYPE_MOD_B: {
		"id": TYPE_MOD_B,
		"name": "改装指南·进阶",
		"desc": "允许进行一次B槽改装",
		"icon": "res://assets/icons/intel_mod_b.png",
		"rarity": "rare",
		"drop_weight_normal": 5,
		"drop_weight_elite": 12,
		"drop_weight_boss": 15,
	},
	TYPE_MOD_C: {
		"id": TYPE_MOD_C,
		"name": "改装指南·高级",
		"desc": "允许进行一次C槽改装",
		"icon": "res://assets/icons/intel_mod_c.png",
		"rarity": "rare",
		"drop_weight_normal": 2,
		"drop_weight_elite": 8,
		"drop_weight_boss": 12,
	},
	TYPE_EVOLVE: {
		"id": TYPE_EVOLVE,
		"name": "进化图纸",
		"desc": "允许进行一次进化操作",
		"icon": "res://assets/icons/intel_evolve.png",
		"rarity": "epic",
		"drop_weight_normal": 0,    ## 普通不掉落
		"drop_weight_elite": 3,
		"drop_weight_boss": 20,
	},
}

## ── 稀有度颜色 ──────────────────────────────────────────────

const RARITY_COLORS: Dictionary = {
	"common": Color(0.7, 0.8, 0.7, 1.0),
	"uncommon": Color(0.3, 0.75, 0.3, 1.0),
	"rare": Color(0.3, 0.5, 1.0, 1.0),
	"epic": Color(0.7, 0.3, 0.9, 1.0),
}

const RARITY_NAMES: Dictionary = {
	"common": "普通",
	"uncommon": "精良",
	"rare": "稀有",
	"epic": "史诗",
}

## ── 商店价格（纳米材料） ──────────────────────────────────

const SHOP_PRICES: Dictionary = {
	TYPE_ENHANCE: 150,
	TYPE_STAR_UPGRADE: 300,
	TYPE_MOD_A: 250,
	TYPE_MOD_B: 500,
	TYPE_MOD_C: 800,
	TYPE_EVOLVE: 1200,
}

## ── 静态方法 ──────────────────────────────────────────────

## 获取道具定义
static func get_def(item_type: String) -> Dictionary:
	return DEFINITIONS.get(item_type, {})

## 获取所有定义
static func get_all_defs() -> Dictionary:
	return DEFINITIONS.duplicate(true)

## 获取稀有度颜色
static func get_rarity_color(rarity: String) -> Color:
	return RARITY_COLORS.get(rarity, Color.WHITE)

## 获取商店价格
static func get_shop_price(item_type: String) -> int:
	return int(SHOP_PRICES.get(item_type, 0))

## 随机掉落一个道具（基于敌人等级权重）
## rank: "normal" / "elite" / "boss"
static func roll_random_item(rank: String) -> Dictionary:
	## 构建权重池
	var pool: Array[Dictionary] = []
	var total_weight: int = 0
	for item_type in ALL_TYPES:
		var def: Dictionary = DEFINITIONS[item_type]
		var w: int = 0
		match rank:
			"boss":
				w = int(def.get("drop_weight_boss", 0))
			"elite":
				w = int(def.get("drop_weight_elite", 0))
			_:
				w = int(def.get("drop_weight_normal", 0))
		if w <= 0:
			continue
		pool.append({"type": item_type, "weight": w})
		total_weight += w

	if pool.is_empty() or total_weight <= 0:
		return {}

	## 加权随机
	var roll: int = randi() % total_weight
	var cumulative: int = 0
	for entry in pool:
		cumulative += int(entry.get("weight", 0))
		if roll < cumulative:
			var chosen_type: String = entry.get("type", "")
			var def: Dictionary = DEFINITIONS[chosen_type]
			return {
				"item_type": chosen_type,
				"name": def.get("name", ""),
				"desc": def.get("desc", ""),
				"rarity": def.get("rarity", "common"),
			}
	return {}

## 判断道具类型是否有效
static func is_valid_type(item_type: String) -> bool:
	return DEFINITIONS.has(item_type)
