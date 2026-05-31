## 收集成就数据
## 由 achievement_definitions_extended.gd 拆分而来
extends RefCounted
class_name AchievementsCollection

const DATA: Dictionary = {
	# ==================== 收集成就 (25个) ====================
	"collect_blueprints_10": {
		"id": "collect_blueprints_10",
		"name": "收藏家起步",
		"description": "解锁10种不同的蓝图",
		"category": "collection",
		"rarity": "COMMON",
		"requirements": {"type": "unique_blueprints", "count": 10},
		"reward": {"nano_materials": 100},
		"icon": "📚",
		"hidden": false,
		"flavor_text": "知识的积累始于好奇心。"
	},
	"collect_blueprints_30": {
		"id": "collect_blueprints_30",
		"name": "蓝图收集者",
		"description": "解锁30种不同的蓝图",
		"category": "collection",
		"rarity": "UNCOMMON",
		"requirements": {"type": "unique_blueprints", "count": 30},
		"reward": {"nano_materials": 200},
		"icon": "📐",
		"hidden": false,
		"flavor_text": "蓝图在手，天下我有。"
		},
	"collect_blueprints_50": {
		"id": "collect_blueprints_50",
		"name": "蓝图大师",
		"description": "解锁50种不同的蓝图",
		"category": "collection",
		"rarity": "RARE",
		"requirements": {"type": "unique_blueprints", "count": 50},
		"reward": {"nano_materials": 400, "rare_card": 1},
		"icon": "🗺️",
		"hidden": false,
		"flavor_text": "你已经掌握了大部分蓝图奥秘。"
		},
	"collect_blueprints_80": {
		"id": "collect_blueprints_80",
		"name": "蓝图百科全书",
		"description": "解锁80种不同的蓝图",
		"category": "collection",
		"rarity": "EPIC",
		"requirements": {"type": "unique_blueprints", "count": 80},
		"reward": {"nano_materials": 800, "mythic_card": 1},
		"icon": "📖",
		"hidden": false,
		"flavor_text": "你就是行走的蓝图百科全书。"
		},
	"collect_all_blueprints": {
		"id": "collect_all_blueprints",
		"name": "终极收藏家",
		"description": "解锁所有蓝图",
		"category": "collection",
		"rarity": "LEGENDARY",
		"requirements": {"type": "unique_blueprints", "count": 999},
		"reward": {"nano_materials": 10000, "mythic_card": 5, "title": "终极收藏家"},
		"icon": "🏆",
		"hidden": false,
		"flavor_text": "没有任何蓝图能逃过你的收藏。"
		},
	"collect_common_complete": {
		"id": "collect_common_complete",
		"name": "普通大师",
		"description": "收集所有普通品质的蓝图",
		"category": "collection",
		"rarity": "RARE",
		"requirements": {"type": "all_common_blueprints"},
		"reward": {"nano_materials": 300},
		"icon": "🟩",
		"hidden": false,
		"flavor_text": "普通并不平凡。"
		},
	"collect_rare_complete": {
		"id": "collect_rare_complete",
		"name": "稀有猎人",
		"description": "收集所有稀有品质的蓝图",
		"category": "collection",
		"rarity": "EPIC",
		"requirements": {"type": "all_rare_blueprints"},
		"reward": {"nano_materials": 600, "rare_card": 1},
		"icon": "🟦",
		"hidden": false,
		"flavor_text": "稀有中的稀有。"
		},
	"collect_mythic_complete": {
		"id": "collect_mythic_complete",
		"name": "神话征服者",
		"description": "收集所有神话品质的蓝图",
		"category": "collection",
		"rarity": "LEGENDARY",
		"requirements": {"type": "all_mythic_blueprints"},
		"reward": {"nano_materials": 2000, "mythic_card": 3, "title": "神话征服者"},
		"icon": "🟪",
		"hidden": false,
		"flavor_text": "神话在向你低头。"
		},
	"collect_cards_100": {
		"id": "collect_cards_100",
		"name": "卡牌收藏家",
		"description": "拥有100张卡牌（包括重复）",
		"category": "collection",
		"rarity": "COMMON",
		"requirements": {"type": "total_cards", "count": 100},
		"reward": {"nano_materials": 150},
		"icon": "🃏",
		"hidden": false,
		"flavor_text": "卡牌就是力量。"
		},
	"collect_cards_500": {
		"id": "collect_cards_500",
		"name": "卡牌大亨",
		"description": "拥有500张卡牌（包括重复）",
		"category": "collection",
		"rarity": "UNCOMMON",
		"requirements": {"type": "total_cards", "count": 500},
		"reward": {"nano_materials": 300},
		"icon": "🎴",
		"hidden": false,
		"flavor_text": "你的卡牌收藏令人印象深刻。"
		},
	"collect_max_rarity": {
		"id": "collect_max_rarity",
		"name": "品质追求",
		"description": "拥有一张最高品质的卡牌",
		"category": "collection",
		"rarity": "UNCOMMON",
		"requirements": {"type": "max_rarity_card"},
		"reward": {"nano_materials": 120},
		"icon": "💎",
		"hidden": false,
		"flavor_text": "品质就是一切。"
		},
}
